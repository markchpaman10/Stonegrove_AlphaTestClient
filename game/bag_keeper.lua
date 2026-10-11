local K={bagName='Medium Leather Bag',grade='D',reach=55}
local B=require('game.bag_system')
local function bag(name)return type(name)=='string'and B.defs[B.name(name)]~=nil end
local function itemsHave(t)for _,o in pairs(t or{})do if type(o)=='table'and bag(o.name)then return true end end;return false end
function K.vendors(w)
 if w.isCave then return{}end
 if w.bagKeepers and #w.bagKeepers>0 then local placed={};for _,n in ipairs(w.bagKeepers)do if not n.eventHidden then placed[#placed+1]=n end end;return placed end
 local out={};local sources={};for _,n in ipairs(w.tradeKeepers or{})do if n.trade=='misc'then sources[#sources+1]=n end end
 for _,n in ipairs(w.traders or{})do sources[#sources+1]=n end
 if #sources==0 and w.tradeKeepers and w.tradeKeepers[1]then sources[1]=w.tradeKeepers[1]end
 for _,n in ipairs(sources)do local x,y=n.x+26,n.y+20;if not w.map or not w.map.isLand or w.map:isLand(x,y)then out[#out+1]={x=x,y=y,race='Human',name='Bag Keeper'}end end;return out
end
function K.at(w,x,y)for _,n in ipairs(K.vendors(w))do if(n.x-x)^2+(n.y-y)^2<14^2 then return n end end end
function K.owner(a)return require('game.gravestones').owner(a)end
function K.groundOwner(w,g)
 if g.bagOwner then return g.bagOwner end
 -- Old grave drops predate owner tags; their broken marker retains the owner.
 if g.graveLoot then local best,dist;for _,v in pairs(w.gravestones or{})do if v.broken then local d=(v.x-g.x)^2+(v.y-g.y)^2;if d<=64^2 and(not dist or d<dist)then best,dist=v.owner,d end end end;return best end
end
function K.eligible(a,worlds)
 local inv=a.inv
 for _,b in pairs(inv.bagSlots or{})do if b then return false,'You already have an equipped bag.'end end
 if itemsHave(inv.bank)then return false,'You have a bag in the bank.'end
 if itemsHave((a.fieldcraft or{}).recovery)then return false,'Recover the bag in your camp storage.'end
 local owner=K.owner(a);local seen={}
 local function visit(w)
  if type(w)~='table'or seen[w]then return end;seen[w]=true
  for _,g in pairs(w.groundItems or w.graveGround or{})do if bag(g.name or(g.object or{}).name)and K.groundOwner(w,g)==owner then return 'Your bag is still on the ground. Recover it first.'end end
  for _,g in pairs(w.gravestones or{})do if g.owner==owner and g.contents and(not g.broken)and(itemsHave(g.contents.bags)or itemsHave(g.contents.equipmentItems))then return 'Your bag is still protected in your grave.'end end
  for _,c in pairs(w.playerCamps or{})do if c.owner==owner and itemsHave(c.storage)then return 'You have a bag in camp storage.'end end
  for _,v in pairs(w.caveInstances or w.caves or{})do local why=visit(v.state or v);if why then return why end end
  local why=visit(w.overworld);if why then return why end
 end
 for _,w in pairs(worlds or{})do local why=visit(w);if why then return false,why end end
 return true
end
function K.worlds(w)
 local all={w};local regions=require('game.regions');for _,v in pairs(regions.cache or{})do all[#all+1]=v end;for _,v in pairs(regions.states or{})do all[#all+1]=v end;return all
end
function K.claim(w,a,cmd,worlds)
 if a.player.hp<=0 then return false,'You must be alive to receive a bag.'end
 local n=K.at(w,cmd.x or-100000,cmd.y or-100000);if not n or(n.x-a.player.x)^2+(n.y-a.player.y)^2>K.reach^2 then return false,'Move near the Bag Keeper at the trader.'end
 local ok,why=K.eligible(a,worlds or K.worlds(w));if not ok then return false,why end
 a.inv.bagSlots={[1]={name=K.bagName,qualityGrade=K.grade,slots={}}};a.inv.activeBag=1;a.inv:applyStrengthBagBonus(a.skills:get('Strength').level)
 return true,'A starter bag has been equipped. Good luck out there!'
end
function K.click(ui,x,y)
 local n=K.at(ui.world,x,y);if not n then return false end
 require('game.fieldcraft_ui').command(ui,{op='starterBag',x=n.x,y=n.y});return true
end
function K.draw(w,sprites,add)
 for i,n in ipairs(K.vendors(w))do local npc=n;add(n.y+8,function()local key='bagKeeper:'..i..':'..tostring(w.regionId);sprites.npcCosmetics:drawShadow(npc,sprites,key);sprites.npcCosmetics:draw(npc,sprites,key);local image=sprites.itemImages[K.bagName];local quad=sprites.itemQuads[K.bagName];love.graphics.setColor(1,1,1);if image and quad then love.graphics.draw(image,quad,npc.x+7,npc.y+3,0,1,1,8,8)end end)end
end
return K
