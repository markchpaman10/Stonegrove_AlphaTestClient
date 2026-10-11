local V={}
V.excluded={['Raw Lobster Tail']=true,["Death's Robes"]=true,['Copper Coins']=true,['Silver Coins']=true,['Gold Coins']=true,['Lit Torch']=true,Logs=true,['Basic Wood Parts']=true,Staff=true,['Arrow Shafts']=true,['Unstrung Bow']=true,Bow=true}
for _,n in ipairs({'Linen Bag','Small Leather Bag D','Small Leather Bag C','Small Leather Bag B','Small Leather Bag A','Large Leather Bag D','Large Leather Bag C','Large Leather Bag B','Large Leather Bag A'})do V.excluded[n]=true end
function V.complete(sprites,tools,materials)
 local function add(st,name)
  local list=tools[st];for _,n in ipairs(list) do if n==name then return end end;list[#list+1]=name
 end
 local craft=require('game.crafting').new()
 for _,st in ipairs({'anvil','tailoring','alchemy','inscription','spinningWheel'}) do
  for _,r in ipairs(craft:getRecipes(st)) do if sprites.itemImages[r.output] then add(st,r.output) end end
 end
 local names={};for name in pairs(sprites.itemImages) do names[#names+1]=name end;table.sort(names)
 for _,name in ipairs(names) do
  local info=sprites.itemInfo[name] or {};local st
  if name=='Iron Tongs' then st='smelter'
  elseif name=='Iron Arrows' then st='spinningWheel'
  elseif require('game.iron_gear').items[name] then local d=require('game.iron_gear').items[name];st=d.craftSkill=='Smithing' and 'anvil' or d.craftSkill=='Leatherworking' and 'hideStretcher' or d.craftSkill=='Tailoring' and 'tailoring' or (name:find('Iron',1,true) or name:find('Coal',1,true)) and 'smelter' or 'tailoring'
  elseif name=='Potent Health Flask' or name=='Potent Antidote' then st='alchemy'
  elseif name=='Fishing Pole' or name=='Small Fish' or name=='Large Fish' or name=='Eel' or name=='Raw Fish Fillet' then st='fisherman'
  elseif name:find('Leather',1,true) and (info.type=='Bag' or info.type=='Head Armor' or info.type=='Body Armor') or require('game.advanced_gear').isQuiver(name) then st='hideStretcher'
  elseif name=='Wizard Hat' or name=='Wizard Robes' or name=='Linen Bag' or (require('game.bag_system').defs[name]and name:find('Linen',1,true)) then st='tailoring'
  elseif name=='Pine Bow' or name=='Oak Bow' or name=='Copper Arrows' or name:find('Unstrung Bow',1,true) or name:find('Arrow Shafts',1,true) then st='spinningWheel'
  elseif info.type=='Food' or info.type=='Burnt Food' or info.type=='Raw Food' then st='stove'
  elseif info.type=='Potion' then st='alchemy' end
  if st and not V.excluded[name] then add(st,name) end
 end
end
function V.misc(sprites,keepers)
 local covered={};for _,k in ipairs(keepers) do for _,it in ipairs(k.shop.slots) do covered[it.name]=true end end
 local stock,accepted={},{}
 for name in pairs(sprites.itemImages) do if not covered[name] and not V.excluded[name] then stock[#stock+1]=name;accepted[name]=true end end
 table.sort(stock);return stock,accepted
end
return V
