from pathlib import Path
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent)
try:
 print(s.eval(r'''
local N=require('game.nagalians');local w=SG_SERVER.world;local count=0
local function check(v,m)assert(v,m);count=count+1 end
check(require('game.naga_queen').spawn==nil,'No automatic queen API')
local hi=select(2,require('game.level_zones').range(w.map));local wild,camps=0,0
for _,e in ipairs(w.enemies)do
 check(e.kind~='nagaQueen'or e.editorSpawnZone,'No automatic queen in generated world')
 if e.kind=='nagalian'then check(e.level==hi,'Highest map level');check(not e.nightOnly and not e.dayOnly,'Both day and night');check(e.headVariant>=1 and e.headVariant<=2 and e.bodyVariant>=1 and e.bodyVariant<=2,'Independent variant bounds');local _,required=require('game.progression').requirement(e.weapon,w.sprites.itemInfo[e.weapon]);check(required<=hi,'Weapon meets level');if e.campId then camps=camps+1 else wild=wild+1 end end
end
check(wild>0,'Wilderness population');check(camps>0,'Camp population')
local e=w.makeExpansionEnemy('nagalian',100,100,1);local I=require('game.inventory');local K=require('game.skills');local inv=I.new();inv.bagSlots[1].size=100;local sk=K.new();local p={x=100,y=100,equipped='Copper Dagger'}
for _,level in ipairs({1,20,21,40,41,60,61,80,81,99})do
 e.dead=true;e.skinned=false;sk.data.Skinning.level=level;local before=inv:countItem('Raw Cave Snake Hide');local xp=sk.data.Skinning.xp
 check(w:skinAnimal(e,p,sk,inv),'Skinnable');local qty=math.min(5,1+math.floor((level-1)/20));check(inv:countItem('Raw Cave Snake Hide')==before+qty,'Exact tier skin quantity');check(sk.data.Skinning.xp>xp,'XP awarded');check(not w:skinAnimal(e,p,sk,inv),'No duplicate skins')
end
e.skinned=false;p.x=200;check(not w:skinAnimal(e,p,sk,inv),'Distance gate');p.x=100;p.equipped='';inv:removeAllItems('Copper Dagger');inv:removeAllItems('Copper Knife');check(not w:skinAnimal(e,p,sk,inv),'Knife gate');p.equipped='Copper Dagger'
local full=I.new();full.bagSlots[1].size=1;full:add('Pine Logs',1);check(not w:skinAnimal(e,p,sk,full),'Full bag gate');check(not e.skinned,'Full bag preserves corpse')
e.dead=false;check(not w:skinAnimal(e,p,sk,inv),'Living enemy gate')
local info=N.weaponInfo({weapon='Copper Dagger',level=30},w.sprites);check(require('game.combat').maxDamage(info,30)>=18,'Level30 damage uses NPC level despite Copper weapon');local low=N.weaponInfo({weapon='Copper Dagger',level=6},w.sprites);check(require('game.combat').maxDamage(low,6)<require('game.combat').maxDamage(info,30),'Damage rises with enemy level');local seen={};for i=1,200 do N.appearance(e);seen[e.headVariant..':'..e.bodyVariant]=true end;for _,key in ipairs({'1:1','1:2','2:1','2:2'})do check(seen[key],'All head-body combinations '..key)end
local ground={};local drops={addGroundItem=function(_,name)ground[#ground+1]=name end};e.lootDropped=nil;require('game.goblins').drop(drops,e);local n=#ground;require('game.goblins').drop(drops,e);check(#ground==n,'Loot paid once')
for _,style in ipairs({'bow','magic'})do e.x=100;e.y=100;e.level=hi;e.stats={ranged=hi,strength=hi};e.weapon=style=='bow'and'Pine Bow'or'Pine Staff';e.nagalianStyle=style;e.attackTimer=0;e.arrows=10;check(N.rangedTurn(w,e,{x=150,y=100},2500),'Ranged attack');local q=w.goblinArrows[#w.goblinArrows];check(q and q.damage~=nil,'Actual projectile');check((q.magic==true)==(style=='magic'),'Projectile style')end
local corpse=w.makeExpansionEnemy('nagalian',100,100,1);corpse.dead=true;w.enemies[#w.enemies+1]=corpse;check(w:animalCarcassAt(100,100)==corpse,'Carcass selection')
local oldmap=w.map;w.map={authored={mapInfo={levelMin=30,levelMax=45},levelZones={{x=0,y=0,w=1000,h=1000,level=2}}}};N.configure(w,corpse);check(corpse.level==45 and corpse.hp==225,'Map maximum ignores lower resource zone');w.map=oldmap
local oldEnemies=w.enemies;local oldCamps=w.goblinCamps;w.goblinCamps={};local enemy=w.makeExpansionEnemy('nagalian',100,100,1);enemy.level=30;enemy.stats={melee=30,ranged=30,strength=30,health=30,agility=30};enemy.weapon='Copper Dagger';enemy.nagalianStyle='melee';enemy.aggro=true;enemy.attackTimer=0;enemy.hp=150;enemy.maxHp=150;w.enemies={enemy};w.combatTarget=nil;w.targetedEnemy=nil;local victim=require('game.player').new();victim.x=100;victim.y=100;victim.hp=90;local vs=K.new();for _,name in ipairs({'Health','Agility','Melee Combat','Strength'})do vs.data[name].level=16;vs.data[name].xp=vs.xpTable[16]end;local eq={head='Copper Helm',body='Copper Armor'};local random=math.random;math.random=function(a,b)if a then return b or a end;return .5 end;w:updateCombat(0,victim,vs,eq,w.sprites,nil,{});math.random=random;check(victim.hp<=80,'Actual level30 melee hit harms level16 armored player');w.enemies=oldEnemies;w.goblinCamps=oldCamps;
return 'PASS '..count..' Nagalian generation/weapon/appearance/skinning/loot/projectile checks'
'''))
finally:s.close()
