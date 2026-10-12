local M={};local T=require('game.tool_slot')
local function inside(x,y,r)return x>=r[1]and x<r[1]+r[3]and y>=r[2]and y<r[2]+r[4]end
function M.buttonRect(u,key)
 if key=='inventory'and u.bagnonMode then local x,y,w=u:combinedRect();return{x+14,y+34,w-28,44}end
 local bi=tonumber(tostring(key):match('^bag(%d)$'));if bi then local x,y=u:bagWindowRect(bi);return{x+106,y+40,162,48}end
end
function M.drawButton(u,key)
 local r=M.buttonRect(u,key);if not r then return end
 local g=love.graphics;local it=T.object(u);local active=u.useTarget and u.useTarget.equipmentSlot=='tool'
 g.setColor(active and .28 or .10,active and .23 or .09,.07,.96);g.rectangle('fill',r[1],r[2],r[3],r[4],4,4)
 g.setColor(.72,.62,.40);g.rectangle('line',r[1],r[2],r[3],r[4],4,4);g.setColor(1,1,1)
 if it then u:drawItemSprite(it,r[1]+4,r[2]+5,34)end
 g.print('TOOL',r[1]+44,r[2]+6);g.printf(it and it.name or'Empty',r[1]+44,r[2]+23,r[3]-48,'left')
 local x,y=love.mouse.getPosition();if inside(x,y,r)then u.hoverTooltip={item=it or{name='Tool slot',qty=1},info=not it and{title='Tool slot',type='One utility tool',detail='Right-click a knife, pickaxe or axe in your bag and choose Equip Tool.'}or nil}end
end
function M.install(U)
 local new=U.new;U.new=function(...)local u=new(...);T.bind(u);return u end
 function U:findUseSource(tool)
  local it=T.object(self);if it and T.action(it.name)==tool then return nil,nil,it,true end
  return self:findInventoryItem(tool)
 end
 function U:selectEquippedTool()
  local it=T.object(self);if not it then self.world:addPopup(self.player.x,self.player.y-22,'TOOL SLOT EMPTY','miss');return false end
  self.useTarget={tool=T.action(it.name),equipmentSlot='tool',equippedName=it.name};self.context=nil;return true
 end
 local compatible=U.isUseCompatible
 function U:isUseCompatible(tool,it)
  if it and tool=='Copper Knife'and(it.name=='Crab'or it.name=='Lobster')then return true end
  return compatible(self,tool,it)
 end
 local use=U.startItemUse
 function U:startItemUse(bag,slot)
  local selected=self.useTarget;if selected and selected.equipmentSlot=='tool'then
   local tool=T.object(self);if not tool or tool.name~=selected.equippedName then self.useTarget=nil;return false,'Tool changed'end
   local b=self.inv:getBag(bag);local it=b and b.slots[slot]
   if it and(it.name=='Crab'or it.name=='Lobster')and T.kind(tool.name)=='knife'then self.useTarget=nil;return require('game.fieldcraft_ui').timedOffline(self,{op='shellFillet',bag=bag,slot=slot})end
  end
  return use(self,bag,slot)
 end
 local options=U.contextOptions
 function U:contextOptions(it)
  local out=options(self,it)
  if T.kind(it.name)then
   table.insert(out,1,'Equip Tool')
  end
  local tool=T.object(self);if tool and self:isUseCompatible(T.action(tool.name),it)then table.insert(out,1,'Use Equipped Tool')end
  return out
 end
 local context=U.doContextOption
 function U:doContextOption(option)
  if option=='Equip Tool'or option=='Use Equipped Tool'then
   local c=self.context;if not c then return end;self.context=nil
   if option=='Equip Tool'then local ok,it=T.equip(self,c.bag,c.slot);if not ok then self.world:addPopup(self.player.x,self.player.y-22,tostring(it),'miss')else self:log('TOOL_EQUIPPED',{item=it.name})end;return end
   if self:selectEquippedTool()then return self:startItemUse(c.bag,c.slot)end;return
  end
  return context(self,option)
 end
 local press=U.mousepressed
 function U:mousepressed(x,y,button,w,h)
  if self.toolContext then
   local c=self.toolContext;self.toolContext=nil
   if button==1 and inside(x,y,{c.x,c.y,190,78})then
    local row=math.floor((y-c.y)/26)
    if row==0 then self:selectEquippedTool()
    elseif row==1 then local ok,why=T.unequip(self);if not ok then self.world:addPopup(self.player.x,self.player.y-22,tostring(why),'miss')end end
   end;return true
  end
  if not(self.context or self.bankContext or self.shopContext or self.equipmentContext or self.craftRecipeContext or self.craftAmountPrompt or self.campPending)then
   local key,px,py,pw,ph,sc=self:panelAt(x,y);local r=key and M.buttonRect(self,key)
   if r and inside(px+(x-px)/sc,py+(y-py)/sc,r)then
    if button==1 then self:selectEquippedTool()elseif button==2 then self.toolContext={x=math.min(x,w-194),y=math.min(y,h-82)}end;return true
   end
  end
  return press(self,x,y,button,w,h)
 end
 local pointer=U.pointerOverUI;U.pointerOverUI=function(u,...)if u.toolContext then return true end;return pointer(u,...)end
 local release=U.mousereleased
 function U:mousereleased(x,y,button,w,h)
  if button==1 and self.dragSlot and not self.panelMove and not self.panelResize then
   local key,px,py,pw,ph,sc=self:panelAt(x,y)
   if key then
    local lx,ly=px+(x-px)/sc,py+(y-py)/sc;local r=M.buttonRect(self,key)
    if r and inside(lx,ly,r)or key=='equipment'and self:equipmentSlotAt(lx,ly)=='tool'then
     local ok,why=T.equip(self,self.dragBagIndex,self.dragSlot);self.dragSlot=nil;self.dragBagIndex=nil
     if not ok then self.world:addPopup(self.player.x,self.player.y-22,tostring(why),'miss')end;return true
    end
   end
  end
  return release(self,x,y,button,w,h)
 end
 local draw=U.draw
 function U:draw(w,h)
  draw(self,w,h);local c=self.toolContext;if c then local g=love.graphics;g.setColor(.04,.035,.025,.99);g.rectangle('fill',c.x,c.y,190,78,4,4);g.setColor(1,.9,.65);g.rectangle('line',c.x,c.y,190,78,4,4);for i,name in ipairs({'Use Tool','Unequip Tool','Cancel'})do g.print(name,c.x+10,c.y+5+(i-1)*26)end end
 end
end
return M
