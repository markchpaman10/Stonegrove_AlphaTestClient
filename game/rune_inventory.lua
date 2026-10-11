local R={}
function R.copy(v) if type(v)~='table' then return v end;local out={};for k,x in pairs(v) do out[k]=R.copy(x) end;return out end
function R.clone(inv) return setmetatable(R.copy(inv),getmetatable(inv)) end
function R.install(I)
 local deposit=I.depositSlot
 function I:depositSlot(bi,slot)
  local b=self:getBag(bi);local it=b and b.slots[slot]
  if not it or it.name~='Rune Bag' then return deposit(self,bi,slot) end
  for i=1,self.bankSize do if not self.bank[i] then self.bank[i]=it;b.slots[slot]=nil;return true,it.name,1 end end
  return false,'bank_full'
 end
 local all=I.depositAll
 function I:depositAll(name)
  if name~='Rune Bag' then return all(self,name) end
  local count=self:countItem(name);local free=self.bankSize-self:bankUsed();if count>free then return false,'bank_full' end
  for bi=1,4 do local b=self:getBag(bi);if b then for i=1,b.size do if b.slots[i] and b.slots[i].name==name then self:depositSlot(bi,i) end end end end
  return true,name,count
 end
 function I:depositEverything()
  local moved=0;for bi=1,4 do local b=self:getBag(bi);if b then for i=1,b.size do if b.slots[i] then local ok,_,q=self:depositSlot(bi,i);if ok then moved=moved+(q or 1) end end end end end;return moved>0,moved
 end
 -- Rune Bag withdrawal is handled by Inventory:withdrawBankSlotAmount so its contents/state survive bank storage.
end
return R
