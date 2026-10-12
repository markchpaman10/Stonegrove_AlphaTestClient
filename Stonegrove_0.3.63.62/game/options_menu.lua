local A=require('game.audio')
local O={open=false,selected=1,rows={{'master','Master'},{'combat','Combat & magic'},{'ambience','Ambience'},{'gathering','Gathering & fishing'},{'crafting','Crafting'},{'ui','UI & notifications'},{'footsteps','Footsteps'}}}
function O.layout()
 local w,h=love.graphics.getDimensions();local pw,ph=math.min(620,w-24),math.min(512,h-24);return (w-pw)/2,(h-ph)/2,pw,ph
end
function O.slider(i)
 local x,y,w=O.layout();return x+210,y+94+(i-1)*37,w-290,22
end
local function inside(x,y,a,b,w,h)return x>=a and y>=b and x<=a+w and y<=b+h end
function O.show()O.open=true;O.drag=nil;O.selected=1 end
function O.close()O.drag=nil;O.open=false;A.saveSettings()end
local function adjust(i,x)
 local sx,sy,sw=O.slider(i);A.setVolume(O.rows[i][1],(x-sx)/sw)
end
function O.click(x,y,b)
 if not O.open then return false end;if b~=1 then return true end
 local ox,oy,w,h=O.layout()
 for i=1,#O.rows do local sx,sy,sw,sh=O.slider(i);if inside(x,y,sx-8,sy-5,sw+16,sh+10) then O.selected=i;O.drag=i;adjust(i,x);return true end end
 if O.ui and inside(x,y,ox+24,oy+h-142,w-48,28)then O.ui.bagnonMode=not O.ui.bagnonMode;require("game.save").write(O.ui.player,O.ui.inv,O.ui.skills,O.ui,O.ui.logger);return true end
 if inside(x,y,ox+24,oy+45,w-48,30) then A.toggle()
 elseif inside(x,y,ox+24,oy+h-84,w-48,28) then love.window.setFullscreen(not love.window.getFullscreen())
 elseif inside(x,y,ox+24,oy+h-44,160,30) then A.resetSettings()
 elseif inside(x,y,ox+w-184,oy+h-44,160,30) then O.close() end
 return true
end
function O.move(x,y)if not O.open then return false end;if O.drag then adjust(O.drag,x)end;return true end
function O.release(x,y,b)if not O.open then return false end;if b==1 and O.drag then adjust(O.drag,x);O.drag=nil;A.saveSettings()end;return true end
function O.key(k)
 if not O.open then return false end
 if k=='escape' then O.close()
 elseif k=='up' then O.selected=(O.selected-2)%#O.rows+1
 elseif k=='down' or k=='tab' then O.selected=O.selected%#O.rows+1
 elseif k=='left' or k=='right' or k=='home' or k=='end' then
  local key=O.rows[O.selected][1];local v=key=='master' and A.volume or A.categories[key]
  A.setVolume(key,k=='home' and 0 or k=='end' and 1 or v+(k=='right' and .05 or -.05));A.saveSettings()
 end;return true
end
function O.draw()
 if not O.open then return end
 love.graphics.push('all');local x,y,w,h=O.layout();local sw,sh=love.graphics.getDimensions()
 love.graphics.setColor(0,0,0,.72);love.graphics.rectangle('fill',0,0,sw,sh)
 love.graphics.setColor(.08,.075,.055,.99);love.graphics.rectangle('fill',x,y,w,h,8,8)
 love.graphics.setColor(.72,.62,.40);love.graphics.rectangle('line',x,y,w,h,8,8)
 love.graphics.setColor(1,.88,.58);love.graphics.print('Options',x+24,y+16)
 local function button(label,bx,by,bw,bh)
  love.graphics.setColor(.65,.54,.35);love.graphics.rectangle('line',bx,by,bw,bh,4,4);love.graphics.setColor(1,1,1);love.graphics.printf(label,bx,by+8,bw,'center')
 end
 button('Audio: '..(A.enabled and 'On' or 'Muted'),x+24,y+45,w-48,30)
 for i,row in ipairs(O.rows) do
  local sx,sy,width=O.slider(i);local v=row[1]=='master' and A.volume or A.categories[row[1]]
  love.graphics.setColor(1,.94,.80);love.graphics.print(row[2],x+24,sy+4)
  love.graphics.setColor(.22,.20,.15);love.graphics.rectangle('fill',sx,sy+8,width,6,3,3)
  love.graphics.setColor(.80,.65,.34);love.graphics.rectangle('fill',sx,sy+8,width*v,6,3,3)
  love.graphics.setColor(i==O.selected and 1 or .8,.83,.51);love.graphics.circle('fill',sx+width*v,sy+11,7)
  love.graphics.setColor(1,1,1);love.graphics.printf(string.format('%d%%',math.floor(v*100+.5)),sx+width+12,sy+4,52,'right')
 end
 love.graphics.setColor(.80,.77,.68);love.graphics.print('Drag sliders. Arrow keys adjust audio.',x+24,y+h-104)
 if O.ui then button('Combined bags: '..(O.ui.bagnonMode and 'On' or 'Off'),x+24,y+h-142,w-48,28)end
 button('Fullscreen: '..(love.window.getFullscreen() and 'On' or 'Off'),x+24,y+h-84,w-48,28)
 button('Reset Audio',x+24,y+h-44,160,30);button('Back',x+w-184,y+h-44,160,30)
 love.graphics.pop()
end
return O
