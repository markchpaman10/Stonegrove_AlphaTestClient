from pathlib import Path
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent);s.stopped.set();s.thread.join()
try:
 print(s.eval(r'''
local S=require('game.seafood_content');local I=require('game.inventory');local C=require('game.crafting').new();local K=require('game.skills');local P=require('game.shellfish');local count=0;local function check(v,m)assert(v,m);count=count+1 end
local sk=K.new();local function level(lv)sk.data.Cooking.xp=sk.xpTable[lv];sk.data.Cooking.level=lv end;level(30)
local function inventory(size)local inv=I.new();inv.bagSlots={{name='QA',size=size or 20,slots={}}};return inv end
local random=math.random
local function rolls(first,second)local n=0;math.random=function(a,b)n=n+1;return n==1 and first or second end end
for _,station in ipairs({'stove','campfire'})do
 for i,r in ipairs(C:getRecipes(station))do if r.seafood then
  check(r.level==30 and r.skill=='Cooking','Level 30 recipe');local inv=inventory();inv:add('Raw Lobster Tail',3);inv:add('Large Meat',3);local before=inv:countItem('Large Meat');level(29);check(not C:canCraft(r,inv,nil,sk),'Cooking 29 rejected');level(30)
  rolls(100,1);check(C:craft(station,i,inv,sk),'Cooking success');check(inv:countItem(r.output..' D')==1,'D grade at low quality roll');check(inv:countItem('Raw Lobster Tail')==2,'One raw tail consumed');check(inv:countItem('Large Meat')==before-(r.output=='Surf and Turf'and 1 or 0),'Exact raw meat consumed')
  level(99);rolls(100,100);check(C:craft(station,i,inv,sk),'High quality cooking');check(inv:countItem(r.output..' A')==1,'A grade high skill');rolls(1,1);check(C:craft(station,i,inv,sk),'Burnt cooking output');check(inv:countItem(r.output=='Surf and Turf'and'Burnt Surf and Turf'or'Burnt Lobster Tail')==1,'Burnt result')
  local fresh=inventory();fresh:add('Raw Lobster Tail',1);fresh:add('Large Meat',1);local xp=sk:get('Cooking').xp;local add=I.add;I.add=function()return false end;rolls(100,1);check(not C:craft(station,i,fresh,sk),'Failed output rejected');I.add=add;check(fresh:countItem('Raw Lobster Tail')==1 and fresh:countItem('Large Meat')==1 and sk:get('Cooking').xp==xp,'Failed cooking keeps inputs and XP')
 end end
end
math.random=random
local sprites=SG_SERVER.sprites;for _,grade in ipairs({'D','C','B','A'})do for _,base in ipairs({'Cooked Lobster Tail','Surf and Turf'})do local n=base..' '..grade;check(sprites.itemInfo[n].heal==require('game.food').healing[n]and sprites.itemImages[n],'Food healing and icon '..n);check(S.isFood(n)and inventory():isStackable(n)and inventory():maxStack(n)==100,'Belt and stacking '..n)end end
check(S.tailChance(30)==.05 and math.abs(S.tailChance(99)-.15)<.00001,'Probability endpoints');check(S.tailChance(60)>S.tailChance(30)and S.tailChance(60)<S.tailChance(99),'Cooking increases probability');check(S.tailChance(120)==S.tailChance(99),'Chance capped');check(sprites.itemInfo['Burnt Lobster Tail'].heal==1 and sprites.itemInfo['Burnt Surf and Turf'].heal==1,'Burnt heals 1')
local w={groundItems={},shellfishParts={},regionId='qa'};local player=require('game.player').new();player.x,player.y=100,100;local inv=inventory();inv:add('Lobster',3);inv:add('Copper Knife',1);local actor={player=player,inv=inv,skills=sk,campOwner='qa:1',fieldcraft={}};local before=sk:get('Cooking').xp;math.random=function(a,b)return a and 1 or .01 end
check(P.command(w,actor,{op='shellFillet',bag=1,slot=1}),'Bulk lobster break');check(inv:countItem('Lobster')==0 and inv:countItem('Lobster Parts')==3 and inv:countItem('Raw Lobster Tail')==3,'One independent tail per lobster and all parts retained');check(#w.groundItems==0 and#w.shellfishParts==0,'No ground drops');check(math.abs(sk:get('Cooking').xp-before-6*sk:xpMultiplier('Cooking'))<.00001,'Breaking XP per lobster');check(not P.command(w,actor,{op='shellFillet',bag=1,slot=1}),'No repeated tail roll from broken parts')
for _,lv in ipairs({30,99})do level(lv);local fresh=inventory();fresh:add('Lobster',1);fresh:add('Copper Knife',1);actor.inv=fresh;math.random=function(a,b)return a and 1 or .1 end;check(P.command(w,actor,{op='shellFillet',bag=1,slot=1}),'Threshold break');check(fresh:countItem('Raw Lobster Tail')==(lv==99 and 1 or 0),'Same roll gains tail only at higher Cooking')end
level(99);local full=inventory(5);full:add('Lobster',3);full:add('Copper Knife',1);full:add('Raw Lobster Tail',98);actor.inv=full;math.random=function(a,b)return a and 1 or .01 end;check(P.command(w,actor,{op='shellFillet',bag=1,slot=1}),'Full inventory breaks all');local pendingSlot;for slot,it in pairs(full.bagSlots[1].slots)do if it.tailPending then pendingSlot=slot end end;check(full:countItem('Raw Lobster Tail')==100 and pendingSlot~=nil,'Overflow tail safely inside parts');check(not P.command(w,actor,{op='shellHarvest',bag=1,slot=pendingSlot}),'Harvest needs space for both meat and tail');check(full.bagSlots[1].slots[pendingSlot].tailPending and full:countItem('Lobster Meat')==0,'Failed harvest atomic');full:removeItems('Copper Knife',1);check(P.command(w,actor,{op='shellHarvest',bag=1,slot=pendingSlot}),'Harvest pending tail');check(full:countItem('Raw Lobster Tail')==101 and full:countItem('Lobster Meat')==1,'Tail preserved and meat awarded once');check(not P.command(w,actor,{op='shellHarvest',bag=1,slot=pendingSlot}),'No repeat harvest');math.random=random
check(require('game.vendor_catalog').excluded['Raw Lobster Tail'],'Rare raw tail not stocked by ordinary vendors');return 'PASS '..count..' seafood checks'
'''))
finally:s.close()
