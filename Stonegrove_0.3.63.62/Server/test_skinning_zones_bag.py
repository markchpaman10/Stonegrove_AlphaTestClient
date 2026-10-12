from pathlib import Path
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent)
try:
 print(s.eval(r'''
local G=require('game.zone_geometry');local L=require('game.level_zones');local T=require('game.tailoring_content');local I=require('game.inventory');local K=require('game.skills');local C=require('game.crafting').new();local S=require('game.skinning_fallback');local n=0
local function check(v,m)assert(v,m);n=n+1 end
local function zone(x,y,w,h,level,density,res)return{x=x,y=y,w=w,h=h,level=level or 5,density=density or 1,resourceMode='custom',resources=res or{tree=true},enemies=true}end
local a=zone(0,0,64,32,5,1);local b=zone(32,32,32,64,15,2);local out,selected,merged=G.merge({a,b},2);check(#out==1 and selected==1 and merged==1,'Touching different levels/densities merge')
local z=out[1];check(G.area(z)==4096 and G.weightedArea(z)==6144,'Union area and original density');check(not G.contains(z,0,64)and G.contains(z,48,80),'Concave footprint preserves gaps')
local map={authored={mapInfo={levelMin=1,levelMax=20},levelZones=out}};check(L.at(map,16,16).level==5 and L.at(map,16,16).density==1,'First local settings');check(L.at(map,48,80).level==15 and L.at(map,48,80).density==2,'Second local settings');check(not L.at(map,16,80),'No marker outside union')
check(L.validate({cols=20,rows=20,levelZones=out}),'Merged world validates')
for i=1,1000 do local x,y=G.sample(z,nil,true);check(G.contains(z,x,y),'Sampling inside actual union')end
local q=zone(64,96,32,32,8,0);out=G.merge({z,q});check(#out==1 and G.localSettings(out[1],80,112).density==0,'Corner contact and zero density retained')
check(#G.merge({a,zone(65,0,32,32)})==2,'Gap does not merge');check(#G.merge({a,zone(64,0,32,32,5,1,{oak=true})})==2,'Different resources do not merge')
local overlap=G.union(zone(0,0,64,64,4,1),zone(16,16,16,16,12,3));check(G.area(overlap)==4096 and G.localSettings(overlap,20,20).level==12,'Overlap preserves smaller marker priority without duplicate area')
local old=G.copy(z);z.level=7;G.propagate(z,old);check(G.localSettings(z,16,16).level==7 and G.localSettings(z,48,80).density==2,'Editing level preserves local density')
local cycle=G.copy(out);check(G.contains(cycle[1],80,112),'Deep copy retains shape')
local shape=G.union(zone(256,256,512,256,5,1),zone(512,512,256,512,15,2));local fake={nodes={},villages={},houses={},fenceRails={},map={width=2048,height=2048,cols=128,rows=128,authored={mapInfo={levelMin=1,levelMax=20},levelZones={shape}},isLand=function()return true end},resourceInfo=function()return{hp=2}end,enemyBlocked=function()return false end}
L.populate(fake);check(#fake.nodes>0,'Merged resources actually populate');for _,node in ipairs(fake.nodes)do check(G.contains(shape,node.x,node.y),'Runtime resources never outside irregular footprint');local localZone=L.at(fake.map,node.x,node.y);check(localZone and(node.y<512 and localZone.level==5 or node.y>=512 and localZone.level==15),'Runtime marker resolves original local level')end
-- Existing timed World skinning path, including normal successful skinning.
local world=SG_SERVER.world;local p=require('game.player').new();p.x,p.y=200,200
local function skin(e,sk,inv)local ok=world:skinAnimal(e,p,sk,inv);check(ok,'Starts cast');local job=world.workJob;world.workJob=nil;if job then return job.finish()end;return ok end
for _,kind in ipairs({'cow','boar'})do local inv=I.new();inv:add('Copper Knife',1);local sk=K.new();local e={kind=kind,dead=true,x=200,y=200};local ok=skin(e,sk,inv);check(ok and e.skinned and inv:countItem('Large Meat')==1 and inv:countItem('Torn Hide')==1,'Partial cow/boar exact drops');check(inv:countItem('Large Raw Leather')==0,'No normal hide');local xp=sk.data.Skinning.xp;check(not S.try(world,e,p,sk,inv)and sk.data.Skinning.xp==xp,'Already skinned cannot duplicate')end
for _,v in ipairs({{kind='rat',meat='Small Meat'},{kind='caveSnake',meat='Cave Snake Meat'},{kind='gigaRat',meat='Giga Rat Meat'}})do local e={kind=v.kind,dead=true,x=200,y=200,skinningLevel=12};local sk=K.new();sk.data.Skinning.level=2;local inv=I.new();inv:add('Copper Dagger',1);check(S.try(world,e,p,sk,inv)and inv:countItem(v.meat)==1 and inv:countItem('Torn Hide')==1,'Exact ten-level boundary and matching meat')end
local e={kind='rat',dead=true,x=200,y=200,skinningLevel=12};local sk=K.new();local inv=I.new();inv:add('Copper Knife',1);check(not S.try(world,e,p,sk,inv)and not e.skinned and inv:countItem('Torn Hide')==0,'Eleven-level shortfall rejects')
e={kind='cow',dead=true,x=200,y=200};inv=I.new();inv.bagSlots[1].size=2;inv.bagSlots[1].slots={{name='Copper Knife',qty=1},{name='Bones',qty=1}};check(not S.try(world,e,p,sk,inv)and not e.skinned and inv:countItem('Large Meat')==0 and sk.data.Skinning.xp==0,'Full bag atomic fallback');inv=I.new();inv.bagSlots[1].slots={};check(not S.try(world,e,p,sk,inv),'Knife required');inv:add('Copper Knife',1);e.x=400;check(not S.try(world,e,p,sk,inv),'Reach required')
inv=I.new();inv.bagSlots[1].size=30;inv:add('Copper Knife',1);sk=K.new();sk.data.Skinning.level=9;sk.data.Skinning.xp=sk.xpTable[9];e={kind='cow',dead=true,x=200,y=200};check(skin(e,sk,inv)and inv:countItem('Large Raw Leather')==1 and inv:countItem('Large Meat')==1,'Normal eligible skin unchanged')
local recipe,index;for i,r in ipairs(C:getRecipes('tailoring'))do if r.output=='Linen Bag'then index,recipe=i,r end end;check(recipe.level==50,'Linen Bag Tailoring 50');inv=I.new();inv.bagSlots[1].size=30;inv:add('Needle',1);inv:add('Wool Thread',5);inv:add('Red Cloth Strip',2);inv:add('Dark Blue Cloth',3);sk=K.new();sk.data.Tailoring.level=49;sk.data.Tailoring.xp=sk.xpTable[49];check(not C:craft('tailoring',index,inv,sk)and inv:countItem('Wool Thread')==5,'Level49 rejects without consumption');sk.data.Tailoring.level=50;sk.data.Tailoring.xp=sk.xpTable[50];check(C:craft('tailoring',index,inv,sk)and inv:countItem('Linen Bag')==1 and inv:countItem('Wool Thread')==0 and T.count(inv,'Any Cloth Strip')==0,'Level50 mixed colour bag exact inputs')
return 'PASS '..n..' skinning fallback, merged-zone geometry/local settings and Linen Bag checks'
'''))
finally:s.close()
