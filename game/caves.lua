local C={}
local Map={};Map.__index=Map
local function distance(a,b)return (a.x-b.x)^2+(a.y-b.y)^2 end
function Map:landAt(x,y)return self.mask[y] and self.mask[y][x] or false end
function Map:isLand(x,y)return self:landAt(math.floor(x/16)+1,math.floor(y/16)+1) end
function Map:isBeachCell()return false end
function Map:isBeachWaterCell()return false end
function Map:isShoreCell()return false end
function Map:draw()
 if not self.batch then
  local image=love.graphics.newImage('assets/cave_tileset.png');image:setFilter('nearest','nearest')
  local batch=love.graphics.newSpriteBatch(image,self.cols*self.rows*4,'static')
  local function q(x,y,w,h)return love.graphics.newQuad(x,y,w,h,image:getDimensions())end
  local parts={}
  for i,d in ipairs({{-1,-1},{1,-1},{-1,1},{1,1}})do
   parts[i]={dx=d[1],dy=d[2],outer=q(d[1]<0 and 96 or 120,d[2]<0 and 0 or 24,24,24),horizontal=q(112,d[2]<0 and 0 or 24,8,24),vertical=q(d[1]<0 and 96 or 120,16,24,8),inner=q(d[1]<0 and 168 or 156,d[2]<0 and 24 or 12,12,12),full=q(112,16,16,16)}
  end
  for y=1,self.rows do for x=1,self.cols do if not self:landAt(x,y) then
   for _,p in ipairs(parts)do local kind=require('game.terrain').kind(not self:landAt(x+p.dx,y),not self:landAt(x,y+p.dy),not self:landAt(x+p.dx,y+p.dy));local quad=p[kind];local _,_,w,h=quad:getViewport();batch:add(quad,(x-1)*16+(p.dx>0 and 8 or 0),(y-1)*16+(p.dy>0 and 8 or 0),0,8/w,8/h)end
  end end end
  self.batch=batch
 end
 love.graphics.setColor(90/255,105/255,136/255);love.graphics.rectangle('fill',0,0,self.width,self.height)
 love.graphics.setColor(1,1,1);love.graphics.draw(self.batch)
end
function C.clearResources(w,p)
 require("game.node_index").invalidate(w)
 for i=#w.nodes,1,-1 do if distance(w.nodes[i],p)<64^2 then table.remove(w.nodes,i)end end
end
function C.replenish(w)
 if w.isCave then return end
 w.caveEntrances=w.caveEntrances or{};w.caveInstances=w.caveInstances or{}
 local count=0;local nextId=w._nextCaveId or 1
 for _,e in ipairs(w.caveEntrances)do nextId=math.max(nextId,(e.id or 0)+1);if not e.authored and not e.questSpawnKey then count=count+1 end end
 local options=(w.map.authored or{}).procedural or{};local maximum=math.max(0,math.min(20,tonumber(options.caveMax)or 3));if options.caves==false then maximum=0 end
 for i=count+1,maximum do for attempt=1,5000 do
  local p={id=nextId,x=math.random(200,w.map.width-200),y=math.random(200,w.map.height-200),seed=math.random(1,1000000000)}
  p.zone=require('game.zones').at(w.map,p.x,p.y);p.levelMin,p.levelMax=require('game.level_zones').encounterRange(w.map,p.x,p.y)
  local clear=not require('game.authored_world').protected(w,p.x,p.y,80)and require('game.expansion').clearVillage(w,p.x,p.y,180)
  for _,camp in ipairs(w.goblinCamps or{})do if distance(camp,p)<260^2 then clear=false end end
  for _,entry in ipairs(w.caveEntrances)do if distance(entry,p)<450^2 then clear=false end end
  local nodes=w.nodes;w.nodes={};require('game.node_index').invalidate(w)
  if clear then for dx=-40,40,20 do for dy=-30,50,20 do local x,y=p.x+dx,p.y+dy;if not w.map:isLand(x,y)or w:playerBlocked(x,y)then clear=false end end end end
  w.nodes=nodes;require('game.node_index').invalidate(w)
  if clear then C.clearResources(w,p);w.caveEntrances[#w.caveEntrances+1]=p;nextId=nextId+1;break end
 end end
 w._nextCaveId=nextId;require('game.navigation').refresh(w)
end
function C.ensure(w)
 if w.isCave then return end
 -- Saved entrances may exist before their runtime instance cache is created.
 w.caveInstances=w.caveInstances or{}
 if w.caveEntrances then return end
 w.caveEntrances={};w.caveInstances={};w._nextCaveId=1
 for _,o in ipairs((w.map.authored or{}).objects or{})do if o.id=='caveEntrance'then local e={id=w._nextCaveId,x=o.x,y=o.y,seed=math.floor(o.x*31+o.y*17+123)+(SG_SERVER_GENERATION or 0),authored=true};e.levelMin,e.levelMax=require('game.level_zones').encounterRange(w.map,e.x,e.y);w._nextCaveId=w._nextCaveId+1;C.clearResources(w,e);w.caveEntrances[#w.caveEntrances+1]=e end end
 C.replenish(w)
end
function C.cleared(w)
 if (next(w.placedContainers or{})or next(w.gravestones or{})or next(w.burialGraves or{}))then if w.entry then w.entry.closing=nil end;return false end
 if not w.isCave or w.entry.authored or w.entry.questSpawnKey or #(w.enemies or{})==0 then return false end
 for _,e in ipairs(w.enemies)do if not e.dead and(e.hp or 1)>0 then return false end end
 w.entry.closing=true;return true
end
function C.remove(over,id)
 for i=#(over.caveEntrances or{}),1,-1 do local e=over.caveEntrances[i];if e.id==id and not e.authored and not e.questSpawnKey then over.caveInstances[id]=nil;table.remove(over.caveEntrances,i);require('game.navigation').refresh(over);return true end end;return false
end
function C.addQuest(w,x,y,key)
 C.ensure(w);local id=w._nextCaveId or 1;for _,e in ipairs(w.caveEntrances)do id=math.max(id,(e.id or 0)+1)end
 local e={id=id,x=x,y=y,seed=math.random(1,1000000000),questSpawnKey=key,questTarget=true};C.clearResources(w,e);w.caveEntrances[#w.caveEntrances+1]=e;w._nextCaveId=id+1;return e
end
function C.entryCleared(e)
 if e.authored or e.questSpawnKey or(e.state and(next(e.state.placedContainers or{})or next(e.state.gravestones or{})or next(e.state.burialGraves or{})))then return false end
 if e.closing then return true end
 local enemies=e.state and e.state.enemies;if not enemies then return false end
 local count=0;for _,enemy in pairs(enemies)do count=count+1;if not enemy.dead and(enemy.hp or 1)>0 then return false end end;return count>0
end
function C.restore(w,entries)
 w.caveEntrances={};w.caveInstances={};w._nextCaveId=entries.nextCaveId or 1
 for _,e in ipairs(entries)do w._nextCaveId=math.max(w._nextCaveId,(e.id or 0)+1);if not C.entryCleared(e)then w.caveEntrances[#w.caveEntrances+1]=e end end
 -- Resources are regenerated on load; keep the saved entrance apron accessible.
 for _,e in ipairs(entries)do C.clearResources(w,e)end
 require('game.navigation').refresh(w)
end
function C.generate(over,entry)
 local w=setmetatable({},getmetatable(over));for k,v in pairs(over)do if type(v)~='table' then w[k]=v end end
 for _,key in ipairs({'placedContainers','nodes','swings','groundItems','enemies','sheep','farmAnimals','popups','enemyProjectiles','playerArrows','mercArrows','magicProjectiles','magicEffects','juiceParticles','slimePuddles','grass','campfires','houses','paths','notifications','tradeKeepers','healers','traders','standingTorches','villages','fenceRails','pastures','guards','bossShots','bossPools','goblinShots','oreSeams'})do w[key]={}end
 w.sprites=over.sprites;w.mercs=over.mercs;w.isCave=true;w.overworld=over;w.entry=entry;w._nightState=false;w.caveChests={}
 for _,key in ipairs(require('game.villages').keys)do w[key]={x=-10000,y=-10000,jobs={},state='empty'}end
 local rng=love.math.newRandomGenerator(entry.seed);local areaLo,areaHi=require('game.level_zones').encounterRange(over.map,entry.x,entry.y);entry.levelMin=entry.levelMin or areaLo;entry.levelMax=entry.levelMax or areaHi
 local map=setmetatable({cols=80,rows=64,width=1280,height=1024,tile=16,mask={}},Map);w.map=map
 for y=1,map.rows do map.mask[y]={}end
 local function carve(x,y,rx,ry)for yy=math.max(2,y-ry),math.min(map.rows-1,y+ry)do for xx=math.max(2,x-rx),math.min(map.cols-1,x+rx)do map.mask[yy][xx]=true end end end
 local rooms={{x=40,y=35}}
 carve(40,35,5,5)
 for i=2,10 do
  local room={x=rng:random(8,72),y=rng:random(8,56)};local last=rooms[#rooms]
  carve(room.x,room.y,rng:random(4,6),rng:random(4,6))
  for x=math.min(last.x,room.x),math.max(last.x,room.x)do carve(x,last.y,2,2)end
  for y=math.min(last.y,room.y),math.max(last.y,room.y)do carve(room.x,y,2,2)end
  rooms[#rooms+1]=room
 end
 w.exit={x=632,y=536};w.arrival={x=632,y=568}
 local occupied={w.arrival,w.exit}
 local function place(minimum)
  for tries=1,3000 do
   local x,y=rng:random(5,75)*16-8,rng:random(5,59)*16-8;local p={x=x,y=y};local clear=distance(p,w.arrival)>(minimum or 130)^2
   for dx=-24,24,12 do for dy=-24,24,12 do if not map:isLand(x+dx,y+dy)then clear=false end end end
   for _,a in ipairs(occupied)do if distance(a,p)<44^2 then clear=false end end
   if clear then occupied[#occupied+1]=p;return p end
  end
 end
 for i=1,18 do local p=place();if p then local kind=i%3==0 and 'coal' or 'iron';local d=w:resourceInfo(kind);w.nodes[#w.nodes+1]={x=p.x,y=p.y,kind=kind,hp=d.hp,maxHp=d.hp,shake=0,respawnTimer=0,depleted=false}end end
 for i=1,12 do local p=place(200);if p then
  local kind=i%3==0 and 'slime' or 'rat';local level=rng:random(entry.levelMin,entry.levelMax);local e=over.makeExpansionEnemy(kind,p.x,p.y,1)
  if kind=='rat' then e.visualScale=1.2;e.hitRadius=17 end;e.level=level;e.tier=2;e.stats={melee=level,ranged=level,strength=math.floor(level*.55),agility=level,health=level};e.mainCombat=level;e.maxHp=level*4;e.hp=e.maxHp;e.caveId=i
  w.enemies[#w.enemies+1]=e
 end end
 local loot={'Iron Bar','Small Iron Chunk','Small Coal Chunk','Health Flask','Rough Onyx'}
 for i=1,4 do local p=place(170);if p then p.items={};for j=1,3 do p.items[#p.items+1]=loot[rng:random(#loot)]end;w.caveChests[#w.caveChests+1]=p end end
 -- Append the boss after the original content so existing saved indices remain valid.
 local bossPoint=place(300) or place(180)
 local encounterRng=love.math.newRandomGenerator(entry.seed+474747)
 local roll=encounterRng:random(1,100)
 local bossKind=roll<=10 and 'caveSnake' or roll<=20 and 'gigaRat' or roll<=30 and 'slimeBoss' or nil
 -- Preserve the already-generated boss/corpse in legacy visited caves.
 if entry.state and not entry.state.encounterVersion and entry.state.enemies and entry.state.enemies[13] then bossKind='caveSnake' end
 if entry.state and entry.state.encounterVersion==2 then bossKind=entry.state.bossKind or nil end
 w.bossKind=bossKind
 if bossPoint and bossKind then
  local boss=over.makeExpansionEnemy(bossKind,bossPoint.x,bossPoint.y,1);boss.hitRadius=bossKind=='gigaRat' and 30 or 24;boss.caveId=13;local level=rng:random(entry.levelMin,entry.levelMax);local scale=level/math.max(1,boss.level);boss.level=level;for key,value in pairs(boss.stats)do boss.stats[key]=math.max(key=='ranged'and 0 or 1,math.floor(value*scale+.5))end;boss.mainCombat=boss.mainSkill=='Ranged'and boss.stats.ranged or boss.stats.melee;boss.maxHp=math.max(5,boss.stats.health*5);boss.hp=boss.maxHp
  boss.level=entry.levelMax;boss.tier=2;boss.stats={melee=entry.levelMax,ranged=entry.levelMax,strength=math.max(1,math.floor(entry.levelMax*.6)),agility=entry.levelMax,health=entry.levelMax};boss.mainCombat=entry.levelMax;boss.maxHp=math.max(40,entry.levelMax*6);boss.hp=boss.maxHp
  w.enemies[#w.enemies+1]=boss
 end
 -- Keep original ore/chest rolls unchanged; add the denser rat population last.
 for id=14,41 do local p=place(160);if p then
  local level=encounterRng:random(entry.levelMin,entry.levelMax);local e=over.makeExpansionEnemy('rat',p.x,p.y,1)
  e.level=level;e.tier=2;e.stats={melee=level,ranged=0,strength=math.floor(level*.55),agility=level,health=level};e.mainCombat=level;e.maxHp=level*4;e.hp=e.maxHp;e.caveId=id;e.visualScale=1.2;e.hitRadius=17
  w.enemies[#w.enemies+1]=e
 end end
 for _,e in ipairs(w.enemies)do
  local lootRng=love.math.newRandomGenerator(entry.seed+e.caveId*7919)
  e.randomLoot=require('game.cave_loot').roll(e.kind,function(a,b)return lootRng:random(a,b)end)
 end
 local state=entry.state
 if state then
  for i,v in ipairs(state.nodes or {})do local n=w.nodes[i];if n then n.hp=v.hp;n.depleted=v.depleted;n.prospected=v.prospected;n.respawnTimer=1e9 end end
  for _,e in ipairs(w.enemies)do local v=(state.enemies or {})[e.caveId];if v then for k,value in pairs(v)do e[k]=value end;e.respawnTimer=1e9 end end
  for i,v in ipairs(state.chests or {})do if w.caveChests[i]then w.caveChests[i].items=v end end
  w.placedContainers=state.placedContainers or{};w.groundItems=state.groundItems or {};w.burialGraves=state.burialGraves or{};w.gravestones=state.gravestones or{};w.graveSerial=state.graveSerial or 0
  require('game.fire_fuel').restore(w,state.fireState)
 end
 return w
end
local function cancel(ui)
 ui.craftJob=nil;ui.magicCast=nil;ui.useTarget=nil;ui.context=nil;ui.dragSlot=nil
 for name in pairs(ui.open)do ui.open[name]=false end
 local w=ui.world;w.gather=nil;w.fishing=nil;w.workJob=nil;w.combatTarget=nil;w.targetedEnemy=nil
 for _,key in ipairs({'playerArrows','mercArrows','magicProjectiles','enemyProjectiles','goblinShots','bossShots'})do w[key]={}end
 for _,e in ipairs(w.enemies)do e.aggro=false;if not e.dead then e.state='return' end end
end
function C.enter(ui,entry)
 require("game.audio").play("instance_start");local over=ui.world;require("game.party").markDeaths(over);C.ensure(over);cancel(ui)
 if entry.closing then over:addPopup(ui.player.x,ui.player.y-24,'This cleared cave is closing');return over end
 local w=over.caveInstances[entry.id];if not w then w=C.generate(over,entry);over.caveInstances[entry.id]=w end
 if w.bossKind then require("game.audio").play("boss_spawn") end;ui.world=w;w.mercs=over.mercs;ui.player.x,ui.player.y=w.arrival.x,w.arrival.y;w.playerRef=ui.player
 for _,m in ipairs(w.mercs)do if not m.waitingInTown and (m.hp or 0)>0 then m.x,m.y=w.arrival.x,w.arrival.y+24;require('game.party').recall(w,m,ui.player)end end
 require('game.navigation').refresh(w);w:addPopup(ui.player.x,ui.player.y-24,'CAVE '..entry.id..' - LEVELS '..tostring(entry.levelMin or 1)..'-'..tostring(entry.levelMax or 10))
 return w
end
function C.leave(ui)
 local w=ui.world;if not w.isCave then return w end;require("game.party").markDeaths(w);cancel(ui)
 local over=w.overworld;if not require('game.multiplayer').active and C.cleared(w)then C.remove(over,w.entry.id)end;ui.world=over;ui.player.x,ui.player.y=w.entry.x,w.entry.y+36;over.playerRef=ui.player
 if w.deathRespawn then local x,y=require('game.respawn').player(over,w.entry.x,w.entry.y,ui.player,ui.campOwner or require("game.gravestones").owner(ui));if x then ui.player.x,ui.player.y=x,y end;w.deathRespawn=nil end
 for _,m in ipairs(over.mercs)do if not m.waitingInTown and (m.hp or 0)>0 then m.x,m.y=ui.player.x,ui.player.y;require('game.party').recall(over,m,ui.player)end end
 require('game.villages').nearest(over,ui.player.x,ui.player.y);require('game.navigation').refresh(over)
 return over
end
function C.at(w,x,y)
 C.ensure(w);local p={x=x,y=y}
 if w.isCave then
  if distance(p,w.exit)<26^2 then return w.exit,'exit' end
  for _,ch in ipairs(w.caveChests)do if distance(p,ch)<16^2 then return ch,'chest' end end
 else for _,e in ipairs(w.caveEntrances)do if distance(p,e)<30^2 then return e,'entrance' end end end
end
function C.click(ui,x,y)
 local w=ui.world;local object,kind=C.at(w,x,y);if not object then return false end
 if distance(ui.player,object)>56^2 then w:addPopup(ui.player.x,ui.player.y-24,'Move closer to '..(kind=='chest' and 'the cache' or 'the cave entrance'));return true end
 if kind=='entrance' then C.enter(ui,object) elseif kind=='exit' then C.leave(ui)
 else
  if #object.items==0 then w:addPopup(object.x,object.y-24,'EMPTY CACHE');return true end
  local taken=0
  while #object.items>0 do local item=object.items[1];if not ui.inv:add(item,1)then break end;table.remove(object.items,1);taken=taken+1 end
  require('game.audio').play(taken>0 and 'item_pickup' or 'inventory_full',object.x,object.y);w:addPopup(object.x,object.y-24,taken>0 and ('Loot collected: '..taken..(#object.items>0 and ' - bags full' or '')) or 'FULL INVENTORY')
 end
 return true
end
function C.draw(w,add)
 C.ensure(w)
 if not C.entranceImage then C.entranceImage=love.graphics.newImage('assets/cave_entrance.png');C.entranceImage:setFilter('nearest','nearest')end
 local list=w.isCave and {w.exit} or w.caveEntrances
 for _,p in ipairs(list)do add(p.y+12,function()love.graphics.setColor(1,1,1);love.graphics.draw(C.entranceImage,p.x,p.y,0,1,1,32,16)end)end
 for _,ch in ipairs(w.caveChests or {})do add(ch.y+10,function()love.graphics.setColor(#ch.items>0 and 1 or .45,#ch.items>0 and 1 or .45,#ch.items>0 and 1 or .45);local im=w.sprites.bankChestImage;love.graphics.draw(im,ch.x,ch.y,0,1,1,im:getWidth()/2,im:getHeight()/2)end)end
end
function C.export(w)
 local over=w.isCave and w.overworld or w;C.ensure(over);local out={nextCaveId=over._nextCaveId}
 for _,entry in ipairs(over.caveEntrances)do
  local a={id=entry.id,x=entry.x,y=entry.y,seed=entry.seed,state=entry.state,questSpawnKey=entry.questSpawnKey,questTarget=entry.questTarget,levelMin=entry.levelMin,levelMax=entry.levelMax,authored=entry.authored,closing=entry.closing};local instance=over.caveInstances[entry.id]
  if instance then
   a.state={encounterVersion=2,bossKind=instance.bossKind or false,nodes={},enemies={},chests={},placedContainers=instance.placedContainers,burialGraves=instance.burialGraves,gravestones=instance.gravestones,graveSerial=instance.graveSerial,groundItems=instance.groundItems,fireState=require('game.fire_fuel').export(instance)}
   for i,n in ipairs(instance.nodes)do a.state.nodes[i]={hp=n.hp,depleted=n.depleted,prospected=n.prospected}end
   for i,e in ipairs(instance.enemies)do local v={};for _,k in ipairs({'hp','dead','skinned','huntingXpAwarded','expansionLoot','skinDrops','snakeLoot','randomLoot','lootPaid'})do v[k]=e[k]end;a.state.enemies[e.caveId or (100+i)]=v end
   for i,ch in ipairs(instance.caveChests)do a.state.chests[i]=ch.items end
  end
  out[#out+1]=a
 end
 return out
end
function C.saveContext(player,ui)
 local w=ui.world;local data=C.export(w)
 if not w.isCave then return player,ui,data end
 local p={};for k,v in pairs(player)do p[k]=v end;p.x,p.y=w.entry.x,w.entry.y+36
 local world=setmetatable({mercs={},_fireSource=w.overworld}, {__index=w.overworld})
 for i,m in ipairs(w.mercs)do local copy={};for k,v in pairs(m)do copy[k]=v end;if not copy.waitingInTown then copy.x,copy.y=p.x,p.y end;world.mercs[i]=copy end
 return p,setmetatable({world=world},{__index=ui}),data
end
return C
