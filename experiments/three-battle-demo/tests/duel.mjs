import { chromium } from '@playwright/test';
import assert from 'node:assert/strict';
import { mkdir } from 'node:fs/promises';
const browser=await chromium.launch({channel:'chrome',headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[];
page.on('pageerror',e=>errors.push(e.message));
const ready=()=>page.waitForFunction(()=>window.__battleDemo?.ready&&!window.__battleDemo.busy);
const phase=value=>page.waitForFunction(value=>document.querySelector('#finisher').dataset.phase===value,value);
async function attack(){await page.click('[data-unit="enemy1"]');await page.click('#card-action');await page.locator('#finisher').waitFor({state:'visible'});}
await mkdir('artifacts',{recursive:true});
try {
  await page.goto(process.env.DEMO_URL||'http://127.0.0.1:4175/');await ready();
  await attack();assert.equal(await page.locator('#duel-card-right strong').innerText(),'2 / 2');
  assert.equal(await page.locator('#duel-right').evaluate(e=>e.classList.contains('fallen')),false);
  await phase('hit');assert.equal(await page.locator('#duel-card-right strong').innerText(),'0 / 2');
  await page.screenshot({path:'artifacts/duel-hit-desktop.png'});
  await phase('result');assert.equal(await page.locator('#duel-right').evaluate(e=>e.classList.contains('fallen')),true);await ready();
  await page.selectOption('#level','first_echo');await ready();
  const p=await page.evaluate(()=>window.__battleDemo.cellScreen({x:1,y:6}));await page.mouse.click(p.x,p.y);await ready();
  await attack();assert.equal(await page.locator('#duel-card-right strong').innerText(),'4 / 4');
  await phase('result');assert.equal(await page.locator('#duel-card-right strong').innerText(),'2 / 4');
  assert.equal(await page.locator('#duel-right').evaluate(e=>e.classList.contains('fallen')),false);await ready();
  await page.click('#end');await page.locator('#finisher').waitFor({state:'visible'});
  assert.equal(await page.locator('#duel-card-right p').innerText(),'发起攻击');
  await phase('result');assert.equal(await page.locator('#duel-card-left strong').innerText(),'0 / 2');
  assert.equal(await page.locator('#duel-left').evaluate(e=>e.classList.contains('fallen')),true);await ready();
  await page.getByRole('button',{name:'进入 T2',exact:true}).click();await page.locator('#finisher').waitFor({state:'visible'});
  assert.equal(await page.locator('#duel-card-left').getAttribute('data-team'),'ghost');
  await page.keyboard.press('Escape');await ready();
  assert.equal((await page.evaluate(()=>window.__battleDemo.snapshot())).enemies[0].hp,2);
  await page.setViewportSize({width:390,height:844});await page.click('#preview');await phase('hit');
  for(const selector of ['#duel-card-left','#duel-card-right','#skip']){
    const box=await page.locator(selector).boundingBox();assert.ok(box.x>=0&&box.x+box.width<=390&&box.y>=0&&box.y+box.height<=844);
  }
  await page.screenshot({path:'artifacts/duel-hit-mobile.png'});await page.keyboard.press('Escape');await ready();
  assert.deepEqual(errors,[]);console.log('PASS: lethal/nonlethal HP sequence, enemy attack and player death, ghost playback/skip, mobile HUD; no runtime errors');
}finally{await browser.close();}
