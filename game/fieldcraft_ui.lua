local M={};local F=require('game.fieldcraft');local C=require('game.fieldcraft_content');local R=require('game.rune_inventory')
local function actor(u)return {campOwner=require('game.profile').active and(tostring(require('game.profile').active.id)..':'..require('game.profile').active.slot)or'offline',player=u.player,inv=u.inv,skills=u.skills,equipment=u.equipment,fieldcraft=u.fieldcraft or{},target=u.world.combatTarget}end
local function hit(mx,my,x,y,w,h)return mx>=x and my>=y and mx<x+w and my<y+h end
function M.command(u,cmd,done)
 if u.craftJob or u.magicCast or u.world.workJob then u.world:addPopup(u.player.x,u.player.y-24,"Finish your current action first");return false end
 local mp=require('game.multiplayer');local p=require('game.profile')
 if not mp.active and not p.active and not u.world.onlineShared then local a=actor(u);local ok,why
  if cmd.op:match('^container')then ok,why=require('game.lumber').command(u.world,a,cmd)
  elseif cmd.op=='starterBag'then ok,why=require('game.bag_keeper').claim(u.world,a,cmd)
  elseif cmd.op=='fishProcess'then ok,why=require('game.high_tier_fish').command(u.world,a,cmd)
  elseif cmd.op:match('^bone')then ok,why=require('game.bone_religion').command(u.world,a,cmd)
  elseif cmd.op=='admin'then local dest;cmd.serverAdmin=true;ok,why,dest=require('game.admin_rules').execute(u.world,a,cmd,u.sprites);if dest then require('game.regions').teleport(u,dest.region,dest.x,dest.y)end
  elseif cmd.op=='craft'then ok,why=u.crafting:craft(cmd.station,cmd.index,u.inv,u.skills,u.logger,u.equipment.weapon,u.world,u.player)
  elseif cmd.op=='leaves'then local trial=R.clone(u.inv);ok=trial:removeItems('Bush Greens',1)and trial:add('Bush Leaves',1);why=ok and'Bush Leaves'or'Need Bush Greens and bag space';if ok then u.inv.bagSlots=trial.bagSlots;u.skills:addXP('Fieldcraft',4)end
  elseif cmd.op:match('^pot')or cmd.op:match('^shell')then ok,why=require('game.shellfish').command(u.world,a,cmd)
  else ok,why=F.command(u.world,a,cmd)end
  u.fieldcraft=a.fieldcraft;require('game.save').write(u.player,u.inv,u.skills,u,u.logger);u.world:addPopup(u.player.x,u.player.y-24,tostring(why),ok and'defeat'or'miss');if done then done(ok)end;return ok
 end
 if not mp.active or not mp.ready then u.world:addPopup(u.player.x,u.player.y-24,'Connect to the shared world before using camp actions','miss');return false end
 if u.campPending then return false end
 u.campPending={command=cmd,done=done,saving=true,shop=(cmd.op=='sellMaterial'or cmd.op=='buyMaterial'or cmd.op=='sellInventory')and u.shop or nil};require('game.save').write(u.player,u.inv,u.skills,u,u.logger);return true
end
local function request(u,job)
 local p=require('game.profile');local session=p.session;local id=tostring(os.time())..':'..tostring(love.timer.getTime())..':'..tostring(math.random(1,1e8))
 local function send(cmd,callback)
  require('game.network').request(session.server..'/v1/camp','POST',{slot=p.active.slot,request=id,revision=p.revision,command=cmd},session.token,function(response)
   if response.status==0 or response.status>=500 then job.retryAt=love.timer.getTime()+2;job.retry=function()send(cmd,callback)end;job.finishing=true;return end
   job.retry=nil;job.retryAt=nil;callback(response)
  end)
 end
 local cmd=job.command;local timed=cmd.op=='carveFeather'or cmd.op=='fishProcess'or cmd.op:match('^bone')or cmd.op=='fireCreate'or cmd.op=='fireRefuel'or cmd.op=='potPlace'or cmd.op=='potRecover'or cmd.op=='shellHarvest'or cmd.op=='shellFillet'or cmd.op=='craft'or cmd.op=='leaves'or cmd.op=='build'or cmd.op=='enchant'
 local function finished(response)
  u.campPending=nil;local data=response.data or{};local ok=response.status==200 and data.ok
  if ok and data.state and(data.revision or 0)>p.revision then local d=p.unpack(data.state);if d.potionBelt then u.potionBelt=d.potionBelt end;u.inv.bagSlots=d.bags;u.inv.bank=d.bank;u.inv.bankSize=d.bankSize;u.fieldcraft=d.fieldcraft;if d.hp then u.player.hp=d.hp end;for k,v in pairs(d.status or{})do u.player[k]=v end
   for name,s in pairs(d.skills)do local old=u.skills.data[name];local gained=s.xp-old.xp;u.skills.data[name]=s;if gained>0 then if u.skills.onGain then u.skills.onGain(name,gained)end;u.skills.pendingGains=u.skills.pendingGains or{};u.skills.pendingGains[name]=(u.skills.pendingGains[name]or 0)+gained end end
   if data.shopSlots and job.shop then job.shop.slots=p.unpack(data.shopSlots)end
   if data.adminPlayer then local values=p.unpack(data.adminPlayer);for k,v in pairs(values)do u.player[k]=v end end
   if data.destination then require('game.regions').teleport(u,data.destination.region,data.destination.x,data.destination.y)end
   p.revision=data.revision;local camp=data.camp and p.unpack(data.camp);u.campStorage=type(camp)=='table'and type(camp.storage)=='table'and camp.storage or{};
  end
  u.world:addPopup(u.player.x,u.player.y-24,data.reason or data.error or'Camp request failed',ok and'defeat'or'miss');if job.done then job.done(ok)end
 end
 if timed then send({op='begin',next=cmd},function(response)
  if response.status~=200 then finished(response);return end
  u.campPending.waiting=true;u.craftJob={name=cmd.op=='carveFeather'and'Carving feather'or cmd.op=='fishProcess'and'Processing fish'or cmd.op=='fireCreate'and'Lighting fire'or cmd.op=='fireRefuel'and'Adding bonfire fuel'or cmd.op=='potPlace'and'Placing pot'or cmd.op=='potRecover'and'Recovering pot'or cmd.op=='shellHarvest'and'Harvesting parts'or cmd.op=='shellFillet'and'Breaking shellfish'or cmd.op=='build'and'Camp construction'or cmd.op=='leaves'and'Cutting Bush Leaves'or'Tent / camp crafting',timer=0,duration=response.data.duration,x=u.player.x,y=u.player.y,finish=function()u.campPending.finishing=true;id=id..':complete';send(cmd,finished)end}
 end)else send(cmd,finished)end
end
function M.update(u)
 if u.campBank and not M.nearStation(u,"bank")then u.campBank=nil;u.open.bank=false end
 local j=u.campPending
 if j and not j.pingBusy and love.timer.getTime()>=(j.pingAt or 0)then local p=require('game.profile');if p.active then j.pingBusy=true;j.pingAt=love.timer.getTime()+5;require('game.network').request(p.session.server..'/v1/camp/ping','POST',{slot=p.active.slot},p.session.token,function()j.pingBusy=false end)end end
 if j and j.retry and love.timer.getTime()>=(j.retryAt or 0)then local retry=j.retry;j.retry=nil;retry()end;local p=require('game.profile')
 if j and j.saving and not p.pending and not p.busy and not require('game.multiplayer').busy and not require('game.multiplayer').actionBusy then j.saving=false;request(u,j)end
 if j and j.waiting and not u.craftJob and not j.finishing then -- A cancelled cast has no inventory consequences.
  j.cancelTimer=(j.cancelTimer or 0)+.05;if j.cancelTimer>2 then u.campPending=nil end
 end
end
function M.nearStation(u,name)
 for _,c in ipairs(u.world.playerCamps or{})do for _,s in ipairs(c.structures or{})do if C.structure(s.id).station==name and(s.x-u.player.x)^2+(s.y-u.player.y)^2<=55^2 then return true end end end;return false
end
function M.drawables(u,camera,add)
 local g=love.graphics;local fields={woodcraft='bankChestImage',leathercraft='bankChestImage',tailoring='tailorTableImage',inscription='inscriptionTableImage',alchemy='alchemyMortarImage'}
 for _,camp in ipairs(u.world.playerCamps or{})do local c=camp
  add(c.y+6,function()local img=u.sprites.itemImages[c.tent];if img then local iw,ih=img:getDimensions();g.setColor(1,1,1);g.draw(img,c.x,c.y,0,c.tent=='Cover Tent'and 1 or 2,c.tent=='Cover Tent'and 1 or 2,iw/2,ih/2)end end,c.x)
  for _,structure in ipairs(c.structures or{})do local st=structure;local def=C.structure(st.id)
   if st.id~='fire'then add(st.y+7,function()local image=u.sprites[fields[def.station]or(def.station and(def.station..'Image')or'bankChestImage')]or u.sprites.bankChestImage;local quad=def.station and u.sprites[def.station..'Quad'];local iw,ih=image:getDimensions();g.setColor(1,1,1);if quad then g.draw(image,quad,st.x,st.y,0,1,1,8,8)else g.draw(image,st.x,st.y,0,1,1,iw/2,ih/2)end end,st.x)end
  end
 end
end
function M.worldDraw(u,camera)
 local g=love.graphics
 if u.campPlacement then local w,h=g.getDimensions();local mx,my=love.mouse.getPosition();local x,y=camera:toWorld(mx,my,w,h);x=math.floor(x/8)*8;y=math.floor(y/8)*8;local a=actor(u);local ok,why=F.valid(u.world,a,u.campPlacement.tent,x,y);local t=C.tents[u.campPlacement.tent];u.campPlacement.x,u.campPlacement.y=x,y
  g.setColor(ok and .15 or 1,ok and .9 or .15,.2,.25);g.rectangle('fill',x-t.width/2,y-t.height/2,t.width,t.height);g.setColor(ok and .15 or 1,ok and .9 or .15,.2,.85);g.rectangle('line',x-t.width/2,y-t.height/2,t.width,t.height)
  local img=u.sprites.itemImages[u.campPlacement.tent];local iw,ih=img:getDimensions();g.setColor(1,1,1,.55);g.draw(img,x,y,0,u.campPlacement.tent=='Cover Tent'and 1 or 2,u.campPlacement.tent=='Cover Tent'and 1 or 2,iw/2,ih/2);u.campPlacement.reason=ok and'Click to deploy; Escape / right-click cancels'or why
 end
 if u.campSelected then local a=actor(u);local c=F.owned(u.world,a);local def=C.structure(u.campSelected)
  if c and def then for slot=1,5 do local x,y=F.slot(c,slot);local valid=u.skills:get('Fieldcraft').level>=def.level and slot<=C.slots(u.skills:get('Fieldcraft').level,c.tent)
   for _,st in ipairs(c.structures)do if st.slot==slot or st.id==def.id then valid=false end end
   if not F.config(a).built[def.id]then for _,n in ipairs(def.needs)do if u.inv:countItem(n[1])<n[2]then valid=false end end end
   g.setColor(valid and .1 or 1,valid and .9 or .15,.2,.45);g.rectangle('fill',x-11,y-11,22,22);g.setColor(1,1,1);g.push();g.translate(x,y-28);g.scale(1/camera.zoom);g.printf('Slot '..slot,-35,0,70,'center');g.pop()
  end end
 end;g.setColor(1,1,1)
end
function M.worldClick(u,camera,x,y,button)
 if u.campPlacement then if button==2 then u.campPlacement=nil;return true end;if button==1 then local p=u.campPlacement;M.command(u,{op='deploy',tent=p.tent,x=p.x,y=p.y},function(ok)if ok then u.campPlacement=nil end end);return true end end
 local w,h=love.graphics.getDimensions();local wx,wy=camera:toWorld(x,y,w,h)
 if u.campSelected then
  if button==2 then u.campSelected=nil;return true end
  local c=F.owned(u.world,actor(u));if c and button==1 then for slot=1,5 do local sx,sy=F.slot(c,slot);if(sx-wx)^2+(sy-wy)^2<=14^2 then M.timedOffline(u,{op='build',structure=u.campSelected,slot=slot});return true end end end
 end
 for _,c in ipairs(u.world.playerCamps or{})do
  for _,s in ipairs(c.structures or{})do if(s.x-wx)^2+(s.y-wy)^2<16^2 and(s.x-u.player.x)^2+(s.y-u.player.y)^2<=55^2 then local def=C.structure(s.id);if def.station=='bank'then u.campBank=true;u:openBank('camp_bank')elseif def.station then u.campStation={owner=c.owner,id=s.id,station=def.station};u:openCrafting(def.station,'camp_facility')end;return true end end
  if(wx-c.x)^2+(wy-c.y)^2<25^2 then if c.owner==actor(u).campOwner then u.open.fieldcraft=true;u.campTab=2;u:bringToFront('fieldcraft')else u.world:addPopup(u.player.x,u.player.y-24,c.name..': stations are shared; storage is private')end;return true end
 end;return false
end
function M.install(U)
 local H=require('game.help');local help=H.world;H.world=function(u,x,y)
  for _,c in ipairs(u.world.playerCamps or{})do
   for _,st in ipairs(c.structures or{})do if(st.x-x)^2+(st.y-y)^2<16^2 then local def=C.structure(st.id);return H.tip(def.name,'Fieldcraft level '..def.level..'. '..(def.storage and('Adds '..def.storage..' owner-only storage slots.')or def.station=='bank'and'Access your real character bank. Available to nearby players.'or'Click nearby to use this shared crafting facility.'))end end
   if(c.x-x)^2+(c.y-y)^2<25^2 then return H.tip(c.name,c.tent..'. Owner-only storage. Click your Tent for construction, storage and packing. '..C.warning)end
  end;return help(u,x,y)
 end
 local new=U.new;U.new=function(...)local u=new(...);u.pos.fieldcraft={x=100,y=90};u.pos.tentcraft={x=100,y=90};u.fieldcraft={layout={},built={},recovery={}};require('game.fieldcraft').bind(u.world,actor(u));u.open.fieldcraft=false;u.campTab=1;u.campScroll=0;u.zOrder[#u.zOrder+1]='fieldcraft';return u end
 local rect=U.rect;U.rect=function(u,name)if name=='fieldcraft'then local p=u.pos.fieldcraft;return p.x,p.y,680,510 end;return rect(u,name)end
 local options=U.contextOptions;U.contextOptions=function(u,it)local out=options(u,it);if C.tents[it.name]then table.insert(out,1,'Deploy Camp')end;if u.open.fieldcraft and u.campTab==2 then table.insert(out,1,'Store in Camp')end;return out end
 local context=U.doContextOption;U.doContextOption=function(u,opt)
  if opt=='Deploy Camp'then local c=u.context;local obj=u.inv:getBag(c.bag).slots[c.slot];if u.skills:get('Fieldcraft').level<C.tents[obj.name].level then u.world:addPopup(u.player.x,u.player.y-24,'Fieldcraft level '..C.tents[obj.name].level..' required');return end;u.campPlacement={tent=obj.name};u.context=nil;u.world:addPopup(u.player.x,u.player.y-24,C.warning);return end
  if opt=='Store in Camp'then local c=u.context;M.command(u,{op='deposit',bag=c.bag,slot=c.slot});u.context=nil;return end;return context(u,opt)
 end
 local sellInventory=U.sellShopInventory;U.sellShopInventory=function(u)
  if require('game.multiplayer').active then local group,index='shopkeeper',1;for _,key in ipairs({'tradeKeepers','traders'})do for i,n in ipairs(u.world[key]or{})do if n.shop==u.shop then group,index=key,i end end end;return M.command(u,{op='sellInventory',vendorGroup=group,vendorIndex=index})end
  return sellInventory(u)
 end
 local shopContext=U.doShopContext;U.doShopContext=function(u,opt)
  local c=u.shopContext;local obj=c and u.shop and u.shop.slots[c.slot]
  if opt~='Cancel'and require('game.multiplayer').active and obj and C.sellable(obj.name)then
   local group,index='shopkeeper',1
   for _,key in ipairs({'tradeKeepers','traders'})do for i,n in ipairs(u.world[key]or{})do if n.shop==u.shop then group,index=key,i end end end
   M.command(u,{op='buyMaterial',slot=c.slot,name=obj.name,qty=opt=='Buy 1'and 1 or opt=='Buy 10'and 10 or'all',vendorGroup=group,vendorIndex=index});u.shopContext=nil;return
  end
  return shopContext(u,opt)
 end
 local oldEat=U.doContextOption;U.doContextOption=function(u,opt)
 if opt:sub(1,4)=='Sell'and require('game.multiplayer').active and u.context then
  local c=u.context;local bag=u.inv:getBag(c.bag);local obj=bag and bag.slots[c.slot]
  if obj and C.sellable(obj.name)then
   local group,index='shopkeeper',1
   for _,key in ipairs({'tradeKeepers','traders'})do for i,n in ipairs(u.world[key]or{})do if n.shop==u.shop then group,index=key,i end end end
   M.command(u,{op='sellMaterial',bag=c.bag,slot=c.slot,name=obj.name,all=opt:sub(1,8)=='Sell All',vendorGroup=group,vendorIndex=index});u.context=nil;return
  end
 end
 if opt:find('Enchant with ',1,true)==1 and require('game.multiplayer').active and M.nearStation(u,'enchantAltar')and u.context then local c=u.context;local obj=u.inv:getBag(c.bag).slots[c.slot];local qty=opt=='Enchant with 1 Dust'and 1 or opt=='Enchant with 5 Dust'and math.min(5,obj.qty or 1)or(obj.qty or 1);u.context=nil;return u:enchantGemWithDust(qty)end
 if opt=='Drop'and require('game.multiplayer').active and u.context then local c=u.context;local b=u.inv:getBag(c.bag);local it=b and b.slots[c.slot];if it and C.protected(it.name)then M.command(u,{op='drop',bag=c.bag,slot=c.slot});u.context=nil;return end end
 if opt=='Eat'and require('game.multiplayer').active and u.context then local ctx=u.context;M.command(u,{op='eat',bag=ctx.bag,slot=ctx.slot});u.context=nil;return end
 if opt=='Eat'and u.context then local ctx=u.context;local b=u.inv:getBag(ctx.bag);local it=b and b.slots[ctx.slot];local before=it and u.inv:countItem(it.name);oldEat(u,opt);if it and u.inv:countItem(it.name)<before then local a=actor(u);require('game.survival_foraging').food(a,it.name);u.fieldcraft=a.fieldcraft end;return end;return oldEat(u,opt)end
 local compatible=U.isUseCompatible;U.isUseCompatible=function(u,tool,it)if(tool=='Copper Knife'or tool=='Copper Dagger')and it.name=='Bush Greens'then return true end;return compatible(u,tool,it)end
 local use=U.performItemUse;U.performItemUse=function(u,bag,slot)local b=u.inv:getBag(bag);local it=b and b.slots[slot];if it and it.name=='Bush Greens'and u.useTarget and(u.useTarget.tool=='Copper Knife'or u.useTarget.tool=='Copper Dagger')then u.useTarget=nil;M.command(u,{op='leaves'});return end;return use(u,bag,slot)end
 local enchant=U.enchantGemWithDust;U.enchantGemWithDust=function(u,qty)
  if require('game.multiplayer').active and M.nearStation(u,'enchantAltar')then local g,p=u.enchantGem,u.enchantPage;if not g or not p then return false,'no_selection'end
   local def=require('game.enchanting').gems[g.name:match('^Cut (%a+)$')];qty=math.min(qty,def and def.maxDust or qty);return M.command(u,{op='enchant',qty=qty,gemBag=g.bag,gemSlot=g.slot,pageBag=p.bag,pageSlot=p.slot},function(ok)if ok then u.enchantGem=nil;u.enchantPage=nil end end)
  end;return enchant(u,qty)
 end
 local start=U.startCraft;U.startCraft=function(u,station,index)local r=u.crafting:getRecipes(station)[index];if r and require('game.multiplayer').active and(r.lumber or r.fieldcraft or r.bagRecipe or u.campStation and u.campStation.station==station)then return M.command(u,{op='craft',station=station,index=index},function(ok)if ok then u:craftBatchDone(station,index);if u.open[station]then u:startCraft(station,index)end else u.craftLimit=nil end end)end;return start(u,station,index)end
 local update=U.updateMagic;U.updateMagic=function(u,dt)update(u,dt);M.update(u)end
 local drawSkills=U.drawSkills;U.drawSkills=function(u)if u.skillGuide=='Fieldcraft'then u.open.fieldcraft=true;u.skillGuide=nil;u:bringToFront('fieldcraft')end;return drawSkills(u)end
 -- Rendering participates in the existing window order and tooltip pass.
 local press=U.mousepressed;U.mousepressed=function(u,x,y,button,w,h)
  if u.open.fieldcraft and not u.context and u:panelAt(x,y)=='fieldcraft'then local px,py,pw,ph=u:rect('fieldcraft');local sc=(u.panelScales or{}).fieldcraft or 1;if hit(x,y,px,py,pw*sc,ph*sc)then
   if button==1 and hit(x,y,px+pw*sc-18,py+ph*sc-18,18,18)then u.panelResize={key='fieldcraft',x=px,y=py,w=pw,h=ph};return true end
   x,y=px+(x-px)/sc,py+(y-py)/sc
   if y<py+28 then if x>px+pw-28 then u.open.fieldcraft=false else u.panelMove={key='fieldcraft',ox=(x-px)*sc,oy=(y-py)*sc}end;return true end
   if y<py+65 then u.campTab=math.max(1,math.min(4,math.floor((x-px-12)/160)+1));u.campScroll=0;return true end
   for _,b in ipairs(u.campButtons or{})do if hit(x,y,b.x,b.y,b.w,b.h)then b.fn();return true end end;return true
  end end;return press(u,x,y,button,w,h)
 end
 local released=U.mousereleased;U.mousereleased=function(u,mx,my,button,w,h)
  if button==1 and u.dragSlot and u.open.fieldcraft and u.campTab==2 then local x,y,pw,ph=u:rect('fieldcraft');local sc=(u.panelScales or{}).fieldcraft or 1;if hit(mx,my,x,y,pw*sc,ph*sc)then local bag,slot=u.dragBagIndex,u.dragSlot;u.dragSlot=nil;u.dragBagIndex=nil;M.command(u,{op='deposit',bag=bag,slot=slot});return true end end
  return released(u,mx,my,button,w,h)
 end
 local wheel=U.wheelmoved;U.wheelmoved=function(u,dx,dy,mx,my)if u.open.fieldcraft and hit(mx,my,u:rect('fieldcraft'))then u.campScroll=math.max(0,(u.campScroll or 0)-dy);return true end;return wheel(u,dx,dy,mx,my)end
end
function M.draw(u,w,h)
 local g=love.graphics;local x,y,pw,ph=u:rect('fieldcraft');local sc=(u.panelScales or{}).fieldcraft or 1;g.push('all');g.translate(x,y);g.scale(sc);g.translate(-x,-y)
 g.setColor(.05,.065,.055,.98);g.rectangle('fill',x,y,pw,ph,6);g.setColor(.62,.72,.46);g.rectangle('line',x,y,pw,ph,6);g.setColor(1,.9,.65);g.print('Fieldcraft â€” Level '..u.skills:get('Fieldcraft').level,x+12,y+8);g.print('X',x+pw-22,y+8);u.campButtons={}
 local function button(text,bx,by,bw,bh,fn,icon)g.setColor(.16,.23,.15);g.rectangle('fill',bx,by,bw,bh,3);g.setColor(.95,.95,.85);if icon then u:drawItemSprite(icon,bx+3,by+2,28);g.setColor(.95,.95,.85)end;g.printf(text,bx+(icon and 35 or 5),by+7,bw-(icon and 40 or 10),'left');if icon then local mx,my=love.mouse.getPosition();mx,my=x+(mx-x)/sc,y+(my-y)/sc;if hit(mx,my,bx,by,bw,bh)then u.hoverTooltip={item=icon}end end;u.campButtons[#u.campButtons+1]={x=bx,y=by,w=bw,h=bh,fn=fn}end
 for i,text in ipairs({'Craft Tents','Camp Construction','Camp Layout','Unlocks (1â€“99)'})do button(text,x+12+(i-1)*160,y+34,154,28,function()u.campTab=i;u.campScroll=0 end)end
 local a=actor(u);local c=F.owned(u.world,a);local d=F.config(a);u.fieldcraft=d
 if u.campTab==1 then
  for i,name in ipairs({'Cover Tent','Leather Drape Tent','Lean-to'})do local t=C.tents[name];local yy=y+80+(i-1)*100;g.setColor(1,1,1);local img=u.sprites.itemImages[name];g.draw(img,x+24,yy,0,2,2);g.print(name..' â€” Lv '..t.level..' â€” '..t.storage..' slots â€” '..t.xp..' XP',x+115,yy);g.printf(C.available(u.inv,t.needs)..(t.alternative and('\nOR '..C.available(u.inv,t.alternative))or''),x+115,yy+24,550,'left')
   local recipes=u.crafting:getRecipes('fieldcraft');for index,r in ipairs(recipes)do if r.output==name then local ix=index;button(r.name,x+115+(r.name:find('Large Leather',1,true)and 260 or 0),yy+58,250,28,function()u.open.fieldcraft=false;u.pos.fieldcraft=u.pos.fieldcraft or{x=100,y=90};u.open.fieldcraft=true;M.timedOffline(u,{op='craft',station='fieldcraft',index=ix})end)end end
  end
 elseif u.campTab==2 then
  g.setColor(1,1,1);g.print(c and(c.name..' â€” '..c.tent..' â€” '..F.capacity(a,c)..' storage slots')or'Right-click a crafted Tent in your bags to deploy.',x+14,y+78)
  if c then
   button('Pack Up Camp',x+14,y+105,155,28,function()M.command(u,{op='pack'})end);button('Rest (+5 XP / 5 min)',x+180,y+105,190,28,function()M.command(u,{op='rest'})end)
   local online=require('game.profile').active~=nil or require('game.multiplayer').active or u.world.onlineShared
   local storage=online and u.campStorage or c.storage
   if type(storage)~='table'then storage={}end
   local first=math.min(u.campScroll or 0,math.max(0,F.capacity(a,c)-12));u.campScroll=first
   for i=1,math.min(12,F.capacity(a,c)-first)do local v=storage[first+i];local index=first+i;button(v and(v.name..' x'..(v.qty or 1))or('Empty slot '..index),x+14+((i-1)%3)*216,y+145+math.floor((i-1)/3)*38,208,32,function()if v then M.command(u,{op='withdraw',slot=index})end end,v)end
   g.setColor(.85,.8,.62);g.printf('Right-click a bag item: Store in Camp. Owner-only. Empty all storage before packing.',x+14,y+320,650,'left')
  end
  button('Recover items from lost camps',x+14,y+368,320,30,function()M.command(u,{op='recover'})end)
 elseif u.campTab==3 then
  g.setColor(1,1,1);g.print(c and('Choose a structure, then click an empty slot. '..C.slots(a.skills:get('Fieldcraft').level,c.tent)..' available slots.')or'Deploy a camp to build. Earned structures and layouts survive Tent loss.',x+14,y+78)
  for i=1,5 do local ix=i;local id=d.layout[i];local def=C.structure(id);button('Slot '..i..': '..(def and def.name or'Empty'),x+14+(i-1)*130,y+106,124,48,function()if u.campSelected then M.timedOffline(u,{op='build',structure=u.campSelected,slot=ix})else M.command(u,{op='layout',slot=ix})end end)end
  local first=math.min(u.campScroll or 0,math.max(0,#C.structures-5));u.campScroll=first
  for i=1,5 do local s=C.structures[first+i];if s then local yy=y+168+(i-1)*48;button('Lv '..s.level..'  '..s.name..(d.built[s.id]and' [built]'or(' â€” '..s.xp..' XP')),x+14,yy,650,42,function()u.campSelected=s.id end);g.setColor(.8,.82,.72);g.print(C.available(u.inv,s.needs),x+25,yy+25)end end
 else
  local first=math.min(u.campScroll or 0,math.max(0,#C.unlocks-10));u.campScroll=first;for i=1,10 do local row=C.unlocks[first+i];if row then g.setColor(a.skills:get('Fieldcraft').level>=row.level and .9 or .5,.8,.6);g.print('Level '..row.level..': '..row.text,x+20,y+80+(i-1)*30)end end
 end
 g.setColor(1,.72,.42);g.printf(C.warning,x+14,y+ph-69,pw-28,'left');g.setColor(.7,.75,.55);g.line(x+pw-15,y+ph-4,x+pw-4,y+ph-15);g.pop()
end
function M.timedOffline(u,cmd)
 if require('game.multiplayer').active then return M.command(u,cmd)end
 if u.craftJob then return end;u.craftJob={name=cmd.op=='fishProcess'and'Processing fish'or cmd.op=='fireCreate'and'Lighting fire'or cmd.op=='fireRefuel'and'Adding bonfire fuel'or cmd.op=='potPlace'and'Placing pot'or cmd.op=='potRecover'and'Recovering pot'or cmd.op=='shellHarvest'and'Harvesting parts'or cmd.op=='shellFillet'and'Breaking shellfish'or cmd.op=='build'and'Camp construction'or'Fieldcraft crafting',timer=0,duration=cmd.op=='fishProcess'and require('game.high_tier_fish').duration(cmd.fish)or(cmd.op=='build'or cmd.op=='potPlace'or cmd.op=='potRecover'or cmd.op=='shellHarvest'or cmd.op=='shellFillet')and 2 or .5,x=u.player.x,y=u.player.y,finish=function()M.command(u,cmd)end}
end
function M.bankInstall()
 local I=require('game.inventory');local deposit=I.depositSlot;I.depositSlot=function(inv,bag,slot,...)
  if ui and ui.campBank and require('game.multiplayer').active then return M.command(ui,{op='bankDeposit',bag=bag,slot=slot})end;return deposit(inv,bag,slot,...)
 end
 local withdraw=I.withdrawBankSlotAmount;I.withdrawBankSlotAmount=function(inv,slot,amount,...)
  if ui and ui.campBank and require('game.multiplayer').active then return M.command(ui,{op='bankWithdraw',slot=slot,amount=amount})end;return withdraw(inv,slot,amount,...)
 end
end
M.bankInstall()
function M.logout(u)
 if not u or require('game.multiplayer').active then return end;local a=actor(u);local w,c=F.find(u.world,a);if c then F.remove(w,a,c,true);u.fieldcraft=a.fieldcraft end
end
return M
