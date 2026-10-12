-- Authoritative unlock levels. UI guides and action checks read this same table.
local U={}
U.equipment={['Copper Dagger']={'Melee Combat',1},['Copper Shield']={'Melee Combat',3},['Copper Longsword']={'Melee Combat',3},['Copper Helm']={'Melee Combat',4},['Copper Armor']={'Melee Combat',5},['Copper Arrows']={'Ranged',1},['Pine Bow']={'Ranged',1},Bow={'Ranged',1},['Oak Bow']={'Ranged',11},['Ruby Staff']={'Magic',30},['Oak Staff']={'Magic',11},['Iron Shield']={'Melee Combat',20},['Iron Sword']={'Melee Combat',20},['Iron Arrows']={'Ranged',20}}
for name,d in pairs(require("game.iron_gear").items) do if d.slot and d.requiredSkill then U.equipment[name]={d.requiredSkill,d.requiredLevel} end end
for name,r in pairs(U.equipment)do local level=require('game.metal_progression').requirement(name);if level then U.equipment[name]={'Melee Combat',level}end end
for name,d in pairs(require('game.advanced_gear').items)do if d.requiredSkill then U.equipment[name]={d.requiredSkill,d.requiredLevel}end end
U.actions={arrows={'Fletching',2},pineBow={'Fletching',6},oakBow={'Fletching',12},leather={'Leatherworking',3},oakFire={'Firemaking',11},largeHide={'Skinning',9},dye={'Tailoring',5}}
local rules={
 Smithing={['Copper Bar']=1,['Copper Dagger']=2,['Copper Knife']=2,['Copper Arrowheads']=3,['Copper Axe']=4,['Copper Pickaxe']=5,['Copper Shield']=6,['Copper Helm']=7,['Copper Longsword']=8,['Copper Armor']=9,['Smelt Large Copper Chunk']=10},
 Woodworking={['Unstrung Fishing Rod']=1,['String Fishing Rod']=1,['Pine Arrow Shafts']=1,['Pine Torch']=3,['Oak Arrow Shafts']=11,['Oak Torch']=11,['Pine Wood Parts']=1,['Oak Wood Parts']=11,['Pine Staff']=1,['Oak Staff']=11},
 Fletching={['Pine Unstrung Bow']=5,['Oak Unstrung Bow']=11},
 Leatherworking={['Rawhide String']=1,['Pine Quiver']=5,['Oak Quiver']=11,['Leather Armor']=8,['Small Leather Bag']=10,['Medium Leather Bag']=20,['Large Leather Bag']=30,['Cut Extra Large Leather']=3},
 Tailoring={['Wool Thread']=1,['Linen Cloth']=3,['Cloth Strip']=3,['Blue Dye']=4,['Dyed Blue Cloth Strip']=4,['Wizard Hat']=6,['Wizard Robes']=8,['Small Linen Bag']=10,['Medium Linen Bag']=20,['Large Linen Bag']=30},
 Alchemy={['Stamina Potion']=20,['Health Tube']=1,['Antipoison Tube']=3,['Health Flask']=20,['Antipoison Flask']=50,['Potent Health Flask']=40,['Potent Antidote']=60},
 Cooking={Tuna=30,Shark=60,Shrimp=6,Swordfish=40,['Crab Meat']=12,['Lobster Meat']=30,['Manta Ray']=20,['Small Fish']=1,['Large Fish']=7,Eel=10,['Raw Chicken']=1,['Torn Hide']=3,['Small Meat']=2,['Raw Fish Fillet']=7,['Large Meat']=9,['Giga Rat Meat']=20,['Cave Snake Meat']=25}
}
function U.configure(station,r)
 if r.tierRecipe then return end
 local default=({woodcraft='Woodworking',spinningWheel='Tailoring',anvil='Smithing',smelter='Smithing',stove='Cooking',campfire='Cooking',leathercraft='Leatherworking',tailoring='Tailoring',alchemy='Alchemy'})[station]
 if station=='inscription' then return end
 if station=='spinningWheel' and r.output=='Bow String' then r.skill='Fletching';r.level=1;return end
 local skill,level
 if station=='stove' or station=='campfire' then skill='Cooking';level=rules.Cooking[r.output]
 else for sn,list in pairs(rules) do if list[r.name] then skill,level=sn,list[r.name];break end end end
 r.skill=skill or default or r.skill or 'Jewel Crafting';r.level=level or 1
end
function U.check(skills,skill,level)
 local data=skills and skills:get(skill)
 if not data or data.level<level then return false,'Requires '..skill..' level '..level end
 return true
end
function U.itemUse(tool,name)
 if (tool=='Copper Knife' or tool=='Copper Dagger') and (name=='Small Fish' or name=='Large Fish' or name=='Eel'or name=='Swordfish'or name=='Tuna'or name=='Shark'or name=='Manta Ray')then return {'Cooking',7} end
 if tool=='Flint and Steel' and name=='Oak Logs' then local originalList=U.list;function U.list(skill,crafting)local rows={};for _,r in ipairs(originalList(skill,crafting))do rows[#rows+1]=r end;for _,r in ipairs(require('game.content_rules').milestones(skill))do rows[#rows+1]=r end;table.sort(rows,function(a,b)return a.level<b.level end);return rows end
return U.actions.oakFire end
 if (tool=='Copper Arrowheads' or tool=='Iron Arrowheads') and name:find('Arrow Shafts',1,true) then return tool=='Iron Arrowheads' and {'Fletching',20} or U.actions.arrows end
 if tool=='Bow String' and name:find('Unstrung Bow',1,true) then return name:find('Oak',1,true) and U.actions.oakBow or U.actions.pineBow end
 if tool=='Blue Dye' and name=='Cloth Strip' then local originalList=U.list;function U.list(skill,crafting)local rows={};for _,r in ipairs(originalList(skill,crafting))do rows[#rows+1]=r end;for _,r in ipairs(require('game.content_rules').milestones(skill))do rows[#rows+1]=r end;table.sort(rows,function(a,b)return a.level<b.level end);return rows end
return U.actions.dye end
end
function U.action(skills,key) local r=assert(U.actions[key],key);local originalList=U.list;function U.list(skill,crafting)local rows={};for _,r in ipairs(originalList(skill,crafting))do rows[#rows+1]=r end;for _,r in ipairs(require('game.content_rules').milestones(skill))do rows[#rows+1]=r end;table.sort(rows,function(a,b)return a.level<b.level end);return rows end
return U.check(skills,r[1],r[2]) end
U.extra={
 Prospecting={{1,"Identify any ore: no level gate. Higher levels reduce identification time."},{15,"Automatically identify copper when mining"},{27,"Automatically identify iron when mining"}},
 Mining={{1,'Mine Small Copper Chunks'},{10,'Chance to mine Large Copper Chunks'},{15,'Mine Small Iron Chunks'},{30,'Chance to mine Large Iron Chunks'},{27,'Mine Small Coal Chunks'},{37,'Chance to mine Large Coal Chunks'}},
 Woodcutting={{1,'Chop Pine'},{15,'Chop Oak'},{30,'Chop Poplar'}},
 Fletching={{2,'Assemble Copper Arrows: arrowheads + shafts'},{6,'String a Pine Bow'},{12,'String an Oak Bow'},{20,'Assemble Iron Arrows: Iron Arrowhead + Feather + any arrow shaft'}},
 Leatherworking={{3,'Soak hides and stretch leather'}},
 Alchemy={{1,'Gather alchemy ingredients'}},
 Cooking={Tuna=30,Shark=60,Shrimp=6,Swordfish=40,{7,'Prepare raw fish fillets with a knife'}},
 Fishing={{20,'Chance to catch Manta Ray with a Pine pole or better'},{30,'Chance to catch Tuna with a Pine pole or better'},{60,'Chance to catch Shark with a Pine pole or better'},{50,'Inspect exact pot catch counts'},{20,'Shrimp Pot capacity 15'},{6,'Place Shrimp Pot: capacity 1, rises to 15 at 20'},{40,'Chance to catch Swordfish with a Pine pole or better'},{20,'Use Poplar Fishing Pole: catch Manta Ray'},{12,'Place Crab Pot: catches accumulate over time, up to 10'},{30,'Place Lobster Pot: catches accumulate over time, up to 10'},{5,'Use Oak Fishing Pole: no Small Fish'},{1,'Catch Small Fish'},{5,'Chance to catch Large Fish'},{10,'Chance to catch Eel'}},
 Skinning={{1,'Skin basic animals for hides'},{5,'Improved chance of intact hides'},{9,'Skin cows and boars for large hides'}},
 Firemaking={{1,'Light a Pine Campfire'},{10,'Build Bonfires: burn all eligible logs, longer duration, +20% Health/Defence nearby'},{11,'Burn Oak Logs / Light an Oak Campfire'}},
 Commanding={{1,'Recruit 1 mercenary'},{5,'Recruit 2 mercenaries'},{10,'Recruit 3 mercenaries'}},
 ['Melee Combat']={{2,'Ability: Second Wind'},{4,'Ability: Burst'},{6,'Ability: Healing Pulse'},{8,'Ability: Warrior Yell'}},
 Magic={{1,'Spell: Fire Bolt'},{2,'Spell: Water Bolt'},{3,'Spell: Stone Bolt'},{4,'Spell: Gust Bolt'},{5,'Spell: Void Bolt'},{6,'Spell: Healing Pulse'}},
 Health={{1,'Every level: +10 maximum HP'}},Agility={{1,'Every level: improves sprint efficiency and evasion'}},
 ['Jewel Crafting']=require('game.jewel_progression').unlocks,
 Religion={},Enchanting={{1,'Tier-1 gem enchantments'}}
}
U.extra.Strength={{99,'Unlock fourth bag equipment slot; +9 capacity per bag'}};for lv=10,90,10 do U.extra.Strength[#U.extra.Strength+1]={lv,'+'..math.floor(lv/10)..' slots to each equipped bag (total)'} end
function U.list(skill,crafting)
 local rows=require('game.metal_progression').guide(skill);local seen={};if skill=='Religion'then return require('game.religion').unlocks()end;if skill=='Fieldcraft'then return require('game.fieldcraft_content').unlocks end
 local function add(level,text,r)local key=level..':'..text;if not seen[key]then rows[#rows+1]={level=level,text=text,icon=r and r.placeholder and r.output or nil,detail=r and r.placeholder and'Not in yet'or nil,placeholder=r and r.placeholder};seen[key]=true end end
 if skill=='Smithing'then add(1,'Bone weapon enhancement - Not in yet',{placeholder=true,output='Bones'})end
 for _,r in ipairs(U.extra[skill] or {}) do add(r[1],r[2]) end
 for name,r in pairs(U.equipment) do if r[1]==skill and name~='Bow' then if require('game.iron_gear').items[name] or require('game.advanced_gear').items[name]then add(r[2],'Equip '..name..' (player and mercenary)') elseif require('game.metal_progression').requirement(name)then add(r[2],'Equip '..name..' (player and mercenary)')else add(1,'Use '..name..' (mercenary requires level '..r[2]..')')end end end
 for _,station in ipairs({'woodcraft','spinningWheel','loom','anvil','smelter','stove','leathercraft','tailoring','alchemy','inscription'}) do
  for _,r in ipairs(crafting:getRecipes(station)) do if r.skill==skill then add(r.level or 1,'Craft '..(r.displayName or r.name)..(r.placeholder and' - Not in yet'or''),r) end end
 end
 table.sort(rows,function(a,b) if a.level==b.level then return a.text<b.text end;return a.level<b.level end)
 return rows
end
local originalList=U.list;function U.list(skill,crafting)local rows={};for _,r in ipairs(originalList(skill,crafting))do rows[#rows+1]=r end;for _,r in ipairs(require('game.content_rules').milestones(skill))do rows[#rows+1]=r end;table.sort(rows,function(a,b)return a.level<b.level end);return rows end
return U
