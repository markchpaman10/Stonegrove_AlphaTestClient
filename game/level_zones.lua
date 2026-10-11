-- Shared editor/runtime rules. Level zones are metadata, never collision objects.
local L={};local G=require('game.zone_geometry');L.contains=G.contains;L.area=G.area
L.resources={
 {kind='tree',name='Pine trees',level=1,family='wood',weight=1},
 {kind='oak',name='Oak trees',level=15,family='wood',weight=4},
 {kind='poplar',name='Poplar trees',level=30,family='wood',weight=6},
 {kind='copper',name='Copper',level=1,family='ore',weight=1},
 {kind='tin',name='Tin',level=1,family='ore',weight=.6},
 {kind='iron',name='Iron',level=15,family='ore',weight=4},
 {kind='coal',name='Coal',level=27,family='ore',weight=5},
 {kind='hemp',name='Hemp',level=1,family='fiber',weight=2},
 {kind='flax',name='Flax',level=1,family='fiber',weight=1},
 {kind='blueMushroom',name='Blue mushroom',level=1,family='forage',weight=1},
 {kind='brownMushroom',name='Brown mushroom',level=1,family='forage',weight=2},
 {kind='berryBush',name='Berry bushes',level=1,family='forage',weight=2},
 {kind='bushGreens',name='Bush greens',level=1,family='forage',weight=1},
}
local catalog={};for _,d in ipairs(L.resources)do catalog[d.kind]=d end
local cache=setmetatable({},{__mode='k'})
local function bounded(v,lo,hi)local n=tonumber(v);if not n or n~=n then n=lo end;return math.max(lo,math.min(hi,n))end
function L.range(map)
 local info=map and map.authored and map.authored.mapInfo
 if info then local lo=math.floor(bounded(info.levelMin,1,100));return lo,math.floor(bounded(info.levelMax,lo,100))end
 return require('game.regions').areaLevel(map)
end
function L.invalidate(map)cache[map]=nil end
function L.at(map,x,y)
 local zones=map and map.authored and map.authored.levelZones;if not zones or #zones==0 then return end
 local c=cache[map]
 if not c or c.list~=zones or c.count~=#zones then
  c={list=zones,count=#zones,buckets={}};cache[map]=c
  for i,z in ipairs(zones)do
   if type(z.x)=='number'and type(z.y)=='number'and type(z.w)=='number'and type(z.h)=='number'and z.w>0 and z.h>0 then
    for by=math.floor(z.y/512),math.floor((z.y+z.h)/512)do for bx=math.floor(z.x/512),math.floor((z.x+z.w)/512)do local key=bx..':'..by;local a=c.buckets[key]or{};c.buckets[key]=a;a[#a+1]=i end end
   end
  end
 end
 local best,index,area
 for _,i in ipairs(c.buckets[math.floor(x/512)..':'..math.floor(y/512)]or{})do local z=zones[i]
  if G.contains(z,x,y)and(not area or G.priorityAt(z,x,y)<=area)then best,index,area=G.localSettings(z,x,y),i,G.priorityAt(z,x,y)end
 end
 return best,index
end
function L.target(map,z)local lo,hi=L.range(map);return math.floor(bounded(z and z.level or (lo+hi)/2,lo,hi))end
function L.level(map,x,y,rng)
 rng=rng or math.random;local lo,hi=L.range(map);local z,i=L.at(map,x,y)
 if not z then return rng(lo,hi),nil end
 -- 85% of rolls favor +/-3 around the marker; 15% retain map-wide variety.
 if rng()<.15 then return rng(lo,hi),i end
 local center=L.target(map,z);local sum=0;local weights={}
 for lv=math.max(lo,center-3),math.min(hi,center+3)do local weight=4-math.abs(lv-center);sum=sum+weight;weights[#weights+1]={lv,sum}end
 local pick=rng()*sum;for _,v in ipairs(weights)do if pick<v[2]then return v[1],i end end;return center,i
end
function L.choose(map,x,y,family,rng,z,level)
 rng=rng or math.random;z=z or L.at(map,x,y);level=level or L.level(map,x,y,rng);local allowed={};local total=0
 for _,d in ipairs(L.resources)do
  if d.level<=level and(not family or family==d.family)and(not z or z.resourceMode~='custom'or(z.resources or{})[d.kind]==true)then
   total=total+d.weight;allowed[#allowed+1]={d.kind,total}
  end
 end
 if total==0 then return nil end;local roll=rng()*total;for _,v in ipairs(allowed)do if roll<v[2]then return v[1]end end;return allowed[#allowed][1]
end
function L.encounterRange(map,x,y)local lo,hi=L.range(map);local z=L.at(map,x,y);if z and z.enemies~=false then local center=L.target(map,z);return math.max(lo,center-3),math.min(hi,center+3)end;return lo,hi end
function L.spawnLevel(map,z,x,y,rng)
 if z.levelMode=='local'then local lo,hi=L.range(map);local marker={x=z.x,y=z.y,w=z.w,h=z.h,level=bounded(z.level or lo,lo,hi)};return L.level({authored={mapInfo={levelMin=lo,levelMax=hi},levelZones={marker}}},x,y,rng)end
 local marker=L.at(map,x,y)
 if marker and marker.enemies~=false and z.useZoneLevel~=false then return L.level(map,x,y,rng)end
 local lo,hi=L.range(map)
 -- Explicit legacy spawn levels stay unchanged unless they opt into a marker.
 return math.floor(bounded(z.level or L.level(map,x,y,rng),1,100))
end
function L.validate(data)
 if type(data)~='table'or type(data.cols)~='number'or type(data.rows)~='number'or data.cols<=0 or data.rows<=0 then return false,'Invalid map size.'end
 local zones=data.levelZones or{};if type(zones)~='table'or #zones>256 then return false,'Maximum 256 level zones per map.'end
 local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
 for _,z in ipairs(zones)do
  if type(z)~='table'or not finite(z.x)or not finite(z.y)or not finite(z.w)or not finite(z.h)or z.x<0 or z.y<0 or z.w<16 or z.h<16 or z.x+z.w>data.cols*16 or z.y+z.h>data.rows*16 then return false,'Level zone must fit inside its map.'end
  if not finite(z.level)or z.level<1 or z.level>100 or not finite(z.density or 1)or(z.density or 1)<0 or(z.density or 1)>3 then return false,'Invalid level zone level/density.'end
  if z.resourceMode and z.resourceMode~='auto'and z.resourceMode~='custom'then return false,'Invalid resource mode.'end
  if z.resources then if type(z.resources)~='table'then return false,'Invalid resource list.'end;for kind,v in pairs(z.resources)do if not catalog[kind]or type(v)~='boolean'then return false,'Invalid resource selection.'end end end
  if z.rects then
   if type(z.rects)~='table'or #z.rects==0 or #z.rects>4096 then return false,'Invalid merged zone shape.'end
   for _,r in ipairs(z.rects)do if type(r)~='table'or not finite(r.x)or not finite(r.y)or not finite(r.w)or not finite(r.h)or r.x<z.x or r.y<z.y or r.w<16 or r.h<16 or r.x+r.w>z.x+z.w or r.y+r.h>z.y+z.h then return false,'Invalid merged zone bounds.'end
    if r.settings then if type(r.settings)~='table'or r.settings.rects then return false,'Invalid local zone settings.'end;local localZone=G.copy(r.settings);localZone.x,localZone.y,localZone.w,localZone.h=r.x,r.y,r.w,r.h;local ok,why=L.validate({cols=data.cols,rows=data.rows,levelZones={localZone}});if not ok then return false,why end end
    if r.priority and(not finite(r.priority)or r.priority<=0)then return false,'Invalid zone priority.'end
   end
  end
  if z.name~=nil and(type(z.name)~='string'or #z.name>80)then return false,'Invalid level zone name.'end
  if z.enemies~=nil and type(z.enemies)~='boolean'then return false,'Invalid enemy inheritance.'end
 end
 return true
end
-- Run once during authoritative world construction, before normal overlap cleanup.
function L.populate(w)
 if w.isCave then return end
 local markers=(w.map.authored or{}).levelZones or{};local kept={};local counts={}
 local function create(kind,x,y,level,index)
  if not kind then return end;local d=w:resourceInfo(kind);local n={kind=kind,x=x,y=y,hp=d and d.hp or 1,maxHp=d and d.hp or 1,depleted=false,respawnTimer=0,shake=0,resourceLevel=level,levelZone=index,zone=(index or 0)+1}
  if kind=='berryBush'then local qty=math.random(1,5);n.berryType=({'Red Berries','Purple Berries','Black Berries'})[math.random(1,3)];n.stage='berries';n.berryCount=qty;n.hp=qty;n.maxHp=qty end
  return n
 end
 for _,n in ipairs(w.nodes)do
  local z,i=L.at(w.map,n.x,n.y);local def=catalog[n.kind]
  if def and not n.questSpawnKey and not n.authored then
   local lv=L.level(w.map,n.x,n.y);local density=z and bounded(z.density or 1,0,3)or 1
   if z and density>0 and math.random()<math.min(1,density)then
    local kind=L.choose(w.map,n.x,n.y,def.family,nil,z,lv)or L.choose(w.map,n.x,n.y,nil,nil,z,lv)
    local replacement;if kind==n.kind then replacement=n;n.resourceLevel=lv;n.levelZone=i;n.zone=(i or 0)+1 else replacement=create(kind,n.x,n.y,lv,i)end;if replacement then kept[#kept+1]=replacement;if i then counts[i]=(counts[i]or 0)+1 end end
   end
  elseif z or n.questSpawnKey or n.authored then kept[#kept+1]=n end
 end
 w.nodes=kept;require('game.node_index').invalidate(w)
 -- Keep the existing node index stable while adding density. Rebuilding its
 -- entire 20,000-node cache after each insert would turn this into O(n^2).
 local additions,grid={},{}
 local function extraClear(x,y)
  local bx,by=math.floor(x/32),math.floor(y/32)
  for dy=-1,1 do for dx=-1,1 do for _,n in ipairs(grid[(bx+dx)..':'..(by+dy)]or{})do if(n.x-x)^2+(n.y-y)^2<32^2 then return false end end end end;return true
 end
 for i,z in ipairs(markers)do
  local density=bounded(z.density or 1,0,3);local wanted=z.rects and math.floor(math.max(counts[i]or 0,G.weightedArea(z)*.00025))or math.floor(math.max(counts[i]or 0,G.area(z)*.00025)*density);local need=math.min(2500,math.max(0,wanted-(counts[i]or 0)))
  for attempt=1,math.min(20000,need*12)do if need<=0 then break end
   local x,y=G.sample(z,nil,z.rects~=nil);local owner,index=L.at(w.map,x,y)
   if index==i and x>80 and y>80 and x<w.map.width-80 and y<w.map.height-80 and w.map:isLand(x,y)and not require('game.authored_world').protected(w,x,y,18)and require('game.expansion').clearVillage(w,x,y,65)and extraClear(x,y)and not w:enemyBlocked(x,y)then
    local lv=L.level(w.map,x,y);local kind=L.choose(w.map,x,y,nil,nil,z,lv);local n=create(kind,x,y,lv,i)
    if n then additions[#additions+1]=n;local key=math.floor(x/32)..':'..math.floor(y/32);local bucket=grid[key]or{};grid[key]=bucket;bucket[#bucket+1]=n;need=need-1 end
   end
  end
 end
 for _,n in ipairs(additions)do w.nodes[#w.nodes+1]=n end
 require('game.node_index').invalidate(w)
end
return L
