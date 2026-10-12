local A={open=false,tab=1,search='',amount='1',level='99',scroll=0,buttons={},focus=nil,x=100,y=75,w=690,h=490}
local function bounded(value,limit)local i=require('utf8').offset(value,limit+1);return i and value:sub(1,i-1)or value end
local function inside(x,y,b)return x>=b.x and y>=b.y and x<b.x+b.w and y<b.y+b.h end
function A.allowed()
 local l=require('game.launcher');return l.offline==true or(l.screen=='game'and l.confirmed and l.session and l.session.role=='admin')
end
function A.toggle()
 if not A.allowed()then if ui then ui.world:addPopup(player.x,player.y-24,'Administrator account required','miss')end;return false end
 A.open=not A.open;A.focus=nil;A.scroll=0;love.keyboard.setTextInput(A.open);return true
end
local function send(command)
 if not A.allowed()then A.open=false;return end
 command.op='admin';if A.target then command.targetId=A.target.id;command.targetSlot=A.target.slot end;require('game.fieldcraft_ui').command(ui,command)
end
function A.rows()
 local list={}
 if A.tab==1 then list={'All Skills'};for _,n in ipairs(require('game.skills').names)do list[#list+1]=n end
 elseif A.tab==2 then for name in pairs(ui.sprites.itemInfo)do list[#list+1]=name end;table.sort(list)
 elseif A.tab==3 then list=require('game.admin_rules').towns(ui.world)else list={{name='My character',self=true}};for _,p in ipairs(require('game.multiplayer').peers or{})do list[#list+1]=p end end
 local out={};for _,row in ipairs(list)do local name=type(row)=='table'and row.name or row;if name:lower():find(A.search:lower(),1,true)then out[#out+1]=row end end;return out
end
function A.draw()
 if not A.open or not ui then return end;if not A.allowed()then A.open=false;return end
 local g=love.graphics;local sw,sh=g.getDimensions();A.w=math.min(A.w,sw-24);A.h=math.min(A.h,sh-24);A.x=math.max(8,math.min(A.x,sw-A.w-8));A.y=math.max(8,math.min(A.y,sh-A.h-8));local x,y,w,h=A.x,A.y,A.w,A.h
 g.push('all');g.setColor(.025,.04,.055,.98);g.rectangle('fill',x,y,w,h,8);g.setColor(.45,.7,.8);g.rectangle('line',x,y,w,h,8);g.setColor(.95,.95,1);g.print('ADMINISTRATOR / OFFLINE DEVELOPMENT',x+16,y+12);A.buttons={}
 local function button(label,bx,by,bw,bh,fn)
  g.setColor(.12,.22,.28);g.rectangle('fill',bx,by,bw,bh,4);g.setColor(.9,.95,1);g.printf(label,bx+5,by+7,bw-10,'left');A.buttons[#A.buttons+1]={x=bx,y=by,w=bw,h=bh,fn=fn}
 end
 button('X',x+w-34,y+6,28,28,function()A.open=false;love.keyboard.setTextInput(false)end)
 for i,label in ipairs({'Skill Levels','Give Items','Teleport to Town','Players'})do button(label,x+14+(i-1)*165,y+43,157,30,function()A.tab=i;A.scroll=0;A.search='';A.focus=nil end)end
 button('Search: '..A.search,x+14,y+84,w-260,30,function()A.focus='search'end)
 button('Target: '..(A.target and A.target.name or 'My character'),x+w-238,y+84,224,30,function()
  local list={};for _,p in ipairs(require('game.multiplayer').peers or{})do list[#list+1]=p end;table.sort(list,function(a,b)return a.name<b.name end)
  local nextIndex=1;if A.target then for i,p in ipairs(list)do if p.id==A.target.id and p.slot==A.target.slot then nextIndex=i+1;break end end end;A.target=list[nextIndex]
 end)
 if A.tab<=2 then local key=A.tab==1 and'level'or'amount';button((A.tab==1 and'Level (1–99): 'or'Quantity: ')..A[key],x+14,y+123,220,30,function()A.focus=key end)end
 button('Restore health / stamina',x+w-250,y+123,236,30,function()send({action='heal'})end)
 local list=A.rows();local visible=math.max(1,math.floor((h-200)/34));A.scroll=math.min(A.scroll,math.max(0,#list-visible))
 for i=1,visible do local row=list[i+A.scroll];if row then local name=type(row)=='table'and row.name or row;local label=name
  if A.tab==1 and not A.target and ui.skills.data[name]then label=label..' — current '..ui.skills:get(name).level end
  local value=row;button(label,x+14,y+164+(i-1)*34,w-28,30,function()
   if A.tab==1 then send({action='level',skill=value,amount=tonumber(A.level)})elseif A.tab==2 then send({action='give',item=value,amount=tonumber(A.amount)})elseif A.tab==3 then send({action='teleport',region=value.region,index=value.index})else A.target=not value.self and value or nil;A.tab=1;A.scroll=0;A.search=''end
  end)
 end end
 g.setColor(.7,.8,.85);g.print('Click a row to apply. Scroll lists. Ctrl+Shift+Enter+Space / Escape closes.',x+14,y+h-25);g.pop()
end
function A.install()
 local key=love.keypressed;love.keypressed=function(k,s,repeatKey)
  if not repeatKey and(k=='return'or k=='space'or k=='lctrl'or k=='rctrl'or k=='lshift'or k=='rshift')and love.keyboard.isDown('lctrl','rctrl')and love.keyboard.isDown('lshift','rshift')and love.keyboard.isDown('return')and love.keyboard.isDown('space')then A.toggle();return end
  if A.open then if k=='escape'then A.open=false;A.focus=nil;love.keyboard.setTextInput(false)elseif k=='backspace'and A.focus then local v=A[A.focus];A[A.focus]=v:sub(1,(require('utf8').offset(v,-1)or 1)-1)elseif k=='v'and A.focus and love.keyboard.isDown('lctrl','rctrl')then local text=(love.system.getClipboardText()or''):gsub('%c','');if A.focus~='search'then text=text:gsub('%D','')end;A[A.focus]=bounded(A[A.focus]..text,A.focus=='search'and 80 or 7)end;return end
  return key(k,s,repeatKey)
 end
 local text=love.textinput;love.textinput=function(t)if A.open then if A.focus then if A.focus~='search'then t=t:gsub('%D','')end;A[A.focus]=bounded(A[A.focus]..t,A.focus=='search'and 80 or 7)end;return end;if text then return text(t)end end
 local press=love.mousepressed;love.mousepressed=function(x,y,b,...)if A.open then if b==1 then for _,v in ipairs(A.buttons)do if inside(x,y,v)then v.fn();return end end;if y<A.y+38 then A.drag={x=x-A.x,y=y-A.y}end end;return end;return press(x,y,b,...)end
 local move=love.mousemoved;love.mousemoved=function(x,y,...)if A.open then if A.drag then A.x=x-A.drag.x;A.y=y-A.drag.y end;return end;if move then return move(x,y,...)end end
 local release=love.mousereleased;love.mousereleased=function(...)if A.open then A.drag=nil;return end;if release then return release(...)end end
 local wheel=love.wheelmoved;love.wheelmoved=function(x,y)if A.open then A.scroll=math.max(0,A.scroll-y);return end;return wheel(x,y)end

end
return A
