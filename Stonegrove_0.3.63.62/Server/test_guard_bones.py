from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent);s.stopped.set();s.thread.join()
try:
 print(s.eval(r'''
local B=require('game.bone_religion');local C=require('game.cursed_enemies');local I=require('game.inventory');local R=require('game.rune_inventory');local Skills=require('game.skills');local count=0
local function check(v,m)assert(v,m or tostring(count+1));count=count+1 end
local function actor(owner)local inv=I.new();inv.bagSlots={};for i=1,3 do inv.bagSlots[i]={name='Large Leather Bag',qualityGrade='A',slots={}}end;inv:applyStrengthBagBonus(99);return{campOwner=owner,inv=inv,skills=Skills.new(),player={name=owner,x=0,y=0}}end
local a=actor('1:1');local other=actor('2:1');local w={groundItems={},burialGraves={},map={isLand=function()return true end},projectileBlocked=function()return false end,addGroundItem=function(self,n,x,y,_,obj)self.groundItems[#self.groundItems+1]=obj end}
local function find(inv,name)for bi,bag in pairs(inv.bagSlots)do for si,it in pairs(bag.slots)do if not name or it.name==name then return bi,si,it end end end end
for _,kind in ipairs({'rat','wolf','boar','cow','chicken','gigaRat','caveSnake','goblin','nagalian','skeleton','nagaQueen','ghost','slime','slimeBoss'})do
 local e={kind=kind,x=0,y=0,level=30,mainCombat=30,maxHp=100,hp=100,stats={defence=30,range=0}};check(C.apply(e,0));check(e.level==31 and e.stats.defence==31 and e.stats.range==0);check(not C.apply(e,0));check(e.level==31);e.boneOwner='1:1';check(B.drop(w,e));check(not B.drop(w,e));local pile=w.groundItems[#w.groundItems];check(B.cursed(pile.name));local claim=B.claims[pile.boneToken];local total=0;for n,q in pairs(claim.outputs)do check(B.parts[B.base(n)]~=nil);total=total+q end;check(total>=1 and total<=4);C.reset(e);check(e.level==30 and e.maxHp==100 and not e.cursed and not e.boneOwner)
end
local e={kind='nagalian',x=0,y=0,boneOwner='1:1'};check(B.drop(w,e));local pile=w.groundItems[#w.groundItems];check(pile.name=='Cursed Humanoid Bone Pile');check(a.inv:addItemObject(pile));local bi,si=find(a.inv,pile.name);check(B.command(w,a,{op='boneSeparate',bag=bi,slot=si}));check(not B.command(w,a,{op='boneSeparate',bag=bi,slot=si}));local bi,si,it=find(a.inv);check(not B.command(w,a,{op='boneBury',bag=bi,slot=si}));local oldXP=a.skills:get('Religion').xp;check(B.command(w,a,{op='boneBless',bag=bi,slot=si}));check(a.skills:get('Religion').xp>oldXP);check(not B.command(w,a,{op='boneBless',bag=bi,slot=si}));check(not B.command(w,a,{op='boneBury',bag=bi,slot=si}));check(a.inv:add('Pine Logs',1));check(B.command(w,a,{op='boneBury',bag=bi,slot=si}));check(a.inv:countItem('Pine Logs')==0 and #w.burialGraves==1);check(w.burialGraves[1].remaining==60);check(B.command(w,other,{op='boneGraveBless',id=w.burialGraves[1].id}));check(not B.command(w,other,{op='boneGraveBless',id=w.burialGraves[1].id}));check(w.burialGraves[1].remaining==60)
-- Shop purchases remove kill claims, including buying back your own pile.
local e={kind='wolf',x=0,y=0,boneOwner='1:1'};check(B.drop(w,e));local p=w.groundItems[#w.groundItems];local bought=B.purchase(p);check(not bought.boneOwner and not bought.boneToken and bought.bonePurchased);check(a.inv:addItemObject(bought));bi,si=find(a.inv,bought.name);check(B.command(w,a,{op='boneSeparate',bag=bi,slot=si}));for bi,bag in pairs(a.inv.bagSlots)do for si,it in pairs(bag.slots)do if not it.boneOwner then check(not B.command(w,a,{op='boneBury',bag=bi,slot=si}))end end end
-- Ownership cannot be forged by changing the public item owner; counts cannot replay.
local original=R.copy(p);original.boneOwner='2:1';check(other.inv:addItemObject(original));bi,si=find(other.inv);check(not B.command(w,other,{op='boneSeparate',bag=bi,slot=si}));original.boneOwner='1:1';other.inv:getBag(bi).slots[si]=original;check(B.command(w,other,{op='boneSeparate',bag=bi,slot=si}));bi,si=find(other.inv);check(not B.command(w,other,{op='boneBury',bag=bi,slot=si}));check(not B.command(w,other,{op='boneBless',bag=bi,slot=si}))
-- Four graves never activate. Five use average owner level, capped at two times.
w.burialGraves={};for i=1,4 do w.burialGraves[i]={x=i*15,y=0,remaining=60,ownerLevel=50}end;check(B.factor(w,a.player)==1);w.burialGraves[5]={x=0,y=15,remaining=60,ownerLevel=50};check(B.factor(w,a.player)==2);for _,g in ipairs(w.burialGraves)do g.ownerLevel=25 end;check(B.factor(w,a.player)==1.5);w.burialGraves[5].x=81;check(B.factor(w,a.player)==1);w.burialGraves[5].x=0;B.update(w,60);check(#w.burialGraves==0 and B.factor(w,a.player)==1)
-- Ledger save/restore and transaction rollback preserve eligible quantities.
local e={kind='wolf',x=0,y=0,boneOwner='1:1'};B.drop(w,e);local p=w.groundItems[#w.groundItems];local inv=actor('1:1').inv;inv:addItemObject(p);local cp=B.checkpoint(inv);local saved=B.export();B.restore(nil);check(not B.claims[p.boneToken]);B.restore(saved);check(B.claims[p.boneToken].phase=='pile');local t={campOwner='1:1',inv=inv,player=a.player,skills=a.skills};bi,si=find(inv);check(B.command(w,t,{op='boneSeparate',bag=bi,slot=si}));B.rollback(cp);check(B.claims[p.boneToken].phase=='pile');inv.bagSlots[1].slots={[1]=p};check(B.command(w,t,{op='boneSeparate',bag=1,slot=1}));check(not B.command(w,t,{op='boneSeparate',bag=1,slot=1}))
check(require('game.crafting').boneEnhancement.enabled==false);check(#require('game.crafting').boneEnhancement.materials==8)

-- Guard killing blows produce no claim or pile, even after player damage.
local Party=require('game.party');w.addPopup=function()end
for _,kind in ipairs({'wolf','goblin','nagalian','skeleton','slimeBoss'})do for _,cursed in ipairs({false,true})do
 local e={kind=kind,x=0,y=0,hp=1,cursed=cursed,boneOwner='1:1',boneDamage={['1:1']=20}};local n=#w.groundItems;local serial=B.serial
 Party.hit(w,{guard=true,role='Tank'},e,5,'Melee');check(e.dead and e.bonePileDropped);check(#w.groundItems==n and B.serial==serial);check(not B.drop(w,e));check(#w.groundItems==n)
 w.enemies={e};C.world(w,0);check(#w.groundItems==n and B.serial==serial)
 C.reset(e);check(not e.bonePileDropped);e.boneOwner='1:1';check(B.drop(w,e,nil,true));check(#w.groundItems==n+1)
end end
-- Unprocessed player-owned deaths still use the delayed sweep.
local e={kind='wolf',x=0,y=0,dead=true,boneOwner='1:1'};w.enemies={e};local n=#w.groundItems;C.world(w,0);check(#w.groundItems==n+1 and w.groundItems[#w.groundItems].boneOwner=='1:1')

return 'PASS '..count..' cursed enemies, all enemy families, single drops, Nagalian, separation, ownership, purchased/forged bones, logs, blessings, five-grave thresholds, expiry, persistence and ledger rollback checks'
'''),flush=True)
finally:s.close()
