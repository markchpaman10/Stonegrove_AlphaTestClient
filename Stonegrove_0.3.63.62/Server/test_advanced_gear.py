from pathlib import Path
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent)
try:
 print(s.eval(r'''
local A=require('game.advanced_gear');local C=require('game.crafting').new();local I=require('game.inventory');local K=require('game.skills');local P=require('game.progression');local F=require('game.fang_poison');local M=require('game.metal_progression');local count=0
local function check(v,m)assert(v,m);count=count+1 end
local w={authoredObjects={{id='metalLoom',x=100,y=100},{id='anvil',x=100,y=100},{id='smelter',x=100,y=100}}};local p={x=100,y=100}
for _,r in ipairs(A.recipes)do
 local idx;for i,v in ipairs(C:getRecipes(r.station))do if v==r then idx=i end end;check(idx,'Recipe registered '..r.output)
 local inv=I.new();inv.bagSlots[1].size=100;local sk=K.new();sk.data[r.skill].level=r.level-1;sk.data[r.skill].xp=sk.xpTable[r.level-1]
 if r.tool then inv:add(r.tool,1)end;for _,n in ipairs(r.needs)do inv:add(n[1],n[2])end
 check(not C:craft(r.station,idx,inv,sk,nil,nil,w,p),'Level gate '..r.output)
 for _,n in ipairs(r.needs)do check(inv:countItem(n[1])==n[2],'No consumption on rejection')end
 sk.data[r.skill].level=r.level;sk.data[r.skill].xp=sk.xpTable[r.level]
 if r.stationRequirement then p.x=200;check(not C:craft(r.station,idx,inv,sk,nil,nil,w,p),'Station range '..r.output);p.x=100;check(not C:canCraft(r,inv,nil,sk,nil,p),'No world cannot bypass station');end
 local xp=sk.data[r.skill].xp;local ok,why=C:craft(r.station,idx,inv,sk,nil,nil,w,p);check(ok,why or r.output);check(inv:countItem(r.output)==1,'Exactly one output '..r.output)
 check(math.abs(sk.data[r.skill].xp-xp-r.xp*sk:xpMultiplier(r.skill))<.00001,'Correct skill XP '..r.output)
 for _,n in ipairs(r.needs)do check(inv:countItem(n[1])==0,'Exact recipe ingredients '..r.output)end
 check(SG_SERVER.sprites.itemImages[r.output]and SG_SERVER.sprites.itemInfo[r.output],'Icon/metadata '..r.output)
end
for n,d in pairs(A.items)do if d.requiredSkill then
 local k=K.new();k.data[d.requiredSkill].level=d.requiredLevel-1;check(not P.canEquip(k,n,SG_SERVER.sprites.itemInfo[n]),'Equip gate '..n);k.data[d.requiredSkill].level=d.requiredLevel;check(P.canEquip(k,n,SG_SERVER.sprites.itemInfo[n]),'Equip unlocked '..n)
end;if d.slot then local doll=SG_SERVER.sprites.paperDolls[n];check(doll and doll.slot==d.slot,'Paper doll slot');for _,dir in ipairs({'up','right','down'})do check(#doll.doll.frames[dir]==4,'Four direction frames');for _,q in ipairs(doll.doll.frames[dir])do local iw,ih=doll.doll.image:getDimensions();check(q[1]+q[3]<=iw and q[2]+q[4]<=ih,'Paper doll bounds')end end end end
check(M.items['Steel Sword']==nil and M.items['Steel Armor']==nil,'Steel art activated');check(M.items['Steel Axe'].placeholder and M.items['Nickel Copper Armor'].placeholder,'Unimplemented items stay black');check(not P.canEquip(K.new(),'Steel Axe',SG_SERVER.sprites.itemInfo['Steel Axe']),'Placeholder not equipable')
local bonuses=require('game.combat').gearBonuses({head='Cave Snake Helm',body='Cave Snake Armor',legs='Cave Snake Boots'});check(bonuses.ranged==7 and bonuses.defence==16,'Snake ranged/defence bonuses')
check(A.isQuiver('Cave Snake Quiver')and A.isQuiver('Quiver')and A.isArrow('Snake Fang Arrows'),'Quiver/ammo compatibility')
local inv=I.new();inv.bagSlots[1].size=3;inv.bagSlots[1].slots={{name='Iron Bar',qty=4},{name='Wool Thread',qty=10},{name='Bones',qty=1}};local k=K.new();k.data.Tailoring.level=30;k.data.Tailoring.xp=k.xpTable[30];local index;for i,r in ipairs(C:getRecipes('tailoring'))do if r.output=='Iron Weave Thread'then index=i end end;local xp=k.data.Tailoring.xp;check(not C:craft('tailoring',index,inv,k,nil,nil,w,p),'Full inventory failure');check(inv:countItem('Iron Bar')==4 and inv:countItem('Wool Thread')==10 and k.data.Tailoring.xp==xp,'Atomic materials/XP')
local kills=0;local world={enemies={},addPopup=function()end,defeatEnemy=function(self,e)e.dead=true;kills=kills+1 end};local e={hp=10,x=0,y=0,kind='rat'};world.enemies={e};local sk=K.new();local xp=sk:get('Ranged').xp
check(not F.apply(world,e,'Copper Arrows',sk,nil,nil,0),'Copper no poison');check(not F.apply(world,e,'Snake Fang Arrows',sk,nil,nil,.25),'25 percent threshold');check(F.apply(world,e,'Snake Fang Arrows',sk,nil,nil,.249),'Poison applies');F.update(world,.5);check(e.hp==10,'No immediate tick');F.update(world,.5);check(e.hp==9,'First second tick');F.update(world,1);check(e.hp==8 and e.fangPoison==nil,'Second second tick/expiration');F.update(world,10);check(e.hp==8,'No extra damage');check(sk:get('Ranged').xp>xp,'Owner poison XP')
e.hp=5;F.apply(world,e,'Snake Fang Arrows',nil,nil,nil,0);F.update(world,3);check(e.hp==3 and not e.fangPoison,'Long frame exactly two ticks')
e.hp=1;F.apply(world,e,'Snake Fang Arrows',nil,nil,nil,0);F.update(world,2);check(e.dead and kills==1,'Poison kills through defeat once');F.update(world,2);check(kills==1,'No duplicate drops')
-- Actual bow path, both equipped quiver types and direct ammo, last-arrow behavior.
local world=SG_SERVER.world;local player=require('game.player').new();local sk=K.new();sk.data.Ranged.level=30;sk.data.Ranged.xp=sk.xpTable[30];player.equipped='Poplar Bow';player.stamina=100;player.maxStamina=100;player.x=200;player.y=200
for _,quiver in ipairs({'Quiver','Cave Snake Quiver','direct'})do
 local e={kind='rat',hp=100,maxHp=100,x=210,y=200,dead=false,stats={melee=1},hitRadius=14};local eq={weapon='Poplar Bow',ammo=quiver=='direct'and{name='Snake Fang Arrows',qty=1}or{name=quiver,arrowType='Snake Fang Arrows',qty=1}};player.attackCooldown=0;player.stamina=100
 local ok,why=world:attackEnemy(e,player,sk,eq,SG_SERVER.sprites,nil,{});check(ok,why or'Bow fires');local arrow=world.playerArrows[#world.playerArrows];check(arrow.ammoType=='Snake Fang Arrows'and arrow.skills==sk,'Capture ammo/owner before last arrow removal');if quiver=='direct'then check(eq.ammo==nil,'Direct ammo depleted')else check(eq.ammo.name==quiver and eq.ammo.qty==0 and eq.ammo.arrowType==nil,'Empty quiver preserved')end
 arrow.hit=false;world:resolvePlayerArrow(arrow,sk);check(e.hp==100 and not e.fangPoison,'Miss has no poison');arrow.hit=true;arrow.damage=1;local rnd=math.random;math.random=function()return 0 end;world:resolvePlayerArrow(arrow,sk);math.random=rnd;check(e.hp==99 and e.fangPoison,'Successful arrow poisons through actual resolver')
end
return 'PASS '..count..' new recipe/equipment/art/poison/bow/atomic-inventory checks'
'''))
finally:s.close()
