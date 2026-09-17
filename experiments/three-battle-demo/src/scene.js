import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { key } from './battle.js';
import { buildLaboratory, animateLaboratory } from './laboratory-art.js';

const colors={player:0x1baba1,ghost:0x9a6ce5,enemy:0xec7464};
const at=(p,height=0.15)=>new THREE.Vector3(p.x-3.5,height,p.y-3.5);
const asset = name => `${import.meta.env.BASE_URL}assets/${name}_idle.png`;

export class BattleScene {
  constructor(container,{onCell,onSelect,onHover}) {
    this.container=container; this.onCell=onCell; this.onSelect=onSelect; this.onHover=onHover;
    this.renderer=new THREE.WebGLRenderer({antialias:true,alpha:true,powerPreference:'high-performance'});
    this.renderer.setPixelRatio(Math.min(devicePixelRatio,2));
    this.renderer.shadowMap.enabled=true; this.renderer.shadowMap.autoUpdate=false; this.renderer.shadowMap.type=THREE.PCFSoftShadowMap;
    this.renderer.outputColorSpace=THREE.SRGBColorSpace;
    this.renderer.toneMapping=THREE.ACESFilmicToneMapping; this.renderer.toneMappingExposure=1.08;
    container.prepend(this.renderer.domElement);
    this.renderer.domElement.setAttribute('aria-label','可旋转的三维战场，拖动旋转，点击格子移动或攻击');
    this.scene=new THREE.Scene(); this.scene.fog=new THREE.Fog(0xeaf0ed,25,55);
    this.camera=new THREE.OrthographicCamera(-7,7,7,-7,.1,100);
    this.controls=new OrbitControls(this.camera,this.renderer.domElement);
    this.controls.enableDamping=true; this.controls.dampingFactor=.09;
    this.controls.minPolarAngle=.12; this.controls.maxPolarAngle=1.13;
    this.controls.minZoom=.7; this.controls.maxZoom=2.1;
    this.controls.enablePan=false; this.controls.rotateSpeed=.65;
    this.controls.mouseButtons={LEFT:THREE.MOUSE.ROTATE,MIDDLE:THREE.MOUSE.DOLLY,RIGHT:THREE.MOUSE.ROTATE};
    this.controls.touches={ONE:THREE.TOUCH.ROTATE,TWO:THREE.TOUCH.DOLLY_PAN};
    this.scene.add(new THREE.HemisphereLight(0xe7f4ff,0x59617d,1.9));
    const sun=new THREE.DirectionalLight(0xf3f7ff,2.6); sun.position.set(-6,14,6); sun.castShadow=true;
    sun.shadow.mapSize.set(2048,2048); Object.assign(sun.shadow.camera,{left:-9,right:9,top:9,bottom:-9,near:1,far:40});
    sun.shadow.normalBias=.035; sun.shadow.bias=-.0002; this.scene.add(sun);
    const fill=new THREE.DirectionalLight(0x91b9ed,1.3); fill.position.set(7,5,-7); this.scene.add(fill);
    this.world=new THREE.Group(); this.scene.add(this.world);
    this.units=new Map(); this.tiles=[]; this.obstacles=[]; this.rifts=[]; this.shards=[];
    this.ray=new THREE.Raycaster(); this.pointer=new THREE.Vector2(); this.selected='player';
    this.detailedEnvironment=true;this.hover=null; this.locked=false; this.tweens=[];
    this.labels=document.createElement('div'); this.labels.className='world-labels'; container.append(this.labels);
    this.observer=new ResizeObserver(()=>this.resize()); this.observer.observe(container);
    const canvas=this.renderer.domElement;
    canvas.addEventListener('contextmenu',e=>e.preventDefault());
    this.activePointers=new Set();
    canvas.addEventListener('pointerdown',e=>{
      this.activePointers.add(e.pointerId);
      if(this.activePointers.size===1) this.down={x:e.clientX,y:e.clientY,moved:false,multi:false};
      else if(this.down) this.down.multi=true;
    });
    canvas.addEventListener('pointermove',e=>{
      if(this.down&&Math.hypot(e.clientX-this.down.x,e.clientY-this.down.y)>6) this.down.moved=true;
      const picked=this.pick(e);
      const next=picked?.kind==='tile'?picked.cell:null;
      if(JSON.stringify(this.hover)!==JSON.stringify(next)) { this.hover=next; this.onHover(next); }
      canvas.style.cursor=this.down?.moved?'grabbing':picked?'pointer':'grab';
    });
    canvas.addEventListener('pointerup',e=>{
      this.activePointers.delete(e.pointerId);
      if(!this.locked&&this.down&&!this.down.moved&&!this.down.multi&&e.button===0) {
        const picked=this.pick(e);
        if(picked?.kind==='unit') this.onSelect(picked.id);
        if(picked?.kind==='tile') this.onCell(picked.cell);
      }
      if(!this.activePointers.size) this.down=null;
    });
    canvas.addEventListener('pointercancel',()=>{this.down=null;this.activePointers.clear();});
    canvas.addEventListener('pointerleave',()=>{this.hover=null;this.onHover(null);});
    this.resetCamera(); this.resize();
    this.renderer.setAnimationLoop(time=>this.frame(time));
  }
  async load() {
    const loader=new THREE.TextureLoader(); this.textures={};
    await Promise.all(['player','ghost','guard'].map(async name=>{
      const texture=await loader.loadAsync(asset(name)); texture.colorSpace=THREE.SRGBColorSpace;
      texture.magFilter=THREE.NearestFilter; texture.minFilter=THREE.LinearMipmapLinearFilter;
      this.textures[name]=texture;
    }));
    await Promise.all([['floor','lab_floor_tile'],['void','time_void_tile']].map(async ([key,name])=>{
      const texture=await loader.loadAsync(`${import.meta.env.BASE_URL}assets/${name}.png`);
      texture.colorSpace=THREE.SRGBColorSpace;texture.magFilter=THREE.NearestFilter;
      texture.anisotropy=Math.min(4,this.renderer.capabilities.getMaxAnisotropy());this.textures[key]=texture;
    }));
  }
  material(color,extra={}) { return new THREE.MeshStandardMaterial({color,roughness:.65,metalness:.12,...extra}); }
  box(w,h,d,x,y,z,material,parent=this.world) {
    const mesh=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),material); mesh.position.set(x,y,z);
    mesh.castShadow=true; mesh.receiveShadow=true; parent.add(mesh); return mesh;
  }
  ring(radius,tube,color,parent) {
    const mesh=new THREE.Mesh(new THREE.TorusGeometry(radius,tube,8,64),new THREE.MeshBasicMaterial({color,transparent:true,opacity:.85}));
    mesh.rotation.x=-Math.PI/2; parent.add(mesh); return mesh;
  }
  clearGroup(group) {
    group.traverse(o=>{o.geometry?.dispose();if(o.material) (Array.isArray(o.material)?o.material:[o.material]).forEach(m=>{if(m.userData.ownedMap)m.map?.dispose();m.dispose();});});
    group.clear();
  }
  build(level) {
    this.labArt?.textures.forEach(texture=>texture.dispose());
    this.clearGroup(this.world); this.units.clear(); this.labels.replaceChildren();
    this.tiles=[];this.obstacles=[];this.rifts=[];this.shards=[];this.level=level;
    this.labArt=buildLaboratory(this,level);this.labArt.exterior.visible=this.detailedEnvironment;this.renderer.shadowMap.needsUpdate=true;
    this.overlays=new THREE.Group();this.world.add(this.overlays);
    this.unitGroup=new THREE.Group();this.world.add(this.unitGroup);
    this.hoverMesh=new THREE.Mesh(new THREE.PlaneGeometry(.92,.92),new THREE.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:.35,depthWrite:false}));
    this.hoverMesh.rotation.x=-Math.PI/2;this.hoverMesh.visible=false;this.world.add(this.hoverMesh);
  }
  toggleEnvironment() {this.detailedEnvironment=!this.detailedEnvironment;this.labArt.exterior.visible=this.detailedEnvironment;this.renderer.shadowMap.needsUpdate=true;return this.detailedEnvironment;}
  coordinate(text,x,z) {
    const canvas=document.createElement('canvas');canvas.width=128;canvas.height=128;
    const ctx=canvas.getContext('2d');ctx.fillStyle='#567387';ctx.font='500 64px sans-serif';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(text,64,64);
    const map=new THREE.CanvasTexture(canvas);map.colorSpace=THREE.SRGBColorSpace;
    const mat=new THREE.MeshBasicMaterial({map,transparent:true,depthWrite:false});mat.userData.ownedMap=true;
    const mesh=new THREE.Mesh(new THREE.PlaneGeometry(.32,.32),mat);mesh.rotation.x=-Math.PI/2;mesh.position.set(x,.07,z);this.world.add(mesh);
  }
  createUnit(unit) {
    const g=new THREE.Group();g.position.copy(at(unit,.12));this.unitGroup.add(g);
    const base=new THREE.Mesh(new THREE.CylinderGeometry(.3,.35,.07,32),this.material(unit.team==='ghost'?0x76609d:0x718a83));base.position.y=.01;g.add(base);
    const ring=this.ring(.37,.024,colors[unit.team],g);ring.position.y=.015;
    const tex=this.textures[unit.team==='enemy'?'guard':unit.team];
    const material=new THREE.MeshBasicMaterial({map:tex,transparent:true,alphaTest:.12,side:THREE.DoubleSide,opacity:unit.team==='ghost'?.76:1});
    const sprite=new THREE.Mesh(new THREE.PlaneGeometry(.92,1.227).translate(0,.6135,0),material);sprite.position.y=.06;sprite.userData={kind:'unit',id:unit.id};g.add(sprite);
    const label=document.createElement('button');label.className=`unit-label ${unit.team}`;label.setAttribute('aria-label',`查看${unit.name}`);
    label.addEventListener('click',e=>{e.stopPropagation();if(!this.locked)this.onSelect(unit.id);});this.labels.append(label);
    const view={group:g,sprite,ring,label,unit:{...unit},dead:false};this.units.set(unit.id,view);return view;
  }
  sync(units,selected=this.selected) {
    this.selected=selected;const ids=new Set(units.filter(u=>u.hp>0).map(u=>u.id));
    for(const [id,view] of this.units) if(!ids.has(id)) {this.clearGroup(view.group);view.group.removeFromParent();view.label.remove();this.units.delete(id);}
    for(const u of units.filter(u=>u.hp>0)) {
      const view=this.units.get(u.id)||this.createUnit(u);view.unit={...u};view.dead=false;view.group.visible=true;view.group.position.copy(at(u,.12));
      view.sprite.material.opacity=u.team==='ghost'?.76:1;
      view.label.textContent=u.team==='ghost'?`T${u.source} · 重演`:`${u.team==='player'?'07':u.id.replace('enemy','E')}　${u.hp}/${u.maxHp}`;
      view.label.classList.toggle('selected',u.id===selected);
    }
  }
  setTactics({reachable,targets,intents,selected}) {
    this.selected=selected;this.moveCells=reachable;this.labels.dataset.move=String(reachable.size>0);this.clearGroup(this.overlays);
    const targetIds=new Set(targets.map(u=>key(u.x,u.y)));
    for(const tile of this.tiles) {
      const p=tile.userData.cell,k=key(p.x,p.y);tile.material.color.copy(tile.userData.base);tile.material.emissive.setHex(0x000000);
      if(reachable.has(k)) {tile.material.color.setHex(0x9ddbc9);tile.material.emissive.setHex(0x082019);}
      if(targetIds.has(k)) {tile.material.color.setHex(0xeeb7a5);tile.material.emissive.setHex(0x281009);}
    }
    for(const intent of intents) {
      const opacity=selected.startsWith('enemy')&&selected!==intent.id ? .18:.85;
      const points=intent.path.map(p=>at(p,.16));
      if(points.length>1) {
        const line=new THREE.Line(new THREE.BufferGeometry().setFromPoints(points),new THREE.LineDashedMaterial({color:0xd09837,dashSize:.12,gapSize:.07,transparent:true,opacity}));line.computeLineDistances();this.overlays.add(line);
        this.marker(intent.path.at(-1),0xe6ae48,opacity);
      }
      if(intent.target) {
        const line=new THREE.Line(new THREE.BufferGeometry().setFromPoints([at(intent.path.at(-1),.19),at(intent.target,.19)]),new THREE.LineBasicMaterial({color:0xe56868,transparent:true,opacity}));this.overlays.add(line);
        this.marker(intent.target,0xe56868,opacity*.7);
      }
    }
  }
  marker(p,color,opacity) {
    const m=new THREE.Mesh(new THREE.PlaneGeometry(.72,.72),new THREE.MeshBasicMaterial({color,transparent:true,opacity:opacity*.35,side:THREE.DoubleSide,depthWrite:false}));
    m.rotation.x=-Math.PI/2;m.position.copy(at(p,.14));this.overlays.add(m);
  }
  resetCamera(top=false) {const damping=this.controls.enableDamping;this.controls.enableDamping=false;this.controls.update();this.camera.position.set(top ? .01 : 10,top ? 20 : 15,top ? .3 : 12);this.camera.zoom=1;this.camera.updateProjectionMatrix();this.controls.target.set(0,0,0);this.controls.update();this.controls.enableDamping=damping;this.camera.updateMatrixWorld();}
  rotate(direction) {const offset=this.camera.position.clone().sub(this.controls.target);offset.applyAxisAngle(new THREE.Vector3(0,1,0),direction*Math.PI/4);this.camera.position.copy(offset.add(this.controls.target));this.controls.update();}
  resize() {
    const {width,height}=this.container.getBoundingClientRect();if(!width||!height)return;
    this.renderer.setSize(width,height);const aspect=width/height;
    const half=Math.max(7.05,8.2/aspect);
    this.camera.left=-half*aspect;this.camera.right=half*aspect;this.camera.top=half;this.camera.bottom=-half;this.camera.updateProjectionMatrix();
  }
  project(p) {this.camera.updateMatrixWorld();const v=p.clone().project(this.camera);const {width,height}=this.container.getBoundingClientRect();return {x:(v.x+1)*width/2,y:(1-v.y)*height/2};}
  cellScreen(p) {return this.project(at(p,.12));}
  pick(e) { this.scene.updateMatrixWorld(true); this.camera.updateMatrixWorld();
    const rect=this.renderer.domElement.getBoundingClientRect();this.pointer.set((e.clientX-rect.left)/rect.width*2-1,-(e.clientY-rect.top)/rect.height*2+1);
    this.ray.setFromCamera(this.pointer,this.camera);
    const objects=[...this.units.values()].filter(v=>!v.dead&&v.group.visible).map(v=>v.sprite).concat(this.tiles);
    const hits=this.ray.intersectObjects(objects,false);
    const tileHit=hits.find(hit=>hit.object.userData.kind==='tile');
    if(tileHit){const p=tileHit.object.userData.cell;if(this.moveCells?.has(key(p.x,p.y)))return tileHit.object.userData;}
    return hits[0]?.object.userData;
  }
  animate(duration,update) {return new Promise(resolve=>this.tweens.push({start:performance.now(),duration,update,resolve}));}
  async move(id,path,speed=1) {
    const view=this.units.get(id);if(!view)return;
    for(let i=1;i<path.length;i++) {
      const from=at(path[i-1],.12),to=at(path[i],.12);
      await this.animate(240/speed,t=>{view.group.position.lerpVectors(from,to,t);view.group.position.y+=Math.sin(t*Math.PI)*.10;});
    }
  }
  async attack(id,target,speed=1) {
    const view=this.units.get(id);if(!view)return;
    const from=view.group.position.clone(),direction=at(target,.12).sub(from).normalize().multiplyScalar(.27);
    await this.animate(230/speed,t=>view.group.position.copy(from).addScaledVector(direction,Math.sin(t*Math.PI)));
    view.group.position.copy(from);
  }
  async damage(id,amount,hp,speed=1) {
    const view=this.units.get(id);if(!view)return;
    const float=document.createElement('span');float.className='damage-number';float.textContent=`−${amount}`;this.labels.append(float);
    const spot=this.project(view.group.position.clone().add(new THREE.Vector3(0,1.4,0)));float.style.left=`${spot.x}px`;float.style.top=`${spot.y}px`;
    view.label.textContent=`${id==='player'?'07':id.replace('enemy','E')}　${hp}/${view.unit.maxHp}`;
    await this.animate(320/speed,t=>{view.sprite.material.color.setRGB(1,1-Math.sin(t*Math.PI)*.65,1-Math.sin(t*Math.PI)*.65);});
    view.sprite.material.color.setHex(0xffffff);float.remove();
  }
  async death(id,speed=1) {
    const view=this.units.get(id);if(!view)return;
    await this.animate(340/speed,t=>{view.sprite.material.opacity=1-t;view.sprite.position.y=.06+t*.35;});
    view.dead=true;view.group.visible=false;view.label.hidden=true;
  }
  frame(time) {
    this.controls.update();
    for(const tween of [...this.tweens]) {
      const t=Math.min(1,(time-tween.start)/tween.duration);tween.update(t);
      if(t>=1){this.tweens.splice(this.tweens.indexOf(tween),1);tween.resolve();}
    }
    const cam=this.camera.position;
    for(const [id,v] of this.units) {
      v.sprite.quaternion.copy(this.camera.quaternion);
      v.ring.material.opacity=id===this.selected? .8+Math.sin(time*.004)*.2:.45;
      v.ring.scale.setScalar(id===this.selected?1.12:1);
      const spot=this.project(v.group.position); spot.y-=1.4*this.container.clientHeight/(this.camera.top-this.camera.bottom)*this.camera.zoom;
      v.label.style.transform=`translate(${spot.x}px,${spot.y}px) translate(-50%,-50%)`;
      v.label.hidden=v.dead||spot.x<0||spot.y<0||spot.x>this.container.clientWidth||spot.y>this.container.clientHeight;
    }
    for(const o of this.obstacles) {
      let fade=false;
      for(const v of this.units.values()) {
        if(v.dead)continue;
        const target=v.group.position.clone().add(new THREE.Vector3(0,.6,0));
        const projected=target.clone().project(this.camera);this.ray.setFromCamera(new THREE.Vector2(projected.x,projected.y),this.camera);const rayDistance=this.ray.ray.origin.distanceTo(target);
        const hit=this.ray.intersectObject(o.body,false)[0];if(hit&&hit.distance<rayDistance){fade=true;break;}
      }
      for(const mat of o.materials)mat.opacity=THREE.MathUtils.lerp(mat.opacity,(mat.userData.baseOpacity??1)*(fade?(o.minimum??.22):1),.1);
    }
    this.rifts.forEach((g,i)=>{g.rotation.y=time*.0003*(i%2?1:-1);g.children.slice(1).forEach((r,j)=>r.material.opacity=.6+Math.sin(time*.002+j)*.25);});
    this.shards.forEach((s,i)=>{s.position.y=s.userData.baseY+Math.sin(time*.0006+i)*.15;s.rotation.y=time*.0002+i;s.rotation.z=Math.sin(time*.0003+i)*.3;});
    if(this.hoverMesh) {this.hoverMesh.visible=Boolean(this.hover)&&!this.locked;if(this.hover)this.hoverMesh.position.copy(at(this.hover,.16));}
    animateLaboratory(this.labArt,this.camera,time);
    this.renderer.render(this.scene,this.camera);
  }
}
