local A={}
A.list={
 {name='Second Wind',level=2,cooldown=18,desc='Restore 15% stamina and increase stamina regeneration for 5 seconds.',asset='assets/ability_second_wind.png',frames=2,fw=16,fh=16},
 {name='Burst',level=4,cooldown=16,desc='Increase melee weapon attack speed to 4x for 5 seconds.',asset='assets/ability_burst.png',frames=5,fw=16,fh=16},
 {name='Healing Pulse',level=6,cooldown=15,desc='Heal over time for 5 seconds.',asset='assets/ability_healing_pulse.png',frames=4,fw=16,fh=16},
 {name='Warrior Yell',level=8,cooldown=18,desc='Draw nearby enemy aggro and increase damage and defence for 6 seconds.',asset='assets/ability_warrior_yell.png',frames=3,fw=48,fh=48,vertical=true},
}
function A.byName(n) for _,a in ipairs(A.list) do if a.name==n then return a end end end
function A.weaponCategory(ui)
 local n=ui.equipment.weapon;if not n then return nil end
 local info=ui.sprites.itemInfo[n];if not (info and info.type=='Weapon') then return nil end
 if tostring(n):find('Bow',1,true) then return 'ranged' end
 if tostring(n):find('Staff',1,true) then return 'magic' end
 return 'melee'
end
function A.hasWeapon(ui) local c=A.weaponCategory(ui);return c=='melee' or c=='ranged' end
function A.isMeleeWeapon(ui) return A.weaponCategory(ui)=='melee' end
function A.cast(ui,name)
 if ui.player.hp<=0 then return false,"dead" end
 local a=A.byName(name);if not a then return false,'unknown' end
 if ui.skills:get('Melee Combat').level<a.level then return false,'locked' end
 ui.player.abilityCooldowns=ui.player.abilityCooldowns or {};if (ui.player.abilityCooldowns[name] or 0)>0 then return false,'cooldown' end
 if name=='Second Wind' then ui.player.stamina=math.min(ui.player.maxStamina,ui.player.stamina+ui.player.maxStamina*.15);ui.player.secondWind=5
 elseif name=='Burst' then ui.player.burst=5
 elseif name=='Healing Pulse' then ui.player.healingPulse=5;ui.player.healingPulseTick=0;ui.player.healingPulseRuneFactor=1;ui.player.healingPulseRuneGrade=nil
 elseif name=='Warrior Yell' then ui.player.warriorYell=6;for _,e in ipairs(ui.world.enemies) do if not e.dead and not e.inactive and (e.x-ui.player.x)^2+(e.y-ui.player.y)^2<=130^2 then e.aggro=true;e.state='combat';require('game.party').threat(ui.world,e,ui.player,0,true) end end end
 require('game.audio').play(({['Second Wind']='second_wind',Burst='haste',['Healing Pulse']='renew',['Warrior Yell']='yell'})[name],ui.player.x,ui.player.y);ui.player.abilityCooldowns[name]=a.cooldown;ui.player.abilityVisual={name=name,t=0,duration=name=='Warrior Yell' and .75 or .55};ui.world:addPopup(ui.player.x,ui.player.y-24,string.upper(name),'defeat');return true
end
function A.update(ui,dt)
 local p=ui.player;p.abilityCooldowns=p.abilityCooldowns or {};for n,t in pairs(p.abilityCooldowns) do p.abilityCooldowns[n]=math.max(0,t-dt) end
 p.secondWind=math.max(0,(p.secondWind or 0)-dt);p.burst=math.max(0,(p.burst or 0)-dt);p.healingPulse=math.max(0,(p.healingPulse or 0)-dt);p.warriorYell=math.max(0,(p.warriorYell or 0)-dt)
 if p.healingPulse>0 and p.hp>0 and (p.slimeCoated or 0)<=0 then p.healingPulseTick=(p.healingPulseTick or 0)-dt;if p.healingPulseTick<=0 then p.healingPulseTick=1;local bonus=require("game.combat").enchantBonuses(ui.equipmentSockets);local gear=require("game.combat").gearBonuses(ui.equipment);p.hp=math.min(p.maxHp,p.hp+math.max(1,math.floor((math.max(1,math.floor(p.maxHp*.04))+bonus.healing+(gear.healing or 0))*(p.healingPulseRuneFactor or 1)*10+.5)/10));ui.world:addPopup(p.x,p.y-22,'HEAL +','defeat') end end
 if p.abilityVisual then p.abilityVisual.t=p.abilityVisual.t+dt;if p.abilityVisual.t>=p.abilityVisual.duration then p.abilityVisual=nil end end
end
return A
