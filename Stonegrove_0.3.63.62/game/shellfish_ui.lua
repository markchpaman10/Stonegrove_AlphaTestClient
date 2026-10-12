local S={};local P=require('game.shellfish');local R=require('game.rune_inventory')
local function owner()local p=require('game.profile').active;return p and(tostring(p.id)..':'..p.slot)or'offline'end
local function actor(u)return{campOwner=owner(),player=u.player,skills=u.skills,inv=u.inv,fieldcraft=u.fieldcraft or{}}end
local function food(name)return type(name)=='string'and(require('game.seafood_content').isFood(name)or name:match('^Cooked Shrimp ')or name:match('^Cooked Swordfish ')or name:match('^Cooked Crab Meat ')or name:match('^Cooked Lobster Meat '))end
function S.install(U)
 local F=require('game.fieldcraft_ui')
 local H=require('game.help');local help=H.world;H.world=function(u,x,y)local pot=P.at(u.world,x,y,'shellfishPots');if pot then return H.tip(pot.name,(u.skills:get('Fishing').level>=P.inspectLevel and((pot.catchCount or 0)..'/'..P.limit(pot.name,pot.level)..' catches; soaking ')or'Soaking ')..math.floor(pot.elapsed or 0)..' seconds. Left-click your pot to recover (2 seconds).')end;local part=P.at(u.world,x,y,'shellfishParts');if part then return H.tip(part.name,'Left-click to break, or right-click Harvest. Gives 1-5 raw '..part.species..' Meat.')end;return help(u,x,y)end
 local options=U.contextOptions;U.contextOptions=function(u,it)local list=options(u,it);if P.levels[it.name]then table.insert(list,1,(it.catchCount or 0)>0 and'Empty'or'Place')elseif it.name=='Crab'or it.name=='Lobster'then table.insert(list,1,'Break')elseif it.name=='Crab Parts'or it.name=='Lobster Parts'then table.insert(list,1,'Harvest')end;if food(it.name)then table.insert(list,1,'Equip Food')end;return list end
 local context=U.doContextOption;U.doContextOption=function(u,opt)
  local c=u.context;local obj=c and u.inv:getBag(c.bag).slots[c.slot]
  if opt=='Place'and obj and P.levels[obj.name]then if u.skills:get('Fishing').level<P.levels[obj.name]then u.world:addPopup(u.player.x,u.player.y-24,'Fishing '..P.levels[obj.name]..' required');return end;u.potPlacement={bag=c.bag,slot=c.slot,name=obj.name};u.context=nil;return
  elseif opt=='Empty'and obj and P.levels[obj.name]then F.command(u,{op='potEmpty',bag=c.bag,slot=c.slot});u.context=nil;return
  elseif opt=='Break'and obj then F.timedOffline(u,{op='shellFillet',bag=c.bag,slot=c.slot});u.context=nil;return
  elseif opt=='Harvest'and obj and(obj.name=='Crab Parts'or obj.name=='Lobster Parts')then F.timedOffline(u,{op='shellHarvest',bag=c.bag,slot=c.slot});u.context=nil;return
  elseif opt=='Equip Food'and obj then u:equipPotionFromBag(c.bag,c.slot);u.context=nil;return end
  return context(u,opt)
 end
 local isPotion=U.isPotion;U.isPotion=function(u,n)return food(n)or isPotion(u,n)end
 local equip=U.equipPotionFromBag;U.equipPotionFromBag=function(u,bi,slot,target)
  local obj=u.inv:getBag(bi).slots[slot];if not obj or not food(obj.name)then return equip(u,bi,slot,target)end
  if not target then for i=1,4 do if not u.potionBelt[i]then target=i;break end end end;if not target then return false,'belt_full'end
  local trial=R.clone(u.inv);local it=trial:getBag(bi).slots[slot];local name=it.name;it.qty=(it.qty or 1)-1;if it.qty<=0 then trial:getBag(bi).slots[slot]=nil end
  if u.potionBelt[target]and not trial:add(u.potionBelt[target],1)then return false,'bags_full'end
  u.inv.bagSlots=trial.bagSlots;u.potionBelt[target]=name;return true,target
 end
 local use=U.usePotion;U.usePotion=function(u,slot)
  local name=u.potionBelt[slot];if not food(name)then return use(u,slot)end
  if require('game.multiplayer').active then return F.command(u,{op='beltFood',slot=slot})end
  if u.player.hp>=u.player.maxHp then return false,'no_effect_needed'end
  u.player.hp=math.min(u.player.maxHp,u.player.hp+require('game.food').healing[name]);u.potionBelt[slot]=nil;return true,name
 end
 local icon=U.drawItemSprite;U.drawItemSprite=function(u,it,...)
  if P.levels[it.name]and(it.catchCount or 0)>0 then local old=u.sprites.itemQuads[it.name];u.sprites.itemQuads[it.name]=u.sprites.fishingTierQuads[it.name].cast;icon(u,it,...);u.sprites.itemQuads[it.name]=old;return end;return icon(u,it,...)
 end
 local update=F.update;F.update=function(u)
  update(u);local a=actor(u);require('game.fieldcraft').bind(u.world,a);local key=tostring(u.world)..':'..owner()
  if not require('game.multiplayer').active then P.restore(u.world,a);for _,pot in ipairs(u.world.shellfishPots or{})do if pot.owner==a.campOwner then pot.level=u.skills:get('Fishing').level end end;a.fieldcraft.pots=a.fieldcraft.pots or{};a.fieldcraft.shellParts=a.fieldcraft.shellParts or{};P.command(u.world,a,{op='potSync'});u.fieldcraft=a.fieldcraft
  elseif require('game.multiplayer').ready and u.potSyncKey~=key and not u.campPending then
   u.potSyncKey=key;if next((u.fieldcraft or{}).pots or{})or next((u.fieldcraft or{}).shellParts or{})then F.command(u,{op='potSync'},function(ok)if not ok then u.potSyncKey=nil end end)end
  end
 end
 local drawables=F.drawables;F.drawables=function(u,camera,add)
  drawables(u,camera,add)
  for _,v in ipairs(u.world.shellfishPots or{})do local pot=v;add(pot.y+10,function()u:drawItemSprite({name=pot.name,catchCount=pot.catchCount},pot.x-10,pot.y-10,20)end,pot.x)end
  for _,v in ipairs(u.world.shellfishParts or{})do local part=v;add(part.y+8,function()u:drawItemSprite({name=part.name},part.x-12,part.y-12,24);if part.species=='Lobster'then love.graphics.draw(u.sprites.lobsterPieceImage,u.sprites.lobsterPieceQuads[(part.variant or 0)+1],part.x+4,part.y,0,1,1,8,8)end end,part.x)end
 end
 local draw=F.worldDraw;F.worldDraw=function(u,camera)
  draw(u,camera);local g=love.graphics;local w,h=g.getDimensions()
  if u.potPlacement then local mx,my=love.mouse.getPosition();local x,y=camera:toWorld(mx,my,w,h);x,y=math.floor(x/8)*8,math.floor(y/8)*8;local p=u.potPlacement;p.x,p.y=x,y;local ok,why=P.valid(u.world,actor(u),p.name,x,y);g.setColor(ok and .15 or 1,ok and .9 or .15,.2,.3);g.rectangle('fill',x-8,y-8,16,16);g.setColor(ok and .15 or 1,ok and .9 or .15,.2,1);g.rectangle('line',x-8,y-8,16,16);g.setColor(1,1,1,.6);u:drawItemSprite({name=p.name},x-10,y-10,20);p.reason=ok and'Left-click to place; right-click / Escape cancels'or why end
  g.setColor(1,1,1)
  if u.shellContext then local c=u.shellContext;local x,y=camera:toWorld(c.x,c.y,w,h);g.setColor(.06,.07,.06,.95);g.rectangle('fill',x,y,110/camera.zoom,28/camera.zoom);g.setColor(1,1,1);g.push();g.translate(x+6/camera.zoom,y+6/camera.zoom);g.scale(1/camera.zoom);g.print('Harvest parts');g.pop()end
 end
 local click=F.worldClick;F.worldClick=function(u,camera,x,y,button)
  if u.shellContext then local c=u.shellContext;u.shellContext=nil;if button==1 and x>=c.x and x<=c.x+110 and y>=c.y and y<=c.y+28 then F.timedOffline(u,{op='shellHarvest',id=c.id});return true end;return true end
  if u.potPlacement then if button==2 then u.potPlacement=nil;return true end;if button==1 then local p=u.potPlacement;local w,h=love.graphics.getDimensions();local wx,wy=camera:toWorld(x,y,w,h);wx,wy=math.floor(wx/8)*8,math.floor(wy/8)*8;local ok,why=P.valid(u.world,actor(u),p.name,wx,wy);if not ok then u.world:addPopup(u.player.x,u.player.y-24,why,'miss');return true end;F.timedOffline(u,{op='potPlace',bag=p.bag,slot=p.slot,name=p.name,x=math.floor(wx/8)*8,y=math.floor(wy/8)*8});u.potPlacement=nil;return true end end
  local w,h=love.graphics.getDimensions();local wx,wy=camera:toWorld(x,y,w,h)
  local v=P.at(u.world,wx,wy,'shellfishPots');if v then if button==1 then F.timedOffline(u,{op='potRecover',id=v.id})end;return true end
  local part=P.at(u.world,wx,wy,'shellfishParts');if part then if button==2 then u.shellContext={x=math.min(x,w-114),y=math.min(y,h-32),id=part.id}else F.timedOffline(u,{op='shellHarvest',id=part.id})end;return true end
  return click(u,camera,x,y,button)
 end
end
return S
