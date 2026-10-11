-- Resize panels uniformly so pixel-art slots, hit targets and text stay aligned.
local R={}
local function hit(mx,my,x,y,w,h) return mx>=x and my>=y and mx<x+w and my<y+h end
function R.install(UI)
 local rect=UI.rect
 function UI:rect(name)
  local x,y,w,h=rect(self,name)
  if self.inputPanel and self.inputPanel~=name then return -100000,-100000,w,h end
  return x,y,w,h
 end
 local bagRect=UI.bagWindowRect
 function UI:bagWindowRect(bi)
  local x,y,w,h=bagRect(self,bi)
  if self.inputPanel and self.inputPanel~="inventory" and self.inputPanel~="bag"..bi then return -100000,-100000,w,h end
  return x,y,w,h
 end
 local combined=UI.combinedRect
 function UI:combinedRect()
  local x,y,w,h=combined(self)
  if self.inputPanel and self.inputPanel~="inventory" then return -100000,-100000,w,h end
  return x,y,w,h
 end
 function UI:panelRect(key)
  if key:sub(1,3)=="bag" then return self:bagWindowRect(tonumber(key:sub(4))) end
  if key=="inventory" and self.bagnonMode then return self:combinedRect() end
  return self:rect(key)
 end
 function UI:panelKeys()
  local keys={};for _,k in ipairs(self.zOrder) do if k~="inventory" and self.open[k] then keys[#keys+1]=k end end
  if self.bagnonMode then if self.bagOpen[1] or self.bagOpen[2] or self.bagOpen[3] or self.bagOpen[4] then keys[#keys+1]="inventory" end
  else for i=1,self.inv:bagSlotCount() do if self.bagOpen[i] and self.inv:getBag(i) then keys[#keys+1]="bag"..i end end end
  return keys
 end
 function UI:panelAt(mx,my)
  local keys=self:panelKeys();for i=#keys,1,-1 do local k=keys[i];local x,y,w,h=self:panelRect(k);local sc=(self.panelScales or {})[k] or 1;if hit(mx,my,x,y,w*sc,h*sc) then return k,x,y,w,h,sc end end
 end
 local function wrap(method,keyFor)
  local original=UI[method]
  UI[method]=function(self,...)
   local key=keyFor(...);local x,y,w,h=self:panelRect(key);local sc=(self.panelScales or {})[key] or 1
   local get=love.mouse.getPosition;local mx,my=get();local top=self:panelAt(mx,my);love.mouse.getPosition=function() if top~=key then return -100000,-100000 end;return x+(mx-x)/sc,y+(my-y)/sc end
   love.graphics.push("all");love.graphics.translate(x,y);love.graphics.scale(sc);love.graphics.translate(-x,-y)
   original(self,...)
   love.graphics.setColor(.85,.74,.45);love.graphics.line(x+w-14,y+h-4,x+w-4,y+h-14);love.graphics.line(x+w-9,y+h-4,x+w-4,y+h-9)
   love.graphics.pop();love.mouse.getPosition=get
  end
 end
 for _,pair in ipairs({{"drawRuneBag","runeBag"},{"drawEquipment","equipment"},{"drawSkills","skills"},{"drawBank","bank"},{"drawShop","shop"},{"drawSpellbook","spellbook"},{"drawSocketTable","socketTable"},{"drawEnchantAltar","enchantAltar"},{"drawMercenary","mercenary"},{"drawMercBand","mercBand"},{"drawBankClerk","bankClerk"},{"drawCombinedInventory","inventory"}}) do local key=pair[2];wrap(pair[1],function() return key end) end
 wrap("drawCrafting",function(station) return station end)
 wrap("drawInventory",function(w,h,bi) return "bag"..bi end)
 local press=UI.mousepressed
 function UI:mousepressed(mx,my,button,w,h)
  if self.context or self.shopContext or self.equipmentContext or self.mercContext or self.bagContext then return press(self,mx,my,button,w,h) end
  local k,x,y,pw,ph,sc=self:panelAt(mx,my)
  if k then
   if button==1 and hit(mx,my,x+pw*sc-18,y+ph*sc-18,18,18) then self.panelResize={key=k,x=x,y=y,w=pw,h=ph};return true end
   if button==1 and my<y+26*sc and mx<x+(pw-28)*sc then self.panelMove={key=k,ox=mx-x,oy=my-y};return true end
   self.inputPanel=k;local result=press(self,x+(mx-x)/sc,y+(my-y)/sc,button,w,h);self.inputPanel=nil
   for _,field in ipairs({"context","shopContext","equipmentContext","mercContext","bagContext"}) do if self[field] then self[field].x,self[field].y=mx,my end end
   return true
  end
  return press(self,mx,my,button,w,h)
 end
 local move=UI.mousemoved
 function UI:mousemoved(mx,my,dx,dy,w,h)
  local d=self.panelResize
  if d then self.panelScales=self.panelScales or {};self.panelScales[d.key]=math.max(.55,math.min(2.5,(mx-d.x)/d.w,(my-d.y)/d.h,(w-d.x)/d.w,(h-d.y)/d.h));return true end
  d=self.panelMove
  if d then local _,_,pw,ph=self:panelRect(d.key);local sc=(self.panelScales or {})[d.key] or 1;local p=d.key:sub(1,3)=="bag" and self.bagPos[tonumber(d.key:sub(4))] or self.pos[d.key];p.x=math.max(0,math.min(w-pw*sc,mx-d.ox));p.y=math.max(0,math.min(h-ph*sc,my-d.oy));return true end
  return move(self,mx,my,dx,dy,w,h)
 end
 local release=UI.mousereleased
 function UI:mousereleased(mx,my,button,w,h)
  if self.panelResize or self.panelMove then self.panelResize=nil;self.panelMove=nil;return true end
  local k,x,y,pw,ph,sc=self:panelAt(mx,my);if k then mx,my=x+(mx-x)/sc,y+(my-y)/sc end
  return release(self,mx,my,button,w,h)
 end
 local wheel=UI.wheelmoved
 function UI:wheelmoved(dx,dy,mx,my)
  local k,x,y,pw,ph,sc=self:panelAt(mx,my);if k then mx,my=x+(mx-x)/sc,y+(my-y)/sc end
  self.inputPanel=k;local result=wheel(self,dx,dy,mx,my);self.inputPanel=nil;return result
 end
end
return R
