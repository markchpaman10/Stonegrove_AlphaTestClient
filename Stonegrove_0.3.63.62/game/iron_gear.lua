-- Iron metal equipment: Smithing 10-19, Melee Combat 10. Reinforced ranged/magic gear retains its existing levels.
local G={items={}}
local function armor(name,set,slot,level,defence,skill,craft,x,y,bonus)
 G.items[name]={title=name,type=slot=='head' and 'Head Armor' or slot=='legs' and 'Foot Armor' or 'Body Armor',set=set,slot=slot,requiredLevel=level,requiredSkill=skill,craftSkill=craft,defence=defence,iconX=x,iconY=y,tier=3,bonus=bonus or {}}
end
armor('Iron Boots','iron','legs',20,3,'Melee Combat','Smithing',64,176)
armor('Iron Helm','iron','head',25,5,'Melee Combat','Smithing',64,192)
armor('Iron Armor','iron','body',30,10,'Melee Combat','Smithing',64,208)
armor('Iron Reinforced Leather Boots','leather','legs',20,2,'Ranged','Leatherworking',144,176,{ranged=1})
armor('Iron Reinforced Leather Helm','leather','head',25,3,'Ranged','Leatherworking',144,208,{ranged=1})
armor('Iron Reinforced Leather Armor','leather','body',30,7,'Ranged','Leatherworking',144,192,{ranged=2})
armor('Iron Reinforced Mage Hat','mage','head',25,2,'Magic','Tailoring',224,192,{magic=2,healing=1})
armor('Iron Reinforced Mage Robes','mage','body',30,5,'Magic','Tailoring',224,176,{magic=3,healing=2})
armor('Iron Reinforced Mage Boots','mage','legs',20,2,'Magic','Tailoring',224,208,{magic=1,healing=1})
G.items['Dark Blue Dye']={title='Dark Blue Dye',type='Dye',tier=3,iconX=224,iconY=144,detail='Tailoring 20: make from Blue Dye and Purple Berries at the Tailor Table. Used to dye Linen Cloth dark blue. Right-click > Use opens Tailoring recipes.'}
G.items['Dark Blue Cloth']={title='Dark Blue Cloth',type='Tailoring Material',tier=3,iconX=224,iconY=160,detail='Tailoring 22: combine Linen Cloth with Dark Blue Dye at the Tailor Table. Used for iron reinforced mage hats and robes. Right-click > Use opens Tailoring recipes.'}
G.items['Small Iron Chunk']={title='Small Iron Chunk',type='Ore',tier=3,detail='Mine iron nodes at Mining 15 with a Copper Pickaxe. Smithing 20: smelt one chunk into an Iron Bar at a Smelter with Copper Tongs.'}
G.items['Large Iron Chunk']={title='Large Iron Chunk',type='Ore',tier=3,detail='Chance to find while mining iron at Mining 30. Smithing 30: smelt one large chunk into two Iron Bars.'}
G.items['Small Coal Chunk']={title='Small Coal Chunk',type='Ore',tier=3,detail='Mine coal seams at Mining 27 after prospecting. Requires a Copper Pickaxe. Store or sell; coal fuel recipes are not implemented yet.'}
G.items['Large Coal Chunk']={title='Large Coal Chunk',type='Ore',tier=3,detail='25% chance while mining coal at Mining 37. Store or sell; coal fuel recipes are not implemented yet.'}
G.items['Iron Bar']={title='Iron Bar',type='Material',tier=3,detail='Smelt iron chunks at a Smelter. Used for iron equipment and reinforced gear.'}
-- Iron weapon/tool tier. iconRow maps directly to the supplied 16x112 vertical sprite sheet.
local function ironItem(name,typ,row,detail,stats,craftSkill)
 local d={title=name,type=typ,tier=3,iconRow=row,detail=detail,craftSkill=craftSkill or 'Smithing'}
 for k,v in pairs(stats or {}) do d[k]=v end
 G.items[name]=d
end
ironItem('Iron Tongs','Tool',1,'Required to smelt iron chunks into Iron Bars.',{damage=2,attackSpeed=1.25,accuracy=1})
ironItem('Iron Arrows','Ammo',2,'Iron-tipped arrows for bows. Made from an Iron Arrowhead, a Feather, and any arrow shaft. Load into a Quiver or equip directly.',{})
ironItem('Iron Hammer','Tool',3,'Required for forging iron weapons, tools, shields, arrowheads, and iron armor at an Anvil.',{damage=2,attackSpeed=1.15,accuracy=2})
ironItem('Iron Shield','Offhand',4,'An iron shield reinforced with wood and leather.',{defence=6})
ironItem('Iron Sword','Weapon',5,'A forged iron sword.',{damage=6,attackSpeed=.62,accuracy=9})
ironItem('Iron Axe','Tool',6,'An iron woodcutting axe. Counts as an upgrade to the Copper Axe.',{damage=3,attackSpeed=.95,accuracy=4})
ironItem('Iron Pickaxe','Tool',7,'An iron mining pickaxe. Counts as an upgrade to the Copper Pickaxe.',{damage=3,attackSpeed=1.05,accuracy=3})
-- Arrowheads use the iron-arrow icon because the supplied art contains the finished arrow, not a separate head icon.
ironItem('Iron Arrowheads','Fletching Material',2,'Forged iron arrowheads. Use on any arrow shaft while carrying Feathers to assemble Iron Arrows.',{})
G.recipes={}
local function recipe(station,name,skill,level,xp,needs,tool,qty,output)
 G.recipes[#G.recipes+1]={station=station,name=name,output=output or name,qty=qty or 1,skill=skill,level=level,xp=xp,needs=needs,tool=tool,tierRecipe=true}
end
recipe('smelter','Iron Bar','Smithing',20,32,{{'Small Iron Chunk',1}},'Iron Tongs')
recipe('smelter','Smelt Large Iron Chunk','Smithing',30,68,{{'Large Iron Chunk',1}},'Iron Tongs',2,'Iron Bar')
recipe('tailoring','Dark Blue Dye','Tailoring',20,24,{{'Blue Dye',1},{'Purple Berries',2}})
recipe('tailoring','Dark Blue Cloth','Tailoring',22,30,{{'Linen Cloth',1},{'Dark Blue Dye',1}},'Needle')
recipe('anvil','Iron Tongs','Smithing',20,30,{{'Iron Bar',1}},'Copper Hammer')
recipe('anvil','Iron Hammer','Smithing',21,34,{{'Iron Bar',2},{'Oak Wood Parts',1}},'Copper Hammer')
recipe('anvil','Iron Arrowheads','Smithing',22,34,{{'Iron Bar',1}},'Iron Hammer',10)
recipe('anvil','Iron Shield','Smithing',23,48,{{'Iron Bar',2},{'Pine Wood Parts',2},{'Leather',1}},'Iron Hammer')
recipe('anvil','Iron Sword','Smithing',24,55,{{'Iron Bar',4},{'Oak Wood Parts',1},{'Leather',1}},'Iron Hammer')
recipe('anvil','Iron Axe','Smithing',25,48,{{'Iron Bar',3},{'Pine Wood Parts',2}},'Iron Hammer')
recipe('anvil','Iron Pickaxe','Smithing',26,48,{{'Iron Bar',2},{'Pine Wood Parts',2}},'Iron Hammer')
for name,d in pairs(G.items) do if d.slot then
 local needs;local st=d.craftSkill=='Smithing' and 'anvil' or d.craftSkill=='Leatherworking' and 'leathercraft' or 'tailoring'
 local bars=d.slot=='body' and 5 or d.slot=='head' and 2 or 1
 if d.set=='iron' then needs={{'Iron Bar',bars},{'Leather',d.slot=='body' and 3 or 1}}
 elseif d.set=='leather' then needs={{'Iron Bar',bars},{'Leather',d.slot=='body' and 5 or 2},{'Rawhide String',2}}
 else needs={{'Iron Bar',bars},{'Dark Blue Cloth',d.slot=='body' and 5 or 2},{'Wool Thread',2}} end
 recipe(st,name,d.craftSkill,d.requiredLevel,40+(d.requiredLevel-20)*3,needs,st=='anvil' and 'Iron Hammer' or 'Needle')
 end end
-- Preserve recipe materials, XP and artwork; move only Smithing/metal melee gates.
for name,d in pairs(G.items)do local level=require('game.metal_progression').requirement(name);if level then d.requiredSkill='Melee Combat';d.requiredLevel=level end end
for _,r in ipairs(G.recipes)do if r.skill=='Smithing'then r.level=math.max(10,math.min(19,r.level-10)) end;if r.station=='smelter'and r.output=='Iron Bar'then r.tool='Copper Tongs'end end
G.items['Small Iron Chunk'].detail='Mine iron nodes at Mining 15. Smithing 10: smelt into an Iron Bar with Copper Tongs or Iron Tongs.'
G.items['Large Iron Chunk'].detail='Chance to find while mining iron at Mining 30. Smithing 19: smelt into two Iron Bars with Copper Tongs or Iron Tongs.'
G.items['Iron Tongs'].detail='Upgraded tongs for smelting. Counts as Copper Tongs at a smelter.'
for name,d in pairs(require('game.advanced_gear').items)do if d.slot then G.items[name]=d end end
function G.load(s)
 local im=love.graphics.newImage('assets/equipment_tier2.png');im:setFilter('nearest','nearest');s.ironSheet=im;s.ironDolls={}
 local function q(x,y,w,h) return love.graphics.newQuad(x,y,w,h,im:getDimensions()) end
 for set,x in pairs({iron=0,leather=80,mage=160}) do local doll={body={},head={},legs={}}
  for row,dir in ipairs({'up','right','down'}) do doll.body[dir]={};doll.head[dir]={};doll.legs[dir]={}
   for frame=1,4 do local xx=x+(frame-1)*16;local yy=128+(row-1)*16;local foot=frame%2==0 and 13 or 14
    doll.body[dir][frame]=q(xx,yy,16,set=='mage' and 16 or foot)
    doll.head[dir][frame]=q(xx,yy+48,16,16)
    doll.legs[dir][frame]={quad=q(xx,yy+foot,16,2),offset=foot-8}
   end
  end;s.ironDolls[set]=doll
 end
 for name,d in pairs(G.items) do
  if d.slot and not d.customEquipment then local parts={'Requires '..d.requiredSkill..' '..d.requiredLevel..' to equip (player and mercenaries).','Defence +'..d.defence..'.'}
   for stat,n in pairs(d.bonus) do parts[#parts+1]='+'..n..' '..stat..'.' end
   parts[#parts+1]='Craft: '..d.craftSkill..' '..d.requiredLevel..'. Equip in '..(d.slot=='legs' and 'BOOTS' or d.slot:upper())..'.';d.detail=table.concat(parts,' ')
  end
  s.itemInfo[name]=d
  if d.iconX then s.itemImages[name]=im;s.itemQuads[name]=q(d.iconX,d.iconY,16,16) end
 end
 s.coalNode=love.graphics.newImage('assets/coal_node.png');s.coalNode:setFilter('nearest','nearest')
 local coal=love.graphics.newImage('assets/coal_items.png');coal:setFilter('nearest','nearest')
 for i,name in ipairs({'Small Coal Chunk','Large Coal Chunk'}) do s.itemImages[name]=coal;s.itemQuads[name]=love.graphics.newQuad((i-1)*16,0,16,16,coal:getDimensions()) end
 local ore=love.graphics.newImage('assets/iron_ore_items.png');ore:setFilter('nearest','nearest')
 for i,name in ipairs({'Small Iron Chunk','Large Iron Chunk'}) do s.itemImages[name]=ore;s.itemQuads[name]=love.graphics.newQuad((i-1)*16,0,16,16,ore:getDimensions()) end
 -- Preserve the existing bar silhouette, with the iron palette from the sheet.
 local data=love.image.newImageData('assets/itemBar_copper.png')
 data:mapPixel(function(x,y,r,g,b,a) local light=(r+g+b)/3;return light*.75,light*.85,math.min(1,light*1.05),a end)
 s.itemImages['Iron Bar']=love.graphics.newImage(data);s.itemImages['Iron Bar']:setFilter('nearest','nearest')
 local tools=love.graphics.newImage('assets/iron_weapons_tools.png');tools:setFilter('nearest','nearest')
 for name,d in pairs(G.items) do if d.iconRow then s.itemImages[name]=tools;s.itemQuads[name]=love.graphics.newQuad(0,(d.iconRow-1)*16,16,16,tools:getDimensions());s.itemInfo[name]=d end end
 s.ironNode=love.graphics.newImage('assets/iron_node.png');s.ironNode:setFilter('nearest','nearest');s.ironNodeQuads={}
 for i,name in ipairs({'depleted','mined','full'}) do s.ironNodeQuads[name]=love.graphics.newQuad(0,(i-1)*16,16,16,s.ironNode:getDimensions()) end
end
function G.draw(s,name,x,y,dir,frame,race)
 local d=G.items[name];if not d or not d.slot then return false end;if d.customEquipment then return require('game.paperdoll').draw(s,name,x,y,dir,frame,race)end
 local key=dir=='left' and 'right' or dir or 'down';local flip=dir=='left' and -1 or 1;frame=frame or 1
 local part=s.ironDolls[d.set][d.slot][key][frame];love.graphics.setColor(1,1,1)
 local offset,sy=require('game.humanoid').metrics(race,d.slot=='head' and 'head' or 'body')
 if d.slot=='legs' then love.graphics.draw(s.ironSheet,part.quad,x,y+offset+part.offset*sy,0,flip,sy,8,0)
 else require('game.humanoid').draw(s.ironSheet,part,x,y,flip,race,d.slot=='head' and 'head' or 'body') end
 return true
end
function G.bonuses(eq)
 local out={defence=0,melee=0,ranged=0,magic=0,healing=0,damage=0}
 for _,slot in ipairs({'head','body','legs'}) do local d=G.items[(eq or {})[slot]];if d and d.slot==slot then out.defence=out.defence+(d.defence or 0);for stat,v in pairs(d.bonus) do out[stat]=(out[stat] or 0)+v end end end
 return out
end
return G
