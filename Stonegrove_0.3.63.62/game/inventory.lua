local Inventory={}; Inventory.__index=Inventory
local BAG_DEFS={
 ['Large Leather Bag']={size=10,icon='large'},['Large Leather Bag D']={size=10,icon='large'},['Large Leather Bag C']={size=12,icon='large'},['Large Leather Bag B']={size=14,icon='large'},['Large Leather Bag A']={size=16,icon='large'},
 ['Linen Bag']={size=14,icon='linen'},
 ['Small Leather Bag']={size=6,icon='small'},['Small Leather Bag D']={size=6,icon='small'},['Small Leather Bag C']={size=7,icon='small'},['Small Leather Bag B']={size=8,icon='small'},['Small Leather Bag A']={size=9,icon='small'}
}
local CURRENCY={['Copper Coins']=1,['Silver Coins']=100,['Gold Coins']=10000}
local STACKABLE={['Copper Coins']=true,['Silver Coins']=true,['Gold Coins']=true,['Ruby Dust']=true,['Sapphire Dust']=true,['Emerald Dust']=true,['Arrow Shafts']=true,['Pine Arrow Shafts']=true,['Oak Arrow Shafts']=true,['Copper Arrowheads']=true,['Copper Arrows']=true,['Feather']=true,['Egg']=true,['Flax']=true,['Wool']=true,['Wool Thread']=true,['Linen Cloth']=true,['Red Berries']=true,['Purple Berries']=true}
for _,n in ipairs({'Steel Bar','Iron Weave Thread','Snake Fang Arrows'})do STACKABLE[n]=true end
local STACK_MAX=999999999; local ITEM_STACK_MAX={['Arrow Shafts']=100,['Pine Arrow Shafts']=100,['Oak Arrow Shafts']=100,['Copper Arrowheads']=100,['Copper Arrows']=100,['Feather']=100,['Egg']=100,['Flax']=100,['Wool']=100,['Wool Thread']=100,['Linen Cloth']=100,['Red Berries']=100,['Purple Berries']=100}; local BANK_SIZE=25; local BANK_STACK_MAX=999999999
for _,n in ipairs({'Steel Bar','Iron Weave Thread','Snake Fang Arrows'})do ITEM_STACK_MAX[n]=100 end
for _,name in ipairs({"Dark Blue Dye","Dark Blue Cloth","Iron Bar","Small Coal Chunk","Large Coal Chunk","Iron Arrowheads","Iron Arrows"}) do STACKABLE[name]=true;ITEM_STACK_MAX[name]=100 end
for _,n in ipairs({'Black Berries','Black Dye','Black Linen Cloth'})do STACKABLE[n]=true;ITEM_STACK_MAX[n]=100 end
STACKABLE['Rawhide String']=true;ITEM_STACK_MAX['Rawhide String']=15
STACKABLE['Onyx Dust']=true;ITEM_STACK_MAX['Onyx Dust']=100
for _,n in ipairs({'Charred Wood','Fish Bones','Stone Gravel','Carved Feather','Carved Onyx','Green Slime Tube','Rough Onyx'}) do STACKABLE[n]=true;ITEM_STACK_MAX[n]=100 end
function Inventory:maxStack(name) if name=='Carved Feather'then return 100 end; if require("game.bone_religion").is(name)then return 15 end; if name=='Crab Meat'or name:match('^Cooked Crab Meat ')or name=='Burnt Crab Meat'then return 10 end; if require('game.seafood_content').stackable(name)then return 100 end; local d=require('game.custom_content').item(name);if d then return math.max(1,math.floor(tonumber(d.stackMax)or 1))end;if name=="Small Iron Chunk" or name=="Large Iron Chunk" then return 1 end;return ITEM_STACK_MAX[name] or STACK_MAX end
local function item(name,qty) return {name=name,qty=qty or 1} end
local function newBag(name) local d=BAG_DEFS[name];return {name=name,size=d.size,slots={}} end
function Inventory.new()
 local self=setmetatable({bankSize=BANK_SIZE},Inventory);self.bagSlots={newBag('Large Leather Bag'),nil,nil};self.activeBag=1;self.bank={}
 -- Starter tools live in the bank, without duplicate carried copies.
 for i,n in ipairs({'Copper Axe','Copper Pickaxe','Copper Knife','Copper Dagger','Copper Hammer','Copper Tongs','Copper Longsword','Copper Shield'})do self.bank[i]=item(n)end
 return self
end
function Inventory:isCurrency(name) return CURRENCY[name]~=nil end
function Inventory:isStackable(name)
 if name=='Carved Feather'then return true end
 if require("game.bone_religion").is(name)then return true end
 if require('game.seafood_content').stackable(name)then return true end;if name=='Shrimp'or name:match('^Cooked Shrimp ')or name=='Burnt Shrimp'or name=='Swordfish'or name:match('^Cooked Swordfish ')or name=='Burnt Swordfish'or name=='Raw Fish Fillet'or name:match('^Cooked Fish Fillet ')or name=='Burnt Fish Fillet'then return true end;if name=='Crab Meat'or name=='Lobster Meat'or name:match('^Cooked Crab Meat ')or name:match('^Cooked Lobster Meat ')or name=='Burnt Crab Meat'or name=='Burnt Lobster Meat'then return true end; local d=require('game.custom_content').item(name);if d then return self:maxStack(name)>1 end;return STACKABLE[name]==true end
function Inventory:applyStrengthBagBonus(level)
 local bonus=math.floor((level or 1)/10)+((level or 1)>=99 and 1 or 0)
 for i=1,self:bagSlotCount() do local b=self.bagSlots[i];if b then
  local d=BAG_DEFS[b.name] or {size=b.baseSize or b.size};b.baseSize=d.size;b.size=require('game.quality').bagSize(b,d.size)+bonus
 end end
end
function Inventory:bagBaseSize(name) local d=BAG_DEFS[name];return d and d.size or nil end
function Inventory:isBagItem(name) return BAG_DEFS[name]~=nil end
function Inventory:getBag(index) return self.bagSlots[index or self.activeBag] end
function Inventory:setActiveBag(index) if self.bagSlots[index] then self.activeBag=index;return true end return false end
function Inventory:usedSlots(index) local b=self:getBag(index);if not b then return 0 end;local n=0;for i=1,b.size do if b.slots[i] then n=n+1 end end;return n end
function Inventory:freeSlots(index) local b=self:getBag(index);return b and b.size-self:usedSlots(index) or 0 end
function Inventory:totalFreeSlots() local n=0;for i=1,self:bagSlotCount() do n=n+self:freeSlots(i) end;return n end
function Inventory:hasItem(name) for bi=1,self:bagSlotCount() do local b=self.bagSlots[bi];if b then for i=1,b.size do if b.slots[i] and b.slots[i].name==name then return true end end end end;return false end
function Inventory:canAdd(name,qty) qty=math.max(0,math.floor(qty or 1));if qty==0 then return true end;if self:isCurrency(name) then return true end;if not self:isStackable(name) then return self:totalFreeSlots()>=qty end;local cap=self:maxStack(name);local room=0;for bi=1,self:bagSlotCount() do local b=self.bagSlots[bi];if b then for i=1,b.size do local v=b.slots[i];if v and v.name==name and not v.blessed and not require('game.items').stateful(v) then room=room+math.max(0,cap-(v.qty or 1)) elseif not v then room=room+cap end;if room>=qty then return true end end end end;return false end
function Inventory:add(name,qty) qty=math.max(0,math.floor(qty or 1));if qty==0 then return true end;if self:isCurrency(name) then return self:setMoney(self:moneyCopper()+(qty*CURRENCY[name])) end;if not self:canAdd(name,qty) then return false end;local left=qty;if self:isStackable(name) then local cap=self:maxStack(name);for bi=1,self:bagSlotCount() do local b=self.bagSlots[bi];if b then for i=1,b.size do local v=b.slots[i];if v and v.name==name and not v.blessed and not require('game.items').stateful(v) and (v.qty or 1)<cap then local put=math.min(left,cap-(v.qty or 1));v.qty=(v.qty or 1)+put;left=left-put;if left<=0 then return true end end end end end;for bi=1,self:bagSlotCount() do local b=self.bagSlots[bi];if b then for i=1,b.size do if not b.slots[i] then local put=math.min(left,cap);b.slots[i]=item(name,put);left=left-put;if left<=0 then return true end end end end end;return false end;for bi=1,self:bagSlotCount() do local b=self.bagSlots[bi];if b then for i=1,b.size do if not b.slots[i] then b.slots[i]=item(name,1);left=left-1;if left<=0 then return true end end end end end;return false end
function Inventory:moneyCopper() local total=0;for bi=1,self:bagSlotCount() do local b=self.bagSlots[bi];if b then for i=1,b.size do local v=b.slots[i];if v and CURRENCY[v.name] then total=total+(v.qty or 1)*CURRENCY[v.name] end end end end;return total end
function Inventory:moneyText(total) total=total or self:moneyCopper();local g=math.floor(total/10000);total=total%10000;local s=math.floor(total/100);local c=total%100;return '['..c..'c, '..s..'s, '..g..'g]' end
function Inventory:bankMoneyCopper() local total=0;for i=1,(self.bankSize or BANK_SIZE) do local v=self.bank[i];if v and CURRENCY[v.name] then total=total+(v.qty or 1)*CURRENCY[v.name] end end;return total end
function Inventory:removeMoney(amount) amount=math.floor(amount or 0);if amount<0 or self:moneyCopper()<amount then return false end;local remain=self:moneyCopper()-amount;return self:setMoney(remain) end
function Inventory:addMoney(amount) amount=math.floor(amount or 0);if amount<=0 then return true end;return self:setMoney(self:moneyCopper()+amount) end
function Inventory:setMoney(total)
 total=math.max(0,math.floor(total or 0))
 local saved={}
 for bi=1,self:bagSlotCount() do local b=self.bagSlots[bi];if b then for i=1,b.size do local v=b.slots[i];if v and CURRENCY[v.name] then saved[#saved+1]={b=b,i=i,item=v};b.slots[i]=nil end end end end
 local parts={{'Gold Coins',math.floor(total/10000)}};local rem=total%10000;parts[#parts+1]={'Silver Coins',math.floor(rem/100)};parts[#parts+1]={'Copper Coins',rem%100}
 local needed=0;for _,p in ipairs(parts) do if p[2]>0 then needed=needed+1 end end
 if self:totalFreeSlots()<needed then for _,v in ipairs(saved) do v.b.slots[v.i]=v.item end;return false end
 for _,p in ipairs(parts) do if p[2]>0 then local placed=false;for bi=1,self:bagSlotCount() do local b=self.bagSlots[bi];if b and not placed then for i=1,b.size do if not b.slots[i] then b.slots[i]=item(p[1],p[2]);placed=true;break end end end end end end
 return true
end
function Inventory:setBankMoney(total)
 total=math.max(0,math.floor(total or 0))
 local saved={}
 for i=1,(self.bankSize or BANK_SIZE) do local v=self.bank[i];if v and CURRENCY[v.name] then saved[#saved+1]={i=i,item=v};self.bank[i]=nil end end
 local parts={{'Gold Coins',math.floor(total/10000)}};local rem=total%10000;parts[#parts+1]={'Silver Coins',math.floor(rem/100)};parts[#parts+1]={'Copper Coins',rem%100}
 local needed=0;for _,p in ipairs(parts) do if p[2]>0 then needed=needed+1 end end
 local free=0;for i=1,(self.bankSize or BANK_SIZE) do if not self.bank[i] then free=free+1 end end
 if free<needed then for _,v in ipairs(saved) do self.bank[v.i]=v.item end;return false end
 for _,p in ipairs(parts) do if p[2]>0 then for i=1,(self.bankSize or BANK_SIZE) do if not self.bank[i] then self.bank[i]=item(p[1],p[2]);break end end end end
 return true
end

function Inventory:countItem(name)
 local total=0
 for bi=1,self:bagSlotCount() do local b=self.bagSlots[bi];if b then for i=1,b.size do local v=b.slots[i];if v and v.name==name then total=total+(v.qty or 1) end end end end
 return total
end
function Inventory:removeItems(name,qty)
 qty=math.max(0,math.floor(qty or 0));if qty==0 then return true end;if self:countItem(name)<qty then return false end
 local left=qty
 for bi=1,self:bagSlotCount() do local b=self.bagSlots[bi];if b then for i=1,b.size do local v=b.slots[i];if v and v.name==name and left>0 then local take=math.min(v.qty or 1,left);local remain=(v.qty or 1)-take;left=left-take;if remain<=0 then b.slots[i]=nil else require("game.items").consumeProvenance(v,take);v.qty=remain end end end end end
 return left==0
end
function Inventory:removeAllItems(name) local n=self:countItem(name);if n>0 then self:removeItems(name,n) end;return n end
function Inventory:countBlessed(name)
 local n=0
 for bi=1,self:bagSlotCount() do local b=self.bagSlots[bi];if b then for i=1,b.size do local v=b.slots[i];if v and v.name==name and v.blessed==true then n=n+(v.qty or 1) end end end end
 return n
end
function Inventory:removeBlessed(name,qty)
 qty=math.max(0,math.floor(qty or 0));if qty==0 then return true end;if self:countBlessed(name)<qty then return false end
 local left=qty
 for bi=1,self:bagSlotCount() do local b=self.bagSlots[bi];if b then for i=1,b.size do local v=b.slots[i];if v and v.name==name and v.blessed==true and left>0 then local take=math.min(v.qty or 1,left);local remain=(v.qty or 1)-take;left=left-take;if remain<=0 then b.slots[i]=nil else require("game.items").consumeProvenance(v,take);v.qty=remain end end end end end
 return left==0
end


function Inventory:canAddObject(obj)
 if not obj or not obj.name then return false end
 if not require('game.items').stateful(obj) then return self:canAdd(obj.name,obj.qty or 1) end
 if not self:isStackable(obj.name) then return self:totalFreeSlots()>=1 end
 local room,cap=0,self:maxStack(obj.name)
 for bi=1,self:bagSlotCount() do local bag=self.bagSlots[bi];if bag then for i=1,bag.size do local v=bag.slots[i]
  if not v then room=room+cap elseif require('game.items').sameMetadata(obj,v) then room=room+math.max(0,cap-(v.qty or 1)) end
 end end end;return room>=(obj.qty or 1)
end
function Inventory:addItemObject(obj)
 if not obj or not obj.name then return false end
 if not require('game.items').stateful(obj) then return self:add(obj.name,obj.qty or 1) end
 if not self:canAddObject(obj) then return false end
 if not self:isStackable(obj.name) then
  for bi=1,self:bagSlotCount() do local bag=self.bagSlots[bi];if bag then for i=1,bag.size do if not bag.slots[i] then bag.slots[i]=obj;return true end end end end
 else
  local left,cap=obj.qty or 1,self:maxStack(obj.name)
  for bi=1,self:bagSlotCount() do local bag=self.bagSlots[bi];if bag then for i=1,bag.size do local v=bag.slots[i]
   if v and require('game.items').sameMetadata(obj,v) then local n=math.min(left,math.max(0,cap-(v.qty or 1)));require("game.items").mergeProvenance(v,obj,n,(obj.qty or 1)-left);v.qty=(v.qty or 1)+n;left=left-n;if left==0 then return true end end
  end end end
  for bi=1,self:bagSlotCount() do local bag=self.bagSlots[bi];if bag then for i=1,bag.size do if not bag.slots[i] then local v=require('game.items').stackPart(obj,math.min(left,cap),(obj.qty or 1)-left);bag.slots[i]=v;left=left-v.qty;if left==0 then return true end end end end end
 end;return false
end
function Inventory:removeSlot(bi,slot) local b=self:getBag(bi);if not b then return nil end;local it=b.slots[slot];b.slots[slot]=nil;return it end
local function mergeSlots(self,sourceBag,sourceSlot,targetBag,targetSlot)
 local a,c=sourceBag.slots[sourceSlot],targetBag.slots[targetSlot]
 if not a or not c or a.name~=c.name or not self:isStackable(a.name) or (a.blessed==true)~=(c.blessed==true) then return false,nil,0 end
 if not require('game.items').sameMetadata(a,c)then return false,nil,0 end;local cap=self:maxStack(a.name);local room=math.max(0,cap-(c.qty or 1));if room<=0 then return false,nil,0 end
 local moved=math.min(a.qty or 1,room);require("game.items").mergeProvenance(c,a,moved);require("game.items").consumeProvenance(a,moved);c.qty=(c.qty or 1)+moved;a.qty=(a.qty or 1)-moved;if a.qty<=0 then sourceBag.slots[sourceSlot]=nil end
 return true,'merge',moved
end
function Inventory:moveSlot(bi,from,to) local b=self:getBag(bi);if not b or from==to or from<1 or to<1 or from>b.size or to>b.size then return false,'invalid' end;local a,c=b.slots[from],b.slots[to];if not a then return false,'empty' end;if c then local ok,action,moved=mergeSlots(self,b,from,b,to);if ok then return ok,action,moved end end;b.slots[from],b.slots[to]=c,a;return true,'swap',a.qty or 1 end
function Inventory:moveSlotBetween(fromBi,fromSlot,toBi,toSlot) local aBag,bBag=self:getBag(fromBi),self:getBag(toBi);if not aBag or not bBag or fromSlot<1 or toSlot<1 or fromSlot>aBag.size or toSlot>bBag.size then return false,'invalid' end;if fromBi==toBi then return self:moveSlot(fromBi,fromSlot,toSlot) end;local a,b=aBag.slots[fromSlot],bBag.slots[toSlot];if not a then return false,'empty' end;if b then local ok,action,moved=mergeSlots(self,aBag,fromSlot,bBag,toSlot);if ok then return ok,action,moved end end;aBag.slots[fromSlot],bBag.slots[toSlot]=b,a;return true,b and 'swap_bags' or 'move_bags',a.qty or 1 end
function Inventory:equipBagFromItem(sourceBagIndex,sourceSlot,targetBagSlot) if targetBagSlot<1 or targetBagSlot>3 or self.bagSlots[targetBagSlot] then return false,'occupied' end;local source=self:getBag(sourceBagIndex);local it=source and source.slots[sourceSlot];if not it or not self:isBagItem(it.name) then return false,'not_bag' end;self.bagSlots[targetBagSlot]=newBag(it.name);self.bagSlots[targetBagSlot].qualityGrade=it.qualityGrade;self.bagSlots[targetBagSlot].size=require('game.quality').bagSize(it,self.bagSlots[targetBagSlot].size);source.slots[sourceSlot]=nil;return true,'equipped' end
function Inventory:unequipBag(index) local b=self.bagSlots[index];if not b then return false,"empty" end;if self:usedSlots(index)>0 then return false,"bag_not_empty" end;local name=b.name;self.bagSlots[index]=nil;if not self:addItemObject({name=name,qty=1,qualityGrade=b.qualityGrade})then self.bagSlots[index]=b;return false,"no_room" end;if self.activeBag==index then for i=1,self:bagSlotCount() do if self.bagSlots[i] then self.activeBag=i;break end end end;return true,name end
function Inventory:bankUpgradeCost()
 local upgrades=math.max(0,math.floor(((self.bankSize or BANK_SIZE)-BANK_SIZE)/25))
 return math.floor(10000*(1.10^upgrades)+0.5)
end
function Inventory:upgradeBank(slots) self.bankSize=math.min(250,(self.bankSize or BANK_SIZE)+(slots or 25));return self.bankSize end
function Inventory:bankUsed() local n=0;for i=1,(self.bankSize or BANK_SIZE) do if self.bank[i] then n=n+1 end end;return n end
function Inventory:bankAdd(name,qty) qty=qty or 1;if self:isCurrency(name) then return self:setBankMoney(self:bankMoneyCopper()+(qty*CURRENCY[name])) end;for i=1,(self.bankSize or BANK_SIZE) do local v=self.bank[i];if v and v.name==name and not require("game.items").stateful(v) then v.qty=(v.qty or 1)+qty;return true end end;for i=1,(self.bankSize or BANK_SIZE) do if not self.bank[i] then self.bank[i]=item(name,qty);return true end end;return false end
function Inventory:depositSlot(bi,slot)
 local b=self:getBag(bi);local it=b and b.slots[slot];if not it then return false,'empty' end
 -- Stateful ammo containers must be stored as the actual item object. Converting them
 -- through bankAdd would discard Rune Bag materials or Quiver arrow contents.
 if require('game.items').stateful(it) then
  for i=1,(self.bankSize or BANK_SIZE) do
   if not self.bank[i] then self.bank[i]=it;b.slots[slot]=nil;return true,it.name,self:isStackable(it.name) and (it.qty or 1) or 1 end
  end
  return false,'bank_full',0
 end
 if not self:bankAdd(it.name,it.qty or 1) then return false,'bank_full',0 end
 b.slots[slot]=nil;return true,it.name,it.qty or 1
end

function Inventory:depositAll(name)
 local targets={};local normalQty,stateful=0,0
 for bi=1,self:bagSlotCount() do local bag=self.bagSlots[bi];if bag then for i=1,bag.size do local v=bag.slots[i];if v and v.name==name then
  targets[#targets+1]={bi,i};if require('game.items').stateful(v) then stateful=stateful+1 else normalQty=normalQty+(v.qty or 1) end
 end end end end
 if #targets==0 then return false,'none',0 end
 local free,normalStack=0,false;for i=1,self.bankSize do local v=self.bank[i];if not v then free=free+1 elseif v.name==name and not require('game.items').stateful(v) then normalStack=true end end
 local required=stateful+((normalQty>0 and not normalStack and not self:isCurrency(name)) and 1 or 0)
 if free<required then return false,'bank_full',0 end
 local moved=0;for _,v in ipairs(targets) do local ok,_,qty=self:depositSlot(v[1],v[2]);assert(ok);moved=moved+qty end;return true,name,moved
end
function Inventory:depositEverything()
 local moved=0
 -- Move one occupied bag slot at a time. Bank stacks normal items, so successful moves free inventory immediately.
 for bi=1,self:bagSlotCount() do
  local b=self.bagSlots[bi]
  if b then
   for slot=1,b.size do
    local it=b.slots[slot]
    if it then
     local qty=it.qty or 1
     local ok,_,count=self:depositSlot(bi,slot);if ok then moved=moved+count end
    end
   end
  end
 end
 return moved>0,moved
end
function Inventory:addSaleMoney(amount) amount=math.max(0,math.floor(amount or 0));if amount==0 then return true end;return self:setMoney(self:moneyCopper()+amount) end
function Inventory:withdrawBankSlotAmount(slot,amount)
 local it=self.bank[slot];if not it then return false,'empty',0 end
 -- Container objects carry state and must be withdrawn whole rather than converted into a plain item stack.
 if require('game.items').stateful(it) then
  if self:isStackable(it.name) then local take=math.min(it.qty or 1,math.max(1,math.floor(amount or 1)));local obj=require('game.items').stackPart(it,take);if not self:addItemObject(obj) then return false,'bags_full',0 end;require('game.items').consumeProvenance(it,take);it.qty=(it.qty or 1)-take;if it.qty<=0 then self.bank[slot]=nil end;return true,obj.name,take end
  local take=math.min(it.qty or 1,math.max(1,math.floor(amount or 1)));local trial=require('game.rune_inventory').clone(self)
  for i=1,take do local obj=require('game.items').copy(it);obj.qty=1;if not trial:addItemObject(obj)then return false,'bags_full',0 end end
  self.bagSlots=trial.bagSlots;self.activeBag=trial.activeBag;it.qty=(it.qty or 1)-take;if it.qty<=0 then self.bank[slot]=nil end;return true,it.name,take
 end
 local available=math.max(1,math.floor(it.qty or 1));local take=math.min(available,math.max(1,math.floor(amount or 1)))
 if self:isCurrency(it.name) then
  if not self:add(it.name,take) then return false,'bags_full',0 end
 elseif not self:isStackable(it.name) then
  -- Bank stacks can contain repeated non-stackables; inventory needs one slot per item.
  if not self:canAdd(it.name,take) or not self:add(it.name,take) then return false,'bags_full',0 end
 else
  if not self:add(it.name,take) then return false,'bags_full',0 end
 end
 it.qty=available-take;if it.qty<=0 then self.bank[slot]=nil end
 return true,it.name,take
end
function Inventory:withdrawBankSlot(slot) return self:withdrawBankSlotAmount(slot,1) end
-- Split iron stacks created by 0.2.40-0.2.44 without losing existing ore.
function Inventory:consolidateBars()
 for _,name in ipairs({'Iron Bar','Steel Bar'})do
  local targets={};for _,bag in pairs(self.bagSlots)do for slot=1,bag.size do local obj=bag.slots[slot]
   if obj and obj.name==name and not obj.blessed and not obj.sockets and not obj.qualityGrade then
    for _,target in ipairs(targets)do local amount=math.min(obj.qty or 1,math.max(0,self:maxStack(name)-(target.qty or 1)));target.qty=(target.qty or 1)+amount;obj.qty=(obj.qty or 1)-amount;if obj.qty<=0 then bag.slots[slot]=nil;break end end
    if bag.slots[slot]then targets[#targets+1]=obj end
   end
  end end
 end
end
function Inventory:migrateIronStacks()
 local overflow={}
 for bi=1,self:bagSlotCount() do local b=self.bagSlots[bi];if b then for i=1,b.size do local v=b.slots[i]
  if v and (v.name=='Small Iron Chunk' or v.name=='Large Iron Chunk') and (v.qty or 1)>1 then
   overflow[v.name]=(overflow[v.name] or 0)+v.qty-1;v.qty=1
  end
 end end end
 local moved=0
 for _,name in ipairs({'Small Iron Chunk','Large Iron Chunk'}) do local qty=overflow[name] or 0
  local toBag=math.min(qty,self:totalFreeSlots());if toBag>0 then self:add(name,toBag) end
  qty=qty-toBag
  if qty>0 then
   if not self:bankAdd(name,qty) then
    self.bankSize=(self.bankSize or 25)+1;self.bank[self.bankSize]={name=name,qty=qty}
   end
   moved=moved+qty
  end
 end
 return moved
end
require('game.bag_system').install(Inventory)
require('game.rune_bank').install(Inventory)
local migrateBags=Inventory.migrateBags
function Inventory:migrateBags(level)
 migrateBags(self,level)
 local extras={}
 for _,bag in pairs(self.bagSlots)do for _,obj in pairs(bag.slots)do
  if obj.name=='Rawhide String'or obj.name=='Crab Meat'or obj.name:match('^Cooked Crab Meat ')or obj.name=='Burnt Crab Meat'then
   local cap=self:maxStack(obj.name);local left=(obj.qty or 1)-cap
   if left>0 then obj.qty=cap;while left>0 do local part=require('game.items').copy(obj);part.qty=math.min(left,cap);extras[#extras+1]=part;left=left-part.qty end end
  end
 end end
 for _,obj in ipairs(extras)do if not self:addItemObject(obj)then local slot=1;while self.bank[slot]do slot=slot+1 end;self.bank[slot]=obj;self.bankSize=math.max(self.bankSize or 25,slot)end end
end
require('game.lumber').installInventory(Inventory)
return Inventory
