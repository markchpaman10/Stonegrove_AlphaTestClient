local Shop={};Shop.__index=Shop
local TIERS={['Leather Helm']=1,['Copper Helm']=1,['Copper Armor']=1,['Leather Armor']=1,['Copper Dagger']=1,['Flint and Steel']=1,['Copper Axe']=1,['Copper Pickaxe']=1,['Copper Hammer']=1,['Chisel']=1,['Ruby-bearing Rock']=1,['Sapphire-bearing Rock']=1,['Emerald-bearing Rock']=1,['Rough Ruby']=1,['Rough Sapphire']=1,['Rough Emerald']=1,['Cut Ruby']=1,['Cut Sapphire']=1,['Cut Emerald']=1,['Copper Tongs']=1,['Copper Longsword']=1,['Copper ore']=1,['Logs']=1,['Copper Bar']=1,['Basic Wood Parts']=1,['Bronze bar']=1,['Large Leather Bag']=1,['Small Leather Bag']=1,['Raw Hide']=1,['Torn Hide']=1,['Soaked Hide']=1,['Leather']=1,['Bones']=1,['Hemp Fibers']=1,['Bow String']=1,['Empty Flask']=1,['Empty Tube']=1,['Large Blue Mushroom']=1,['Brown Mushroom']=1,['Bush Root']=1,['Bush Greens']=1,['Purple Berries']=1,['Red Berries']=1,['Health Flask']=1,['Health Tube']=1,['Antipoison Flask']=1,['Antipoison Tube']=1,['Green Slime Jar']=1,['Needle']=1,['Wizard Hat']=1,['Wizard Robes']=1,['Dyed Blue Cloth Strip']=1,['Cloth Strip']=1,['Shears']=1,['Wool']=1,['Staff']=1,['Blue Dye']=1,['Fishing Pole']=1,['Large Fish']=1,['Small Fish']=1,['Eel']=1,['Raw Fish Fillet']=1,['Cooked Fish Fillet A']=1,['Cooked Fish Fillet B']=1,['Cooked Fish Fillet C']=1,['Cooked Fish Fillet D']=1,['Burnt Fish Fillet']=1,['Large Meat']=1,['Cooked Large Meat A']=1,['Cooked Large Meat B']=1,['Cooked Large Meat C']=1,['Cooked Large Meat D']=1,['Burnt Large Meat']=1,['Small Meat']=1,['Cooked Small Meat A']=1,['Cooked Small Meat B']=1,['Cooked Small Meat C']=1,['Cooked Small Meat D']=1,['Burnt Small Meat']=1,['Jerky A']=1,['Jerky B']=1,['Jerky C']=1,['Jerky D']=1,['Burnt Jerky']=1,['Copper Shield']=1,['Rawhide String']=1,['Arrow Shafts']=1,['Copper Arrowheads']=1,['Copper Arrows']=1,['Unstrung Bow']=1,['Bow']=1,['Small Leather Bag A']=1,['Small Leather Bag B']=1,['Small Leather Bag C']=1,['Small Leather Bag D']=1,['Large Leather Bag A']=1,['Large Leather Bag B']=1,['Large Leather Bag C']=1,['Large Leather Bag D']=1,['Ruby Dust']=1,['Sapphire Dust']=1,['Emerald Dust']=1,['Melee Skill Page']=1,['Ranged Skill Page']=1,['Empty Spell Page']=1,['Inscription Pen and Ink']=1,['Pine Logs']=1,['Oak Logs']=2,['Pine Wood Parts']=1,['Oak Wood Parts']=2,['Pine Staff']=1,['Oak Staff']=2,['Pine Arrow Shafts']=1,['Oak Arrow Shafts']=2,['Pine Unstrung Bow']=1,['Oak Unstrung Bow']=2,['Pine Bow']=1,['Oak Bow']=2,['Small Copper Chunk']=1,['Large Copper Chunk']=2,['Large Raw Leather']=2,['Large Soaked Leather']=2,['Large Leather']=2,['Egg']=1,['Feather']=1,['Raw Chicken']=1,['Cooked Chicken']=1,['Burnt Chicken']=1,['Quiver']=1,['Rune Bag']=1}
TIERS['Rough Onyx']=1;TIERS['Cut Onyx']=1;TIERS['Onyx Dust']=1;TIERS['Magic Skill Page']=1
local function hash(s) local h=0;for i=1,#s do h=(h*31+s:byte(i))%2147483647 end;return h end
local function rand100(period,name,salt) local n=(period*1103515245+hash(name)*97+salt*12345)%2147483647;return n%101 end
function Shop.new(logger) local self=setmetatable({logger=logger,slots={},period=-1,seed=1},Shop);self:update(true);return self end
function Shop.trader(logger,title)
 local self=setmetatable({logger=logger,slots={},period=math.floor(os.time()/1800),seed=1,title=title or "Trader",traderOnly=true,tradeOnly=false},Shop)
 return self
end
function Shop.trade(logger,title,items,accepted,materialItems,toolItems)
 local materialSet,toolSet={},{}
 for _,name in ipairs(toolItems or {}) do toolSet[name]=true end
 for _,name in ipairs(materialItems or {}) do if not toolSet[name] then materialSet[name]=true end end
 local self=setmetatable({logger=logger,slots={},period=math.floor(os.time()/1800),seed=1,title=title or "Trade Shop",tradeOnly=true,accepted=accepted or {},materialItems=materialSet,materialPriceMult=4},Shop)
 self.seed=((self.period*17+5)%9)+1
 for _,name in ipairs(items or {}) do self.slots[#self.slots+1]={name=name,qty=999} end
 return self
end
function Shop:reset(period) local owned={};for _,row in ipairs(self.slots or {}) do if row.object then owned[#owned+1]=row end end;self.period=period;self.seed=((period*17+5)%9)+1;self.slots={{name='Copper Helm',qty=10},{name='Copper Armor',qty=10},{name='Leather Armor',qty=10},{name='Copper Dagger',qty=10},{name='Flint and Steel',qty=10},{name='Copper Axe',qty=10},{name='Copper Pickaxe',qty=10},{name='Copper Hammer',qty=10},{name='Chisel',qty=10},{name='Copper Tongs',qty=10},{name='Copper Longsword',qty=10},{name='Copper ore',qty=10},{name='Logs',qty=10},{name='Copper Bar',qty=10},{name='Basic Wood Parts',qty=10},{name='Bronze bar',qty=10},{name='Large Leather Bag',qty=10},{name='Small Leather Bag',qty=10},{name='Raw Hide',qty=10},{name='Torn Hide',qty=10},{name='Soaked Hide',qty=10},{name='Leather',qty=10},{name='Bones',qty=10},{name='Hemp Fibers',qty=10},{name='Bow String',qty=10},{name='Empty Flask',qty=10},{name='Empty Tube',qty=10},{name='Large Blue Mushroom',qty=10},{name='Brown Mushroom',qty=10},{name='Bush Root',qty=10},{name='Bush Greens',qty=10},{name='Purple Berries',qty=10},{name='Red Berries',qty=10},{name='Health Flask',qty=10},{name='Health Tube',qty=10},{name='Antipoison Flask',qty=10},{name='Antipoison Tube',qty=10},{name='Green Slime Jar',qty=10},{name='Needle',qty=10},{name='Wizard Hat',qty=10},{name='Wizard Robes',qty=10},{name='Dyed Blue Cloth Strip',qty=10},{name='Cloth Strip',qty=10},{name='Shears',qty=10},{name='Wool',qty=10},{name='Staff',qty=10},{name='Blue Dye',qty=10},{name='Fishing Pole',qty=10},{name='Jerky A',qty=10},{name='Jerky B',qty=10},{name='Jerky C',qty=10},{name='Jerky D',qty=10},{name='Burnt Jerky',qty=10},{name='Copper Shield',qty=10},{name='Rawhide String',qty=10},{name='Arrow Shafts',qty=10},{name='Copper Arrowheads',qty=10},{name='Copper Arrows',qty=10},{name='Unstrung Bow',qty=10},{name='Bow',qty=10},{name='Ruby Dust',qty=10},{name='Sapphire Dust',qty=10},{name='Emerald Dust',qty=10},{name='Melee Skill Page',qty=10},{name='Ranged Skill Page',qty=10},{name='Empty Spell Page',qty=10},{name='Inscription Pen and Ink',qty=10}};
 -- Keep the test shop stocked with every registered static item. New items added to TIERS
 -- automatically become available here instead of needing a second hand-maintained list.
 local stocked={}
 for _,slot in ipairs(self.slots) do if slot and slot.name then stocked[slot.name]=true end end
 local missing={}
 for name,_ in pairs(TIERS) do if not stocked[name] then missing[#missing+1]=name end end
 table.sort(missing)
 for _,name in ipairs(missing) do self.slots[#self.slots+1]={name=name,qty=10} end
 for _,row in ipairs(owned) do self.slots[#self.slots+1]=row end
 if self.logger then self.logger:log('SHOP_SEED_CHANGED',{seed=self.seed,period=period}) end end
function Shop:update(force) if self.tradeOnly or self.traderOnly then return false end;local p=math.floor(os.time()/1800);if force or p~=self.period then self:reset(p);return true end;return false end
function Shop:secondsToChange() return 1800-(os.time()%1800) end
function Shop:tier(name) return (require("game.iron_gear").items[name] and 3) or TIERS[name] or 1 end
function Shop:buyPrice(name)
 local bag=require('game.bag_system').defs[require('game.bag_system').name(name)];if bag then return bag.value+self.seed*100 end
 local d=require('game.custom_content').item(name);if d and tonumber(d.value)then return math.max(1,math.floor(tonumber(d.value)))end
 if name=="Stone Gravel" then return 5 end
 if name:find("Large Leather Bag",1,true) then return 9000+self.seed*200 end
 if name:find("Small Leather Bag",1,true) then return 4200+self.seed*150 end
 local base=rand100(self.period,name,1)*self.seed*self:tier(name)
 if self.tradeOnly and self.materialItems and self.materialItems[name] then return base*(self.materialPriceMult or 4) end
 return base
end
function Shop:baseSellPrice(name) local d=require('game.custom_content').item(name);if d and tonumber(d.value)then return math.max(1,math.floor(tonumber(d.value)*.5))end;if name:sub(1,6)=="Burnt " then return 1 end;return rand100(self.period,name,2)*self.seed*self:tier(name) end
function Shop:acceptsSale(name) if self.traderOnly then return true end;return (not self.tradeOnly) or self.accepted[name]==true end
function Shop:sellPrice(name)if name=='Sawdust'then return 1 end; if name=="Stone Gravel" then return self.traderOnly and 1 or 2 end;local base=self:baseSellPrice(name);if self.traderOnly then return math.max(1,math.floor(base*0.25)) end;if self.tradeOnly and self.accepted[name] then return base+10 end;return base end
function Shop:addSold(name,qty) if self.traderOnly then return true end;if self.tradeOnly then return self:acceptsSale(name) end;qty=qty or 1;for i=1,#self.slots do local v=self.slots[i];if v and v.name==name and not v.object then v.qty=v.qty+qty;return true end end;for i=1,math.max(25,#self.slots+1) do if not self.slots[i] then self.slots[i]={name=name,qty=qty};return true end end;return false end
function Shop:buy(slot,inventory,qty)
 local it=self.slots[slot];if not it or(it.qty or 0)<=0 then return false,'empty'end
 local unit=math.max(1,math.floor(self:buyPrice(it.name)*(it.priceMult or 1)));local all=qty=='all'
 qty=all and math.min(it.qty,math.floor(inventory:moneyCopper()/unit))or math.max(1,math.min(qty or 1,it.qty))
 if qty<=0 or inventory:moneyCopper()<unit*qty then return false,'not_enough_currency'end
 local trial,reason
 repeat
  trial=require('game.rune_inventory').clone(inventory)
  local ok=trial:removeMoney(unit*qty)
  if not ok then reason='currency_error'
  elseif it.object and not trial:isStackable(it.name)then
   for i=1,qty do local obj=require('game.items').copy(it.object);obj.qty=1;if require('game.bone_religion').is(obj.name)then obj=require('game.bone_religion').purchase(obj)end;if not trial:addItemObject(obj)then ok=false;break end end
  elseif it.object then local obj=require('game.items').stackPart(it.object,qty);if require('game.bone_religion').is(obj.name)then obj=require('game.bone_religion').purchase(obj)end;ok=trial:addItemObject(obj)
  else ok=trial:add(it.name,qty)end
  if ok then break end
  reason=reason or'bags_full';trial=nil;if not all then break end;qty=qty-1
 until qty<=0
 if not trial then return false,reason or'bags_full'end
 inventory.bagSlots=trial.bagSlots
 local total=unit*qty;if it.object then require("game.items").consumeProvenance(it.object,qty);it.object.qty=(it.object.qty or it.qty)-qty end;it.qty=it.qty-qty;if it.qty<=0 then table.remove(self.slots,slot)end
 if self.logger then self.logger:log('SHOP_BUY',{item=it.name,qty=qty,unitPrice=unit,totalPrice=total})end
 return true,it.name,total,qty
end

function Shop:sellObject(obj,inventory)
 if not obj or not obj.name then return false,'empty' end
 if not self:acceptsSale(obj.name) then return false,'not_accepted' end
 if not require('game.items').stateful(obj) then return self:sell(obj.name,obj.qty or 1,inventory) end
 local quantity=inventory:isStackable(obj.name)and(obj.qty or 1)or 1;local price=self:sellPrice(obj.name)*quantity
 if not inventory:addSaleMoney(price) then return false,'currency_bag_full' end
 self.slots[#self.slots+1]={name=obj.name,qty=quantity,object=obj};return true,price
end
function Shop:sell(name,qty,inventory) qty=qty or 1;if inventory:isCurrency(name) then return false,'cannot_sell_currency' end;local price=self:sellPrice(name)*qty;if not inventory:addSaleMoney(price) then return false,'currency_bag_full' end;if not self:addSold(name,qty) then inventory:removeMoney(price);return false,'shop_full' end;return true,price end
function Shop:sellAll(name,inventory)
 if inventory:isCurrency(name) then return false,'cannot_sell_currency',0 end
 if not self:acceptsSale(name) then return false,'not_accepted',0 end
 local slots={};local count=0;local price=0
 for bi=1,4 do local bag=inventory:getBag(bi);if bag then for i=1,bag.size do local obj=bag.slots[i]
  if obj and obj.name==name then local qty=inventory:isStackable(name)and(obj.qty or 1)or 1;slots[#slots+1]={bag=bag,index=i,obj=obj};count=count+qty;price=price+self:sellPrice(name)*qty end
 end end end
 if count==0 then return false,'none',0 end
 local trial=require('game.rune_inventory').clone(inventory)
 for _,v in ipairs(slots)do local index;for bi=1,4 do if inventory:getBag(bi)==v.bag then index=bi;break end end;trial:getBag(index).slots[v.index]=nil end
 if not trial:addSaleMoney(price)then return false,'currency_bag_full',0 end
 local old=require('game.items').copy(self.slots)
 for _,v in ipairs(slots)do
  if require('game.items').stateful(v.obj)then self.slots[#self.slots+1]={name=name,qty=inventory:isStackable(name)and(v.obj.qty or 1)or 1,object=require('game.items').copy(v.obj)}
  elseif not self:addSold(name,v.obj.qty or 1)then self.slots=old;return false,'shop_full',0 end
 end
 inventory.bagSlots=trial.bagSlots
 return true,price,count
end
function Shop:sellInventory(inventory)
 local trial=require('game.rune_inventory').clone(inventory);local old=require('game.items').copy(self.slots);local count,total=0,0
 for bi=1,4 do local bag=trial:getBag(bi);if bag then for i=1,bag.size do local obj=bag.slots[i]
  if obj and not trial:isCurrency(obj.name)and self:acceptsSale(obj.name)then
   -- Loaded containers must be emptied first: bulk sale must not discard contents.
   local loaded=obj.arrowType and(obj.qty or 0)>0 or obj.tailPending;for _,q in pairs(obj.materials or{})do if type(q)=='number'and q>0 then loaded=true end end
   if not loaded then bag.slots[i]=nil;local ok,price=self:sellObject(obj,trial);if not ok then self.slots=old;return false,price,0 end;count=count+(trial:isStackable(obj.name)and(obj.qty or 1)or 1);total=total+price end
  end
 end end end
 if count==0 then self.slots=old;return false,'none',0 end
 inventory.bagSlots=trial.bagSlots;return true,total,count
end
local accepted=Shop.acceptsSale
function Shop:acceptsSale(name)if require('game.fieldcraft_content').tents[name]then return false end;return accepted(self,name)end
local buy=Shop.buy
function Shop:buy(name,...)
 local row=type(name)=='number'and self.slots[name];if require('game.fieldcraft_content').tents[row and row.name or name]then return false,'Tents must be crafted'end
 return buy(self,name,...)
end
return Shop
