-- Installed outside the resize adapter: pointer positions here are screen pixels.
local BankDrag={}
function BankDrag.install(UI)
 local function slotAt(self,mx,my)
  if not self.open.bank then return end
  local key,x,y,w,h,scale=self:panelAt(mx,my)
  if key~="bank" then return end
  return self:bankSlotAt(x+(mx-x)/scale,y+(my-y)/scale)
 end
 local function moved(d,mx,my)
  d.moved=d.moved or (mx-d.x)^2+(my-d.y)^2>=25
 end
 local press=UI.mousepressed
 function UI:mousepressed(mx,my,button,w,h)
  if self.bankDrag then return true end
  if button==1 and not (self.context or self.bankContext or self.shopContext or self.equipmentContext or self.mercContext or self.bagContext or self.dragSlot) then
   local slot=slotAt(self,mx,my);local item=slot and self.inv.bank[slot]
   if item then self.bankDrag={slot=slot,item=item,x=mx,y=my,moved=false};self:bringToFront("bank");return true end
  end
  return press(self,mx,my,button,w,h)
 end
 local move=UI.mousemoved
 function UI:mousemoved(mx,my,dx,dy,w,h)
  if self.bankDrag then moved(self.bankDrag,mx,my);return true end
  return move(self,mx,my,dx,dy,w,h)
 end
 local release=UI.mousereleased
 function UI:mousereleased(mx,my,button,w,h)
  local d=self.bankDrag
  if d and button==1 then
   self.bankDrag=nil;moved(d,mx,my)
   local target=slotAt(self,mx,my)
   -- Cancel if the panel closed, another window covers the target, or the source changed.
   if not target or self.inv.bank[d.slot]~=d.item then return true end
   if d.moved then
    if target~=d.slot then
     self.inv.bank[d.slot],self.inv.bank[target]=self.inv.bank[target],d.item
     self:log("BANK_SLOTS_SWAPPED",{from=d.slot,to=target,item=d.item.name})
    end
   elseif target==d.slot then
    local ok,name,qty=self.inv:withdrawBankSlot(d.slot)
    self:log("BANK_WITHDRAW",{slot=d.slot,item=name or "none",qty=qty or 0,success=tostring(ok)})
   end
   return true
  end
  return release(self,mx,my,button,w,h)
 end
 local draw=UI.draw
 function UI:draw(w,h)
  if not self.open.bank then self.bankDrag=nil end
  draw(self,w,h)
  local d=self.bankDrag
  if d and d.moved then
   local mx,my=love.mouse.getPosition();local target=slotAt(self,mx,my)
   if target then local x,y=self:rect("bank");local sc=(self.panelScales or {}).bank or 1;local first=((self.bankPage or 1)-1)*50+1;local li=target-first
    love.graphics.setColor(1,.85,.35);love.graphics.rectangle("line",x+(20+(li%5)*47)*sc,y+(72+math.floor(li/5)*43)*sc,38*sc,38*sc,4,4)
   end
   self:drawItemSprite(d.item,mx+10,my+10,38,true)
  end
 end
 local help=UI.drawHelp
 function UI:drawHelp(...) if not self.bankDrag then return help(self,...) end end
end
return BankDrag
