local R={cache={},states={},records={}}
local function read(path)local ok,v=pcall(function()local fn=love.filesystem.load(path);return fn and fn()end);return ok and type(v)=='table' and v or nil end
function R.boot(document,save)
 local d=document or (require('game.world_package').current and require('game.world_package').current.files.current) or read('current.lua');R.doc=nil;R.cache={};R.states={};R.records={};R.masks={};R.previews={}
 if not d or d.format~='StonegroveWorld' then return end
 R.doc=d;R.networkFingerprint=require('game.world_fingerprint').of({world=d,items=require('item_data'),npcs=require('npc_data'),monsters=require('monster_data'),quests=require('quest_data'),events=require('event_data'),content=require('content_data')});for _,r in ipairs(d.maps or {})do R.records[r.id]=r;r.data.regionId=r.id;local seed=17;for i=1,#(d.worldId..r.id)do seed=(seed*31+(d.worldId..r.id):byte(i))%2147483646 end;r.data.seed=r.data.seed or seed end
 R.start=R.records[d.startMap] and d.startMap or (d.maps[1] and d.maps[1].id);R.active=R.start
 local old=save or read('character_save.lua')
 if old and old.worldId==d.worldId and R.records[old.regionId]then R.active=old.regionId;R.states=old.regions or {}end
end
function R.data()return R.doc and R.records[R.active] and R.records[R.active].data end
function R.areaLevel(map)
 local direct=map and map.authored and map.authored.mapInfo;if direct then local lo=math.max(1,math.min(100,math.floor(tonumber(direct.levelMin)or 1)));return lo,math.max(lo,math.min(100,math.floor(tonumber(direct.levelMax)or 10)))end
 local id=map and map.authored and map.authored.regionId;local r=id and R.records[id]
 if not r then return 1,10 end
 local info=r.data and r.data.mapInfo;if info and tonumber(info.levelMin) and tonumber(info.levelMax) then return math.max(1,math.min(100,tonumber(info.levelMin))),math.max(1,math.min(100,tonumber(info.levelMax))) end
 local ring=math.abs(tonumber(r.x) or 0)+math.abs(tonumber(r.y) or 0)
 local lo=math.min(91,1+ring*10);return lo,math.min(100,lo+9)
end
function R.neighbor(map,dx,dy)
 local r=map.authored and R.records[map.authored.regionId];if not r then return nil end
 local name=(dx==-1 and dy==0 and 'west')or(dx==1 and dy==0 and 'east')or(dx==0 and dy==-1 and 'north')or(dx==0 and dy==1 and 'south');if not name then return nil end
 local info=r.data and r.data.mapInfo;local con=info and info.connections;if not(con and con[name])then return nil end
 local other=R.records[(r.x+dx)..','..(r.y+dy)];if not other then return nil end
 local opposite={west='east',east='west',north='south',south='north'};local oi=other.data and other.data.mapInfo;return oi and oi.connections and oi.connections[opposite[name]] and other or nil
end
function R.landAt(map,x,y)
 if not R.doc or not map.authored or not map.authored.regionId then return false end
 local dx=x<1 and -1 or x>map.cols and 1 or 0;local dy=y<1 and -1 or y>map.rows and 1 or 0
 local other=R.neighbor(map,dx,dy);if not other then return false end
 local data=other.data;local mask=R.masks[other.id];if not mask then mask={};for _,i in ipairs(data.landCells or {})do mask[i]=true end;R.masks[other.id]=mask end
 x=x<1 and data.cols or x>map.cols and 1 or x;y=y<1 and data.rows or y>map.rows and 1 or y
 return mask[(y-1)*data.cols+x-1] or false
end
function R.edgeProtected(map,x,y,pad)
 return (x<pad and R.neighbor(map,-1,0)) or (x>map.width-pad and R.neighbor(map,1,0)) or (y<pad and R.neighbor(map,0,-1)) or (y>map.height-pad and R.neighbor(map,0,1))
end
function R.drawNeighbors(w)
 if not R.doc or w.isCave then return end
 local sw,sh=love.graphics.getDimensions();local left,top=love.graphics.inverseTransformPoint(0,0);local right,bottom=love.graphics.inverseTransformPoint(sw,sh)
 for dy=-1,1 do for dx=-1,1 do if dx~=0 or dy~=0 then local other=R.neighbor(w.map,dx,dy)
  if other then local ox,oy=dx*w.map.width,dy*w.map.height;local data=other.data
   if right>ox and bottom>oy and left<ox+data.cols*16 and top<oy+data.rows*16 then
    local preview=R.previews[other.id]
    if not preview then
     local mask={};for _,i in ipairs(data.landCells)do mask[i]=true end
     local map={cols=data.cols,rows=data.rows,tile=16,authored=data}
     function map:landAt(x,y)if x>=1 and x<=self.cols and y>=1 and y<=self.rows then return mask[(y-1)*self.cols+x-1]or false end;return R.landAt(self,x,y)end
     preview={map=map};R.previews[other.id]=preview
    end
    love.graphics.push();love.graphics.translate(ox,oy)
    require('game.terrain_renderer').draw(preview.map,math.floor((left-ox)/16)-1,math.floor((top-oy)/16)-1,math.ceil((right-ox)/16)+1,math.ceil((bottom-oy)/16)+1)
    require('game.authored_paths').draw(preview);require('game.mountains').draw(preview.map,math.floor((left-ox)/16)-1,math.floor((top-oy)/16)-1,math.ceil((right-ox)/16)+1,math.ceil((bottom-oy)/16)+1);love.graphics.pop()
   end
  end
 end end end
end
local function capture(w)
 if w.isCave then w=w.overworld end
 if not w.regionId then return end
 R.states[w.regionId]={placedContainers=require("game.items").copy(w.placedContainers or{}),burialGraves=require("game.rune_inventory").copy(w.burialGraves or{}),gravestones=require("game.rune_inventory").copy(w.gravestones or{}),graveGround=require("game.rune_inventory").copy(w.groundItems or{}),fireState=require("game.fire_fuel").export(w),ore=require('game.prospecting').save(w),caves=require('game.caves').export(w),merchantItems=require('game.items').shopSnapshot(w),hideStations=require('game.hide_processing').export(w)}
end
function R.get(id,sprites)
 if R.cache[id]then return R.cache[id]end
 local record=assert(R.records[id],'Unknown world map');local w=require('game.world').new(sprites,record.data);w.regionId=id;R.cache[id]=w
 local state=R.states[id];if state then w.placedContainers=state.placedContainers or{};w.burialGraves=state.burialGraves or{};w.gravestones=state.gravestones or{};w.groundItems=state.graveGround or w.groundItems; require("game.fire_fuel").restore(w,state.fireState);require('game.hide_processing').restore(w,state.hideStations); require('game.items').restoreShops(w,state.merchantItems); require('game.prospecting').load(w,state.ore);if state.caves then require('game.caves').restore(w,state.caves)end end
 return w
end
function R.preload(sprites,progress)
 if not R.doc then return end
 for i,record in ipairs(R.doc.maps or{})do if progress then progress(record.id,i,#R.doc.maps)end;R.get(record.id,sprites)end
end
function R.initial(sprites)
 if not R.doc then return require('game.world').new(sprites)end
 return R.get(R.active,sprites)
end
local function safe(w,x,y)
 if x>=8 and y>=8 and x<w.map.width-8 and y<w.map.height-12 and not w:playerBlocked(x,y)then return x,y end
 for radius=16,256,16 do for i=0,15 do local a=i*math.pi/8;local xx,yy=x+math.cos(a)*radius,y+math.sin(a)*radius
  if xx>=8 and yy>=8 and xx<w.map.width-8 and yy<w.map.height-12 and not w:playerBlocked(xx,yy)then return xx,yy end
 end end
 for _,k in ipairs((w.map.authored or {}).landCells or {})do local xx=(k%w.map.cols)*16+8;local yy=math.floor(k/w.map.cols)*16+8;if not w:playerBlocked(xx,yy)then return xx,yy end end
 return x,y
end
function R.placeStart(w,p)
 local pos=(w.map.authored or {}).playerStart or {x=w.map.width/2,y=w.map.height/2+55};p.x,p.y=safe(w,pos.x,pos.y)
 for _,m in ipairs(w.mercs or {})do m.x,m.y=safe(w,p.x+20,p.y+20)end
end
function R.newGame(sprites)
 R.cache={};R.states={};R.active=R.start
 return R.initial(sprites)
end
function R.restore(ui,d)
 if not R.doc then return false end
 local valid=d.worldId==R.doc.worldId and R.records[d.regionId]~=nil
 local id=valid and d.regionId or R.start
 if valid then R.states=d.regions or {}end
 ui.world=R.get(id,ui.sprites);R.active=id
 return not valid
end
function R.finishLoad(ui,d,migrate)
 if not R.doc then return end
 if migrate then R.placeStart(ui.world,ui.player)else ui.player.x,ui.player.y=safe(ui.world,ui.player.x,ui.player.y)end
 ui.world.playerRef=ui.player;ui.world.questPlayer=ui.player
end
function R.save(w)
 if not R.doc then return nil,nil,nil end
 capture(w);for _,v in pairs(R.cache)do capture(v)end
 local over=w.overworld or w;return over.regionId,R.doc.worldId,R.states
end
local function transfer(ui,w,x,y)
 local old=ui.world;require("game.party").markDeaths(old);capture(old);old:stopCombat('map_transition',ui.logger);old.gather=nil;old.fishing=nil;old.targetedEnemy=nil
 for _,name in ipairs({'playerArrows','mercArrows','magicProjectiles','enemyProjectiles','goblinShots','bossShots'})do old[name]={}end
 w.mercs=old.mercs;ui.world=w;R.active=w.regionId;ui.player.x,ui.player.y=x,y;w.playerRef=ui.player;w.questPlayer=ui.player
 ui.questPanel=nil;ui.craftJob=nil;ui.magicCast=nil;ui.useTarget=nil;ui.context=nil
 for name in pairs(ui.open)do if name~='inventory' and name~='equipment' and name~='skills' and name~='mercBand'then ui.open[name]=false end end
 for _,m in ipairs(w.mercs or {})do if not m.waitingInTown and (m.hp or 0)>0 then m.x,m.y=safe(w,x+16,y+16);require('game.navigation').forget(m)end end
 require('game.villages').nearest(w,x,y)
 w.notifications[#w.notifications+1]={text='Map '..w.regionId,t=3}
end
function R.teleport(ui,id,x,y)
 local w=R.doc and R.get(id,ui.sprites)or(ui.world.overworld or ui.world);local xx,yy=safe(w,x,y);transfer(ui,w,xx,yy);return true
end
function R.cross(ui,dx,dy,oldX,oldY)
 local w,p=ui.world,ui.player;if not R.doc or w.isCave then return false end
 local sx,sy=0,0
 if dx<0 and p.x<10 then sx=-1 elseif dx>0 and p.x>w.map.width-10 then sx=1 elseif dy<0 and p.y<10 then sy=-1 elseif dy>0 and p.y>w.map.height-14 then sy=1 else return false end
 local other=R.neighbor(w.map,sx,sy);if not other then p.x,p.y=oldX,oldY;return false end
 local edgeX=sx<0 and 8 or sx>0 and w.map.width-8 or p.x;local edgeY=sy<0 and 8 or sy>0 and w.map.height-12 or p.y
 if w:playerBlocked(edgeX,edgeY,oldX,oldY)then p.x,p.y=oldX,oldY;return false end
 local nextWorld=R.get(other.id,ui.sprites)
 local x=sx<0 and nextWorld.map.width-24 or sx>0 and 24 or p.x
 local y=sy<0 and nextWorld.map.height-28 or sy>0 and 24 or p.y
 if nextWorld:playerBlocked(x,y)then p.x,p.y=oldX,oldY;return false end
 transfer(ui,nextWorld,x,y);return true
end
function R.transfer(ui,id,x,y)
 if not R.records[id]then return false end
 local destination=R.get(id,ui.sprites);if not destination.map:isLand(x,y)then return false end
 capture(ui.world);R.active=id;ui.world=destination;ui.player.x,ui.player.y=x,y;return true
end
return R

