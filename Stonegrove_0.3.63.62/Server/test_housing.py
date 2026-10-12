from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent);s.stopped.set();s.thread.join()
try:
 print(s.eval(r'''
local H=require('game.modular_houses');local C=require('game.click_actions');local Player=require('game.player');local W=require('game.world');local count=0
local function check(v,m)assert(v,m or tostring(count+1));count=count+1 end
local w=SG_SERVER.world;w.map.isLand=function()return true end;w.nodes={};w._nodeIndexEnabled=false;w.enemies={};w.tradeKeepers={};w.traders={};w.healers={};w.fenceRails={};w.playerCamps={};w.villages={};w.questNPCs={};w.groundItems={};w.sheep={};w.popups={}
for _,k in ipairs({'bankChest','bankClerk','mercRecruiter','smelter','anvil','tanningVat','hideStretcher','spinningWheel','alchemy','stove'})do w[k]={x=0,y=0}end
local p=Player.new();local u={world=w,player=p,logger=nil};local positions={}
for i=1,120 do local h=H.place({id='modularHouse',x=500,y=500},love.math.newRandomGenerator(i));positions[h.houseDoorPosition]=true;local saved=require('game.rune_inventory').copy(h);H.configure(h);check(h.houseDoorPosition==saved.houseDoorPosition and h.houseRoof==saved.houseRoof)end
check(positions[1]and positions[2]and positions[3],'Placement does not randomize door positions')
local trips=0
for offset=0,15 do for pos=1,3 do for floors=1,2 do
 local h=H.configure({id='modularHouse',x=500+offset,y=500+offset,houseDoorPosition=pos,houseFloors=floors});w.houses={h};local dx,dy=H.door(h)
 check(H.doorAt(h,dx,dy));check(not H.doorAt(h,dx+20,dy));for y=h.y-20,h.y+35 do check(not H.blocked(h,dx,y,5));check(not w:playerBlocked(dx,y-5))end
 for _,side in ipairs({-1,0,1})do
  p.x,p.y=h.x+side*90,h.y+90;C.start(u,dx,dy,function()error('Door travel dispatched a different interaction')end);check(C.pending and C.pending.kind=='house')
  for frame=1,600 do if not C.pending then break end;local vx,vy=C.direction(u,.02,0,0);local ox,oy=p.x,p.y;p:update(.02,vx,vy,dx,dy);w:resolvePlayerMovement(p,ox,oy)end
  check(not C.pending,'Mouse route stalled');check(H.inside(h,p.x,p.y+4),'Mouse route failed to enter randomized door');check(math.abs(p.x-dx)<4 and math.abs(p.y-(h.y-9))<4);check(H.lightBounds(w,p)~=nil);trips=trips+1
 end
 p.x,p.y=h.x,h.y+90;check(H.lightBounds(w,p)==nil);C.start(u,dx,dy,function()end);C.direction(u,.02,1,0);check(not C.pending,'Keyboard cannot cancel door travel')
end end end
local legacy={x=0,y=0};require('game.houses').generate({legacy},123);local l,t,b,d=require('game.houses').bounds(legacy);check(b==53 and d==16 and t==2)
return 'PASS '..count..' housing checks, including '..trips..' complete mouse-only entry routes across every door position, one/two floors and all 16 grid offsets, movement cancellation, lighting boundaries, stable appearance and legacy footprint'
'''),flush=True)
finally:s.close()
