from pathlib import Path
from simulation import Simulation
root=Path(__file__).resolve().parent.parent
source=(root/'LevelEditor/main.lua').read_text(encoding='utf-8')
assert "{id='bagKeeper',name='Bag Keeper'}" in source
assert "elseif o.id=='bagKeeper' then" in source
s=Simulation(root);s.stopped.set();s.thread.join()
try:
 print(s.eval(r'''
local w=SG_SERVER.world;local K=require('game.bag_keeper');local A=require('game.authored_world');local I=require('game.inventory');local P=require('game.profile');local n=0;local function check(v,m)assert(v,m);n=n+1 end
local doc={objects={{id='bagKeeper',x=640,y=656},{id='trader',x=720,y=720}}};w.map.authored=doc;A.finish(w,doc,function()error('No enemy expected')end);check(#w.bagKeepers==1,'Authored bag NPC');check(w.bagKeepers[1].x==640 and w.bagKeepers[1].y==656,'Exact editor coordinates');check(#K.vendors(w)==1,'No automatic duplicate');check(K.at(w,640,656),'Clickable placed vendor');check(not K.at(w,746,740),'Automatic vendor replaced')
local actors=require('game.npc_bindings').apply(w);check(require('game.npc_bindings').ids.bagKeeper,'Inspector appearance supported');check(w.bagKeepers[1].linkKey:find('bagKeeper',1,true),'Appearance binding links placed NPC')
local inv=I.new();inv.bagSlots={};local a={inv=inv,player={x=640,y=656,hp=10},skills=require('game.skills').new(),id=3,slot=1};check(K.claim(w,a,{x=640,y=656},{w}),'Placed NPC grants starter');check(not K.claim(w,a,{x=640,y=656},{w}),'No duplicate');check(inv:bankUsed()==8,'Starter bank preserved')
local saved=require('game.json').decode(require('game.json').encode(P.pack(doc)));saved=P.unpack(saved);w.map.authored=saved;A.finish(w,saved,function()end);check(K.at(w,640,656),'World document round trip');check(#K.vendors(w)==1,'Round trip no duplicate');w.bagKeepers[1].eventHidden=true;check(#K.vendors(w)==0,'Hidden NPC stays hidden');w.bagKeepers={};check(#K.vendors(w)==1,'Legacy automatic fallback');w.isCave=true;check(#K.vendors(w)==0,'Cave isolation')
return 'PASS '..n..' authored Bag Keeper placement, appearance, claim, document round trip and legacy fallback checks'
'''))
finally:s.close()
