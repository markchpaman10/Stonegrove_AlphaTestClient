local R={}
local names={};for _,n in ipairs(require('game.rune_quality').names)do names[n]=true end
function R.install(I)
 local deposit=I.depositSlot
 function I:depositSlot(bi,slot)
  local b=self:getBag(bi);local obj=b and b.slots[slot];if not obj or not(names[obj.name]or require('game.bone_religion').is(obj.name))then return deposit(self,bi,slot)end
  local items=require('game.items')
  for i=1,self.bankSize do local v=self.bank[i];if v and items.sameMetadata(v,obj)then items.mergeProvenance(v,obj,obj.qty or 1);v.qty=(v.qty or 1)+(obj.qty or 1);b.slots[slot]=nil;return true,obj.name,obj.qty or 1 end end
  for i=1,self.bankSize do if not self.bank[i]then self.bank[i]=items.copy(obj);b.slots[slot]=nil;return true,obj.name,obj.qty or 1 end end
  return false,'bank_full',0
 end
 local all=I.depositAll
 function I:depositAll(name)
  if not(names[name]or require('game.bone_religion').is(name))then return all(self,name)end
  local trial=require('game.rune_inventory').clone(self);local moved=0
  for bi=1,trial:bagSlotCount()do local b=trial:getBag(bi);if b then for i=1,b.size do if b.slots[i]and b.slots[i].name==name then local ok,why,qty=trial:depositSlot(bi,i);if not ok then return false,why,0 end;moved=moved+qty end end end end
  if moved==0 then return false,'none',0 end;self.bagSlots=trial.bagSlots;self.bank=trial.bank;return true,name,moved
 end
end
return R
