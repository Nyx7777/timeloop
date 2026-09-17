import { chromium } from '@playwright/test';
import assert from 'node:assert/strict';
import { mkdir,writeFile } from 'node:fs/promises';

await mkdir('artifacts/art-pass',{recursive:true});
const browser=await chromium.launch({channel:process.env.DEMO_BROWSER_CHANNEL||'chrome',headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[],checks=[];
page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
const ready=()=>page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
const info=()=>page.evaluate(()=>window.__battleDemo.artInfo());
try {
  await page.goto(process.env.DEMO_URL||'http://127.0.0.1:4173/');await page.waitForFunction(()=>window.__battleDemo?.ready);await ready();
  const state=await page.evaluate(()=>window.__battleDemo.snapshot());
  for(let i=0;i<8;i++){
    await page.waitForTimeout(400);await ready();
    await page.waitForFunction(()=>window.__battleDemo.artInfo().walls.some(w=>w.fade<.05));
    const art=await info();assert.equal(art.tiles,64);
    assert.ok(art.walls.filter(w=>w.fade<.05).length>=1,'camera-facing walls cut away');
    const frame=await page.locator('#stage').boundingBox();
    for(const [x,y] of [[-.5,-.5],[7.5,-.5],[7.5,7.5],[-.5,7.5]]){
      const p=await page.evaluate(p=>window.__battleDemo.cellScreen(p),{x,y});
      assert.ok(p.x>=frame.x&&p.x<=frame.x+frame.width&&p.y>=frame.y&&p.y<=frame.y+frame.height,'all playable corners remain in frame');
    }
    if(i%2===0)await page.screenshot({path:`artifacts/art-pass/direction-${i*45}.png`});
    await page.click('#rotate-right');
  }
  checks.push('8 camera orientations: cutaway walls active, 64 cells and all playable corners retained');
  assert.deepEqual(await page.evaluate(()=>window.__battleDemo.snapshot()),state);
  await page.click('#reset-view');await ready();
  await page.click('#detail-toggle');await ready();assert.equal((await info()).detailed,false);
  assert.deepEqual(await page.evaluate(()=>window.__battleDemo.snapshot()),state);
  await page.screenshot({path:'artifacts/art-pass/tactical-view.png'});
  await page.click('#restart');await ready();assert.equal((await info()).detailed,false);
  await page.click('#detail-toggle');await ready();assert.equal((await info()).detailed,true);
  checks.push('Detailed/tactical switch preserves battle and survives reset');
  await page.click('#restart');await ready();await page.waitForTimeout(400);const baseline=await info();
  for(let i=0;i<3;i++){await page.click('#restart');await ready();}
  const after=await info();assert.equal(after.textures,baseline.textures);assert.equal(after.geometries,baseline.geometries);
  checks.push('Three scene rebuilds retain stable GPU texture and geometry counts');
  for(const [width,height] of [[360,800],[390,844],[430,932]]){
    await page.setViewportSize({width,height});await page.click('#reset-view');await ready();await page.waitForTimeout(400);
    const frame=await page.locator('#stage').boundingBox();
    for(const [x,y] of [[-2,-2],[9,-2],[9,9],[-2,9]]){
      const p=await page.evaluate(p=>window.__battleDemo.cellScreen(p),{x,y});assert.ok(p.x>=frame.x-1&&p.x<=frame.x+frame.width+1&&p.y>=frame.y&&p.y<=frame.y+frame.height,'service apron fits mobile frame');
    }
    await page.screenshot({path:`artifacts/art-pass/mobile-${width}.png`,fullPage:true});
    checks.push(`Full laboratory apron fits ${width}×${height}`);
  }
  assert.deepEqual(errors,[]);
  const report={checks,resources:after,errors};await writeFile('artifacts/art-pass/report.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
} catch(error){await page.screenshot({path:'artifacts/art-pass/failure.png',fullPage:true});throw error;}
finally{await browser.close();}
