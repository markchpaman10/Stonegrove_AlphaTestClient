-- Articulated world boss. Gameplay runs only in World:updateCombat (server online).
local N={}
N.def={baseLevel=12,tierMin=1,tierMax=1,melee=12,ranged=12,strength=10,agility=8,health=60,mainSkill='Melee Combat',aggro=220,leash=600,roam=280,speed=23,attackRange=65,rangedRange=180,attackSpeed=8}
N.rest=8;N.windup=1.4;N.recovery=.7;N.respawn=900
local targets=setmetatable({},{__mode='k'})
local searches=setmetatable({},{__mode='k'})
local visual=setmetatable({},{__mode='k'})
local function distance(a,b)return (a.x-b.x)^2+(a.y-b.y)^2 end
local function alive(a)return not a.dead and not a.inactive and (a.hp==nil or a.hp>0)end
function N.load(s)
 s.nagaQueen={};for i=1,8 do local im=love.graphics.newImage('assets/naga_queen_'..i..'.png');im:setFilter('nearest','nearest');s.nagaQueen[i]=im end
end
function N.allowed(w,x,y,pad)
 pad=pad or 75
 if w.isCave or not w.map:isLand(x,y)or require('game.regions').edgeProtected(w.map,x,y,pad)then return false end
 for _,z in ipairs((w.map.authored or{}).townZones or{})do if x>=z.x-pad and x<=z.x+z.w+pad and y>=z.y-pad and y<=z.y+z.h+pad then return false end end
 if not require('game.expansion').clearVillage(w,x,y,pad)then return false end
 for _,p in ipairs(w.paths or{})do if x>=p.x-pad and x<=p.x+p.w+pad and y>=p.y-pad and y<=p.y+p.h+pad then return false end end
 for _,h in ipairs(w.houses or{})do local hx,hy,ww,hh=require('game.houses').bounds(h);if x>=hx-pad and x<=hx+ww+pad and y>=hy-pad and y<=hy+hh+pad then return false end end
 for _,c in ipairs(w.playerCamps or{})do if (x-c.x)^2+(y-c.y)^2<(pad+60)^2 then return false end end
 return not require('game.fences').blocked(w,x,y)
end
local function walkable(w,x,y)
 -- Region transitions are player-owned; keep this replicated entity in its room.
 if x<80 or y<80 or x>w.map.width-80 or y>w.map.height-80 then return false end
 if not w.map:isLand(x,y)then return false end
 for _,h in ipairs(w.houses or{})do local hx,hy,ww,hh=require('game.houses').bounds(h);if x>=hx-30 and x<=hx+ww+30 and y>=hy-30 and y<=hy+hh+30 then return false end end
 for _,c in ipairs(w.playerCamps or{})do if(x-c.x)^2+(y-c.y)^2<80^2 then return false end end
 for _,offset in ipairs({{0,0},{-20,0},{20,0},{0,-20},{0,20}})do if not w.map:isLand(x+offset[1],y+offset[2])or require('game.fences').blocked(w,x+offset[1],y+offset[2])then return false end end
 return true
end
local function candidates(w,p)
 local out={};local seen={};local function add(a)if a and not seen[a]then seen[a]=true;out[#out+1]=a end end
 if w.onlineActors then for _,a in ipairs(w.onlineActors)do add(a.player)end else add(p)end
 for _,e in ipairs(w.enemies or{})do add(e)end
 for _,e in ipairs(w.sheep or{})do add(e)end
 for _,e in ipairs(w.guards or{})do add(e)end
 for _,e in ipairs(w.mercs or{})do if require('game.party').present(w,e)then add(e)end end
 return out
end
function N.breakTrees(w,x,y,r)
 local seen={};local count=0
 -- Query existing spatial buckets, not the entire resource list every frame.
 for oy=-r,r,32 do for ox=-r,r,32 do for _,n in ipairs(require('game.node_index').at(w,x+ox,y+oy))do
  if not seen[n]then seen[n]=true
   if not n.depleted and(n.kind=='tree'or n.kind=='oak'or n.kind=='poplar')and(n.x-x)^2+(n.y-y)^2<=r*r then
    n.hp=0;n.depleted=true;n.stumpSnow=n.snowCovered==true;n.respawnTimer=n.kind=='poplar'and 900 or n.kind=='oak'and 600 or 300;n.shake=.3;count=count+1
    w:addGroundItem(n.kind=='poplar'and'Poplar Logs'or n.kind=='oak'and'Oak Logs'or'Pine Logs',n.x,n.y+10)
    if w.gather and w.gather.node==n then w.gather=nil end
    for _,a in ipairs(w.onlineActors or{})do if a.gather and a.gather.node==n then a.gather=nil end end
    w:emitJuice(n.x,n.y,'wood',10,w:objectJuiceColor(n.kind))
   end
  end
 end end end
 if count>0 then w.navRefresh=0;require('game.audio').play('wood_chop',x,y)end
 return count
end
local function move(w,e,tx,ty,dt)
 local dx,dy=tx-e.x,ty-e.y;local d=math.sqrt(dx*dx+dy*dy);if d<2 then e.nagaMoving=false;return end
 local step=math.min(d,(e.customDefinition and e.customDefinition.speed or N.def.speed)*dt);local nx,ny=e.x+dx/d*step,e.y+dy/d*step
 if walkable(w,nx,ny)then
  N.breakTrees(w,nx,ny,38)
  if not w:enemyBlocked(nx,ny,e)then e.x,e.y=nx,ny;e.nagaMoving=true;e.nagaFacing=dx>0 and -1 or 1;return end
  -- Slide along a hard obstacle; walls, rocks, water and camps remain solid.
  if math.abs(nx-e.x)>.01 and walkable(w,nx,e.y)and not w:enemyBlocked(nx,e.y,e)then e.x=nx;e.nagaMoving=true;return end
  if math.abs(ny-e.y)>.01 and walkable(w,e.x,ny)and not w:enemyBlocked(e.x,ny,e)then e.y=ny;e.nagaMoving=true;return end
 end
 e.nagaMoving=false
end
local function hurt(w,e,t,amount,magic)
 if not alive(t)then return end
 local isPlayer=t==w.playerRef or t.onlineId~=nil
 if isPlayer or t.equipment then
  local eq=t.equipment or t.gear or{};amount=math.max(1,amount-math.floor(require('game.combat').defense(eq)/3))
  if isPlayer and not magic then local sk;for _,a in ipairs(w.onlineActors or{})do if a.player==t then sk=a.skills;break end end;sk=sk or w.nagaPlayerSkills;amount=require('game.religion').physicalTaken(sk,amount)end
 else amount=t.hp or 5 end -- Other creatures are killed by a successful boss strike.
 if amount>0 then t.damageSerial=(t.damageSerial or 0)+1;t.lastDamageSource="Naga Queen"end;t.hp=math.max(0,(t.hp or 5)-amount);t.hitFlash=.15;w:addPopup(t.x,t.y-18,math.floor(amount*10+.5)/10,'damage')
 if t.hp<=0 and not isPlayer then t.dead=true;t.aggro=false;t.state='dead';t.respawnTimer=t.kind=='nagaQueen'and N.respawn or 300;t.skinned=false
  if not t.kind and t.homeX then t.nagaKilled=true end
  require('game.audio').death(t.kind or'creature',t.x,t.y)
 end
end
function N.strike(w,e,p)
 if e.nagaAttack=='magic'then
  local spell=require('game.magic_system').spells['Water Spell Page'];local dx,dy=e.nagaAimX-e.x,e.nagaAimY-(e.y-35);local d=math.max(1,math.sqrt(dx*dx+dy*dy))
  w.bossShots=w.bossShots or{};w.bossShots[#w.bossShots+1]={x=e.x,y=e.y-35,vx=dx/d*220,vy=dy/d*220,time=d/220,row=spell.row,spellName=spell.name,damage=spell.damage+math.floor((e.level or 12)/10),sourceId=e.netId,sourceX=e.x,sourceY=e.y,nagaSpell=true}
  require('game.audio').play('water_spell',e.x,e.y);return
 end
 local magic=e.nagaAttack=='magic';local x,y=e.nagaAimX,e.nagaAimY;local r=magic and 28 or(e.nagaAttack=='tail'and 85 or 48)
 if e.nagaAttack=='tail'then x,y=e.x,e.y end
 local melee=(e.stats and e.stats.melee)or 12;local ranged=(e.stats and e.stats.ranged)or 12
 local damage=magic and math.max(1,math.floor(ranged*.75))or e.nagaAttack=='tail'and math.max(1,math.floor(melee*.85))or melee
 for _,t in ipairs(candidates(w,p))do if t~=e and alive(t)and(t.x-x)^2+(t.y-y)^2<=r*r then hurt(w,e,t,damage,magic)end end
 N.breakTrees(w,x,y,r)
 if magic then w.magicEffects[#w.magicEffects+1]={x=x,y=y,row=2,t=0,duration=.7};require('game.audio').play('water_spell',x,y)
 else require('game.audio').play('swing',e.x,e.y)end
end
function N.updateSpells(w,dt,p)
 for i=#(w.bossShots or{}),1,-1 do local q=w.bossShots[i];if q.nagaSpell then
  local travel=math.min(dt,math.max(0,q.time));local dx,dy=q.vx*travel,q.vy*travel;local steps=math.max(1,math.ceil(math.sqrt(dx*dx+dy*dy)/4));local hit=false
  for step=1,steps do
   local x,y=q.x+dx/steps,q.y+dy/steps;q.x,q.y=x,y
   if w:projectileBlocked(x,y)then hit=true;break end
   for _,t in ipairs(candidates(w,p))do
    if alive(t)and not(t.kind=='nagaQueen'and(t.x-(q.sourceX or 0))^2+(t.y-(q.sourceY or 0))^2<.01^2)and(t.x-x)^2+(t.y-y)^2<=((t.hitRadius or 10)+5)^2 then
     hurt(w,nil,t,q.damage,true);hit=true;break
    end
   end
   if hit then break end
  end
  q.time=q.time-dt
  if hit or q.time<=0 then w.magicEffects[#w.magicEffects+1]={x=q.x,y=q.y,row=q.row,t=0,duration=.7};require('game.audio').play('magic_impact',q.x,q.y);table.remove(w.bossShots,i)end
 end end
end
function N.onDeath(w,e)
 if e.nagaLootDropped then return end;e.nagaLootDropped=true
 local drops={};for i=1,5 do drops[#drops+1]='Raw Cave Snake Hide'end
 if math.random(1,4)==1 then local potions={'Health Tube','Health Flask','Stamina Potion (3/3)','Antipoison Tube'};drops[#drops+1]=potions[math.random(#potions)]end
 for i,item in ipairs(drops)do w:dropScattered(item,e.x,e.y,i,#drops)end
end
function N.turn(w,e,dt,p,skills)
 if e.kind~='nagaQueen'then return false end
 e.hitRadius=36;e.customName=e.customName or'Naga Queen';w.nagaPlayerSkills=skills
 e.nagaPhase=e.nagaPhase or'rest';e.nagaTimer=math.max(0,(e.nagaTimer or N.rest)-dt);e.nagaMoving=false
 if e.nagaPhase=='windup'then
  e.state='combat';if e.nagaTimer<=0 then N.strike(w,e,p);e.nagaPhase='recover';e.nagaTimer=N.recovery end
  return true
 elseif e.nagaPhase=='recover'then
  e.state='combat';if e.nagaTimer<=0 then e.nagaPhase='rest';e.nagaTimer=N.rest;e.state='rest' end;return true
 end
 searches[e]=(searches[e]or 0)-dt;local t=targets[e]
 if (t and(not alive(t)or distance(e,t)>240^2))or searches[e]<=0 then
  local best;targets[e]=nil;searches[e]=.5
  for _,a in ipairs(candidates(w,p))do if a~=e and alive(a)then local d=distance(e,a);if d<220^2 and(not best or d<best)then targets[e]=a;best=d end end end;t=targets[e]
 end
 if t then
  e.aggro=true;w.targetedEnemy=e;e.nagaFacing=t.x>e.x and -1 or 1
  if e.nagaTimer>0 then e.state='rest';return true end
  local cycle=(e.nagaCycle or 0)%3+1;local range=cycle==3 and 180 or 65
  if distance(e,t)>range^2 then e.state='chase';move(w,e,t.x,t.y,dt)
  else e.nagaCycle=cycle;e.nagaAttack=({'head','tail','magic'})[cycle];e.nagaPhase='windup';e.nagaTimer=N.windup;e.nagaAimX=t.x;e.nagaAimY=t.y;e.state='combat';w:addPopup(e.x,e.y-65,cycle==1 and'HEAD BUTT' or cycle==2 and'TAIL SWING'or'WATER BOLT','miss')end
 else
  e.aggro=false;e.state='roam';e.roamTimer=(e.roamTimer or 0)-dt
  if e.roamTimer<=0 then local a=math.random()*math.pi*2;e.roamX=e.spawnX+math.cos(a)*280;e.roamY=e.spawnY+math.sin(a)*280;e.roamTimer=8 end
  move(w,e,e.roamX or e.x,e.roamY or e.y,dt)
 end
 if e.nagaMoving then local face=e.nagaFacing or 1;N.breakTrees(w,e.x,e.y,40);N.breakTrees(w,e.x+face*48,e.y,26);N.breakTrees(w,e.x-face*20,e.y-42,24)end
 return true
end
-- Each child's anchor is computed from its parent's transformed attachment point.
-- Uploaded PNGs remain unchanged; image 7 is reference-only.
function N.draw(s,e)
 local im=s.nagaQueen;if not im then return end
 local g=love.graphics;local clock=love.timer.getTime();local memo=visual[e]
 if not memo or memo.timer~=e.nagaTimer or memo.phase~=e.nagaPhase then memo={timer=e.nagaTimer,phase=e.nagaPhase,at=clock};visual[e]=memo end
 local remaining=math.max(0,(e.nagaTimer or 0)-(clock-memo.at));local wind=e.nagaPhase=='windup'and math.min(1,1-remaining/N.windup)or 0
 local hit=e.nagaPhase=='recover'and math.max(0,remaining/N.recovery)or 0
 local wave=math.sin(clock*2);local slither=e.nagaMoving and math.sin(clock*6)*.12 or wave*.025
 local tail=e.nagaAttack=='tail'and(-wind*.6+hit*1.15)or 0;local head=e.nagaAttack=='head'and(wind*.15-hit*.35)or 0
 g.push('all');g.setColor(0,0,0,.28);g.ellipse('fill',e.x+12,e.y+2,48,12);g.translate(e.x,e.y);g.scale((e.nagaFacing or 1)*1.6,e.dead and .48 or 1.6)
 if e.dead then wave=0;slither=0;tail=0;head=0;g.setColor(.5,.5,.5,.75)else g.setColor(1,(e.hitFlash or 0)>0 and .55 or 1,(e.hitFlash or 0)>0 and .55 or 1)end
 local function bone(image,x,y,ox,oy,a,scale,ex,ey)
  g.draw(image,x,y,a,scale,scale,ox,oy);local dx,dy=(ex-ox)*scale,(ey-oy)*scale;return x+dx*math.cos(a)-dy*math.sin(a),y+dx*math.sin(a)+dy*math.cos(a)
 end
 local bx,by=0,-8+wave*.35;local ba=wave*.015+head*.25
 local bodyScale=1+wave*.015
 local tx,ty=bx+(-6*math.cos(ba)-2*math.sin(ba))*bodyScale,by+(-6*math.sin(ba)+2*math.cos(ba))*bodyScale
 local tipx,tipy=bone(im[5],tx,ty,5,14,slither+tail,1,27,22)
 bone(im[6],tipx,tipy,5,18,slither*1.6+tail*1.35,1,28,20)
 local nx,ny=bone(im[4],bx,by,16,27,ba,bodyScale,16,10)
 local hx,hy=bone(im[3],nx,ny,24,14,.8+slither+head,.85,12,18)
 hx,hy=bone(im[2],hx,hy,24,14,.7+slither*.8+head,.8,10,20)
 local open=not e.dead and(e.nagaPhase=='windup'or e.nagaPhase=='recover');bone(im[open and 8 or 1],hx,hy,open and 21 or 24,22,slither*.25+head,1+hit*.05,24,22)
 g.pop()
 if not e.dead and e.nagaPhase=='windup'then
  g.push('all');g.setColor(e.nagaAttack=='magic'and .25 or 1,e.nagaAttack=='magic'and .65 or .4,1,.45)
  if e.nagaAttack=='tail'then g.circle('line',e.x,e.y,85)else g.circle('line',e.nagaAimX or e.x,e.nagaAimY or e.y,e.nagaAttack=='magic'and 28 or 48)end;g.pop()
 end
end
return N
