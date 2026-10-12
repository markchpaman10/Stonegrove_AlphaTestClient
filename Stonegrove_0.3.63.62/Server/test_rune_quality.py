from pathlib import Path
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent);s.stopped.set();s.thread.join()
try:
 print(s.eval(r'''
local R=require('game.rune_quality');local U=require('game.ui');local P=require('game.profile');local I=require('game.inventory');local S=require('game.skills');local Player=require('game.player');local M=require('game.magic_system');local Q=require('game.quality');local count=0
local function check(v)assert(v);count=count+1 end
local function ui()
 local p=Player.new();p.x,p.y=100,100;p.hp=10;p.maxHp=100;p.stamina=1000;p.maxStamina=1000
 local sk=S.new();sk.data.Magic.level=99
 local inv=I.new();for _,b in pairs(inv.bagSlots)do b.slots={}end
 local w={magicProjectiles={},combatTarget={x=120,y=100,hp=100},addPopup=function()end}
 local u=setmetatable({player=p,skills=sk,inv=inv,world=w,equipment={offhand='Spellbook'},equipmentSockets={},spellPages={'Fire Spell Page'}},{__index=U});return u
end
local b={name='Rune Bag',materials={['Carved Feather']=7}};R.ensure(b);check(b.materialGrades['Carved Feather'].C==7);R.ensure(b);check(b.materials['Carved Feather']==7)
check(R.deposit(b,{name='Carved Feather',blessed=true,qualityGrade='A',qty=10})==10);check(b.materialGrades['Carved Feather'].A==10 and b.materials['Carved Feather']==17)
local u=ui();u.equipment.ammo=b;u.inv.bagSlots[1].slots[1]={name='Carved Feather',qualityGrade='B',blessed=true,qty=3}
check(R.select(u,'Carved Feather')=='A');local ok,g=R.consume(u,'Carved Feather');check(ok and g=='A' and b.materials['Carved Feather']==16)
check(R.withdraw(b,'Carved Feather',u.inv));check(b.materials['Carved Feather']==0);check(u.inv:countBlessed('Carved Feather')==19);check(R.select(u,'Carved Feather')=='A')
check(u:storeBlessedInRuneBag('Carved Feather'));check(b.materialGrades['Carved Feather'].A==9 and b.materialGrades['Carved Feather'].B==3 and b.materialGrades['Carved Feather'].C==7)
local copy=P.unpack(P.pack(b));check(copy.materialGrades['Carved Feather'].A==9 and copy.materials['Carved Feather']==19)
for _,grade in ipairs({'D','C','B','A'})do
 for page,spell in pairs(M.spells)do
  local u=ui();u.spellPages[1]=page;u.inv.bagSlots[1].slots[1]={name=spell.rune,blessed=true,qualityGrade=grade,qty=2}
  check(M.cast(u,1));if spell.heal then check(u.player.healingPulseRuneFactor==Q.factors[grade]);local before=u.player.hp;require('game.abilities').update(u,.1);check(math.abs(u.player.hp-before-4*Q.factors[grade])<.001)
  else local q=u.world.magicProjectiles[1];check(q.runeGrade==grade);local base=spell.damage+9;check(math.abs(q.damage-math.floor(base*Q.factors[grade]*10+.5)/10)<.001)end
 end
end
local u=ui();u.inv.bagSlots[1].slots[1]={name='Charred Wood',blessed=true,qty=1};check(M.cast(u,1));check(u.world.magicProjectiles[1].damage==12)
local u=ui();u.inv.bagSlots[1].slots[1]={name='Charred Wood',blessed=false,qualityGrade='A'};check(not M.cast(u,1));check(not R.select(u,'Charred Wood'))
local u=ui();u.inv.bagSlots[1].slots[1]={name='Charred Wood',blessed=true,qualityGrade='A',qty=2};u.player.stamina=0;check(not M.cast(u,1));check(u.inv.bagSlots[1].slots[1].qty==2)
local u=ui();u.skills.data.Religion.level=99;u.inv.bagSlots[1].slots[1]={name='Charred Wood',blessed=true,qualityGrade='A',qty=2};local old=math.random;math.random=function()return 0 end;check(M.cast(u,1));math.random=old;check(u.inv.bagSlots[1].slots[1].qty==2);check(u.world.magicProjectiles[1].runeGrade=='A')
local u=ui();u.equipment.ammo={name='Rune Bag',materials={['Charred Wood']=1},materialGrades={['Charred Wood']={D=1}}};u.inv.bagSlots[1].slots[1]={name='Charred Wood',blessed=true,qualityGrade='A',qty=1};check(R.select(u,'Charred Wood')=='D');check(u:consumeSpellRuneMaterial('Charred Wood',1));check(R.select(u,'Charred Wood')=='A')
local u=ui();for _,bag in pairs(u.inv.bagSlots)do for i=1,bag.size do bag.slots[i]={name='Copper Axe',qty=1}end end;local b={name='Rune Bag',materials={['Fish Bones']=1},materialGrades={['Fish Bones']={A=1}}};check(not R.withdraw(b,'Fish Bones',u.inv));check(b.materials['Fish Bones']==1 and b.materialGrades['Fish Bones'].A==1)
local u=ui();u.skills.data.Magic.level=1;u.inv.bagSlots[1].slots[1]={name='Charred Wood',blessed=true,qualityGrade='A',qty=2};local old=math.random;math.random=function()return 1 end;check(not M.cast(u,1));math.random=old;check(u.inv.bagSlots[1].slots[1].qty==2)
local u=ui();u.equipment.ammo={name='Rune Bag',materials={['Fish Bones']=49}};u.log=function()end;u.inv.bagSlots[1].slots[1]={name='Fish Bones',blessed=true,qualityGrade='A',qty=5};check(u:depositIntoAmmoContainer(1,1,2));check(u.inv.bagSlots[1].slots[1].qty==4);check(u.equipment.ammo.materialGrades['Fish Bones'].A==1 and u.equipment.ammo.materialGrades['Fish Bones'].C==49);check(not u:depositIntoAmmoContainer(1,1,2));check(u:withdrawAmmoContainerSlot(2));check(u.inv:countBlessed('Fish Bones')==54)
local u=ui();u.skills.data['Melee Combat'].level=99;u.player.healingPulseRuneFactor=1.4;check(require('game.abilities').cast(u,'Healing Pulse'));check(u.player.healingPulseRuneFactor==1)
local u=ui();u.log=function()end;u.equipment.ammo={name='Rune Bag',materials={['Cave Snake Fang']=2}};u.inv.bagSlots[1].slots[1]={name='Cave Snake Fang',blessed=true,qualityGrade='A',qty=3};check(u:storeBlessedInRuneBag('Cave Snake Fang'));check(u.equipment.ammo.materialGrades['Cave Snake Fang'].C==2 and u.equipment.ammo.materialGrades['Cave Snake Fang'].A==3);check(u:withdrawAmmoContainerSlot(7));check(u.inv:countBlessed('Cave Snake Fang')==5)
return 'PASS '..count..' rune quality, all spell grades, healing, storage, migration, preservation and atomic withdrawal checks'
'''))
finally:s.close()
