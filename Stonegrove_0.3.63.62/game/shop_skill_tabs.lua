local T={}
local membership
local function build()
 membership={}
 local function add(name,skill)if not name or not skill then return end;membership[name]=membership[name]or{};membership[name][skill]=true end
 for _,recipes in pairs(require('game.crafting').new():allRecipes())do
  for _,r in ipairs(recipes)do
   add(r.output,r.skill);add(r.tool,r.skill)
   for _,n in ipairs(r.needs or{})do add(n[1],r.skill)end
  end
 end
 for _,name in ipairs({'Small Fish','Large Fish','Eel','Tuna','Swordfish','Shark','Manta Ray','Shrimp','Crab','Lobster','Shrimp Pot','Crab Pot','Lobster Pot','Fishing Pole','Pine Fishing Pole','Poplar Fishing Pole'})do add(name,'Fishing')end
 for name in pairs(require('game.religion').blessXP)do add(name,'Religion')end
end
function T.skills(name,sprites)
 if not membership then build()end
 local plain=name:gsub(" [ABCD]$","");local base=membership[name]or membership[plain];local result={};for skill in pairs(base or{})do result[skill]=true end
 if name:find('Pickaxe',1,true)or name:find('Pick Axe',1,true)or name:find('Ore',1,true)or name=='Coal'then result.Mining=true end
 if name:find('Axe',1,true)and not name:find('Pick',1,true)or name:find('Logs',1,true)then result.Woodcutting=true end
 if name:find('Fishing Pole',1,true)or name:find('Fish',1,true)and not name:find('Bones',1,true)then result.Fishing=true end
 if name:find('Bone',1,true)or name:find('Skull',1,true)or name:find('Ribs',1,true)then result.Religion=true end
 if name:find('Spell',1,true)or name=='Rune Bag'or name=='Staff'then result.Magic=true end
 if name:find('Gem',1,true)or name:find('Ruby',1,true)or name:find('Onyx',1,true)or name:find('Emerald',1,true)or name:find('Sapphire',1,true)then result['Jewel Crafting']=true end
 local info=sprites and sprites.itemInfo and sprites.itemInfo[name]
 if info and(info.type=="Food"or info.type=="Burnt Food"or info.type=="Raw Food")then result.Cooking=true end
 if name:find("Bag",1,true)and name:find("Linen",1,true)then result.Tailoring=true elseif name:find("Bag",1,true)and name:find("Leather",1,true)then result.Leatherworking=true end
 if not next(result)then result.Other=true end
 return result
end
function T.enabled(u)return u.shop and u.shop.title=='Town Supplies'end
function T.tabs(u)
 if not T.enabled(u)then return{}end
 local seen={};for _,row in ipairs(u.shop.slots)do for skill in pairs(T.skills(row.name,u.sprites))do seen[skill]=true end end
 local tabs={};for skill in pairs(seen)do tabs[#tabs+1]=skill end;table.sort(tabs);table.insert(tabs,1,'All');return tabs
end
function T.offset(u)return math.ceil(#T.tabs(u)/2)*24 end
function T.fit(u)
 if not T.enabled(u)then return end
 local width,height=love.graphics.getDimensions();local panelHeight=320+T.offset(u);local scale=(u.panelScales or{}).shop or 1
 if panelHeight*scale>height-8 then scale=math.max(.55,math.min(scale,(height-8)/panelHeight));u.panelScales=u.panelScales or{};u.panelScales.shop=scale end
 local p=u.pos.shop;p.x=math.max(0,math.min(p.x,width-270*scale));p.y=math.max(0,math.min(p.y,height-panelHeight*scale))
end
function T.view(u)
 local rows,indices={},{};local chosen=u.shopSkillTab or'All';local valid=chosen=='All'
 for _,tab in ipairs(T.tabs(u))do if tab==chosen then valid=true end end
 if not valid then chosen='All';u.shopSkillTab='All' end
 for i,row in ipairs(u.shop.slots)do if not T.enabled(u)or chosen=='All'or T.skills(row.name,u.sprites)[chosen]then rows[#rows+1]=row;indices[#indices+1]=i end end
 return rows,indices
end
function T.select(u,tab)
 u.shopSkillTab=tab;u.shopScroll=0;u.lastShopClick=nil;u.lastShopSellClick=nil;u.shopContext=nil;u.selectedShopRow=nil
end
function T.tabAt(u,mx,my)
 local x,y=u:rect('shop');for i,tab in ipairs(T.tabs(u))do local tx=x+12+(i-1)%2*123;local ty=y+58+math.floor((i-1)/2)*24
  if mx>=tx and mx<tx+120 and my>=ty and my<ty+22 then return tab end
 end
end
function T.draw(u,x,y)
 for i,tab in ipairs(T.tabs(u))do local tx=x+12+(i-1)%2*123;local ty=y+58+math.floor((i-1)/2)*24
  local selected=(u.shopSkillTab or'All')==tab;love.graphics.setColor(selected and .35 or .12,selected and .28 or .11,.09);love.graphics.rectangle('fill',tx,ty,120,22,3,3);love.graphics.setColor(1,1,1);love.graphics.printf(tab,tx,ty+4,120,'center')
 end
end
function T.sellClick(u,bi,slot,mx,my)
 if not u.open.shop then u.lastShopSellClick=nil;return false end
 local bag=u.inv:getBag(bi);local obj=bag and bag.slots[slot];if not obj or not u.shop:acceptsSale(obj.name)or u.inv:isCurrency(obj.name)then u.lastShopSellClick=nil;return false end
 -- Use the existing sale action, including loaded-container protections and online commands.
 local option;for _,opt in ipairs(u:contextOptions(obj))do if opt:sub(1,5)=='Sell 'and opt:sub(1,8)~='Sell All'then option=opt;break end end
 if not option then u.lastShopSellClick=nil;return false end
 local now=love.timer.getTime();local previous=u.lastShopSellClick
 u.dragSlot=nil;u.dragBagIndex=nil
 if previous and previous.shop==u.shop and previous.object==obj and previous.bag==bi and previous.slot==slot and (mx-previous.x)^2+(my-previous.y)^2<=25 and now-previous.time<=.35 then
  u.lastShopSellClick=nil;u.context={bag=bi,slot=slot,x=mx,y=my};u:doContextOption(option)
 else u.lastShopSellClick={shop=u.shop,object=obj,bag=bi,slot=slot,time=now,x=mx,y=my}end
 return true
end
return T
