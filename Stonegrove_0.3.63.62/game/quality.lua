local Q={factors={D=.8,C=1,B=1.2,A=1.4},equipment=setmetatable({},{__mode='k'}),consumables={['Health Tube']=20,['Health Flask']=40,['Potent Health Flask']=80,['Antipoison Tube']=0,['Antipoison Flask']=0,['Potent Antidote']=0,['Stamina Potion (3/3)']=30,['Stamina Potion (2/3)']=30,['Stamina Potion (1/3)']=30}}
function Q.grade(obj)return obj and(obj.qualityGrade or(obj.name or''):match(' ([DCBA])$'))end
function Q.factor(obj)return Q.factors[Q.grade(obj)]or 1 end
function Q.roll(level)local n=math.random(1,100)+math.min(35,math.max(1,level or 1));return n>=115 and'A'or n>=85 and'B'or n>=55 and'C'or'D'end
function Q.bind(eq,objects)if eq then Q.equipment[eq]=objects or{}end end
function Q.object(eq,slot)return eq and((Q.equipment[eq]or{})[slot]or(type(eq[slot])=='table'and eq[slot]))end
function Q.info(info,obj)
 info=require('game.content_rules').equipment(info and(info.qualityBase or info.title)or obj and obj.name,info)
 if not obj or not obj.qualityGrade then return info end
 local out={};for k,v in pairs(info or{})do out[k]=v end
 if out.damage and out.damage>0 then out.damage=math.max(1,math.floor(out.damage*Q.factor(obj)+.5))end
 if out.defence and out.defence>0 then out.defence=math.max(1,math.floor(out.defence*Q.factor(obj)+.5))end
 if out.heal and out.heal>0 then out.heal=math.max(1,math.floor(out.heal*Q.factor(obj)+.5))end
 return out
end
function Q.defenceBonus(eq)
 local total=0;for _,slot in ipairs({'head','body','legs','cape','offhand'})do local obj=Q.object(eq,slot);if obj and Q.grade(obj)then
  local name=obj.name;local d=require('game.iron_gear').items[name]or require('game.advanced_gear').items[name]or require('game.custom_content').item(name)or(Q.baseInfo or{})[name];local base=d and tonumber(d.defence)or({['Copper Helm']=2,['Copper Armor']=5,['Copper Shield']=4})[name]or 0
  total=total+math.max(base>0 and 1 or 0,math.floor(base*Q.factor(obj)+.5))-base
 end end;return total
end
function Q.bagSize(b,base)if require('game.bag_system').defs[require('game.bag_system').name(b.name)]then return require('game.bag_system').capacity(b,1)end;if(b.name or''):match(' [DCBA]$')then return base end;return math.max(1,math.floor(base*Q.factor(b)+.5))end
function Q.add(inv,name,qty,level,add)
 if name:match('^Burnt ')or name:match(' [DCBA]$')then return add(inv,name,qty)end
 local grade=require('game.bag_system').defs[name]and require('game.bag_system').roll(level)or Q.roll(level)
 if Q.consumables[name]then return add(inv,name..' '..grade,qty)end
 local obj={name=name,qty=qty or 1,qualityGrade=grade}
 if inv:isStackable(name)then return inv:addItemObject(obj)end
 local trial=require('game.rune_inventory').clone(inv);for i=1,(qty or 1)do if not trial:addItemObject({name=name,qty=1,qualityGrade=grade})then return false end end;inv.bagSlots=trial.bagSlots;return true
end
function Q.wrap(C)
 local craft=C.craft;function C:craft(station,index,inv,skills,...)
  local r=self:getRecipes(station)[index];if not r then return craft(self,station,index,inv,skills,...)end
  local I=require('game.inventory');local add=I.add;local trial=require('game.rune_inventory').clone(inv);local level=skills:get(r.skill or'Jewel Crafting').level
  I.add=function(target,name,qty)return Q.add(target,name,qty,level,add)end
  local result={pcall(craft,self,station,index,trial,skills,...)};I.add=add;if not result[1]then error(result[2])end
  if result[2]then inv.bagSlots=trial.bagSlots end;return unpack(result,2)
 end
end
function Q.load(s)Q.baseInfo=s.itemInfo;
 for _,g in ipairs({'D','C','B','A'})do
  local chicken='Cooked Chicken '..g;s.itemImages[chicken]=s.itemImages['Cooked Chicken'];s.itemQuads[chicken]=s.itemQuads['Cooked Chicken'];s.itemInfo[chicken]={title=chicken,type='Food',heal=require('game.food').healing[chicken],detail='Quality '..g..'. Restores '..require('game.food').healing[chicken]..' health.'}
  for name,heal in pairs(Q.consumables)do if s.itemInfo[name]then local alias=name..' '..g;local d={};for k,v in pairs(s.itemInfo[name])do d[k]=v end;d.title=alias;d.qualityGrade=g;d.qualityBase=name;if heal>0 then d.heal=math.floor(heal*Q.factors[g]+.5)end;d.detail='Quality '..g..'. '..(heal>0 and('Restores '..d.heal..(name:find('Stamina',1,true)and' stamina.'or' health.'))or('Poison immunity '..math.floor((name=='Potent Antidote'and 15 or 3)*Q.factors[g]+.5)..' seconds.'));s.itemInfo[alias]=d;s.itemImages[alias]=s.itemImages[name];s.itemQuads[alias]=s.itemQuads[name]end end
 end
end
function Q.installUI(U)
 local new=U.new;U.new=function(...)local u=new(...);Q.bind(u.equipment,u.equipmentItems);u.skills.bagInventory=u.inv;u.inv:applyStrengthBagBonus(u.skills:get("Strength").level);require("game.options_menu").ui=u;return u end
 local tooltip=U.drawTooltip;function U:drawTooltip(it,x,y,w,h,override)if it.name=='Rune Bag'then local d={};for k,v in pairs(override or self.sprites.itemInfo[it.name]or{})do d[k]=v end;local R=require('game.rune_quality');d.detail=(d.detail or'')..'\nCapacity per material: '..R.capacity(it)..'. Spell strength: '..math.floor(R.spellFactor(it)*100+.5)..'% (also scales with rune grade).';override=d end;if it.tailPending then local d={};for k,v in pairs(override or self.sprites.itemInfo[it.name]or{})do d[k]=v end;d.detail=(d.detail or'')..'\nBonus Raw Lobster Tail inside. Make inventory space, then Harvest.';override=d end;if (self.sprites.itemInfo[it.name]or{}).type=='Rune Material'then local d={};for k,v in pairs(override or self.sprites.itemInfo[it.name]or{})do d[k]=v end;d.detail=(d.detail or'')..'\nSpell strength: '..tostring(math.floor(Q.factor(it)*100+.5))..'% when blessed. Rune Bag first, highest grade first.\nBlessing requires Religion '..require('game.religion').requiredLevel(it.name)..'.';override=d end;local info=require("game.bag_system").tooltip(it,self.skills:get("Strength").level)or Q.info(override or self.sprites.itemInfo[it.name],it);if self.inv:isBagItem(it.name)and override then local copy={};for k,v in pairs(info)do copy[k]=v end;copy.detail=copy.detail..'\n'..(override.detail or'');copy.type=override.type or copy.type;info=copy end;local grade=Q.grade(it);if grade and not self.inv:isBagItem(it.name)then local copy={};for k,v in pairs(info or{})do copy[k]=v end;copy.title=(copy.title or it.name)..(it.qualityGrade and(' ['..grade..']')or'');copy.detail=(copy.detail or'')..'\nQuality: '..grade..(self.inv:isBagItem(it.name)and(' â€” '..Q.bagSize(it,self.inv:bagBaseSize(it.name))..' base slots before Strength.')or'');if it.qualityGrade and info and info.damage then copy.detail=copy.detail..'\nDamage: '..info.damage end;if it.qualityGrade and info and info.defence then copy.detail=copy.detail..'\nDefence: '..info.defence end;info=copy end;return tooltip(self,it,x,y,w,h,info)end
 local icon=U.drawItemSprite;function U:drawItemSprite(it,x,y,size,...)icon(self,it,x,y,size,...);local grade=Q.grade(it);if grade then local g=love.graphics;g.setColor(.02,.025,.03,.9);g.rectangle('fill',x+size-13,y+size-14,12,13);g.setColor(grade=='A'and.45 or 1,grade=='D'and.65 or 1,.6,1);g.print(grade,x+size-12,y+size-15);g.setColor(1,1,1)end end
 local use=U.usePotion;function U:usePotion(slot)
  local name=self.potionBelt[slot];local meta=name and self.sprites.itemInfo[name];local base=meta and meta.qualityBase;if not base then return use(self,slot)end
  local factor=Q.factors[meta.qualityGrade];local p=self.player;local nextItem
  if base=='Health Tube'or base=='Health Flask'or base=='Potent Health Flask'then if p.hp>=p.maxHp then return false,'no_effect_needed'end;p.hp=math.min(p.maxHp,p.hp+meta.heal)
  elseif base:find('Stamina Potion',1,true)then p.stamina=math.min(p.maxStamina,p.stamina+meta.heal);p.secondWind=math.max(p.secondWind or 0,math.floor(10*factor+.5));local dose=tonumber(base:match('%((%d)/3%)'));if dose and dose>1 then nextItem='Stamina Potion ('..(dose-1)..'/3) '..meta.qualityGrade end
  elseif base=='Antipoison Tube'or base=='Antipoison Flask'then p.poisonedTimer=0;p.poisonTick=0;p.poisonImmuneTimer=math.floor(3*factor+.5)
  else return use(self,slot)end
  self.potionBelt[slot]=nextItem;return true,name
 end
 local context=U.doContextOption;function U:doContextOption(opt)
  local c=self.context;local obj=c and self.inv:getBag(c.bag).slots[c.slot];local meta=obj and self.sprites.itemInfo[obj.name]
  if opt=='Eat'and meta and meta.qualityBase=='Potent Health Flask'then local p=self.player;if p.hp>=p.maxHp then return false end;p.hp=math.min(p.maxHp,p.hp+meta.heal);self.inv:removeItems(obj.name,1);self.context=nil;return true end
  if opt=='Eat'and meta and meta.qualityBase=='Potent Antidote'then local p=self.player;p.poisonedTimer=0;p.poisonTick=0;p.slimeCoated=0;p.slimeBreathTick=0;p.poisonImmuneTimer=math.floor(15*Q.factor(obj)+.5);self.inv:removeItems(obj.name,1);self.context=nil;return true end
  return context(self,opt)
 end
end
return Q
