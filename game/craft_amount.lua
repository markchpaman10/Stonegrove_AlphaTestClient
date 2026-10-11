local M={}
local function hit(x,y,r)return x>=r.x and x<r.x+r.w and y>=r.y and y<r.y+r.h end
function M.install(U)
 function U:craftBatchDone(station,index)
  local c=self.craftLimit;if c and c.station==station and c.index==index then c.remaining=c.remaining-1 end
 end
 local start=U.startCraft
 function U:startCraft(station,index)
  local c=self.craftLimit;if c and(c.station~=station or c.index~=index)then self.craftLimit=nil;c=nil end
  if c and c.remaining<=0 then self.craftLimit=nil;return false,'batch_complete'end
  local ok,why=start(self,station,index);if not ok then self.craftLimit=nil end;return ok,why
 end
 function U:craftAmountKey(key)
  if not self.craftAmountPrompt then return false end
  if key=='escape'then self.craftAmountPrompt=nil
  elseif key=='backspace'then self.craftAmountPrompt.text=self.craftAmountPrompt.text:sub(1,-2)
  elseif key=='return'or key=='kpenter'then
   local p=self.craftAmountPrompt;local amount=tonumber(p.text)
   if amount and amount>=1 and amount<=9999 and amount%1==0 then self.craftLimit={station=p.station,index=p.index,remaining=amount};self.craftAmountPrompt=nil;self:startCraft(p.station,p.index)else p.error='Enter a number from 1 to 9999.'end
  end
  return true
 end
 function U:craftAmountText(text)
  local p=self.craftAmountPrompt;if not p then return false end
  if text:match('^%d+$')and #p.text+#text<=4 then p.text=p.text..text;p.error=nil end;return true
 end
 local pointer=U.pointerOverUI;U.pointerOverUI=function(u,...)if u.craftAmountPrompt or u.craftRecipeContext then return true end;return pointer(u,...)end
 local press=U.mousepressed
 function U:mousepressed(x,y,button,w,h)
  if self.craftAmountPrompt then if button==1 then local p=self.craftAmountPrompt;local px,py=w/2-160,h/2-80;if hit(x,y,{x=px+18,y=py+110,w=130,h=28})then self:craftAmountKey('return')elseif hit(x,y,{x=px+170,y=py+110,w=130,h=28})then self.craftAmountPrompt=nil end end;return true end
  local c=self.craftRecipeContext
  if c then self.craftRecipeContext=nil;if button==1 and hit(x,y,c)then
   local row=math.floor((y-c.y)/26)
   if row==0 then self.craftLimit={station=c.station,index=c.index,remaining=1};self:startCraft(c.station,c.index)
   elseif row==1 then self.craftLimit=nil;self:startCraft(c.station,c.index)
   elseif row==2 then self.craftAmountPrompt={station=c.station,index=c.index,text=''}end
  end;return true end
  local key,px,py,pw,ph,sc=self:panelAt(x,y)
  if key and self.craftScroll[key]~=nil then local index=self:craftRecipeAt(key,px+(x-px)/sc,py+(y-py)/sc)
   if index and(self.craftJob or self.campPending or self.magicCast or self.world.workJob)then self.world:addPopup(self.player.x,self.player.y-24,'Finish your current action first');return true end
   if index and button==2 then self.craftRecipeContext={station=key,index=index,x=math.min(x,w-164),y=math.min(y,h-108),w=160,h=104};return true end
   if index and button==1 then self.craftLimit=nil end
  end
  return press(self,x,y,button,w,h)
 end
 local draw=U.draw
 function U:draw(w,h)
  draw(self,w,h);local g=love.graphics;local c=self.craftRecipeContext
  if c then g.setColor(.04,.035,.025,.99);g.rectangle('fill',c.x,c.y,c.w,c.h,4);g.setColor(1,.9,.65);g.rectangle('line',c.x,c.y,c.w,c.h,4);for i,v in ipairs({'Make 1','Make All','Make X...','Cancel'})do g.print(v,c.x+12,c.y+5+(i-1)*26)end end
  local p=self.craftAmountPrompt;if p then local x,y=w/2-160,h/2-80;g.setColor(.03,.035,.04,.99);g.rectangle('fill',x,y,320,150,5);g.setColor(1,.9,.65);g.rectangle('line',x,y,320,150,5);g.printf('Make X — number of crafts',x+14,y+14,292,'center');g.rectangle('line',x+18,y+46,282,30);g.print(p.text..'|',x+26,y+52);g.printf(p.error or 'Enter to craft; Escape to cancel',x+12,y+84,296,'center');g.rectangle('line',x+18,y+110,130,28);g.rectangle('line',x+170,y+110,130,28);g.print('Craft',x+61,y+116);g.print('Cancel',x+212,y+116)end;g.setColor(1,1,1)
 end
end
return M
