local Races={names={'Human','Elf','Dwarf'}}
local elfSkills={Ranged=true,Agility=true,Magic=true,['Jewel Crafting']=true,Enchanting=true,Inscription=true,Tailoring=true}
local dwarfCrafts={Mining=true,Prospecting=true,Smithing=true,['Jewel Crafting']=true}
function Races.valid(race) return race=='Human' or race=='Elf' or race=='Dwarf' end
function Races.normalize(race) return Races.valid(race) and race or 'Human' end
function Races.multiplier(race,skill)
 if race=='Elf' then return elfSkills[skill] and 1.30 or 1 end
 if race=='Dwarf' then return dwarfCrafts[skill] and 1.30 or (skill=='Strength' or skill=='Health') and 1.15 or 1 end
 return 1.10
end
function Races.maxHealth(race,level)
 local base=math.max(5,level*5);return race=='Dwarf' and math.floor(base*1.2+.5) or base
end
function Races.maxStamina(race,level)
 local base=30+math.max(0,level-1)*5;return race=='Dwarf' and math.floor(base*1.2+.5) or base
end
function Races.description(race)
 if race=='Dwarf' then return '+30% XP: Mining, Prospecting, Smithing, Jewel Crafting. +15% XP: Strength, Health. Other skills: normal XP. Enduring: +20% maximum health and stamina. Short, bearded mountain craftspeople. Lore: hard to dominate and resistant to fire, yet tempted by treasure.' end
 if race=='Elf' then return '+30% XP: Ranged, Agility, Magic, Jewel Crafting, Enchanting, Inscription, Tailoring. Other skills: normal XP.' end
 return '+10% XP in every skill. Adaptable, all-round learners.'
end
return Races
