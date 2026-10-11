-- Item metadata travels with the physical item; equipment names remain compatible
-- with the combat/animation systems. equipmentSockets is only a live projection.
local I={}
function I.copy(v,seen)
 if type(v)~='table' then return v end
 seen=seen or {};if seen[v] then return seen[v] end
 local out={};seen[v]=out;for k,x in pairs(v) do out[k]=I.copy(x,seen) end;return out
end
function I.stateful(obj)
 if not obj then return false end
 if obj.name=='Rune Bag' or require('game.advanced_gear').isQuiver(obj.name) then return true end
 for k in pairs(obj) do if k~='name' and k~='qty' then return true end end
 return false
end
-- A stacked bone item retains a count for every credited kill token.
function I.boneTokens(obj)
 local out={};if obj.boneTokens then for token,n in pairs(obj.boneTokens)do out[tostring(token)]=n end
 elseif obj.boneToken then out[tostring(obj.boneToken)]=obj.qty or 1 end;return out
end
function I.stackPart(obj,qty,offset)
 local out=I.copy(obj);out.qty=qty;offset=offset or 0
 if obj.boneRolls then out.boneRolls={};for i=1,qty do out.boneRolls[i]=I.copy(obj.boneRolls[offset+i])end end
 if require('game.bone_religion').is(obj.name)and(obj.boneToken or obj.boneTokens)then
  out.boneToken=nil;out.boneTokens={};local keys={};local tokens=I.boneTokens(obj);for token in pairs(tokens)do keys[#keys+1]=token end;table.sort(keys)
  local left=qty;for _,token in ipairs(keys)do local n=tokens[token];local skip=math.min(offset,n);offset=offset-skip;n=n-skip;local take=math.min(left,n);if take>0 then out.boneTokens[token]=take;left=left-take end end
 end;return out
end
function I.mergeProvenance(target,source,qty,offset)
 if not require('game.bone_religion').is(source.name)then return end
 local tokens=I.boneTokens(target);for token,n in pairs(I.boneTokens(I.stackPart(source,qty,offset)))do tokens[token]=(tokens[token]or 0)+n end
 target.boneToken=nil;target.boneTokens=next(tokens)and tokens or nil
 if source.boneRolls then target.boneRolls=target.boneRolls or{};for _,roll in ipairs(I.stackPart(source,qty,offset).boneRolls)do target.boneRolls[#target.boneRolls+1]=I.copy(roll)end end
end
function I.consumeProvenance(obj,qty)
 if not require('game.bone_religion').is(obj.name)or not(obj.boneToken or obj.boneTokens or obj.boneRolls)then return end
 local remain=I.stackPart(obj,math.max(0,(obj.qty or 1)-qty),qty);obj.boneToken=nil;obj.boneTokens=remain.boneTokens;obj.boneRolls=remain.boneRolls
end
function I.sameMetadata(a,b)
 -- Legacy rune stacks sometimes carry explicit false/empty fields. Normalize only
 -- these equivalent states; preserve all ownership, enchantment and custom data.
 if require('game.religion').blessXP[a.name]and a.name==b.name then
  a=I.copy(a);b=I.copy(b)
  for _,v in ipairs({a,b})do v.blessed=v.blessed==true;v.qualityGrade=require('game.quality').grade(v)or'C';if type(v.sockets)=='table'and not next(v.sockets)then v.sockets=nil end end
 end
 if a.name==b.name and require("game.bone_religion").is(a.name)then
  a=I.copy(a);b=I.copy(b);for _,v in ipairs({a,b})do v.boneToken=nil;v.boneTokens=nil;if not v.boneOwner then v.bonePurchased=nil end;v.hasBoneRolls=v.boneRolls~=nil;v.boneRolls=nil;v.blessed=v.blessed==true;if type(v.sockets)=="table"and not next(v.sockets)then v.sockets=nil end end
 end
 local function equal(x,y)
  if type(x)~=type(y) then return false end;if type(x)~='table' then return x==y end
  for k,v in pairs(x) do if not equal(v,y[k]) then return false end end
  for k in pairs(y) do if x[k]==nil then return false end end;return true
 end
 for k,v in pairs(a) do if k~='qty' and not equal(v,b[k]) then return false end end
 for k in pairs(b) do if k~='qty' and a[k]==nil then return false end end;return true
end
function I.equipped(actor,slot)
 require('game.quality').bind(actor.equipment,actor.equipmentItems);local value=(actor.equipment or {})[slot];if not value then return nil end
 if type(value)=='table' then return value end
 actor.equipmentItems=actor.equipmentItems or {};actor.equipmentSockets=actor.equipmentSockets or {}
 local obj=actor.equipmentItems[slot]
 if not obj or obj.name~=value then obj={name=value,qty=1,sockets=actor.equipmentSockets[slot] or {}};actor.equipmentItems[slot]=obj end
 obj.sockets=obj.sockets or {};actor.equipmentSockets[slot]=obj.sockets;return obj
end
function I.setEquipped(actor,slot,obj)
 actor.equipment=actor.equipment or {};actor.equipmentItems=actor.equipmentItems or {};actor.equipmentSockets=actor.equipmentSockets or {}
 require('game.quality').bind(actor.equipment,actor.equipmentItems);actor.equipment[slot]=obj and (slot=='ammo' and obj or obj.name) or nil
 actor.equipmentItems[slot]=slot~='ammo' and obj or nil
 actor.equipmentSockets[slot]=obj and (obj.sockets or {}) or {}
 require('game.tool_slot').bind(actor)
end
function I.sync(actor)
 for _,slot in ipairs({'head','body','legs','cape','weapon','offhand','ammo','tool'}) do local obj=I.equipped(actor,slot);if obj and obj.sockets then require('game.sockets').normalize(obj) end end
end
function I.equipFromBag(ui,bi,index,slot,actor)
 actor=actor or ui;local bag=ui.inv:getBag(bi);local incoming=bag and bag.slots[index];if not incoming then return false,'empty' end
 local old=I.equipped(actor,slot);local off
 if slot=='weapon' and incoming.name:match('Bow$') then off=I.equipped(actor,'offhand') end
 if off and old and not ui.inv:canAddObject(off) then return false,'no_room_for_offhand' end
 I.setEquipped(actor,slot,incoming);bag.slots[index]=old
 if off then I.setEquipped(actor,'offhand',nil);if old then assert(ui.inv:addItemObject(off)) else bag.slots[index]=off end end
 if actor==ui and slot=='weapon' then ui.player.equipped=incoming.name end
 return true,incoming,old,off
end
function I.shopSnapshot(w)
 w=w.overworld or w;local out={}
 for _,group in ipairs({'tradeKeepers','traders'}) do for i,npc in ipairs(w[group] or {}) do
  if npc.shop then local rows={};for _,row in ipairs(npc.shop.slots) do if row.object then rows[#rows+1]=I.copy(row) end end
   if #rows>0 then out[group..':'..i]=rows end
  end
 end end;return out
end
function I.restoreShops(w,data)
 for _,group in ipairs({'tradeKeepers','traders'}) do for i,npc in ipairs(w[group] or {}) do
  local shop=npc.shop;if shop then
   for j=#shop.slots,1,-1 do if shop.slots[j].object then table.remove(shop.slots,j) end end
   for _,row in ipairs((data or {})[group..':'..i] or {}) do shop.slots[#shop.slots+1]=I.copy(row) end
  end
 end end
end
return I
