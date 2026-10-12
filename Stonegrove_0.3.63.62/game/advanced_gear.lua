-- Shared new equipment, production and station rules. Artwork is preserved verbatim.
local A={items={},recipes={}}
function A.isQuiver(n)return n=='Quiver'or n=='Cave Snake Quiver'end
function A.arrowType(a)return type(a)=='table'and(A.isQuiver(a.name)and a.arrowType or a.name)or nil end
function A.isArrow(n)return n=='Copper Arrows'or n=='Iron Arrows'or n=='Snake Fang Arrows'end
function A.stationName(n)return ({metalLoom='Metal Weaving Loom',loom='Loom',spinningWheel='Spinning Wheel',anvil='Anvil',smelter='Smelter'})[n]or n end
local function item(n,t,detail,extra)local d={title=n,type=t,detail=detail,tier=4};for k,v in pairs(extra or{})do d[k]=v end;A.items[n]=d;return d end
local function recipe(n,station,skill,level,xp,needs,tool)
 local r={name=n,output=n,qty=1,station=station,skill=skill,level=level,xp=xp,needs=needs,tool=tool,tierRecipe=true,advancedRecipe=true}
 if station=='metalLoom'or station=='anvil'or station=='smelter'then r.stationRequirement=station end
 if station=='metalLoom'then r.station='tailoring'end
 A.recipes[#A.recipes+1]=r;return r
end
item('Ruby Staff','Weapon','Woodworking 30: 2 Cut Rubies + 2 Pine Logs. Requires Magic 30.',{damage=8,attackSpeed=1,accuracy=12,requiredSkill='Magic',requiredLevel=30,craftSkill='Woodworking',customEquipment=true,bonus={magic=4,damage=3}})
recipe('Ruby Staff','woodcraft','Woodworking',30,90,{{'Cut Ruby',2},{'Pine Logs',2}},'Copper Dagger')
item('Poplar Bow','Weapon','Fletching 30: 1 Bones + 3 Leather + 2 Poplar Logs + 1 Bow String. Requires Ranged 30.',{damage=6,attackSpeed=.9,accuracy=10,requiredSkill='Ranged',requiredLevel=30,craftSkill='Fletching',customEquipment=true})
item('Wolf Head','Leatherworking Material','Rare bonus from fully skinning a wolf (10% chance). Required for Cave Snake body armor.')
recipe('Poplar Bow','woodcraft','Fletching',30,90,{{'Bones',1},{'Leather',3},{'Poplar Logs',2},{'Bow String',1}})
item("Death's Robes",'Body Armor','Special robes: level-40-equivalent mage armor (9 defence, +5 Magic, +4 healing). Anyone can equip. Not craftable; available for authored rewards and editor placement.',{slot='body',defence=9,bonus={magic=5,healing=4},equivalentLevel=40,unrestricted=true,customEquipment=true})
item('Steel Bar' ,'Material','Smithing 20: smelt 1 Iron Bar and 1 Small Coal Chunk at a Smelter with Iron Tongs.')
item('Iron Weave Thread','Tailoring Material','Tailoring 30: weave 2 Iron Bars with 5 Wool Thread at the Metal Weaving Loom. Used for Magic Weave Iron equipment.')
item('Snake Fang Arrows','Ammo','Fletching 30: 1 Cave Snake Fang + 1 Pine Arrow Shaft + 1 Feather. Successful damaging hits have a 25% chance to poison for 2 seconds (1 damage per second). Equip directly or load either quiver.',{requiredSkill='Ranged',requiredLevel=30,customEquipment=true})
item('Cave Snake Quiver','Ammo','Leatherworking 30: 3 Cave Snake Leather + 2 Rawhide String, with a Needle. Equip in AMMO. Holds unlimited arrows of one type, including Snake Fang Arrows.',{requiredSkill='Ranged',requiredLevel=30,quiver=true,customEquipment=true})
local function armor(n,set,slot,combat,craft,level,defence,bonus)
 return item(n,slot=='head'and'Head Armor'or slot=='legs'and'Foot Armor'or'Body Armor','Requires '..combat..' '..(set=='steel'and 20 or 30)..' to equip. Craft: '..craft..' '..level..'. '..(set=='weave'and'Requires the Metal Weaving Loom and a Needle.'or'Carry the recipe tool.'),{set=set,slot=slot,requiredSkill=combat,requiredLevel=set=='steel'and 20 or 30,craftSkill=craft,craftLevel=level,defence=defence,bonus=bonus or{},customEquipment=true})
end
armor('Steel Boots','steel','legs','Melee Combat','Smithing',20,4)
armor('Steel Helm','steel','head','Melee Combat','Smithing',25,7)
armor('Steel Armor','steel','body','Melee Combat','Smithing',29,13)
armor('Cave Snake Boots','snake','legs','Ranged','Leatherworking',30,3,{ranged=2})
armor('Cave Snake Helm','snake','head','Ranged','Leatherworking',32,4,{ranged=2})
armor('Cave Snake Armor','snake','body','Ranged','Leatherworking',35,9,{ranged=3})
armor('Magic Weave Iron Boots','weave','legs','Magic','Tailoring',30,3,{magic=2,healing=1})
armor('Magic Weave Iron Hat','weave','head','Magic','Tailoring',32,3,{magic=3,healing=2})
armor('Magic Weave Iron Robes','weave','body','Magic','Tailoring',35,7,{magic=4,healing=3})
item('Steel Sword','Weapon','Smithing 24: forge at an Anvil with an Iron Hammer. Requires Melee Combat 20.',{damage=8,attackSpeed=.62,accuracy=11,requiredSkill='Melee Combat',requiredLevel=20,craftSkill='Smithing',customEquipment=true})
item('Steel Shield','Offhand','Smithing 23: forge at an Anvil with an Iron Hammer. Requires Melee Combat 20.',{defence=8,requiredSkill='Melee Combat',requiredLevel=20,craftSkill='Smithing',customEquipment=true})
recipe('Steel Bar','smelter','Smithing',20,45,{{'Iron Bar',1},{'Small Coal Chunk',1}},'Iron Tongs')
recipe('Iron Weave Thread','metalLoom','Tailoring',30,60,{{'Iron Bar',2},{'Wool Thread',5}})
for _,part in ipairs({'Boots','Helm','Armor'})do
 local d=A.items['Steel '..part];local amount=part=='Armor'and 5 or part=='Helm'and 2 or 1
 recipe('Steel '..part,'anvil','Smithing',d.craftLevel,50+(d.craftLevel-20)*5,{{'Steel Bar',amount},{'Leather',part=='Armor'and 3 or 1}},'Iron Hammer')
 local sd=A.items['Cave Snake '..part];recipe('Cave Snake '..part,'leathercraft','Leatherworking',sd.craftLevel,65+(sd.craftLevel-30)*5,{{'Cave Snake Leather',part=='Armor'and 5 or 2},{'Rawhide String',2}},'Needle')
end
recipe('Steel Sword','anvil','Smithing',24,75,{{'Steel Bar',4},{'Oak Wood Parts',1},{'Leather',1}},'Iron Hammer')
recipe('Steel Shield','anvil','Smithing',23,70,{{'Steel Bar',2},{'Pine Wood Parts',2},{'Leather',1}},'Iron Hammer')
recipe('Magic Weave Iron Boots','metalLoom','Tailoring',30,75,{{'Iron Weave Thread',2},{'Dark Blue Cloth',3}},'Needle')
recipe('Magic Weave Iron Hat','metalLoom','Tailoring',32,85,{{'Iron Weave Thread',2},{'Dark Blue Cloth',3}},'Needle')
recipe('Magic Weave Iron Robes','metalLoom','Tailoring',35,120,{{'Iron Weave Thread',4},{'Dark Blue Cloth',7}},'Needle')
recipe('Cave Snake Quiver','leathercraft','Leatherworking',30,80,{{'Cave Snake Leather',3},{'Rawhide String',2}},'Needle')
recipe('Snake Fang Arrows','woodcraft','Fletching',30,5,{{'Cave Snake Fang',1},{'Pine Arrow Shafts',1},{'Feather',1}})
for _,r in ipairs(A.recipes)do if r.output=='Cave Snake Armor'then r.needs[#r.needs+1]={'Wolf Head',1}end end
A.items['Cave Snake Armor'].detail=A.items['Cave Snake Armor'].detail..' Requires 1 Wolf Head.'
function A.configure(all)
 local active={};for _,r in ipairs(A.recipes)do active[r.output]=true end
 for _,list in pairs(all)do for i=#list,1,-1 do if active[list[i].output]then table.remove(list,i)end end end
 for _,r in ipairs(A.recipes)do all[r.station][#all[r.station]+1]=r end
end
function A.access(r,w,p)
 if not r.advancedRecipe or not r.stationRequirement then return true end
 if require('game.tailoring_content').near(w,p,r.stationRequirement)then return true end
 return false,'Move near a '..A.stationName(r.stationRequirement)
end
function A.load(s)
 s.itemImages['Poplar Bow']=love.graphics.newImage('assets/weaponPoplarBow.png');s.itemImages['Poplar Bow']:setFilter('nearest','nearest');local im=s.itemImages['Poplar Bow'];s.itemQuads['Poplar Bow']=love.graphics.newQuad(0,0,16,16,im:getDimensions())
 s.itemImages['Wolf Head']=love.graphics.newImage('assets/itemWolfHead.png');s.itemImages['Wolf Head']:setFilter('nearest','nearest')
 s.itemImages['Ruby Staff']=love.graphics.newImage('assets/rubyStaff.png');s.itemImages['Ruby Staff']:setFilter('nearest','nearest')
 local images={};for i=1,11 do images[i]=love.graphics.newImage('assets/advanced_gear_'..i..'.png');images[i]:setFilter('nearest','nearest')end
 s.metalLoomImage=images[7];s.paperDolls=s.paperDolls or{};s.caveSnakeQuiverQuads={empty=love.graphics.newQuad(0,0,16,16,32,16),copper=love.graphics.newQuad(16,0,16,16,32,16)}
 for id,d in pairs(A.items)do s.itemInfo[id]=d end
 s.itemImages['Iron Weave Thread']=images[6];s.itemImages['Snake Fang Arrows']=images[4];s.itemImages['Cave Snake Quiver']=images[5]
 s.itemImages['Steel Bar']=s.itemImages['Iron Bar'] -- Until a separate steel-bar sprite is supplied.
 s.itemQuads['Steel Bar']=s.itemQuads['Iron Bar']
 for _,set in ipairs({{name='steel',doll=1,icons=8,ids={'Steel Boots','Steel Armor','Steel Helm'}},{name='snake',doll=2,icons=10,ids={'Cave Snake Boots','Cave Snake Armor','Cave Snake Helm'}},{name='weave',doll=3,icons=9,ids={'Magic Weave Iron Boots','Magic Weave Iron Robes','Magic Weave Iron Hat'}}})do
  local im=images[set.doll];local iw,ih=im:getDimensions()
  for i,id in ipairs(set.ids)do
   local slot=A.items[id].slot;local doll={image=im,frames={},w=16,h=16};local ay=8
   for row,dir in ipairs({'up','right','down'})do doll.frames[dir]={};for frame=1,4 do local foot=frame%2==0 and 13 or 14;local yy=(row-1)*16;local h=16
    if slot=='head'then yy=yy+48 elseif slot=='body'then h=foot else yy=yy+foot;h=2 end
    doll.frames[dir][frame]=love.graphics.newQuad((frame-1)*16,yy,16,h,iw,ih)
   end end
   s.paperDolls[id]={doll=doll,slot=slot,ax=8,ay=ay,footSlot=slot=='legs'}
   s.itemImages[id]=images[set.icons];s.itemQuads[id]=love.graphics.newQuad(0,(i-1)*16,16,16,16,48)
  end
 end
 for id,x in pairs({['Steel Sword']=16,['Steel Shield']=32})do s.itemImages[id]=images[11];s.itemQuads[id]=love.graphics.newQuad(x,0,16,16,48,16)end
 s.itemInfo['Cave Snake Leather'].detail='Processed cave snake hide. Leatherworking 30-35: make Cave Snake equipment and a quiver with a Needle.'
 s.itemInfo['Cave Snake Fang'].detail='Use for Snake Fang Arrows (Fletching 30). Blessed fangs remain available as rune materials.'
end
function A.install(UI)
 local open=UI.openCrafting;function UI:openCrafting(station,source)return open(self,station=='metalLoom'and'tailoring'or station,source)end
 local start=UI.startCraft;function UI:startCraft(station,index)
  local r=self.crafting:getRecipes(station)[index];if r and r.advancedRecipe then
   local ok,why=A.access(r,self.world,self.player);if not ok then self.world:addPopup(self.player.x,self.player.y-24,why);return false,why end
   if require('game.multiplayer').active then return require('game.fieldcraft_ui').command(self,{op='craft',station=station,index=index},function(ok)if ok then self:craftBatchDone(station,index);if self.open[station]then self:startCraft(station,index)end else self.craftLimit=nil end end)end
  end;return start(self,station,index)
 end
end
return A
