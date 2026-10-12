local S=SG_SERVER
local J=require('game.json');local Pack=require('game.profile')
local World=require('game.world');local Player=require('game.player');local Skills=require('game.skills');local Inventory=require('game.inventory')
local Regions=require('game.regions');local Caves=require('game.caves')
local rooms,actors={},{}
require('Server.camp_rules').install(actors,rooms,S)
local collections
local savedRooms={}
local graveLedger={}
S.bagWorlds=function()local all={};for _,r in pairs(rooms)do all[#all+1]=r.world end;for _,d in pairs(savedRooms)do all[#all+1]=d end;return all end
local function graveKey(a)return tostring(a.id)..":"..a.slot end
local function graveRecord(a)
 a.religionHighWater=a.skills:get("Religion").xp;local key=graveKey(a);local old=graveLedger[key];a.graveEpoch=(old and old.graveEpoch or 0)+1
 graveLedger[key]={graveEpoch=a.graveEpoch,bags=require("game.rune_inventory").copy(a.inv.bagSlots),equipment=require("game.rune_inventory").copy(a.equipment),equipmentItems=require("game.rune_inventory").copy(a.equipmentItems),equipmentSockets=require("game.rune_inventory").copy(a.sockets),potionBelt=require("game.rune_inventory").copy(a.potionBelt),deathCaveExit=a.deathCaveExitPending,player={x=a.player.x,y=a.player.y,hp=a.player.hp,stamina=a.player.stamina},skills=require("game.rune_inventory").copy(a.skills.data),religionXP=a.skills:get("Religion").xp}
end
if Regions.doc then rooms[Regions.start]={world=S.world,members={}}end
local clock=0
local day=require('game.daynight').new()
local function copy(t,seen)
 if type(t)=='number'then return t==t and math.abs(t)<math.huge and t or nil end
 if type(t)=='string'or type(t)=='boolean'then return t end
 if type(t)~='table'then return nil end
 seen=seen or{};if seen[t]then return nil end;seen[t]=true
 local out={};for k,v in pairs(t)do if type(k)=='number'or type(k)=='string'then out[k]=copy(v,seen)end end;seen[t]=nil;return out
end
SG_AUDIO=function(method,cue,x,y,data)
 local w=S.activeWorld;if not w then return end;local owner=S.activeActor;x=x or(owner and owner.player.x);y=y or(owner and owner.player.y)
 for _,a in ipairs(w.onlineActors or{})do if x and y and(a.player.x-x)^2+(a.player.y-y)^2<=900^2 then a.audio=a.audio or{};if #a.audio<256 then a.audio[#a.audio+1]={method=method,cue=cue,x=x,y=y,data=copy(data)}end end end
end
local function restore(a,d)
 if a.gather and (not d.gatherTarget or a.gather.node.netId~=d.gatherTarget)then a.gather=nil;a.player.heldOverride=nil end;a.player.quests=d.quests or{};a.knownOre=d.knownOre or{};a.knownPositions=d.knownPositions or{}
 local previous=a.mercs or{};a.mercs={};for i,m in ipairs(d.mercs or{})do local old=previous[i];if old and old.name==m.name then local last=a.sentMercs and a.sentMercs[i];for _,field in ipairs({'equipment','equipmentSockets','equipmentItems'})do old[field]=old[field]or{};for _,slot in ipairs({'head','body','legs','cape','weapon','offhand','ammo'})do local v=(m[field]or{})[slot];local before=last and(last[field]or{})[slot];if not last or J.encode(Pack.pack(v))~=J.encode(Pack.pack(before))then old[field][slot]=v end end end;old.waitingInTown=m.waitingInTown;old.waitingRegionId=m.waitingRegionId;old.waitX=m.waitX;old.waitY=m.waitY;m=old end;m.onlineOwner=a.id;a.mercs[i]=m end
 local p=a.player;for _,k in ipairs({'x','y','headDir','bodyDir','frame','moving','equipped','race','hp','maxHp','stamina','maxStamina','burst','warriorYell','poisonImmuneTimer','slimeCoated','toolSwing','activity','activityTimer'})do if d.player[k]~=nil then p[k]=d.player[k]end end
 a.skills.bagInventory=a.inv;a.skills:load(d.skills);a.skills:setRace(p.race)
 a.inv.bagSlots=d.bags or a.inv.bagSlots;a.inv.activeBag=d.activeBag or 1;a.inv:applyStrengthBagBonus(a.skills:get("Strength").level)
 a.graveEpoch=d.graveEpoch or 0;a.potionBelt=d.potionBelt or{};a.equipment=d.equipment or{};a.equipmentItems=d.equipmentItems or{};require('game.quality').bind(a.equipment,a.equipmentItems);require('game.tool_slot').bind(a);a.sockets=d.equipmentSockets or{};a.pages=d.spellPages or{};p.onlineId=a.id;p.combatSkills=a.skills.data;p.equipment=a.equipment
end
local function state(a)
 a.inv:applyStrengthBagBonus(a.skills:get("Strength").level)
 return {graveEpoch=a.graveEpoch or 0,potionBelt=copy(a.potionBelt or{}),equipmentSockets=copy(a.sockets or{}),player=copy(a.player),skills=copy(a.skills.data),bags=copy(a.inv.bagSlots),activeBag=a.inv.activeBag,equipment=copy(a.equipment),equipmentItems=copy(a.equipmentItems),quests=copy(a.player.quests),mercs=copy(a.mercs)}
end
local function countBlessed(bags)
 local out={};for _,bag in pairs(bags or{})do for _,obj in pairs(bag.slots or{})do if obj.blessed then out[obj.name]=(out[obj.name]or 0)+(obj.qty or 1)end end end;return out
end
local function effects(a,before)
 local after=state(a);for name,sk in pairs(a.skills.data)do if a.activityHighWater then a.activityHighWater[name]=math.max(a.activityHighWater[name]or 0,sk.xp)end end;local e=a.effects;e.blessed=e.blessed or{};e.materials=e.materials or{}
 local previous=countBlessed(before.bags);local current=countBlessed(after.bags);for name,qty in pairs(previous)do e.blessed[name]=(e.blessed[name]or 0)+(current[name]or 0)-qty end
 local oldAmmo=before.equipment.ammo;local newAmmo=after.equipment.ammo;if type(oldAmmo)=='table'and oldAmmo.name=='Rune Bag'and type(newAmmo)=='table'and newAmmo.name=='Rune Bag'then for name,qty in pairs(oldAmmo.materials or{})do e.materials[name]=(e.materials[name]or 0)+((newAmmo.materials or{})[name]or 0)-qty end end
 e.hp=e.hp+(after.player.hp-before.player.hp);e.stamina=e.stamina+(after.player.stamina-before.player.stamina)
 if after.player.x~=before.player.x or after.player.y~=before.player.y then e.teleport={x=after.player.x,y=after.player.y}end
 for k,v in pairs(after.skills)do e.xp[k]=(e.xp[k]or 0)+v.xp-before.skills[k].xp end
end
local function restoreRoom(r,key)
 local d=savedRooms[key];if not d then return end;savedRooms[key]=nil
 local w=r.world;local Persist=require('game.world_persistence')
 for _,name in ipairs(Persist.lists)do if name=='campfires'then for _,f in ipairs(d[name]or{})do w.campfires[#w.campfires+1]=f end else w[name]=d[name]or{}end end
 w.graveSerial=d.graveSerial or 0;w.graveRevision=d.graveRevision or 0
 require('game.ground_lifetime').update(w);require('game.fire_fuel').realtime(w,nil,nil)
 -- Recovery footprints stay reachable when procedural resources regenerate.
 local recovery={};for _,v in ipairs(w.placedContainers or{})do recovery[#recovery+1]=v end;for _,g in ipairs(w.gravestones or{})do recovery[#recovery+1]=g end;for _,g in ipairs(w.groundItems or{})do if g.relocatedFromCave then recovery[#recovery+1]=g end end
 for i=#w.nodes,1,-1 do local n=w.nodes[i];if not n.authored and not n.questSpawnKey then for _,g in ipairs(recovery)do if(n.x-g.x)^2+(n.y-g.y)^2<64^2 then table.remove(w.nodes,i);break end end end end
 require('game.node_index').invalidate(w);require('game.navigation').refresh(w)
end
local function room(b)
 if not Regions.doc or b.worldId~=Regions.doc.worldId then error('Client world differs from the server GitHub world: download the same GitHub world into the clients')end
 if b.worldFingerprint and b.worldFingerprint~=Regions.networkFingerprint then error('World contents differ: clients must load the same GitHub world as the server')end
 local r=Regions.records[b.regionId];if not r then error('Unknown region')end
 local key=b.regionId
 if not rooms[key]then local old=Regions.active;Regions.active=key;rooms[key]={world=World.new(S.sprites,r.data),members={}};rooms[key].world.regionId=key;Regions.active=old end
 restoreRoom(rooms[key],key);local over=rooms[key].world;Caves.ensure(over)
 if b.area=='cave'then
  Caves.ensure(over);local entry;for _,e in ipairs(over.caveEntrances)do if e.id==b.caveId then entry=e end end
  if not entry then if b.initial or not actors[b.id]then b.restartReturn=true;b.restartPosition={x=over.bankChest.x,y=over.bankChest.y+24};return rooms[key],key else error('Unknown cave')end end
  if b.caveSeed and b.caveSeed~=0 and b.caveSeed~=entry.seed then if b.initial or not actors[b.id]then b.restartArrival=true else error('Cave changed; return to the overworld')end end
  local retained=rooms[key..'/cave/'..entry.id]and rooms[key..'/cave/'..entry.id].world or savedRooms[key..'/cave/'..entry.id];if retained and next(retained.gravestones or{})then entry.closing=nil end
  if entry.closing then local a=actors[b.id];if not a or a.room~=key..'/cave/'..entry.id then error('This cleared cave is closing')end end
  key=key..'/cave/'..entry.id
  if not rooms[key]then rooms[key]={world=Caves.generate(over,entry),members={}}end;over.caveInstances[entry.id]=rooms[key].world;rooms[key].world.entry=entry
 end
 restoreRoom(rooms[key],key)
 if rooms[key].world.isCave then local w=rooms[key].world;for _,e in ipairs(w.overworld.caveEntrances)do if e.id==w.entry.id then w.entry=e;break end end;w.overworld.caveInstances[w.entry.id]=w end
 return rooms[key],key
end
local function assign(w,collection)
 w._onlineIds=w._onlineIds or{};w._onlineSerial=w._onlineSerial or 0
 for _,e in ipairs(w[collection]or{})do if not e.netId then w._onlineSerial=w._onlineSerial+1;e.netId=w._onlineSerial end end
end
collections={'placedContainers','nodes','enemies','groundItems','sheep','campfires','playerArrows','mercArrows','magicProjectiles','enemyProjectiles','magicEffects','slimePuddles','bossShots','bossPools','goblinShots','goblinArrows','guards','farmAnimals','popups','juiceParticles','shellfishPots','shellfishParts','gravestones','burialGraves'}
local packedRows=setmetatable({},{__mode='k'});local packedValues=setmetatable({},{__mode='k'})
local function wireSnapshot(out)
 local root={entries={}};for k,v in pairs(out)do local value
 if type(v)=='table'and packedValues[v]then value=packedValues[v]
 elseif type(v)=='table'and #v>0 and packedRows[v[1]]then value={array={}};for i,row in ipairs(v)do value.array[i]=packedRows[row]or Pack.pack(row)end else value=Pack.pack(v)end
 root.entries[#root.entries+1]={key=k,value=value}end;return root
end
local function rowDelta(cached,previous)
 if not previous then return cached.data end
 cached.deltas=cached.deltas or setmetatable({},{__mode="k"});if cached.deltas[previous]then return cached.deltas[previous]end
 local d={netId=cached.data.netId}
 for k,v in pairs(cached.data)do
  local changed
  if type(v)=='table'then
   cached.metadata=cached.metadata or{};previous.metadata=previous.metadata or{}
   cached.metadata[k]=cached.metadata[k]or J.encode(Pack.pack(v))
   if previous.data[k]~=nil then previous.metadata[k]=previous.metadata[k]or J.encode(Pack.pack(previous.data[k]))end
   changed=cached.metadata[k]~=previous.metadata[k]
  else changed=v~=previous.data[k]end
  if changed then d[k]=v end
 end
 cached.deltas[previous]=d;packedRows[d]=J.cache(Pack.pack(d));return d
end
local function snapshot(w,p,initial,a)
 require("game.cursed_enemies").world(w)
 local function global(name,build)
  if a.persist then return build()end
  w._snapshotRows=w._snapshotRows or{};local key='global:'..name;local cached=w._snapshotRows[key]
  if not cached then local value=build();local packed=J.cache(Pack.pack(value));cached={data=value,signature=J.encode(packed)};w._snapshotRows[key]=cached;if type(value)=='table'then packedValues[value]=packed end end
  a.sentGlobals=a.sentGlobals or{};if initial or a.sentGlobals[name]~=cached.signature then a.sentGlobals[name]=cached.signature;return cached.data end
 end
 local out={removed={},campRevision=w.campRevision or 0};if initial or a.sentCampRevision~=out.campRevision then out.playerCamps=require('game.fieldcraft').public(w);a.sentCampRevision=out.campRevision end;a.sent=a.sent or{};a.sentRows=a.sentRows or{}
 for _,name in ipairs(collections)do
  assign(w,name);out[name]={};local sent=a.sent[name]or{};a.sent[name]=sent;local prior=a.sentRows[name]or{};a.sentRows[name]=prior;local alive={};local delta=not a.persist and(name=='placedContainers'or name=='nodes'or name=='enemies'or name=='sheep'or(name=='guards'and a.snapshotVersion==2))
  for _,e in ipairs(w[name]or{})do
   alive[e.netId]=true
   if initial or(name=='gravestones'and e.owner==tostring(a.id)..':'..tostring(a.slot))or name=='campfires'or name=='groundItems'or name=='guards'or (e.x-p.x)^2+(e.y-p.y)^2<1100^2 then
    w._snapshotRows=w._snapshotRows or{};local cached=not a.persist and delta and w._snapshotRows[e];local d=cached and cached.data
    if not d then d={};for k,v in pairs(e)do if k~='prospected'and((type(v)=='number'and v==v and math.abs(v)<math.huge)or type(v)=='string'or type(v)=='boolean')then d[k]=v end end
    for i,c in ipairs(w.goblinCamps or{})do if e.campId==c or e.goblinCamp==c then d.campIndex=i end end
    for _,k in ipairs({'stats','combatSkills','equipment','equipmentItems','equipmentSockets','object','customDefinition','color'})do if e[k]then d[k]=copy(e[k])end end
    if a.persist then if name=="gravestones"then d.contents=copy(e.contents)elseif name=="enemies"then d.curseBase=copy(e.curseBase);d.boneDamage=copy(e.boneDamage)end end
    if delta and not a.persist then local packed=J.cache(Pack.pack(d));cached={data=d,packed=packed,signature=J.encode(packed)};w._snapshotRows[e]=cached;packedRows[d]=packed end end
    local signature=cached and cached.signature or(delta and J.encode(Pack.pack(d))or nil)
    if initial or not delta or sent[e.netId]~=signature then out[name][#out[name]+1]=(cached and not initial)and rowDelta(cached,prior[e.netId])or d;sent[e.netId]=signature;if cached then prior[e.netId]=cached end end
   end
  end
  out.removed[name]={};for id in pairs(sent)do if not alive[id]then out.removed[name][#out.removed[name]+1]=id;sent[id]=nil;prior[id]=nil end end
 end
 out.graveRevision=w.graveRevision or 0;out.graveSerial=w.graveSerial or 0;if a.persist then out.pendingRuneDrops=copy(w.pendingRuneDrops)end;out.onlineSerial=w._onlineSerial;out.nextCaveId=w._nextCaveId;out.dayTime=day.time;out.caveChests=global('caveChests',function()return copy(w.caveChests or{})end);out.goblinCamps=global('goblinCamps',function()return require('game.world_persistence').camps(w)end);out.exit=copy(w.exit);out.caveEntrances=global('caveEntrances',function()return copy(w.caveEntrances or{})end);out.houseSeed=w.houseSeed;out.stations=global('stations',function()local list={};for i,v in ipairs(w.villages or{})do list[i]={tanningVat=copy(v.tanningVat),hideStretcher=copy(v.hideStretcher)}end;return list end)
 if initial and w.isCave then out.caveMap=copy(w.map.mask);out.arrival=copy(w.arrival);out.entry=copy(w.entry)end
 return out
end
local Q=require('game.quests')
 Q.event=function(w,kind,target,amount)for _,a in ipairs(w.onlineActors or{})do if (kind=='kill'and(a.player.x-w.playerRef.x)^2+(a.player.y-w.playerRef.y)^2<=200^2)or a.player==w.playerRef then a.events=a.events or{};a.events[#a.events+1]={kind=kind,target=target,amount=amount or 1}end end end
local resolveArrow=World.resolvePlayerArrow
World.resolvePlayerArrow=function(w,q,skills,logger)local a=q.onlineOwner and (q.onlineActor or actors[q.onlineOwner]);if a then w.playerRef=a.player end;return resolveArrow(w,q,a and a.skills or skills,logger)end
local function uiFor(a,w)
 local u={world=w,player=a.player,inv=a.inv,skills=a.skills,equipmentItems=a.equipmentItems,equipment=a.equipment,equipmentSockets=a.sockets,spellPages=a.pages,sprites=S.sprites,logger=a.logger}
 setmetatable(u,{__index=require('game.ui')})
 u.countSpellRuneMaterial=require('game.ui').countSpellRuneMaterial
 u.consumeSpellRuneMaterial=require('game.ui').consumeSpellRuneMaterial
 return u
end
local function action(a,w,c)
 require("game.ground_lifetime").update(w)
 w._snapshotRows=nil
 if c.kind=='grave'then return require('game.gravestones').start(w,a,c.op,c.target)end
 if c.kind=='batch'then
  assert(type(c.commands)=='table'and #c.commands<=64,'Invalid action batch')
  for _,command in ipairs(c.commands)do assert(command.kind=='drop'and type(command.name)=='string'and S.sprites.itemInfo[command.name],'Invalid dropped output')end
  for _,command in ipairs(c.commands)do local ok,why=action(a,w,command);if not ok then return false,why end end
  return true,'Dropped'
 end
 local p=a.player;local target
 for _,e in ipairs(w[c.collection or'enemies']or{})do if e.netId==c.target then target=e;break end end
 require('game.villages').nearest(w,p.x,p.y)
 S.activeWorld=w;S.activeActor=a;w.playerRef=p;w.gather=a.gather;w.fishing=a.fishing;w.combatTarget=a.target;w.targetedEnemy=a.target
 local ok,why=false,'Unknown action'
 if c.kind=='questAccept'or c.kind=='questClaim'then
  Q.setup(w);local n;for _,npc in ipairs(w.questNPCs or{})do if npc.key==c.key then n=npc end end
  if n and (n.x-p.x)^2+(n.y-p.y)^2<=65^2 then ok,why=(c.kind=='questAccept'and Q.accept or Q.claim)(uiFor(a,w),n)end
 elseif c.kind=='chest'then
  local ch=w.caveChests and w.caveChests[c.index];if ch and (ch.x-p.x)^2+(ch.y-p.y)^2<=70^2 then ok=true;while #ch.items>0 do if not a.inv:add(ch.items[1],1)then break end;table.remove(ch.items,1)end;why='Cache collected'end
 elseif c.kind=='cage'then ok=require('game.goblin_camps').click(w,p,c.x,c.y)
 elseif c.kind=='drop'then
  if require('game.fieldcraft_content').protected(c.name)then return false,'Camp items require an authoritative inventory transfer'end
  if type(c.name)~='string'or not S.sprites.itemInfo[c.name]then return false,'Unknown item'end
  w:addGroundItem(c.name,p.x+10,p.y+8,nil,c.object and Pack.unpack(c.object));if a.inv:isBagItem(c.name)then w.groundItems[#w.groundItems].bagOwner=tostring(a.id)..':'..a.slot end;ok=true;why='Dropped'
 elseif c.kind=='gather'then
  if not target or target.depleted then return false,'Resource depleted' end
  -- The client deliberately gathers on an 0.8s cadence. Allow a small server-clock
  -- tolerance so normal network/tick jitter cannot reject a legitimate next swing.
  -- Sequence IDs already prevent duplicate/replayed multiplayer requests.
  if clock+0.20<(a.gatherNext or 0)then return false,'Gathering too quickly' end
  local oldProspected=target.prospected;local cycle=target.resourceCycle or 0;local known=a.knownOre[target.netId];local position=a.knownPositions[target.kind..':'..target.x..':'..target.y];target.prospected=known==cycle or position==cycle or cycle==0 and(known==true or position==true)or oldProspected
  a.prospectedTarget=target;a.oldProspected=oldProspected
  if a.gather and a.gather.bushStage and a.gather.bushStage~=target.stage then a.gather=nil;w.gather=nil end
  if not a.gather or a.gather.node~=target then ok,why=w:startGather(target,p,a.skills,a.inv)else ok=true end
  if ok then a.gatherNext=clock+.8;w:updateGather(.8,p,a.inv,a.skills,a.logger)end
 elseif c.kind=='attack'then
  if target then w:startCombat(target,p)end
  ok,why=w:attackEnemy(target,p,a.skills,a.equipment,S.sprites,a.logger,a.sockets)
  for _,q in ipairs(w.playerArrows)do q.onlineOwner=q.onlineOwner or a.id;q.onlineActor=q.onlineActor or a end
 elseif c.kind=='pickupAll'then
  local count=0;for i=#w.groundItems,1,-1 do local g=w.groundItems[i];if(g.graveLoot or not require('game.fieldcraft_content').protected(g.name))and(g.x-p.x)^2+(g.y-p.y)^2<=80^2 then local added=g.object and a.inv:addItemObject(copy(g.object))or(not g.object and a.inv:add(g.name=='Lit Torch'and'Torch'or g.name,1));if added then table.remove(w.groundItems,i);count=count+1 end end end;ok=count>0;why='Collected '..count..' items'
 elseif c.kind=='pickup'then
  if target and not target.graveLoot and require('game.fieldcraft_content').protected(target.name)then return false,'Camp items require an authoritative inventory transfer'end
  if target and (target.x-p.x)^2+(target.y-p.y)^2<=80^2 then
   ok=target.object and a.inv:addItemObject(copy(target.object))or(not target.object and a.inv:add(target.name=='Lit Torch'and'Torch'or target.name,1))
   if ok then for i,g in ipairs(w.groundItems)do if g==target then table.remove(w.groundItems,i);break end end end;why=ok and'Collected'or'Bags full'
  else why='Too far away' end
 elseif c.kind=='skin'then ok,why=w:skinAnimal(target,p,a.skills,a.inv,a.logger)
 elseif c.kind=='shear'then ok,why=w:shearSheep(target,p,a.inv,a.equipment,a.logger)
 elseif c.kind=='fire'then ok,why=w:createCampfire(p,a.inv,a.skills,a.logger,c.fuel)
 elseif c.kind=='log'then ok,why=w:addBonfireLog(p,a.inv,a.skills,a.logger,c.fuel,target)
 elseif c.kind=='tanning'then local st=w.tanningVat;local before=st and #st.jobs or 0;ok,why=w:useTanningVat(a.inv,a.skills,a.logger);if ok and st then for i=before+1,#st.jobs do st.jobs[i].onlineOwner=a.id end end
 elseif c.kind=='drying'then ok,why=w:useHideStretcher(a.inv,a.skills,a.logger);if ok and w.hideStretcher and w.hideStretcher.state=='stretching'then w.hideStretcher.onlineOwner=a.id end
 elseif c.kind=='spell'then
  w.combatTarget=target;local u=uiFor(a,w);local other=c.healPlayerId~=nil and actors[c.healPlayerId]or nil
  if c.healPlayerId~=nil and(not other or other.room~=a.room or clock-other.seen>=15 or other.player.hp<=0 or not(require('game.magic_system').spells[a.pages[c.slot]]or{}).heal)then ok,why=false,'Healing target unavailable'
  else u.healingTarget=other and other.player;ok,why=require('game.magic_system').cast(u,c.slot)end
  for _,q in ipairs(w.magicProjectiles)do q.onlineOwner=q.onlineOwner or a.id end
 elseif c.kind=='ability'then ok,why=require('game.abilities').cast(uiFor(a,w),c.name)
 end
 if a.prospectedTarget then a.prospectedTarget.prospected=a.oldProspected;a.prospectedTarget=nil end
 a.gather=w.gather;a.fishing=w.fishing;w.gather=nil;w.fishing=nil;w.combatTarget=nil;w.targetedEnemy=nil
 return ok,why
end
local function exchange(b)
 local data=Pack.unpack(b.personal)
 local actor=actors[b.id];local adminUpdate=actor and actor.slot==b.slot and actor.owner==b.owner and actor.adminUpdate
 if adminUpdate and (tonumber(b.adminRevision)or 0)>=adminUpdate.revision then actor.adminUpdate=nil;adminUpdate=nil end
 if adminUpdate then adminUpdate=copy(adminUpdate);adminUpdate.personal.player=copy(actor.player);adminUpdate.personal.skills=copy(actor.skills.data);adminUpdate.personal.bags=copy(actor.inv.bagSlots);actor.effects={hp=0,stamina=0,xp={}};for k,v in pairs(adminUpdate.personal)do data[k]=copy(v)end;b.action=nil;if adminUpdate.destination then b.regionId=adminUpdate.destination.region;b.area='overworld';b.caveId=0;b.caveSeed=0 end end
 assert(type(data)=='table'and type(data.player)=='table'and type(data.skills)=='table'and type(data.bags)=='table','Invalid player state')
 for _,k in ipairs({'x','y','hp','maxHp','stamina','maxStamina'})do local v=data.player[k];assert(type(v)=='number'and v==v and v>=0 and v<10000000,'Invalid player '..k)end
 assert(({up=true,down=true,left=true,right=true})[data.player.bodyDir],'Invalid direction')
 require('game.bag_system').validate(data.bags,data.skills)
 local r,key=room(b);local a=actors[b.id]
 local ledger=graveLedger[tostring(b.id)..":"..b.slot];local graveSync=ledger and data.graveEpoch~=ledger.graveEpoch
 if graveSync then for _,field in ipairs({"bags","equipment","equipmentItems","equipmentSockets","potionBelt","graveEpoch"})do data[field]=copy(ledger[field])end;for k,v in pairs(ledger.player)do data.player[k]=v end;data.skills=copy(ledger.skills or data.skills);if a then a.effects={hp=0,stamina=0,xp={}}end end
 if b.restartArrival and not(graveSync and ledger.deathCaveExit)then data.player.x,data.player.y=r.world.arrival.x,r.world.arrival.y;b.restartPosition={x=data.player.x,y=data.player.y}elseif b.restartPosition then data.player.x,data.player.y=b.restartPosition.x,b.restartPosition.y end
 if not a then data.fieldcraft=data.fieldcraft or{};data.fieldcraft.pots={}end
 if a and (a.owner~=b.owner or a.slot~=b.slot) then if a.room then rooms[a.room].members[b.id]=nil end;actors[b.id]=nil;a=nil end
 if not a then b.initial=true;a={id=b.id,owner=b.owner,slot=b.slot,player=Player.new(),skills=Skills.new(),inv=Inventory.new(),effects={hp=0,stamina=0,xp={}},lastSeq=0};actors[b.id]=a end
 a.snapshotVersion=tonumber(b.snapshotVersion)==2 and 2 or 1
 if a.lastSeq==b.seq and a.reply then return a.reply end
 if b.seq<=a.lastSeq then error('Out of order multiplayer request')end
 if a.room~=key then if a.room then rooms[a.room].members[b.id]=nil end;a.room=key;a.gather=nil;a.sent={};a.sentRows={};a.sentGlobals={};r.members[b.id]=a end
 a.logger={log=function(_,event,details)SG_AUDIO('event',event,details and details.x or a.player.x,details and details.y or a.player.y,details)end}
 local skillTotals={};for _,name in ipairs({'Fieldcraft','Survival','Foraging'})do skillTotals[name]=a.protectedSkills and a.skills.data[name].xp or ((b.skillBaseline or{})[name]or 0)end
 local religionXP=math.max(a.religionHighWater or 0,tonumber(b.religionBaseline)or 0,ledger and ledger.religionXP or 0)
 if adminUpdate then religionXP=data.skills.Religion.xp;for name in pairs(skillTotals)do skillTotals[name]=data.skills[name].xp end;a.activityHighWater={} end;restore(a,data);a.skills.data.Religion.xp=religionXP;a.skills.data.Religion.level=a.skills:levelForXP(religionXP);a.religionHighWater=religionXP;for name,xp in pairs(skillTotals)do a.skills.data[name].xp=xp;a.skills.data[name].level=a.skills:levelForXP(xp)end;a.protectedSkills=true;a.player.name=b.name;a.player.race=b.race;a.skills:setRace(b.race);a.seen=clock
 if not a.bonfireInitialized then a.bonfireInitialized=true;local baseline=b.buffBaseline or{};local untilTime=tonumber(baseline.bonfireBuffUntil)or 0;local now=require('game.fire_fuel').now();if untilTime>now and untilTime<=now+301 then a.player.bonfireBuffUntil=untilTime;a.player.bonfireLastSource=baseline.bonfireLastSource end end
 a.campOwner=tostring(a.id)..':'..a.slot;require('game.fieldcraft').bind(r.world,a)
 a.activityHighWater=a.activityHighWater or{};for name,sk in pairs(a.skills.data)do
  local old=a.activityHighWater[name];if old and sk.xp>old then require('game.fieldcraft').activity(a.skills,name,sk.xp-old)end
  a.activityHighWater[name]=math.max(old or 0,sk.xp)
 end
 local pending=a.effects;a.player.hp=math.max(0,a.player.hp+pending.hp);a.player.stamina=math.max(0,a.player.stamina+pending.stamina)
 for k,xp in pairs(pending.xp)do if a.skills.data[k]and k~='Fieldcraft'and k~='Survival'and k~='Foraging'then a.skills.data[k].xp=a.skills.data[k].xp+xp;a.skills.data[k].level=a.skills:levelForXP(a.skills.data[k].xp)end end
 for name,qty in pairs(pending.blessed or{})do if qty<0 then a.inv:removeBlessed(name,-qty)end end
 local ammo=a.equipment.ammo;if type(ammo)=='table'and ammo.name=='Rune Bag'then ammo.materials=ammo.materials or{};for name,qty in pairs(pending.materials or{})do ammo.materials[name]=math.max(0,(ammo.materials[name]or 0)+qty)end end
 a.effects={hp=0,stamina=0,xp={}}
 local result
 if b.action then local lootBefore=0;for _,g in ipairs(r.world.groundItems)do if g.graveLoot then lootBefore=lootBefore+1 end end;local ok,why=action(a,r.world,b.action);result={ok=ok,reason=why};local lootAfter=0;for _,g in ipairs(r.world.groundItems)do if g.graveLoot then lootAfter=lootAfter+1 end end;if lootAfter<lootBefore then r.world.graveRevision=(r.world.graveRevision or 0)+1;graveRecord(a);a.graveTransition=true end end
 local function visibleGear(eq)local out={};for _,slot in ipairs({'head','body','legs','cape','weapon','offhand'})do if type((eq or{})[slot])=='string'then out[slot]=eq[slot]end end;return out end
 local peers={};for id,other in pairs(actors)do if id~=b.id and clock-other.seen<15 then
  local w=rooms[other.room].world;local o=w.overworld or w
  local mercs={};for _,m in ipairs(other.mercs or{})do mercs[#mercs+1]={name=m.name,x=m.x,y=m.y,race=m.race,frame=m.frame,direction=m.direction,hp=m.hp,deathRegionId=m.deathRegionId,waitingInTown=m.waitingInTown,waitingRegionId=m.waitingRegionId,equipment=visibleGear(m.equipment)}end
  local held=other.player.equipped;local def=other.gather and other.gather.node and w:getDef(other.gather.node.kind);if def and def.tool then held=def.tool end
  peers[#peers+1]={held=held,toolSwing=other.player.toolSwing,headDirection=other.player.headDir,id=id,slot=other.slot,name=other.player.name,race=other.player.race,worldId=Regions.doc.worldId,regionId=o.regionId,area=w.isCave and'cave'or'overworld',caveId=w.isCave and w.entry.id or 0,caveSeed=w.isCave and w.entry.seed or 0,
   hp=other.player.hp,maxHp=other.player.maxHp,x=other.player.x,y=other.player.y,mapX=w.isCave and w.entry.x or other.player.x,mapY=w.isCave and w.entry.y or other.player.y,direction=other.player.bodyDir,frame=other.player.frame,equipment=visibleGear(other.equipment),mercs=mercs}
 end end
 a.religionHighWater=a.skills:get("Religion").xp;local current=(b.action or graveSync or a.graveTransition)and state(a)or{player=a.player,skills=a.skills.data};local delta={hp=current.player.hp-data.player.hp,stamina=current.player.stamina-data.player.stamina,xp={},teleport=pending.teleport,blessed=pending.blessed,materials=pending.materials}
 for k,v in pairs(current.skills)do delta.xp[k]=v.xp-(data.skills[k]and data.skills[k].xp or 0)end
 local events=a.events or{};a.events={};local audio=a.audio or{};a.audio={};a.sentMercs=copy(a.mercs)
 local skillTotals={};for _,name in ipairs({'Fieldcraft','Survival','Foraging'})do skillTotals[name]=a.skills.data[name].xp end
 local reply={fullSnapshot=b.initial==true,adminUpdate=adminUpdate and Pack.pack(adminUpdate),skillTotals=skillTotals,campStorage=Pack.pack((require('game.fieldcraft').owned(r.world,{campOwner=tostring(a.id)..':'..a.slot})or{}).storage or{}),audio=audio,mercs=Pack.pack(a.mercs or{}),status=copy({bonfireBuffUntil=a.player.bonfireBuffUntil or 0,bonfireLastSource=a.player.bonfireLastSource,maxHp=a.player.maxHp,poisonedTimer=a.player.poisonedTimer,poisonTick=a.player.poisonTick,slimeCoated=a.player.slimeCoated}),events=events,seq=b.seq,players=peers,snapshot=wireSnapshot(snapshot(r.world,a.player,b.initial,a)),delta=delta,result=result,personal=(b.action or graveSync or a.graveTransition)and Pack.pack(current)or nil,graveCast=copy(a.graveCast),restartPosition=b.restartPosition,deathCaveExit=b.restartReturn or a.deathCaveExitPending or(graveSync and ledger.deathCaveExit)}
 a.graveTransition=nil;a.deathCaveExitPending=nil;a.lastSeq=b.seq;a.reply=reply;return reply
end
local function tick(b)
 clock=b.time;SG_CLOCK(clock);day:update(b.dt)
 for id,a in pairs(actors)do if clock-a.seen>=(a.fieldcraft and a.fieldcraft.active and 60 or 15)then SG_CAMP('camp_cleanup',{id=id,slot=a.slot}); if rooms[a.room]then rooms[a.room].members[id]=nil end;actors[id]=nil end end
 for _,r in pairs(rooms)do
  r.world._snapshotRows=nil
  require("game.ground_lifetime").update(r.world)
  local members={};for _,a in pairs(r.members)do members[#members+1]=a end
  require('game.bone_religion').update(r.world,b.dt);require('game.gravestones').update(r.world,b.dt);require('game.gravestones').enemyAttacks(r.world,b.dt)
  if #members==0 then require('game.shellfish').update(r.world,b.dt)end
  if #members>0 then
   local w=r.world;local first=members[1];S.activeWorld=w;S.activeActor=first;local before={};for _,a in ipairs(members)do before[a.id]=state(a);a.player.attackCooldown=math.max(0,a.player.attackCooldown-b.dt);a.player.toolSwing=math.max(0,(a.player.toolSwing or 0)-b.dt);a.player.activityTimer=math.max(0,(a.player.activityTimer or 0)-b.dt);if a.player.activityTimer<=0 then a.player.activity=nil end end
   w.onlineActors=members;w.mercs={};for _,owner in ipairs(members)do for _,m in ipairs(owner.mercs or{})do w.mercs[#w.mercs+1]=m end end;w.contentDayTime=day.time;w:setNightState(day:isNight());w.playerRef=first.player;w.gather=nil;w.fishing=nil;w.combatTarget=nil;w.targetedEnemy=nil
   w:update(b.dt,first.player,first.inv,first.skills,first.logger)
   for _,a in ipairs(members)do if a~=first then w:updatePlayerStatus(b.dt,a.player)end end
   w:updateCombat(b.dt,first.player,first.skills,first.equipment,S.sprites,first.logger,first.sockets,first.inv)
   Caves.cleared(w)
   local projectiles=w.magicProjectiles
   for _,a in ipairs(members)do
    w.magicProjectiles={};for _,q in ipairs(projectiles)do if q.onlineOwner==a.id then w.magicProjectiles[#w.magicProjectiles+1]=q end end
    w.playerRef=a.player;require('game.magic_system').update(uiFor(a,w),b.dt)
    require('game.abilities').update(uiFor(a,w),b.dt)
    for _,q in ipairs(w.magicProjectiles)do q._retained=true end
   end
   w.magicProjectiles={};for _,q in ipairs(projectiles)do if q._retained then q._retained=nil;w.magicProjectiles[#w.magicProjectiles+1]=q end end
   for _,a in ipairs(members)do local prior=a.graveEpoch or 0;local hadBags=next(before[a.id].bags or{})~=nil
    if a.player.hp<=0 then w:respawnPlayer(a.player)end
    if a.player.graveDeathPending and w.isCave then local x,y=require('game.respawn').player(w.overworld,w.entry.x,w.entry.y,a.player,a.campOwner);a.player.x,a.player.y=x or w.entry.x,y or w.entry.y+36;a.deathCaveExitPending=true end
    local completed=require("game.gravestones").tickCast(w,a,b.dt)
    if a.player.graveDeathPending or completed==true then a.player.graveDeathPending=nil;graveRecord(a);a.graveTransition=true end;effects(a,before[a.id])end;w.graveDirty=nil
  else require('game.fire_fuel').realtime(r.world,nil,nil);if not r.world.isCave then local night=day:isNight();if r.world._caveNight~=night then r.world._caveNight=night;if night then Caves.ensure(r.world);Caves.replenish(r.world)end end end end
 end
 for _,d in pairs(savedRooms)do require("game.ground_lifetime").update(d)end
 local remove={};for key,r in pairs(rooms)do if r.world.isCave and Caves.cleared(r.world)and not next(r.members)and not next(r.world.gravestones or{})then remove[#remove+1]=key end end;for _,key in ipairs(remove)do local w=rooms[key].world;Caves.remove(w.overworld,w.entry.id);rooms[key]=nil;savedRooms[key]=nil end
 return {ok=true}
end
local function export()
 local Persist=require('game.world_persistence');local all={}
 for key,d in pairs(savedRooms)do all[key]=d end
 for key,r in pairs(rooms)do all[key]=Persist.capture(r.world)end
 return Pack.pack({schemaVersion=Persist.version,boneClaims=require('game.bone_religion').export(),graveLedger=copy(graveLedger),fingerprint=Regions.networkFingerprint,rooms=Persist.normalize(all),dayTime=day.time})
end
function SG_CALL(method,raw)
 local b=J.decode(raw);if method:match('^camp_')or method=='leave'or method=='delete_character'then for _,r in pairs(rooms)do r.world._snapshotRows=nil end end
 if method=='grave_version'then local v={bones=require('game.bone_religion').revision};for key,d in pairs(graveLedger)do v['actor:'..key]=d.graveEpoch end;for key,r in pairs(rooms)do v['room:'..key]=r.world.graveRevision or 0 end;for key,r in pairs(savedRooms)do if not rooms[key]then v['room:'..key]=r.graveRevision or 0 end end;return J.encode(v)elseif method=='grave_ledger'then return J.encode(Pack.pack(graveLedger[tostring(b.id)..':'..b.slot]))elseif method=='delete_character'then local a=actors[b.id];if a and a.slot==b.slot then if clock-a.seen<(a.fieldcraft and a.fieldcraft.active and 60 or 15)then return '{"ok":false}'end;if rooms[a.room]then rooms[a.room].members[b.id]=nil end;actors[b.id]=nil end;for _,r in pairs(rooms)do require('game.lumber').deleteOwner(r.world,tostring(b.id)..':'..b.slot);for _,key in ipairs({'shellfishPots','shellfishParts'})do for i=#(r.world[key]or{}),1,-1 do if r.world[key][i].owner==tostring(b.id)..':'..b.slot then table.remove(r.world[key],i)end end end end;local owner=tostring(b.id)..':'..b.slot;graveLedger[owner]=nil;for _,r in pairs(rooms)do for _,g in ipairs(r.world.gravestones or{})do if g.owner==owner and not g.broken and not g.recovered then require('game.gravestones').breakGrave(r.world,g)end end end;SG_CAMP('camp_cleanup',b);return '{"ok":true}'elseif method=='camp_command'or method=='camp_cleanup'or method=='camp_ping'or method=='camp_prepare'or method=='camp_rollback'or method=='camp_commit'or method=='admin_info'or method=='admin_sync'then return J.encode(SG_CAMP(method,b))elseif method=='export'then return J.encode(export())elseif method=='restore'then local d=Pack.unpack(b);assert(not d.schemaVersion or d.schemaVersion<=3,'Shared-world save schema is newer than this server');if d.fingerprint==Regions.networkFingerprint then require("game.bone_religion").restore(d.boneClaims);graveLedger=d.graveLedger or{};savedRooms=require("game.world_persistence").normalize(d.rooms or{});day.time=d.dayTime or day.time;local keys={};for key in pairs(savedRooms)do keys[#keys+1]=key end;table.sort(keys);for _,key in ipairs(keys)do local region,cave=key:match('^(.-)/cave/(%d+)$');if not cave then room({worldId=Regions.doc.worldId,regionId=key,area='overworld'})end end;for _,key in ipairs(keys)do local region,cave=key:match('^(.-)/cave/(%d+)$');if cave and savedRooms[key]then room({worldId=Regions.doc.worldId,regionId=region,area='cave',caveId=tonumber(cave)})end end end;return '{"ok":true}'elseif method=='exchange_encoded'then local r=exchange(b);SG_EXCHANGE_TOTALS=J.encode(r.skillTotals);return J.encode(r)elseif method=='exchange'then return J.encode(exchange(b))elseif method=='tick'then return J.encode(tick(b))elseif method=='leave'then local a=actors[b.id];if a and a.owner==b.owner then SG_CAMP('camp_cleanup',{id=b.id,slot=a.slot}); if rooms[a.room]then rooms[a.room].members[b.id]=nil end;actors[b.id]=nil end;return '{"ok":true}'end
 error('Unknown simulation method')
end
