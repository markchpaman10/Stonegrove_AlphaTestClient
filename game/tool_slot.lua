-- One physical utility item, independent of the weapon. Inventory bindings are
-- transient weak keys; persistence continues through equipment/equipmentItems.
local T={inventories=setmetatable({},{__mode='k'})}
function T.name(value)return type(value)=='table'and value.name or value end
function T.kind(name)
 name=T.name(name);if type(name)~='string'then return end
 if name:match(' Knife$')or name:match(' Dagger$')then return 'knife'end
 if name:match(' Pickaxe$')or name:match(' Pick$')then return 'pick'end
 if name:match(' Axe$')then return 'axe'end
end
function T.action(name)return T.kind(name)=='knife'and'Copper Knife'or T.name(name)end
function T.bind(a)
 if a.inv then T.inventories[a.inv]=a.equipment or{}end
 if a.player then a.player.equipment=a.equipment or{}end
end
function T.has(inv,equipped,required,player)
 if not required then return true end
 local eq=T.inventories[inv]or(type(equipped)=='table'and equipped)or(player and(player.equipment or player.gear))or{}
 local kind=T.kind(required);local weapon=T.name(type(equipped)=='table'and equipped.weapon or equipped)or T.name(eq.weapon)
 if kind then
  if T.kind(eq.tool)==kind or T.kind(weapon)==kind then return true end
  for _,bag in pairs(inv.bagSlots or{})do for _,it in pairs(bag.slots or{})do if T.kind(it.name)==kind then return true end end end
  return false
 end
 return inv:hasItem(required)or weapon==required
end
function T.object(a)return require('game.items').equipped(a,'tool')end
function T.equip(a,bag,slot)
 if a.craftJob or a.campPending or a.magicCast or a.world and a.world.workJob then return false,'Finish your current action first'end
 local b=a.inv:getBag(bag);local it=b and b.slots[slot]
 if not it or not T.kind(it.name)or(it.qty or 1)~=1 then return false,'Select one knife, pickaxe or axe'end
 local ok,skill,level=require('game.progression').canEquip(a.skills,it.name,a.sprites and a.sprites.itemInfo[it.name])
 if not ok then return false,skill..' level '..level..' required'end
 local old=T.object(a);require('game.items').setEquipped(a,'tool',it);b.slots[slot]=old;T.bind(a);a.useTarget=nil
 return true,it,old
end
function T.unequip(a)
 if a.craftJob or a.campPending or a.magicCast or a.world and a.world.workJob then return false,'Finish your current action first'end
 local it=T.object(a);if not it then return false,'Tool slot is empty'end
 if not a.inv:addItemObject(require('game.items').copy(it))then return false,'Bags full'end
 require('game.items').setEquipped(a,'tool',nil);T.bind(a);a.useTarget=nil;return true,it
end
return T
