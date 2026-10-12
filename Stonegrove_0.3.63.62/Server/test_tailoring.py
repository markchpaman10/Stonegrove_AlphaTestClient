"""Native shared-game rules; uses no account database."""
from pathlib import Path
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent)
try:
 print(s.eval(r'''
local T=require('game.tailoring_content');local C=require('game.crafting').new();local I=require('game.inventory');local K=require('game.skills');local count=0
local function check(v,m)assert(v,m);count=count+1 end
local levels={['Linen Bag']=50,['Wool Thread']=1,['Blue Dye']=3,['Cloth Strip']=4,['Dyed Blue Cloth Strip']=5,['Wizard Robes']=7,['Wizard Hat']=9,['Red Dye']=9,['Dark Blue Dye']=10,['Iron Reinforced Mage Hat']=13,['Green Dye']=14,['Iron Reinforced Mage Robes']=16,['Iron Reinforced Mage Boots']=17}
local w=SG_SERVER.world;local p={x=200,y=200};local testworld={authoredObjects={{id='loom',x=200,y=200},{id='spinningWheel',x=200,y=200}}}
for index,r in ipairs(C:getRecipes('tailoring'))do if r.tailoring then
 check(r.level==(levels[r.output]or(r.output:find('Hood')and 20 or r.output:find('Cape')and 19 or r.output=='Red Cloth Strip'and 9 or r.output=='Green Cloth Strip'and 14 or 10)),'Level '..r.output)
 local inv=I.new();inv.bagSlots[1].size=64;local sk=K.new();if r.tool then inv:add(r.tool,1)end;for _,n in ipairs(r.needs)do inv:add(n[1]=='Any Cloth Strip'and'Cloth Strip'or n[1],n[2])end
 if r.level>1 then sk.data.Tailoring.level=r.level-1;sk.data.Tailoring.xp=sk.xpTable[r.level-1];local ok=C:craft('tailoring',index,inv,sk,nil,nil,testworld,p);check(not ok and inv:countItem(r.output)==0,'Reject below level '..r.output);for _,n in ipairs(r.needs)do check(T.count(inv,n[1])==n[2],'Preserve ingredients after level failure')end end
 sk.data.Tailoring.level=r.level;sk.data.Tailoring.xp=sk.xpTable[r.level];local xp=sk.data.Tailoring.xp;local jewel=sk.data['Jewel Crafting'].xp
 if r.stationRequirement then p.x=400;local ok=C:craft('tailoring',index,inv,sk,nil,nil,testworld,p);check(not ok,'Reject distant station');p.x=200 end
 local ok,why=C:craft('tailoring',index,inv,sk,nil,nil,testworld,p);check(ok,why or r.output);check(inv:countItem(r.output)==1,'One output');check(math.abs(sk.data.Tailoring.xp-xp-r.xp*sk:xpMultiplier('Tailoring'))<.0001 and sk.data['Jewel Crafting'].xp==jewel,'Only Tailoring XP');for _,n in ipairs(r.needs)do check(T.count(inv,n[1])==0,'Exact material consumption')end
 check(SG_SERVER.sprites.itemInfo[r.output]~=nil and SG_SERVER.sprites.itemImages[r.output]~=nil,'Registered tooltip/icon')
end end
local wool;for _,r in ipairs(C:getRecipes('spinningWheel'))do if r.output=='Wool Thread'then wool=r end end;check(wool and wool.skill=='Tailoring'and wool.level==1,'Wheel ownership');check(#C:getRecipes('loom')==5,'Loom recipe list')
for _,colour in ipairs(T.colours)do for _,part in ipairs({'Cape','Hood'})do local id=colour.name..' Cloth '..part;check(SG_SERVER.sprites.itemInfo[id].type==(part=='Hood'and'Head Armor'or'Cape'),'Equipment slot');local doll=SG_SERVER.sprites.paperDolls[id];check(doll and #doll.doll.frames.up==4 and #doll.doll.frames.right==4 and #doll.doll.frames.down==4,'Directional paper dolls')end end
check(T.useRecipe('Empty Tube','Purple Berries')=='Dark Blue Dye','Purple berries inventory use');check(T.useRecipe('Empty Tube','Large Blue Mushroom')=='Blue Dye','Mushroom inventory use')
-- A full bag whose partially consumed ingredients retain every slot rejects atomically.
local inv=I.new();inv.bagSlots[1].size=3;inv.bagSlots[1].slots={{name='Red Berries',qty=10},{name='Empty Tube',qty=2},{name='Bones',qty=1}};local sk=K.new();sk.data.Tailoring.level=9;sk.data.Tailoring.xp=sk.xpTable[9]
local index;for i,r in ipairs(C:getRecipes('tailoring'))do if r.output=='Red Dye'then index=i end end;local xp=sk.data.Tailoring.xp;check(not C:craft('tailoring',index,inv,sk),'Full bag rejected');check(inv:countItem('Red Berries')==10 and inv:countItem('Empty Tube')==2 and sk.data.Tailoring.xp==xp,'Full bag preserves inputs and XP')
local inv=I.new();inv.bagSlots[1].size=64;inv:add('Needle',1);inv:add('Red Cloth Strip',2);inv:add('Green Cloth Strip',2);inv:add('Dark Blue Cloth',1);inv:add('Wool Thread',9);local sk=K.new();sk.data.Tailoring.level=19;sk.data.Tailoring.xp=sk.xpTable[19];local index;for i,r in ipairs(C:getRecipes('tailoring'))do if r.output=='Red Cloth Cape'then index=i end end;check(C:craft('tailoring',index,inv,sk),'Mixed colour cape');check(T.count(inv,'Any Cloth Strip')==0 and inv:countItem('Wool Thread')==0 and inv:countItem('Red Cloth Cape')==1,'Mixed colour exact consumption')
return 'PASS '..count..' Tailoring level/material/XP/station/slot/paper-doll/atomic inventory checks'
'''))
finally:s.close()
