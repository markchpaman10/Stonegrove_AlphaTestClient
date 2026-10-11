local Staff=require("game.staff_effects")
local Audio=require("game.audio")
local M={}
local castSounds={"ember_spell","water_spell","earth_spell","air_spell","void_spell","spirit_spell"}
local function payRune(ui,s)
 local saved=Staff.saves(ui.equipment.weapon,ui.skills:get("Magic").level) or require('game.religion').runePreserved(ui.skills)
 if not saved then ui:consumeSpellRuneMaterial(s.rune,1) else ui.world:addPopup(ui.player.x,ui.player.y-34,"RUNE SAVED","defeat") end
 Audio.play(castSounds[s.row],ui.player.x,ui.player.y)
end
M.spells={
 ['Fire Spell Page']={name='Fire Bolt',rune='Charred Wood',damage=3,row=1,level=1,stamina=8},
 ['Water Spell Page']={name='Water Bolt',rune='Fish Bones',damage=2,row=2,level=2,stamina=7},
 ['Earth Spell Page']={name='Stone Bolt',rune='Stone Gravel',damage=3,row=3,level=3,stamina=10},
 ['Air Spell Page']={name='Gust Bolt',rune='Carved Feather',damage=2,row=4,level=4,stamina=6},
 ['Void Spell Page']={name='Void Bolt',rune='Carved Onyx',damage=4,row=5,level=5,stamina=14},
 ['Healing Spell Page']={name='Healing Pulse',rune='Green Slime Tube',heal=true,row=6,level=6,stamina=12},
}
function M.cast(ui,slot)
 if ui.equipment.offhand~="Spellbook" then return false,"no_spellbook" end
 if ui.player.hp<=0 then return false,"dead" end
 if ui.magicCast and (ui.magicCast.timer or 0)>0 then ui.world:addPopup(ui.player.x,ui.player.y-24,"FINISH CURRENT SPELL","miss");return false,"casting" end
 if (ui.player.slimeCoated or 0)>0 then ui.world:addPopup(ui.player.x,ui.player.y-24,"SLIME BLOCKS MAGIC","miss");return false,"slimed" end
 local page=ui.spellPages[slot];local s=M.spells[page];if not s then return false,'empty' end
 local magicLevel=ui.skills:get('Magic').level
 if magicLevel<(s.level or 1) then ui.world:addPopup(ui.player.x,ui.player.y-24,'MAGIC LEVEL '..tostring(s.level or 1)..' REQUIRED','miss');return false,'locked' end
 ui.player.spellCooldowns=ui.player.spellCooldowns or {};if (ui.player.spellCooldowns[slot] or 0)>0 then return false,'cooldown' end
 if ui:countSpellRuneMaterial(s.rune)<1 then ui.world:addPopup(ui.player.x,ui.player.y-24,'NEED BLESSED '..string.upper(s.rune),'miss');return false,'no_rune' end
 local runeGrade=require('game.rune_quality').select(ui,s.rune)or'C';local runeFactor=require('game.quality').factors[runeGrade]*require('game.rune_quality').spellFactor(ui:runeBag())
 local staminaCost=s.stamina or 8
 local function attemptCast()
  if ui.player.stamina<staminaCost then ui.player:staminaWarning(ui.world,ui.logger,'magic');return false,'no_stamina' end
  local castChance=math.min(1,.70+math.max(0,magicLevel-(s.level or 1))*.03)
  if not ui.player:spendStamina(staminaCost,ui.skills,ui.logger,'magic') then return false,'no_stamina' end
  if math.random()>castChance then
   ui.magicCast={timer=.6,spell=s.name};ui.player.spellCooldowns[slot]=.8
   ui.world:addPopup(ui.player.x,ui.player.y-24,'SPELL FAILED','miss')
   if ui.logger then ui.logger:log('MAGIC_CAST_FAILED',{spell=s.name,magicLevel=magicLevel,requiredLevel=s.level or 1,staminaCost=staminaCost,castChance=castChance}) end
   return false,'failed'
  end
  return true
 end
 if s.heal then local recipient=ui.healingTarget or ui.player;if recipient.hp<=0 then return false,'target_dead' end;if (recipient.x-ui.player.x)^2+(recipient.y-ui.player.y)^2>210^2 then ui.world:addPopup(ui.player.x,ui.player.y-24,'HEALING TARGET OUT OF RANGE','miss');return false,'range'end;local ok,why=attemptCast();if not ok then return false,why end;payRune(ui,s);ui.skills:addXP('Religion',require('game.religion').spellXP(ui.skills));ui.magicCast={timer=.6,spell=s.name};recipient.healingPulse=5;recipient.healingPulseTick=0;recipient.healingPulseRuneFactor=runeFactor;recipient.healingPulseRuneGrade=runeGrade;ui.player.spellCooldowns[slot]=6;ui.world:addPopup(recipient.x,recipient.y-24,'HEALING PULSE','defeat');return true end
 local target=ui.world.combatTarget or ui.world.targetedEnemy;if not target or target.dead or target.inactive then ui.world:addPopup(ui.player.x,ui.player.y-24,'NO TARGET','miss');return false,'no_target' end
 local dx,dy=target.x-ui.player.x,target.y-ui.player.y;local d=math.sqrt(dx*dx+dy*dy);if d>210 then ui.world:addPopup(ui.player.x,ui.player.y-24,'OUT OF RANGE','miss');return false,'range' end
 local ok,why=attemptCast();if not ok then return false,why end
 payRune(ui,s);ui.magicCast={timer=.6,spell=s.name};local bonus=require('game.combat').enchantBonuses(ui.equipmentSockets);local gear=require('game.combat').gearBonuses(ui.equipment);local level=magicLevel+bonus.magic+(gear.magic or 0);local damage=s.damage+math.floor(level/10)+bonus.damage+(gear.damage or 0);damage=math.floor(require('game.religion').magicDamage(ui.skills,damage)*runeFactor*10+.5)/10;ui.skills:addXP('Religion',require('game.religion').spellXP(ui.skills));ui.world.magicProjectiles[#ui.world.magicProjectiles+1]={x=ui.player.x,y=ui.player.y-4,vx=dx/math.max(1,d)*210,vy=dy/math.max(1,d)*210,target=target,life=d/210,damage=damage,runeGrade=runeGrade,row=s.row};ui.player.spellCooldowns[slot]=1.2;return true
end
function M.update(ui,dt)
 if ui.magicCast then ui.magicCast.timer=(ui.magicCast.timer or 0)-dt;if ui.magicCast.timer<=0 then ui.magicCast=nil end end
 local p=ui.player;p.spellCooldowns=p.spellCooldowns or {};for k,t in pairs(p.spellCooldowns) do p.spellCooldowns[k]=math.max(0,t-dt) end
 for i=#ui.world.magicProjectiles,1,-1 do local q=ui.world.magicProjectiles[i];local ox,oy=q.x,q.y;local travel=math.min(dt,math.max(0,q.life));q.life=q.life-dt;q.x=q.x+q.vx*travel;q.y=q.y+q.vy*travel;local blocked=false;local steps=math.max(1,math.ceil(math.sqrt((q.x-ox)^2+(q.y-oy)^2)/4));for j=1,steps do local t=j/steps;if ui.world:projectileBlocked(ox+(q.x-ox)*t,oy+(q.y-oy)*t) then blocked=true;break end end;if blocked then Audio.play("magic_impact",q.x,q.y);table.remove(ui.world.magicProjectiles,i) elseif q.life<=0 then local e=q.target;if e and not e.dead and not e.inactive and (e.x-q.x)^2+(e.y-q.y)^2<=((e.hitRadius or 14)+8)^2 then Audio.play('magic_impact',e.x,e.y);Audio.hurt(e.kind,e.x,e.y);require('game.party').threat(ui.world,e,p,q.damage);local actualDamage=math.min(q.damage,e.hp);e.hp=math.max(0,e.hp-q.damage);e.hitFlash=.12;ui.world:addPopup(e.x,e.y-14,q.damage,'damage');local old,new,total=ui.skills:addXP('Magic',actualDamage*2);if ui.logger then ui.logger:log('MAGIC_DAMAGE_XP',{spellRow=q.row,damage=actualDamage,xpGained=actualDamage*2,totalXp=total}) end;if e.hp<=0 then ui.world:defeatEnemy(e,ui.skills,ui.logger) end end;table.remove(ui.world.magicProjectiles,i) end end
end
return M
