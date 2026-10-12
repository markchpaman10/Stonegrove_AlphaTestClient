local Crafting={};Crafting.__index=Crafting
local recipes={
 alchemy={
  {name="Health Flask",output="Health Flask",qty=1,xp=18,needs={{"Empty Flask",1},{"Large Blue Mushroom",1},{"Bush Root",1},{"Red Berries",2}}},
  {name="Health Tube",output="Health Tube",qty=1,xp=8,skill="Alchemy",level=1,needs={{"Empty Tube",1},{"Brown Mushroom",1},{"Red Berries",1}}},
  {name="Antipoison Flask",output="Antipoison Flask",qty=1,xp=20,needs={{"Empty Flask",1},{"Large Blue Mushroom",1},{"Bush Greens",1},{"Purple Berries",2}}},
  {name="Antipoison Tube",output="Antipoison Tube",qty=1,xp=10,skill="Alchemy",level=3,needs={{"Empty Tube",1},{"Green Slime Jar",1},{"Purple Berries",1}}},
  {name="Stamina Potion",output="Stamina Potion (3/3)",qty=1,xp=45,skill="Alchemy",level=20,needs={{"Egg",3},{"Giga Rat Blood",1},{"Small Meat",1},{"Empty Flask",1}}}
 },
 spinningWheel={
  {name="Bow String (Hemp)",output="Bow String",qty=1,xp=10,needs={{"Hemp Fibers",3}}},
  {name="Bow String (Flax)",output="Bow String",qty=1,xp=10,skill="Jewel Crafting",needs={{"Flax",3}}},
  {name="Wool Thread",output="Wool Thread",qty=1,xp=8,skill="Jewel Crafting",needs={{"Wool",1}}},
  {name="Linen Cloth",output="Linen Cloth",qty=1,xp=12,skill="Jewel Crafting",needs={{"Wool Thread",2}}},
  {name="Cloth Strip",output="Cloth Strip",qty=1,xp=10,skill="Tailoring",needs={{"Wool",2}}}
 },
 smelter={
  {name="Smelt Small Copper Chunk",output="Copper Bar",qty=1,xp=10,tool="Copper Tongs",needs={{"Small Copper Chunk",1}}},
  {name="Smelt Large Copper Chunk",output="Copper Bar",qty=2,xp=22,tool="Copper Tongs",skill="Smithing",level=11,needs={{"Large Copper Chunk",1}}},{name="Smelt Copper Ore",output="Copper Bar",qty=1,xp=12.5,tool="Copper Tongs",needs={{"Copper ore",1}}}},
 woodcraft={
  {name="Pine Torch",output="Torch",qty=1,xp=10,tool="Copper Dagger",needs={{"Pine Logs",1},{"Linen Cloth",2}}},
  {name="Oak Torch",output="Torch",qty=1,xp=12,tool="Copper Dagger",needs={{"Oak Logs",1},{"Linen Cloth",2}}},
  {name="Pine Wood Parts",output="Pine Wood Parts",qty=1,xp=5,tool="Copper Dagger",needs={{"Pine Logs",1}}},
  {name="Oak Wood Parts",output="Oak Wood Parts",qty=1,xp=10,tool="Copper Dagger",level=20,skill="Woodcutting",needs={{"Oak Logs",1}}},
  {name="Pine Staff",output="Pine Staff",qty=1,xp=12,tool="Copper Dagger",needs={{"Pine Logs",1}}},
  {name="Oak Staff",output="Oak Staff",qty=1,xp=20,tool="Copper Dagger",needs={{"Oak Logs",1}}},
  {name="Pine Arrow Shafts",output="Pine Arrow Shafts",qty=10,xp=8,tool="Copper Dagger",skill="Fletching",needs={{"Pine Logs",1}}},
  {name="Oak Arrow Shafts",output="Oak Arrow Shafts",qty=10,xp=14,tool="Copper Dagger",skill="Fletching",needs={{"Oak Logs",1}}},
  {name="Pine Unstrung Bow",output="Pine Unstrung Bow",qty=1,xp=14,tool="Copper Dagger",skill="Fletching",needs={{"Pine Logs",1}}},
  {name="Oak Unstrung Bow",output="Oak Unstrung Bow",qty=1,xp=24,tool="Copper Dagger",skill="Fletching",needs={{"Oak Logs",1}}}
 },
 leathercraft={
  {name="Small Leather Bag",output="Small Leather Bag",qty=1,xp=22,skill="Leatherworking",level=10,tool="Needle",bagRecipe=true,needs={{"Leather",2},{"Rawhide String",2}}},
  {name="Medium Leather Bag",output="Medium Leather Bag",qty=1,xp=44,skill="Leatherworking",level=20,tool="Needle",bagRecipe=true,needs={{"Leather",4},{"Rawhide String",4}}},
  {name="Large Leather Bag",output="Large Leather Bag",qty=1,xp=66,skill="Leatherworking",level=30,tool="Needle",bagRecipe=true,needs={{"Leather",6},{"Rawhide String",6}}},
  {name="Torn Hide Bundle",output="Raw Hide",qty=1,xp=10,tool="Needle",skill="Leatherworking",level=1,needs={{"Torn Hide",5}}},
  {name="Rawhide String",output="Rawhide String",qty=1,xp=8,tool="Needle",needs={{"Raw Hide",1}}},
  {name="Leather Armor",output="Leather Armor",qty=1,xp=45,tool="Needle",skill="Leatherworking",level=5,needs={{"Leather",5},{"Rawhide String",2}}},
  {name="Pine Quiver",output="Quiver",qty=1,xp=55,tool="Needle",skill="Leatherworking",level=10,needs={{"Leather",3},{"Pine Wood Parts",4}}},
  {name="Oak Quiver",output="Quiver",qty=1,xp=55,tool="Needle",skill="Leatherworking",level=10,needs={{"Leather",3},{"Oak Wood Parts",4}}},
  {name="Rune Bag",output="Rune Bag",qty=1,xp=60,tool="Needle",skill="Leatherworking",level=10,needs={{"Leather",3},{"Linen Cloth",4}}}
 },
 sewing={},
 tailoring={
  {name="Small Linen Bag",output="Small Linen Bag",qty=1,xp=18,skill="Tailoring",level=10,tool="Needle",bagRecipe=true,tailoring=true,needs={{"Linen Cloth",2},{"Wool Thread",2}}},
  {name="Medium Linen Bag",output="Medium Linen Bag",qty=1,xp=36,skill="Tailoring",level=20,tool="Needle",bagRecipe=true,tailoring=true,needs={{"Linen Cloth",4},{"Wool Thread",4}}},
  {name="Large Linen Bag",output="Large Linen Bag",qty=1,xp=54,skill="Tailoring",level=30,tool="Needle",bagRecipe=true,tailoring=true,needs={{"Linen Cloth",6},{"Wool Thread",6}}},
  {name="Blue Dye",output="Blue Dye",qty=1,xp=6,skill="Tailoring",level=1,needs={{"Large Blue Mushroom",1},{"Purple Berries",1}}},
  {name="Dyed Blue Cloth Strip",output="Dyed Blue Cloth Strip",qty=1,xp=8,skill="Tailoring",level=2,needs={{"Cloth Strip",1},{"Blue Dye",1}}},
  {name="Wizard Hat",output="Wizard Hat",qty=1,xp=20,skill="Tailoring",level=5,tool="Needle",needs={{"Dyed Blue Cloth Strip",2}}},
  {name="Wizard Robes",output="Wizard Robes",qty=1,xp=35,skill="Tailoring",level=8,tool="Needle",needs={{"Dyed Blue Cloth Strip",5}}}
 },
 campfire={
  {name="Cook Chicken",output="Raw Chicken",qty=1,xp=8,skill="Cooking",level=1,needs={{"Raw Chicken",1}}},
  {name="Cook Torn Hide",output="Torn Hide",qty=1,xp=8,needs={{"Torn Hide",1}}},
  {name="Cook Fish Fillet",output="Raw Fish Fillet",qty=1,xp=12,needs={{"Raw Fish Fillet",1}}},
  {name="Cook Large Meat",output="Large Meat",qty=1,xp=18,needs={{"Large Meat",1}}},
  {name="Cook Small Meat",output="Small Meat",qty=1,xp=10,needs={{"Small Meat",1}}}
 },
 stove={
  {name="Cook Chicken",output="Raw Chicken",qty=1,xp=8,skill="Cooking",level=1,needs={{"Raw Chicken",1}}},
  {name="Cook Torn Hide",output="Torn Hide",qty=1,xp=8,needs={{"Torn Hide",1}}},
  {name="Cook Fish Fillet",output="Raw Fish Fillet",qty=1,xp=12,needs={{"Raw Fish Fillet",1}}},
  {name="Cook Large Meat",output="Large Meat",qty=1,xp=18,needs={{"Large Meat",1}}},
  {name="Cook Small Meat",output="Small Meat",qty=1,xp=10,needs={{"Small Meat",1}}}
 },
 anvil={
  {name="Copper Helm",output="Copper Helm",qty=1,xp=18,tool="Copper Hammer",needs={{"Copper Bar",2},{"Leather",1}}},
  {name="Copper Armor",output="Copper Armor",qty=1,xp=30,tool="Copper Hammer",needs={{"Copper Bar",5},{"Leather",3}}},
  {name="Copper Shield",output="Copper Shield",qty=1,xp=24,tool="Copper Hammer",needs={{"Copper Bar",3},{"Pine Wood Parts",2},{"Leather",1}}},
  {name="Copper Longsword",output="Copper Longsword",qty=1,xp=25,tool="Copper Hammer",needs={{"Copper Bar",3},{"Pine Wood Parts",2}}},
  {name="Copper Axe",output="Copper Axe",qty=1,xp=20,tool="Copper Hammer",needs={{"Copper Bar",2},{"Pine Wood Parts",2}}},
  {name="Copper Pickaxe",output="Copper Pickaxe",qty=1,xp=20,tool="Copper Hammer",needs={{"Copper Bar",2},{"Pine Wood Parts",2}}},
  {name="Copper Dagger",output="Copper Dagger",qty=1,xp=16,tool="Copper Hammer",needs={{"Copper Bar",1},{"Pine Wood Parts",1}}},
  {name="Copper Hammer",output="Copper Hammer",qty=1,xp=16,tool="Copper Hammer",needs={{"Copper Bar",1},{"Pine Wood Parts",1}}},
  {name="Copper Tongs",output="Copper Tongs",qty=1,xp=14,tool="Copper Hammer",needs={{"Copper Bar",1}}},
  {name="Copper Arrowheads",output="Copper Arrowheads",qty=10,xp=12,tool="Copper Hammer",needs={{"Copper Bar",1}}}
 },
 inscription={
  {name="Magic Skill Page",output="Magic Skill Page",qty=1,xp=15,skill="Inscription",level=8,tool="Inscription Pen and Ink",needs={{"Empty Spell Page",1},{"Green Slime Tube",1,true}}},
  {name="Water Spell Page",output="Water Spell Page",qty=1,xp=18,skill="Inscription",level=1,tool="Inscription Pen and Ink",needs={{"Empty Spell Page",1},{"Fish Bones",10,true}}},
  {name="Earth Spell Page",output="Earth Spell Page",qty=1,xp=18,skill="Inscription",level=1,tool="Inscription Pen and Ink",needs={{"Empty Spell Page",1},{"Stone Gravel",10,true}}},
  {name="Air Spell Page",output="Air Spell Page",qty=1,xp=18,skill="Inscription",level=1,tool="Inscription Pen and Ink",needs={{"Empty Spell Page",1},{"Carved Feather",10,true}}},
  {name="Fire Spell Page",output="Fire Spell Page",qty=1,xp=18,skill="Inscription",level=1,tool="Inscription Pen and Ink",needs={{"Empty Spell Page",1},{"Charred Wood",10,true}}},
  {name="Void Spell Page",output="Void Spell Page",qty=1,xp=22,skill="Inscription",level=1,tool="Inscription Pen and Ink",needs={{"Empty Spell Page",1},{"Carved Onyx",10,true}}},
  {name="Healing Spell Page",output="Healing Spell Page",qty=1,xp=22,skill="Inscription",level=1,tool="Inscription Pen and Ink",needs={{"Empty Spell Page",1},{"Green Slime Tube",10,true}}},
  {name="Melee Skill Page",output="Melee Skill Page",qty=1,xp=13,skill="Inscription",level=6,tool="Inscription Pen and Ink",needs={{"Empty Spell Page",1},{"Bones",1}}},
  {name="Ranged Skill Page",output="Ranged Skill Page",qty=1,xp=14,skill="Inscription",level=7,tool="Inscription Pen and Ink",needs={{"Empty Spell Page",1},{"Copper Arrowheads",1}}},
 }
}
for _,station in ipairs({'stove','campfire'}) do
 recipes[station][#recipes[station]+1]={name='Cook Cave Snake Meat',output='Cave Snake Meat',qty=1,xp=80,skill='Cooking',level=25,needs={{'Cave Snake Meat',1}}}
 recipes[station][#recipes[station]+1]={name='Cook Giga Rat Meat',output='Giga Rat Meat',qty=1,xp=60,skill='Cooking',level=20,needs={{'Giga Rat Meat',1}}}
end
recipes.leathercraft[#recipes.leathercraft+1]={name='Cut Extra Large Leather',output='Leather',qty=4,xp=20,skill='Leatherworking',tool='Needle',needs={{'Extra Large Leather',1}}}
recipes.alchemy[#recipes.alchemy+1]={name='Potent Health Flask',output='Potent Health Flask',qty=1,xp=45,skill='Alchemy',needs={{'Giga Rat Blood',1},{'Pickled Large Meat',1},{'Pickled Small Meat',1}}}
recipes.alchemy[#recipes.alchemy+1]={name='Potent Antidote',output='Potent Antidote',qty=1,xp=45,skill='Alchemy',needs={{'Potent Slime Jar',1},{'Slime-coated Bones',1},{'Bush Greens',1}}}
recipes.anvil[#recipes.anvil+1]={name="Copper Knife",output="Copper Knife",qty=1,xp=16,tool="Copper Hammer",needs={{"Copper Bar",1},{"Pine Wood Parts",1}}}
recipes.woodcraft[#recipes.woodcraft+1]={name="Unstrung Fishing Rod",output="Unstrung Fishing Rod",qty=1,xp=6,tool="Copper Dagger",needs={{"Pine Logs",1}}}
recipes.woodcraft[#recipes.woodcraft+1]={name="String Fishing Rod",output="Fishing Pole",qty=1,xp=6,needs={{"Unstrung Fishing Rod",1},{"Rawhide String",1}}}
for _,r in ipairs(require("game.iron_gear").recipes) do recipes[r.station][#recipes[r.station]+1]=r end
for _,station in ipairs({'stove','campfire'})do
 for raw,xp in pairs(require('game.whole_fish').xp)do
  recipes[station][#recipes[station]+1]={name='Cook Whole '..raw,output=raw,qty=1,xp=xp,skill='Cooking',needs={{raw,1}}}
 end
end
require('game.tailoring_content').configure(recipes)
local stationSkills={smelter="Smithing",anvil="Smithing",stove="Cooking",campfire="Cooking",leathercraft="Leatherworking",alchemy="Alchemy",woodcraft="Jewel Crafting",spinningWheel="Jewel Crafting",sewing="Tailoring",tailoring="Tailoring",inscription="Inscription"}
for station,list in pairs(recipes) do for _,r in ipairs(list) do
 r.skill=r.skill or stationSkills[station] or "Jewel Crafting"
 if station=="spinningWheel" and r.output=="Bow String" then r.skill="Fletching" end
 require("game.unlocks").configure(station,r)
end end
for _,list in pairs(recipes) do table.sort(list,function(a,b) if (a.level or 1)==(b.level or 1) then return a.name<b.name end;return (a.level or 1)<(b.level or 1) end) end
recipes.fieldcraft=require('game.fieldcraft_content').recipes()
for _,name in ipairs({'Angled Timber','Horizontal Timber','Vertical Timber','Stump Pole'})do
 for _,wood in ipairs({'Pine Logs','Oak Logs','Logs'})do recipes.woodcraft[#recipes.woodcraft+1]={name=name..' ('..wood..')',output=name,qty=1,xp=name=='Stump Pole'and 20 or 10,skill='Woodworking',level=1,tool='Copper Dagger',needs={{wood,name=='Stump Pole'and 4 or 2}},fieldcraft=true}end
end
for _,r in ipairs(require('game.metal_progression').recipes)do recipes[r.station][#recipes[r.station]+1]=r end
require('game.seafood_content').configure(recipes)
require('game.advanced_gear').configure(recipes);require('game.fishing_tiers').configure(recipes)
for _,list in pairs(recipes)do table.sort(list,function(a,b)return(a.level or 1)==(b.level or 1)and a.name<b.name or(a.level or 1)<(b.level or 1)end)end
require('game.high_tier_fish').configure(recipes)
require('game.lumber').configure(recipes)
local fishFoods={['Raw Tuna']=true,['Raw Shark']=true,['Raw Swordfish']=true,['Raw Manta Ray']=true,Tuna=true,Shark=true,['Small Fish']=true,['Large Fish']=true,Eel=true,Shrimp=true,Swordfish=true,['Manta Ray']=true,['Raw Fish Fillet']=true,['Crab Meat']=true,['Lobster Meat']=true,['Raw Lobster Tail']=true}
for _,station in ipairs({'stove','campfire'})do
 for _,r in ipairs(recipes[station])do r.foodCategory=fishFoods[(r.needs[1]or{})[1]]and'Fish & Seafood'or'Other Food' end
 table.sort(recipes[station],function(a,b)if a.foodCategory~=b.foodCategory then return a.foodCategory<b.foodCategory end;if(a.level or 1)~=(b.level or 1)then return(a.level or 1)<(b.level or 1)end;return a.name<b.name end)
end
local originalRecipes=require('game.content_schema').copy(recipes);local contentVersion
local function refreshRecipes()local d=require('content_data');if contentVersion~=d then contentVersion=d;recipes=require('game.content_schema').copy(originalRecipes);require('game.content_rules').recipes(recipes)end end
function Crafting.new()refreshRecipes();return setmetatable({},Crafting)end
function Crafting:allRecipes()refreshRecipes();return recipes end
function Crafting:getRecipes(station)refreshRecipes();return recipes[station]or{}end
function Crafting:canCraft(recipe,inv,equippedTool,skills,world,player) local ok,why=require('game.content_rules').allowed(recipe.contentRule,skills,player);if not ok then return false,why end;ok,why=require('game.content_rules').gate('recipe',recipe.contentId or recipe.name,skills,player);if not ok then return false,why end;if recipe.lumber then local ok,why=require('game.lumber').access(recipe,world,player);if not ok then return false,why end end; if recipe.advancedRecipe then local ok,why=require('game.advanced_gear').access(recipe,world,player);if not ok then return false,why end end;if world then local ok,why=require('game.tailoring_content').access(recipe,world,player);if not ok then return false,why end end;if recipe.placeholder then return false,'Not in yet'end;if recipe.level and (not skills or not skills:get(recipe.skill or "Leatherworking") or skills:get(recipe.skill or "Leatherworking").level<recipe.level) then return false,"Requires "..(recipe.skill or "Leatherworking").." level "..recipe.level end;if recipe.tool then local hasTool=require("game.tool_slot").has(inv,equippedTool,recipe.tool,player);if recipe.tool=="Copper Tongs"then hasTool=hasTool or inv:hasItem("Iron Tongs")or equippedTool=="Iron Tongs"end;if recipe.tool=="Copper Dagger" then hasTool=hasTool or inv:hasItem("Copper Knife") or equippedTool=="Copper Knife" end;if not hasTool then return false,"missing_"..recipe.tool end end;for _,n in ipairs(recipe.needs) do local count=n[3] and inv:countBlessed(n[1]) or require('game.tailoring_content').count(inv,n[1]);if count<n[2] then return false,(n[3] and "missing_blessed_" or "missing_")..n[1] end end;return true end
function Crafting:craft(station,index,inv,skills,logger,equippedTool,world,player)
 local r=(recipes[station] or {})[index];if not r then return false,"bad_recipe" end
 local ok,why=self:canCraft(r,inv,equippedTool,skills,world,player);if not ok then return false,why end
 if r.lumber then return require('game.lumber').craft(r,inv,skills,world,player)end
 if r.seafood then return require('game.seafood_content').cook(r,station,inv,skills,logger)end
 if station=="stove" or station=="campfire" then
  local raw=r.output;inv:removeItems(raw,1)
  local lvl=skills:get("Cooking").level;local burnChance=math.max(3,(station=="campfire" and 52 or 32)-lvl);local burnt=math.random(1,100)<=burnChance
  local grade="D";if not burnt then local roll=math.random(1,100)+math.min(35,lvl);if roll>=115 then grade="A" elseif roll>=85 then grade="B" elseif roll>=55 then grade="C" end end
  local base=raw=="Raw Chicken"and"Chicken"or raw=="Raw Fish Fillet" and "Fish Fillet" or (raw=="Large Meat" and "Large Meat" or (raw=="Torn Hide" and "Jerky" or "Small Meat"))
  if raw=="Giga Rat Meat" or raw=="Cave Snake Meat" or require("game.whole_fish").levels[raw] then base=raw end
  base=require('game.high_tier_fish').processed[raw]or base
  local output=burnt and ("Burnt "..base) or ((base=="Jerky" and "" or "Cooked ")..base.." "..grade)
  if not inv:add(output,1) then inv:add(raw,1);return false,"bags_full" end
  local old,new,xp=skills:addXP("Cooking",r.xp);if logger then logger:log("FOOD_COOKED",{raw=raw,output=output,grade=burnt and "BURNT" or grade,cookingLevel=new,xpGained=r.xp,totalXp=xp});if new>old then logger:log("SKILL_LEVEL_UP",{skill="Cooking",from=old,to=new,totalXp=xp}) end end
  return true,output,r.xp
 end
 if r.advancedRecipe then
  local trial=require('game.rune_inventory').clone(inv);for _,n in ipairs(r.needs)do if not trial:removeItems(n[1],n[2])then return false,'missing_'..n[1]end end;if not trial:add(r.output,r.qty)then return false,'bags_full'end;inv.bagSlots=trial.bagSlots;local before,after,total=skills:addXP(r.skill,r.xp);if logger then logger:log('ADVANCED_EQUIPMENT_CRAFT',{item=r.output,skill=r.skill,xpGained=r.xp,totalXp=total});if after>before then logger:log('SKILL_LEVEL_UP',{skill=r.skill,from=before,to=after,totalXp=total})end end;return true,r.output,r.xp
 end
 if r.tailoring then
  local trial=require('game.rune_inventory').clone(inv);for _,n in ipairs(r.needs)do if not require('game.tailoring_content').consume(trial,n[1],n[2],r.output)then return false,'missing_'..n[1]end end
  if not trial:add(r.output,r.qty)then return false,'bags_full'end
  inv.bagSlots=trial.bagSlots;local old,new,total=skills:addXP('Tailoring',r.xp);if logger then logger:log('TAILORING_CRAFT',{station=station,item=r.output,xpGained=r.xp,totalXp=total});if new>old then logger:log('SKILL_LEVEL_UP',{skill='Tailoring',from=old,to=new,totalXp=total})end end;return true,r.output,r.xp
 end
 if r.byproducts then
  local trial=require('game.rune_inventory').clone(inv)
  for _,n in ipairs(r.needs) do trial:removeItems(n[1],n[2]) end
  if not trial:add(r.output,r.qty) then return false,'bags_full' end
  for _,n in ipairs(r.byproducts) do if not trial:add(n[1],n[2]) then return false,'bags_full' end end
  inv.bagSlots=trial.bagSlots;skills:addXP(r.skill,r.xp);return true,r.output,r.xp
 end
 -- Ingredients are removed first, so their slots can hold the crafted item.
 for _,n in ipairs(r.needs) do if n[3] then inv:removeBlessed(n[1],n[2]) else inv:removeItems(n[1],n[2]) end end
 local craftedOutput=r.output
 if r.bagGrade then
  local lvl=skills:get("Leatherworking").level;local roll=math.random(1,100)+math.min(35,lvl)
  local grade=(roll>=115 and "A") or (roll>=85 and "B") or (roll>=55 and "C") or "D"
  craftedOutput=r.output.." "..grade
 end
 if not inv:add(craftedOutput,r.qty) then for _,n in ipairs(r.needs) do for i=1,n[2] do inv:add(n[1],1);if n[3] then for bi=1,4 do local bb=inv.bagSlots[bi];if bb then for si=1,bb.size do local vv=bb.slots[si];if vv and vv.name==n[1] and not vv.blessed then vv.blessed=true;break end end end end end end end;return false,"bags_full" end
 if station=="alchemy" then local old,new,xp=skills:addXP("Alchemy",r.xp);if logger then logger:log("ALCHEMY_CRAFT",{station=station,item=craftedOutput,xpGained=r.xp,totalXp=xp,level=new});if new>old then logger:log("SKILL_LEVEL_UP",{skill="Alchemy",from=old,to=new,totalXp=xp}) end end;return true,r.output,r.xp end
 if station=="spinningWheel" then local skillName=r.skill or "Jewel Crafting";local old,new,xp=skills:addXP(skillName,r.xp);if logger then logger:log("CRAFTING_SKILL_CRAFT",{station=station,item=craftedOutput,xpGained=r.xp,totalXp=xp,level=new,skill=skillName});if new>old then logger:log("SKILL_LEVEL_UP",{skill=skillName,from=old,to=new,totalXp=xp}) end end;return true,r.output,r.xp end
 if station=="leathercraft" then
  local old,new,xp=skills:addXP("Leatherworking",r.xp)
  if logger then logger:log("LEATHERWORKING_CRAFT",{tool=r.tool,item=craftedOutput,xpGained=r.xp,totalXp=xp,level=new});if new>old then logger:log("SKILL_LEVEL_UP",{skill="Leatherworking",from=old,to=new,totalXp=xp}) end end
  return true,r.output,r.xp
 end
 if station=="woodcraft" or station=="sewing" or station=="inscription" or station=="tailoring" then
  local skillName=r.skill or "Jewel Crafting";local old,new,xp=skills:addXP(skillName,r.xp)
  if logger then logger:log("CRAFTING_SKILL_CRAFT",{station=station,tool=r.tool,item=craftedOutput,skill=skillName,xpGained=r.xp,totalXp=xp,level=new});if new>old then logger:log("SKILL_LEVEL_UP",{skill=skillName,from=old,to=new,totalXp=xp}) end end
  return true,r.output,r.xp
 end
 local old,new,xp=skills:addXP("Smithing",r.xp)
 if logger then logger:log("SMITHING_CRAFT",{station=station,item=craftedOutput,xpGained=r.xp,totalXp=xp,level=new}) end
 if new>old and logger then logger:log("SKILL_LEVEL_UP",{skill="Smithing",from=old,to=new,totalXp=xp}) end
 return true,craftedOutput,r.xp
end
local oldCraft=Crafting.craft
function Crafting:craft(station,index,inv,skills,logger,equippedTool,world,player)
 local r=self:getRecipes(station)[index]
 if r and(r.fieldcraft or r.contentRecipe)then
  local ok,why=self:canCraft(r,inv,equippedTool,skills,world,player);if not ok then return false,why end
  local trial=require('game.rune_inventory').clone(inv)
  for _,n in ipairs(r.needs)do trial:removeItems(n[1],n[2])end
  if not trial:add(r.output,r.qty)then return false,'bags_full'end
  inv.bagSlots=trial.bagSlots;skills:addXP(r.skill,r.xp);return true,r.output,r.xp
 end
 local ok,item,xp=oldCraft(self,station,index,inv,skills,logger,equippedTool,world,player)
 if ok and ui and ui.inv==inv and require('game.fieldcraft_ui').nearStation(ui,station)then ui.fieldcraft=ui.fieldcraft or{};local t=os.time();if t>=(ui.fieldcraft.facilityNext or 0)then ui.fieldcraft.facilityNext=t+60;skills:addXP('Fieldcraft',2)end end
 return ok,item,xp
end
Crafting.boneEnhancement=require('game.bone_religion').enhancement
require('game.quality').wrap(Crafting)
return Crafting
