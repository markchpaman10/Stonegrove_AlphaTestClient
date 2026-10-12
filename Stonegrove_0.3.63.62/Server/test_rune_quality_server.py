from pathlib import Path
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent);s.stopped.set();s.thread.join()
try:
 print(s.eval(r'''
local J=require('game.json');local P=require('game.profile');local Q=require('game.quality');local regions=require('game.regions');local w=SG_SERVER.world;w.enemies={};local checks=0
for gi,grade in ipairs({'D','C','B','A'})do
 local sk=require('game.skills').new();sk.data.Magic.xp=sk.xpTable[99];sk.data.Magic.level=99;local inv=require('game.inventory').new();local p=require('game.player').new();p.x,p.y=500,500;p.hp=10;p.maxHp=100;p.stamina=100;p.maxStamina=100
 local bag={name='Rune Bag',materials={['Charred Wood']=2,['Green Slime Tube']=2},materialGrades={['Charred Wood']={[grade]=2},['Green Slime Tube']={[grade]=2}}}
 local state={player=p,skills=sk.data,bags=inv.bagSlots,equipment={offhand='Spellbook',ammo=bag},equipmentItems={},equipmentSockets={},spellPages={'Fire Spell Page','Healing Spell Page'}}
 local target={netId='rune-qa-'..gi,kind='slime',x=520,y=500,hp=100,maxHp=100};w.enemies[#w.enemies+1]=target
 local b={id=700+gi,owner='qa',slot=1,name='Rune QA',race='Human',worldId=regions.doc.worldId,regionId=regions.start,area='overworld',initial=true,seq=1,personal=P.pack(state),action={kind='spell',slot=1,target=target.netId}}
 local reply=J.decode(SG_CALL('exchange',J.encode(b)));assert(reply.result.ok,reply.result.message);local actual=P.unpack(reply.personal);assert(actual.equipment.ammo.materialGrades['Charred Wood'][grade]==1);local projectile=w.magicProjectiles[#w.magicProjectiles];assert(projectile.runeGrade==grade and projectile.damage==math.floor(12*Q.factors[grade]*10+.5)/10);checks=checks+3
 b.id=b.id+100;b.personal=P.pack(state);b.action={kind='spell',slot=2};reply=J.decode(SG_CALL('exchange',J.encode(b)));assert(reply.result.ok,reply.result.reason);actual=P.unpack(reply.personal);assert(actual.player.healingPulseRuneFactor==Q.factors[grade]);assert(actual.equipment.ammo.materialGrades['Green Slime Tube'][grade]==1);checks=checks+3
end
return 'PASS '..checks..' multiplayer server cast, graded Rune Bag consumption, projectile damage and healing-state checks'
'''))
finally:s.close()
