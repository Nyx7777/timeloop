// A deliberately small, deterministic adapter for this visual experiment.
// Godot remains the authoritative full game; no DOM or animation lives here.
export const LEVELS = {
  laboratory: {
    name: '时间断层实验室', subtitle: '空间与斩杀 · 自定义试验场', lives: 3,
    hint: '先攻击身旁的 E1，体验二维斩杀；随后移动、结束回合，或固化留下分身。',
    walls: [[1,1],[1,2],[5,2],[5,3],[2,4],[5,6]], holes: [[3,3],[6,1]],
    player: { x: 2, y: 6, hp: 6, damage: 2, range: 3 },
    enemies: [{x:3,y:6,hp:2,damage:1,range:1},{x:6,y:4,hp:4,damage:1,range:1},{x:3,y:1,hp:4,damage:1,range:1}],
    crystallize: true,
  },
  first_echo: {
    name: '留下第一个自己', subtitle: '原项目第 1 关 · 时间循环验证', lives: 2,
    hint: '移动到 B7，攻击 B6 的 E1，再结束回合。下一条时间线与分身配合补刀。',
    walls: [[2,4],[2,5],[2,6]], holes: [],
    player: {x:0,y:7,hp:2,damage:2,range:3},
    enemies: [{x:1,y:5,hp:4,damage:2,range:1}], crystallize: false,
  },
};
export const key = (x,y) => `${x},${y}`;
export const same = (a,b) => a.x === b.x && a.y === b.y;
export const distance = (a,b) => Math.abs(a.x-b.x)+Math.abs(a.y-b.y);
export const cellName = p => `${String.fromCharCode(65+p.x)}${p.y+1}`;
const copy = value => structuredClone(value);
const position = u => ({x:u.x,y:u.y});
const dirs = [[1,0],[-1,0],[0,1],[0,-1]];

export class Battle {
  constructor(levelId = 'laboratory') { this.reset(levelId); }
  reset(levelId = this.levelId) {
    if (!LEVELS[levelId]) throw new Error('Unknown level');
    this.levelId = levelId;
    this.level = copy(LEVELS[levelId]);
    this.timeline = 1; this.turn = 1; this.records = []; this.history = {};
    this.resetUnits();
  }
  resetUnits() {
    const p = this.level.player;
    this.player = {...p,id:'player',name:'实验体 07',team:'player',maxHp:p.hp};
    this.enemies = this.level.enemies.map((e,i)=>({...e,id:`enemy${i+1}`,name:`错位研究员 E${i+1}`,team:'enemy',maxHp:e.hp}));
    this.ghosts = this.records.map(r=>({...p,id:`ghost${r.timeline}`,name:`T${r.timeline} 时间分身`,team:'ghost',maxHp:p.hp,source:r.timeline,endTurn:r.endTurn}));
    this.recording = []; this.currentHistory = {}; this.phase = 'input';
    this.moved = false; this.acted = false;
  }
  get units() { return [this.player,...this.ghosts.filter(g=>g.endTurn>=this.turn),...this.enemies.filter(e=>e.hp>0)]; }
  get intents() { return copy(this.history[this.turn] || []).filter(i=>this.enemies.some(e=>e.id===i.id&&e.hp>0)); }
  get known() { return Object.hasOwn(this.history,this.turn); }
  ground(x,y) { return Number.isInteger(x)&&Number.isInteger(y)&&x>=0&&y>=0&&x<8&&y<8&&!this.level.walls.some(p=>p[0]===x&&p[1]===y)&&!this.level.holes.some(p=>p[0]===x&&p[1]===y); }
  reachable() {
    const paths = new Map();
    if(this.phase!=='input'||this.moved||this.acted) return paths;
    const origin = position(this.player), queue = [[origin]];
    const visited = new Set([key(origin.x,origin.y)]);
    while(queue.length) {
      const path=queue.shift(), end=path.at(-1);
      if(path.length>this.player.range) continue;
      for(const [dx,dy] of dirs) {
        const p={x:end.x+dx,y:end.y+dy}, k=key(p.x,p.y);
        if(visited.has(k)||!this.ground(p.x,p.y)||this.enemies.some(e=>e.hp>0&&same(e,p))) continue;
        visited.add(k); const next=[...path,p]; queue.push(next);
        const ghostHere = this.ghosts.some(g=>g.endTurn>=this.turn&&same(g,p));
        if(!ghostHere||same(p,this.level.player)) paths.set(k,next);
      }
    }
    return paths;
  }
  targets() { return this.phase==='input'&&!this.acted?this.enemies.filter(e=>e.hp>0&&distance(e,this.player)===1):[]; }
  command(type, target) {
    if(type==='next') {
      if(this.phase!=='transition') return {ok:false,reason:'当前无需切换时间线。',events:[]};
      this.timeline++; this.turn=1; this.resetUnits();
      const events=[{type:'timeline'}]; this.beginTurn(events); return {ok:true,events};
    }
    if(this.phase!=='input') return {ok:false,reason:'请先完成当前时间线。',events:[]};
    const events=[];
    if(type==='move') {
      const path=this.reachable().get(key(target?.x,target?.y));
      if(!path) return {ok:false,reason:'该格不可达；每回合可先移动一次，再攻击一次。',events};
      const action={type:'move',turn:this.turn,path:copy(path),target:copy(target)};
      this.recording.push(action); this.moved=true;
      events.push({type:'move',id:'player',path:copy(path)}); Object.assign(this.player,target);
    } else if(type==='attack') {
      const enemy=this.targets().find(e=>same(e,target));
      if(!enemy) return {ok:false,reason:'只能攻击上下左右相邻的敌人，每回合一次。',events};
      this.acted=true;
      this.recording.push({type:'attack',turn:this.turn,target:position(enemy),damage:this.player.damage});
      this.hit(this.player,enemy,this.player.damage,events);
    } else if(type==='end') {
      const intents=this.known?this.intents:this.enemies.filter(e=>e.hp>0).map(e=>this.ai(e));
      this.currentHistory[this.turn]=copy(intents);
      for(const intent of intents) {
        const e=this.enemies.find(e=>e.id===intent.id&&e.hp>0); if(!e) continue;
        const destination=intent.path.at(-1);
        if(intent.path.length>1) {
          // A fixed enemy owns its recorded destination; basic collision handling.
          if(same(destination,this.player)) {
            const before=intent.path.at(-2), p={x:this.player.x+destination.x-before.x,y:this.player.y+destination.y-before.y};
            if(this.ground(p.x,p.y)&&!this.enemies.some(other=>other.hp>0&&other.id!==e.id&&same(other,p))&&!this.ghosts.some(g=>g.endTurn>=this.turn&&same(g,p))) {
              events.push({type:'move',id:'player',path:[position(this.player),p]}); Object.assign(this.player,p);
            } else { this.player.hp=0; events.push({type:'death',id:'player'}); this.finishTimeline(events); break; }
          }
          events.push({type:'move',id:e.id,path:copy(intent.path)}); Object.assign(e,destination);
        }
        if(intent.target) {
          if(same(this.player,intent.target)) this.hit(e,this.player,e.damage,events);
          else events.push({type:'miss',id:e.id,target:copy(intent.target)});
        }
        if(this.phase!=='input') break;
      }
      if(this.phase==='input') { this.turn++; this.beginTurn(events); }
    } else if(type==='crystallize') {
      if(!this.level.crystallize||this.timeline>=this.level.lives) return {ok:false,reason:'当前无法固化时间线。',events};
      this.finishTimeline(events,'crystallize');
    } else return {ok:false,reason:'未知操作。',events};
    return {ok:true,events};
  }
  ai(enemy) {
    let p=position(enemy); const path=[p];
    for(let n=0;n<enemy.range&&distance(p,this.player)>1;n++) {
      const options=dirs.map(([dx,dy])=>({x:p.x+dx,y:p.y+dy})).filter(c=>this.ground(c.x,c.y)&&!this.enemies.some(e=>e.id!==enemy.id&&e.hp>0&&same(e,c)));
      options.sort((a,b)=>distance(a,this.player)-distance(b,this.player));
      if(!options.length||distance(options[0],this.player)>=distance(p,this.player)) break;
      p=options[0]; path.push(p);
    }
    return {id:enemy.id,path,target:distance(p,this.player)===1?position(this.player):null,damage:enemy.damage};
  }
  hit(source,target,damage,events) {
    events.push({type:'attack',id:source.id,target:position(target),targetId:target.id});
    target.hp=Math.max(0,target.hp-damage);
    events.push({type:'damage',id:target.id,damage,hp:target.hp});
    if(target.hp===0) {
      events.push({type:'death',id:target.id,killer:source.id,finisher:target.team==='enemy'&&source.team!=='enemy'});
      if(target.team==='player') this.finishTimeline(events);
      else if(this.enemies.every(e=>e.hp<=0)) { this.phase='won'; events.push({type:'victory'}); }
    }
  }
  finishTimeline(events,reason='death') {
    if(this.timeline>=this.level.lives) { this.phase='lost'; events.push({type:'defeat'}); return; }
    this.records.push({timeline:this.timeline,endTurn:this.turn,actions:copy(this.recording)});
    this.history={...this.history,...copy(this.currentHistory)};
    this.phase='transition'; events.push({type:'transition',reason});
  }
  beginTurn(events) {
    this.moved=false; this.acted=false;
    for(const record of this.records) {
      if(this.turn>record.endTurn) continue;
      const ghost=this.ghosts.find(g=>g.source===record.timeline);
      for(const action of record.actions.filter(a=>a.turn===this.turn)) {
        if(action.type==='move') { Object.assign(ghost,action.target); events.push({type:'move',id:ghost.id,path:copy(action.path)}); }
        else {
          const target=this.enemies.find(e=>e.hp>0&&same(e,action.target))||(this.player.hp>0&&same(this.player,action.target)?this.player:null);
          if(target) this.hit(ghost,target,action.damage,events);
          else events.push({type:'miss',id:ghost.id,target:copy(action.target)});
        }
        if(this.phase!=='input') return;
      }
    }
  }
  snapshot() {
    return copy({levelId:this.levelId,timeline:this.timeline,turn:this.turn,phase:this.phase,player:this.player,enemies:this.enemies,ghosts:this.ghosts,records:this.records,history:this.history,recording:this.recording,moved:this.moved,acted:this.acted});
  }
}
