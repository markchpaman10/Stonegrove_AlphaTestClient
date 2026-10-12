local function same(a,b)for k,v in pairs(a)do if b[k]~=v then return false end end;for k,v in pairs(b)do if a[k]~=v then return false end end;return true end
local M={};local F=require('game.fieldcraft');local C=require('game.fieldcraft_content');local P=require('game.profile');local R=require('game.rune_inventory')
function M.install(actors,rooms,S)
 SG_CAMP=function(method,b)
  if method=='camp_cleanup'then
   local owner=tostring(b.id)..':'..tostring(b.slot)
   for _,r in pairs(rooms)do require('game.shellfish').cleanup(r.world,owner);for i=#(r.world.playerCamps or{}),1,-1 do local c=r.world.playerCamps[i];if c.owner==owner then F.remove(r.world,{campOwner=owner,fieldcraft={}},c,false)end end end
   return {ok=true}
  end
  local a=actors[b.id]
  if method=='admin_info'then if not a or love.timer.getTime()-a.seen>=15 or b.slot and a.slot~=b.slot then return {ok=false,reason='Target player disconnected or changed character'}end
   return {ok=true,slot=a.slot,owner=a.owner,personal=P.pack({player=a.player,skills=a.skills.data,bags=a.inv.bagSlots})}end
  if method=='admin_sync'then if not a or a.slot~=b.slot or a.owner~=b.owner then return {ok=false}end;a.effects={hp=0,stamina=0,xp={}};a.adminUpdate={revision=b.revision,personal=P.unpack(b.personal),destination=b.destination};return {ok=true}end
  if not a or a.slot~=b.slot or a.owner~=b.owner then return {ok=false,reason='Character is not connected to this world'}end
  if method=='camp_ping'then a.seen=love.timer.getTime();return {ok=true}end
  local w=rooms[a.room].world
  local function shallow(v)local out={};for i,x in ipairs(v or{})do out[i]=x end;return out end
  if method=='camp_prepare'then local fuelFires={};if b.op=='fireRefuel'then for _,f in ipairs(w.campfires)do fuelFires[#fuelFires+1]={fire=f,values={timer=f.timer,queuedLogs=f.queuedLogs,burnedLogs=f.burnedLogs,completedLogs=f.completedLogs,burnUpdatedAt=f.burnUpdatedAt,buffId=f.buffId}}end end;a.campRollback={placedContainers=R.copy(w.placedContainers or{}),boneClaims=(b.op=="bless"or tostring(b.op):match("^bone"))and require("game.bone_religion").checkpoint(a.inv)or nil,burialGraves=R.copy(w.burialGraves or{}),religionHighWater=a.religionHighWater,fuelFires=fuelFires,activityHighWater=R.copy(a.activityHighWater),player=R.copy(a.player),inv=R.clone(a.inv),config=R.copy(a.fieldcraft or{}),skills=R.copy(a.skills.data),camps=R.copy(w.playerCamps or{}),fires=shallow(w.campfires),ground=shallow(w.groundItems),nodes=(b.op=='deploy'or b.op=='pack')and shallow(w.nodes)or nil,revision=w.campRevision,job=R.copy(a.campJob),pots=R.copy(w.shellfishPots or{}),parts=R.copy(w.shellfishParts or{}),gains=R.copy(a.skills.pendingGains or{}),levels=R.copy(a.skills.pendingLevelUps or{})};return {ok=true}end
  if method=='camp_rollback'then local old=a.campRollback;if old then w.placedContainers=old.placedContainers;require("game.bone_religion").rollback(old.boneClaims);w.burialGraves=old.burialGraves;for _,record in ipairs(old.fuelFires or{})do for _,k in ipairs({'timer','queuedLogs','burnedLogs','completedLogs','burnUpdatedAt','buffId'})do record.fire[k]=record.values[k]end end;a.religionHighWater=old.religionHighWater;a.activityHighWater=old.activityHighWater;if old.vendor then old.vendor.shop.slots=old.vendor.slots end;for k in pairs(a.player)do a.player[k]=nil end;for k,v in pairs(old.player)do a.player[k]=v end;a.inv=old.inv;require("game.tool_slot").bind(a);a.fieldcraft=old.config;a.skills.data=old.skills;a.skills.pendingGains=old.gains;a.skills.pendingLevelUps=old.levels;a.campJob=old.job;w.shellfishPots=old.pots;w.shellfishParts=old.parts;w.playerCamps=old.camps;w.campfires=old.fires;w.groundItems=old.ground;if old.nodes then w.nodes=old.nodes end;w.campRevision=old.revision;require('game.node_index').invalidate(w);require('game.navigation').refresh(w);a.campRollback=nil end;return {ok=true}end
  if method=='camp_commit'then a.campRollback=nil;return {ok=true}end
  local cmd=b.command
  if type(cmd)~='table'then return {ok=false,reason='Invalid camp command'}end
  local d=P.unpack(b.saved);a.campOwner=tostring(b.id)..':'..b.slot;a.fieldcraft=d.fieldcraft or{};require('game.fieldcraft').bind(w,a);require('game.bag_system').validate(d.bags,d.skills);a.inv.bagSlots=d.bags;a.inv.strengthLevel=a.skills:levelForXP((d.skills.Strength or{}).xp or 0);a.inv.bank=d.bank or{};a.inv.bankSize=d.bankSize or 25;require('game.tool_slot').inventories[a.inv]=d.equipment or a.equipment
  for _,name in ipairs({'Fieldcraft','Survival','Foraging','Woodworking','Strength'})do local sk=d.skills and d.skills[name];if sk then local amount=sk.xp or 0;if name~='Woodworking'then amount=math.max(amount,a.skills.data[name].xp)end;a.skills.data[name].xp=amount;a.skills.data[name].level=a.skills:levelForXP(amount)end end
  if a.campRollback and a.campRollback.boneClaims then a.campRollback.boneClaims=require('game.bone_religion').checkpoint(a.inv)end
   local t=love.timer.getTime()
  if cmd.op=='begin'then
   if type(cmd.next)~='table'then return {ok=false,reason='Select a recipe or construction'}end
   local n=cmd.next;local duration=(n.op=='build'and 2)or .5
   if n.op=='craft'then local r=require('game.crafting').new():getRecipes(n.station)[n.index];if not r then return {ok=false,reason='Unknown recipe'}end;duration=(r.duration or .5)*math.max(1,r.qty or 1)elseif n.op=='enchant'then if type(n.qty)~='number'or n.qty<1 or n.qty%1~=0 or n.qty>9999 then return {ok=false,reason='Invalid dust amount'}end;local bag=a.inv:getBag(n.gemBag);local gem=bag and bag.slots[n.gemSlot];local def=gem and require('game.enchanting').gems[gem.name:match('^Cut (%a+)$')];duration=.5*math.min(n.qty,def and def.maxDust or 30) elseif n.op=='fireCreate'or n.op=='fireRefuel'then duration=2 elseif n.op=='potPlace'or n.op=='potRecover'or n.op=='shellHarvest'or n.op=='shellFillet'then duration=2 elseif n.op=='fishProcess'then local b=a.inv:getBag(n.bag);local it=b and b.slots[n.slot];if not it or not require('game.high_tier_fish').data[it.name]then return {ok=false,reason='Select a whole high-tier fish'}end;duration=require('game.high_tier_fish').duration(it.name) elseif n.op=='carveFeather'or n.op:match('^bone')then duration=.5 elseif n.op~='build'and n.op~='leaves'then return {ok=false,reason='Invalid timed action'}end
   a.campJob={command=R.copy(n),ready=t+duration,damageSerial=a.player.damageSerial or 0,x=a.player.x,y=a.player.y};return {ok=true,begin=true,duration=duration}
  end
  if cmd.op=='carveFeather'or cmd.op=='fishProcess'or cmd.op:match('^bone')or cmd.op=='fireCreate'or cmd.op=='fireRefuel'or cmd.op=='potPlace'or cmd.op=='potRecover'or cmd.op=='shellHarvest'or cmd.op=='shellFillet'or cmd.op=='craft'or cmd.op=='leaves'or cmd.op=='build'or cmd.op=='enchant'then
   local j=a.campJob;if not j or t+0.01<j.ready or not same(j.command,cmd)or(a.player.x-j.x)^2+(a.player.y-j.y)^2>4 or(cmd.op:match("^bone")and(a.player.damageSerial or 0)~=(j.damageSerial or 0))then return {ok=false,reason='Complete the cast without moving'}end;a.campJob=nil
  end
  require('game.shellfish').restore(w,a)
  local ok,why,destination,shopSlots
  if cmd.op=='fishProcess'then ok,why=require('game.high_tier_fish').command(w,a,cmd)
  elseif cmd.op:match('^bone')then ok,why=require('game.bone_religion').command(w,a,cmd)
  elseif cmd.op=='starterBag'then ok,why=require('game.bag_keeper').claim(w,a,cmd,S.bagWorlds())
  elseif cmd.op=='bless'then
   if cmd.altar then local near=false;for _,v in ipairs(w.villages or{})do local st=v.religionAltar;if st and(st.x-a.player.x)^2+(st.y-a.player.y)^2<=55^2 then near=true end end;for _,o in ipairs((w.map.authored or{}).objects or{})do if o.id=='religionAltar'and(o.x-a.player.x)^2+(o.y-a.player.y)^2<=55^2 then near=true end end;if not near then return {ok=false,reason='Move near a Religion Altar'}end end
   ok,why=require('game.religion').blessInventory({campOwner=a.campOwner,inv=a.inv,skills=a.skills,player=a.player,world=w,sprites=S.sprites,logger=a.logger},cmd.altar==true)
  elseif cmd.op=='carveFeather'then
   if not require('game.tool_slot').has(a.inv,nil,'Copper Knife',a.player)then return {ok=false,reason='Need a Copper Knife or Copper Dagger'}end
   ok,why=require('game.religion').carveFeather(a.inv,a.skills)
  elseif cmd.op=='fireCreate'then ok,why=w:createCampfire(a.player,a.inv,a.skills,a.logger,cmd.fuel)
  elseif cmd.op=='fireRefuel'then local fire;for _,v in ipairs(w.campfires)do if v.netId==cmd.fireId then fire=v;break end end;if not fire then return {ok=false,reason='Bonfire expired'}end;ok,why=w:addBonfireLog(a.player,a.inv,a.skills,a.logger,cmd.fuel,fire)
  elseif cmd.op=='potPlace'or cmd.op=='potRecover'or cmd.op=='potEmpty'or cmd.op=='potSync'or cmd.op=='shellFillet'or cmd.op=='shellHarvest'then ok,why=require('game.shellfish').command(w,a,cmd)
  elseif cmd.op=='beltFood'then
   local name=d.potionBelt and d.potionBelt[cmd.slot];local heal=name and require('game.food').healing[name];if not heal or not(require('game.seafood_content').isFood(name)or tostring(name):match('^Cooked Shrimp ')or tostring(name):match('^Cooked Swordfish ')or tostring(name):match('^Cooked Crab Meat ')or tostring(name):match('^Cooked Lobster Meat '))or a.player.hp>=a.player.maxHp then return {ok=false,reason='No food needed'}end;d.potionBelt[cmd.slot]=nil;a.player.hp=math.min(a.player.maxHp,a.player.hp+heal);ok,why=true,'Ate '..name
  elseif cmd.op=='sellMaterial'or cmd.op=='buyMaterial'or cmd.op=='sellInventory'then
   if cmd.vendorGroup~='shopkeeper'and cmd.vendorGroup~='tradeKeepers'and cmd.vendorGroup~='traders'then return {ok=false,reason='Invalid merchant'}end
   if type(cmd.vendorIndex)~='number'or cmd.vendorIndex%1~=0 or cmd.vendorIndex<1 then return {ok=false,reason='Invalid merchant'}end
   local vendor=cmd.vendorGroup=='shopkeeper'and cmd.vendorIndex==1 and w.shopkeeper or cmd.vendorGroup~='shopkeeper'and(w[cmd.vendorGroup]or{})[cmd.vendorIndex]
   if not vendor or (vendor.x-a.player.x)^2+(vendor.y-a.player.y)^2>75^2 then return {ok=false,reason='Move near the merchant'}end
   vendor.shop=vendor.shop or require('game.shop').new();local merchant=vendor.shop;if merchant.contentProfile then merchant:update(false)end
   local bag=a.inv:getBag(cmd.bag);local obj=cmd.op=='buyMaterial'and merchant.slots[cmd.slot]or bag and bag.slots[cmd.slot]
   if cmd.op~='sellInventory'and(not obj or obj.name~=cmd.name or(not merchant.contentProfile and not C.sellable(obj.name)))then return {ok=false,reason='Material moved; select it again'}end
   if cmd.op~='buyMaterial'and cmd.op~='sellInventory'and not merchant:acceptsSale(obj.name)then return {ok=false,reason='Merchant does not buy this material'}end
   local trial=R.clone(a.inv);local sale={};for k,v in pairs(merchant)do sale[k]=v end;sale.slots=R.copy(merchant.slots);setmetatable(sale,getmetatable(merchant));local amount,price
   if cmd.op=='sellInventory'then ok,price,amount=sale:sellInventory(trial)
   elseif cmd.op=='buyMaterial'then
    if cmd.qty~='all'and cmd.qty~=1 and cmd.qty~=10 then return {ok=false,reason='Invalid purchase quantity'}end
    local name;ok,name,price,amount=sale:buy(cmd.slot,trial,cmd.qty);if not ok then return {ok=false,reason=name}end
   elseif cmd.all==true then ok,price,amount=sale:sellAll(obj.name,trial)
   else local selected=trial:removeSlot(cmd.bag,cmd.slot);amount=selected and(selected.qty or 1)or 0;ok,price=sale:sellObject(selected,trial)end
   if not ok then return {ok=false,reason=price}end
   if a.campRollback then a.campRollback.vendor={shop=merchant,slots=merchant.slots}end
   a.inv.bagSlots=trial.bagSlots;merchant.slots=sale.slots;shopSlots=P.pack(sale.slots);why=(cmd.op=='buyMaterial'and'Bought 'or'Sold ')..amount..' '..(obj and obj.name or'items')..' for '..price..' copper'
  elseif cmd.op=='admin'then ok,why,destination=require('game.admin_rules').execute(w,a,cmd,S.sprites)
  elseif cmd.op:match('^container')then ok,why=require('game.lumber').command(w,a,cmd)
  elseif cmd.op=='craft'then
   local crafting=require('game.crafting').new();local recipe=crafting:getRecipes(cmd.station)[cmd.index]
   if not recipe then return {ok=false,reason='Unknown recipe'}end
   if recipe.contentRecipe or recipe.contentRule~=nil then local permitted=cmd.station=='woodcraft' or cmd.station=='leathercraft' or cmd.station=='inscription';for _,o in ipairs(w.authoredObjects or{})do if o.id==cmd.station and(o.x-a.player.x)^2+(o.y-a.player.y)^2<=55^2 then permitted=true end end;local o=w[cmd.station];if o and o.x and(o.x-a.player.x)^2+(o.y-a.player.y)^2<=55^2 then permitted=true end;for _,c in ipairs(w.playerCamps or{})do for _,st in ipairs(c.structures or{})do local d=C.structure(st.id);if d and d.station==cmd.station and(st.x-a.player.x)^2+(st.y-a.player.y)^2<=55^2 then permitted=true end end end;if cmd.station=='campfire'then for _,f in ipairs(w.campfires or{})do if(f.timer or 0)>0 and(f.x-a.player.x)^2+(f.y-a.player.y)^2<=55^2 then permitted=true end end end;if not permitted then return {ok=false,reason='Move near the recipe station'}end end
   if recipe.lumber then local allowed,reason=require('game.lumber').access(recipe,w,a.player);if not allowed then return {ok=false,reason=reason}end;if not recipe.sawing and cmd.station=='anvil'then local found=false;for _,o in ipairs(w.authoredObjects or{})do if o.id=='anvil'and(o.x-a.player.x)^2+(o.y-a.player.y)^2<=55^2 then found=true end end;local o=w.anvil;if o and(o.x-a.player.x)^2+(o.y-a.player.y)^2<=55^2 then found=true end;if not found then return {ok=false,reason='Move near an anvil'}end end
   elseif recipe.advancedRecipe then
    local allowed,reason=require('game.advanced_gear').access(recipe,w,a.player);if not allowed then return {ok=false,reason=reason}end
   elseif recipe.tailoring then
    local allowed,reason=require('game.tailoring_content').access(recipe,w,a.player);if not allowed then return {ok=false,reason=reason}end
   elseif not recipe.contentRecipe and recipe.contentRule==nil and not recipe.fieldcraft and not recipe.bagRecipe then
    local permitted=false;for _,c in ipairs(w.playerCamps or{})do for _,s in ipairs(c.structures)do local def=C.structure(s.id);if def.station==cmd.station and(s.x-a.player.x)^2+(s.y-a.player.y)^2<=55^2 then permitted=true end end end
    if not permitted then return {ok=false,reason='Move near an unlocked camp facility'}end
   end
   ok,why=crafting:craft(cmd.station,cmd.index,a.inv,a.skills,a.logger,a.equipment.weapon,w,a.player)
   if ok and not recipe.fieldcraft and not recipe.tailoring and not recipe.advancedRecipe and os.time()>=(a.fieldcraft.facilityNext or 0)then a.fieldcraft.facilityNext=os.time()+60;a.skills:addXP('Fieldcraft',2)end
  elseif cmd.op=='enchant'then
   local access=false;for _,camp in ipairs(w.playerCamps or{})do for _,st in ipairs(camp.structures)do if C.structure(st.id).station=='enchantAltar'and(st.x-a.player.x)^2+(st.y-a.player.y)^2<=55^2 then access=true end end end
   if not access then return {ok=false,reason='Move near an unlocked camp Enchanting Altar'}end
   local gb=a.inv:getBag(cmd.gemBag);local pb=a.inv:getBag(cmd.pageBag);local gem=gb and gb.slots[cmd.gemSlot];local page=pb and pb.slots[cmd.pageSlot]
   if not gem or not page then return {ok=false,reason='Selection moved; choose the gem and page again'}end
   local u={inv=a.inv,skills=a.skills,enchantGem={bag=cmd.gemBag,slot=cmd.gemSlot,name=gem.name,item=gem},enchantPage={bag=cmd.pageBag,slot=cmd.pageSlot,name=page.name,item=page},log=function()end}
   ok,why=require('game.enchanting').enchant(u,cmd.qty)
   if ok and os.time()>=(a.fieldcraft.facilityNext or 0)then a.fieldcraft.facilityNext=os.time()+60;a.skills:addXP('Fieldcraft',2)end
  elseif cmd.op=='leaves'then
   if not a.inv:hasItem('Copper Knife')and not a.inv:hasItem('Copper Dagger')then return {ok=false,reason='Need a Knife'}end
   local trial=R.clone(a.inv);if not trial:removeItems('Bush Greens',1)then return {ok=false,reason='Need Bush Greens'}end
   if not trial:add('Bush Leaves',1)then return {ok=false,reason='Bags full'}end;a.inv.bagSlots=trial.bagSlots;a.skills:addXP('Fieldcraft',4);ok,why=true,'Bush Leaves'
  elseif cmd.op=='drop'then
   local bag=a.inv:getBag(cmd.bag);local obj=bag and bag.slots[cmd.slot]
   if not obj or not C.protected(obj.name)then return {ok=false,reason='Item moved; select it again'}end
   bag.slots[cmd.slot]=nil;w:addGroundItem(obj.name,a.player.x+10,a.player.y+8,nil,R.copy(obj));ok,why=true,'Dropped'
  elseif cmd.op=='pickup'or cmd.op=='pickupAll'then
   local count=0
   for i=#w.groundItems,1,-1 do local g=w.groundItems[i]
    if (cmd.op=='pickupAll'or g.netId==cmd.target)and(g.x-a.player.x)^2+(g.y-a.player.y)^2<=80^2 then
     local added=g.object and a.inv:addItemObject(R.copy(g.object))or(not g.object and a.inv:add(g.name=='Lit Torch'and'Torch'or g.name,1))
     if added then table.remove(w.groundItems,i);count=count+1 end
    end
   end;ok,why=count>0,'Collected '..count..' items'
  elseif cmd.op=='eat'then
   local bag=a.inv:getBag(cmd.bag);local obj=bag and bag.slots[cmd.slot];local heal=obj and require('game.food').healing[obj.name]
   if not obj or (obj.name~='Potent Antidote'and(not heal or a.player.hp>=a.player.maxHp))then return {ok=false,reason='Cannot eat this item now'}end
   local name=obj.name;obj.qty=(obj.qty or 1)-1;if obj.qty<=0 then bag.slots[cmd.slot]=nil end;if name=='Potent Antidote'then a.player.poisonedTimer=0;a.player.poisonTick=0;a.player.slimeCoated=0;a.player.slimeBreathTick=0;a.player.poisonImmuneTimer=15 else a.player.hp=math.min(a.player.maxHp,a.player.hp+heal)end;require('game.survival_foraging').food(a,name);ok,why=true,'Ate '..name
  elseif cmd.op=='bankDeposit'or cmd.op=='bankWithdraw'then
   local access=false;for _,c in ipairs(w.playerCamps or{})do for _,s in ipairs(c.structures)do if s.id=='bank'and(s.x-a.player.x)^2+(s.y-a.player.y)^2<=55^2 then access=true end end end
   if not access then return {ok=false,reason='Move near a level 99 Bank Access Station'}end
   if cmd.op=='bankDeposit'then ok,why=a.inv:depositSlot(cmd.bag,cmd.slot)else ok,why=a.inv:withdrawBankSlotAmount(cmd.slot,cmd.amount or 1)end
  else ok,why=F.command(w,a,cmd,os.time())end
  if a.activityHighWater then for name,skill in pairs(a.skills.data)do a.activityHighWater[name]=math.max(a.activityHighWater[name]or 0,skill.xp)end end
  a.religionHighWater=math.max(a.religionHighWater or 0,a.skills:get("Religion").xp)
  a.inv:migrateBags(a.skills:get("Strength").level)
  local c=F.owned(w,a)
  return {ok=ok,reason=why,shopSlots=shopSlots,destination=destination,adminPlayer=cmd.op=='admin'and P.pack({x=a.player.x,y=a.player.y,hp=a.player.hp,maxHp=a.player.maxHp,stamina=a.player.stamina,maxStamina=a.player.maxStamina}),state=P.pack({potionBelt=cmd.op=='beltFood'and d.potionBelt or nil,status={bonfireBuffUntil=a.player.bonfireBuffUntil or 0,bonfireLastSource=a.player.bonfireLastSource,maxHp=a.player.maxHp,poisonedTimer=a.player.poisonedTimer,poisonTick=a.player.poisonTick,slimeCoated=a.player.slimeCoated,slimeBreathTick=a.player.slimeBreathTick,poisonImmuneTimer=a.player.poisonImmuneTimer},hp=a.player.hp,bags=a.inv.bagSlots,bank=a.inv.bank,bankSize=a.inv.bankSize,fieldcraft=a.fieldcraft,skills=a.skills.data}),camp=c and P.pack(c)}
 end
end
return M
