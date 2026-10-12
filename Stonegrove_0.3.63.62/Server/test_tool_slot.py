from pathlib import Path
import sys
root=Path(__file__).resolve().parent.parent;sys.path.insert(0,str(root/'Server'))
from simulation import Simulation
s=Simulation(root);s.stopped.set();s.thread.join()
try:
 print(s.eval(r'''
local T=require('game.tool_slot');local I=require('game.inventory');local Items=require('game.items');local Sk=require('game.skills');local P=require('game.player');local C=require('game.crafting').new();local G=require('game.gravestones');local Pack=require('game.profile');local count=0
local function check(v,m)assert(v,m or tostring(count+1));count=count+1 end
local function actor()
 local inv=I.new();inv.bank={};inv.bagSlots={{name='Large Leather Bag',qualityGrade='A',slots={}}};inv:applyStrengthBagBonus(99)
 local sk=Sk.new();for _,name in ipairs({'Strength','Melee Combat','Mining','Woodcutting','Skinning','Cooking','Woodworking','Religion','Fletching'})do sk.data[name].level=99;sk.data[name].xp=sk.xpTable[99]end
 local a={inv=inv,skills=sk,player=P.new(),equipment={weapon='Copper Longsword'},equipmentItems={weapon={name='Copper Longsword',qty=1,qualityGrade='B'}},equipmentSockets={},sprites=SG_SERVER.sprites};a.player.x,a.player.y=500,500;a.player.equipped='Copper Longsword';T.bind(a);return a
end
for _,grade in ipairs({'D','C','B','A'})do
 local a=actor();for i,name in ipairs({'Copper Knife','Copper Axe','Copper Pickaxe','Iron Axe','Iron Pickaxe','Copper Dagger'})do
  a.inv.bagSlots[1].slots[i]={name=name,qty=1,qualityGrade=grade,customMark='preserve',sockets={{name='Cut Ruby',state='enchanted',enchantKind='spell',enchantValue=10}}}
  local incoming=a.inv.bagSlots[1].slots[i];local old=T.object(a);check(T.equip(a,1,i));check(T.object(a)==incoming and a.inv.bagSlots[1].slots[i]==old)
  check(a.equipment.weapon=='Copper Longsword'and a.player.equipped=='Copper Longsword'and a.equipmentItems.weapon.qualityGrade=='B')
  check(T.object(a).qualityGrade==grade and T.object(a).customMark=='preserve')
  check(T.has(a.inv,nil,({knife='Copper Knife',axe='Copper Axe',pick='Copper Pickaxe'})[T.kind(name)]))
  check(require('game.combat').enchantBonuses(a.equipmentSockets).damage==0,'Utility enchantment became combat damage')
 end
 local state=Pack.unpack(Pack.pack({equipment=a.equipment,equipmentItems=a.equipmentItems}));check(state.equipment.tool==a.equipment.tool and state.equipmentItems.tool.qualityGrade==grade)
 local obj=Items.copy(T.object(a));check(T.unequip(a));check(not a.equipment.tool);local n=0;for _,it in pairs(a.inv.bagSlots[1].slots)do if Items.sameMetadata(obj,it)then n=n+1 end end;check(n==1)
end
local a=actor();a.inv.bagSlots[1].slots[1]={name='Copper Shield',qty=1};check(not T.equip(a,1,1));a.inv.bagSlots[1].slots[1]={name='Copper Knife',qty=2};check(not T.equip(a,1,1))
a.inv.bagSlots[1].slots[1]={name='Copper Knife',qty=1,qualityGrade='A'};a.craftJob={};check(not T.equip(a,1,1));a.craftJob=nil;check(T.equip(a,1,1));a.campPending={};check(not T.unequip(a));a.campPending=nil
for i=1,a.inv.bagSlots[1].size do a.inv.bagSlots[1].slots[i]={name='Copper Shield',qty=1}end;check(not T.unequip(a));check(a.equipment.tool=='Copper Knife')
a.inv.bagSlots[1].slots={};check(T.has(a.inv,nil,'Copper Dagger'));check(not T.has(a.inv,nil,'Copper Axe'));check(not T.has(a.inv,nil,'Copper Pickaxe'))
local w=SG_SERVER.world;a.player.x,a.player.y=500,500
local copper={kind='copper',x=500,y=500,hp=4,prospected=true};check(not w:startGather(copper,a.player,a.skills,a.inv));Items.setEquipped(a,'tool',{name='Copper Pickaxe',qty=1,qualityGrade='A'});check(w:startGather(copper,a.player,a.skills,a.inv));w:stopGather()
Items.setEquipped(a,'tool',{name='Copper Axe',qty=1});check(w:startGather({kind='tree',x=500,y=500,hp=6},a.player,a.skills,a.inv));w:stopGather()
Items.setEquipped(a,'tool',{name='Copper Knife',qty=1});check(w:startGather({kind='hemp',x=500,y=500,hp=2},a.player,a.skills,a.inv));w:stopGather()
check(w:skinAnimal({kind='wolf',dead=true,x=500,y=500,level=1},a.player,a.skills,a.inv))
a.inv.bagSlots[1].slots={};a.inv:add('Swordfish',1);check(require('game.high_tier_fish').command(w,a,{op='fishProcess',bag=1,slot=1}));check(a.inv:countItem('Raw Swordfish')==1)
a.inv.bagSlots[1].slots={};a.inv:add('Lobster',1);check(require('game.shellfish').command(w,a,{op='shellFillet',bag=1,slot=1}));check(a.inv:countItem('Lobster Parts')==1)
local tested=0;for station,list in pairs(C:allRecipes())do for _,r in ipairs(list)do if r.tool=='Copper Dagger'or r.tool=='Copper Knife'then local trial=actor();trial.equipment.tool='Copper Knife';T.bind(trial);for _,need in ipairs(r.needs)do trial.inv:add(need[1],need[2])end;local ok,why=C:canCraft(r,trial.inv,trial.equipment.weapon,trial.skills);check(ok or r.placeholder or why~='missing_'..r.tool);tested=tested+1 end end end;check(tested>0)
-- Death and recovery carry exactly the equipped physical tool and its metadata.
a=actor();Items.setEquipped(a,'tool',{name='Copper Knife',qty=1,qualityGrade='A',customMark='grave'});local w={gravestones={},enemies={},groundItems={},addGroundItem=function(self,n,x,y,lit,obj)self.groundItems[#self.groundItems+1]={name=n,object=obj}end}
local g=G.die(w,a,'Wolf');check(g.contents.equipment.tool=='Copper Knife'and not a.equipment.tool);check(not T.has(a.inv,nil,'Copper Knife'))
check(G.recover(w,a,g));check(a.equipment.tool=='Copper Knife'and T.object(a).qualityGrade=='A'and T.object(a).customMark=='grave');check(T.has(a.inv,nil,'Copper Knife'))
return 'PASS '..count..' tool slot swaps, single-item/allowed-tool restrictions, busy/full-bag safety, metadata/save/death recovery, weapon isolation, gathering/skinning, fish/shellfish and crafting checks'
'''),flush=True)
finally:s.close()
