-- Map-only ghosts: no actors, collisions, combat, inventory or interaction hooks.
local V={peers={},targets={},generation=0,interval=2,ttl=15,nextPoll=0}
local function now()return love.timer.getTime()end
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
function V.context(w,p)
 local over=w.overworld or w;local regions=require('game.regions')
 return {worldId=regions.doc and regions.doc.worldId or('legacy-'..tostring(over.houseSeed or 0)),regionId=over.regionId or regions.active or'local',
  x=p.x,y=p.y,mapX=w.isCave and w.entry.x or p.x,mapY=w.isCave and w.entry.y or p.y,
  area=w.isCave and'cave'or'overworld',caveId=w.isCave and w.entry.id or 0,caveSeed=w.isCave and w.entry.seed or 0}
end
function V.stop()
 local session=V.session;V.session=nil;V.key=nil;V.peers={};V.targets={};V.generation=V.generation+1;V.busy=false;V.nextPoll=0;V.receivedAt=nil
 if session then require('game.network').request(session.server..'/v1/presence/leave','POST',{},session.token,function()end)end
end
function V.update(L)
 local P=require('game.profile');local session=L.session
 local active=L.screen=='game'and L.confirmed and not L.leaving and not L.quitting and session and P.active and ui and ui.world and player
 if not active then if V.session then V.stop()end;return end
 local context=V.context(ui.world,player);context.slot=P.active.slot
 local key=session.server..'|'..session.token..'|'..context.slot..'|'..context.worldId
 if V.key~=key then if V.session then V.stop()end;V.key=key;V.session={server=session.server,token=session.token,id=session.id};V.generation=V.generation+1;V.nextPoll=0 end
 local clock=now();if V.receivedAt and clock-V.receivedAt>=V.ttl then V.peers={};V.targets={}end
 if V.busy or clock<V.nextPoll then return end
 V.busy=true;V.nextPoll=clock+V.interval;local generation=V.generation
 require('game.network').request(session.server..'/v1/presence','POST',context,session.token,function(r)
  if generation~=V.generation then return end;V.busy=false
  if r.status==200 and r.data and type(r.data.players)=='table'then
   local peers={}
   for _,p in ipairs(r.data.players)do
    if finite(p.id)and p.id>0 and p.id%1==0 and p.id~=session.id and type(p.name)=='string'and #p.name<=320 and p.worldId==context.worldId and type(p.regionId)=='string'and
     finite(p.x)and finite(p.y)and finite(p.mapX)and finite(p.mapY)and(p.area=='overworld'or p.area=='cave')and finite(p.caveId)and finite(p.caveSeed)then
     peers[#peers+1]={id=p.id,name=p.name:gsub('[%z\1-\31]',' '),worldId=p.worldId,regionId=p.regionId,x=p.x,y=p.y,mapX=p.mapX,mapY=p.mapY,area=p.area,caveId=p.caveId,caveSeed=p.caveSeed}
    end
   end
   V.peers=peers;V.receivedAt=now()
  elseif r.status==401 or r.status==404 then V.peers={};V.targets={};V.nextPoll=now()+30
  else V.nextPoll=now()+5 end
 end)
end
function V.install(L)
 if V.installed then return end;V.installed=true
 local update,quit=love.update,love.quit
 love.update=function(dt)if update then update(dt)end;V.update(L)end
 love.quit=function(...)V.stop();if quit then return quit(...)end end
 for _,name in ipairs({'slots','returnSlots'})do
  local old=L[name];if old then L[name]=function(...)V.stop();return old(...)end end
 end
end
function V.beginFrame()V.targets={}end
local function ghost(peer,x,y,size,layer)
 local g=love.graphics
 g.setColor(.63,.91,1,.68);g.circle('fill',x,y-size*.25,size*.55)
 g.polygon('fill',x-size*.55,y-size*.25,x-size*.55,y+size*.65,x-size*.25,y+size*.4,x,y+size*.65,x+size*.25,y+size*.4,x+size*.55,y+size*.65,x+size*.55,y-size*.25)
 g.setColor(.06,.16,.23,.9);g.circle('fill',x-size*.2,y-size*.25,size*.09);g.circle('fill',x+size*.2,y-size*.25,size*.09)
 V.targets[#V.targets+1]={x=x,y=y,r=math.max(7,size),name=peer.name,layer=layer}
end
function V.drawMinimap(w,p,x,y,mw,mh,left,top,sx,sy,cx,cy,radius)
 local context=V.context(w,p)
 for _,peer in ipairs(V.peers)do if peer.worldId==context.worldId and peer.regionId==context.regionId and peer.area==context.area and peer.caveId==context.caveId and peer.caveSeed==context.caveSeed then
  local px,py=x+(peer.x-left)*sx,y+(peer.y-top)*sy
  if(px-cx)^2+(py-cy)^2<=(radius-8)^2 then ghost(peer,px,py,8,'mini')end
 end end
 love.graphics.setColor(1,1,1)
end
function V.drawRegion(r,x,y,size,clip)
 local doc=require('game.regions').doc
 for _,peer in ipairs(V.peers)do if doc and peer.worldId==doc.worldId and peer.regionId==r.id then
  local px,py=x+peer.mapX/(r.data.cols*16)*size,y+peer.mapY/(r.data.rows*16)*size
  if peer.mapX>=0 and peer.mapX<=r.data.cols*16 and peer.mapY>=0 and peer.mapY<=r.data.rows*16 and px>=clip.x+7 and px<=clip.x+clip.w-7 and py>=clip.y+7 and py<=clip.y+clip.h-7 then ghost(peer,px,py,7,'world')end
 end end
 love.graphics.setColor(1,1,1)
end
function V.hover(x,y,layer)
 local worldMap=require('game.world_map')
 if worldMap.open and x>=worldMap.x and x<=worldMap.x+worldMap.w and y>=worldMap.y and y<=worldMap.y+worldMap.h then layer='world'end
 for _,t in ipairs(V.targets)do if(not layer or t.layer==layer)and(x-t.x)^2+(y-t.y)^2<=t.r*t.r then return true end end
 return false
end
function V.drawTooltip(w,h)
 local mx,my=love.mouse.getPosition();if not V.hover(mx,my)then return end
 local map=require('game.world_map');local layer=map.open and mx>=map.x and mx<=map.x+map.w and my>=map.y and my<=map.y+map.h and'world'or nil
 local names,seen={},{}
 for _,t in ipairs(V.targets)do if(not layer or t.layer==layer)and(mx-t.x)^2+(my-t.y)^2<=t.r*t.r and not seen[t.name]then seen[t.name]=true;names[#names+1]=t.name end end
 if #names==0 then return end;table.sort(names)
 local g=love.graphics;local font=g.getFont();local width=0;for _,name in ipairs(names)do width=math.max(width,font:getWidth(name))end;width=math.min(w-16,width+20)
 local text=table.concat(names,'\n');local _,lines=font:getWrap(text,width-20);local height=math.min(h-16,#lines*font:getHeight()+16)
 local x=math.max(8,math.min(w-width-8,mx+12));local y=math.max(8,math.min(h-height-8,my+14))
 g.setColor(.03,.055,.07,.96);g.rectangle('fill',x,y,width,height,4,4);g.setColor(.57,.8,.9,.9);g.rectangle('line',x,y,width,height,4,4)
 g.setColor(.86,.96,1);g.printf(text,x+10,y+8,width-20,'left');g.setColor(1,1,1)
end
return V
