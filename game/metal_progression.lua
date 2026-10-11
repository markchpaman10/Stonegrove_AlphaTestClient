-- Metal-family progression shared by players, mercenaries, recipes and guides.
local M={items={},recipes={}}
M.tiers={{name='Copper',level=1,maxLevel=9},{name='Iron',level=10,maxLevel=19},{name='Steel',level=20,maxLevel=29,placeholder=true},{name='Nickel Copper',level=30,maxLevel=39,placeholder=true},{name='Nickel Iron',level=40,maxLevel=49,placeholder=true},{name='Nickel Steel',level=50,maxLevel=59,placeholder=true}}
local parts={'Sword','Shield','Helm','Armor','Boots','Axe','Pickaxe','Hammer','Tongs','Arrowheads','Arrows'}
for _,t in ipairs(M.tiers)do if t.placeholder then for _,part in ipairs(parts)do local name=t.name..' '..part
 if not require('game.advanced_gear').items[name]then
 M.items[name]={title=name,type='Unfinished Equipment',detail='Not in yet',placeholder=true,requiredSkill='Melee Combat',requiredLevel=t.level,smithingLevel=t.level,metal=t.name}
 if part~='Arrows'then M.recipes[#M.recipes+1]={station='anvil',name=name,output=name,qty=1,skill='Smithing',level=t.level,xp=0,needs={},placeholder=true,tierRecipe=true}end
 end end end end
function M.load(s)
 local pixels=love.image.newImageData(16,16);pixels:mapPixel(function()return 0,0,0,1 end)
 local black=love.graphics.newImage(pixels);black:setFilter('nearest','nearest');s.unfinishedMetalIcon=black
 for name,d in pairs(M.items)do s.itemImages[name]=black;s.itemQuads[name]=nil;s.itemInfo[name]=d end
end
function M.family(name)
 for i=#M.tiers,1,-1 do local t=M.tiers[i];if name:sub(1,#t.name+1)==t.name..' 'then return t end end
end
function M.requirement(name)
 local t=M.family(name);if not t then return nil end
 -- Iron-reinforced ranged/magic gear retains its own production and combat skill.
 if name:find('Reinforced',1,true)or name:find('Arrow',1,true)then return nil end
 local part=name:sub(#t.name+2);if ({Dagger=true,Longsword=true,Sword=true,Shield=true,Helm=true,Armor=true,Boots=true,Axe=true,Pickaxe=true,Hammer=true,Tongs=true,Knife=true})[part]then return t.level end
end
function M.guide(skill)
 local out={};if skill~='Smithing'and skill~='Melee Combat'then return out end
 for _,t in ipairs(M.tiers)do out[#out+1]={level=t.level,text=t.name..' equipment ('..t.level..'-'..t.maxLevel..')'..(t.name=='Steel'and' - armor, sword and shield available; other items Not in yet'or t.placeholder and' - Not in yet'or''),detail=t.name=='Steel'and'Steel Boots 20, Shield 23, Sword 24, Helm 25, Armor 29. Other Steel equipment is Not in yet.'or t.placeholder and'Not in yet'or(skill=='Smithing'and'Copper and Iron recipes unlock within their metal band.'or'Required melee level for this metal family, for players and mercenaries.'),icon=t.placeholder and(t.name..' Sword')or nil,placeholder=t.placeholder and t.name~='Steel'}end
 return out
end
return M
