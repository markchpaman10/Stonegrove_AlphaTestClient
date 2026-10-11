local A={}
local keys=require('game.villages').keys
local function marker(x,y)return {x=x or -100000,y=y or -100000,jobs={},state='empty'}end
-- Authored layout is immutable in the running game. Cache each protection padding
-- separately; preserve inclusive zones/paths and strict NPC-object boundaries.
local SIZE=128
local EMPTY={}
local function protection(w,a,pad)
 local objects,paths,zones=a.objects or EMPTY,a.paths or EMPTY,a.townZones or EMPTY
 local c=w._protectionPerfCache
 if not c or c.authored~=a or c.objects~=objects or c.paths~=paths or c.zones~=zones or c.objectCount~=#objects or c.pathCount~=#paths or c.zoneCount~=#zones then
  c={authored=a,objects=objects,paths=paths,zones=zones,objectCount=#objects,pathCount=#paths,zoneCount=#zones,paddings={}}
  w._protectionPerfCache=c
 end
 local rows=c.paddings[pad]
 if rows then return rows end
 rows={};c.paddings[pad]=rows
 local function add(left,top,right,bottom,strict)
  local rect={left,top,right,bottom,strict}
  for by=math.floor(top/SIZE),math.floor(bottom/SIZE) do
   local row=rows[by];if not row then row={};rows[by]=row end
   for bx=math.floor(left/SIZE),math.floor(right/SIZE) do
    local list=row[bx];if not list then list={};row[bx]=list end;list[#list+1]=rect
   end
  end
 end
 for _,z in ipairs(zones)do add(z.x-pad,z.y-pad,z.x+z.w+pad,z.y+z.h+pad,false)end
 for _,o in ipairs(objects)do add(o.x-pad-40,o.y-pad-40,o.x+pad+40,o.y+pad+40,true)end
 for _,p in ipairs(paths)do add(p.x-pad,p.y-pad,p.x+16+pad,p.y+16+pad,false)end
 return rows
end
function A.protected(w,x,y,pad)
 if require('game.regions').edgeProtected(w.map,x,y,pad+40)then return true end
 local a=w.map.authored;if not a then return false end
 local rows=protection(w,a,pad);local row=rows[math.floor(y/SIZE)];local list=row and row[math.floor(x/SIZE)]
 for _,r in ipairs(list or EMPTY)do
  if r[5] then
   if x>r[1] and y>r[2] and x<r[3] and y<r[4] then return true end
  elseif x>=r[1] and y>=r[2] and x<=r[3] and y<=r[4] then return true end
 end
 return false
end

function A.finish(w,a,makeEnemy)
 local Shop=require('game.shop')
 for _,list in ipairs({w.nodes,w.enemies})do for i=#list,1,-1 do local v=list[i];if require('game.regions').edgeProtected(w.map,v.x,v.y,64)then table.remove(list,i)end end end
 w.bagKeepers={};w.tradeKeepers={};w.traders={};w.healers={};w.sheep={};w.guards={};w.campfires={};w.villages={};w.authoredObjects={};w.authoredSelected={}
 for i=#w.enemies,1,-1 do if w.enemies[i].townAnimal then table.remove(w.enemies,i)end end
 for _,k in ipairs(keys)do w[k]=marker()end
 local valid={};for _,k in ipairs(keys)do valid[k]=true end
 for _,o in ipairs(a.objects or {})do
  local p=marker(o.x,o.y);p.id=o.id
  if valid[o.id] then
   local v={cx=o.x,cy=o.y,name='Authored',_authoredProxy=true}
   for _,k in ipairs(keys)do v[k]=marker()end;v[o.id]=p;w.villages[#w.villages+1]=v;w.authoredObjects[#w.authoredObjects+1]=p
  end
  if o.id=='skillVendor' then
   local profile=require('game.vendor_profiles');local trade=o.trade or 'anvil';local tier=tonumber(o.vendorTier)or 0
   w.tradeKeepers[#w.tradeKeepers+1]={x=o.x,y=o.y,race='Human',trade=trade,vendorTier=tier,shop=profile.makeShop(w.sprites,trade,tier)}
  elseif o.id=='shopkeeper' then
   local stock,accepted=require('game.vendor_catalog').misc(w.sprites,{})
   w.tradeKeepers[#w.tradeKeepers+1]={x=o.x,y=o.y,race='Human',trade='misc',shop=Shop.trade(nil,'Town Supplies',stock,accepted)}
  elseif o.id=='bagKeeper' then w.bagKeepers[#w.bagKeepers+1]={x=o.x,y=o.y,race='Human',name='Bag Keeper',authored=true}
  elseif o.id=='trader' then w.traders[#w.traders+1]={x=o.x,y=o.y,race='Human',trade='buyer',shop=Shop.trader(nil,'Buyer Vendor')}
  elseif o.id=='healer' then w.healers[#w.healers+1]={x=o.x,y=o.y,race='Human'}
  elseif o.id=='guard' then w.guards[#w.guards+1]={x=o.x,y=o.y,spawnX=o.x,spawnY=o.y,name='Town Guard',role='Tank',guard=true,race='Human',hp=80,maxHp=80,equipment={weapon='Copper Longsword',head='Copper Helm',body='Copper Armor',offhand='Copper Shield'}};local guard=w.guards[#w.guards];guard.role=o.role=='Ranged' and 'Ranged' or 'Tank';require('game.party').configureGuard(guard,tonumber(o.level) or 16)
  elseif o.id=='sheep' then w.sheep[#w.sheep+1]={x=o.x,y=o.y,homeX=o.x,homeY=o.y,wool=true,woolTimer=0,moveTimer=1,vx=0,vy=0,townAnimal=true}
  elseif o.id=='chicken' or o.id=='cow' then local e=makeEnemy(o.id,o.x,o.y,1);e.townAnimal=true;e.variant=o.id=='chicken' and 'hen' or 1;w.enemies[#w.enemies+1]=e
  elseif o.id=='campfire' then w.campfires[#w.campfires+1]=require('game.fire_fuel').stamp({x=o.x,y=o.y,timer=1e9,permanent=true,authored=true})
  end
 end
 -- Authored spawn-zone population is intentionally silent during normal gameplay.
 -- Placement shortfalls remain internal; only world bosses announce their spawns.
 A.nearest(w,0,0);require('game.navigation').refresh(w)
end
function A.nearest(w,x,y)
 for _,k in ipairs(keys)do
  local best=w.authoredSelected[k];local dist=best and (best.x-x)^2+(best.y-y)^2 or math.huge
  if dist>75^2 then best=nil;dist=math.huge;for _,o in ipairs(w.authoredObjects)do if o.id==k then local d=(o.x-x)^2+(o.y-y)^2;if d<dist then best,dist=o,d end end end end
  w[k]=best or marker()
 end
end
function A.at(w,x,y,id)
 for _,o in ipairs(w.authoredObjects or {})do if o.id==id and (x-o.x)^2+(y-o.y)^2<18^2 then w[id]=o;w.authoredSelected[id]=o;return o end end
end
return A
