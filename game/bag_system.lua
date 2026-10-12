local B={schema=2,gradeBonus={D=0,C=1,B=2,A=3},quality={C=55,B=85,A=115,skillCap=35},defs={}}
for row,size in ipairs({'Small','Medium','Large'})do for col,material in ipairs({'Leather','Linen'})do local name=size..' '..material..' Bag';B.defs[name]={base=(row*2)+(material=='Leather'and 1 or 0),material=material,size=size,x=(col-1)*16,y=(row-1)*16,level=row*10,value=(material=='Leather'and({4200,6500,9000})or({2800,4400,6000}))[row]}end end
function B.name(name)return name=='Linen Bag'and'Large Linen Bag'or(name or''):gsub(' [DCBA]$','')end
function B.grade(obj)return(obj and(obj.qualityGrade or(obj.name or''):match(' ([DCBA])$')))or'D'end
function B.strength(level)return math.floor(math.min(99,math.max(1,level or 1))/10)end
function B.limit(level)return(level or 1)>=99 and 4 or 3 end
function B.capacity(obj,level)local d=B.defs[B.name(obj.name)];return d and(d.base+(B.gradeBonus[B.grade(obj)]or 0)+B.strength(level))end
function B.roll(level)local n=math.random(1,100)+math.min(B.quality.skillCap,math.max(1,level or 1));return n>=B.quality.A and'A'or n>=B.quality.B and'B'or n>=B.quality.C and'C'or'D'end
function B.item(obj)local out=require('game.items').copy(obj);out.name=B.name(out.name);out.qualityGrade=B.grade(obj);out.qty=obj.qty or 1;out.slots=nil;out.size=nil;out.baseSize=nil;return out end
function B.tooltip(obj,level)local d=B.defs[B.name(obj.name)];if not d then return end;local grade=B.grade(obj);return{title=B.name(obj.name)..' [Grade '..grade..']',type='Bag',detail='Material: '..d.material..'\nSize: '..d.size..'\nBase slots: '..d.base..'\nGrade bonus: +'..B.gradeBonus[grade]..'\nStrength bonus: +'..B.strength(level)..'\nTotal available slots: '..B.capacity(obj,level)}end
function B.load(s)
 local img=love.graphics.newImage('assets/bagProgression.png');img:setFilter('nearest','nearest');s.bagProgression=img
 for name,d in pairs(B.defs)do s.itemImages[name]=img;s.itemQuads[name]=love.graphics.newQuad(d.x,d.y,16,16,img:getDimensions());s.itemInfo[name]=B.tooltip({name=name,qualityGrade='D'},1)end
 -- Aliases remain readable in old world loot/shop data but use the supplied new art.
 for _,name in ipairs({'Linen Bag','Small Leather Bag D','Small Leather Bag C','Small Leather Bag B','Small Leather Bag A','Large Leather Bag D','Large Leather Bag C','Large Leather Bag B','Large Leather Bag A'})do local n=B.name(name);s.itemImages[name]=s.itemImages[n];s.itemQuads[name]=s.itemQuads[n];s.itemInfo[name]=B.tooltip({name=name},1)end
end
function B.validate(bags,skills)
 local level=require('game.skills').new():levelForXP(((skills or{}).Strength or{}).xp or 0)
 for index,bag in pairs(bags or{})do
  assert(type(index)=='number'and index%1==0 and index>=1 and index<=B.limit(level),'Bag equipment slot locked')
  assert(type(bag)=='table'and B.defs[bag.name]and B.gradeBonus[bag.qualityGrade]~=nil,'Invalid bag or grade')
  assert(bag.size==B.capacity(bag,level),'Invalid bag capacity')
  for slot,obj in pairs(bag.slots or{})do assert(type(slot)=='number'and slot%1==0 and slot>=1 and slot<=bag.size and type(obj)=='table','Invalid inventory slot');require('game.lumber').validate(obj);if B.defs[B.name(obj.name)]then assert(B.gradeBonus[B.grade(obj)]~=nil,'Invalid bag item grade')end end
 end
 return true
end
function B.install(I)
 function I:bagSlotCount()return B.limit(self.strengthLevel)end
 function I:bagBaseSize(name)local d=B.defs[B.name(name)];return d and d.base end
 function I:isBagItem(name)return B.defs[B.name(name)]~=nil end
 function I:applyStrengthBagBonus(level)
  self.strengthLevel=math.min(99,math.max(1,level or 1))
  for i=1,4 do local b=self.bagSlots[i];if b then b.baseSize=self:bagBaseSize(b.name);b.size=B.capacity(b,self.strengthLevel)end end
 end
 function I:migrateBags(level)
  local overflow={};local oldSchema=self.bagSchemaVersion~=B.schema
  for i=1,4 do local b=self.bagSlots[i];if b then
   b.qualityGrade=B.grade(b);b.name=B.name(b.name);assert(B.defs[b.name],'Unknown saved bag')
   b.slots=b.slots or{};local cap=B.capacity(b,level)
   for slot,obj in pairs(b.slots)do if self:isBagItem(obj.name)then b.slots[slot]=B.item(obj);obj=b.slots[slot]end;if slot>cap or i>B.limit(level)then overflow[#overflow+1]=obj;b.slots[slot]=nil end end
   if i>B.limit(level)then overflow[#overflow+1]=B.item(b);self.bagSlots[i]=nil end
  end end
  for _,obj in pairs(self.bank or{})do if self:isBagItem(obj.name)then local migrated=B.item(obj);for k in pairs(obj)do obj[k]=nil end;for k,v in pairs(migrated)do obj[k]=v end end end
  self:applyStrengthBagBonus(level);self.bagSchemaVersion=B.schema
  for _,obj in ipairs(overflow)do if not self:addItemObject(obj)then local slot=1;while self.bank[slot]do slot=slot+1 end;self.bank[slot]=obj;self.bankSize=math.max(self.bankSize or 25,slot)end end
  if not self.bagSlots[self.activeBag]then for i=1,self:bagSlotCount()do if self.bagSlots[i]then self.activeBag=i;break end end end
 end
 local addObject=I.addItemObject
 function I:addItemObject(obj)
  if self:isBagItem(obj.name)then obj=B.item(obj);local qty=obj.qty or 1;if qty==1 and not next(self.bagSlots)then local bag=B.item(obj);bag.slots={};bag.size=B.capacity(bag,self.strengthLevel or 1);bag.baseSize=self:bagBaseSize(bag.name);self.bagSlots[1]=bag;self.activeBag=1;return true end;if self:totalFreeSlots()<qty then return false end;for i=1,qty do local copy=B.item(obj);copy.qty=1;assert(addObject(self,copy))end;return true end
  return addObject(self,obj)
 end
 local add=I.add;function I:add(name,qty)if self:isBagItem(name)then return self:addItemObject({name=name,qty=qty or 1})end;return add(self,name,qty)end
 local new=I.new;I.new=function()local inv=new();inv.bagSlots[1]={name='Medium Leather Bag',qualityGrade='D',baseSize=5,size=5,slots=inv.bagSlots[1].slots};inv.strengthLevel=1;inv.bagSchemaVersion=B.schema;return inv end
 function I:equipBagFromItem(bi,slot,target)
  if type(target)~='number'or target%1~=0 or target<1 or target>self:bagSlotCount()then return false,'locked_slot'end
  local trial=require('game.rune_inventory').clone(self);local source=trial:getBag(bi);local obj=source and source.slots[slot];if not obj or not self:isBagItem(obj.name)then return false,'not_bag'end
  source.slots[slot]=nil;local old=trial.bagSlots[target];local contents=old and old.slots or{};local bag=B.item(obj);bag.slots={};bag.size=B.capacity(bag,self.strengthLevel);bag.baseSize=self:bagBaseSize(bag.name);trial.bagSlots[target]=bag
  for _,v in pairs(contents)do if not trial:addItemObject(v)then return false,'no_room'end end
  if old and not trial:addItemObject(B.item(old))then return false,'no_room'end
  self.bagSlots=trial.bagSlots;return true,'equipped'
 end
 function I:unequipBag(index)
  if index<1 or index>self:bagSlotCount()then return false,'locked_slot'end
  local b=self.bagSlots[index];if not b then return false,'empty'end
  local trial=require('game.rune_inventory').clone(self);trial.bagSlots[index]=nil
  for _,obj in pairs(b.slots)do if not trial:addItemObject(obj)then return false,'no_room'end end
  if not trial:addItemObject(B.item(b))then return false,'no_room'end
  self.bagSlots=trial.bagSlots;if not self.bagSlots[self.activeBag]then for i=1,self:bagSlotCount()do if self.bagSlots[i]then self.activeBag=i;break end end end;return true,b.name
 end
end
return B
