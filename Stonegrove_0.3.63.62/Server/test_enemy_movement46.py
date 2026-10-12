from pathlib import Path
import sys
r=Path(__file__).resolve().parent.parent;sys.path.insert(0,str(r/'Server'));from simulation import Simulation
s=Simulation(r);s.stopped.set();s.thread.join()
try:
 print(s.eval(r'''
local w=SG_SERVER.world;local Items=require('game.items');local P=require('game.player');local sk=require('game.skills').new();local inv=require('game.inventory').new();local p=P.new();local original
for _,e in ipairs(w.enemies)do if e.kind=='rat'then original=e;break end end;assert(original)
local x,y;for yy=160,w.map.height-160,160 do for xx=160,w.map.width-600,160 do if not x and w.map:isLand(xx,yy)and w.map:isLand(xx+360,yy)then local good=true;for dx=0,360,8 do if w:projectileBlocked(xx+dx,yy)then good=false end end;if good then x,y=xx,yy end end end end;assert(x)
sk.data.Health.xp=sk.xpTable[99];sk.data.Health.level=99;p.x,p.y=x,y;p.hp=10000;p.maxHp=10000;w.enemies={};w.guards={};w.mercs={};w.onlineActors={{id=1,slot=1,campOwner='1:1',player=p,skills=sk,inv=inv,equipment={}}};w.playerRef=p
for i=1,3 do local e=Items.copy(original);e.x,e.y=x+(i==3 and 120 or 250+i*40),y;e.spawnX,e.spawnY=e.x,e.y;e.dead=false;e.inactive=false;e.dayOnly=nil;e.nightOnly=nil;e.curseRolled=true;e.aggro=i==3;e.state=i==3 and'chase'or'roam';e.roamTimer=1000;e.roamX,e.roamY=100000,100000;e.attackTimer=0;e.netId=i;w.enemies[i]=e end
local start=w.enemies[3].x;local damage=p.damageSerial or 0
for i=1,240 do w:update(.05,p,inv,sk);w:updateCombat(.05,p,sk,{},SG_SERVER.sprites,nil,{},inv)end
assert(w.enemies[3].x<start-50,'Live chase frozen');assert((p.damageSerial or 0)>damage,'Live enemy failed to attack')
return 'PASS actual shared-world chase and enemy attacks with two blocked routes ahead in the AI queue'
'''))
finally:s.close()
