from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent)
try:
 print(s.eval(r'''
local F=require('game.fishing_tiers');local I=require('game.inventory');local K=require('game.skills');local C=require('game.crafting').new();local w=SG_SERVER.world;local n=0
local function check(v,m)assert(v,m);n=n+1 end
check(F.capacity(12)==10 and F.capacity(99)==10,'Pot yield endpoints')
for lv=30,99 do check(F.capacity(lv)>=1 and F.capacity(lv)<=10,'Pot cap '..lv)end
for lv=7,99 do for roll=1,125 do local name=F.catch('Oak Fishing Pole',lv,roll);check(name=='Large Fish'or name=='Eel'or(lv>=40 and name=='Swordfish')or(lv>=40 and name=='Swordfish')or(lv>=40 and name=='Swordfish')or(lv>=40 and name=='Swordfish'),'No Small Fish with Oak from level 7')end end
check(F.catch('Poplar Fishing Pole',20,1)=='Manta Ray','Poplar manta')
local oldrandom=math.random;math.random=function(a,b)return b or .9 end
local inv=I.new();inv.bagSlots[1].size=100;inv:add('Crab Pot',1);local sk=K.new();sk.data.Fishing.level=29;local p={x=100,y=100,equipped='Crab Pot',pulseTool=function()end}
local oldmap=w.map;w.map={isBeachCell=function()return true end,isBeachWaterCell=function()return true end};w.fishing=nil
check(not w:fishAt(100,100,p,sk,inv),'Pots use placed workflow');w.fishing=nil
math.random=function(a,b)return a or .01 end;p.equipped='Poplar Fishing Pole';sk.data.Fishing.level=19;check(not w:fishAt(100,100,p,sk,inv),'Manta19 rejects');sk.data.Fishing.level=20;check(w:fishAt(100,100,p,sk,inv),'Manta20 cast');w.fishing.timer=0;w:updateFishing(1,p,sk,inv);check(inv:countItem('Manta Ray')==1,'Actual Manta catch');p.x=200;w:updateFishing(1,p,sk,inv);check(not w.fishing,'Move cancels');w.map=oldmap
for _,station in ipairs({'stove','campfire'})do for idx,r in ipairs(C:getRecipes(station))do if r.output=='Crab Meat'or r.output=='Lobster Meat'or r.output=='Manta Ray'then
 local level=require('game.whole_fish').levels[r.output];local bag=I.new();bag.bagSlots[1].size=100;bag:add(r.output,5);sk.data.Cooking.level=level-1;check(not C:craft(station,idx,bag,sk),'Cooking level reject');sk.data.Cooking.level=math.max(level,15)
 math.random=function(a,b)return b end;local ok,out=C:craft(station,idx,bag,sk);check(ok and out=='Cooked '..r.output..' A','Grade A cooking');check(require('game.food').healing[out]==(r.output=='Crab Meat'and 24 or r.output=='Lobster Meat'and 115 or 60),'Tier healing');sk.data.Cooking.level=level;math.random=function(a,b)return a end;ok,out=C:craft(station,idx,bag,sk);check(ok and out=='Burnt '..r.output,'Burn cooking '..tostring(ok)..' '..tostring(out)..' '..r.output);check(require('game.food').healing[out]==1,'Burnt heals1')
 end end end
for _,name in ipairs({'Oak Fishing Pole','Poplar Fishing Pole','Crab Pot','Lobster Pot'})do local found=false;for idx,r in ipairs(C:getRecipes('woodcraft'))do if r.output==name then found=true;local bag=I.new();bag.bagSlots[1].size=100;bag:add('Copper Knife',1);for _,need in ipairs(r.needs)do bag:add(need[1],need[2])end;sk.data[r.skill].level=r.level;local ok,out=C:craft('woodcraft',idx,bag,sk);check(ok and out==name,'Craft '..name)end end;check(found,'Recipe '..name)end
for _,base in ipairs({'Crab Meat','Manta Ray'})do for _,grade in ipairs({'D','C','B','A'})do local info=SG_SERVER.sprites.itemInfo['Cooked '..base..' '..grade];check(info and info.heal==require('game.food').healing['Cooked '..base..' '..grade],'Tooltip healing')end end
math.random=oldrandom;return 'PASS '..n..' fishing/cooking shared server checks'
'''.replace('and30','and 30').replace('or20','or 20').replace('and115','and 115').replace('or60','or 60')))
finally:s.close()


