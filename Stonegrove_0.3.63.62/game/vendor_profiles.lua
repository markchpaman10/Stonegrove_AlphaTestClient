local P={}
P.tools={
 fisherman={"Fishing Pole","Copper Dagger"},
 smelter={"Copper Tongs","Iron Tongs"},
 anvil={"Copper Hammer","Iron Hammer","Iron Shield","Iron Sword","Iron Axe","Iron Pickaxe"},
 tanningVat={"Copper Dagger"}, hideStretcher={"Copper Dagger","Quiver"}, spinningWheel={"Shears"},
 alchemy={"Copper Dagger"}, stove={"Flint and Steel","Torch","Copper Dagger"}, magicAltar={"Staff","Spellbook"}, religion={},
 socketTable={"Chisel"}, enchantAltar={"Chisel"}, inscription={"Inscription Pen and Ink"}, tailoring={"Needle","Shears"}
}
P.names={fisherman="Fishing Supplies",smelter="Smelting Supplies",anvil="Smithing Supplies",tanningVat="Tanning Supplies",hideStretcher="Leatherworking Supplies",spinningWheel="Spinning Supplies",alchemy="Alchemy Supplies",stove="Cooking Supplies",magicAltar="Magic Supplies",religion="Religion Supplies",socketTable="Jewelcraft Supplies",enchantAltar="Enchanting Supplies",inscription="Inscription Supplies",tailoring="Tailoring Supplies"}
P.materials={
 fisherman={"Small Fish","Large Fish","Eel","Raw Fish Fillet"},
 smelter={"Small Copper Chunk","Large Copper Chunk","Copper Bar","Bronze bar","Small Iron Chunk","Large Iron Chunk","Iron Bar"},
 anvil={"Copper Bar","Bronze bar","Copper Arrowheads","Iron Bar","Iron Arrowheads"},
 tanningVat={"Raw Hide","Torn Hide","Soaked Hide","Large Raw Leather","Large Soaked Leather","Extra Large Raw Hide","Extra Large Soaked Hide"},
 hideStretcher={"Soaked Hide","Leather","Large Soaked Leather","Large Leather","Extra Large Soaked Hide","Extra Large Leather","Rawhide String","Pine Wood Parts","Oak Wood Parts"},
 spinningWheel={"Wool","Wool Thread","Hemp Fibers","Flax","Linen Cloth","Bow String"},
 alchemy={"Empty Flask","Empty Tube","Large Blue Mushroom","Brown Mushroom","Bush Root","Bush Greens","Purple Berries","Red Berries","Green Slime Jar","Giga Rat Blood","Pickled Large Meat","Pickled Small Meat","Potent Slime Jar","Slime-coated Bones"},
 stove={"Large Fish","Small Fish","Eel","Raw Fish Fillet","Large Meat","Small Meat"},
 magicAltar={"Pine Staff","Oak Staff","Spellbook","Stone Gravel"},
 religion={"Charred Wood","Fish Bones","Stone Gravel","Carved Feather","Carved Onyx","Green Slime Tube"},
 socketTable={"Ruby-bearing Rock","Sapphire-bearing Rock","Emerald-bearing Rock","Rough Ruby","Rough Sapphire","Rough Emerald","Cut Ruby","Cut Sapphire","Cut Emerald"},
 enchantAltar={"Ruby Dust","Sapphire Dust","Emerald Dust","Melee Skill Page","Ranged Skill Page"},
 inscription={"Empty Spell Page","Melee Skill Page","Ranged Skill Page"},
 tailoring={"Wool","Wool Thread","Flax","Linen Cloth","Hemp Fibers","Cloth Strip","Dyed Blue Cloth Strip","Leather"}
}
local function copy(src)local t={} for k,v in pairs(src or {})do if type(v)=='table'then t[k]={} for i,n in ipairs(v)do t[k][i]=n end else t[k]=v end end return t end
function P.makeShop(sprites,trade,tier)
 tier=math.max(0,math.min(2,tonumber(tier)or 0))
 local Shop=require('game.shop');local tools=copy(P.tools);local mats=copy(P.materials)
 local rawTools=copy(P.tools)[trade] or {};local rawMats=P.materials[trade] or {}
 local fullTools=tools[trade] or {};require('game.vendor_catalog').complete(sprites,tools,mats);fullTools=tools[trade] or fullTools
 local stock,seen={},{};local function add(n)if n and not seen[n]then seen[n]=true;stock[#stock+1]=n end end
 if trade=='religion' then for _,n in ipairs(rawMats)do add(n)end end
 if tier==0 then for _,n in ipairs(rawTools)do add(n)end
 elseif tier==1 then for _,n in ipairs(rawTools)do add(n)end;for i=1,math.min(10,#rawMats)do add(rawMats[i])end
 else for _,n in ipairs(fullTools)do add(n)end;for _,n in ipairs(rawMats)do add(n)end end
 local accepted={} for _,n in ipairs(fullTools)do accepted[n]=true end;for _,n in ipairs(rawMats)do accepted[n]=true end
 local suffix=({[0]='Basic',[1]='Tier 1',[2]='Tier 2'})[tier]
 local shop=Shop.trade(nil,(P.names[trade]or trade)..' - '..suffix,stock,accepted,rawMats,rawTools)
 if trade=='religion' then
  -- Religion vendors carry both raw rune materials and already-blessed versions.
  -- Blessed stock uses the existing item-state flag, never duplicate item definitions.
  for _,n in ipairs(rawMats) do shop.slots[#shop.slots+1]={name=n,qty=999,object={name=n,qty=1,blessed=true},priceMult=2} end
 end
 return require('game.content_rules').shop(shop,trade)
end
return P
