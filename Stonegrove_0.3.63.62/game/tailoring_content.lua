-- Saved item IDs remain stable; display names describe the new colour progression.
local T={items={},recipes={},colours={
 {name='Light Blue',cloth='Dyed Blue Cloth Strip',dye='Blue Dye',x=0,y=0,level=5},
 {name='Dark Blue',cloth='Dark Blue Cloth',dye='Dark Blue Dye',x=160,y=0,level=10},
 {name='Red',cloth='Red Cloth Strip',dye='Red Dye',x=0,y=64,level=9},
 {name='Green',cloth='Green Cloth Strip',dye='Green Dye',x=160,y=64,level=14}}}
local function item(id,title,typ,detail,extra)
 local d={title=title,type=typ,detail=detail};for k,v in pairs(extra or{})do d[k]=v end;T.items[id]=d
end
local function recipe(id,level,xp,needs,station,tool)
 local r={name=id,output=id,qty=1,skill='Tailoring',level=level,xp=xp,needs=needs,station=station or'tailoring',tool=tool,tailoring=true,tierRecipe=true}
 if station=='loom'or station=='spinningWheel'then r.stationRequirement=station end
 T.recipes[#T.recipes+1]=r;return r
end
item('Wool','Wool','Material','Spin 1 Wool into 1 Wool Thread at a Spinning Wheel. Tailoring 1.')
item('Wool Thread','Wool Thread','Tailoring Material','Tailoring 1: spin Wool at a Spinning Wheel. Weave 5 thread into a Cloth Strip at a Loom (Tailoring 4).')
item('Cloth Strip','Cloth Strip','Tailoring Material','Tailoring 4: weave 5 Wool Thread at a Loom. Use dyes at the Loom to make coloured cloth.')
item('Blue Dye','Light Blue Dye','Dye','Tailoring 3: use an Empty Tube on a Large Blue Mushroom. Dye Cloth Strips at a Loom (Tailoring 5).')
item('Dark Blue Dye','Dark Blue Dye','Dye','Tailoring 10: 4 Purple Berries + 1 Large Blue Mushroom + 1 Empty Tube. Use on Cloth Strips at a Loom.')
item('Red Dye','Red Dye','Dye','Tailoring 9: 5 Red Berries + 1 Empty Tube. Use on Cloth Strips at a Loom.')
item('Green Dye','Green Dye','Dye','Tailoring 14: 3 Bush Greens + 1 Empty Tube. Use on Cloth Strips at a Loom.')
item('Wizard Robes','Wizard Robes','Body Armor','Tailoring 7: sew 5 Light Blue Cloth Strips with a Needle.',{defence=2})
item('Wizard Hat','Mage Hat','Head Armor','Tailoring 9: sew 3 Light Blue Cloth Strips with a Needle.',{defence=1})
recipe('Wool Thread',1,8,{{'Wool',1}},'spinningWheel')
recipe('Blue Dye',3,10,{{'Large Blue Mushroom',1},{'Empty Tube',1}})
recipe('Cloth Strip',4,15,{{'Wool Thread',5}},'loom')
recipe('Wizard Robes',7,45,{{'Dyed Blue Cloth Strip',5}},nil,'Needle')
recipe('Wizard Hat',9,30,{{'Dyed Blue Cloth Strip',3}},nil,'Needle')
recipe('Red Dye',9,18,{{'Red Berries',5},{'Empty Tube',1}})
recipe('Dark Blue Dye',10,22,{{'Purple Berries',4},{'Large Blue Mushroom',1},{'Empty Tube',1}})
recipe('Iron Reinforced Mage Hat',13,55,{{'Dark Blue Cloth',3},{'Iron Bar',1},{'Wool Thread',3}},nil,'Needle')
recipe('Green Dye',14,25,{{'Bush Greens',3},{'Empty Tube',1}})
recipe('Iron Reinforced Mage Robes',16,90,{{'Dark Blue Cloth',7},{'Iron Bar',2},{'Wool Thread',5}},nil,'Needle')
recipe('Iron Reinforced Mage Boots',17,65,{{'Dark Blue Cloth',3},{'Iron Bar',1},{'Wool Thread',4}},nil,'Needle')
for _,c in ipairs(T.colours)do
 item(c.cloth,c.name..' Cloth Strip','Tailoring Material','Dye 1 Cloth Strip with 1 '..(c.name..' Dye')..' at a Loom. Tailoring '..c.level..'. Used for matching-colour clothing.')
 recipe(c.cloth,c.level,12+c.level,{{'Cloth Strip',1},{c.dye,1}},'loom')
 for _,kind in ipairs({'Cape','Hood'})do
  local id=c.name..' Cloth '..kind;local hood=kind=='Hood';local level=hood and 20 or 19
  item(id,id,hood and'Head Armor'or'Cape','Tailoring '..level..': '..(hood and'4'or'5')..' Cloth Strips (any colour, including mixtures) + '..(hood and'5'or'9')..' Wool Thread. Sew with a Needle. '..(hood and'Equip in HEAD.'or'Equip in CAPE.'),{slot=hood and'head'or'cape',defence=hood and 2 or 1,colour=c.name})
  recipe(id,level,hood and 60 or 70,{{'Any Cloth Strip',hood and 4 or 5},{'Wool Thread',hood and 5 or 9}},nil,'Needle')
 end
end
T.clothNames={'Cloth Strip','Dyed Blue Cloth Strip','Dark Blue Cloth','Red Cloth Strip','Green Cloth Strip'}
function T.count(inv,name)
 if name~='Any Cloth Strip'then return inv:countItem(name)end;local total=0;for _,id in ipairs(T.clothNames)do total=total+inv:countItem(id)end;return total
end
function T.consume(inv,name,amount,output)
 if name~='Any Cloth Strip'then return inv:removeItems(name,amount)end
 if T.count(inv,name)<amount then return false end
 local preferred;for _,c in ipairs(T.colours)do if output:find(c.name,1,true)then preferred=c.cloth end end
 local order={};if preferred then order[1]=preferred end;for _,id in ipairs(T.clothNames)do if id~=preferred then order[#order+1]=id end end
 for _,id in ipairs(order)do local n=math.min(amount,inv:countItem(id));if n>0 then inv:removeItems(id,n);amount=amount-n end;if amount==0 then break end end;return amount==0
end
item('Black Berries','Black Berries','Alchemy Ingredient','Gather from berry bushes. Combine 6 with an Empty Tube for Black Dye.')
item('Black Dye','Black Dye','Dye','Tailoring 14: 6 Black Berries + 1 Empty Tube. Dye Linen Cloth at a Loom.')
item('Black Linen Cloth','Black Linen Cloth','Tailoring Material','Tailoring 14: 1 Linen Cloth + 1 Black Dye at a Loom. Used for Black Cape and Black Hood.')
item('Black Cape','Black Cape','Cape','Tailoring 19: 5 Black Linen Cloth + 9 Wool Thread, with a Needle.',{slot='cape',defence=1})
item('Black Hood','Black Hood','Head Armor','Tailoring 20: 4 Black Linen Cloth + 5 Wool Thread, with a Needle.',{slot='head',defence=2})
recipe('Black Dye',14,25,{{'Black Berries',6},{'Empty Tube',1}})
recipe('Black Linen Cloth',14,26,{{'Linen Cloth',1},{'Black Dye',1}},'loom')
recipe('Black Cape',19,70,{{'Black Linen Cloth',5},{'Wool Thread',9}},nil,'Needle')
recipe('Black Hood',20,60,{{'Black Linen Cloth',4},{'Wool Thread',5}},nil,'Needle')
T.clothNames[#T.clothNames+1]='Black Linen Cloth'
local outputs={};for _,r in ipairs(T.recipes)do outputs[r.output]=r end
function T.configure(all)
 -- Replace conflicting recipes in place; unrelated tailoring and fiber recipes survive.
 for _,list in pairs(all)do for i=#list,1,-1 do if outputs[list[i].output]then table.remove(list,i)end end end
 all.loom={}
 for _,r in ipairs(T.recipes)do r.displayName=(T.items[r.output]or{}).title or r.output:gsub('^Iron Reinforced','Reinforced');local list=all[r.station];list[#list+1]=r;if r.station~='tailoring'then all.tailoring[#all.tailoring+1]=r end end
end
function T.near(w,p,station)
 if not w or not p then return false end
 local function near(o)return o and(o.x-p.x)^2+(o.y-p.y)^2<=55^2 end
 if w.authoredObjects then for _,o in ipairs(w.authoredObjects)do if o.id==station and near(o)then return true end end
 else for _,v in ipairs(w.villages or{})do if near(v[station])then return true end end;if near(w[station])then return true end end
 return false
end
function T.access(r,w,p)
 if not r.tailoring or not r.stationRequirement then return true end
 if T.near(w,p,r.stationRequirement)then return true end
 return false,'Move near a '..(r.stationRequirement=='loom'and'Loom'or'Spinning Wheel')
end
function T.load(s)
 local function image(i)local im=love.graphics.newImage('assets/tailoring_'..i..'.png');im:setFilter('nearest','nearest');return im end
 s.loomImage=image(1)
 if s.itemInfo['Linen Bag']then s.itemInfo['Linen Bag'].detail='Tailoring 50: sew 5 Wool Thread and 5 Cloth Strips of any colour (mixtures accepted), using a Needle.'end
 for id,i in pairs({Wool=2,['Wool Thread']=3,['Cloth Strip']=4,['Wizard Robes']=5,['Blue Dye']=6,['Dark Blue Dye']=7,['Wizard Hat']=8,['Red Dye']=9,['Dark Blue Cloth']=10,['Green Dye']=11,['Iron Reinforced Mage Boots']=12})do s.itemImages[id]=image(i);s.itemQuads[id]=nil end
 local sheet=image(13);local iw,ih=sheet:getDimensions();s.paperDolls=s.paperDolls or{}
 for _,c in ipairs(T.colours)do
  local function quad(x,y)return love.graphics.newQuad(c.x+x,c.y+y,16,16,iw,ih)end
  if c.name~='Light Blue'then s.itemImages[c.cloth]=sheet;s.itemQuads[c.cloth]=quad(0,32)
  else
   -- The light-blue quadrant has no cloth icon; use the supplied white strip
   -- silhouette and the exact palette from its paper doll.
   local d=love.image.newImageData('assets/tailoring_4.png');d:mapPixel(function(x,y,r,g,b,a)return 0,153/255,219/255,a end);s.itemImages[c.cloth]=love.graphics.newImage(d);s.itemImages[c.cloth]:setFilter('nearest','nearest');s.itemQuads[c.cloth]=nil
  end
  for _,kind in ipairs({'Cape','Hood'})do
   local id=c.name..' Cloth '..kind;local hood=kind=='Hood';local doll={image=sheet,frames={},w=16,h=16}
   for row,dir in ipairs({'up','right','down'})do doll.frames[dir]={};for frame=1,4 do doll.frames[dir][frame]=quad((hood and 80 or 16)+(frame-1)*16,(row-1)*16)end end
   s.paperDolls[id]={doll=doll,slot=hood and'head'or'cape',ax=8,ay=8};s.itemImages[id]=sheet;s.itemQuads[id]=quad(0,hood and 0 or 16)
  end
 end
 for id,d in pairs(T.items)do s.itemInfo[id]=d end
 for id,level in pairs({['Iron Reinforced Mage Hat']=13,['Iron Reinforced Mage Robes']=16,['Iron Reinforced Mage Boots']=17})do
  local d=s.itemInfo[id];d.title=id:gsub('^Iron ','');d.detail='Tailoring '..level..': sew Dark Blue Cloth Strips, Iron Bars and Wool Thread with a Needle. '..(id:find('Boots')and'Equip in BOOTS.'or id:find('Hat')and'Equip in HEAD.'or'Equip in BODY.')..' Requires Magic '..d.requiredLevel..' to equip.'
 end
end
function T.useRecipe(tool,target)
 if tool=='Empty Tube'and target=='Black Berries'then return 'Black Dye'end
 if tool=='Black Dye'and target=='Linen Cloth'then return 'Black Linen Cloth'end
 if tool=='Empty Tube'then return ({['Large Blue Mushroom']='Blue Dye',['Red Berries']='Red Dye',['Purple Berries']='Dark Blue Dye',['Bush Greens']='Green Dye'})[target]end
 for _,c in ipairs(T.colours)do if tool==c.dye and target=='Cloth Strip'then return c.cloth end end
end
function T.install(UI)
 local start=UI.startCraft
 function UI:startCraft(station,index)
  local r=self.crafting:getRecipes(station)[index];if r and r.tailoring then
   local ok,why=T.access(r,self.world,self.player);if not ok then self.world:addPopup(self.player.x,self.player.y-24,why);return false,why end
   if require('game.multiplayer').active then return require('game.fieldcraft_ui').command(self,{op='craft',station=station,index=index},function(ok)if ok and self.open[station]then self:startCraft(station,index)end end)end
  end
  return start(self,station,index)
 end
 local options=UI.contextOptions
 function UI:contextOptions(it)local out=options(self,it);if it.name=='Wool Thread'or T.items[it.name]and(T.items[it.name].type=='Tailoring Material'or T.items[it.name].type=='Dye')then local found;for _,v in ipairs(out)do if v=='Use'then found=true end end;if not found then table.insert(out,1,'Use')end end;return out end
 local compatible=UI.isUseCompatible
 function UI:isUseCompatible(tool,target)local name=type(target)=='table'and target.name or target;if T.useRecipe(tool,name)then return true end;if(tool=='Needle'or tool=='Wool Thread')and T.items[name]and T.items[name].type=='Tailoring Material'then return true end;return compatible(self,tool,target)end
 local context=UI.doContextOption
 function UI:doContextOption(opt)
  local c=self.context;local b=c and self.inv:getBag(c.bag);local it=b and b.slots[c.slot]
  if opt=='Use'and it and(T.items[it.name]and(T.items[it.name].type=='Tailoring Material'or T.items[it.name].type=='Dye'))then self.useTarget={tool=it.name,bag=c.bag,slot=c.slot};self.context=nil;return end
  return context(self,opt)
 end
 local use=UI.startItemUse
 function UI:startItemUse(bi,slot)
  local b=self.inv:getBag(bi);local it=b and b.slots[slot];local tool=self.useTarget and self.useTarget.tool
  local output=it and T.useRecipe(tool,it.name)
  if output then self.useTarget=nil;self:openCrafting('tailoring','inventory_use');for index,r in ipairs(self.crafting:getRecipes('tailoring'))do if r.output==output then return self:startCraft('tailoring',index)end end;return false end
  if it and(tool=='Needle'or tool=='Wool Thread')and T.items[it.name]and T.items[it.name].type=='Tailoring Material'then self.useTarget=nil;self:openCrafting('tailoring','inventory_use');return true end
  return use(self,bi,slot)
 end
end
return T
