import './style.css';
import { Battle, cellName, same } from './battle.js';
import { BattleScene } from './scene.js';

const asset=name=>`${import.meta.env.BASE_URL}assets/${name}_idle.png`;
const $=s=>document.querySelector(s);
document.querySelector('#app').innerHTML=`
  <header class="masthead">
    <a class="brand" href="./" aria-label="重载时间循环实验室"><span class="brand-symbol">◈</span><span>时间循环<small>TIMELOOP / TACTICAL LAB</small></span></a>
    <div class="prototype-badge"><span></span> 三维表现试验 <b>01</b></div>
    <button class="quiet" id="help" aria-label="打开操作说明">操作说明 <span>?</span></button>
  </header>
  <main>
    <section class="statusbar" aria-label="战斗状态">
      <div class="scene-switch"><span class="eyebrow">场景 / SCENARIO</span><select id="level" aria-label="选择试验场景"><option value="laboratory">01　时间断层实验室</option><option value="first_echo">02　留下第一个自己</option></select></div>
      <div class="counters"><div><span>时间线</span><strong id="timeline">T1 <i>/ 3</i></strong></div><div><span>回合</span><strong id="turn">01</strong></div><div class="time-state"><span>敌人行为</span><strong id="time-state">未知时间</strong></div></div>
      <button id="restart" class="quiet" title="重开当前场景">↻ <span>重新开始</span></button>
    </section>
    <section class="sequence-wrap" aria-label="行动顺序"><div class="sequence-title"><span class="eyebrow">行动序列</span><small>点击卡片查看</small></div><div class="sequence" id="sequence"></div><div class="sequence-end">分身 → 本体 → 敌人</div></section>
    <div class="battle-layout">
      <section id="stage" class="stage" aria-label="三维战斗场景">
        <div class="stage-heading"><span class="eyebrow">SECTOR 07 / TEMPORAL FRACTURE</span><h1 id="scene-title">时间断层实验室</h1><p id="scene-subtitle"></p></div>
        <div id="loading" class="loading">正在构建实验室<span></span></div>
        <div class="camera-tools" aria-label="镜头控制"><button id="rotate-left" title="向左旋转 45°" aria-label="向左旋转">↶</button><button id="rotate-right" title="向右旋转 45°" aria-label="向右旋转">↷</button><button id="top-view">俯视</button><button id="reset-view">复位</button></div>
        <div class="stage-bottom"><div class="legend"><span class="cyan">本体</span><span class="purple">分身</span><span class="coral">敌人</span><span class="gold">固定意图</span></div><div class="camera-help">拖动旋转 · 滚轮缩放 · 点击选格</div></div>
        <div class="coordinate" id="coordinate">8 × 8</div>
      </section>
      <aside class="inspector" aria-label="完整单位卡片">
        <div class="inspector-heading"><span class="eyebrow">单位档案</span><span id="unit-tag">当前本体</span></div>
        <div class="portrait-wrap" id="portrait-wrap"><div class="portrait-orbit"></div><span class="portrait-number" id="portrait-number">07</span><img id="portrait" src="${asset('player')}" alt="实验体 07"/><span class="portrait-caption" id="portrait-caption">SUBJECT / 07</span></div>
        <div class="unit-info"><h2 id="unit-name">实验体 07</h2><p id="unit-description">在时间断层中，留下另一个自己。</p><div class="health-row"><span>生命</span><strong id="health-value">6 / 6</strong></div><div class="health-track"><span id="health-fill"></span></div><div class="unit-stats"><div><span>移动</span><b id="stat-move">3 格</b></div><div><span>伤害</span><b id="stat-attack">2 点</b></div><div><span>位置</span><b id="stat-position">C7</b></div></div><div class="intent-card"><span class="eyebrow" id="intent-title">本回合行动</span><p id="intent-detail"></p></div><button id="card-action" class="primary card-action">选择移动位置 ↗</button></div>
        <div class="record-panel"><span class="eyebrow">最近发生</span><ol id="log"></ol></div>
      </aside>
    </div>
    <section class="command-deck"><div class="context"><span class="context-dot"></span><p id="hint" role="status" aria-live="polite"></p><label class="cinematic-option"><input type="checkbox" id="cinematics" checked/>斩杀演出</label><button id="preview" class="quiet">演出预览 ↗</button></div><div class="actions"><button id="move" data-command="move"><span class="action-icon">↗</span><span><b>移动</b><small id="move-state">3 格 · 每回合一次</small></span><kbd>1</kbd></button><button id="attack" data-command="attack"><span class="action-icon">✧</span><span><b>攻击</b><small id="attack-state">相邻一格</small></span><kbd>2</kbd></button><button id="crystallize" data-command="crystallize"><span class="action-icon">◈</span><span><b>固化</b><small>留下本条时间线</small></span><kbd>3</kbd></button><button id="end" data-command="end" class="end-action"><span class="action-icon">→</span><span><b>结束回合</b><small>执行敌方行动</small></span><kbd>空格</kbd></button></div></section>
  </main>
  <footer><span>THREE-DIMENSIONAL COMBAT STUDY</span><span>场景可旋转 / 信息始终正对你</span></footer>
  <div id="dialog" class="dialog-backdrop" hidden><section class="dialog" role="dialog" aria-modal="true" aria-labelledby="dialog-title"><span class="eyebrow" id="dialog-kicker">TIMELOOP</span><h2 id="dialog-title"></h2><p id="dialog-text"></p><div id="dialog-buttons"></div></section></div>
  <div id="finisher" class="finisher" hidden role="dialog" aria-modal="true" aria-label="二维斩杀演出"><div class="finish-grid"></div><div class="finish-halo"></div><span class="finish-code">CAUSALITY / SEVERED</span><div class="finish-portrait"><img id="finish-actor" src="${asset('player')}" alt="我方角色斩杀特写"/></div><div class="finish-enemy"><img src="${asset('guard')}" alt="时间错位研究员"/></div><div class="finish-slash"></div><div class="finish-copy"><span id="finish-source">实验体 07 · 特殊终结</span><h2>时序<span>断裂</span></h2><p>这一刻，只留下你的未来。</p><b id="finish-result">目标已消除</b></div><button id="skip" class="skip">跳过演出　Esc ↗</button></div>
`;

let battle=new Battle(),scene,busy=false,selected='player',mode='move',logs=[],finishResolve=null,previousFocus=null;
const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
if(reduced) $('#cinematics').checked=false;
const portraitName=u=>u.team==='enemy'?'guard':u.team;
const getSelected=()=>battle.units.find(u=>u.id===selected&&u.hp>0)||battle.player;
const say=text=>{$('#hint').textContent=text;};
function log(text) {logs.unshift(text);logs=logs.slice(0,3);$('#log').replaceChildren(...logs.map(t=>{const li=document.createElement('li');li.textContent=t;return li;}));}
function render() {
  const u=getSelected(); selected=u.id;
  $('#timeline').innerHTML=`T${battle.timeline} <i>/ ${battle.level.lives}</i>`;$('#turn').textContent=String(battle.turn).padStart(2,'0');
  $('#time-state').textContent=battle.known?`固定 ${battle.intents.length}`:'未知时间';$('#time-state').classList.toggle('known',battle.known);
  $('#scene-title').textContent=battle.level.name;$('#scene-subtitle').textContent=battle.level.subtitle + (battle.known?' · 已知时间':' · 未知时间');
  const sequence=[...battle.ghosts.filter(g=>g.endTurn>=battle.turn),battle.player,...battle.enemies];
  $('#sequence').innerHTML=sequence.map(unit=>`<button class="sequence-card ${unit.team} ${unit.id===selected?'selected':''} ${unit.hp<=0?'defeated':''}" data-unit="${unit.id}" ${unit.hp<=0?'disabled':''}><span class="sequence-face"><img src="${asset(portraitName(unit))}" alt=""/></span><span><b>${unit.team==='player'?'07 · 本体':unit.team==='ghost'?`T${unit.source} · 分身`:unit.id.replace('enemy','E')+' · 研究员'}</b><small>${unit.hp<=0?'已消除':unit.team==='player'?'你的行动':unit.team==='ghost'?'历史重演':battle.known?'◷ 固定意图':'? 未知行动'}</small></span></button>`).join('');
  $('#portrait').src=asset(portraitName(u));$('#portrait').alt=u.name;$('#portrait-wrap').dataset.team=u.team;
  $('#unit-tag').textContent=u.team==='player'?'当前本体':u.team==='ghost'?'历史投影':battle.known?'固定敌人':'未知敌人';
  $('#unit-name').textContent=u.name;$('#portrait-number').textContent=u.team==='player'?'07':u.team==='ghost'?`T${u.source}`:u.id.replace('enemy','E');
  $('#portrait-caption').textContent=u.team==='player'?'SUBJECT / 07':u.team==='ghost'?'TEMPORAL / ECHO':'RESEARCHER / DISPLACED';
  $('#unit-description').textContent=u.team==='player'?'在时间断层中，留下另一个自己。':u.team==='ghost'?'沿原路径重演，攻击原来的目标格。':'被困在实验室中的时间错位研究员。';
  $('#health-value').textContent=u.team==='ghost'?'时间投影':`${u.hp} / ${u.maxHp}`;$('#health-fill').style.width=`${u.team==='ghost'?100:u.hp/u.maxHp*100}%`;
  $('#stat-move').textContent=`${u.range} 格`;$('#stat-attack').textContent=`${u.damage} 点`;$('#stat-position').textContent=cellName(u);
  const intent=battle.intents.find(i=>i.id===u.id);
  $('#intent-title').textContent=u.team==='player'?'本回合行动':u.team==='ghost'?'已记录的行为':battle.known?'本回合固定意图':'未来尚未发生';
  $('#intent-detail').textContent=u.team==='player'?`${battle.moved?'移动已用':battle.acted?'本回合移动已关闭':'可移动'} · ${battle.acted?'攻击已用':'可攻击'}。青色格可达，橙红色格可攻击。`:u.team==='ghost'?`重演 T${u.source} 的第 ${battle.turn} 回合，录像止于第 ${u.endTurn} 回合。`:
    intent?`${intent.path.length>1?`移动至 ${cellName(intent.path.at(-1))}`:'原地'}${intent.target?` → 攻击 ${cellName(intent.target)}，${intent.damage} 点伤害`:' → 等待'}。`:'? 敌人将在你结束回合后决策，当前不显示其路径或攻击目标。';
  const legalTarget=battle.targets().some(e=>e.id===u.id);
  $('#card-action').textContent=u.team==='enemy'?(legalTarget?(u.hp<=battle.player.damage?'斩杀这个敌人 ✧':'攻击这个敌人 ✧'):'与本体相邻后可攻击'):u.team==='ghost'?'查看本体行动 ↗':'选择移动位置 ↗';
  $('#card-action').disabled=busy||battle.phase!=='input'||(u.team==='enemy'&&!legalTarget)||(u.team==='player'&&(battle.moved||battle.acted));
  $('#move-state').textContent=battle.moved?'本回合已移动':battle.acted?'攻击后不可移动':`${battle.player.range} 格 · 每回合一次`;
  $('#attack-state').textContent=battle.acted?'本回合已攻击':`${battle.player.damage} 点伤害 · 相邻一格`;
  for(const id of ['move','attack','crystallize','end']) {
    const button=$(`#${id}`);button.disabled=busy||battle.phase!=='input'||(id==='move'&&(battle.moved||battle.acted))||(id==='attack'&&battle.acted)||(id==='crystallize'&&(!battle.level.crystallize||battle.timeline>=battle.level.lives));
    button.classList.toggle('active',mode===id);
  }
  for(const id of ['restart','level','preview','help'])$(`#${id}`).disabled=busy;
  scene.locked=busy;scene.sync(battle.units,selected);
  scene.setTactics({reachable:mode==='move'&&!busy?battle.reachable():new Map(),targets:!busy?battle.targets():[],intents:busy?[]:battle.intents,selected});
}
function select(id) {
  if(busy||!$('#dialog').hidden)return;
  if(!battle.units.some(u=>u.id===id&&u.hp>0))return;
  selected=id;render();
  const u=getSelected();
  if(u.team==='enemy') say(battle.targets().some(e=>e.id===id)?'已选中敌人。点击卡片中的攻击按钮，或再次点击敌人所在格。':'已聚焦该敌人；移动到相邻格后可以攻击。');
}
async function clickCell(p) {
  if(busy||!$('#dialog').hidden)return;
  const enemy=battle.enemies.find(e=>e.hp>0&&same(e,p));
  if(enemy) {
    if(mode==='attack'||selected===enemy.id)await run('attack',p);
    else select(enemy.id);
  } else if(mode==='move') await run('move',p);
  else say('选择一个与本体相邻的敌人，或切换到移动。');
}
function showDialog(kicker,title,text,buttons) {
  previousFocus=document.activeElement;$('#dialog-kicker').textContent=kicker;$('#dialog-title').textContent=title;$('#dialog-text').textContent=text;
  $('#dialog-buttons').replaceChildren(...buttons.map(({label,action,primary=true})=>{const b=document.createElement('button');b.textContent=label;b.className=primary?'primary':'quiet';b.onclick=()=>{$('#dialog').hidden=true;previousFocus?.focus();action?.();};return b;}));
  $('#dialog').hidden=false;$('#dialog-buttons button').focus();
}
function closeFinisher() {finishResolve?.();}
async function finisher(source='player',preview=false) {
  const previous=document.activeElement;const ghost=source.startsWith('ghost');
  $('#finish-actor').src=asset(ghost?'ghost':'player');$('#finish-source').textContent=ghost?`T${source.replace('ghost','')} 分身 · 历史终结`:'实验体 07 · 特殊终结';
  $('#finish-result').textContent=preview?'演出预览 · 不影响战斗':'目标已消除';
  $('#finisher').hidden=false;$('#finisher').classList.toggle('ghost-finish',ghost);$('#skip').focus();
  await new Promise(resolve=>{
    let done=false;const timer=setTimeout(finish,reduced?350:2100);
    function finish(){if(done)return;done=true;clearTimeout(timer);finishResolve=null;$('#finisher').hidden=true;previous?.focus();resolve();}
    finishResolve=finish;
  });
}
async function play(events) {
  for(const event of events) {
    const speed=reduced?4:1;
    if(event.type==='move') await scene.move(event.id,event.path,speed);
    if(event.type==='attack'||event.type==='miss') await scene.attack(event.id,event.target,speed);
    if(event.type==='damage'){await scene.damage(event.id,event.damage,event.hp,speed);log(`${event.id==='player'?'本体':event.id.replace('enemy','E')} 受到 ${event.damage} 点伤害。`);}
    if(event.type==='death') {
      if(event.finisher&&$('#cinematics').checked)await finisher(event.killer);
      await scene.death(event.id,speed);
    }
  }
}
async function run(type,target) {
  if(busy)return;
  const result=battle.command(type,target);if(!result.ok){say(result.reason);return;}
  busy=true;scene.locked=true;
  for(const button of document.querySelectorAll('.actions button,#card-action,#restart,#level,#preview,#help'))button.disabled=true;
  scene.setTactics({reachable:new Map(),targets:[],intents:[],selected});
  if(type==='next') {
    scene.build(battle.level);
    const initial=new Battle(battle.levelId);
    scene.sync([...initial.units,...battle.ghosts.map(g=>({...g,x:battle.level.player.x,y:battle.level.player.y}))],selected);
    log(`进入 T${battle.timeline}，旧时间线开始重演。`);
  }
  say(type==='end'?'敌方行动与历史重演中…':type==='next'?'正在重建历史…':'正在执行行动…');
  try{await play(result.events);}finally{busy=false;mode=battle.moved?'attack':'move';render();}
  if(battle.phase==='won') {
    log('所有敌人已消除。');
    showDialog('TIMELINE / RESOLVED','战斗完成',`你在 T${battle.timeline} 的第 ${battle.turn} 回合清除了所有敌人。可以换个场景，继续比较三维棋盘与二维牌面的阅读体验。`,[{label:'再试一次',action:()=>reset(battle.levelId)},{label:'留在棋盘',primary:false}]);
  } else if(battle.phase==='transition') {
    const crystallized=result.events.some(e=>e.type==='transition'&&e.reason==='crystallize');
    showDialog('TEMPORAL / ECHO',crystallized?'这一刻，被留下了':'你倒下了，历史仍在',`T${battle.timeline} 的动作已被记录。进入 T${battle.timeline+1} 后，紫色分身会先重演；你可以改变本体的行动，与过去的自己配合。`,[{label:`进入 T${battle.timeline+1}`,action:()=>run('next')}]);
  } else if(battle.phase==='lost') {
    showDialog('LINK / DISCONNECTED','时间链接已断开','所有时间线已用尽。重新开始后，可以尝试改变站位和攻击时机。',[{label:'重新开始',action:()=>reset(battle.levelId)}]);
  } else say(type==='next'?'分身已完成本回合重演。现在轮到你；注意紫色分身占位和固定攻击格。':battle.acted?'攻击已完成，结束回合执行敌方行动。':battle.moved?'移动已完成。选择相邻敌人攻击，或结束回合。':'新回合开始，可以移动或攻击。');
}
function reset(levelId) {if(busy)return;battle.reset(levelId);$('#level').value=levelId;selected='player';mode='move';logs=[];$('#dialog').hidden=true;scene.build(battle.level);scene.resetCamera();render();say(battle.level.hint);log('实验室已就绪，等待你的行动。');}

async function boot() {
  try {
    scene=new BattleScene($('#stage'),{onCell:clickCell,onSelect:id=>{
      if(mode==='attack'&&id.startsWith('enemy')){const enemy=battle.enemies.find(e=>e.id===id);run('attack',{x:enemy.x,y:enemy.y});}else select(id);
    },onHover:p=>{$('#coordinate').textContent=p?cellName(p):'8 × 8';}});
    await scene.load();$('#loading').remove();reset('laboratory');
    $('#sequence').addEventListener('click',e=>{const b=e.target.closest('[data-unit]');if(b)select(b.dataset.unit);});
    $('#level').onchange=e=>reset(e.target.value);$('#restart').onclick=()=>reset(battle.levelId);
    $('#rotate-left').onclick=()=>scene.rotate(-1);$('#rotate-right').onclick=()=>scene.rotate(1);$('#top-view').onclick=()=>scene.resetCamera(true);$('#reset-view').onclick=()=>scene.resetCamera();
    $('#move').onclick=()=>{if(busy)return;mode='move';selected='player';render();say('点击青色格移动。拖动镜头不会消耗行动。');};
    $('#attack').onclick=()=>{if(busy)return;mode='attack';render();say(battle.targets().length?'点击相邻敌人攻击；生命不高于伤害时触发斩杀。':'当前没有相邻敌人，可以先移动靠近。');};
    $('#end').onclick=()=>run('end');$('#crystallize').onclick=()=>run('crystallize');
    $('#card-action').onclick=()=>{const u=getSelected();if(u.team==='enemy')run('attack',{x:u.x,y:u.y});else {selected='player';render();$('#move').click();}};
    $('#preview').onclick=async()=>{if(busy)return;busy=true;render();try{await finisher('player',true);}finally{busy=false;render();}};
    $('#skip').onclick=closeFinisher;
    $('#help').onclick=()=>showDialog('FIELD / MANUAL','把战场转到看得清的角度','拖动棋盘旋转，滚轮或双指缩放；点击顶部行动卡查看完整信息。按 1 移动、2 攻击、3 固化，空格结束回合。手机上点击底部按钮操作。第一关沿用项目原始配置；实验室是自定义视觉试验场，未加入击退、扰动和完整六关规则。',[{label:'进入实验室'}]);
    window.addEventListener('keydown',e=>{
      if(e.key==='Escape'&&finishResolve){e.preventDefault();closeFinisher();return;}
      const overlay=!$('#finisher').hidden?$('#finisher'):!$('#dialog').hidden?$('#dialog'):null;
      if(overlay){if(e.key==='Tab'){const buttons=[...overlay.querySelectorAll('button')];if(e.shiftKey&&document.activeElement===buttons[0]){e.preventDefault();buttons.at(-1).focus();}else if(!e.shiftKey&&document.activeElement===buttons.at(-1)){e.preventDefault();buttons[0].focus();}}return;}
      if(busy||['INPUT','SELECT'].includes(document.activeElement?.tagName))return;
      if(e.key===' '&&document.activeElement?.tagName==='BUTTON')return;
      const id={'1':'move','2':'attack','3':'crystallize',' ':'end','q':'rotate-left','e':'rotate-right','r':'reset-view'}[e.key.toLowerCase()];
      if(id){e.preventDefault();$(`#${id}`).click();}
    });
    window.__battleDemo={snapshot:()=>battle.snapshot(),cellScreen:p=>{const q=scene.cellScreen(p),r=$('#stage').getBoundingClientRect();return {x:q.x+r.left,y:q.y+r.top};},camera:()=>scene.camera.position.toArray(),ready:true,get busy(){return busy;}};
  } catch(error) {
    console.error(error);$('#loading')?.remove();
    const notice=document.createElement('div');notice.className='load-error';notice.textContent='三维场景未能启动。请使用支持 WebGL 2 的浏览器并开启硬件加速，然后刷新页面。';$('#stage').append(notice);
    for(const b of document.querySelectorAll('button,select'))b.disabled=true;
  }
}
boot();
