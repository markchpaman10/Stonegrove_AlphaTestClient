from pathlib import Path
import sys,time
root=Path(__file__).resolve().parent.parent;sys.path.insert(0,str(root/'Server'));from simulation import Simulation
s=Simulation(root);s.stopped.set();s.thread.join()
try:
 print(s.eval(r'''
local w=SG_SERVER.world;local now=100000;os.time=function()return now end
w.groundItems={};w:addGroundItem('Copper Pickaxe',100,100,false,{name='Copper Pickaxe',qualityGrade='A'});assert(w.groundItems[1].expiresAt==100300)
local G=require('game.gravestones');local obj={name='Small Linen Bag',qualityGrade='A',slots={{name='Carved Feather',qty=10,qualityGrade='B'}}}
local grave={x=100,y=100,owner='1:1',contents={bags={obj},equipment={},equipmentItems={}}};w.gravestones={};G.breakGrave(w,grave)
for _,item in ipairs(w.groundItems)do assert(item.expiresAt==100300)end
w.groundItems[#w.groundItems+1]={name='Charred Wood',x=100,y=100,expiresAt=100300,object={name='Charred Wood',qualityGrade='B'}}
local data=require('game.fire_fuel').export(w);assert(data.charred[1].expiresAt==100300)
now=100299;SG_CALL('tick','{"time":1,"dt":0.05}');assert(#w.groundItems>0)
local packed=require('game.json').decode(SG_CALL('export','{}'));local exported=require('game.profile').unpack(packed);local kept
for _,room in pairs(exported.rooms)do if room.groundItems and #room.groundItems>0 then kept=true;for _,i in ipairs(room.groundItems)do assert(i.expiresAt==100300)end end end;assert(kept)
now=100300;SG_CALL('tick','{"time":2,"dt":0.05}');assert(#w.groundItems==0,'Empty room did not expire')
SG_CALL('restore',require('game.json').encode(packed));assert(#w.groundItems==0,'Restart revived expired items')
require('game.fire_fuel').restore(w,data);assert(#w.groundItems==0,'Offline fire restore reset deadline')
return 'PASS world drop and grave scatter deadlines, empty-server-area expiry, saved deadlines, restart expiry, offline bonfire ground-loot restore'
'''))
finally:s.close()
