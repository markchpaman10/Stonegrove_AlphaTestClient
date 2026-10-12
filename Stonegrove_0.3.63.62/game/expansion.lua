local E={}
E.defs={
 slimeBoss={baseLevel=20,tierMin=1,tierMax=1,melee=8,ranged=8,strength=6,agility=2,health=30,mainSkill='Ranged',aggro=190,leash=280,roam=25,speed=16,attackRange=35,rangedRange=180,attackSpeed=2.5},
 gigaRat={baseLevel=15,tierMin=1,tierMax=1,melee=7,ranged=0,strength=6,agility=3,health=18,mainSkill='Melee Combat',aggro=110,leash=220,roam=45,speed=30,attackRange=42,rangedRange=0,attackSpeed=1.8},
 boar={baseLevel=6,tierMin=1,tierMax=2,melee=4,ranged=0,strength=4,agility=2,health=5,mainSkill='Melee Combat',aggro=80,leash=150,roam=45,speed=31,attackRange=28,rangedRange=0,attackSpeed=1.6}
}
E.defs.caveSnake=require('game.cave_snake').def
E.defs.nagalian=require('game.nagalians').def
E.defs.nagaQueen=require('game.naga_queen').def
E.defs.skeleton=require('game.dark_content').defs.skeleton
E.defs.ghost=require('game.dark_content').defs.ghost
E.heals={['Cooked Giga Rat Meat D']=30,['Cooked Giga Rat Meat C']=40,['Cooked Giga Rat Meat B']=50,['Cooked Giga Rat Meat A']=60,['Burnt Giga Rat Meat']=1}
function E.load(s)
 local image=love.graphics.newImage('assets/masterSheet.png');image:setFilter('nearest','nearest')
 local function part(x,y,w,h) return {image=image,quad=love.graphics.newQuad(x,y,w,h,image:getDimensions()),w=w,h=h} end
 s.expansion={boss=part(240,32,32,32),rat=part(192,80,96,32),
  boars={part(256,144,32,16),part(288,144,32,16)},wolves={part(192,160,32,16),part(224,160,32,16)},
  minions={part(224,64,16,16),part(240,64,16,16)},coating=part(208,64,16,16),
  shots={part(208,48,16,16),part(224,48,16,16)},pools={part(272,48,16,16),part(288,48,32,16)}}
 local function item(name,x,y,typ,detail,heal)
  s.itemImages[name]=image;s.itemQuads[name]=part(x,y,16,16).quad
  s.itemInfo[name]={title=name,type=typ,detail=detail,heal=heal}
 end
 item('Potent Slime Jar',256,64,'Alchemy Material','Concentrated boss slime. Stronger than ordinary slime; used for potent antidotes.')
 item('Slime-coated Bones',272,64,'Alchemy Material','A boss-slime reagent for potent antidotes.')
 item('Pickled Large Meat',288,64,'Alchemy Material','Slime-preserved meat used in restorative alchemy.')
 item('Pickled Small Meat',304,64,'Alchemy Material','Slime-preserved meat used in restorative alchemy.')
 item('Giga Rat Blood',272,112,'Alchemy Material','Concentrated blood used in restorative alchemy.')
 item('Giga Rat Meat',288,96,'Raw Food','Requires Cooking 20. Grade D heals 30 HP; better grades heal up to 60.')
 item('Extra Large Raw Hide',304,112,'Skinned Hide','Soak in a tanning vat, then stretch into extra-large leather.')
 item('Extra Large Soaked Hide',288,112,'Material','Ready for a hide stretcher.')
 item('Extra Large Leather',304,96,'Material','Can be cut into four ordinary leather pieces.')
 for name,heal in pairs(E.heals) do item(name,name:match('^Burnt') and 288 or 304,80,name:match('^Burnt') and 'Burnt Food' or 'Food','Restores '..heal..' health.',heal) end
 item('Potent Health Flask',272,112,'Food','A powerful alchemical restorative. Restores 80 health.',80)
 item('Potent Antidote',256,64,'Food','Clears poison and slime coating; grants 15 seconds of poison immunity.')
end
function E.drawPart(part,x,y,flip,angle)
 love.graphics.draw(part.image,part.quad,x,y,angle or 0,flip or 1,1,part.w/2,part.h/2)
end
function E.enemyPart(s,e)
 if e.kind=='slimeBoss' then return s.expansion.boss end
 if e.kind=='gigaRat' then return s.expansion.rat end
 if e.kind=='boar' then return s.expansion.boars[e.variant or 1] end
 if e.kind=='wolf' then return s.expansion.wolves[e.variant or 1] end
 if e.summoned then return s.expansion.minions[e.variant or 1] end
end
function E.clearVillage(world,x,y,margin)
 for _,v in ipairs(world.villages or {}) do
  if v.fenceBounds and require('game.fences').inside(v.fenceBounds,x,y,-(margin or 0)) then return false end
  if math.abs(x-v.cx)<500+(margin or 0) and math.abs(y-v.cy)<245+(margin or 0) then return false end
 end
 return true
end
function E.populate(world,makeEnemy)
 world.bossShots={};world.bossPools={}
 world.makeExpansionEnemy=makeEnemy
 local kinds={'slimeBoss','gigaRat','gigaRat','boar','boar','boar','boar','boar','boar','boar','wolf','wolf','wolf','wolf'}
 for _,kind in ipairs(kinds) do
  for attempt=1,1000 do
   local x,y=math.random(120,world.map.width-120),math.random(120,world.map.height-120)
   local zone=require('game.zones').at(world.map,x,y)
   local zoneOK=(kind=='slimeBoss' or kind=='gigaRat') and zone==3 or (kind~='slimeBoss' and kind~='gigaRat')
   if zoneOK and E.clearVillage(world,x,y,50) and not world:enemyBlocked(x,y) and world.map:isLand(x-40,y) and world.map:isLand(x+40,y) then
    local e=makeEnemy(kind,x,y,1);e.zone=zone;e.variant=math.random(1,2);e.hitRadius=kind=='gigaRat' and 30 or (kind=='slimeBoss' and 20 or 14)
    e.specialCooldown=4;e.summonCooldown=8;if kind=='slimeBoss' or kind=='gigaRat' or kind=='wolf' then e.nightOnly=true;e.inactive=true elseif kind=='boar' then e.dayOnly=true end;world.enemies[#world.enemies+1]=e;break
   end
  end
 end
end
function E.skin(world,e,player,skills,inv)
 if not (world.isCave and e.kind=='rat') and e.kind~='caveSnake' and e.kind~='gigaRat' and e.kind~='boar' then return nil end
 if not e.dead or e.skinned then return false,'not_skinnable' end
 if (e.x-player.x)^2+(e.y-player.y)^2>70^2 then return false,'too_far' end
 if player.equipped~='Copper Dagger' and player.equipped~='Copper Knife' and not inv:hasItem('Copper Dagger') and not inv:hasItem('Copper Knife') then return false,'missing_Copper_Dagger_or_Copper_Knife' end
 local drops=e.skinDrops
 if not drops then
  drops=e.kind~='boar' and require('game.cave_loot').ensure(e).skin or {{'Large Raw Leather',1},{'Large Meat',math.random(2,3)}}
  e.skinDrops=drops
 end
 local needed=0;for _,d in ipairs(drops) do needed=needed+d[2] end
 if inv:totalFreeSlots()<needed then return false,'bag_full' end
 for _,d in ipairs(drops) do assert(inv:add(d[1],d[2])) end
 local meatXP=0;for _,d in ipairs(drops)do if d[1]:find('Meat',1,true)then meatXP=meatXP+4*d[2]end end;skills:addXP('Skinning',meatXP)
 e.skinned=true;skills:addXP('Skinning',e.kind=='caveSnake' and 90 or e.kind=='gigaRat' and 60 or 30)
 world:addPopup(e.x,e.y-25,'SKINNED','defeat');return true,drops[1][1]
end
local function hitSegment(x1,y1,x2,y2,x,y,r)
 local dx,dy=x2-x1,y2-y1;local len=dx*dx+dy*dy
 local t=len>0 and math.max(0,math.min(1,((x-x1)*dx+(y-y1)*dy)/len)) or 0
 return (x1+dx*t-x)^2+(y1+dy*t-y)^2<=r*r
end
function E.update(world,dt,player)
 require('game.cave_snake').update(world,dt)
 world.bossShots=world.bossShots or {};world.bossPools=world.bossPools or {}
 local targets={player};if world.onlineActors then targets={};for _,a in ipairs(world.onlineActors)do targets[#targets+1]=a.player end end;for _,m in ipairs(world.mercs) do if require("game.party").present(world,m) then targets[#targets+1]=m end end
 for _,t in ipairs(targets) do
  local remaining=t.slimeCoated or 0
  if remaining>0 then
   t.slimeBreathTick=(t.slimeBreathTick or 0)+math.min(dt,remaining)
   while t.slimeBreathTick>=1 do
    t.slimeBreathTick=t.slimeBreathTick-1;t.hp=math.max(0,(t.hp or 0)-1)
    world:addPopup(t.x,t.y-20,'SUFFOCATING 2','damage')
   end
  end
  t.slimeCoated=math.max(0,remaining-dt)
  if t.slimeCoated<=0 then t.slimeBreathTick=0 end
 end
 for _,e in ipairs(world.enemies) do
  local player=player;if world.onlineActors then local best;for _,a in ipairs(world.onlineActors)do local d=(a.player.x-e.x)^2+(a.player.y-e.y)^2;if not best or d<best then player,best=a.player,d end end end
  if not e.inactive and e.dead and not e.expansionLoot then
   e.expansionLoot=true
   if e.kind=='slimeBoss' then
    require('game.cave_loot').drop(world,e)
    e.respawnTimer=600
   elseif e.kind=='gigaRat' then require('game.cave_loot').drop(world,e);e.respawnTimer=420
   elseif e.kind=='boar' then e.respawnTimer=240 end
  elseif not e.inactive and not e.dead and e.kind=='slimeBoss' and e.aggro then
   player=require('game.slime_minions').target(world,e,player)or player;e.specialCooldown=(e.specialCooldown or 4)-dt;e.summonCooldown=(e.summonCooldown or 8)-dt
   if e.specialCooldown<=0 and (player.x-e.x)^2+(player.y-e.y)^2<200^2 then
    e.specialCooldown=3;e.shotVariant=(e.shotVariant or 0)%2+1
    local dx,dy=player.x-e.x,player.y-e.y;local d=math.max(1,math.sqrt(dx*dx+dy*dy))
    require("game.audio").play("slime_projectile",e.x,e.y);world.bossShots[#world.bossShots+1]={x=e.x,y=e.y,vx=dx/d*95,vy=dy/d*95,time=d/95,variant=e.shotVariant}
   end
   if e.summonCooldown<=0 then
    e.summonCooldown=14;local count=0
    for _,m in ipairs(world.enemies) do if m.summoned and not m.dead then count=count+1 end end
    for i=1,math.min(math.random(2,3),6-count) do
     local x,y=e.x+(i-2)*20,e.y+22
     for attempt=1,16 do
      if world.map:isLand(x,y) and not world:enemyBlocked(x,y) then break end
      local a=attempt*math.pi/4;local r=16+math.floor(attempt/8)*12;x=e.x+math.cos(a)*r;y=e.y+math.sin(a)*r
     end
     if world.map:isLand(x,y) and not world:enemyBlocked(x,y) then
      local m=world.makeExpansionEnemy('slime',x,y,1);m.summoned=true;require('game.slime_minions').link(e,m);require('game.party').setTarget(m,player);m.variant=math.random(1,2);m.aggro=true;m.state='chase'
      if world.isCave then m.level=20;m.tier=2;m.stats={melee=20,ranged=20,strength=10,agility=20,health=20};m.mainCombat=20;m.maxHp=100;m.hp=100 end
      world.enemies[#world.enemies+1]=m
     end
    end
   end
  end
 end
 require("game.naga_queen").updateSpells(world,dt,player)
 for i=#world.bossShots,1,-1 do
  local p=world.bossShots[i];if not p.nagaSpell then local ox,oy=p.x,p.y;local step=math.min(dt,p.time)
  p.x=p.x+p.vx*step;p.y=p.y+p.vy*step;p.time=p.time-dt
  for _,t in ipairs(targets) do if (t.hp or 0)>0 and hitSegment(ox,oy,p.x,p.y,t.x,t.y,9) then
   t.damageSerial=(t.damageSerial or 0)+1;t.lastDamageSource="Slime King";t.hp=math.max(0,t.hp-4);t.slimeCoated=6;p.time=0;world:addPopup(t.x,t.y-20,'SLIMED 4','damage');break
  end end
  if p.time<=0 then require("game.audio").play("slime_hit",p.x,p.y);world.bossPools[#world.bossPools+1]={x=p.x,y=p.y,variant=p.variant,time=10,tick=0};table.remove(world.bossShots,i) end
 end end
 for i=#world.bossPools,1,-1 do
  local p=world.bossPools[i];p.time=p.time-dt;p.tick=p.tick-dt
  if p.tick<=0 then p.tick=1;for _,t in ipairs(targets) do
   local radius=p.variant==2 and 22 or 15
   if (t.hp or 0)>0 and (t.x-p.x)^2+(t.y-p.y)^2<radius^2 and (t.poisonImmuneTimer or 0)<=0 then
    require("game.audio").play("player_hurt",t.x,t.y);t.damageSerial=(t.damageSerial or 0)+1;t.lastDamageSource="Slime King";t.hp=math.max(0,t.hp-2);t.slimeCoated=math.max(t.slimeCoated or 0,3);world:addPopup(t.x,t.y-20,'SLIME 2','damage')
   end
  end end
  if p.time<=0 then table.remove(world.bossPools,i) end
 end
 for i=#world.enemies,1,-1 do local e=world.enemies[i];if e.summoned and e.dead then
  if world.combatTarget==e then world:stopCombat('target_defeated') end
  if world.targetedEnemy==e then world.targetedEnemy=nil end
  table.remove(world.enemies,i)
 end end
end
return E
