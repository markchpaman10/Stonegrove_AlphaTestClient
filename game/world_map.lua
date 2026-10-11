local M={open=false,x=70,y=55,w=760,h=560,panX=0,panY=0,zoom=1,drag=false,resize=false,offX=0,offY=0,minW=480,minH=330,
 filters={towns=true,people=true,stations=true,services=true,quests=true,caves=true}}
local stationIds={smelter=true,anvil=true,tanningVat=true,hideStretcher=true,spinningWheel=true,alchemy=true,stove=true,magicAltar=true,religionAltar=true,socketTable=true,enchantAltar=true,inscription=true,tailoring=true,campfire=true}
local peopleIds={skillVendor=true,shopkeeper=true,trader=true,healer=true,guard=true,mercRecruiter=true,bankClerk=true,questGather=true,questKill=true,questEscort=true,questCave=true,questCamp=true,questStory=true}
local serviceIds={bankChest=true,caveEntrance=true,watchTower=true,largeGate=true}
local function inside(px,py,x,y,w,h)return px>=x and px<=x+w and py>=y and py<=y+h end
local function bounds(doc)
 local minx,maxx,miny,maxy=0,0,0,0
 for _,r in ipairs(doc and doc.maps or {})do minx=math.min(minx,r.x);maxx=math.max(maxx,r.x);miny=math.min(miny,r.y);maxy=math.max(maxy,r.y)end
 return minx,maxx,miny,maxy
end
function M.openMap(sw,sh)
 M.open=true;M.w=math.min(M.w,sw-24);M.h=math.min(M.h,sh-24);M.x=math.max(8,math.min(sw-M.w-8,M.x));M.y=math.max(8,math.min(sh-M.h-8,M.y))
end
function M.close()M.open=false;M.drag=false;M.resize=false end
local function category(id)
 if id:match('^quest')then return 'quests'end
 if stationIds[id] then return 'stations' end
 if peopleIds[id] then return 'people' end
 if id=='caveEntrance' then return 'caves' end
 if serviceIds[id] then return 'services' end
 if id=='townCenter' or id=='playerStart' then return 'towns' end
 return nil
end
local function marker(col,row,size,ox,oy,o,cat)
 local px=ox+col*size+(o.x/(o._mw or 1))*size;local py=oy+row*size+(o.y/(o._mh or 1))*size
 if cat=='people' then love.graphics.setColor(.35,.8,1) ;love.graphics.circle('fill',px,py,3)
 elseif cat=='stations' then love.graphics.setColor(1,.68,.18);love.graphics.rectangle('fill',px-3,py-3,6,6)
 elseif cat=='caves' then love.graphics.setColor(.82,.55,1);love.graphics.polygon('fill',px,py-4,px-4,py+3,px+4,py+3)
 elseif cat=='quests'then love.graphics.setColor(1,.6,.15);love.graphics.polygon('fill',px,py-4,px-4,py,px,py+4,px+4,py)
 elseif cat=='towns' then love.graphics.setColor(1,.88,.35);love.graphics.circle('fill',px,py,5);love.graphics.circle('line',px,py,7)
 else love.graphics.setColor(.75,.9,.72);love.graphics.rectangle('line',px-3,py-3,6,6) end
end
function M.draw(regions,world,player)
 if not M.open then return end
 local sw,sh=love.graphics.getDimensions();M.w=math.min(M.w,sw-16);M.h=math.min(M.h,sh-16);M.x=math.max(8,math.min(sw-M.w-8,M.x));M.y=math.max(8,math.min(sh-M.h-8,M.y))
 love.graphics.setColor(.025,.03,.025,.97);love.graphics.rectangle('fill',M.x,M.y,M.w,M.h,7);love.graphics.setColor(.62,.5,.28);love.graphics.rectangle('line',M.x,M.y,M.w,M.h,7)
 love.graphics.setColor(1,.86,.55);love.graphics.print('WORLD MAP',M.x+12,M.y+9);love.graphics.setColor(.8,.8,.76);love.graphics.print('Scroll: zoom / Drag: pan',M.x+110,M.y+9);love.graphics.setColor(1,.55,.45);love.graphics.print('X',M.x+M.w-22,M.y+9)
 local cats={{'towns','Towns'},{'people','People'},{'stations','Workstations'},{'services','Services'},{'quests','Quests'},{'caves','Caves'}};local fx=M.x+12
 for _,c in ipairs(cats)do local tw=love.graphics.getFont():getWidth(c[2])+28;love.graphics.setColor(M.filters[c[1]] and .22 or .08,M.filters[c[1]] and .35 or .08,.16);love.graphics.rectangle('fill',fx,M.y+34,tw,22,3);love.graphics.setColor(1,1,1);love.graphics.print((M.filters[c[1]] and '[x] ' or '[ ] ')..c[2],fx+4,M.y+38);c._x=fx;c._w=tw;fx=fx+tw+5 end
 M.regions=regions;M.player=world.isCave and world.entry or player;local mapPlayer=M.player
 local vx,vy,vw,vh=M.x+10,M.y+64,M.w-20,M.h-76;love.graphics.setScissor(vx,vy,vw,vh)
 local doc=regions.doc;if doc then
  local minx,maxx,miny,maxy=bounds(doc);local cols=maxx-minx+1;local rows=maxy-miny+1;local size=math.max(80,math.min((vw-40)/math.max(1,cols),(vh-40)/math.max(1,rows)))*M.zoom
  local baseX=vx+vw/2-(cols*size)/2+M.panX;local baseY=vy+vh/2-(rows*size)/2+M.panY
  for _,r in ipairs(doc.maps or {})do local col,row=r.x-minx,r.y-miny;local px,py=baseX+col*size,baseY+row*size;local d=r.data;local sx=size/d.cols;local sy=size/d.rows
   local image=require('game.map_texture').get(d);love.graphics.setColor(1,1,1);love.graphics.draw(image,px,py,0,size/image:getWidth(),size/image:getHeight())
   love.graphics.setColor(r.id==regions.active and 1 or .38,r.id==regions.active and .75 or .48,.28);love.graphics.rectangle('line',px,py,size,size);love.graphics.setColor(.9,.9,.84);love.graphics.print(r.id,px+4,py+3)
   for _,o in ipairs(d.objects or {})do local cat=category(o.id);if cat and M.filters[cat] then o._mw=d.cols*16;o._mh=d.rows*16;marker(col,row,size,baseX,baseY,o,cat)end end
   require('game.presence').drawRegion(r,px,py,size,{x=vx,y=vy,w=vw,h=vh})
   if r.id==regions.active then local qx=px+(mapPlayer.x/(d.cols*16))*size;local qy=py+(mapPlayer.y/(d.rows*16))*size;love.graphics.setColor(1,1,1);love.graphics.circle('fill',qx,qy,4);love.graphics.setColor(.05,.05,.04);love.graphics.circle('line',qx,qy,4)end
  end
 end
 love.graphics.setScissor()
 for i,label in ipairs({'You','−','+','1x'})do local bx=M.x+M.w-190+(i-1)*40;love.graphics.setColor(.14,.22,.18);love.graphics.rectangle('fill',bx,M.y+5,36,24,3);love.graphics.setColor(1,1,1);love.graphics.printf(label,bx,M.y+9,36,'center')end
 love.graphics.setColor(.75,.65,.4);love.graphics.line(M.x+M.w-15,M.y+M.h-4,M.x+M.w-4,M.y+M.h-15);love.graphics.line(M.x+M.w-10,M.y+M.h-4,M.x+M.w-4,M.y+M.h-10)
end
function M.mousepressed(x,y,b)
 if not M.open or b~=1 then return false end
 for i=1,4 do if inside(x,y,M.x+M.w-190+(i-1)*40,M.y+5,36,24)then
  if i==1 then M.recenter()elseif i==2 then M.zoomAt(-1)elseif i==3 then M.zoomAt(1)else M.zoom=1;M.panX=0;M.panY=0 end;return true
 end end
 if inside(x,y,M.x+M.w-34,M.y,34,32)then M.close();return true end
 local cats={{'towns','Towns'},{'people','People'},{'stations','Workstations'},{'services','Services'},{'quests','Quests'},{'caves','Caves'}};local fx=M.x+12
 for _,c in ipairs(cats)do local tw=love.graphics.getFont():getWidth(c[2])+28;if inside(x,y,fx,M.y+34,tw,22)then M.filters[c[1]]=not M.filters[c[1]];return true end;fx=fx+tw+5 end
 if inside(x,y,M.x+M.w-22,M.y+M.h-22,22,22)then M.resize=true;M.offX=M.x+M.w-x;M.offY=M.y+M.h-y;return true end
 if require('game.presence').hover(x,y,'world')then return true end
 if inside(x,y,M.x+10,M.y+64,M.w-20,M.h-76)then M.drag=true;M.offX=x;M.offY=y;return true end
 return true
end
function M.mousemoved(x,y,dx,dy)
 if M.resize then local sw,sh=love.graphics.getDimensions();M.w=math.max(M.minW,math.min(sw-M.x-8,x-M.x+M.offX));M.h=math.max(M.minH,math.min(sh-M.y-8,y-M.y+M.offY));return true end
 if M.drag then M.panX=M.panX+dx;M.panY=M.panY+dy;return true end
 return M.open
end
function M.mousereleased(x,y,b)if b==1 and (M.drag or M.resize)then M.drag=false;M.resize=false;return true end return M.open end
function M.zoomAt(delta,mx,my)
 local old=M.zoom;M.zoom=math.max(.5,math.min(8,old*1.2^delta));local ratio=M.zoom/old
 local cx,cy=M.x+M.w/2,M.y+64+(M.h-76)/2;mx,my=mx or cx,my or cy
 M.panX=(mx-cx)-(mx-cx-M.panX)*ratio;M.panY=(my-cy)-(my-cy-M.panY)*ratio
end
function M.wheel(delta,mx,my)if M.open then M.zoomAt(delta,mx,my);return true end end
function M.recenter()
 local regions,p=M.regions,M.player;if not regions or not regions.doc or not p then return end
 local minx,maxx,miny,maxy=bounds(regions.doc);local cols,rows=maxx-minx+1,maxy-miny+1
 local size=math.max(80,math.min((M.w-60)/cols,(M.h-116)/rows))*M.zoom
 for _,r in ipairs(regions.doc.maps)do if r.id==regions.active then M.panX=cols*size/2-((r.x-minx)+p.x/(r.data.cols*16))*size;M.panY=rows*size/2-((r.y-miny)+p.y/(r.data.rows*16))*size;break end end
end
return M
