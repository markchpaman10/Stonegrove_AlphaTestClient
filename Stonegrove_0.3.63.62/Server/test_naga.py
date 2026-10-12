"""Naga authoritative gameplay regression; no production database writes."""
from pathlib import Path
from simulation import Simulation
root=Path(__file__).resolve().parent.parent
s=Simulation(root)
try:
 print(s.eval(r'''
local N=require('game.naga_queen');local w=SG_SERVER.world;local count=0
local function check(v,m)assert(v,m);count=count+1 end
local q;for _,e in ipairs(w.enemies)do if e.kind=='nagaQueen'then q=e end end
check(q==nil,'No automatic Queen');local x,y;for yy=160,w.map.height-160,160 do for xx=160,w.map.width-160,160 do if not x and N.allowed(w,xx,yy)and not w:enemyBlocked(xx,yy)then x,y=xx,yy end end end;check(x~=nil,'Safe editor placement');local authored=require('game.rune_inventory').copy(w.map.authored);authored.spawnZones={{enemy='nagaQueen',x=x-32,y=y-32,w=64,h=64,count=1,level=12}};local placed=require('game.world').new(SG_SERVER.sprites,authored);for _,e in ipairs(placed.enemies)do if e.kind=='nagaQueen'then q=e end end;assert(q,'Editor Queen placed');q.editorSpawnZone=1;w.enemies[#w.enemies+1]=q;check(q.level==12 and q.maxHp==300,'Level 12 boss stats');check(N.allowed(w,q.x,q.y),'Safe spawn')
for _,v in ipairs(w.villages)do check(not N.allowed(w,v.cx,v.cy),'Town excluded')end
for i=1,math.min(20,#w.paths)do local p=w.paths[i];check(not N.allowed(w,p.x+p.w/2,p.y+p.h/2),'Path excluded')end
for i=1,8 do check(SG_SERVER.sprites.nagaQueen[i]~=nil,'Art loaded')end
local a=require('game.rune_inventory').copy(w.map.authored);a.spawnZones={{enemy='nagaQueen',x=q.x-64,y=q.y-64,w=128,h=128,count=1,level=99}}
local zoned=require('game.world').new(SG_SERVER.sprites,a);local queens=0;for _,e in ipairs(zoned.enemies)do if e.kind=='nagaQueen'then queens=queens+1;check(e.level==99 and e.editorSpawnZone==1,'Authored boss zone preserves selected level 99')end end;check(queens==1,'Authored zone suppresses automatic duplicate')
local v=w.villages[1];a.spawnZones={{enemy='nagaQueen',x=v.cx-16,y=v.cy-16,w=32,h=32,count=1,level=12}};local bad=require('game.world').new(SG_SERVER.sprites,a);queens=0;for _,e in ipairs(bad.enemies)do if e.kind=='nagaQueen'then queens=queens+1 end end;check(queens==0,'Town boss zone rejected without automatic fallback')
local p=require('game.player').new();p.x,p.y=q.x-30,q.y;p.hp=200;p.maxHp=200;local sk=require('game.skills').new();w.playerRef=p;w.nagaPlayerSkills=sk
local original=w.enemies;w.enemies={q};w.sheep={};w.guards={};w.mercs={};w.nodes={{kind='tree',x=q.x+3,y=q.y,hp=6,maxHp=6,snowCovered=true},{kind='oak',x=q.x+5,y=q.y,hp=9,maxHp=9},{kind='copper',x=q.x+8,y=q.y,hp=4,maxHp=4,shake=0}};require('game.node_index').invalidate(w)
local before=#w.groundItems;check(N.breakTrees(w,q.x,q.y,20)==2,'Tree destruction');check(w.nodes[1].depleted and w.nodes[1].stumpSnow and w.nodes[1].respawnTimer==300,'Pine stump/respawn');check(w.nodes[2].respawnTimer==600 and not w.nodes[3].depleted,'Oak lifecycle / ore preserved');check(#w.groundItems==before+2,'Logs produced');check(N.breakTrees(w,q.x,q.y,20)==0 and #w.groundItems==before+2,'No duplicate tree drops')
q.nagaPhase='rest';q.nagaTimer=8;q.nagaCycle=0
N.turn(w,q,7,p,sk);check(q.nagaPhase=='rest'and p.hp==200,'Seven seconds no attack');N.turn(w,q,1.01,p,sk);check(q.nagaPhase=='windup'and q.nagaAttack=='head','Head windup');N.turn(w,q,1.2,p,sk);check(p.hp==200,'Windup does not deal damage');N.turn(w,q,.21,p,sk);check(p.hp<200 and q.nagaPhase=='recover','Head hit once');local hp=p.hp;N.turn(w,q,.3,p,sk);check(p.hp==hp,'Recovery no duplicate damage');N.turn(w,q,.41,p,sk);check(q.nagaPhase=='rest'and q.nagaTimer==8,'Full rest after hit')
N.turn(w,q,8.01,p,sk);check(q.nagaAttack=='tail','Tail rotation');N.turn(w,q,1.41,p,sk);check(p.hp<hp,'Tail damage');N.turn(w,q,.71,p,sk);N.turn(w,q,8.01,p,sk);check(q.nagaAttack=='magic','Magic rotation');local effects=#w.magicEffects;N.turn(w,q,1.41,p,sk);check(#w.bossShots>0 and w.bossShots[#w.bossShots].spellName=='Water Bolt','Actual Water Bolt launched');N.updateSpells(w,1,p);check(#w.magicEffects>effects,'Water Bolt impact')
local victim=w.makeExpansionEnemy('wolf',q.x+20,q.y,1);w.enemies={q,victim};q.nagaAttack='tail';q.nagaAimX=q.x;q.nagaAimY=q.y;N.strike(w,q,p);check(victim.dead and victim.hp==0 and victim.respawnTimer>0,'Kills other creatures using corpse state');check(sk:get('Melee Combat').xp==0,'No player XP from boss creature kills')
local px,py=p.x,p.y;p.x=q.x-30;p.y=q.y-20;q.nagaAttack='head';q.nagaAimX=p.x;q.nagaAimY=p.y;p.x=p.x-150;hp=p.hp;N.strike(w,q,p);check(p.hp==hp,'Dodge locked head aim')
local tree=w.nodes[1];tree.respawnTimer=.01;w:update(.1,p,require('game.inventory').new(),sk);check(not tree.depleted and tree.hp==tree.maxHp,'Normal resource regrowth')
p.x=q.x+500;p.y=q.y;local origin=q.x;q.nagaPhase='rest';q.nagaTimer=0;q.roamX=q.x+100;q.roamY=q.y;q.roamTimer=100;w.nodes={{kind='tree',x=q.x+3,y=q.y,hp=6,maxHp=6,shake=0,depleted=false}};require('game.node_index').invalidate(w);N.turn(w,q,.2,p,sk);check(q.x>origin and w.nodes[1].depleted,'Walking tramples trees')
local land=w.map.isLand;origin=q.x;w.map.isLand=function()return false end;N.turn(w,q,.2,p,sk);check(q.x==origin and not q.nagaMoving,'Water blocks boss movement');w.map.isLand=land
local ox,oy=q.x,q.y;q.x=80;q.y=500;q.roamX=0;q.roamY=500;q.roamTimer=100;p.x=1000;p.y=1000;N.turn(w,q,1,p,sk);check(q.x==80,'Boss stays within owning map');q.x,q.y=ox,oy
q.dead=true;q.hp=0;q.respawnTimer=1;w:updateCombat(.1,p,sk,{},SG_SERVER.sprites,nil,{},require('game.inventory').new());check(q.respawnTimer>890,'Boss death sets long respawn');local start=q.x;N.turn(w,{kind='rat'},.1,p,sk);check(q.x==start,'Normal monsters unaffected')

local R=require('game.religion');local unlocks=R.unlocks();check(#unlocks==10 and unlocks[10].level==99,'Spaced progression to 99')
for i,row in ipairs(unlocks)do
 sk:get('Religion').level=row.level;check(R.level(sk)==row.level,'Real Religion level preserved');check(row.detail:find('Total effects',1,true),'Tier description');check(R.physicalDamage(sk,100)>100,'Working physical bonus')
 if i>1 then check(R.attackCooldown(sk,1)>1,'Working slowdown tradeoff');check(R.physicalTaken(sk,100)<100,'Working protection')end
 if i<#unlocks then local m=R.modifiers(sk);sk:get('Religion').level=unlocks[i+1].level-1;check(R.modifiers(sk)==m,'No per-level passive increase')end
end
sk:get('Religion').level=99;check(math.abs(R.magicDamage(sk,100)-112)<.001,'Level99 spell bonus');check(R.spellXP(sk)==3,'High tier spell XP')
q.dead=false;q.hp=q.maxHp;w.enemies={q};w.onlineActors=nil;w.playerRef=p;p.hp=200;p.x=q.x+100;p.y=q.y-35
local oldBlocked=w.projectileBlocked;w.projectileBlocked=function()return false end
q.nagaAttack='magic';q.nagaAimX=p.x;q.nagaAimY=p.y;w.bossShots={};N.strike(w,q,p);check(p.hp==200,'Spell is not instant damage');local bolt=w.bossShots[1];check(bolt.row==require('game.magic_system').spells['Water Spell Page'].row,'Uses actual spell row');N.updateSpells(w,.1,p);check(p.hp==200 and #w.bossShots==1,'Bolt travels before damage');N.updateSpells(w,1,p);check(p.hp==197 and #w.bossShots==0,'Actual Water Bolt hit once')
p.hp=200;w.bossShots={};N.strike(w,q,p);p.y=p.y+60;N.updateSpells(w,1,p);check(p.hp==200,'Moving dodges bolt')
p.y=q.y-35;q.nagaAimY=p.y;N.strike(w,q,p);w.projectileBlocked=function()return true end;N.updateSpells(w,1,p);check(p.hp==200 and #w.bossShots==0,'Terrain blocks bolt');w.projectileBlocked=oldBlocked
w.groundItems={};q.nagaLootDropped=nil;local rng=math.random;math.random=function(a,b)if a==1 and b==4 then return 4 end;return rng(a,b)end;N.onDeath(w,q);math.random=rng
local hides,bones=0,0;for _,v in ipairs(w.groundItems)do if v.name=='Raw Cave Snake Hide'then hides=hides+1 elseif v.name=='Bones'then bones=bones+1 end end;check(hides==5 and bones==10,'Exact guaranteed boss drops');local qty=#w.groundItems;N.onDeath(w,q);check(#w.groundItems==qty,'Death cleanup cannot duplicate loot')
w.groundItems={};q.nagaLootDropped=nil;math.random=function(a,b)return 1 end;N.onDeath(w,q);math.random=rng;check(#w.groundItems==16,'Optional potion');check(SG_SERVER.sprites.itemInfo[w.groundItems[16].name].type=='Potion','Existing potion item')
return tostring(count)..' Naga Queen authoritative rule checks passed'
'''))
finally:s.close()

