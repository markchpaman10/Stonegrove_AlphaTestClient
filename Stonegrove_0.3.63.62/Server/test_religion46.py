from pathlib import Path
import sys
r=Path(__file__).resolve().parent.parent;sys.path.insert(0,str(r/'Server'));from simulation import Simulation
s=Simulation(r);s.stopped.set();s.thread.join()
try:
 print(s.eval(r'''
local I=require('game.inventory');local R=require('game.religion');local Q=require('game.quality');local Sk=require('game.skills');local Items=require('game.items');local B=require('game.bone_religion');local count=0
local function ck(v,m)assert(v,m or tostring(count+1));count=count+1 end
local function actor(level)
 local sk=Sk.new();sk:setRace('Human');sk.data.Religion.level=level;sk.data.Religion.xp=sk.xpTable[level]
 local inv=I.new();inv.bagSlots={{name='Large Leather Bag',qualityGrade='A',slots={}}};inv:applyStrengthBagBonus(99)
 return {inv=inv,skills=sk,player={x=0,y=0,name='QA'},world={addPopup=function()end},sprites={itemInfo={}}}
end
local names={['Charred Wood']=1,['Fish Bones']=2,['Stone Gravel']=3,['Carved Feather']=4,['Carved Onyx']=5,['Green Slime Tube']=6}
for name,lv in pairs(names)do
 ck(R.requiredLevel(name)==lv);for n=1,6 do ck(R.canBless(actor(n).skills,name)==(n>=lv))end
 local a=actor(6);a.inv:addItemObject({name=name,qty=100,qualityGrade='A'});local old=a.skills.data.Religion.xp;local ok,units,xp=R.blessInventory(a,false);ck(ok and units==100);ck(math.abs(xp-R.blessXP[name]*100*1.1)<.001);ck(a.skills.data.Religion.xp==old+xp);ck(not R.blessInventory(a,false))
 a=actor(6);a.inv:add(name,100);local _,u,x=R.blessInventory(a,true);ck(u==100 and math.abs(x-R.blessXP[name]*200*1.1)<.001)
 if lv>1 then a=actor(lv-1);a.inv:add(name,1);old=a.skills.data.Religion.xp;ck(not R.blessInventory(a,false));ck(a.skills.data.Religion.xp==old and not a.inv.bagSlots[1].slots[1].blessed)end
end
ck(R.requiredLevel('Stone Pieces')==3)
local oldRoll=Q.roll;Q.roll=function()return'A'end;local a=actor(6);a.inv:add('Feather',10);for i=1,10 do ck(R.carveFeather(a.inv,a.skills))end;ck(a.inv:countItem('Feather')==0 and a.inv:countItem('Carved Feather')==10);local slots=0;for _,v in pairs(a.inv.bagSlots[1].slots)do slots=slots+1;ck(v.qty==10 and v.qualityGrade=='A')end;ck(slots==1);Q.roll=oldRoll
for _,g in ipairs({'D','C','B','A'})do
 local inv=actor(6).inv;ck(inv:addItemObject({name='Carved Feather',qty=2,qualityGrade=g}));ck(inv:addItemObject({name='Carved Feather',qty=3,qualityGrade=g,blessed=false,sockets={}}));ck(inv.bagSlots[1].slots[1].qty==5)
 ck(inv:addItemObject({name='Carved Feather',qty=1,qualityGrade=g,blessed=true}));ck(inv.bagSlots[1].slots[2].qty==1)
 ck(inv:depositSlot(1,1));ck(inv:withdrawBankSlotAmount(9,5)or inv:withdrawBankSlotAmount(1,5));ck(inv:countItem('Carved Feather')==6)
end
ck(not Items.sameMetadata({name='Carved Feather',qualityGrade='A'},{name='Carved Feather',qualityGrade='B'}));ck(not Items.sameMetadata({name='Carved Feather',qualityGrade='A',customMark='one'},{name='Carved Feather',qualityGrade='A',customMark='two'}))

local a=actor(6);a.inv.bagSlots[1].size=3;a.inv.bagSlots[1].slots={{name='Feather',qty=10},{name='Copper Axe',qty=1},{name='Copper Pickaxe',qty=1}};local xp=a.skills.data.Religion.xp;ck(not R.carveFeather(a.inv,a.skills));ck(a.inv:countItem('Feather')==10 and a.skills.data.Religion.xp==xp)
local roll=Q.roll;Q.roll=function()return'A'end;a.inv.bagSlots[1].slots[2]={name='Carved Feather',qty=99,qualityGrade='A'};ck(R.carveFeather(a.inv,a.skills));ck(a.inv:countItem('Feather')==9 and a.inv:countItem('Carved Feather')==100);xp=a.skills.data.Religion.xp;ck(not R.carveFeather(a.inv,a.skills));ck(a.inv:countItem('Feather')==9 and a.skills.data.Religion.xp==xp);Q.roll=roll
return 'PASS '..count..' Religion XP per unit, rune level gates, carve outputs and metadata-safe graded stacking checks'
'''))
finally:s.close()
