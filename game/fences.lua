local F={}

-- Performance cache: fence collision used to scan every rail for every moving actor,
-- and tall-wall rendering rebuilt lookup tables/quads every frame. Keep the exact
-- behavior, but cache immutable authored fence geometry in 64px spatial buckets.
local BUCKET=64
local function bucketKey(x,y) return math.floor(x/BUCKET)..":"..math.floor(y/BUCKET) end
function F.ensureCache(world)
 local rails=world.fenceRails or {}; local gates=world.largeGateTiles or {}
 local c=world._fencePerfCache
 if c and c.rails==rails and c.gates==gates and c.railCount==#rails and c.gateCount==#gates then return c end
 c={rails=rails,gates=gates,railCount=#rails,gateCount=#gates,buckets={},gateSet={}}
 for _,r in ipairs(rails) do
  local minx,maxx=r.x-8,r.x+r.w+8;local miny,maxy=r.y-8,r.y+r.h+8
  for by=math.floor(miny/BUCKET),math.floor(maxy/BUCKET) do for bx=math.floor(minx/BUCKET),math.floor(maxx/BUCKET) do
   local k=bx..":"..by;local b=c.buckets[k];if not b then b={};c.buckets[k]=b end;b[#b+1]=r
  end end
 end
 for _,g in ipairs(gates) do c.gateSet[g.x..":"..g.y]=true end
 world._fencePerfCache=c;return c
end
function F.load()
 local data=love.image.newImageData('assets/fence_autotile.png')
 -- The supplied sheet has a flat grass backing rather than alpha in most cells.
 data:mapPixel(function(x,y,r,g,b,a) if math.abs(r-129/255)<.001 and math.abs(g-163/255)<.001 and math.abs(b-142/255)<.001 then return r,g,b,0 end;return r,g,b,a end)
 F.image=love.graphics.newImage(data);F.image:setFilter('nearest','nearest')
 F.horizontal=love.graphics.newQuad(32,0,16,16,80,32)
 F.vertical=love.graphics.newQuad(56,0,16,16,80,32)
end
function F.inside(p,x,y,pad)
 pad=pad or 0;return x>=p.x+pad and x<=p.x+p.w-pad and y>=p.y+pad and y<=p.y+p.h-pad
end
function F.blocked(world,x,y,actor)
 if actor and actor.pasture and not F.inside(actor.pasture,x,y,18) then return true end
 local c=F.ensureCache(world);local b=c.buckets[bucketKey(x,y+4)]
 if b then for _,r in ipairs(b) do
  if x>r.x-8 and x<r.x+r.w+8 and y+4>r.y-8 and y+4<r.y+r.h+8 then return true end
 end end
 return false
end
function F.prepare(world)
 for _,v in ipairs(world.villages) do
  local size=(v.townType=='large') and 896 or ((v.townType=='medium') and 620 or 420)
  local boundary={x=v.cx-size/2,y=v.cy-size/2,w=size,h=size}
  v.fenceBounds=boundary
  -- Reserve dry ground for the whole town plot, including a shoreline margin.
  local tile=world.map.tile
  for ty=math.floor((boundary.y-48)/tile)+1,math.floor((boundary.y+boundary.h+48)/tile)+1 do
   for tx=math.floor((boundary.x-48)/tile)+1,math.floor((boundary.x+boundary.w+48)/tile)+1 do
    if world.map.mask[ty] and tx>=1 and tx<=world.map.cols then world.map.mask[ty][tx]=true end
   end
  end
  world.map.batches=nil
 end
end
function F.build(world)
 require("game.node_index").invalidate(world)
 world.fenceRails={};world.pastures={}
 local function rail(x,y,vertical)
  world.fenceRails[#world.fenceRails+1]={x=x,y=y,w=vertical and 2 or 16,h=vertical and 16 or 2,vertical=vertical}
 end
 local function enclosure(p,town)
  for x=p.x,p.x+p.w-16,16 do
   local gap=math.abs(x+8-p.gateX)<(town and 40 or 24)
   if not gap then rail(x,p.y,false) end
   if not town or not gap then rail(x,p.y+p.h,false) end
  end
  for y=p.y,p.y+p.h-16,16 do
   if not town or math.abs(y+8-p.gateY)>=40 then rail(p.x,y,true);rail(p.x+p.w,y,true) end
  end
 end
 for _,v in ipairs(world.villages) do
  if v.townType=='large' then
  local boundary={x=v.cx-448,y=v.cy-448,w=896,h=896,gateX=v.cx,gateY=v.cy}
  enclosure(boundary,true);v.fenceBounds=boundary
  local p={x=v.cx-240,y=v.cy+250,w=480,h=300,gateX=v.cx};v.pasture=p;world.pastures[#world.pastures+1]=p
  enclosure(p,false)
  world.paths[#world.paths+1]={x=v.cx-16,y=v.cy+132,w=32,h=172}
  world.paths[#world.paths+1]={x=v.cx-16,y=v.cy-288,w=32,h=156}
  world.paths[#world.paths+1]={x=v.cx-400,y=v.cy-16,w=180,h=32}
  world.paths[#world.paths+1]={x=v.cx+220,y=v.cy-16,w=276,h=32}
  -- The south exit skirts the pasture rather than running through livestock.
  world.paths[#world.paths+1]={x=v.cx+240,y=v.cy+132,w=32,h=460}
  world.paths[#world.paths+1]={x=v.cx-16,y=v.cy+576,w=288,h=32}
  world.paths[#world.paths+1]={x=v.cx-16,y=v.cy+592,w=32,h=32}
  end
 end
 local counts={}
 local function houseAnimal(a)
  local v=require('game.villages').nearestData(world,a.x,a.y);local p=v and v.pasture
  if not p then return end
  counts[p]=(counts[p] or 0)+1;local i=counts[p]-1
  a.x=p.x+40+(i%6)*60;a.y=p.y+42+math.floor(i/6)*48
  a.homeX,a.homeY=a.x,a.y;a.spawnX,a.spawnY=a.x,a.y;a.roamX,a.roamY=a.x,a.y;a.pasture=p
 end
 for _,a in ipairs(world.sheep) do houseAnimal(a) end
 for _,a in ipairs(world.enemies) do if a.kind=='cow' or a.kind=='chicken' then houseAnimal(a) end end
 -- Keep pre-existing wilderness spawn layouts outside the expanded town plots.
 for _,a in ipairs(world.enemies) do if not a.pasture and not require('game.expansion').clearVillage(world,a.x,a.y,24) then
  for attempt=1,500 do
   local x,y=math.random(32,world.map.width-32),math.random(32,world.map.height-32)
   if require('game.expansion').clearVillage(world,x,y,80) and not world:enemyBlocked(x,y,a) then
    a.x,a.y=x,y;a.spawnX,a.spawnY=x,y;a.roamX,a.roamY=x,y;break
   end
  end
 end end
 -- Clear pasture and fence corridors of resource collision and visual obstructions.
 for i=#world.nodes,1,-1 do local n=world.nodes[i];local remove=F.blocked(world,n.x,n.y)
  for _,p in ipairs(world.pastures) do if F.inside(p,n.x,n.y,-20) then remove=true end end
  for _,r in ipairs(world.paths) do if n.x>r.x-12 and n.x<r.x+r.w+12 and n.y>r.y-12 and n.y<r.y+r.h+12 then remove=true end end
  if remove then table.remove(world.nodes,i) end
 end
end
function F.draw(world,addDrawable)
 if not F.image then F.load() end
 if not F.gateFront then F.gateFront=love.graphics.newImage('assets/large_gate_front.png');F.gateBack=love.graphics.newImage('assets/large_gate_back.png');F.gateFront:setFilter('nearest','nearest');F.gateBack:setFilter('nearest','nearest') end
 if not F.gateAuto then F.gateAuto=love.graphics.newImage('assets/large_gate_autotile.png');F.gateAuto:setFilter('nearest','nearest') end
 local cache=F.ensureCache(world);local gs=cache.gateSet
 local function gh(x,y)return gs[x..':'..y]~=nil end
 if not F.gateAutoH then local iw,ih=F.gateAuto:getDimensions();F.gateAutoH=love.graphics.newQuad(32,0,16,32,iw,ih);F.gateAutoV=love.graphics.newQuad(0,16,16,32,iw,ih) end
 for _,g in ipairs(world.largeGateTiles or {}) do local gate=g;addDrawable(gate.y+24,function()
  local L,R,U,D=gh(gate.x-16,gate.y),gh(gate.x+16,gate.y),gh(gate.x,gate.y-16),gh(gate.x,gate.y+16);love.graphics.setColor(1,1,1)
  if L or R or (not U and not D) then love.graphics.draw(F.gateAuto,F.gateAutoH,gate.x,gate.y-16) end
  if U or D then love.graphics.draw(F.gateAuto,F.gateAutoV,gate.x,gate.y-16) end
 end,gate.x) end
 for _,g in ipairs(world.largeGates or {}) do local gate=g;addDrawable(gate.y+24,function() local rot=(gate.rotation or 0)%4;local im=(rot==2 or rot==3) and F.gateBack or F.gateFront;local iw,ih=im:getDimensions();love.graphics.setColor(1,1,1);love.graphics.draw(im,gate.x,gate.y,rot*math.pi/2,1,1,iw/2,ih/2) end) end
 for _,r in ipairs(world.fenceRails or {}) do local rail=r
  -- Tall-wall rails are collision-only. The wall itself is already rendered from
  -- largeGateTiles above. Drawing these rails with the normal fence sheet overlays
  -- thin fence/post graphics on the tall-wall autotile and visually breaks the wall.
  if not rail.tallWall then
   addDrawable(rail.y+2,function() love.graphics.setColor(1,1,1);love.graphics.draw(F.image,rail.vertical and F.vertical or F.horizontal,rail.x-(rail.vertical and 5 or 0),rail.y-(rail.vertical and 0 or 2)) end,rail.x)
  end
 end
end
return F
