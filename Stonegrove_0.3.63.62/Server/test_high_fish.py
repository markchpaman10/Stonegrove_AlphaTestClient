from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent);s.stopped.set();s.thread.join()
try:
 print(s.eval(r'''
local F=require('game.fishing_tiers');local H=require('game.high_tier_fish');local Skills=require('game.skills');local I=require('game.inventory');local UI=require('game.ui');local C=require('game.crafting').new();local P=require('game.player');local count=0
local function check(v,m)assert(v,m or tostring(count+1));count=count+1 end
for level=1,99 do for roll=1,125 do local name=F.catch('Fishing Pole',level,roll);if H.data[name]then check(level>=H.data[name].level,'Early high fish unlock')end end end
local expected={['Manta Ray']=80,Tuna=95,Swordfish=110,Shark=125};local w=SG_SERVER.world;w.map.isBeachCell=function()return true end;w.map.isBeachWaterCell=function()return true end;w.map.authored=nil
local rand=math.random
for name,d in pairs(H.data)do
 check(F.catch('Fishing Pole',d.level,expected[name])==name)
 local sk=Skills.new();sk.data.Fishing.level=d.level;sk.data.Fishing.xp=sk.xpTable[d.level];sk.data.Cooking.level=99;sk.data.Cooking.xp=sk.xpTable[99];local inv=I.new();inv.bank={};inv.bagSlots={};for i=1,3 do inv.bagSlots[i]={name='Large Leather Bag',qualityGrade='A',slots={}}end;inv:applyStrengthBagBonus(99);inv:add('Fishing Pole',1);inv:add('Copper Knife',1)
 local p=P.new();p.x,p.y=500,500;p.equipped='Fishing Pole';w.fishing=nil;w.enemies={};w.nodes={};local n=0;math.random=function(a,b)if a==1 and b==100 then n=n+1;return n==2 and expected[name]-math.min(25,d.level)or 1 end;if not a then return rand()elseif not b then return rand(a)end;return rand(a,b)end
 check(w:fishAt(520,500,p,sk,inv));local base=w.fishing.timer;w:updateFishing(base+.001,p,sk,inv);check(inv:countItem(name)==0 and w.fishing.pendingCatch.fish==name and w.fishing.timer==d.extra,'High fish awarded before landing wait');w:updateFishing(d.extra-.01,p,sk,inv);check(inv:countItem(name)==0);w:updateFishing(.02,p,sk,inv);check(inv:countItem(name)==1 and not w.fishing.pendingCatch);check(sk:get('Fishing').xp>0)
 local u=setmetatable({inv=inv,player=p,skills=sk,world=w,equipment={},sprites=SG_SERVER.sprites,log=function()end},{__index=UI});local bi,si;for b,bag in pairs(inv.bagSlots)do for slot,it in pairs(bag.slots)do if it.name=='Copper Knife'then bi,si=b,slot end end end;u.useTarget={tool='Copper Knife',bag=bi,slot=si};check(u:isUseCompatible('Copper Knife',{name=name}));check(u:isBatchableItemUse('Copper Knife',name));check(u:queueItemBatchStep('Copper Knife',name));check(u.craftJob.duration==d.process);local finish=u.craftJob.finish;u.craftJob=nil;finish();check(inv:countItem(name)==0 and inv:countItem('Raw Fish Fillet')==H.fillets(name,99));u.craftJob=nil
 for _,station in ipairs({'stove','campfire'})do local recipe,index;for i,r in ipairs(C:getRecipes(station))do if r.output==name then recipe,index=r,i end end;check(recipe and recipe.level==d.level and recipe.duration==d.cook and recipe.foodCategory=='Fish & Seafood');local before=inv:countItem(name);inv:add(name,1);math.random=function(a,b)return b or .99 end;check(C:craft(station,index,inv,sk,nil,nil));check(inv:countItem(name)==before and inv:countItem('Cooked '..name..' A')>=1);check(require('game.food').healing['Cooked '..name..' A']>require('game.food').healing['Cooked '..name..' D']);check(require('game.food').healing['Burnt '..name]==1)end
 inv:add(name,1);local bi,si;for b,bag in pairs(inv.bagSlots)do for slot,it in pairs(bag.slots)do if it.name==name then bi,si=b,slot end end end;check(H.command(w,{inv=inv,player=p,skills=sk},{bag=bi,slot=si}));check(inv:countItem(name)==0 and inv:countItem('Raw '..name)==1);local recipe,index;for i,r in ipairs(C:getRecipes('stove'))do if r.output=='Raw '..name then recipe,index=r,i end end;check(recipe and recipe.duration==d.cook and recipe.level==d.level and recipe.foodCategory=='Fish & Seafood');check(C:craft('stove',index,inv,sk,nil,nil));check(inv:countItem('Raw '..name)==0 and inv:countItem('Cooked '..name..' A')==3)
 math.random=rand
end
check(F.catch('Fishing Pole',1,125)=='Small Fish');check(F.catch('Oak Fishing Pole',6,125)=='Small Fish');check(F.catch('Poplar Fishing Pole',20,1)=='Manta Ray');check(H.duration('Small Fish')==.5);check(require('game.unlocks').itemUse('Copper Knife','Shark')[2]==7)
return 'PASS '..count..' high fish unlocks, Pine catch boundaries, authoritative delayed landing, no early items, Cooking grades/XP, stove/campfire recipes, batch knife timing/yields and legacy low-tier fishing checks'
'''),flush=True)
finally:s.close()

