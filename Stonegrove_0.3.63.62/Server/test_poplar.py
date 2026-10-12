from pathlib import Path
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent)
try:
 print(s.eval(r'''
local w=SG_SERVER.world;local S=SG_SERVER.sprites;local K=require('game.skills');local I=require('game.inventory');local sk=K.new();local inv=I.new();inv.bagSlots[1].size=100;local p=require('game.player').new();p.x=100;p.y=100;p.equipped='Copper Axe';local count=0
local function check(v,m)assert(v,m);count=count+1 end
for _,d in ipairs({{'tree',1,'Pine Logs'},{'oak',15,'Oak Logs'},{'poplar',30,'Poplar Logs'}})do
 local info=w:resourceInfo(d[1]);check(info and info.level==d[2]and info.item==d[3],'Correct unlock '..d[1]);local n={kind=d[1],x=100,y=100,hp=1,maxHp=info.hp,snowCovered=true,depleted=false};w.gather=nil
 if d[2]>1 then sk.data.Woodcutting.level=d[2]-1;check(not w:startGather(n,p,sk,inv),'Below unlock denied')end
 sk.data.Woodcutting.level=d[2];sk.data.Woodcutting.xp=sk.xpTable[d[2]];check(w:startGather(n,p,sk,inv),'Unlock accepted');w.gather.hitsLeft=1;local xp=sk.data.Woodcutting.xp;local before=inv:countItem(d[3]);w:updateGather(.8,p,inv,sk);check(inv:countItem(d[3])==before+1,'Correct log award');check(math.abs(sk.data.Woodcutting.xp-xp-info.xp*sk:xpMultiplier('Woodcutting'))<.001,'Correct XP');check(n.depleted and n.stumpSnow and n.respawnTimer==info.respawn,'Snow stump and depletion');w.gather=nil;n.depleted=false;sk.data.Woodcutting.level=99;check(w:startGather(n,p,sk,inv),'Higher levels retain access');w.gather=nil
end
check(S.itemInfo['Poplar Logs']and S.itemImages['Poplar Logs']and S.poplarTreeImage and S.snowPoplarImage,'All uploaded art registered')
local n={kind='poplar',x=100,y=100,hp=12,maxHp=12,depleted=false};p.equipped=nil;inv:removeAllItems('Copper Axe');inv:removeAllItems('Iron Axe');check(not w:startGather(n,p,sk,inv),'Axe required');p.equipped='Iron Axe';check(w:startGather(n,p,sk,inv),'Iron axe accepted');w.gather=nil;p.x=200;check(not w:startGather(n,p,sk,inv),'Range required');p.x=100
local full=I.new();for _,bag in pairs(full.bagSlots)do bag.size=1;bag.slots={{name='Pine Logs',qty=1}}end;check(w:startGather(n,p,sk,full),'Gathering starts normally');local xp=sk.data.Woodcutting.xp;w:updateGather(.8,p,full,sk);check(not w.gather and n.hp==12 and sk.data.Woodcutting.xp==xp,'Full bags stop without consumption or XP')
local L=require('game.level_zones');local map={authored={mapInfo={levelMin=1,levelMax=100}}};local custom={resourceMode='custom',resources={poplar=true}}
check(L.choose(map,0,0,'wood',function()return .1 end,custom,29)==nil,'Poplar tier minimum');check(L.choose(map,0,0,'wood',function()return .1 end,custom,30)=='poplar','Poplar level 30 resource eligibility');check(L.choose(map,0,0,'wood',function()return .1 end,custom,99)=='poplar','No upper spawn cutoff')
check(require('game.fieldcraft').suppressible(n),'Camp suppresses Poplar');local Weather=require('game.weather');Weather.updateCover(n,1,20);check(n.snowCovered,'Snow accumulation');n.depleted=true;Weather.updateCover(n,0,100);check(not n.stumpSnow,'Stump snow melts')
local J=require('game.json');local P=require('game.profile');local R=require('game.regions');w.nodes[#w.nodes+1]=n;n.depleted=false;n.hp=12;n.netId=990100;require('game.node_index').invalidate(w)
local request={id=991,owner=991,slot=1,seq=1,name='Poplar QA',race='Human',worldId=R.doc.worldId,worldFingerprint=R.networkFingerprint,regionId=R.start,area='overworld',initial=true,personal=P.pack({player=p,skills=sk.data,bags=inv.bagSlots,equipment={}})}
local reply=J.decode(SG_CALL('exchange',J.encode(request)));local found;for _,node in ipairs(P.unpack(reply.snapshot).nodes)do if node.netId==990100 then found=node end end;check(found and found.kind=='poplar','Poplar replicated to clients');request.seq=2;request.action={kind='gather',collection='nodes',target=990100};reply=J.decode(SG_CALL('exchange',J.encode(request)));check(reply.result and reply.result.ok,'Authoritative server Poplar gathering')
local oldNodes,oldMap=w.nodes,w.map;w.map={authored={mapInfo={levelMin=1,levelMax=45},levelZones={{x=0,y=0,w=1000,h=1000,level=35,density=1,resourceMode='auto'}}}};w.nodes={};for i=1,6 do w.nodes[i]={kind='tree',x=100+i*20,y=100,hp=6,maxHp=6,resourceLevel=35,depleted=i==6,respawnTimer=i==6 and 111 or 0}end
check(require('game.poplar').restore(w)==2,'Existing server worlds gain Poplar');check(w.nodes[1].kind=='poplar'and w.nodes[1].hp==12,'Migrated intact tree health');check(w.nodes[6].depleted and w.nodes[6].hp==0 and w.nodes[6].respawnTimer==111,'Migration preserves depleted state/timer');check(require('game.poplar').restore(w)==0,'Migration runs once');w.nodes=oldNodes;w.map=oldMap;require('game.node_index').invalidate(w)
return 'PASS '..count..' Woodcutting unlock/gather/log/XP/snow/tool/range/full-bag/resource/server checks'
'''))
finally:s.close()
