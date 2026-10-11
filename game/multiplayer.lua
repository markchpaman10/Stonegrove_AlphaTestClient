-- Shared-world transactions and interpolated remote characters.
local M={interval=.2,seq=0,ack=0,nextPoll=0,generation=0,status='Connecting to shared world',peers={}}
local V=require('game.presence');local P=require('game.profile');local J=require('game.json')
local function now()return love.timer.getTime()end
local function personal()
 local known={};for _,n in ipairs(ui.world.nodes)do if n.netId and n.prospected then known[n.netId]=n.resourceCycle or 0 end end
 return P.pack({graveEpoch=ui.graveEpoch or 0,potionBelt=ui.potionBelt,knownOre=known,knownPositions=require('game.prospecting').save(ui.world),mercs=ui.world.mercs,player={x=player.x,y=player.y,hp=player.hp,maxHp=player.maxHp,stamina=player.stamina,maxStamina=player.maxStamina,race=player.race,
  headDir=player.headDir,bodyDir=player.bodyDir,frame=player.frame,moving=player.moving,equipped=player.equipped,burst=player.burst,warriorYell=player.warriorYell,poisonImmuneTimer=player.poisonImmuneTimer,slimeCoated=player.slimeCoated,toolSwing=player.toolSwing,activity=player.activity,activityTimer=player.activityTimer},
  gatherTarget=ui.world.gather and ui.world.gather.node and ui.world.gather.node.netId,quests=player.quests,bags=inventory.bagSlots,activeBag=inventory.activeBag,skills=skills.data,equipment=ui.equipment,equipmentItems=ui.equipmentItems,equipmentSockets=ui.equipmentSockets,spellPages=ui.spellPages})
end
local collections={'nodes','enemies','groundItems','sheep','campfires','playerArrows','mercArrows','magicProjectiles','enemyProjectiles','magicEffects','slimePuddles','bossShots','bossPools','goblinShots','goblinArrows','guards','farmAnimals','popups','juiceParticles','shellfishPots','shellfishParts','gravestones','burialGraves'}
local function apply(w,d,initial)
 local known=initial and require('game.prospecting').save(w)
 local structureChanged=initial
 if d.playerCamps and d.campRevision~=w.campRevision then w.playerCamps=d.playerCamps;w.campRevision=d.campRevision;structureChanged=true end
 for _,name in ipairs(collections)do
  local byId,known={},{};for _,e in ipairs(w[name]or{})do if e.netId then byId[e.netId]=e;known[e.netId]=true end end
  local list={};for _,e in ipairs(d[name]or{})do
   local old=byId[e.netId]or{};if name=='nodes'and e.resourceCycle~=(old.resourceCycle or 0)and e.resourceCycle~=nil then old.prospected=false end;for k,v in pairs(e)do if name~='nodes'or(k~='stumpSnow'and k~='snowCovered')then old[k]=v end end;byId[e.netId]=old;list[#list+1]=old
  end
  if initial or(name~='nodes'and name~='enemies'and name~='sheep'and name~='guards')then w[name]=list
  else for _,e in ipairs(list)do if not known[e.netId]then w[name][#w[name]+1]=e;if name=='nodes'then structureChanged=true end end end;local removed=d.removed and d.removed[name];if removed then local gone={};for _,id in ipairs(removed)do gone[id]=true end;for i=#w[name],1,-1 do if gone[w[name][i].netId]then table.remove(w[name],i);if name=='nodes'then structureChanged=true end end end end end
 end
 if dayNight and d.dayTime then dayNight.time=d.dayTime end
 if d.caveChests then w.caveChests=d.caveChests end;if d.goblinCamps then w.goblinCamps=d.goblinCamps end;if d.exit then w.exit=d.exit end
 if d.caveEntrances and not w.isCave then local seeds={};for _,entry in ipairs(d.caveEntrances)do seeds[entry.id]=entry.seed end;for id,cached in pairs(w.caveInstances or{})do if not seeds[id]or not cached.entry or cached.entry.seed~=seeds[id]then w.caveInstances[id]=nil end end;w.caveEntrances=d.caveEntrances end
 if d.caveMap and w.isCave then w.map.mask=d.caveMap;w.map.batch=nil;w.map.terrainRevision=(w.map.terrainRevision or 0)+1;w.arrival=d.arrival;w.entry=d.entry;if not w.map:isLand(player.x,player.y)then player.x,player.y=d.arrival.x,d.arrival.y end end
 if initial then require('game.prospecting').load(w,known)end;if structureChanged then require('game.node_index').invalidate(w);require('game.navigation').refresh(w)end
 for i,st in ipairs(d.stations or{})do local v=w.villages[i];if v then for _,name in ipairs({'tanningVat','hideStretcher'})do for k,x in pairs(st[name]or{})do v[name][k]=x end end end end
end
local function applyDelta(d,full)
 if not full then for name,qty in pairs(d.blessed or{})do if qty<0 then inventory:removeBlessed(name,-qty)end end;local ammo=ui.equipment.ammo;if type(ammo)=='table'and ammo.name=='Rune Bag'then ammo.materials=ammo.materials or{};for name,qty in pairs(d.materials or{})do ammo.materials[name]=math.max(0,(ammo.materials[name]or 0)+qty)end end end
 if d.teleport then player.x,player.y=d.teleport.x,d.teleport.y end
 player.hp=math.max(0,math.min(player.maxHp,player.hp+(d.hp or 0)));player.stamina=math.max(0,math.min(player.maxStamina,player.stamina+(d.stamina or 0)))
 for name,xp in pairs(d.xp or{})do local s=skills.data[name];if s and xp~=0 then local old=s.level;s.xp=math.max(0,s.xp+xp);s.level=skills:levelForXP(s.xp);if s.level>old then skills.pendingLevelUps[#skills.pendingLevelUps+1]={skill=name,level=s.level}end end end
end
function M.stop()
 M.generation=M.generation+1;M.ready=false;M.key=nil;M.room=nil;M.busy=false;M.actionBusy=false;M.queued=nil;M.peers={};V.peers={};M.nextPoll=0;M.status='Disconnected';M.sent=nil;M.retry=nil;M.lastSuccess=nil
end
function M.command(c,callback)
 if M.active and M.ready and ui and(c.kind=='pickup'or c.kind=='pickupAll')then
  for _,g in ipairs(ui.world.groundItems)do if require('game.fieldcraft_content').protected(g.name)and not g.graveLoot and(c.kind=='pickup'and g.netId==c.target or c.kind=='pickupAll'and(g.x-player.x)^2+(g.y-player.y)^2<=80^2)then
   return require('game.fieldcraft_ui').command(ui,{op=c.kind,target=c.target},callback)
  end end
 end
 if ui and ui.campPending then return false,"camp_transaction"end
 if not M.active or not M.ready then if ui then ui.world:addPopup(player.x,player.y-24,'WORLD CONNECTION REQUIRED','miss')end;return false,'connecting' end
 if M.queued and c.kind=='drop'and(M.queued.command.kind=='drop'or M.queued.command.kind=='batch')then
  local command=M.queued.command
  if command.kind=='drop'then command={kind='batch',commands={command}};M.queued.command=command end
  if #command.commands>=64 then return false,'busy'end;command.commands[#command.commands+1]=c;return true,'pending'
 end
 if M.queued or M.actionBusy then return false,'busy'end
 M.queued={command=c,callback=callback};M.actionBusy=true;M.nextPoll=0
 return true,'pending'
end
local function restoreDrops(command)
 if command.kind=='batch'then for _,c in ipairs(command.commands)do restoreDrops(c)end
 elseif command.kind=='drop'then if command.object then inventory:addItemObject(P.unpack(command.object))else inventory:add(command.name,1)end end
end
function M.update(L)
 M.active=L.screen=='game'and L.confirmed and not L.leaving and not L.quitting and L.session and P.active and ui and player
 if not M.active then if M.key then M.stop()end;return end
 local context=V.context(ui.world,player);local key=L.session.server..'|'..L.session.token..'|'..P.active.slot
 if M.key~=key then M.stop();M.key=key;V.session={server=L.session.server,token=L.session.token,id=L.session.id};M.status='Connecting to shared world'end
 local room=context.worldId..'|'..context.regionId..'|'..context.area..'|'..context.caveId
 if room~=M.room then M.room=room;M.ready=false;M.nextPoll=0 end
 if M.lastSuccess and now()-M.lastSuccess>15 then M.ready=false;M.peers={};V.peers={}end
 if M.busy or now()<M.nextPoll or(ui.campPending and not ui.campPending.saving)then return end
 local w=ui.world;local job=M.queued
 if M.retry then context=M.retry.context;job=M.retry.job;w=M.retry.world;room=M.retry.room
 else M.queued=nil;M.seq=M.seq+1;context.worldFingerprint=require('game.regions').networkFingerprint;context.seq=M.seq;context.snapshotVersion=2;context.adminRevision=P.revision;context.slot=P.active.slot;context.initial=not M.ready;context.personal=personal();context.action=job and job.command or nil end
 local generation=M.generation;local started=now();M.busy=true;M.nextPoll=started+M.interval
 require('game.network').request(L.session.server..'/v1/multiplayer','POST',context,L.session.token,function(r)
  if generation~=M.generation then return end;M.busy=false
  M.actionBusy=false
  if r.status==200 and r.data and r.data.seq==context.seq then
   if r.data.seq<=M.ack then return end;M.ack=r.data.seq;M.retry=nil
   if ui.world==w and M.room==room then
    apply(w,P.unpack(r.data.snapshot),context.initial or r.data.fullSnapshot);M.ready=true;w.onlineShared=true
    applyDelta(r.data.delta or{},r.data.personal~=nil)
    ui.graveCast=r.data.graveCast;if ui.graveCast then ui.graveCast.receivedAt=now()end
    if r.data.campStorage then ui.campStorage=P.unpack(r.data.campStorage)end
    for name,xp in pairs(r.data.skillTotals or{})do local s=skills.data[name];local old=s.xp;s.xp=xp;s.level=skills:levelForXP(xp);if xp>old then skills.pendingGains=skills.pendingGains or{};skills.pendingGains[name]=(skills.pendingGains[name]or 0)+xp-old end end
    if r.data.mercs then w.mercs=P.unpack(r.data.mercs)end
    for k,v in pairs(r.data.status or{})do player[k]=v end
    if r.data.personal then local d=P.unpack(r.data.personal);if d.graveEpoch~=ui.graveEpoch then player.x,player.y=d.player.x,d.player.y;player.hp=d.player.hp;player.stamina=d.player.stamina end;ui.graveEpoch=d.graveEpoch or ui.graveEpoch;ui.potionBelt=d.potionBelt or ui.potionBelt;ui.equipmentSockets=d.equipmentSockets or{};player.quests=d.quests or player.quests;inventory.bagSlots=d.bags;inventory.activeBag=d.activeBag;ui.equipment=d.equipment;ui.equipmentItems=d.equipmentItems or{};require('game.quality').bind(ui.equipment,ui.equipmentItems);require('game.tool_slot').bind(ui);player.equipped=d.equipment.weapon;for _,k in ipairs({'toolSwing','activity','activityTimer','attackCooldown','spellCooldowns','abilityCooldowns','healingPulse','healingPulseTick','healingPulseRuneFactor','healingPulseRuneGrade','burst','warriorYell','secondWind','abilityVisual'})do player[k]=d.player[k]end end
    if r.data.adminUpdate then local update=P.unpack(r.data.adminUpdate);if update.revision>P.revision then local d=update.personal;inventory.bagSlots=d.bags;inventory.bank=d.bank;inventory.bankSize=d.bankSize;ui.fieldcraft=d.fieldcraft;skills:load(d.skills);for k,v in pairs(d.player or{})do player[k]=v end;P.acceptAuthoritative(update.revision);if update.destination then require('game.regions').teleport(ui,update.destination.region,update.destination.x,update.destination.y)end;w:addPopup(player.x,player.y-24,'Administrator updated your character','defeat')end end
    if r.data.restartPosition then player.x,player.y=r.data.restartPosition.x,r.data.restartPosition.y end
    if r.data.deathCaveExit and w.isCave then local spawnX,spawnY=player.x,player.y;w.deathRespawn=true;local destination=require('game.caves').leave(ui);player.x,player.y=spawnX,spawnY;world=destination;M.room=nil;M.ready=false end
    for _,event in ipairs(r.data.events or{})do require('game.quests').event(w,event.kind,event.target,event.amount)end
   end
   local old={};for _,p in ipairs(M.peers)do old[p.id]=p end;M.peers={}
   for _,p in ipairs(r.data.players or{})do local previous=old[p.id];p.actor=previous and previous.actor or{};p.fromX=previous and previous.drawX or p.x;p.fromY=previous and previous.drawY or p.y;p.at=now();p.duration=math.max(.1,math.min(.5,now()-started+M.interval));M.peers[#M.peers+1]=p end
   for _,sound in ipairs(r.data.audio or{})do local A=require('game.audio');if sound.method=='play'then A.play(sound.cue,sound.x,sound.y)elseif sound.method=='hurt'then A.hurt(sound.cue,sound.x,sound.y)elseif sound.method=='event'then A.event(sound.cue,sound.data or{})end end
   V.peers=M.peers;V.receivedAt=now();M.lastSuccess=now();M.status='Online • '..tostring(#M.peers+1)..' player'..(#M.peers>0 and's'or'')
   if job then local result=r.data.result or{};if not result.ok then restoreDrops(job.command);if result.reason~='no_stamina'then w:addPopup(player.x,player.y-24,tostring(result.reason or'Action failed'),'miss')else player.attackCooldown=math.max(player.attackCooldown,.35)end end;if job.callback then job.callback(result.ok,result.reason)end end
  else
   M.status=r.status==404 and'Update and restart the developer account server'or((r.data and r.data.error)or'Cannot reach shared world server')
   M.nextPoll=now()+2;M.ready=false
   if r.status==0 or r.status>=500 then M.retry={context=context,job=job,world=w,room=room};M.actionBusy=job~=nil
   elseif job then restoreDrops(job.command)end
   if job then w:addPopup(player.x,player.y-24,'ACTION NOT CONFIRMED — RECONNECTING','miss')end
  end
 end)
 if M.lastSuccess and now()-M.lastSuccess>15 then M.ready=false;M.peers={};V.peers={}end
end
function M.drawActors(w,p,sprites,camera,add,sw,sh)
 local context=V.context(w,p)
 for _,peer in ipairs(M.peers)do if peer.worldId==context.worldId and peer.regionId==context.regionId and peer.area==context.area and peer.caveId==context.caveId then
  local t=math.min(1,math.max(0,(now()-peer.at)/peer.duration));peer.drawX=peer.fromX+(peer.x-peer.fromX)*t;peer.drawY=peer.fromY+(peer.y-peer.fromY)*t
  local actor=peer.actor;actor.x,actor.y=peer.drawX,peer.drawY;actor.race=peer.race;actor.headDir=peer.headDirection or peer.direction or'down';actor.bodyDir=peer.direction or'down';actor.frame=math.max(1,math.min(4,peer.frame or 1));actor.equipped=peer.held or(peer.equipment and peer.equipment.weapon);actor.toolSwing=peer.toolSwing or 0
  add(actor,function()require('game.character_renderer').draw(sprites,actor,peer.equipment or{},{})
   love.graphics.setColor(.7,.94,1);local f=love.graphics.getFont();love.graphics.push();love.graphics.translate(actor.x,actor.y-24);love.graphics.scale(1/camera.zoom);love.graphics.print(peer.name,-f:getWidth(peer.name)/2,0);love.graphics.pop();love.graphics.setColor(1,1,1)
  end)
  for _,merc in ipairs(peer.mercs or{})do if require('game.party').present(w,merc)then local actor=merc;add(actor,function()local dir=actor.direction or'down';require('game.character_renderer').draw(sprites,{x=actor.x,y=actor.y,race=actor.race or'Human',headDir=dir,bodyDir=dir,frame=actor.frame or 1,equipped=actor.equipment and actor.equipment.weapon,toolSwing=0},actor.equipment or{},{})end)end end
 end end
end
function M.pickupClick(w,p,camera,x,y,presses,sw,sh)
 if not M.active then return false end
 local wx,wy=camera:toWorld(x,y,sw,sh);local item=w:groundItemAt(wx,wy)
 if presses>=2 then for _,g in ipairs(w.groundItems)do if(g.x-p.x)^2+(g.y-p.y)^2<=80^2 then item=g;break end end end
 if item then M.command({kind=presses>=2 and'pickupAll'or'pickup',collection='groundItems',target=item.netId});return true end
 return false
end
function M.install(L)
 if M.installed then return end;M.installed=true
 V.update=function()M.update(L)end
 local oldStop=V.stop;V.stop=function()oldStop();M.stop()end
 local W=require('game.world');local update,combat=W.update,W.updateCombat
 W.update=function(w,dt,p,inv,sk,logger)
  if not M.active then return update(w,dt,p,inv,sk,logger)end
  require('game.villages').nearest(w,p.x,p.y)
  if w.workJob then local j=w.workJob;if (p.x-j.x)^2+(p.y-j.y)^2>4 then w.workJob=nil else j.timer=j.timer+dt;if j.timer>=j.duration then w.workJob=nil;j.finish()end end end
  if w.gather and not M.actionBusy then local g=w.gather;g.timer=g.timer-dt;if g.timer<=0 then g.timer=.8;M.command({kind='gather',collection='nodes',target=g.node.netId},function(ok)if not ok or g.node.depleted then w.gather=nil end end)end end
  w:updateFishing(dt,p,sk,inv,logger)
  -- Particle feedback is local; world state and regrowth come from the server.
  for i=#w.juiceParticles,1,-1 do local q=w.juiceParticles[i];q.time=q.time-dt;if q.time<=0 then table.remove(w.juiceParticles,i)end end
 end
 W.updateCombat=function(w,dt,p,sk,equipment,sprites,logger,sockets,inv)
  if not M.active then return combat(w,dt,p,sk,equipment,sprites,logger,sockets,inv)end
  local e=w.combatTarget;if e and e.dead then w:stopCombat('target_defeated',logger)elseif e and p.attackCooldown<=0 and not M.actionBusy and p.stamina<7 then p:staminaWarning(w,logger,'combat');p.attackCooldown=.35 elseif e and p.attackCooldown<=0 and not M.actionBusy then M.command({kind='attack',target=e.netId},function(ok)if ok then p.attackCooldown=(sprites.itemInfo[p.equipped]or{}).attackSpeed or 1.15 end end)end
  for i=#w.popups,1,-1 do local q=w.popups[i];q.time=q.time-dt;q.y=q.y-dt*10;if q.time<=0 then table.remove(w.popups,i)end end
 end
 for name,kind in pairs({createCampfire='fire',addBonfireLog='log',useTanningVat='tanning',useHideStretcher='drying'})do
  local old=W[name];W[name]=function(w,...)
   if not M.active then return old(w,...)end;local args={...};local target=name=='addBonfireLog'and args[6]or nil
   return M.command({kind=kind,fuel=(kind=='fire'and args[5])or(kind=='log'and args[5]),target=target and target.netId,collection='campfires'})
  end
 end
 -- Job wrappers keep the existing cast bars; only the completed job becomes a transaction.
 local Jobs=require('game.world_jobs');for name,kind in pairs({skinAnimal='skin',shearSheep='shear'})do local old=W[name];W[name]=function(w,target,p,...)
  if not M.active then return old(w,target,p,...)end;if w.workJob then return false,'busy'end
  w.workJob={name=kind=='skin'and'Skinning'or'Shearing',timer=0,duration=kind=='skin'and 1.2 or 1.5,x=p.x,y=p.y,finish=function()return M.command({kind=kind,target=target.netId,collection=kind=='skin'and'enemies'or'sheep'})end};return true,'started'
 end end
 local Q=require('game.quests');for name,kind in pairs({accept='questAccept',claim='questClaim'})do local old=Q[name];Q[name]=function(u,n)if not M.active then return old(u,n)end;return M.command({kind=kind,key=n.key})end end
 local cave=require('game.caves');local caveClick=cave.click;cave.click=function(u,x,y)if M.active and u.world.isCave then for i,ch in ipairs(u.world.caveChests or{})do if(ch.x-x)^2+(ch.y-y)^2<22^2 then M.command({kind='chest',index=i});return true end end end;return caveClick(u,x,y)end
 local camps=require('game.goblin_camps');local campClick=camps.click;camps.click=function(w,p,x,y)if M.active then for _,camp in ipairs(w.goblinCamps or{})do local q=camp.cage;if q and not q.open and(x-q.x)^2+(y-q.y)^2<42^2 then M.command({kind='cage',x=x,y=y});return true end end;return false end;return campClick(w,p,x,y)end
 local magic=require('game.magic_system');local cast=magic.cast;magic.cast=function(u,slot)if not M.active then return cast(u,slot)end;local healing=(magic.spells[(u.spellPages or{})[slot]]or{}).heal;local T=require('game.player_target');local peer=healing and T.resolve(u);if healing and T.id and not peer then u.world:addPopup(u.player.x,u.player.y-24,'HEALING TARGET UNAVAILABLE','miss');return false,'no_target'end;return M.command({kind='spell',slot=slot,healPlayerId=peer and peer.id,target=(u.world.combatTarget or u.world.targetedEnemy or{}).netId})end
 local ability=require('game.abilities');local castAbility=ability.cast;ability.cast=function(u,name)if not M.active then return castAbility(u,name)end;return M.command({kind='ability',name=name})end
 local U=require('game.ui');local updateUi=U.updateMagic;U.updateMagic=function(u,dt)if M.actionBusy then return end;return updateUi(u,dt)end
 local updateAbility=ability.update;ability.update=function(u,dt)if not M.active then return updateAbility(u,dt)end;for _,k in ipairs({'secondWind','burst','healingPulse','warriorYell'})do u.player[k]=math.max(0,(u.player[k]or 0)-dt)end;for k,t in pairs(u.player.abilityCooldowns or{})do u.player.abilityCooldowns[k]=math.max(0,t-dt)end;if u.player.abilityVisual then u.player.abilityVisual.t=u.player.abilityVisual.t+dt;if u.player.abilityVisual.t>=u.player.abilityVisual.duration then u.player.abilityVisual=nil end end end
 local addGround=W.addGroundItem;W.addGroundItem=function(w,name,x,y,lit,obj)if not M.active then return addGround(w,name,x,y,lit,obj)end;return M.command({kind='drop',name=name,object=obj and P.pack(obj)})end
 local draw=love.draw;love.draw=function(...)if M.active and not M.ready then local g=love.graphics;g.clear(.055,.07,.06);g.setColor(1,1,1);g.printf('Loading shared world… '..M.status,40,g.getHeight()/2,g.getWidth()-80,'center');require('game.pause_menu').draw();require('game.options_menu').draw();return end;draw(...);if M.active then local g=love.graphics;local sw,sh=g.getDimensions();g.setColor(.025,.04,.06,.9);g.rectangle('fill',12,sh-31,math.min(sw-24,560),23,4,4);g.setColor(M.ready and .65 or 1,M.ready and .95 or .65,M.ready and .75 or .45);g.printf(M.status,20,sh-27,math.min(sw-40,540),'left');g.setColor(1,1,1)end end
end
return M

