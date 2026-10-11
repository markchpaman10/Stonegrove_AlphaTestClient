local T={}
local utf8=require('utf8')
local function state(L)
 L.fieldEdit=L.fieldEdit or{};local s=L.fieldEdit[L.focus];local value=L.fields[L.focus]
 if not s or s.last~=value then s={cursor=#value,anchor=#value,last=value};L.fieldEdit[L.focus]=s end;return s,value
end
local function bounds(s)return math.min(s.cursor,s.anchor),math.max(s.cursor,s.anchor)end
local function trim(value,limit)local count=utf8.len(value);if not count then return nil end;if count>limit then return value:sub(1,utf8.offset(value,limit+1)-1)end;return value end
function T.insert(L,text)
 local s,value=state(L);text=text:gsub('[%z\1-\31\127]','');if not utf8.len(text)then return end
 local a,b=bounds(s);local limit=L.focus==3 and 128 or 500;local remaining=limit-(utf8.len(value:sub(1,a))+utf8.len(value:sub(b+1)));text=trim(text,math.max(0,remaining));if not text then return end
 value=value:sub(1,a)..text..value:sub(b+1);s.cursor=a+#text;s.anchor=s.cursor;s.last=value;L.fields[L.focus]=value
end
local function move(s,value,target,shift)s.cursor=math.max(0,math.min(#value,target));if not shift then s.anchor=s.cursor end end
function T.key(L,key)
 local s,value=state(L);local ctrl=love.keyboard.isDown('lctrl','rctrl');local shift=love.keyboard.isDown('lshift','rshift');local a,b=bounds(s)
 if ctrl and key=='a'then s.anchor=0;s.cursor=#value;return true end
 if (ctrl and(key=='c'or key=='x'))or(ctrl and key=='insert')or(shift and key=='delete')then
  if b>a then love.system.setClipboardText(value:sub(a+1,b));if key=='x'or key=='delete'then T.insert(L,'')end end;return true
 end
 if(ctrl and key=='v')or(shift and key=='insert')then T.insert(L,love.system.getClipboardText()or'');return true end
 if key=='home'then move(s,value,0,shift);return true elseif key=='end'then move(s,value,#value,shift);return true end
 if key=='left'or key=='right'then
  local target
  if not shift and a~=b then target=key=='left'and a or b
  elseif key=='left'then target=s.cursor>0 and(utf8.offset(value,-1,s.cursor+1)-1)or 0
  else target=s.cursor<#value and((utf8.offset(value,2,s.cursor+1)or(#value+1))-1)or #value end
  move(s,value,target,shift);return true
 end
 if key=='backspace'or key=='delete'then
  if a==b then if key=='backspace'and s.cursor>0 then s.anchor=utf8.offset(value,-1,s.cursor+1)-1 elseif key=='delete'and s.cursor<#value then s.anchor=(utf8.offset(value,2,s.cursor+1)or(#value+1))-1 end end
  T.insert(L,'');return true
 end
 return false
end
local function displayed(value,masked)return masked and string.rep('*',utf8.len(value)or 0)or value end
function T.draw(L,index,x,y,width)
 local g=love.graphics;local value=L.fields[index];local mask=index==3;local text=displayed(value,mask);local font=g.getFont();local s=index==L.focus and state(L)or nil;local offset=0
 if s then offset=math.max(0,font:getWidth(displayed(value:sub(1,s.cursor),mask))-width+8);s.scroll=offset end
 local sx,sy=g.getWidth()/1100,g.getHeight()/700;g.setScissor((x-4)*sx,(y-5)*sy,(width+8)*sx,30*sy)
 if s then local a,b=bounds(s);if b>a then local left=font:getWidth(displayed(value:sub(1,a),mask));local right=font:getWidth(displayed(value:sub(1,b),mask));g.setColor(.35,.48,.35);g.rectangle('fill',x+left-offset,y-2,right-left,font:getHeight()+4)end end
 g.setColor(1,1,1);g.print(text,x-offset,y)
 if s and love.timer.getTime()%1<.6 then local cx=x+font:getWidth(displayed(value:sub(1,s.cursor),mask))-offset;g.line(cx,y,cx,y+font:getHeight())end
 g.setScissor()
end
function T.click(L,index,x)
 L.focus=index;local s,value=state(L);local font=love.graphics.getFont();local target=x+(s.scroll or 0);local cursor=0;local previous=0
 for pos in utf8.codes(value)do local nextPos=utf8.offset(value,2,pos)or(#value+1);local byte=nextPos-1;local width=font:getWidth(displayed(value:sub(1,byte),index==3));if target<(previous+width)/2 then break end;cursor=byte;previous=width end
 s.cursor=cursor;s.anchor=cursor
end
return T
