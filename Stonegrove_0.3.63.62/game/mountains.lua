local M={}
function M.mask(map)
 local source=map.mountainMask or(map.authored and map.authored.mountainCells)
 if map.mountainMask then return source end
 if not map._mountainMask or map._mountainSource~=source then
  map._mountainSource=source;map._mountainMask={}
  for _,k in ipairs(source or{})do if type(k)=='number'and k>=0 and k<map.cols*map.rows and k%1==0 then map._mountainMask[k]=true end end
 end
 return map._mountainMask or{}
end
function M.at(map,x,y)
 return x>=0 and y>=0 and x<map.cols and y<map.rows and M.mask(map)[y*map.cols+x]or false
end
function M.ramps(map)return map.mountainRamps or(map.authored and map.authored.mountainRamps)or{}end
function M.onRamp(map,x,y)
 for _,r in pairs(M.ramps(map))do
  if M.validRamp(map,r)then local rx,ry=r.x*16,r.y*16
   if x>=rx+8 and x<rx+40 and y>=ry and y<ry+64 then return true end
  end
 end
 return false
end
function M.validRamp(map,r)
 if type(r)~='table'or type(r.x)~='number'or type(r.y)~='number'or r.x%1~=0 or r.y%1~=0 then return false end
 for x=r.x,r.x+2 do if not M.at(map,x,r.y)or M.at(map,x,r.y+1)then return false end end
 return true
end
M.styles={{x=0,y=0,name='Grass'},{x=128,y=0,name='Grass / Dirt Path'},{x=0,y=80,name='Grass / Water Base'},{x=128,y=80,name='Dirt'},{x=0,y=160,name='Cave'}}
function M.style(map,x,y)
 local value=map.mountainMask and map.mountainMask[y*map.cols+x]or(map.authored and map.authored.mountainStyles or{})[y*map.cols+x]
 return type(value)=='number'and M.styles[value]and value or 1
end
function M.load()
 if M.image then return end
 M.image=love.graphics.newImage('assets/mountain_autotile.png');M.image:setFilter('nearest','nearest');M.styleQuads={};M.rampQuads={}
 for i,st in ipairs(M.styles)do local qs={};M.styleQuads[i]=qs
  for y=0,9 do for x=0,9 do qs[y*16+x]=love.graphics.newQuad(st.x+x*8,st.y+y*8,8,8,256,240)end end
  if i~=5 then M.rampQuads[i]={love.graphics.newQuad(st.x+80,st.y+16,48,64,256,240),love.graphics.newQuad(st.x+96,st.y+32,16,16,256,240)}end
 end
 M.quads=M.styleQuads[1];M.caveEntranceQuad=love.graphics.newQuad(240,160,16,32,256,240);M.caveExitImage=love.graphics.newImage('assets/mountain_cave_parts.png');M.caveExitImage:setFilter('nearest','nearest');M.caveExitQuad=love.graphics.newQuad(80,48,16,32,96,80)
end
function M.drawCave(x,y,exit)
 M.load();love.graphics.setColor(1,1,1);love.graphics.draw(exit and M.caveExitImage or M.image,exit and M.caveExitQuad or M.caveEntranceQuad,x-8,y-24)
end
-- Four independent quadrants connect the top, including diagonal cut-ins.
function M.part(h,v,d,dx,dy)
 local x=h and 2 or(dx<0 and 0 or 5);local y=v and 2 or(dy<0 and 0 or 5)
 if h and v and not d then x=dx<0 and 8 or 7;y=dy<0 and 4 or 3 end
 return x,y
end
function M.drawRamp(r,map)
 local x,y=r.x*16,r.y*16
 local parts=M.rampQuads[M.style(map,r.x,r.y)]or M.rampQuads[1];local q,fill=parts[1],parts[2]
 -- R mirrors the ramp for the opposite side, using the same supplied tiles.
 if r.mirror then love.graphics.draw(M.image,q,x+48,y,0,-1,1);love.graphics.draw(M.image,fill,x+32,y+32,0,-1,1)
 else love.graphics.draw(M.image,q,x,y);love.graphics.draw(M.image,fill,x+16,y+32)end
end
function M.drawLayer(map,left,top,right,bottom)
 local mask=M.mask(map);if not next(mask)then return end;M.load()
 left=math.max(0,left or 0);top=math.max(0,(top or 0)-2);right=math.min(map.cols-1,right or map.cols-1);bottom=math.min(map.rows-1,bottom or map.rows-1)
 love.graphics.setColor(1,1,1)
 for y=top,bottom do for x=left,right do if M.at(map,x,y)then
  local quads=M.styleQuads[M.style(map,x,y)]
  if not M.at(map,x,y+1)then
   for row=0,3 do for side=0,1 do
    local horizontal=M.at(map,x+(side==0 and -1 or 1),y)
    local sx=horizontal and 2 or(side==0 and 0 or 5)
    love.graphics.draw(M.image,quads[(6+row)*16+sx],x*16+side*8,y*16+16+row*8)
   end end
  end
  for _,c in ipairs({{-1,-1},{1,-1},{-1,1},{1,1}})do
   local sx,sy=M.part(M.at(map,x+c[1],y),M.at(map,x,y+c[2]),M.at(map,x+c[1],y+c[2]),c[1],c[2])
   love.graphics.draw(M.image,quads[sy*16+sx],x*16+(c[1]>0 and 8 or 0),y*16+(c[2]>0 and 8 or 0))
  end
 end end end
 for _,r in pairs(M.ramps(map))do if M.validRamp(map,r)and r.x+3>=left and r.x<=right and r.y+4>=top and r.y<=bottom then M.drawRamp(r,map)end end
end
function M.blockedLayer(map,x,y)
 if M.onRamp(map,x,y)then return false end
 local tx,ty=math.floor(x/16),math.floor(y/16)
 if M.at(map,tx,ty)then return not(M.at(map,tx-1,ty)and M.at(map,tx+1,ty)and M.at(map,tx,ty-1)and M.at(map,tx,ty+1))end
 return M.at(map,tx,ty-1)or M.at(map,tx,ty-2)
end
function M.layers(map)
 local layers=map.layerMaps or(map.authored and map.authored.mountainLayers)
 if not layers or #layers==0 then return {map}end
 if map._layerSource==layers and map._layerViews then return map._layerViews end
 local out={};for i=1,math.min(3,#layers)do local d=layers[i];out[i]={cols=map.cols,rows=map.rows,mountainMask=d.mask,mountainRamps=d.ramps,authored={mountainCells=d.cells,mountainStyles=d.styles,mountainRamps=d.ramps}}end
 map._layerSource=layers;map._layerViews=out;return out
end
function M.surface(map,x,y)
 local tx,ty=math.floor(x/16),math.floor(y/16)
 for _,layer in ipairs(M.layers(map))do if M.at(layer,tx,ty)then return true end end;return false
end
function M.blocked(map,x,y)
 local layers=M.layers(map);local tx,ty=math.floor(x/16),math.floor(y/16)
 for i=#layers,1,-1 do local layer=layers[i]
  if M.onRamp(layer,x,y)then return false end
  if M.at(layer,tx,ty)then return M.blockedLayer(layer,x,y)end
  if M.at(layer,tx,ty-1)or M.at(layer,tx,ty-2)then return true end
 end
 return false
end
function M.draw(map,left,top,right,bottom)
 for _,layer in ipairs(M.layers(map))do M.drawLayer(layer,left,top,right,bottom)end
end
function M.validate(d)
 local layers=d.mountainLayers or{{cells=d.mountainCells,styles=d.mountainStyles,ramps=d.mountainRamps}}
 if type(layers)~='table'or #layers>3 then return false,'Mountain layers must be between one and three'end
 local lower
 for i,l in ipairs(layers)do
  if type(l)~='table'then return false,'Invalid mountain layer'end
  local mask={};for _,k in ipairs(l.cells or{})do
   if type(k)~='number'or k%1~=0 or k<0 or k>=d.cols*d.rows then return false,'Invalid mountain cell'end
   if i>1 and not lower[k]then return false,'Upper mountain needs support on the layer below'end;mask[k]=true
  end
  for k,v in pairs(l.styles or{})do if not mask[k]or type(v)~='number'or not M.styles[v]then return false,'Invalid mountain style'end end
  for _,r in ipairs(l.ramps or{})do if type(r)~='table'or type(r.x)~='number'or type(r.y)~='number'or r.x%1~=0 or r.y%1~=0 or r.x<0 or r.y<0 or r.x+3>d.cols or r.y+4>d.rows then return false,'Invalid mountain ramp'end end
  lower=mask
 end
 return true
end
function M.spawnBlocked(map,x,y,pad)
 pad=pad or 0
 for _,layer in ipairs(M.layers(map))do for _,r in pairs(M.ramps(layer))do
  if M.validRamp(layer,r)and x>=r.x*16-pad and x<(r.x+3)*16+pad and y>=r.y*16-pad and y<(r.y+4)*16+pad then return true end
 end end
 return false
end
return M
