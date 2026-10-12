from pathlib import Path
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent);s.stopped.set();s.thread.join()
try:
 print(s.eval(r'''
local checks=0;local function check(v,m)assert(v,m);checks=checks+1 end
local sprites=SG_SERVER.sprites;local T=require('game.tailoring_content');local C=require('game.crafting').new();local I=require('game.inventory');local sk=require('game.skills').new();sk.data.Tailoring.level=99;sk.data.Tailoring.xp=sk.xpTable[99]
local recipes={};for station,list in pairs(C:allRecipes())do for i,r in ipairs(list)do check(r.output~="Death's Robes",'Death robes have no recipe');recipes[r.output]={station,i,r}end end
for _,name in ipairs({'Black Berries','Black Dye','Black Linen Cloth','Black Cape','Black Hood',"Death's Robes"})do check(sprites.itemImages[name]and sprites.itemInfo[name],'Catalog '..name)end
local inv=I.new();inv.bagSlots={{name='Large Leather Bag',qualityGrade='A',size=40,slots={}}};inv:add('Black Berries',6);inv:add('Empty Tube',1)
local r=recipes['Black Dye'];check(C:craft(r[1],r[2],inv,sk),'Black dye crafted');check(inv:countItem('Black Berries')==0 and inv:countItem('Empty Tube')==0 and inv:countItem('Black Dye')==1,'Exact dye materials consumed')
local function physical(name)for _,b in pairs(inv.bagSlots)do for _,it in pairs(b.slots)do if it.name==name then return it end end end end
check(physical('Black Dye').qualityGrade~=nil,'Dye quality');inv:add('Linen Cloth',1);inv:add('Black Linen Cloth',8);r=recipes['Black Linen Cloth'];local w={authoredObjects={{id='loom',x=0,y=0}}};local p={x=0,y=0};check(C:craft(r[1],r[2],inv,sk,nil,nil,w,p),'Loom black cloth');check(inv:countItem('Black Linen Cloth')==9,'Existing black cloth preserved');inv:add('Wool Thread',14);inv:add('Needle',1)
for _,name in ipairs({'Black Cape','Black Hood'})do r=recipes[name];check(C:craft(r[1],r[2],inv,sk),'Craft '..name);check(physical(name).qualityGrade~=nil,'Quality '..name)end
check(inv:countItem('Black Linen Cloth')==0 and inv:countItem('Wool Thread')==0,'Matching black cloth and exact thread quantities');check(T.useRecipe('Empty Tube','Black Berries')=='Black Dye'and T.useRecipe('Black Dye','Linen Cloth')=='Black Linen Cloth','Use-on recipes')
local low=require('game.skills').new();check(not C:canCraft(recipes['Black Dye'][3],inv,nil,low),'Tailoring level enforced');inv:add('Red Cloth Strip',20);inv:add('Wool Thread',20);check(not C:canCraft(recipes['Black Cape'][3],inv,nil,sk),'Other cloth cannot replace black cloth');check(not C:canCraft(recipes['Black Linen Cloth'][3],inv,nil,sk,{},p),'Loom enforced')
local d=sprites.itemInfo["Death's Robes"];check(d.defence==9 and not d.requiredSkill and not d.requiredLevel,'Death robes unrestricted level-40 stats');local bonuses=require('game.combat').gearBonuses({body="Death's Robes"});check(bonuses.defence==9 and bonuses.magic==5 and bonuses.healing==4,'Actual combat bonuses '..require('game.json').encode(bonuses));check(require('game.vendor_catalog').excluded["Death's Robes"],'No ordinary vendor sale')
for _,name in ipairs({'Black Berries','Black Dye','Black Linen Cloth'})do check(inv:isStackable(name)and inv:maxStack(name)==100,'Stacking '..name)end
for _,kind in ipairs({'skeleton','ghost'})do check(require('game.expansion').defs[kind]and sprites.undead[kind],'Enemy stats and art '..kind);local e=SG_SERVER.world.makeExpansionEnemy(kind,300,300,1);check(e.kind==kind and e.stats.melee==10 and e.hp==50,'Actual enemy construction '..kind);check(require('game.custom_content').monster(kind).baseSprite==kind,'Monster editor template '..kind)end
check(require('game.custom_content').npc('ghost').race=='Ghost','Ghost NPC template');check(not require('game.races').valid('Ghost'),'Ghost not a player race')
local P=require('game.progression');check(P.canEquip(low,"Death's Robes",d),'Level-1 player can actually equip robes');check(P.canEquip({combatSkills={}},"Death's Robes",d),'Level-1 merc can actually equip robes');check(P.canEquip(low,'Black Cape',sprites.itemInfo['Black Cape']),'Cape follows existing unrestricted player equip rules')
local world=SG_SERVER.world;world.guards={};world.mercs={};world.slimeMinions={};world.bossShots={};world.bossPools={};world.gravestones={};local player=require('game.player').new();player.x,player.y=2000,2000;player.hp,player.maxHp=10000,10000
for _,kind in ipairs({'skeleton','ghost'})do local enemy=world.makeExpansionEnemy(kind,2000,2000,1);enemy.aggro=true;enemy.attackTimer=0;world.enemies={enemy};player.hp=player.maxHp;local hp=player.hp;local random=math.random;math.random=function(a,b)if a then return a end;return .5 end;for i=1,10 do world:updateCombat(.2,player,low,{},sprites,nil,{},inv)end;math.random=random;check(player.hp<hp,'Actual enemy damages player '..kind)end
local M=assert(loadfile(SG_ROOT..'/EditorShared/model.lua'))();check(M.validate(require('monster_data').entries,'monster',sprites.itemInfo),'Monster editor validation');check(M.validate(require('npc_data').entries,'npc',sprites.itemInfo),'Ghost NPC editor validation')
local pack=require('game.profile');for mask=0,255 do local slots={};for i=1,8 do if math.floor(mask/2^(i-1))%2==1 then slots[i]={name='Black Linen Cloth',qty=i}end end;local restored=pack.unpack(pack.pack(slots));for i=1,8 do check((slots[i]==nil and restored[i]==nil)or(slots[i]and restored[i]and restored[i].qty==i),'Sparse slot serialization '..mask..':'..i)end end
return 'PASS '..checks..' dark content checks'
'''))
finally:s.close()
