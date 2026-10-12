local L={inventories=setmetatable({},{__mode='k'}),woods={'Pine','Oak','Poplar'},levels={10,20,30},defs={},mills={copperSawmill=1,ironSawmill=2,steelSawmill=3},bonus={D=0,C=1,B=2,A=3}}
for i,wood in ipairs(L.woods)do for _,kind in ipairs({'Crate','Barrel'})do L.defs[wood..' '..kind]={tier=i,base=(kind=='Crate'and 5 or 7)+(i-1)*3,kind=kind,wood=wood}end end
function L.capacity(obj)local d=L.defs[obj.name];return d and d.base+(L.bonus[require('game.quality').grade(obj)or'D']or 0)end
function L.normalize(obj)if L.defs[obj.name]then obj.qty=1;obj.contents=obj.contents or{} end;return obj end
function L.used(obj)local n=0;for _ in pairs(obj.contents or{})do n=n+1 end;return n end
function L.owner(a)return a.campOwner or'offline'end
function L.mill(w,p)
 for _,o in ipairs(w.authoredObjects or{})do if L.mills[o.id]and(o.x-p.x)^2+(o.y-p.y)^2<=55^2 then return L.mills[o.id],o end end
 for _,v in ipairs(w.villages or{})do for id,tier in pairs(L.mills)do local o=v[id];if o and(o.x-p.x)^2+(o.y-p.y)^2<=55^2 then return tier,o end end end
 for id,tier in pairs(L.mills)do local o=w[id];if o and(o.x-p.x)^2+(o.y-p.y)^2<=55^2 then return tier,o end end
end
function L.validate(obj)
 if not L.defs[obj.name]then return true end
 assert(obj.qty==nil or obj.qty==1,'Container quantity must be one');assert(not obj.qualityGrade or L.bonus[obj.qualityGrade]~=nil,'Invalid container grade')
 for slot,it in pairs(obj.contents or{})do assert(type(slot)=='number'and slot%1==0 and slot>=1 and slot<=L.capacity(obj)and type(it)=='table','Invalid container contents');assert(not require('game.fieldcraft_content').protected(it.name),'Camp deployment items must remain in main bags');assert(not L.defs[it.name]and not require('game.bag_system').defs[it.name]and it.name~='Rune Bag'and not require('game.advanced_gear').isQuiver(it.name),'Containers cannot be nested');assert(type(it.qty or 1)=='number'and(it.qty or 1)>0 and(it.qty or 1)%1==0,'Invalid stored quantity')end;return true
end
function L.access(r,w,p)
 if not r.sawing then return true end
 local tier=w and p and L.mill(w,p);if not tier then return false,'Move near a sawmill'end
 if tier<r.woodTier then return false,'Requires '..({'Copper','Iron','Steel'})[r.woodTier]..' Sawmill or better'end
 return true
end
function L.configure(recipes)
 for i,wood in ipairs(L.woods)do
  recipes.woodcraft[#recipes.woodcraft+1]={name=wood..' Planks',output=wood..' Planks',qty=1,xp=15+i*5,level=L.levels[i],skill='Woodworking',duration=1.5+i*.5,needs={{wood..' Logs',1}},sawing=true,woodTier=i,lumber=true}
  recipes.woodcraft[#recipes.woodcraft+1]={name=wood..' Crate',output=wood..' Crate',qty=1,xp=35+i*15,level=L.levels[i],skill='Woodworking',tool='Copper Hammer',needs={{wood..' Logs',i==1 and 4 or 5},{i==1 and'Copper Nails'or'Iron Nails',5}},lumber=true}
  recipes.anvil[#recipes.anvil+1]={name=wood..' Barrel',output=wood..' Barrel',qty=1,xp=40+i*15,level=L.levels[i],skill='Smithing',tool='Copper Hammer',needs={{wood..' Logs',4},{({'Copper','Iron','Steel'})[i]..' Bar',2}},lumber=true}
 end
 for i,metal in ipairs({'Copper','Iron','Steel'})do recipes.anvil[#recipes.anvil+1]={name=metal..' Nails',output=metal..' Nails',qty=5,xp=10*i,level=10,skill='Smithing',tool='Copper Hammer',needs={{metal..' Bar',1}},lumber=true}end
 for _,st in ipairs({'woodcraft','anvil'})do table.sort(recipes[st],function(a,b)if(a.level or 1)==(b.level or 1)then return a.name<b.name end;return(a.level or 1)<(b.level or 1)end)end
end
function L.craft(r,inv,skills,w,p)
 local trial=require('game.rune_inventory').clone(inv);for _,n in ipairs(r.needs)do if not trial:removeItems(n[1],n[2])then return false,'missing_'..n[1]end end
 local qty=r.qty;local dust=0
 if r.sawing then
  local level=skills:get('Woodworking').level;local tier=L.mill(w,p);local margin=math.max(0,level-r.level)
  local failure=math.max(3,28-margin*.4-(tier-r.woodTier)*5)
  if math.random(1,100)<=failure then qty=0;dust=math.random(2,4)else qty=1;if math.random(1,100)<=math.min(70,margin)then qty=qty+1 end;if level>=70 and math.random(1,100)<=math.min(25,level-69)then qty=qty+1 end;dust=1 end
 end
 if qty>0 and not trial:add(r.output,qty)then return false,'bags_full'end
 if dust>0 and not trial:add('Sawdust',dust)then return false,'bags_full'end
 local xp=qty>0 and r.xp or math.max(1,math.floor(r.xp/4));inv.bagSlots=trial.bagSlots;skills:addXP(r.skill,xp)
 return true,qty>0 and r.output or'Sawing failed: Sawdust',xp
end
function L.command(w,a,c)
 w.placedContainers=w.placedContainers or{};local trial=require('game.rune_inventory').clone(a.inv);local rows=require('game.items').copy(w.placedContainers)
 local placed,index;for i,v in ipairs(rows)do if v.id==c.id then placed=v;index=i;break end end
 local obj,bag
 if placed then if placed.owner~=L.owner(a)then return false,'This container belongs to another player'end;if(placed.x-a.player.x)^2+(placed.y-a.player.y)^2>55^2 then return false,'Move closer to the container'end;obj=placed.object
 else bag=trial:getBag(c.bag);obj=bag and bag.slots[c.slot] end
 if not obj or not L.defs[obj.name]or(c.name and obj.name~=c.name)then return false,'Container moved or missing'end;L.normalize(obj)
 if c.op=='containerPlace'then
  if placed then return false,'Already placed'end
  local x,y=a.player.x+16,a.player.y+16;if w.map and not w.map:isLand(x,y)or w.playerBlocked and w:playerBlocked(x,y,a.player.x,a.player.y)then return false,'No room to place here'end
  for _,v in ipairs(rows)do if(v.x-x)^2+(v.y-y)^2<18^2 then return false,'Another container is too close'end end
  local id=1;for _,v in ipairs(rows)do id=math.max(id,(v.id or 0)+1)end
  rows[#rows+1]={id=id,owner=L.owner(a),x=x,y=y,object=obj};bag.slots[c.slot]=nil
 elseif c.op=='containerRetrieve'then
  if not placed then return false,'Container is not placed'end;if not trial:addItemObject(obj)then return false,'bags_full'end;table.remove(rows,index)
 elseif c.op=='containerStore'then
  local source=trial:getBag(c.sourceBag);local it=source and source.slots[c.sourceSlot];if not it or it==obj then return false,'Select another item'end
  if require('game.fieldcraft_content').protected(it.name)then return false,'Keep camp deployment items in your main bags'end
  if L.defs[it.name]or trial:isBagItem(it.name)or it.name=='Rune Bag'or require('game.advanced_gear').isQuiver(it.name)then return false,'Containers cannot be nested'end
  local inner=require('game.inventory').new();inner.bagSlots={[1]={name='Medium Leather Bag',size=L.capacity(obj),slots=obj.contents}};inner.activeBag=1
  if not inner:addItemObject(it)then return false,'container_full'end;obj.contents=inner.bagSlots[1].slots;source.slots[c.sourceSlot]=nil
 elseif c.op=='containerWithdraw'then
  local it=obj.contents[c.contentSlot];if not it then return false,'empty'end
  if not trial:addItemObject(it)then return false,'bags_full'end;obj.contents[c.contentSlot]=nil
 else return false,'Unknown container action'end
 a.inv.bagSlots=trial.bagSlots;w.placedContainers=rows;return true,'Container updated'
end
function L.load(s)
 for i,wood in ipairs(L.woods)do
  local image=love.graphics.newImage('assets/storage_'..wood:lower()..'.png');image:setFilter('nearest','nearest')
  for j,kind in ipairs({'Crate','Barrel'})do local name=wood..' '..kind;s.itemImages[name]=image;s.itemQuads[name]=love.graphics.newQuad((j-1)*16,0,16,16,image:getDimensions());s.itemInfo[name]={title=name,type='Storage Container',detail='Place, open and retrieve with contents. '..L.defs[name].base..' base slots + D/C/B/A bonus 0/1/2/3. Filled carried containers slow movement and increase sprint cost. Containers cannot be nested.'}end
  image=love.graphics.newImage('assets/wood_'..wood:lower()..'.png');image:setFilter('nearest','nearest')
  for j,kind in ipairs({'Logs','Planks'})do local name=wood..' '..kind;s.itemImages[name]=image;s.itemQuads[name]=love.graphics.newQuad((j-1)*16,0,16,16,image:getDimensions());s.itemInfo[name]={title=name,type='Woodworking Material',detail='Saw '..wood..' Logs at a suitable mill (Woodworking '..L.levels[i]..'). Higher Woodworking gives extra planks and fewer failures.'}end
 end
 local dust=love.graphics.newImage('assets/sawdust.png');dust:setFilter('nearest','nearest');s.itemImages.Sawdust=dust;s.itemQuads.Sawdust=love.graphics.newQuad(0,0,16,16,dust:getDimensions());s.itemInfo.Sawdust={title='Sawdust',type='Woodworking Material',detail='Sawing byproduct. Failures produce more. Stacks to 20. Sells for 1 copper each.'}
 local black=love.graphics.newImage('assets/nails.png');black:setFilter('nearest','nearest')
 for i,metal in ipairs({'Copper','Iron','Steel'})do local name=metal..' Nails';s.itemImages[name]=black;s.itemQuads[name]=love.graphics.newQuad((i-1)*16,0,16,16,black:getDimensions());s.itemInfo[name]={title=name,type='Smithing Material',detail='1 '..metal..' Bar makes 5 nails. Requires Smithing 10. Used for crates and future construction.'}end
 s.sawmills=love.graphics.newImage('assets/sawmills.png');s.sawmills:setFilter('nearest','nearest');s.sawmillQuads={};for i=1,3 do s.sawmillQuads[i]=love.graphics.newQuad((i-1)*16,0,16,32,s.sawmills:getDimensions())end
end
function L.installInventory(I)
 local add=I.addItemObject;function I:addItemObject(obj)if L.defs[obj.name]then obj=L.normalize(require('game.items').copy(obj))end;return add(self,obj)end
 local stack=I.isStackable;function I:isStackable(name)if name=='Sawdust'or name=='Copper Nails'or name=='Iron Nails'or name=='Steel Nails'or name:match('^(Pine) Planks$')or name=='Oak Planks'or name=='Poplar Planks'then return true end;return stack(self,name)end
 local cap=I.maxStack;function I:maxStack(name)if name=='Sawdust'then return 20 end;if name=='Copper Nails'or name=='Iron Nails'or name=='Steel Nails'then return 100 end;if name=='Pine Planks'or name=='Oak Planks'or name=='Poplar Planks'then return 15 end;return cap(self,name)end
end
function L.deleteOwner(w,owner)
 for i=#(w.placedContainers or{}),1,-1 do local v=w.placedContainers[i];if v.owner==owner then w:addGroundItem(v.object.name,v.x,v.y,nil,v.object);table.remove(w.placedContainers,i)end end
end
function L.installWorld(W)
 local previous=W.playerBlocked;function W:playerBlocked(x,y,oldX,oldY,...)
  local pad=5;local function blocked(o)return o and math.abs(x-o.x)<8+pad and y>o.y-pad and y<o.y+16+pad end
  for _,o in ipairs(self.authoredObjects or{})do if L.mills[o.id]and blocked(o)then return true end end
  if not self.authoredObjects then for _,v in ipairs(self.villages or{self})do for id in pairs(L.mills)do if blocked(v[id])then return true end end end end
  return previous(self,x,y,oldX,oldY,...)
 end
end
return L
