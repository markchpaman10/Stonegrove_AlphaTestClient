from pathlib import Path
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent);s.stopped.set();s.thread.join()
try:
 print(s.eval(r'''
local K=require('game.bag_keeper');local I=require('game.inventory');local P=require('game.profile');local G=require('game.gravestones');local n=0;local function check(v,m)assert(v,m or('Bag keeper check '..(n+1)));n=n+1 end
local function actor()local inv=I.new();inv.bagSlots={};return {id=7,slot=1,campOwner='7:1',inv=inv,player={x=126,y=120,hp=10},skills=require('game.skills').new(),fieldcraft={}}end
local function world()return {tradeKeepers={{x=100,y=100,trade='misc'}},groundItems={},gravestones={},map={isLand=function()return true end},playerCamps={}}end
local w=world();local a=actor();check(#K.vendors(w)==1);check(K.at(w,126,120));check(K.eligible(a,{w}));check(K.claim(w,a,{x=126,y=120},{w}));check(a.inv.bagSlots[1].name=='Medium Leather Bag'and a.inv.bagSlots[1].qualityGrade=='D');check(a.inv.bagSlots[1].size==5 and not next(a.inv.bagSlots[1].slots));check(a.inv:bankUsed()==8 and a.inv.bank[7].name=='Copper Longsword');check(not K.claim(w,a,{x=126,y=120},{w}),'No duplicate');check(a.inv.activeBag==1)
for _,name in ipairs({'Small Linen Bag','Medium Leather Bag A','Linen Bag','Large Leather Bag'})do a=actor();a.inv.bank[9]={name=name,qty=1};check(not K.eligible(a,{w}),name)end
a=actor();w.groundItems={{name='Medium Leather Bag',bagOwner='7:1'}};check(not K.eligible(a,{w}));w.groundItems[1].bagOwner='8:1';check(K.eligible(a,{w}));w.groundItems={}
w.gravestones={{owner='7:1',contents={bags={{name='Medium Leather Bag',slots={}}}}}};check(not K.eligible(a,{w}));w.gravestones[1].owner='8:1';check(K.eligible(a,{w}));w.gravestones={}
local remote=world();remote.gravestones={{owner='7:1',contents={bags={{name='Medium Leather Bag'}}}}};check(not K.eligible(a,{w,remote}));w.caveInstances={[1]=remote};check(not K.eligible(a,{w}));w.caveInstances=nil
local saved={caves={{state={gravestones={{owner='7:1',contents={bags={{name='Linen Bag'}}}}}}}}};check(not K.eligible(a,{w,saved}))
remote.gravestones={{owner='7:1',broken=true,x=100,y=100}};remote.groundItems={{name='Medium Leather Bag',x=110,y=110,graveLoot=true}};check(not K.eligible(a,{w,remote}),'Legacy corpse loot inferred');remote.gravestones[1].owner='8:1';check(K.eligible(a,{w,remote}))
w.playerCamps={{owner='7:1',storage={{name='Small Leather Bag'}}}};check(not K.eligible(a,{w}));w.playerCamps[1].owner='8:1';check(K.eligible(a,{w}));w.playerCamps={};a.fieldcraft.recovery={{name='Linen Bag'}};check(not K.eligible(a,{w}));a.fieldcraft.recovery={}
a.player.x=1000;check(not K.claim(w,a,{x=126,y=120},{w}));a.player.x=126;check(not K.claim(w,a,{x=1,y=1},{w}));a.player.hp=0;check(not K.claim(w,a,{x=126,y=120},{w}));a.player.hp=10;a.skills.data.Strength.level=99;check(K.claim(w,a,{x=126,y=120},{w}));check(a.inv.bagSlots[1].size==14)
local packed=P.unpack(P.pack({bags=a.inv.bagSlots,bank=a.inv.bank}));a.inv.bagSlots=packed.bags;a.inv.bank=packed.bank;check(not K.eligible(a,{w}),'Relog prevents duplicate')
a=actor();local g={owner='7:1',contents={bags={{name='Medium Leather Bag',qualityGrade='D',slots={}}}},x=100,y=100};w.gravestones={g};w.addGroundItem=function(self,name,x,y,lit,obj)self.groundItems[#self.groundItems+1]={name=name,x=x,y=y,object=obj}end;G.breakGrave(w,g);check(w.groundItems[1].bagOwner=='7:1');check(not K.eligible(a,{w}));w.groundItems={};check(K.claim(w,a,{x=126,y=120},{w}),'Claim only after old bag gone')
check(#K.vendors({isCave=true})==0)
return 'PASS '..n..' bag keeper eligibility, ownership, graves, regions/caves, bank, starter capacity, proximity and duplicate checks'
'''))
finally:s.close()
