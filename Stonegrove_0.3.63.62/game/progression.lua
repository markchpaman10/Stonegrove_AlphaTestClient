local Skills=require('game.skills')
local Combat=require('game.combat')
local P={}
local baseline=Skills.new()
function P.level(actor,name)
 if actor.get then return actor:get(name).level end
 local v=(actor.combatSkills or {})[name];return v and v.level or 1
end
function P.combatLevel(actor)
 local attack=math.max(P.level(actor,'Melee Combat'),P.level(actor,'Ranged'),P.level(actor,'Magic'))
 return math.max(1,math.floor((attack+P.level(actor,'Strength')+P.level(actor,'Agility')+P.level(actor,'Health'))/4))
end
function P.train(actor,name,xp)
 actor.combatSkills=actor.combatSkills or {};local v=actor.combatSkills[name] or {xp=0,level=1};actor.combatSkills[name]=v
 v.xp=v.xp+xp*(actor.race=='Dwarf' and require('game.races').multiplier(actor.race,name) or 1);v.level=baseline:levelForXP(v.xp)
end
function P.requirement(name,info)
 if info and info.unrestricted then return 'Magic',1 end
 local metal=require('game.metal_progression').requirement(name);if metal then return 'Melee Combat',metal end
 local unlock=require("game.unlocks").equipment[name];if unlock then return unlock[1],unlock[2] end
 info=info or {};local tier=info.tier or require('game.shop').tier({},name)
 local skill=(name:find('Bow',1,true) and 'Ranged') or (name:find('Staff',1,true) or name:find('Wizard',1,true)) and 'Magic' or 'Melee Combat'
 if info.type=='Tool' then return skill,1 end
 return info.requiredSkill or skill,info.requiredLevel or (tier==1 and 1 or (tier-1)*10+1)
end
function P.canEquip(actor,name,info)
 info=require('game.content_rules').equipment(name,info);local context=actor.fieldcraftContext;local player=context and context.actor.player or actor.player;local ok=require('game.content_rules').gate('equipment',name,actor,player);if not ok or not require('game.content_rules').allowed(info and info.contentRule,actor,player)then return false,'Progression',info and info.requiredLevel or 1 end
 if info and info.unrestricted then return true,'Magic',1 end
 local skill,level=P.requirement(name,info);if require('game.metal_progression').items[name]or(info and info.placeholder)then return false,skill,level end;if require('game.metal_progression').requirement(name)then return P.level(actor,skill)>=level,skill,level end;if actor.get and not require("game.iron_gear").items[name] and not (info and info.customEquipment) then return true,skill,1 end;return P.level(actor,skill)>=level,skill,level
end
function P.roll(level,info,strength)
 local chance=math.min(.95,.68+level*.008+((info and info.accuracy) or 0)*.012)
 return math.random()<=chance and math.random(1,Combat.maxDamage(info,strength)) or 0
end
return P
