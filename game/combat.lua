local Combat={}
function Combat.enchantBonuses(equipmentSockets)
 local out={melee=0,ranged=0,magic=0,damage=0,healing=0}
 for key,slot in pairs(equipmentSockets or {}) do for _,gem in ipairs(slot or {}) do if key~="tool" and type(gem)=="table" and gem.state~="broken" and gem.state~="open" and gem.enchantValue then
  local v=tonumber(gem.enchantValue) or 0
  if gem.enchantKind=="skill" then if gem.enchantSkill=="Melee Combat" then out.melee=out.melee+v elseif gem.enchantSkill=="Ranged" then out.ranged=out.ranged+v elseif gem.enchantSkill=="Magic" then out.magic=out.magic+v end
  elseif gem.enchantKind=="spell" then if gem.enchantSpell=="Healing Pulse" then out.healing=out.healing+v else out.damage=out.damage+v end end
 end end end
 return out
end
function Combat.maxDamage(info,strength)
 if info and info.title=="Copper Knife" then return 0 end
 local oldScale=((info and info.damage) or 1)+math.floor((strength-1)/5)
 return math.max(1,math.ceil(oldScale/2))
end
function Combat.gearBonuses(equipment)
 equipment=equipment or{};local G=require('game.iron_gear');local A=require('game.advanced_gear');local Q=require('game.quality');local out=G.bonuses(equipment);out.defence=0
 for _,slot in ipairs({'head','body','legs','cape','offhand'})do local name=equipment[slot];local d=(Q.baseInfo or{})[name]or G.items[name]or A.items[name]or(name and require('game.custom_content').item(name));if d then local info=Q.info(d,Q.object(equipment,slot));out.defence=out.defence+(tonumber(info.defence)or 0)elseif name=='Copper Helm'then out.defence=out.defence+2 elseif name=='Copper Armor'then out.defence=out.defence+5 elseif name=='Copper Shield'then out.defence=out.defence+4 end end
 for _,slot in ipairs({'weapon','offhand'})do local d=A.items[equipment[slot]];if d and d.bonus then for stat,value in pairs(d.bonus)do out[stat]=(out[stat]or 0)+value end end end;return out
end
function Combat.defense(equipment)return Combat.gearBonuses(equipment).defence end
function Combat.magicDamage(level) return math.max(1,1+math.floor(level/12)) end
function Combat.healing(level) return math.max(2,1+math.floor(level/10)) end
function Combat.mitigate(raw,equipment,agility)
 if math.random()<math.min(.45,.08+(agility-1)*.006) then return 0 end
 local blocked=math.max(0,math.min(raw-1,math.floor(Combat.defense(equipment)/3)))
 return math.max(0,raw-blocked)
end
return Combat
