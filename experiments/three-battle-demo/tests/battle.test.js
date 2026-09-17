import test from 'node:test';
import assert from 'node:assert/strict';
import { Battle, key, LEVELS } from '../src/battle.js';
import { readFileSync } from 'node:fs';

function firstDeath(b) {
  assert.ok(b.command('move',{x:1,y:6}).ok);
  assert.ok(b.command('attack',{x:1,y:5}).ok);
  const r=b.command('end');
  assert.equal(b.phase,'transition');
  assert.equal(b.player.hp,0);
  return r;
}
test('first_echo matches the source Godot level coordinates and parameters',()=>{
  const source=readFileSync(new URL('../../../game/content/levels/first_echo.tres',import.meta.url),'utf8');
  const p=LEVELS.first_echo.player,e=LEVELS.first_echo.enemies[0];
  const spawns=[...source.matchAll(/position = Vector2i\((\d+), (\d+)\)\r?\nmax_hp = (\d+)\r?\nmove_range = (\d+)\r?\nattack_damage = (\d+)/g)].map(m=>m.slice(1).map(Number));
  assert.deepEqual(spawns,[[p.x,p.y,p.hp,p.range,p.damage],[e.x,e.y,e.hp,e.range,e.damage]]);
  for(const [x,y] of LEVELS.first_echo.walls)assert.ok(source.includes(`Vector2i(${x}, ${y})`));
  assert.ok(source.includes(`lives = ${LEVELS.first_echo.lives}`));
});
test('illegal movement, attacks and unavailable crystallize never change state',()=>{
  const b=new Battle('first_echo'),before=b.snapshot();
  for(const [cmd,target] of [['move',{x:2,y:6}],['move',{x:7,y:0}],['move',{x:-1,y:7}],['attack',{x:1,y:5}],['crystallize'],['next'],['bogus']]) {
    assert.equal(b.command(cmd,target).ok,false);assert.deepEqual(b.snapshot(),before);
  }
});
test('movement respects walls, enemy occupancy and range; movement only once',()=>{
  const b=new Battle('first_echo');
  for(const path of b.reachable().values()) {assert.ok(path.length<=4);assert.ok(path.every(p=>b.ground(p.x,p.y)));}
  assert.ok(!b.reachable().has(key(1,5)));
  assert.ok(b.command('move',{x:1,y:6}).ok);
  assert.equal(b.command('move',{x:0,y:6}).ok,false);
});
test('T1 unknown intentions are not exposed before the enemy phase',()=>{
  const b=new Battle('first_echo');assert.equal(b.known,false);assert.deepEqual(b.intents,[]);
  b.command('move',{x:1,y:6});assert.deepEqual(b.intents,[]);
});
test('first level: death → fixed intent → ghost replay → player finisher victory',()=>{
  const b=new Battle('first_echo');firstDeath(b);
  const next=b.command('next');
  assert.equal(b.timeline,2);assert.equal(b.turn,1);assert.equal(b.player.hp,2);
  assert.equal(b.enemies[0].hp,2);assert.equal(b.known,true);
  assert.equal(next.events.filter(e=>e.type==='damage').length,1);
  assert.deepEqual(b.intents[0].target,{x:1,y:6});
  assert.ok(!b.reachable().has(key(1,6)));
  assert.ok(b.command('move',{x:0,y:5}).ok);
  const hit=b.command('attack',{x:1,y:5});
  assert.equal(b.phase,'won');assert.equal(b.enemies[0].hp,0);
  assert.equal(hit.events.filter(e=>e.type==='death'&&e.finisher).length,1);
  const complete=b.snapshot();assert.equal(b.command('attack',{x:1,y:5}).ok,false);assert.deepEqual(b.snapshot(),complete);
});
test('crystallize records immediately without executing enemies; last life cannot crystallize',()=>{
  const b=new Battle();const hp=b.player.hp;
  b.command('move',{x:2,y:5});assert.ok(b.command('crystallize').ok);
  assert.equal(b.player.hp,hp);assert.deepEqual(b.history,{});assert.equal(b.records[0].actions.length,1);
  b.command('next');assert.equal(b.ghosts[0].x,2);assert.equal(b.ghosts[0].y,5);
  b.command('crystallize');b.command('next');
  assert.equal(b.command('crystallize').ok,false);assert.equal(b.timeline,3);
});
test('finisher events do not own damage: event playback, skip and omission preserve state',()=>{
  const results=[];
  for(const mode of ['full','skip','off']) {
    const b=new Battle();const r=b.command('attack',{x:3,y:6});
    if(mode==='full')for(const event of r.events)structuredClone(event);
    if(mode==='skip')r.events.length=0;
    results.push(b.snapshot());
    assert.equal(b.command('attack',{x:3,y:6}).ok,false);
  }
  assert.deepEqual(results[0],results[1]);assert.deepEqual(results[1],results[2]);
});
test('an attack closes movement for that turn; restart clears recordings and histories',()=>{
  const b=new Battle();b.command('attack',{x:3,y:6});assert.equal(b.reachable().size,0);
  b.command('crystallize');b.command('next');b.reset('first_echo');
  assert.equal(b.timeline,1);assert.deepEqual(b.records,[]);assert.deepEqual(b.history,{});assert.equal(b.units.length,2);
});
test('ghosts expire after their recorded end turn and never retarget',()=>{
  const b=new Battle();b.command('attack',{x:3,y:6});b.command('crystallize');b.command('next');
  assert.equal(b.enemies[0].hp,0);assert.equal(b.units.filter(u=>u.team==='ghost').length,1);
  b.command('end');assert.equal(b.turn,2);assert.equal(b.units.filter(u=>u.team==='ghost').length,0);
});
test('final life death yields defeat without an unusable extra recording',()=>{
  const b=new Battle('first_echo');firstDeath(b);b.command('next');
  // Wait in safety until the surviving researcher reaches the player.
  for(let i=0;i<8&&b.phase==='input';i++)b.command('end');
  assert.equal(b.phase,'lost');assert.equal(b.records.length,1);assert.equal(b.command('next').ok,false);
});
