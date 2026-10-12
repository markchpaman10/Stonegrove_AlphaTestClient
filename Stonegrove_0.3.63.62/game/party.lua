-- Party and town defenders use the same skill table, equipment gates and damage rules.
local P=require('game.progression')
local Combat=require('game.combat')
local B={}
local Audio=require("game.audio")
local Staff=require("game.staff_effects")
local guardXP=require('game.skills').new().xpTable
function B.configureGuard(a,level)
 level=math.max(1,math.min(99,math.floor(level or P.level(a,'Health'))))
 for _,skill in ipairs({'Melee Combat','Ranged','Magic','Health','Strength','Agility'}) do
  a.combatSkills=a.combatSkills or {};a.combatSkills[skill]={level=level,xp=guardXP[level]}
 end
 local ranged=a.role=='Ranged'
 a.equipment={weapon=ranged and (level>=11 and 'Oak Bow' or 'Pine Bow') or (level>=20 and 'Iron Sword' or level>=3 and 'Copper Longsword' or 'Copper Dagger'),
  head=level>=25 and (ranged and 'Iron Reinforced Leather Helm' or 'Iron Helm') or level>=4 and 'Copper Helm' or 'Leather Helm',
  body=level>=30 and (ranged and 'Iron Reinforced Leather Armor' or 'Iron Armor') or level>=5 and 'Copper Armor' or 'Leather Armor',
  legs=level>=20 and (ranged and 'Iron Reinforced Leather Boots' or 'Iron Boots') or nil,
  offhand=not ranged and (level>=20 and 'Iron Shield' or level>=3 and 'Copper Shield') or nil,
  ammo=ranged and {name=level>=20 and 'Iron Arrows' or 'Copper Arrows',qty=100} or nil}
 a.maxHp=math.max(40,require("game.races").maxHealth(a.race,level));a.hp=a.maxHp
end
local RUNE_BY_ELEMENT={[1]='Charred Wood',[2]='Fish Bones',[3]='Stone Gravel',[4]='Carved Feather',[5]='Carved Onyx',[6]='Green Slime Tube'}
local function runeBag(equipment)
 local b=equipment and equipment.ammo
 return type(b)=='table' and b.name=='Rune Bag' and b or nil
end
local function countRune(inventory,equipment,name)
 local b=runeBag(equipment);local inBag=b and b.materials and (b.materials[name] or 0) or 0
 return inBag+(inventory and inventory.countBlessed and inventory:countBlessed(name) or 0)
end
local function consumeRune(inventory,equipment,name,qty,caster)
 qty=qty or 1;if countRune(inventory,equipment,name)<qty then return false end
 if caster and Staff.saves(caster.equipment.weapon,P.level(caster,"Magic")) then return true end
 local b=runeBag(equipment);local fromBag=0
 if b then b.materials=b.materials or {};fromBag=math.min(qty,b.materials[name] or 0);b.materials[name]=(b.materials[name] or 0)-fromBag end
 local left=qty-fromBag;if left>0 and inventory then inventory:removeBlessed(name,left) end
 return true
end
local targets=setmetatable({},{__mode='k'})
local threat=setmetatable({},{__mode='k'})
local function distance(a,b) return (a.x-b.x)^2+(a.y-b.y)^2 end
local function move(w,a,b,dt,speed)
 require('game.navigation').move(w,a,b.x,b.y,speed*((a.slimeCoated or 0)>0 and .5 or 1),dt)
end
function B.initialize(a)
 if not a.equipmentItems then require("game.items").sync(a) end
 for _,skill in ipairs({'Melee Combat','Ranged','Magic','Health','Strength','Agility'}) do if not a.combatSkills or not a.combatSkills[skill] then P.train(a,skill,0) end end
 a.hp=a.hp or 5;a.maxHp=a.maxHp or 5;a.equipment=a.equipment or {};a.abilityTimers=a.abilityTimers or {}
end
function B.engaged(w,player)
 if w.combatTarget and not w.combatTarget.dead then return true end
 for _,a in ipairs(w.onlineActors or{})do if a.player==player and a.target and not a.target.dead then return true end end
 for _,e in ipairs(w.enemies) do if e.aggro and not e.dead and not e.inactive and distance(e,player)<220^2 and (not targets[e] or not targets[e].guard) then return true end end
 return false
end
function B.present(w,a)
 if (a.hp or 0)<=0 and a.deathRegionId and a.deathRegionId~=((w.overworld or w).regionId or "overworld") then return false end
 return not a.waitingInTown or (not w.isCave and a.waitingRegionId==(w.regionId or "overworld"))
end
function B.markDeaths(w)
 for _,a in ipairs(w.mercs or {}) do if (a.hp or 0)<=0 and not a.deathRegionId then local over=w.overworld or w;a.deathRegionId=over.regionId or "overworld";a.deathX=w.isCave and w.entry.x or a.x;a.deathY=w.isCave and w.entry.y or a.y end end
end
function B.respawn(w,a)
 local townWorld=w.overworld or w
 if a.deathRegionId and a.deathRegionId~=(townWorld.regionId or "overworld") then local regions=require('game.regions');townWorld=regions.cache[a.deathRegionId] or (regions.records[a.deathRegionId] and regions.get(a.deathRegionId,w.sprites)) or townWorld end
 local x,y=require('game.respawn').town(townWorld,a.deathX or (w.isCave and w.entry.x or a.x),a.deathY or (w.isCave and w.entry.y or a.y),a)
 if not x then return false end
 a.x,a.y=x,y;a.hp=a.maxHp;a.recover=nil;a.slimeCoated=0;a.slimeBreathTick=0
 a.deathRegionId=nil;a.deathX=nil;a.deathY=nil;a.waitingInTown=true;a.waitingRegionId=townWorld.regionId or "overworld";require('game.navigation').forget(a)
 return true
end
function B.recall(w,a,player)
 if a.waitingInTown or (a.hp or 0)<=0 then return false end
 for radius=24,96,16 do for i=0,15 do local angle=i*math.pi/8;local x,y=player.x+math.cos(angle)*radius,player.y+math.sin(angle)*radius
  if not w:enemyBlocked(x,y,a) then a.x,a.y=x,y;return true end
 end end;return false
end
function B.setup(w)
 if w.guards then return end;w.guards={}
 for vi,v in ipairs(w.villages) do local guardCount=(v.townType=='large' and 5) or (v.townType=='medium' and 3) or 2;for i=1,guardCount do
  local angle=(i-1)*math.pi*2/guardCount;local radius=(v.townType=='large' and 410) or (v.townType=='medium' and 165) or 110;local x,y=v.cx+math.cos(angle)*radius,v.cy+math.sin(angle)*radius
  for r=0,100,8 do local xx,yy=x+math.cos(angle)*r,y+math.sin(angle)*r;if not w:enemyBlocked(xx,yy) then x,y=xx,yy;break end end
  local ranged=i%2==0;local g={name='Town Guard '..vi..'-'..i,role=ranged and 'Ranged' or 'Tank',guard=true,race='Human',x=x,y=y,spawnX=x,spawnY=y,hp=40,maxHp=40,equipment={head='Copper Helm',body='Copper Armor',weapon=ranged and 'Pine Bow' or 'Copper Longsword',offhand=not ranged and 'Copper Shield' or nil,ammo=ranged and {name='Copper Arrows',qty=100} or nil},combatSkills={}}
  for _,skill in ipairs({'Melee Combat','Ranged','Magic','Health','Strength','Agility'}) do P.train(g,skill,1200) end
  B.configureGuard(g);w.guards[#w.guards+1]=g
 end end
 if w.map.authored then return end
 -- Additional permanent wilderness spawn points, separate from rare encounters.
 for i=1,24 do for attempt=1,80 do
  local x,y=math.random(64,w.map.width-64),math.random(64,w.map.height-64)
  if require('game.expansion').clearVillage(w,x,y,80) and not w:enemyBlocked(x,y) then
   local e=w.makeExpansionEnemy(i%3==0 and 'wolf' or 'rat',x,y,1);e.nightOnly=i%3==0;e.inactive=e.nightOnly and not w._nightState;w.enemies[#w.enemies+1]=e;break
  end
 end end
end
function B.threat(w,e,a,amount,taunt,boneDamage)
 if not taunt then require("game.bone_religion").hit(w,e,a,boneDamage or amount or 0)end
 if not a then return end
 local list=threat[e] or setmetatable({},{__mode='k'});threat[e]=list
 local highest=0;for _,v in pairs(list) do highest=math.max(highest,v) end
 list[a]=taunt and highest+20 or (list[a] or 0)+amount
 local current=targets[e];if not current or (current.hp or 0)<=0 or list[a]>(list[current] or 0) then targets[e]=a end
end
function B.target(e) return targets[e] end
function B.setTarget(e,t)targets[e]=t end
function B.hit(w,a,t,damage,skill)
 B.threat(w,t,a,damage*(a.role=='Tank' and 3 or 1),false,math.min(t.hp,damage));damage=math.min(t.hp,damage);t.hp=math.max(0,t.hp-damage);t.hitFlash=.12;w:addPopup(t.x,t.y-22,damage>0 and tostring(damage) or 'MISS',damage>0 and 'damage' or 'miss')
 if not a.guard then P.train(a,skill,damage*4);if skill~='Magic' then P.train(a,'Strength',damage*4) end;P.train(a,'Health',damage*1.33) end
 if damage>0 then Audio.play(skill=='Magic' and 'magic_impact' or skill=='Ranged' and 'arrow_impact' or 'sword_hit',t.x,t.y);Audio.hurt(t.kind,t.x,t.y) else Audio.play('miss',t.x,t.y) end
 if t.hp<=0 and t.kind then Audio.death(t.kind,t.x,t.y); if not a.guard and not a.kind then require('game.quests').event(w,'kill',t.kind,1)end;t.dead=true;t.aggro=false;t.state='dead';t.respawnTimer=t.kind=='slimeBoss' and 600 or t.kind=='gigaRat' and 420 or 240;t.skinned=false;require('game.bone_religion').drop(w,t,a);if t.kind=='chicken' then w:dropScattered('Raw Chicken',t.x,t.y,1,2);w:dropScattered('Feather',t.x,t.y,2,2) end end
end
function B.update(w,dt,player,sprites,inventory,playerEquipment)
 B.markDeaths(w);B.setup(w);local engaged=B.engaged(w,player)
 local allies={};for _,m in ipairs(w.mercs) do allies[#allies+1]=m end;for _,g in ipairs(w.guards) do allies[#allies+1]=g end
 for index,a in ipairs(allies) do
  local player,inventory,playerEquipment,engaged=player,inventory,playerEquipment,engaged
  if a.onlineOwner and w.onlineActors then for _,owner in ipairs(w.onlineActors)do if owner.id==a.onlineOwner then player,inventory,playerEquipment=owner.player,owner.inv,owner.equipment;engaged=B.engaged(w,player);break end end end
  B.initialize(a);local gearBonus=Combat.gearBonuses(a.equipment);local gems=Combat.enchantBonuses(a.equipmentSockets);for k,v in pairs(gems) do gearBonus[k]=(gearBonus[k] or 0)+v end;local timers=a.abilityTimers
  for name,t in pairs(timers) do timers[name]=math.max(0,t-dt) end
  a.cooldown=math.max(0,(a.cooldown or 0)-dt);a.maxHp=math.max(a.guard and 40 or 5,require('game.races').maxHealth(a.race,P.level(a,'Health')));a.hp=math.min(a.hp,a.maxHp)
  local maxStamina=require('game.races').maxStamina(a.race,1);a.stamina=math.min(maxStamina,(a.stamina or maxStamina)+2*dt)
  if not a.guard and a.hp>0 and not a.waitingInTown and not engaged and (distance(a,player)>700^2 or not w.map:isLand(a.x,a.y) or require('game.fences').blocked(w,a.x,a.y)) then B.recall(w,a,player) end
  if a.hp<=0 then a.recover=(a.recover or 20)-dt;if a.recover<=0 then a.hp=a.maxHp;a.recover=nil;if a.guard then a.x,a.y=a.spawnX,a.spawnY else if not B.respawn(w,a) then a.hp=0;a.recover=2 end end end
  elseif a.waitingInTown and (not B.present(w,a) or distance(a,player)>90^2) then
   -- Wait at the town until the player actually reunites with this companion.
  else
   a.waitingInTown=nil;a.waitingRegionId=nil
   local target=nil;local ownerTarget=w.combatTarget;for _,owner in ipairs(w.onlineActors or{})do if owner.player==player then ownerTarget=owner.target;break end end;local best=a.guard and 190^2 or 240^2
   if a.guard or engaged then
    for _,e in ipairs(w.enemies) do if not e.dead and not e.inactive and (a.guard and e.kind~='cow' and e.kind~='chicken' or not a.guard and (ownerTarget==e or e.aggro and distance(e,player)<220^2 and (not targets[e] or not targets[e].guard))) then
     local d=distance(a,e);if d<best and (not a.guard or (e.x-a.spawnX)^2+(e.y-a.spawnY)^2<260^2) then target=e;best=d end
    end end
   end
   local acted=false
   if a.role=='Healer' and engaged and a.cooldown<=0 and (a.slimeCoated or 0)<=0 and (timers.heal or 0)<=0 then
    local patient;local urgency=0
    local patients={player};for _,other in ipairs(w.mercs) do patients[#patients+1]=other end
    for _,p in ipairs(patients) do local missing=(p.maxHp or 5)-(p.hp or 0);local ratio=missing/(p.maxHp or 5)
     if p.hp>0 and (p.slimeCoated or 0)<=0 and distance(a,p)<140^2 and missing>=2 and ratio>urgency then patient=p;urgency=ratio end
    end
    if patient then
     local level=P.level(a,'Magic');local magical=level>=5
     if not magical or consumeRune(inventory,playerEquipment,'Green Slime Tube',1,a) then
      local heal=math.min(patient.maxHp-patient.hp,magical and (Combat.healing(level+gearBonus.magic)+gearBonus.healing) or 2)
      Audio.play(magical and "healer_cast" or "renew",a.x,a.y);patient.hp=patient.hp+heal;timers.heal=level>=15 and 3 or level>=5 and 4 or 6;a.cooldown=.8;acted=true
      P.train(a,magical and 'Magic' or 'Health',heal*3);w:addPopup(patient.x,patient.y-22,(magical and 'HEAL +' or 'FIRST AID +')..heal,'defeat')
     else
      timers.heal=1.0;w:addPopup(a.x,a.y-24,'NO SPIRIT RUNE','miss')
     end
    end
   end
   if target and not acted then
    local ranged=a.role=='Ranged';local mage=a.role=='Healer';local skill=mage and 'Magic' or ranged and 'Ranged' or 'Melee Combat';local level=P.level(a,skill)
    local range=mage and 140 or ranged and (a.race=='Elf' and 165 or 135) or 27
    if a.role=='Tank' and best<90^2 and (timers.taunt or 0)<=0 and targets[target]~=a then
     Audio.play('tank_aggro',a.x,a.y);B.threat(w,target,a,0,true);timers.taunt=level>=10 and 5 or 8;w:addPopup(a.x,a.y-24,'TAUNT!','defence')
     if level>=10 then for _,e in ipairs(w.enemies) do if e.aggro and not e.dead and distance(a,e)<90^2 then B.threat(w,e,a,0,true) end end end
    end
    if best>range^2 then move(w,a,target,dt,75)
    elseif a.cooldown<=0 and (mage or a.stamina>=7) then
     local eq=a.equipment;local weapon=eq.weapon;local info=require('game.quality').info(sprites.itemInfo[weapon]or{},require('game.items').equipped(a,'weapon'));local ammo=eq.ammo;local ammoName=type(ammo)=='table'and(require('game.advanced_gear').isQuiver(ammo.name)and ammo.arrowType or ammo.name)
     if (mage or P.canEquip(a,weapon or '',info)) and weapon~='Copper Knife' and (not ranged or tostring(weapon):find('Bow') and ammo and require('game.advanced_gear').isArrow(ammoName)and(ammo.qty or 0)>0) and (not mage or (a.slimeCoated or 0)<=0) then
      local magicElement=mage and (level>=10 and 1 or level>=3 and 4 or level>=2 and 3 or 2) or nil
      local magicRune=magicElement and RUNE_BY_ELEMENT[magicElement] or nil
      if mage and not consumeRune(inventory,playerEquipment,magicRune,1,a) then a.cooldown=.8;w:addPopup(a.x,a.y-24,'NO RUNE MATERIAL','miss') else
      Audio.play(mage and ({"ember_spell","water_spell","earth_spell","air_spell","void_spell","spirit_spell"})[magicElement] or ranged and "bow_shot" or "swing",a.x,a.y)
      local shots=1
      if ranged and (timers.volley or 0)<=0 and level>=5 then shots=level>=15 and 3 or 2;shots=math.min(shots,ammo.qty);timers.volley=8;w:addPopup(a.x,a.y-24,shots==3 and 'TRIPLE SHOT' or 'DOUBLE SHOT','defeat') end
      a.stamina=math.max(0,a.stamina-(mage and 0 or 7));a.cooldown=mage and 1.8 or ranged and .85 or 1.1
      for shot=1,shots do
       local damage=(mage and Combat.magicDamage(level+gearBonus.magic) or P.roll(level+(ranged and gearBonus.ranged or gearBonus.melee),info,P.level(a,'Strength')))+(gearBonus.damage or 0)
       if mage then damage=math.floor(damage*require('game.quality').factor(require('game.items').equipped(a,'weapon'))+.5)end
       if a.role=='Tank' and eq.offhand=='Copper Shield' and level>=5 and (timers.bash or 0)<=0 then damage=damage+2;timers.bash=6;targets[target]=a;w:addPopup(a.x,a.y-24,'SHIELD BASH','defence') end
       if ranged or mage then
        if ranged then ammo.qty=ammo.qty-1 end
        local dx,dy=target.x-a.x,target.y-a.y;local d=math.max(1,math.sqrt(dx*dx+dy*dy));w.mercArrows=w.mercArrows or {}
        local element=magicElement
        w.mercArrows[#w.mercArrows+1]={element=element,x=a.x,y=a.y+(shot-1)*2,vx=dx/d*220,vy=dy/d*220,life=d/220+(shot-1)*.08,target=target,damage=damage,owner=a,skill=skill,magic=mage,ammoType=ammoName}
       else B.hit(w,a,target,damage,skill) end
      end
      if not targets[target] then targets[target]=a end
      end
     end
    end
   end
   if not target then local home=a.guard and {x=a.spawnX,y=a.spawnY} or player;local followD=distance(a,player);if a.guard or followD>72^2 then move(w,a,home,dt,(player.speed or 78)*1.2) end
    if a.guard and distance(a,home)<16^2 then a.hp=math.min(a.maxHp,a.hp+dt*4);if a.equipment.ammo then a.equipment.ammo.qty=100 end end
   end
  end
 end
 for i=#(w.mercArrows or {}),1,-1 do local a=w.mercArrows[i];local travel=math.min(dt,math.max(0,a.life));a.life=a.life-dt;local ox,oy=a.x,a.y;local nx,ny=a.x+a.vx*travel,a.y+a.vy*travel;local blocked=false
  if a.magic then local steps=math.max(1,math.ceil(math.sqrt((nx-ox)^2+(ny-oy)^2)/4));for step=1,steps do local t=step/steps;if w:projectileBlocked(ox+(nx-ox)*t,oy+(ny-oy)*t) then blocked=true;break end end end
  if blocked then Audio.play("magic_impact",nx,ny);table.remove(w.mercArrows,i) else a.x,a.y=nx,ny;if a.life<=0 then if a.target and not a.target.dead and not a.target.inactive and (not a.magic or (a.target.x-a.x)^2+(a.target.y-a.y)^2<=((a.target.hitRadius or 14)+8)^2) then B.hit(w,a.owner,a.target,a.damage,a.skill);if not a.magic and a.damage>0 then require('game.fang_poison').apply(w,a.target,a.ammoType,nil,nil,a.owner)end end;table.remove(w.mercArrows,i) end end
 end
 -- Night goblins hunt nearby wolves and can themselves be killed in those fights.
 for _,g in ipairs(w.enemies) do if g.kind=='goblin' and not g.dead and not g.inactive and not g.aggro then
  local wolf;local best=200^2;for _,e in ipairs(w.enemies) do if e.kind=='wolf' and not e.dead and not e.inactive and distance(g,e)<best then wolf=e;best=distance(g,e) end end
  g.huntingWolf=wolf~=nil
  if wolf then g.huntTimer=(g.huntTimer or 0)-dt;targets[wolf]=g;if best>28^2 then move(w,g,wolf,dt,35) elseif g.huntTimer<=0 then g.huntTimer=1.1;B.hit(w,g,wolf,P.roll(g.stats.melee,{damage=2},g.stats.strength),'Melee Combat') end end
 end end
end
function B.enemyTurn(w,e,dt)
 local t=targets[e];if t==w.playerRef or(t and t.onlineId)then return false end;if not t then return e.huntingWolf and not e.aggro or false end
 if t.hp<=0 or t.dead or t.inactive or (t.waitingInTown and not B.present(w,t)) or distance(e,t)>(e.summoned and e.minionBossId and 300 or 250)^2 then targets[e]=nil;return false end
 e.aggro=true;e.state='combat';e.attackTimer=e.attackTimer-dt
 if distance(e,t)>28^2 then move(w,e,t,dt,36)
 elseif e.attackTimer<=0 then e.attackTimer=1.4;local dmg=P.roll(e.stats.melee,{damage=math.max(1,e.stats.melee)},e.stats.strength);dmg=Combat.mitigate(dmg,t.equipment or {},P.level(t,'Agility'));Audio.play(dmg>0 and 'player_hurt' or 'block',t.x,t.y);if dmg>0 then t.damageSerial=(t.damageSerial or 0)+1;t.lastDamageSource=e.customName or e.kind end;t.hp=math.max(0,t.hp-dmg);w:addPopup(t.x,t.y-18,dmg,'damage');if t.kind and t.hp<=0 then t.dead=true;t.aggro=false;t.respawnTimer=240 end end
 return true
end
return B

