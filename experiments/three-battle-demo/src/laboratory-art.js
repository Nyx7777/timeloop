import * as THREE from 'three';

// Visual vocabulary follows the approved laboratory references (03 and 13):
// cold ceramic panels, graphite equipment, blue guidance, cyan specimen light,
// and violet temporal erosion outside the playable grid.
const C = { white:0xcbd7e4, light:0xe1e8ec, dark:0x283847, steel:0x61798d,
  blue:0x487ca7, cyan:0x65ddfa, violet:0x9b62ef, floor:0xb9c8d5 };

function canvasMap(draw,w=512,h=256) {
  const canvas=document.createElement('canvas');canvas.width=w;canvas.height=h;
  draw(canvas.getContext('2d'),w,h);
  const texture=new THREE.CanvasTexture(canvas);texture.colorSpace=THREE.SRGBColorSpace;
  texture.magFilter=THREE.NearestFilter;return texture;
}

function screens() {
  return canvasMap((ctx,w,h)=>{
    ctx.fillStyle='#0b2336';ctx.fillRect(0,0,w,h);
    ctx.strokeStyle='#163d52';ctx.lineWidth=1;
    for(let x=12;x<w;x+=24){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke();}
    for(let y=12;y<h;y+=24){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(w,y);ctx.stroke();}
    ctx.fillStyle='#72d8f6';ctx.font='600 18px monospace';ctx.fillText('BIOCHRON / SYNC',20,28);
    ctx.strokeStyle='#6ce5fa';ctx.lineWidth=3;ctx.beginPath();
    for(let x=20;x<330;x++){const y=115+Math.sin(x*.044)*20+(x%80>65?-35:0);x===20?ctx.moveTo(x,y):ctx.lineTo(x,y);}ctx.stroke();
    ctx.fillStyle='#305a70';ctx.fillRect(360,55,130,3);
    for(let i=0;i<5;i++){ctx.fillStyle=i===4?'#dfb35e':'#5fb4d5';ctx.fillRect(363,78+i*25,35+(i*19)%100,7);}
    ctx.fillStyle='#638d9b';ctx.font='13px monospace';ctx.fillText('TEMPORAL PHASE     00:07:12',20,226);
    ctx.strokeStyle='#528397';ctx.strokeRect(5,5,w-10,h-10);
  });
}

function rackMap() {
  return canvasMap((ctx,w,h)=>{
    ctx.fillStyle='#1c2b38';ctx.fillRect(0,0,w,h);
    for(let i=0;i<6;i++){
      const y=10+i*80;ctx.fillStyle='#3b5061';ctx.fillRect(10,y,w-20,67);
      ctx.fillStyle='#101e2a';ctx.fillRect(17,y+8,w-34,48);
      ctx.fillStyle=i===0?'#52b2df':'#2c536c';ctx.fillRect(28,y+15,70,30);
      for(let k=0;k<7;k++){ctx.fillStyle=k%3===0?'#49cfef':'#287797';ctx.fillRect(128+k*12,y+17,5,18+k%2*8);}
      ctx.fillStyle=i===5?'#f1ba69':'#80edff';ctx.fillRect(225,y+18,9,7);
      ctx.fillStyle='#8294a5';ctx.fillRect(20,y+55,6,3);ctx.fillRect(230,y+55,6,3);
    }
  },256,512);
}

function wallMap(label) {
  return canvasMap((ctx,w,h)=>{
    ctx.fillStyle='#c7d3df';ctx.fillRect(0,0,w,h);
    ctx.fillStyle='#597f9e';ctx.fillRect(0,h*.69,w,h*.15);
    ctx.fillStyle='#395769';ctx.fillRect(0,h*.85,w,5);
    ctx.strokeStyle='#899eae';ctx.lineWidth=2;
    for(let x=0;x<w;x+=128){ctx.strokeRect(x+4,5,120,h-12);ctx.fillStyle='#697d8d';ctx.fillRect(x+11,13,5,5);ctx.fillRect(x+111,h-23,5,5);}
    ctx.fillStyle='#5b7d98';ctx.font='600 47px monospace';ctx.fillText(label,36,110);
    ctx.font='15px monospace';ctx.fillText('TEMPORAL RESEARCH / AUTHORIZED PERSONNEL',38,145);
    ctx.fillStyle='#627f91';for(let n=0;n<12;n++)ctx.fillRect(w-152+n*9,110,4,40-n%3*8);
  },1024,256);
}

function hazardMap() {
  return canvasMap((ctx,w,h)=>{
    ctx.fillStyle='#c0a870';ctx.fillRect(0,0,w,h);ctx.fillStyle='#374552';
    for(let x=-20;x<w;x+=40){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x+20,0);ctx.lineTo(x+50,h);ctx.lineTo(x+30,h);ctx.fill();}
  },256,32);
}

function plateMap(label,sub='CHRONOBIOLOGY DIVISION') {
  return canvasMap((ctx,w,h)=>{
    ctx.fillStyle='#233744';ctx.fillRect(0,0,w,h);ctx.strokeStyle='#5794ad';ctx.lineWidth=3;ctx.strokeRect(5,5,w-10,h-10);
    ctx.fillStyle='#a5e1ec';ctx.font='600 44px monospace';ctx.textAlign='center';ctx.fillText(label,w/2,65);
    ctx.fillStyle='#649bae';ctx.font='14px monospace';ctx.fillText(sub,w/2,98);
  },512,128);
}

export function buildLaboratory(v,level) {
  const box=(w,h,d,x,y,z,m,g=v.world)=>{const mesh=v.box(w,h,d,x,y,z,m,g);mesh.castShadow=w*h*d>.1&&h>.22;return mesh;};
  const mat=(color,extra={})=>v.material(color,{roughness:.66,metalness:.24,...extra});
  const glow=(color=C.cyan)=>mat(color,{emissive:color,emissiveIntensity:.7});
  const group=(x=0,y=0,z=0,rotation=0,parent=v.world)=>{
    const g=new THREE.Group();g.position.set(x,y,z);g.rotation.y=rotation;parent.add(g);return g;
  };
  const art={exterior:group(),walls:[],pulses:[],clockHands:[],glass:[],textures:[]};
  const maps={screen:screens(),rack:rackMap(),hazard:hazardMap(),plate:plateMap('SECTOR 07'),pod:plateMap('STASIS','SUBJECT PRESERVATION')};
  art.textures.push(...Object.values(maps));
  const screenMat=()=>new THREE.MeshBasicMaterial({map:maps.screen,color:0x9cc6db});
  function plane(w,h,x,y,z,material,parent,rotationX=0) {
    const mesh=new THREE.Mesh(new THREE.PlaneGeometry(w,h),material);mesh.position.set(x,y,z);mesh.rotation.x=rotationX;parent.add(mesh);return mesh;
  }
  function cylinder(radius,height,x,y,z,m,g,segments=16) {
    const mesh=new THREE.Mesh(new THREE.CylinderGeometry(radius,radius,height,segments),m);mesh.position.set(x,y,z);mesh.castShadow=height>.25&&!m.transparent;mesh.receiveShadow=true;g.add(mesh);return mesh;
  }
  function fadeable(g,body,minimum=.2) {
    const materials=new Set();g.traverse(o=>{if(o.material){o.material.transparent=true;o.material.userData.baseOpacity=o.material.opacity;materials.add(o.material);}});
    v.obstacles.push({body,materials:[...materials],minimum});
  }
  function label(map,w,h,x,y,z,g) {return plane(w,h,x,y,z,new THREE.MeshBasicMaterial({map}),g);}

  // The tactical deck is physically separate from its non-playable service apron.
  box(11.3,.52,11.3,0,-.47,0,mat(0x2f384e));
  box(11.16,.10,11.16,0,-.16,0,mat(0x748598));
  box(11.04,.10,11.04,0,-.065,0,mat(0xa6b6c5));
  box(8.18,.12,8.18,0,-.03,0,mat(0x304556));
  const boardGeometry=new THREE.BoxGeometry(.973,.12,.973);
  for(let y=0;y<8;y++)for(let x=0;x<8;x++){
    const hole=level.holes.some(p=>p[0]===x&&p[1]===y);
    const material=mat(hole?0x1f1238:(x+y)%2?0xe3eaf5:0xf1f3fa,{map:hole?null:v.textures.floor,roughness:.83,metalness:.08});
    const tile=new THREE.Mesh(boardGeometry,material);tile.position.set(x-3.5,.01,y-3.5);tile.receiveShadow=true;
    tile.userData={kind:'tile',cell:{x,y},base:material.color.clone(),hole};v.world.add(tile);v.tiles.push(tile);
    if(hole){
      const rift=group(x-3.5,.08,y-3.5);
      plane(.98,.98,0,.002,0,new THREE.MeshBasicMaterial({map:v.textures.void,transparent:true,depthWrite:false}),rift,-Math.PI/2);
      [.22,.34,.45].forEach((radius,i)=>{const ring=v.ring(radius,.009,i===2?0x7943b7:0xc199ff,rift);ring.position.y=.012+i*.008;});
      v.rifts.push(rift);
    }
  }
  for(let side=0;side<4;side++){
    const edge=group(0,0,0,side*Math.PI/2);
    box(8.4,.055,.11,0,.035,4.12,mat(C.dark),edge);
    box(8.18,.012,.026,0,.065,4.16,glow(0x63c9f1),edge);
    box(10.8,.045,.06,0,-.27,5.66,mat(0x5d5580),edge);
    for(let n=0;n<8;n++){
      box(.28,.025,.065,n*1.28-4.48,-.36,5.665,glow(n%3?0x576fba:0xab6fe4),edge);
    }
    for(let x=-4;x<=4;x+=2){
      box(1.65,.02,.025,x,.004,4.51,mat(C.blue),edge);
      box(.045,.024,.28,x+.78,.006,4.51,mat(C.blue),edge);
    }
  }
  for(let i=0;i<8;i++){v.coordinate(String.fromCharCode(65+i),i-3.5,4.29);v.coordinate(String(i+1),-4.29,i-3.5);}

  function server(x,z,rotation=0,parent=v.world) {
    const g=group(x,0,z,rotation,parent),shell=mat(C.white),dark=mat(C.dark);
    box(.82,.12,.82,0,.13,0,dark,g);
    const body=box(.69,1.00,.66,0,.66,0,shell,g);
    box(.73,.06,.72,0,1.19,0,mat(C.light),g);
    box(.54,.80,.02,0,.68,.34,dark,g);
    label(maps.rack,.48,.76,0,.68,.355,g);
    box(.045,.84,.032,-.30,.67,.352,mat(C.steel),g);
    box(.045,.84,.032,.30,.67,.352,mat(C.steel),g);
    box(.28,.012,.15,0,1.228,.03,mat(C.steel),g);
    box(.035,.035,.10,.25,1.228,.23,glow(),g);
    fadeable(g,body);return g;
  }
  function pod(x,z,rotation=0,parent=art.exterior,small=false) {
    const g=group(x,0,z,rotation,parent),radius=small?.26:.36,height=small?.68:1.08;
    const body=cylinder(radius+.075,.19,0,.18,0,mat(C.dark),g);
    cylinder(radius+.03,.065,0,.30,0,mat(C.steel),g);
    cylinder(radius,height,0,.34+height/2,0,new THREE.MeshPhysicalMaterial({color:0x8be5f8,roughness:.14,metalness:.1,transparent:true,opacity:.21,depthWrite:false,side:THREE.DoubleSide}),g,24);
    cylinder(radius+.055,.11,0,.37+height,0,mat(C.white),g);
    cylinder(radius-.015,.02,0,.31,0,glow(0x44bfe9),g,24);
    for(const angle of [0,Math.PI*.66,Math.PI*1.33]){
      box(.035,height+.06,.04,Math.sin(angle)*radius,.34+height/2,Math.cos(angle)*radius,mat(C.steel),g);
    }
    const outline=v.ring(radius-.015,.011,C.cyan,g);outline.position.y=.34+height*.8;art.pulses.push(outline.material);
    if(!small){
      const bodyMat=mat(0x38849e,{emissive:0x1a516d,emissiveIntensity:.35});
      const torso=new THREE.Mesh(new THREE.CapsuleGeometry(.10,.23,4,8),bodyMat);torso.position.set(0,.84,0);g.add(torso);
      const head=new THREE.Mesh(new THREE.SphereGeometry(.10,12,8),bodyMat);head.position.set(0,1.08,0);g.add(head);
      box(.045,.22,.06,-.064,.61,0,bodyMat,g);box(.045,.22,.06,.064,.61,0,bodyMat,g);
      label(maps.pod,.43,.105,0,.19,radius+.08,g);
    }
    // Use an invisible full-height proxy for an orthographic occlusion query.
    const proxy=new THREE.Mesh(new THREE.BoxGeometry(radius*2,height+.45,radius*2),new THREE.MeshBasicMaterial({visible:false}));proxy.position.y=(height+.45)/2;g.add(proxy);
    fadeable(g,proxy,.16);return g;
  }
  function consoleDesk(x,z,rotation=0,parent=art.exterior,width=1.18) {
    const g=group(x,0,z,rotation,parent),white=mat(C.white),dark=mat(C.dark);
    const body=box(width,.47,.59,0,.3,0,white,g);
    box(width+.1,.075,.72,0,.57,0,mat(C.light),g);
    box(width*.78,.26,.018,0,.31,.301,dark,g);
    box(width*.36,.06,.023,-width*.18,.30,.32,mat(C.steel),g);
    box(.05,.03,.025,width*.27,.39,.33,glow(),g);
    const monitor=group(-width*.13,.65,-.13,-.03,g);monitor.rotation.x=-.12;
    box(.65,.40,.055,0,.18,0,dark,monitor);
    plane(.575,.32,0,.18,.034,screenMat(),monitor);
    box(.045,.15,.045,0,-.08,0,mat(C.steel),monitor);
    box(.44,.02,.19,-.15,.619,.18,mat(C.steel),g);
    for(let i=0;i<3;i++)cylinder(.035,.10+i*.025,width*.32,.69+i*.013,-.11+i*.10,mat(i===2?0x80b8d4:0x588ca7),g,8);
    fadeable(g,body);return g;
  }
  // Single-cell obstacles retain their exact original logical footprints.
  level.walls.forEach(([x,y],i)=>{
    if(i%3===1)pod(x-3.5,y-3.5,0,v.world,true);
    else if(i%3===2)consoleDesk(x-3.5,y-3.5,0,v.world,.76);
    else server(x-3.5,y-3.5);
  });

  // Peripheral departments tell a readable spatial story: analysis → stasis → recovery.
  consoleDesk(-3.6,-4.94);consoleDesk(-2.15,-4.94);
  pod(2.23,-4.94);pod(3.36,-4.94);
  server(-4.93,-2.7,Math.PI/2,art.exterior);
  consoleDesk(-4.93,.18,Math.PI/2);
  pod(4.94,-2.50,-Math.PI/2);
  consoleDesk(4.94,1.75,-Math.PI/2);
  consoleDesk(-2.8,4.97,Math.PI);

  // Recovery bench: steel base, segmented mattress, restraint straps, bedside display.
  const bed=group(4.91,0,-.13,Math.PI/2,art.exterior);
  const bedBody=box(1.58,.36,.65,0,.24,0,mat(C.dark),bed);
  box(1.8,.085,.76,0,.47,0,mat(C.light),bed);
  box(1.4,.10,.60,.07,.56,0,mat(0x87b0bc),bed);
  box(.32,.15,.58,-.62,.60,0,mat(0xc4dfe3),bed);
  for(const x of [-.24,.45])box(.09,.012,.63,x,.622,0,mat(C.steel),bed);
  for(const z of [-.39,.39])box(1.6,.035,.028,0,.67,z,mat(C.steel),bed);
  fadeable(bed,bedBody);

  // Two low utility cabinets and a canister cart occupy the near service apron.
  for(const x of [.25,1.18]){
    const g=group(x,0,5.04,Math.PI,art.exterior),white=mat(C.white);
    const body=box(.74,.62,.54,0,.35,0,white,g);
    box(.78,.05,.61,0,.69,0,mat(C.light),g);
    for(const y of [.23,.46]){box(.63,.19,.025,0,y,.283,mat(0xacbdcc),g);box(.16,.018,.023,0,y+.05,.30,mat(C.dark),g);}
    fadeable(g,body);
  }
  const cart=group(3.2,0,5.0,0,art.exterior);
  box(.82,.07,.60,0,.18,0,mat(C.dark),cart);
  for(const x of [-.23,.23]){cylinder(.13,.48,x,.45,0,mat(C.white),cart);cylinder(.10,.04,x,.72,0,glow(0x4b9ac1),cart);}
  // A small living specimen echoes the plant in the approved reference.
  const plant=group(-4.94,0,3.32,0,art.exterior);
  cylinder(.21,.28,0,.21,0,mat(0xd1d9d4),plant);cylinder(.18,.015,0,.357,0,mat(0x3a4850),plant);
  for(let i=0;i<5;i++){
    const leaf=new THREE.Mesh(new THREE.SphereGeometry(.13,5,4),mat(i%2?0x779c83:0x567f72));
    leaf.scale.set(.55,1.7,.6);leaf.position.set(Math.sin(i*2.4)*.13,.52,Math.cos(i*2.4)*.13);leaf.rotation.z=Math.sin(i*2.4)*.6;plant.add(leaf);
  }

  // Segmented cutaway walls: the two camera-facing sides disappear automatically.
  for(let side=0;side<4;side++){
    const wall=group(0,0,0,side*Math.PI/2,art.exterior);
    const map=wallMap(side===0?'SECTOR 07':side===1?'ANALYSIS':side===2?'RECOVERY':'STASIS');art.textures.push(map);
    const wallM=mat(C.white),trim=mat(C.dark);
    box(10.8,.13,.18,0,.12,-5.42,trim,wall);
    for(const x of [-3.50,3.50]){
      box(3.65,1.33,.13,x,.85,-5.43,wallM,wall);
      plane(3.61,1.28,x,.86,-5.357,new THREE.MeshBasicMaterial({map,color:0xcddae9}),wall);
      box(3.66,.065,.23,x,1.55,-5.43,mat(C.light),wall);
      box(3.38,.018,.028,x,1.48,-5.30,glow(0x9cdaf1),wall);
    }
    for(const x of [-5.39,-1.63,1.63,5.39])box(.14,1.58,.21,x,.84,-5.4,mat(C.steel),wall);
    // Observation window in the centre, with a recessed bulkhead frame.
    box(3.03,.65,.10,0,.39,-5.42,mat(0xa9bfd1),wall);
    plane(2.98,.68,0,1.03,-5.39,new THREE.MeshBasicMaterial({color:0x70b7d5,transparent:true,opacity:.17,depthWrite:false,side:THREE.DoubleSide}),wall);
    box(3.08,.08,.20,0,1.42,-5.42,trim,wall);
    box(.035,.72,.035,0,1.03,-5.35,mat(C.steel),wall);
    const materials=new Set();wall.traverse(o=>{if(o.material){o.castShadow=false;o.material.transparent=true;o.material.userData.baseOpacity=o.material.opacity;materials.add(o.material);}});
    art.walls.push({group:wall,materials:[...materials],normal:new THREE.Vector3(0,0,-1).applyAxisAngle(new THREE.Vector3(0,1,0),side*Math.PI/2),fade:1});
  }

  // The timing station is the central landmark. It belongs to the back wall cutaway.
  const clockWall=art.walls[0],gate=group(0,0,-5.30,0,clockWall.group);
  box(1.36,1.35,.21,0,.73,0,mat(C.dark),gate);
  box(1.17,1.19,.05,0,.72,.13,mat(0xb9cfdd),gate);
  box(.032,1.12,.018,0,.72,.166,mat(C.steel),gate);
  label(maps.plate,1.42,.355,0,1.57,.15,gate);
  box(.82,.045,.035,0,1.38,.18,glow(),gate);
  const clock=group(0,2.06,.08,0,gate);
  const clockRing=new THREE.Mesh(new THREE.TorusGeometry(.39,.035,8,48),mat(C.steel));clock.add(clockRing);
  const luminous=new THREE.Mesh(new THREE.TorusGeometry(.33,.009,6,48),new THREE.MeshBasicMaterial({color:C.cyan}));clock.add(luminous);
  for(let i=0;i<12;i++){
    const tick=new THREE.Mesh(new THREE.BoxGeometry(.017,i%3?.04:.07,.014),mat(C.light));const a=i*Math.PI/6;tick.position.set(Math.sin(a)*.28,Math.cos(a)*.28,0);tick.rotation.z=-a;clock.add(tick);
  }
  const hand=group(0,0,.026,0,clock);box(.013,.24,.01,0,.10,0,glow(),hand);art.clockHands.push(hand);
  gate.traverse(o=>{if(o.material){o.castShadow=false;o.material.transparent=true;o.material.userData.baseOpacity=o.material.opacity;clockWall.materials.push(o.material);}});

  // Hazard strips mark only service equipment. They never mark walkable danger cells.
  for(const x of [-2.85,2.78]){
    plane(1.88,.12,x,.025,-4.43,new THREE.MeshBasicMaterial({map:maps.hazard}),art.exterior,-Math.PI/2);
  }
  const conduit=new THREE.CatmullRomCurve3([new THREE.Vector3(-5.1,.03,1.1),new THREE.Vector3(-4.55,.03,1.1),new THREE.Vector3(-4.50,.03,2.1),new THREE.Vector3(-5.05,.03,2.2)]);
  art.exterior.add(new THREE.Mesh(new THREE.TubeGeometry(conduit,16,.025,5,false),mat(C.dark)));

  // The laboratory is suspended in a fractured slice of time, with an intact play area.
  for(let i=0;i<32;i++){
    const a=i*2.399, radius=5.7+(i%4)*.15;
    const shard=box(.16+i%3*.10,.10+i%2*.08,.22,Math.cos(a)*radius,-.32+(i%5)*.11,Math.sin(a)*radius,mat(i%4?0x465269:0x8b69b0,{emissive:0x302143,emissiveIntensity:.2}),art.exterior);
    shard.rotation.set(i*.7,i*.3,i*.2);shard.userData.baseY=shard.position.y;v.shards.push(shard);
  }
  for(let side=0;side<4;side++){
    const points=[];for(let i=0;i<19;i++){const x=-5.55+i*.617;points.push(new THREE.Vector3(x,-.51+(i%3)*.055,5.68+(i%2)*.06));}
    const crack=new THREE.Line(new THREE.BufferGeometry().setFromPoints(points),new THREE.LineBasicMaterial({color:0xa27df1,transparent:true,opacity:.75}));crack.rotation.y=side*Math.PI/2;art.exterior.add(crack);
  }
  // Tiny particles are one draw call, not dozens of independent glow sprites.
  const particlePositions=[];for(let i=0;i<80;i++){const a=i*2.399;particlePositions.push(Math.cos(a)*(5.6+i%3*.22),-.25+(i%7)*.12,Math.sin(a)*(5.6+i%3*.22));}
  const particleGeometry=new THREE.BufferGeometry();particleGeometry.setAttribute('position',new THREE.Float32BufferAttribute(particlePositions,3));
  art.particles=new THREE.Points(particleGeometry,new THREE.PointsMaterial({color:0xb59ae2,size:.035,transparent:true,opacity:.55,depthWrite:false}));art.exterior.add(art.particles);
  return art;
}

export function animateLaboratory(art,camera,time) {
  if(!art)return;
  const dt=art.lastTime===undefined?1/60:Math.min(.25,(time-art.lastTime)/1000);art.lastTime=time;
  const blend=1-Math.exp(-12*dt);
  const direction=camera.position.clone().normalize();
  for(const wall of art.walls){
    const target=wall.normal.dot(direction)>.04?0:1;
    wall.fade=THREE.MathUtils.lerp(wall.fade,target,blend);wall.group.visible=wall.fade>.025;
    for(const m of wall.materials)m.opacity=(m.userData.baseOpacity??1)*wall.fade;
  }
  art.pulses.forEach((m,i)=>{m.opacity=.55+Math.sin(time*.0015+i)*.2;});
  art.clockHands.forEach(hand=>{hand.rotation.z=-time*.00012;});
  if(art.particles)art.particles.position.y=Math.sin(time*.00045)*.08;
}
