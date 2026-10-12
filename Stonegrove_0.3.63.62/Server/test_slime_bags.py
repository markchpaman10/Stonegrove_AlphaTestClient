from pathlib import Path
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent)
try:
 print(s.eval(r"""
local w=SG_SERVER.world;local I=require('game.inventory');local Skills=require('game.skills');local Player=require('game.player');local P=require('game.party');local M=require('game.slime_minions');local checks=0;local function check(v,msg)assert(v,msg);checks=checks+1 end
local inv=I.new();inv.bagSlots[2]={name='Large Linen Bag',qualityGrade='D',slots={{name='Pine Logs',qty=1}}};inv.bagSlots[3]={name='Small Leather Bag',qualityGrade='A',slots={}};for _,lv in ipairs({1,10,90,98,99})do inv:applyStrengthBagBonus(lv);local bonus=math.floor(lv/10);check(inv.bagSlots[1].size==5+bonus and inv.bagSlots[2].size==6+bonus and inv.bagSlots[3].size==6+bonus,'All equipped bags scale at '..lv)end
inv:applyStrengthBagBonus(99);check(inv.bagSlots[1].size==14 and inv.bagSlots[2].slots[1].name=='Pine Logs','Repeat application does not inflate size or lose items');local found;for _,row in ipairs(require('game.unlocks').list('Strength',require('game.crafting').new()))do if row.level==99 and row.text:find('fourth',1,true)then found=true end end;check(found,'Strength99 guide')
local boss=w.makeExpansionEnemy('slimeBoss',100,100,1);boss.aggro=true;boss.inactive=false;boss.attackTimer=9999;boss.specialCooldown=9999;boss.summonCooldown=9999
local minion=w.makeExpansionEnemy('slime',100,100,1);minion.summoned=true;minion.inactive=false;minion.stats={melee=20,ranged=20,strength=20,agility=20,health=20};minion.attackTimer=0;M.link(boss,minion)
local victim=Player.new();victim.x=110;victim.y=100;victim.hp=100;victim.onlineId=101;local bystander=Player.new();bystander.x=100;bystander.y=100;bystander.hp=100;bystander.onlineId=102
local sk=Skills.new();sk.data.Health.level=20;sk.data.Health.xp=sk.xpTable[20];w.enemies={boss,minion};w.mercs={};w.goblinCamps={};w.combatTarget=nil;w.targetedEnemy=nil;w.onlineActors={{player=bystander,skills=sk,equipment={}},{player=victim,skills=sk,equipment={}}};P.threat(w,boss,victim,1,true)
check(M.follow(w,minion,bystander)==victim and P.target(minion)==victim,'Minion follows boss threat instead of nearer bystander')
local random=math.random;math.random=function(a,b)if a then return b or a end;return .5 end;w:updateCombat(0,bystander,sk,{},w.sprites,nil,{});math.random=random;check(victim.hp<100 and bystander.hp==100,'Actual online minion attack damages Kings target only')
P.threat(w,boss,bystander,0,true);check(M.follow(w,minion,victim)==bystander,'Minion follows target switch');bystander.hp=0;check(M.follow(w,minion,victim)==victim,'Dead target replaced by living player')
local merc={x=110,y=100,hp=100,maxHp=100,equipment={},combatSkills={}};P.threat(w,boss,merc,0,true);check(M.follow(w,minion,victim)==merc,'Mercenary tank target inherited');minion.attackTimer=0;math.random=function(a,b)if a then return b or a end;return .5 end;check(P.enemyTurn(w,minion,0)and merc.hp<100,'Minion attacks mercenary target');math.random=random
boss.dead=true;check(M.follow(w,minion,victim)==nil and P.target(minion)==nil,'Dead boss clears inherited target');boss.dead=false;boss.aggro=true;local legacy={summoned=true,x=100,y=100};check(M.follow(w,legacy,victim)~=nil and legacy.minionBossId==boss.minionBossId,'Existing minion links to nearby boss')
w.onlineActors=nil;P.setTarget(boss,nil);check(M.target(w,boss,victim)==victim,'Offline player target');boss.summonCooldown=0;boss.specialCooldown=9999;w.enemies={boss};local oldLand=w.map.isLand;local oldBlocked=w.enemyBlocked;w.map.isLand=function()return true end;w.enemyBlocked=function()return false end;require('game.expansion').update(w,0,victim);w.map.isLand=oldLand;w.enemyBlocked=oldBlocked;local summoned=0;for _,m in ipairs(w.enemies)do if m.summoned then summoned=summoned+1;check(m.minionBossId==boss.minionBossId and P.target(m)==victim,'Actual summon links to Kings target')end end;check(summoned>=2 and summoned<=3,'Actual summon count');
return 'PASS '..checks..' Strength99 bag and Slime King minion targeting checks'
"""))
finally:s.close()
