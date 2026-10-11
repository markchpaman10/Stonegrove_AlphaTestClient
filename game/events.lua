local E={};local S=require('game.event_schema')
local function copy(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
local function number(v,fallback)return tonumber(v)or fallback or 0 end
local function mapId(w)return w.regionId or(w.map.authored and w.map.authored.regionId)or'root'end
local function state(ui)ui.player.eventState=ui.player.eventState or{variables={},switches={},completed={},positions={},spawned={}};local t=ui.player.eventState;for _,k in ipairs({'variables','switches','completed','positions','spawned'})do t[k]=t[k]or{}end;return t end
local function refs(ui,force)
 E.refs=E.refs or setmetatable({},{__mode='k'});local out=E.refs[ui.world]
 if not out then out={_lists=setmetatable({},{__mode='k'}),_seen=setmetatable({},{__mode='k'}),_counts={}};E.refs[ui.world]=out end
 local groups={npc=ui.world.customNPCs,enemy=ui.world.enemies,merc=ui.world.mercs,guard=ui.world.guards,node=ui.world.nodes,object=ui.world.map.authored and ui.world.map.authored.objects,house=ui.world.houses,quest=ui.world.questNPCs,fire=ui.world.campfires,torch=ui.world.standingTorches,sheep=ui.world.sheep,vendor=ui.world.tradeKeepers,trader=ui.world.traders,healer=ui.world.healers,groundItem=ui.world.groundItems}
 for kind,list in pairs(groups)do if list and(force or out._lists[list]~=#list)then out._lists[list]=#list;for _,a in ipairs(list)do if not out._seen[a]then
  out._seen[a]=true;local name=tostring(a.id or a.customMonster or a.kind or a.name or'*');local key=kind..':'..name;out._counts[key]=(out._counts[key]or 0)+1;out._counts[kind]=(out._counts[kind]or 0)+1
  local value={actor=a,list=list};out[key..'#'..out._counts[key]]=value;out[kind..':*#'..out._counts[kind]]=value;if not out[key]then out[key]=value end
 end end end end;return out
end
function E.resolve(ui,ref)
 if ref=='player'then return ui.player end;local entry=(E.refs and E.refs[ui.world]or refs(ui))[ref];if not entry or entry.actor._eventRemoved then return nil end;return entry.actor,entry.list
end
function E.targets(world)
 local out={};for ref,entry in pairs(refs({world=world}))do if type(entry)=='table'and entry.actor and ref:match('#%d+$')and not ref:find(':*',1,true)and not entry.actor._eventRemoved then out[#out+1]={ref=ref,x=entry.actor.x,y=entry.actor.y,actor=entry.actor}end end
 table.sort(out,function(a,b)return a.ref<b.ref end);return out
end
local function record(ui,ref,a)
 if ref=='player'then return end;local t=state(ui);local id=mapId(ui.world);t.positions[id]=t.positions[id]or{};t.positions[id][ref]={x=a.x,y=a.y,hidden=a.eventHidden,direction=a.direction,race=a.race,equipment=copy(a.equipment),properties=copy(a._eventProperties),removed=a._eventRemoved}
end
local function objectCopies(ui,a,fn)
 local w=ui.world;local groups={w.authoredObjects or{}};local ids={bagKeeper='bagKeepers',skillVendor='tradeKeepers',shopkeeper='tradeKeepers',trader='traders',healer='healers',sheep='sheep',guard='guards',campfire='campfires',house1='houses',house2='houses',modularHouse='houses',modularHouse1='houses',modularHouse2='houses',standingTorch='standingTorches',largeGate='largeGates',watchTower='watchTowers',questGather='questNPCs',questKill='questNPCs',questEscort='questNPCs',questStory='questNPCs',questCave='questNPCs',questCamp='questNPCs'}
 if ids[a.id]then groups[#groups+1]=w[ids[a.id]]or{}end;local customNpc=a.id and a.id:match('^customNPC:(.+)$');local customItem=a.id and a.id:match('^customItem:(.+)$');if customNpc then groups[#groups+1]=w.customNPCs or{}end;if customItem then groups[#groups+1]=w.groundItems or{}end
 for _,list in ipairs(groups)do for i=#list,1,-1 do local p=list[i];if p~=a and p.x==a.x and p.y==a.y and(not p.id or p.id==a.id or customNpc and p.id==customNpc or p.customQuest and a.id:match('^quest'))then fn(p,list,i)end end end
end
local function removeActor(ui,ref,a,list)
 if ref:match('^object:')then
  objectCopies(ui,a,function(p,group,i)p.eventHidden=true;p._eventRemoved=true;table.remove(group,i)end)
  for i=#(ui.world.villages or{}),1,-1 do local v=ui.world.villages[i];if v._authoredProxy and v[a.id]and v[a.id].x==a.x and v[a.id].y==a.y then table.remove(ui.world.villages,i)end end
  ui.world.authoredSelected={};require('game.authored_world').nearest(ui.world,ui.player.x,ui.player.y);ui.world._protectionPerfCache=nil;ui.world.navRefresh=0
 end
 a.eventHidden=true;a._eventRemoved=true;for i,v in ipairs(list or{})do if v==a then table.remove(list,i);break end end;require('game.node_index').invalidate(ui.world)
end
function E.position(ui,ref,x,y,through)
 local a=assert(E.resolve(ui,ref),'Missing actor/object: '..tostring(ref));local oldX,oldY=a.x,a.y
 if not through then assert(ui.world.map:isLand(x,y),'Destination must be land');assert(not require('game.fences').blocked(ui.world,x,y),'Destination is blocked by a fence')end
 if ref:match('^object:')then objectCopies(ui,a,function(p)p.x,p.y=x,y end);ui.world._protectionPerfCache=nil;ui.world.navRefresh=0 end
 a.x,a.y=x,y;if ref=='player'and not through then ui.world:resolvePlayerMovement(a,oldX,oldY)end
 if ref:match('^house:')then ui.world.navRefresh=0 end
 if ref:match('^node:')then require('game.node_index').invalidate(ui.world);ui.world.navRefresh=0 end;record(ui,ref,a);return a
end
local function condition(ui,c)
 local t=state(ui);local value
 if c.test=='switch'then value=t.switches[c.key]or false
 elseif c.test=='skill'then local skill=ui.skills:get(c.key);value=skill and skill.level or 0
 elseif c.test=='item'then value=ui.inv:countItem(c.key)
 elseif c.test=='property'then local ref,key=c.key:match('^(.+)%.([%w_]+)$');local a=E.resolve(ui,ref);if a and a[key]~=nil then value=a[key]else value=0 end
 elseif c.test=='race'then value=ui.player.race
 else value=t.variables[c.key]or 0 end
 local wanted=tonumber(c.value)or c.value;if c.value=='true'then wanted=true elseif c.value=='false'then wanted=false end
 local op=c.compare or'=='
 if op=='=='then return value==wanted elseif op=='!='then return value~=wanted end
 value,wanted=tonumber(value),tonumber(wanted);if not value or not wanted then return false end
 return op=='>='and value>=wanted or op=='<='and value<=wanted or op=='>'and value>wanted or op=='<'and value<wanted
end
local function eligible(ui,e)
 return e.enabled~=false and e.enabled~='false'and(e.map==nil or e.map=='*'or e.map==mapId(ui.world))and(not e.conditionSwitch or e.conditionSwitch==''or state(ui).switches[e.conditionSwitch]==S.boolean(e.conditionValue))and(not e.minSkill or e.minSkill==''or(ui.skills:get(e.minSkill)and ui.skills:get(e.minSkill).level>=number(e.minLevel,1)))
end
function E.start(id,force,resume)
 local e=E.byId and E.byId[id];if not e or E.busy[id]or E.failed[id]or(not resume and not eligible(E.ui,e))then return false end
 if not resume and not force and((e.once~=false and e.once~='false'and state(E.ui).completed[id])or(E.cooldowns[id]or 0)>0)then return false end
 local r={id=id,event=e,pc=1,links={},labels={}};local stack={}
 for i,c in ipairs(e.commands or{})do if c.op=='label'then r.labels[c.name]=i elseif c.op=='if'then stack[#stack+1]={i=i}elseif c.op=='else'then local top=stack[#stack];r.links[top.i]=i+1;top.other=i elseif c.op=='end_if'then local top=table.remove(stack);r.links[top.i]=r.links[top.i]or i+1;if top.other then r.links[top.other]=i+1 end end end
 if resume then for _,k in ipairs({'pc','wait','motion','camMotion','fadeMotion','dialogue','child'})do r[k]=copy(resume[k])end;if resume.ownsCamera then E.cameraOwner=id end;if resume.ownsFade then E.fadeOwner=id end;if resume.message then E.message=copy(resume.message);E.message.owner=r.id end end
 E.running[#E.running+1]=r;E.busy[id]=r;return true
end
local function finish(r,error)
 E.busy[r.id]=nil;r.finished=true;E.cooldowns[r.id]=number(r.event.cooldown,1)
 if error then E.failed[r.id]=true;if E.ui.logger then E.ui.logger:log('EVENT_ERROR',{event=r.id,error=error})end;E.ui.world:addPopup(E.ui.player.x,E.ui.player.y-24,'EVENT ERROR: '..r.id,'miss')
 else state(E.ui).completed[r.id]=true end
 if E.message and E.message.owner==r.id then E.message=nil end
 if E.cameraOwner==r.id then E.camera=nil;E.cameraOwner=nil end
 if E.fadeOwner==r.id then E.fade=0;E.fadeOwner=nil end
end
local function spawn(ui,c,persist)
 local d=assert(require('game.custom_content').npc(c.npc),'Unknown NPC prefab');local npc={id=c.npc,name=d.name or c.npc,x=number(c.x),y=number(c.y),race=require('game.races').normalize(d.race),gender=d.gender,role=d.role,dialogue=d.dialogue,key=d.appearanceKey or d.id,equipment=require('game.custom_content').equipment(d)}
 ui.world.customNPCs[#ui.world.customNPCs+1]=npc;refs(ui,true);if persist then local t=state(ui);local key=mapId(ui.world);t.spawned[key]=t.spawned[key]or{};t.spawned[key][#t.spawned[key]+1]=copy(c)end;return npc
end
local function applyWorld(ui)
 if E.applied[ui.world]then return end;require('game.quests').setup(ui.world);E.applied[ui.world]=true;local t=state(ui);local id=mapId(ui.world)
 for _,c in ipairs(t.spawned[id]or{})do if require('game.custom_content').npc(c.npc)then spawn(ui,c,false)end end
 refs(ui)
 for ref,p in pairs(t.positions[id]or{})do local a=E.resolve(ui,ref);if a then E.position(ui,ref,p.x,p.y,true);a.eventHidden=p.hidden;a.direction=p.direction;a.race=p.race or a.race;if p.equipment then a.equipment=copy(p.equipment)end;for key,value in pairs(p.properties or{})do a[key]=value end;if p.removed then local _,list=E.resolve(ui,ref);removeActor(ui,ref,a,list)end end end
end
function E.init(ui,document)
 E.ui=ui;E.running={};E.busy={};E.failed={};E.cooldowns={};E.touch={};E.queue={};E.refs=setmetatable({},{__mode='k'});E.applied=setmetatable({},{__mode='k'});E.camera=nil;E.message=nil;E.fade=0;E.error=nil;E.cameraOwner=nil;E.fadeOwner=nil;E.cursor=1
 local ok,d=pcall(function()return document or require('event_data')end);d=ok and d or{entries={}};local valid,why=S.validate(d);E.byId={};E.entries={};E.listeners={};if valid then for _,e in ipairs(d.entries)do E.byId[e.id]=e;E.entries[#E.entries+1]=e;E.listeners[e.trigger]=E.listeners[e.trigger]or{};E.listeners[e.trigger][e.target or'']=true end else E.error=why end
 ui.skills.onGain=function(skill,amount)E.notify('skill',skill,{amount=amount})end
 applyWorld(ui);local t=state(ui);for _,resume in ipairs(t.resume or{})do E.start(resume.id,true,resume)end;E.camera=copy(t.camera);E.fade=t.fade or 0
end
function E.notify(trigger,key,data)
 if not E.ui or E.executing or not(E.listeners and E.listeners[trigger]and(E.listeners[trigger][key]or E.listeners[trigger]['*']))then return end
 E.queue[#E.queue+1]={trigger=trigger,key=key,data=data}
end
function E.export(ui)
 local t=copy(state(ui));t.resume={};if E.ui==ui then
  for _,r in ipairs(E.running)do if not r.finished then local snap={id=r.id,ownsCamera=E.cameraOwner==r.id,ownsFade=E.fadeOwner==r.id};for _,k in ipairs({'pc','wait','motion','camMotion','fadeMotion','dialogue','child'})do snap[k]=copy(r[k])end;if E.message and E.message.owner==r.id then snap.message=copy(E.message)end;t.resume[#t.resume+1]=snap end end;t.camera=copy(E.camera);t.fade=E.fade
 end;return t
end
local function step(r)
 local ui=E.ui;local c=(r.event.commands or{})[r.pc];if not c then finish(r);return end;local index=r.pc;r.pc=r.pc+1;local op=c.op;local t=state(ui)
 if op=='message'or op=='choice'then if E.message then r.pc=index;return end;E.message={owner=r.id,speaker=c.speaker or'',text=c.text or'',variable=c.variable,options={},selected=1,page=1};local _,lines=love.graphics.getFont():getWrap(E.message.text,564);E.message.lines=lines;if op=='choice'then for text in (c.options or'Yes|No'):gmatch('[^|]+')do E.message.options[#E.message.options+1]=text end end;r.dialogue=true
 elseif op=='wait'then r.wait=number(c.seconds)
 elseif op=='move'then local a=assert(E.resolve(ui,c.target),'Missing movement target');r.motion={target=c.target,x=a.x,y=a.y,tx=number(c.x),ty=number(c.y),time=0,seconds=math.max(.001,number(c.seconds,1)),through=S.boolean(c.through)}
 elseif op=='teleport'then E.position(ui,c.target,number(c.x),number(c.y),S.boolean(c.through))
 elseif op=='face'then local a=assert(E.resolve(ui,c.target),'Missing facing target');a.direction=c.direction;a.headDir=c.direction;a.bodyDir=c.direction;record(ui,c.target,a)
 elseif op=='camera'then local x,y=ui.player.x,ui.player.y;if E.camera then x,y=E.camera.x,E.camera.y end;E.camera={x=x,y=y};E.cameraOwner=r.id;r.camMotion={x=x,y=y,tx=number(c.x),ty=number(c.y),time=0,seconds=math.max(.001,number(c.seconds,1))}
 elseif op=='camera_follow'then E.camera=nil;E.cameraOwner=nil
 elseif op=='fade'then E.fadeOwner=r.id;r.fadeMotion={from=E.fade or 0,to=math.max(0,math.min(1,number(c.value))),time=0,seconds=math.max(.001,number(c.seconds,1))}
 elseif op=='variable'then local value=tonumber(c.value)or c.value or'';t.variables[c.variable]=c.operation=='add'and(number(t.variables[c.variable])+number(value))or value
 elseif op=='switch'then t.switches[c.variable]=S.boolean(c.value)
 elseif op=='if'then if not condition(ui,c)then r.pc=r.links[index]end
 elseif op=='else'then r.pc=r.links[index]
 elseif op=='jump'then r.pc=assert(r.labels[c.name],'Missing label')
 elseif op=='call'then if E.start(c.event,true)and S.boolean(c.wait)then r.child=c.event end
 elseif op=='stop'then finish(r)
 elseif op=='skill_xp'then assert(ui.skills:get(c.skill),'Missing skill');ui.skills:addXP(c.skill,number(c.amount));ui.player:syncVitals(ui.skills)
 elseif op=='skill_set'then local skill=assert(ui.skills:get(c.skill),'Missing skill');local level=math.floor(number(c.level,1));skill.level=level;skill.xp=ui.skills.xpTable[level];ui.player:syncVitals(ui.skills)
 elseif op=='item'then local qty=math.floor(number(c.amount,1));if qty>=0 then assert(ui.inv:add(c.item,qty),'Inventory full')else assert(ui.inv:countItem(c.item)>=-qty,'Not enough items');ui.inv:removeItems(c.item,-qty)end
 elseif op=='equip'then local a=assert(E.resolve(ui,c.target),'Missing actor');local actor=a==ui.player and ui or a;local slotType=assert(require('game.paperdoll').slots[c.slot],'Invalid equipment slot');if c.item and c.item~=''then local info=assert(ui.sprites.itemInfo[c.item],'Unknown equipment');assert(info.slot==c.slot or info.type==slotType or c.slot=='weapon'and info.type=='Tool','Item does not fit equipment slot')end;require('game.items').setEquipped(actor,c.slot,c.item and c.item~=''and{name=c.item,qty=1}or nil);if a==ui.player and c.slot=='weapon'then a.equipped=actor.equipment.weapon end;record(ui,c.target,a)
 elseif op=='race'then local a=assert(E.resolve(ui,c.target),'Missing actor');assert(require('game.races').valid(c.race),'Invalid race');a.race=c.race;a.cosmetics=nil;if a==ui.player then ui.skills:setRace(c.race);a:syncVitals(ui.skills)end;record(ui,c.target,a)
 elseif op=='vitals'then local a=assert(E.resolve(ui,c.target),'Missing actor');if c.health and c.health~=''then a.hp=math.max(0,math.min(a.maxHp or 100000,number(c.health)))end;if c.stamina and c.stamina~=''then a.stamina=math.max(0,math.min(a.maxStamina or 100000,number(c.stamina)))end;if a~=ui.player then a._eventProperties=a._eventProperties or{};if a.hp~=nil then a._eventProperties.hp=a.hp end;if a.stamina~=nil then a._eventProperties.stamina=a.stamina end;record(ui,c.target,a)end
 elseif op=='property'then local a=assert(E.resolve(ui,c.target),'Missing property target');local key=c.property;assert(key:match('^[%a][%w_]*$'),'Invalid property name');local value=tonumber(c.value)or c.value;if c.value=='true'then value=true elseif c.value=='false'then value=false end;local old=a[key];assert(old~=nil and type(old)~='table'and type(old)~='function'and type(old)==type(value),'Property must exist and keep its original scalar type');assert(key~='x'and key~='y','Use movement commands for coordinates');a[key]=value;a._eventProperties=a._eventProperties or{};a._eventProperties[key]=value;record(ui,c.target,a)
 elseif op=='spawn_npc'then spawn(ui,c,true)
 elseif op=='remove'then local a,list=E.resolve(ui,c.target);assert(a and list,'Player cannot be removed');removeActor(ui,c.target,a,list);record(ui,c.target,a)
 elseif op=='transfer'then assert(require('game.regions').transfer(ui,c.map,number(c.x),number(c.y)),'Invalid destination map');applyWorld(ui)
 elseif op=='sound'then require('game.audio').play(c.sound)
 elseif op=='emit'then E.executing=false;E.notify('signal',c.signal);E.executing=true
 end
end
function E.blocked()
 if E.message then return true end;for _,r in ipairs(E.running or{})do if not r.finished and r.event.blocking~=false and r.event.blocking~='false'and r.event.trigger~='parallel'then return true end end;return false
end
function E.update(ui,dt,camera)
 if E.ui~=ui then E.init(ui)end;applyWorld(ui);if #E.entries>0 then refs(ui)end;for id,time in pairs(E.cooldowns)do E.cooldowns[id]=math.max(0,time-dt)end
 local queue=E.queue;E.queue={};for _,signal in ipairs(queue)do for _,e in ipairs(E.entries)do if e.trigger==signal.trigger and(e.target==signal.key or e.target=='*')then E.start(e.id)end end end
 for _,e in ipairs(E.entries)do if eligible(ui,e)then
  if e.trigger=='autorun'or e.trigger=='parallel'then E.start(e.id)
  elseif e.trigger=='touch'then local inside=(ui.player.x-number(e.x))^2+(ui.player.y-number(e.y))^2<=number(e.radius,24)^2;if inside and not E.touch[e.id]then E.start(e.id)end;E.touch[e.id]=inside end
 end end
 local budget=512
 local count=#E.running;local first=E.cursor or 1;E.cursor=count>0 and(first%count+1)or 1
 for offset=0,count-1 do local r=E.running[(first+offset-1)%count+1];if not r.finished then
  if r.wait then r.wait=r.wait-dt;if r.wait<=0 then r.wait=nil end end
  if r.child and not E.busy[r.child]then r.child=nil end
  local ok,error=pcall(function()
   if r.motion then local m=r.motion;m.time=m.time+dt;local p=math.min(1,m.time/m.seconds);local a=E.position(ui,m.target,m.x+(m.tx-m.x)*p,m.y+(m.ty-m.y)*p,m.through);a.direction=math.abs(m.tx-m.x)>math.abs(m.ty-m.y)and(m.tx>=m.x and'right'or'left')or(m.ty>=m.y and'down'or'up');a.bodyDir=a.direction;a.headDir=a.direction;a.frame=math.floor(m.time/.14)%4+1;if p==1 then assert(m.through or(a.x-m.tx)^2+(a.y-m.ty)^2<1,'Movement route is blocked');a.frame=1;r.motion=nil end end
   if r.camMotion then local m=r.camMotion;m.time=m.time+dt;local p=math.min(1,m.time/m.seconds);E.camera={x=m.x+(m.tx-m.x)*p,y=m.y+(m.ty-m.y)*p};if p==1 then r.camMotion=nil end end
   if r.fadeMotion then local m=r.fadeMotion;m.time=m.time+dt;local p=math.min(1,m.time/m.seconds);E.fade=m.from+(m.to-m.from)*p;if p==1 then r.fadeMotion=nil end end
   local steps=0;while not r.finished and not(r.wait or r.motion or r.camMotion or r.fadeMotion or r.dialogue or r.child)and budget>0 and steps<32 do E.executing=true;step(r);E.executing=false;steps=steps+1;budget=budget-1 end
  end);E.executing=false;if not ok then finish(r,tostring(error))end
 end end
 for i=#E.running,1,-1 do if E.running[i].finished then table.remove(E.running,i)end end
 if E.camera then camera.x,camera.y=E.camera.x,E.camera.y end
 return E.blocked()
end
function E.interact(ui,x,y,priority)
 local storyOnly=priority=='story'
 for _,npc in ipairs(ui.world.interactionNPCs or ui.world.customNPCs or{})do if(npc.x-x)^2+(npc.y-y)^2<20^2 and(npc.x-ui.player.x)^2+(npc.y-ui.player.y)^2<=80^2 then local id=storyOnly and npc.storyEventId or npc.eventId;if id and id~=''and E.start(id)then return true end end end
 if E.blocked()then return true end
 for _,e in ipairs(E.entries or{})do if e.trigger=='interact'and (S.boolean(e.story)==storyOnly)and eligible(ui,e)then local a=e.target and e.target~=''and E.resolve(ui,e.target);local ex,ey=a and a.x or number(e.x),a and a.y or number(e.y)
  if(x-ex)^2+(y-ey)^2<=number(e.radius,24)^2 and(ui.player.x-ex)^2+(ui.player.y-ey)^2<=80^2 then if E.start(e.id)then return true end end
 end end;return false
end
local function dismiss(choice)
 local m=E.message;if not m then return end;if m.variable and m.variable~=''then state(E.ui).variables[m.variable]=choice end;local r=E.busy[m.owner];if r then r.dialogue=nil end;E.message=nil
end
function E.key(key)
 if key=='f9'and E.blocked()then for _,r in ipairs(E.running)do if not r.finished then finish(r)end end;E.queue={};return true end
 local m=E.message;if not m then return E.blocked()end
 if key=='pageup'then m.page=math.max(1,(m.page or 1)-1)elseif key=='pagedown'then m.page=math.min(math.max(1,math.ceil(#(m.lines or{})/5)),(m.page or 1)+1)elseif key=='up'then m.selected=math.max(1,m.selected-1)elseif key=='down'then m.selected=math.min(#m.options,m.selected+1)
 elseif tonumber(key)and m.options[tonumber(key)]then dismiss(tonumber(key))elseif key=='return'or key=='space'then if(m.page or 1)*5<#(m.lines or{})then m.page=(m.page or 1)+1 else dismiss(#m.options>0 and m.selected or 0)end elseif key=='escape'then dismiss(0)end;return true
end
function E.click(x,y,b)
 if not E.message then return E.blocked()end;if b~=1 then return true end;local w,h=love.graphics.getDimensions();local first=math.max(1,E.message.selected-5);local top=h-150-math.min(6,#E.message.options)*25
 for i=first,math.min(#E.message.options,first+5)do if x>=w/2-280 and x<=w/2+280 and y>=top+(i-first)*25 and y<=top+(i-first+1)*25 then dismiss(i);return true end end
 if #E.message.options==0 then E.key('return')end;return true
end
function E.draw()
 local w,h=love.graphics.getDimensions();love.graphics.push('all');if(E.fade or 0)>0 then love.graphics.setColor(0,0,0,E.fade);love.graphics.rectangle('fill',0,0,w,h)end
 local m=E.message;if m then local x=w/2-300;local first=math.max(1,m.selected-5);local top=h-240-math.min(6,#m.options)*25;love.graphics.setColor(.055,.07,.065,.98);love.graphics.rectangle('fill',x,top,600,h-top-30,8,8);love.graphics.setColor(1,.86,.57);love.graphics.print(m.speaker,x+18,top+14);love.graphics.setColor(1,1,1);local lines=m.lines or{m.text};for i=1,5 do local line=lines[((m.page or 1)-1)*5+i];if line then love.graphics.print(line,x+18,top+42+(i-1)*love.graphics.getFont():getHeight())end end;local y=h-150-math.min(6,#m.options)*25;for i=first,math.min(#m.options,first+5)do local text=m.options[i]; love.graphics.setColor(i==m.selected and 1 or .7,.85,.65);love.graphics.print(i..'. '..text,x+20,y+(i-first)*25)end;love.graphics.setColor(.7,.8,.7);love.graphics.print('Enter: next | PgUp/PgDn: pages | Esc: cancel | F9: skip',x+18,h-62)end;love.graphics.pop()
end
return E

