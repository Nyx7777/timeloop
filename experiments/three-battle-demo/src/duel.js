import './duel.css';

const asset=team=>`${import.meta.env.BASE_URL}assets/${team==='enemy'?'guard':team}_idle.png`;
export const duelMarkup=`<div id="finisher" class="duel" hidden role="dialog" aria-modal="true" aria-label="一对一战斗演出">
  <header class="duel-heading"><span>SECTOR 07 / COMBAT LINK</span><h2>交战</h2><p id="duel-status" aria-live="polite">双方就位</p></header>
  <div class="duel-room"><div class="duel-windows"></div><div class="duel-door">07</div><div class="duel-floor"></div><div class="duel-platform"></div>
    ${['left','right'].map(side=>`<div class="duel-fighter ${side}" id="duel-${side}"><div class="duel-shadow"></div><img alt=""/><span class="duel-impact"></span><b class="duel-damage"></b></div>`).join('')}
  </div>
  <div class="duel-hud">${['left','right'].map(side=>`<section class="duel-card" id="duel-card-${side}"><small></small><h3></h3><div class="duel-hp-label"><span>HP</span><strong></strong></div><div class="duel-hp-track"><i></i><b></b></div><p></p></section>`).join('')}</div>
  <button id="skip" class="duel-skip">跳过演出　Esc ↗</button>
</div>`;

// Uses immutable event-time snapshots, never the already-settled battle state.
export function playDuel(event,{preview=false,reduced=false}={}) {
  const root=document.querySelector('#finisher'),previous=document.activeElement;
  const {attacker,defender,damage,hpAfter}=event;
  const attackerSide=attacker.team==='enemy'?'right':'left';
  const defenderSide=attackerSide==='left'?'right':'left';
  const fighter=side=>root.querySelector(`#duel-${side}`);
  const card=side=>root.querySelector(`#duel-card-${side}`);
  for(const [unit,side,role] of [[attacker,attackerSide,'发起攻击'],[defender,defenderSide,'迎战']]) {
    const f=fighter(side),c=card(side);f.className=`duel-fighter ${side}`;
    f.querySelector('img').src=asset(unit.team);f.querySelector('img').alt=unit.name;
    f.querySelector('.duel-damage').textContent='';c.dataset.team=unit.team;
    c.querySelector('small').textContent=unit.team==='ghost'?'TEMPORAL ECHO':unit.team==='enemy'?'DISPLACED RESEARCHER':'SUBJECT / 07';
    c.querySelector('h3').textContent=unit.name;c.querySelector('strong').textContent=`${unit.hp} / ${unit.maxHp}`;
    for(const bar of c.querySelectorAll('.duel-hp-track > *'))bar.style.width=`${unit.hp/unit.maxHp*100}%`;
    c.querySelector('p').textContent=role;
  }
  root.dataset.phase='ready';root.querySelector('#duel-status').textContent=preview?'演出预览 · 不影响战斗':`${attacker.name} 发起攻击`;
  root.hidden=false;root.querySelector('#skip').focus();
  const timers=[];let done=false,resolve;
  const finished=new Promise(r=>resolve=r);
  const later=(ms,fn)=>timers.push(setTimeout(fn,reduced?ms/5:ms));
  const close=()=>{if(done)return;done=true;timers.forEach(clearTimeout);root.hidden=true;previous?.focus();resolve();};
  later(500,()=>{root.dataset.phase='strike';fighter(attackerSide).classList.add('lunging');});
  later(900,()=>{
    root.dataset.phase='hit';fighter(defenderSide).classList.add('hit');
    fighter(defenderSide).querySelector('.duel-damage').textContent=`−${damage}`;
    const c=card(defenderSide);c.querySelector('strong').textContent=`${hpAfter} / ${defender.maxHp}`;
    c.querySelector('.duel-hp-track b').style.width=`${hpAfter/defender.maxHp*100}%`;
    c.querySelector('p').textContent=`受到 ${damage} 点伤害`;
    root.querySelector('#duel-status').textContent='命中';
  });
  later(1250,()=>{card(defenderSide).querySelector('.duel-hp-track i').style.width=`${hpAfter/defender.maxHp*100}%`;});
  later(1650,()=>{
    root.dataset.phase='result';fighter(attackerSide).classList.remove('lunging');
    if(hpAfter===0)fighter(defenderSide).classList.add('fallen');
    card(defenderSide).querySelector('p').textContent=hpAfter===0?'生命归零 · 战死':'仍可继续战斗';
    root.querySelector('#duel-status').textContent=hpAfter===0?`${defender.name} 倒下了`:'攻击结束';
  });
  later(hpAfter===0?3000:2350,close);
  return {finished,close};
}
