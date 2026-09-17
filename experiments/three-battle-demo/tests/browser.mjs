import { chromium } from '@playwright/test';
import assert from 'node:assert/strict';
import { mkdir, writeFile } from 'node:fs/promises';

await mkdir('artifacts',{recursive:true});
const browser=await chromium.launch({channel:process.env.DEMO_BROWSER_CHANNEL||'chrome',headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const page=await browser.newPage({viewport:{width:1440,height:1000},deviceScaleFactor:1});
const errors=[];page.on('pageerror',e=>errors.push(e.message));
page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
const checks=[];
async function ready(){await page.waitForFunction(()=>window.__battleDemo?.ready&&!window.__battleDemo.busy,{},{timeout:30000});await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));}
const snapshot=()=>page.evaluate(()=>window.__battleDemo.snapshot());
async function cell(x,y){const p=await page.evaluate(p=>window.__battleDemo.cellScreen(p),{x,y});await page.mouse.click(p.x,p.y);await ready();}
async function shot(name){await page.screenshot({path:`artifacts/${name}.png`,fullPage:true});}
try {
  await page.goto(process.env.DEMO_URL||'http://127.0.0.1:4173/');await ready();
  await page.waitForTimeout(400);await shot('desktop-initial');
  checks.push('Desktop loads with real WebGL scene');
  const before=await snapshot(),camera=await page.evaluate(()=>window.__battleDemo.camera());
  await page.click('#rotate-right');await page.waitForTimeout(250);
  assert.notDeepEqual(await page.evaluate(()=>window.__battleDemo.camera()),camera);assert.deepEqual(await snapshot(),before);
  const stage=await page.locator('#stage').boundingBox();
  await page.mouse.move(stage.x+stage.width*.5,stage.y+stage.height*.55);await page.mouse.down();await page.mouse.move(stage.x+stage.width*.5+120,stage.y+stage.height*.55+25,{steps:10});await page.mouse.up();
  assert.deepEqual(await snapshot(),before);checks.push('Camera button/drag do not consume actions');
  await page.click('#top-view');await page.waitForTimeout(400);await shot('desktop-top-view');await page.click('#reset-view');
  await page.click('[data-unit="enemy1"]');assert.match(await page.locator('#intent-detail').innerText(),/不显示/);
  assert.match(await page.locator('#card-action').innerText(),/斩杀/);checks.push('Unknown enemy intent remains hidden; selected card readable');
  await page.click('#card-action');await page.locator('#finisher').waitFor({state:'visible'});await page.waitForTimeout(650);await shot('finisher');
  const atFinisher=await snapshot();assert.equal(atFinisher.enemies[0].hp,0);
  await page.click('#skip');await ready();assert.deepEqual(await snapshot(),atFinisher);checks.push('Lethal hit enters 2D finisher; skip preserves settled state');
  const skipped=await snapshot();
  await page.click('#restart');await ready();await page.click('[data-unit="enemy1"]');await page.click('#card-action');await ready();assert.deepEqual(await snapshot(),skipped);checks.push('Normal and skipped finisher results match');
  await page.click('#restart');await ready();await page.uncheck('#cinematics');await page.click('[data-unit="enemy1"]');await page.click('#card-action');await ready();assert.deepEqual(await snapshot(),skipped);assert.equal(await page.locator('#finisher').isVisible(),false);checks.push('Disabled finisher yields identical combat result');
  await page.click('#restart');await ready();const previewState=await snapshot();await page.click('#preview');await page.locator('#finisher').waitFor({state:'visible'});await page.keyboard.press('Escape');await ready();assert.deepEqual(await snapshot(),previewState);checks.push('Preview and Escape leave battle unchanged');
  await page.selectOption('#level','first_echo');await ready();
  await cell(1,6);assert.equal((await snapshot()).player.x,1);assert.equal((await snapshot()).player.y,6);
  await page.click('[data-unit="enemy1"]');await page.click('#card-action');await ready();assert.equal((await snapshot()).enemies[0].hp,2);
  await page.click('#end');await page.locator('#dialog').waitFor({state:'visible'});assert.equal((await snapshot()).phase,'transition');
  await page.getByRole('button',{name:'进入 T2',exact:true}).click();await ready();assert.equal((await snapshot()).timeline,2);assert.equal((await snapshot()).enemies[0].hp,2);
  assert.equal(await page.locator('[data-unit="ghost1"]').count(),1);await shot('first-echo-t2');
  await cell(0,5);assert.equal((await snapshot()).player.y,5);
  await page.click('[data-unit="enemy1"]');await page.click('#card-action');await page.locator('#dialog').waitFor({state:'visible'});assert.equal((await snapshot()).phase,'won');checks.push('Real UI: T1 move, attack, death → T2 ghost replay → move, final kill, victory');
  await page.getByRole('button',{name:'留在棋盘',exact:true}).click();
  await page.selectOption('#level','laboratory');await ready();await page.click('#crystallize');await page.locator('#dialog').waitFor({state:'visible'});await page.getByRole('button',{name:'进入 T2',exact:true}).click();await ready();assert.equal((await snapshot()).timeline,2);checks.push('Crystallize enters new timeline from visible controls');
  for(const [width,height] of [[1280,720],[390,844],[360,800],[430,932]]) {
    await page.setViewportSize({width,height});await page.click('#restart');await ready();await page.waitForTimeout(300);
    assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
    for(const id of ['move','attack','crystallize','end','card-action']) {
      const box=await page.locator(`#${id}`).boundingBox();assert.ok(box&&box.x>=0&&box.x+box.width<=width+1,`${id} fits ${width}`);
    }
    await shot(`layout-${width}x${height}`);checks.push(`Layout ${width}×${height}: no horizontal overflow, all action buttons fit`);
  }
  await page.setViewportSize({width:390,height:844});await page.selectOption('#level','first_echo');await ready();await cell(1,6);assert.equal((await snapshot()).player.y,6);checks.push('Mobile-width point selection uses correct board coordinates');
  const mobile=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:1,hasTouch:true,isMobile:true});
  const touch=await mobile.newPage();touch.on('pageerror',e=>errors.push(e.message));
  await touch.goto(process.env.DEMO_URL||'http://127.0.0.1:4173/');await touch.waitForFunction(()=>window.__battleDemo?.ready);
  await touch.selectOption('#level','first_echo');await touch.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
  const touchTarget=await touch.evaluate(()=>window.__battleDemo.cellScreen({x:1,y:6}));await touch.touchscreen.tap(touchTarget.x,touchTarget.y);
  await touch.waitForFunction(()=>!window.__battleDemo.busy);assert.equal((await touch.evaluate(()=>window.__battleDemo.snapshot())).player.y,6);
  await touch.screenshot({path:'artifacts/mobile-touch.png',fullPage:true});await mobile.close();checks.push('Mobile touch tap moves to the intended grid cell');
  assert.deepEqual(errors,[]);
  const report={passed:checks.length,checks,errors};await writeFile('artifacts/browser-report.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
} catch(error) {
  await shot('failure');console.error('Browser errors:',errors);throw error;
} finally {await browser.close();}
