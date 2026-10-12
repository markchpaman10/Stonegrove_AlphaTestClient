"""Authoritative level/resource-zone rules and full world generation."""
from pathlib import Path
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent)
try:
 print(s.eval(r"""
local L=require('game.level_zones');local count=0;local function check(v,m)assert(v,m);count=count+1 end
local map={width=2000,height=1500,authored={mapInfo={levelMin=1,levelMax=20},levelZones={{name='Low',x=0,y=0,w=1000,h=1500,level=2,density=1},{name='High',x=1000,y=0,w=1000,h=1500,level=18,density=1}}}}
local rng=love.math.newRandomGenerator(77891);local rand=function(a,b)return rng:random(a,b)end
-- headless RNG needs the arity-preserving wrapper below.
rand=function(a,b)if a==nil then return rng:random()elseif b==nil then return rng:random(a)else return rng:random(a,b)end end
local low,high,li,hi,coal=0,0,0,0,0
for n=1,10000 do local a=L.level(map,100,100,rand);local b=L.level(map,1100,100,rand);check(a>=1 and a<=20 and b>=1 and b<=20,'Bounded local levels');low=low+a;high=high+b
 local k=L.choose(map,100,100,'ore',rand,nil,a);if k=='iron'then li=li+1 end;local k=L.choose(map,1100,100,'ore',rand,nil,b);if k=='iron'then hi=hi+1 elseif k=='coal'then coal=coal+1 end
end
check(low/10000<5 and high/10000>15,'Target bias');check(hi>li*6,'Higher target favors iron');check(coal==0,'Map range excludes coal27')
local zone=map.authored.levelZones[2];zone.resourceMode='custom';zone.resources={oak=true};check(L.choose(map,1100,100,nil,rand,zone,18)=='oak','Explicit resource choice');check(L.choose(map,1100,100,nil,rand,zone,1)==nil,'Choice still obeys existing requirement')
zone.resources={coal=true};check(L.choose(map,1100,100,nil,rand,zone,20)==nil,'Custom selection cannot bypass level cap');zone.resourceMode='auto'
map.authored.levelZones[#map.authored.levelZones+1]={x=1100,y=100,w=100,h=100,level=5,density=1};check(L.at(map,1150,150).level==5,'Smaller overlapping zone wins');check(L.at(map,1200,200).level==18,'Half-open rectangle bounds');L.invalidate(map)
local lo,up=L.encounterRange(map,1050,10);check(lo==15 and up==20,'Cave/camp entrance band');check(L.spawnLevel(map,{level=3,useZoneLevel=false},1050,10,rand)==3,'Fixed spawn retained')
zone.enemies=false;check(L.spawnLevel(map,{level=3},1050,10,rand)==3,'Zone can disable inheritance');zone.enemies=true
map.authored.mapInfo.levelMax=10;check(L.target(map,zone)==10,'Target clamps when map range shrinks');map.authored.mapInfo.levelMax=20
local valid={cols=125,rows=100,levelZones=map.authored.levelZones};check(L.validate(valid),'Valid zone document');local invalid={cols=125,rows=100,levelZones={{x=0,y=0,w=5000,h=100,level=1}}};check(not L.validate(invalid),'Reject out-of-map rectangle');invalid.levelZones[1].w=100;invalid.levelZones[1].resources={nonexistent=true};check(not L.validate(invalid),'Reject nonexistent resources')
local w=SG_SERVER.world;local function clone(t)if type(t)~='table'then return t end;local out={};for k,v in pairs(t)do out[k]=clone(v)end;return out end
local data=clone(w.map.authored);data.mapInfo={levelMin=1,levelMax=20,connections={}};local points={}
for y=600,w.map.height-600,700 do for x=600,w.map.width-600,700 do
 if #points<2 then local good=true;for _,o in ipairs({{-300,-300},{300,-300},{-300,300},{300,300},{0,0}})do if not require('game.naga_queen').allowed(w,x+o[1],y+o[2],80)then good=false end end;if good then points[#points+1]={x=x,y=y}end end
end end;check(#points==2,'Find two real safe wilderness zones')
data.levelZones={};data.spawnZones={}
for i,p in ipairs(points)do data.levelZones[i]={name='QA '..i,x=p.x-300,y=p.y-300,w=600,h=600,level=i==1 and 2 or 18,density=1,resourceMode=i==1 and'auto'or'custom',resources={iron=true},enemies=true};data.spawnZones[i]={x=p.x-200,y=p.y-200,w=400,h=400,enemy='wolf',level=1,count=5}end
-- Disable automatic boss in the isolated QA world without changing production data.
data.spawnZones[3]={x=0,y=0,w=16,h=16,enemy='nagaQueen',level=12,count=1}
local p=points[2];data.spawnZones[4]={x=p.x-250,y=p.y-250,w=500,h=500,enemy='slimeBoss',level=18,levelMode='local',count=1};data.spawnZones[5]={x=p.x-250,y=p.y-250,w=500,h=500,enemy='gigaRat',level=15,useZoneLevel=false,count=1}
local generated=require('game.world').new(SG_SERVER.sprites,data);local lowEnemies,highEnemies,iron=0,0,0
for _,e in ipairs(generated.enemies)do if e.editorSpawnZone==1 then lowEnemies=lowEnemies+e.level;check(e.level>=1 and e.level<=20,'Low monster bounded')elseif e.editorSpawnZone==2 then highEnemies=highEnemies+e.level;check(e.level>=1 and e.level<=20,'High monster bounded')end end
check(highEnemies>lowEnemies,'Real authored monster zones inherit local target');local slimeBoss,gigaRat;for _,e in ipairs(generated.enemies)do if e.editorSpawnZone==4 then slimeBoss=e elseif e.editorSpawnZone==5 then gigaRat=e end end;check(slimeBoss and slimeBoss.kind=='slimeBoss'and slimeBoss.level>=1 and slimeBoss.level<=20,'Real Slime Boss spawn and local level');check(gigaRat and gigaRat.kind=='gigaRat'and gigaRat.level==15,'Real Giga Rat fixed spawn')
for _,n in ipairs(generated.nodes)do local z,i=L.at(generated.map,n.x,n.y);check(i~=nil,'No resources outside configured zones');if i then check(not require('game.authored_world').protected(generated,n.x,n.y,0),'Resource respects authored exclusions');if i==2 then check(n.kind=='iron','Only configured iron in high zone');iron=iron+1 end end end
check(iron>0,'Full world generates higher-tier iron');local p=points[2]
local farm={map=generated.map,nodes={{kind='tree',x=p.x,y=p.y,hp=6,maxHp=6}},paths=generated.paths,villages=generated.villages,resourceInfo=generated.resourceInfo,enemyBlocked=function()return false end};data.levelZones[2].density=0;L.invalidate(generated.map);L.populate(farm);local highCount=0;for _,n in ipairs(farm.nodes)do local z,i=L.at(farm.map,n.x,n.y);if i==2 then highCount=highCount+1 end end;check(highCount==0,'Zero density empties selected zone')
-- 3x density produces additional nodes with bounded generation attempts.
data.levelZones[1].density=0;data.levelZones[2].density=3;data.levelZones[2].resourceMode='custom';data.levelZones[2].resources={iron=true};farm.nodes={};L.populate(farm);check(#farm.nodes>100,'Density increases valid resource count');check(#farm.nodes<=270,'Density generation bounded')
local denser=require('game.world').new(SG_SERVER.sprites,data);local denserIron=0;for _,n in ipairs(denser.nodes)do local marker,index=L.at(denser.map,n.x,n.y);if index==2 then check(n.kind=='iron','Dense zone only configured resource');denserIron=denserIron+1 end end;check(denserIron>iron,'Higher density increases full-world iron population')
return tostring(count)..' level zone checks passed; high/low averages '..string.format('%.2f/%.2f',high/10000,low/10000)..'; generated iron '..iron..', density3 '..denserIron
"""))
finally:s.close()
