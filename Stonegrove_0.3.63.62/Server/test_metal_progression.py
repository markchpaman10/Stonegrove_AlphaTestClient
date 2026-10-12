from pathlib import Path
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent)
try:
 print(s.eval(r"""
local checks=0;local function check(v,m)assert(v,m);checks=checks+1 end
local M=require('game.metal_progression');local G=require('game.iron_gear');local P=require('game.progression');local U=require('game.unlocks');local C=require('game.crafting').new();local sk=require('game.skills').new();local I=require('game.inventory')
local function level(skill,n)sk.data[skill].xp=sk.xpTable[n];sk.data[skill].level=n end
local starts={1,10,20,30,40,50};for i,t in ipairs(M.tiers)do check(t.level==starts[i]and t.maxLevel==starts[i]+(i==1 and 8 or 9),'Exact metal bands')end
for _,name in ipairs({'Copper Dagger','Copper Longsword','Copper Shield','Copper Helm','Copper Armor'})do check(P.canEquip(sk,name,SG_SERVER.sprites.itemInfo[name]),'Copper available at melee 1')end
for _,name in ipairs({'Iron Sword','Iron Shield','Iron Helm','Iron Armor','Iron Boots','Iron Axe','Iron Pickaxe','Iron Hammer','Iron Tongs'})do
 level('Melee Combat',9);check(not P.canEquip(sk,name,SG_SERVER.sprites.itemInfo[name]),'Iron blocked below melee 10');level('Melee Combat',10);check(P.canEquip(sk,name,SG_SERVER.sprites.itemInfo[name]),'Iron usable at melee 10');local merc={combatSkills={['Melee Combat']={level=9}}};check(not P.canEquip(merc,name,SG_SERVER.sprites.itemInfo[name]),'Merc gate 9');merc.combatSkills['Melee Combat'].level=10;check(P.canEquip(merc,name,SG_SERVER.sprites.itemInfo[name]),'Merc gate 10')
end
for _,r in ipairs(G.recipes)do if r.skill=='Smithing'then check(r.level>=10 and r.level<=19,'Every Iron smithing recipe in 10-19')end end
check(G.items['Iron Reinforced Mage Robes'].requiredLevel==30 and G.items['Iron Reinforced Leather Armor'].requiredLevel==30,'Unrelated mage/ranged gear retained')
local inv=I.new();inv.bagSlots[1].slots={{name='Copper Tongs',qty=1},{name='Small Iron Chunk',qty=1}};local index,r;for i,v in ipairs(C:getRecipes('smelter'))do if v.name=='Iron Bar'then index,r=i,v end end;check(r and r.level==10,'Iron Bar level 10')
level('Smithing',9);check(not C:canCraft(r,inv,nil,sk),'Smithing 9 rejects Iron Bar');check(inv:countItem('Small Iron Chunk')==1,'Failure preserves material')
level('Smithing',10);check(C:canCraft(r,inv,nil,sk),'Copper Tongs bootstrap iron without circular bar dependency');local ok=C:craft('smelter',index,inv,sk);check(ok and inv:countItem('Iron Bar')==1 and inv:countItem('Small Iron Chunk')==0,'Real Iron Bar crafting transaction')
inv.bagSlots[1].slots={{name='Iron Tongs',qty=1},{name='Small Iron Chunk',qty=1}};check(C:canCraft(r,inv,nil,sk),'Existing Iron Tongs still compatible')
level('Smithing',99);level('Melee Combat',99);local total=0;for name,d in pairs(M.items)do total=total+1;check(SG_SERVER.sprites.itemInfo[name].detail=='Not in yet'and SG_SERVER.sprites.itemImages[name]~=nil,'Black icon and exact placeholder tooltip');check(not P.canEquip(sk,name,d),'Placeholder never equips even at 99')end;check(total==39,'All later metal item previews registered')
local recipes=0;local before=inv:countItem('Small Iron Chunk');local xp=sk.data.Smithing.xp;for i,r in ipairs(C:getRecipes('anvil'))do if r.placeholder then recipes=recipes+1;local ok,why=C:craft('anvil',i,inv,sk);check(not ok and why=='Not in yet','Placeholder craft safely rejects');check(inv:countItem(r.output)==0,'No future equipment granted')end end;check(recipes==35,'Four future tiers have equipment recipe previews');check(before==inv:countItem('Small Iron Chunk')and xp==sk.data.Smithing.xp,'Placeholder grants no XP and consumes nothing')
for _,skill in ipairs({'Smithing','Melee Combat'})do local rows=U.list(skill,C);for _,t in ipairs(M.tiers)do local found;for _,r in ipairs(rows)do if r.level==t.level and r.text:find(t.name..' equipment',1,true)then found=r;break end end;check(found and(not t.placeholder or found.icon and (found.detail=='Not in yet'or t.name=='Steel')),'Skill guide includes tier preview')end end
return 'PASS '..checks..' metal progression, player/mercenary gates, real iron smelting, higher-tier placeholder safety and guide assertions'
"""))
finally:s.close()
