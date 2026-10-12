-- Shared, authoritative placed-pot and shellfish processing rules.
local P={levels={['Shrimp Pot']=6,['Crab Pot']=12,['Lobster Pot']=30},species={['Shrimp Pot']='Shrimp',['Crab Pot']='Crab',['Lobster Pot']='Lobster'},duration=2,capacity=10}
local R=require('game.rune_inventory')
P.inspectLevel=50
function P.limit(name,level)return name=='Shrimp Pot'and math.max(1,math.min(15,(level or 6)-5))or 10 end
function P.interval(name)return(name=='Shrimp Pot'or name=='Crab Pot')and 60 or 30 end
function P.cleanup(w,owner)for i=#(w.shellfishPots or{}),1,-1 do if w.shellfishPots[i].owner==owner then table.remove(w.shellfishPots,i)end end end
function P.valid(w,a,name,x,y)
 if not P.levels[name]or a.skills:get('Fishing').level<P.levels[name]then return false,'Fishing '..tostring(P.levels[name]or 12)..' required'end
 if type(x)~='number'or type(y)~='number'or x~=x or y~=y then return false,'Invalid position'end
 if (x-a.player.x)^2+(y-a.player.y)^2>80^2 then return false,'Move nearer to the shore'end
 local tx,ty=math.floor(x/16)+1,math.floor(y/16)+1
 if w.isCave or not(w.map:isBeachCell(tx,ty)or w.map:isBeachWaterCell(tx,ty))then return false,'Place at shoreline water'end
 for _,v in ipairs(w.shellfishPots or{})do if(v.x-x)^2+(v.y-y)^2<24^2 then return false,'Another pot is too close'end end
 return true
end
function P.update(w,dt)
 if w.onlineShared then return end
 for _,v in ipairs(w.shellfishPots or{})do
  for _,a in ipairs(w.onlineActors or{})do if v.owner==tostring(a.id)..':'..a.slot then v.level=a.skills:get('Fishing').level end end
  v.elapsed=(v.elapsed or 0)+math.max(0,dt);v.rollTimer=(v.rollTimer or 0)+math.max(0,dt)
  local interval=P.interval(v.name);local capacity=P.limit(v.name,v.level);while v.rollTimer>=interval and(v.catchCount or 0)<capacity do v.rollTimer=v.rollTimer-interval
   local chance=math.min(.95,.15+.006*math.max(0,(v.level or 12)-P.levels[v.name])+.002*math.min(180,v.elapsed))
   if math.random()<chance then v.catchCount=(v.catchCount or 0)+1 end
  end
  if(v.catchCount or 0)>=capacity then v.rollTimer=0 end
 end
end
function P.at(w,x,y,collection)
 for i,v in ipairs(w[collection]or{})do if(v.x-x)^2+(v.y-y)^2<=16^2 then return v,i end end
end
function P.command(w,a,c)
 w.shellfishPots=w.shellfishPots or{};w.shellfishParts=w.shellfishParts or{};a.fieldcraft=a.fieldcraft or{};local owner=a.campOwner or'offline';local config=a.fieldcraft;local region=w.regionId or require('game.regions').active
 local function sync()local keep={};for _,v in pairs(config.pots or{})do if v.region~=region then keep[#keep+1]=v end end;config.pots=keep;for _,v in ipairs(w.shellfishPots)do if v.owner==owner then config.pots[#config.pots+1]=R.copy(v)end end;local parts={};for _,v in pairs(config.shellParts or{})do if v.region~=region then parts[#parts+1]=v end end;config.shellParts=parts;for _,v in ipairs(w.shellfishParts)do if v.owner==owner then config.shellParts[#config.shellParts+1]=R.copy(v)end end end
 local function near(v)return v and(v.x-a.player.x)^2+(v.y-a.player.y)^2<=80^2 end
 local bag=a.inv:getBag(c.bag);local obj=bag and bag.slots[c.slot]
 if c.op=='potSync'then sync();return true,'Pots restored'
 elseif c.op=='potPlace'then
  if not obj or obj.name~=c.name or not P.levels[obj.name]or(obj.catchCount or 0)>0 then return false,'Select an empty pot'end
  local ok,why=P.valid(w,a,obj.name,c.x,c.y);if not ok then return false,why end
  w.shellfishSerial=(w.shellfishSerial or 0)+1;w.shellfishPots[#w.shellfishPots+1]={id=owner..':'..w.shellfishSerial..':'..tostring(os.time()),name=obj.name,qualityGrade=obj.qualityGrade,owner=owner,x=c.x,y=c.y,level=a.skills:get('Fishing').level,region=region,elapsed=0,rollTimer=0,catchCount=0};bag.slots[c.slot]=nil;sync();return true,'Pot placed'
 elseif c.op=='potRecover'then
  local v,index;for i,pot in ipairs(w.shellfishPots)do if pot.id==c.id then v,index=pot,i end end
  if not near(v)or v.owner~=owner then return false,'Move near your pot'end
  local trial=R.clone(a.inv);if not trial:addItemObject({name=v.name,qty=1,qualityGrade=v.qualityGrade,catchCount=v.catchCount or 0})then return false,'Bags full'end
  a.inv.bagSlots=trial.bagSlots;table.remove(w.shellfishPots,index);if(v.catchCount or 0)>0 then a.skills:addXP('Fishing',v.catchCount*({['Shrimp Pot']=10,['Crab Pot']=20,['Lobster Pot']=45})[v.name])end;sync();return true,a.skills:get('Fishing').level>=P.inspectLevel and('Pot recovered: '..(v.catchCount or 0)..' catches')or'Pot recovered'
 elseif c.op=='potEmpty'then
  if not obj or not P.levels[obj.name]or(obj.catchCount or 0)<1 then return false,'Pot is empty'end
  for i=1,obj.catchCount do w:dropScattered(P.species[obj.name],a.player.x,a.player.y,i,obj.catchCount)end;obj.catchCount=0;return true,'Catches dropped on the ground'
 elseif c.op=='shellFillet'then
  if not obj or(obj.name~='Crab'and obj.name~='Lobster')then return false,'Select a crab or lobster'end
  local lv=obj.name=='Crab'and 12 or 30;if a.skills:get('Cooking').level<lv then return false,'Cooking '..lv..' required'end
  if not require('game.tool_slot').has(a.inv,a.equipment or a.player.equipped,'Copper Knife',a.player)then return false,'Need a knife'end
  local species=obj.name;local trial=R.clone(a.inv);local count,tails=0,0;local pending={}
  for _,b in pairs(trial.bagSlots)do for _,it in pairs(b.slots)do if it.name==species then it.name=species..' Parts';count=count+1;if species=='Lobster'and math.random()<require('game.seafood_content').tailChance(a.skills:get('Cooking').level)then pending[#pending+1]=it end end end end
  for _,part in ipairs(pending)do if trial:add('Raw Lobster Tail',1)then tails=tails+1 else part.tailPending=true end end
  a.inv.bagSlots=trial.bagSlots;a.skills:addXP('Cooking',2*count);return true,'Broke all '..species..(tails>0 and(' + '..tails..' Raw Lobster Tail')or'')..(#pending>tails and'; bonus tail held in parts until space is available'or'')
 elseif c.op=='shellHarvest'then
  if obj and(obj.name=='Crab Parts'or obj.name=='Lobster Parts')then
   local species=obj.name:gsub(' Parts$','');local trial=R.clone(a.inv);trial:getBag(c.bag).slots[c.slot]=nil;local meat=math.random(1,5);if not trial:add(species..' Meat',meat)then return false,'Bags full'end;if obj.tailPending and not trial:add('Raw Lobster Tail',1)then return false,'Bags full; make space for the bonus tail'end;a.inv.bagSlots=trial.bagSlots;return true,'Harvested '..meat..' raw meat'
  end
  local v,index;for i,part in ipairs(w.shellfishParts)do if part.id==c.id then v,index=part,i end end
  if not near(v)or v.owner~=owner then return false,'Move near your parts'end
  local trial=R.clone(a.inv);if not trial:add(v.species..' Meat',v.meat)then return false,'Bags full'end
  a.inv.bagSlots=trial.bagSlots;table.remove(w.shellfishParts,index);sync();return true,'Harvested '..v.meat..' raw meat'
 end
 return false,'Unknown shellfish action'
end
function P.restore(w,a)
 w.shellfishPots=w.shellfishPots or{};w.shellfishParts=w.shellfishParts or{}
 for _,pair in ipairs({{'pots','shellfishPots'},{'shellParts','shellfishParts'}})do
  for _,v in pairs((a.fieldcraft or{})[pair[1]]or{})do local found=false;for _,old in ipairs(w[pair[2]])do if old.id==v.id then found=true end end
   if not found and(pair[1]~='pots'or not SG_SERVER)and v.region==(w.regionId or require('game.regions').active) then w[pair[2]][#w[pair[2]]+1]=R.copy(v)end
  end
 end
end
return P
