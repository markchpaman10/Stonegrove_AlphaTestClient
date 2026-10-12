from pathlib import Path
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent)
try:
 print(s.eval(r'''
local w=SG_SERVER.world;local I=require('game.inventory');local K=require('game.skills');local C=require('game.crafting').new();local A=require('game.advanced_gear');local count=0
local function check(v,m)assert(v,m);count=count+1 end
for _,name in ipairs({'Poplar Bow','Snake Fang Arrows'})do local found;for _,r in ipairs(C:getRecipes('woodcraft'))do if r.output==name then found=r end end;check(found and found.skill=='Fletching'and found.level==30,'Fletching recipe '..name)end
local armor;for _,r in ipairs(A.recipes)do if r.output=='Cave Snake Armor'then armor=r end;for _,n in ipairs(r.needs)do if n[1]=='Wolf Head'then check(r.output=='Cave Snake Armor'and n[2]==1,'Wolf Head body only')end end end;check(armor,'Body recipe')
local sk=K.new();sk.data.Ranged.level=29;check(not require('game.progression').canEquip(sk,'Poplar Bow',SG_SERVER.sprites.itemInfo['Poplar Bow']),'Ranged 29 rejected');sk.data.Ranged.level=30;check(require('game.progression').canEquip(sk,'Poplar Bow',SG_SERVER.sprites.itemInfo['Poplar Bow']),'Ranged 30 accepted')
local p={x=100,y=100,equipped='Copper Dagger'};local random=math.random
for _,value in ipairs({.099,.10,.9})do
 local inv=I.new();inv.bagSlots[1].size=100;local e={kind='wolf',x=100,y=100,dead=true,skinned=false};math.random=function(a,b)if a then return 1 end;return value end
 check(w:skinAnimal(e,p,sk,inv),'Successful wolf skin');check(inv:countItem('Wolf Head')==(value<.10 and 1 or 0),'Rare threshold');local before=inv:countItem('Wolf Head');check(not w:skinAnimal(e,p,sk,inv),'No double skin');check(inv:countItem('Wolf Head')==before,'No duplicate head')
end
math.random=function(a,b)if a then return 1 end;return .01 end
local inv=I.new();inv.bagSlots={{name='QA',size=2,slots={}}};local e={kind='wolf',x=100,y=100,dead=true,skinned=false};local xp=sk.data.Skinning.xp
check(not w:skinAnimal(e,p,sk,inv),'Rare head requires whole yield space');check(not e.skinned and inv:countItem('Raw Hide')==0 and sk.data.Skinning.xp==xp,'Atomic full bag');check(e.wolfHeadDrop,'Rare roll cached');inv.bagSlots[1].size=3;check(w:skinAnimal(e,p,sk,inv),'Retry after space freed');check(inv:countItem('Wolf Head')==1 and inv:countItem('Large Meat')==1,'Full yield delivered')
local other=I.new();other.bagSlots[1].size=100;local rat={kind='rat',x=100,y=100,dead=true};check(w:skinAnimal(rat,p,sk,other),'Rat retained');check(other:countItem('Wolf Head')==0,'No head from other animal');math.random=random
check(SG_SERVER.sprites.poplarStumpImage and SG_SERVER.sprites.itemImages['Wolf Head'],'Uploaded assets registered')
return 'PASS '..count..' bow/arrow Fletching, equipment and rare wolf-head atomic skinning checks'
'''))
finally:s.close()
