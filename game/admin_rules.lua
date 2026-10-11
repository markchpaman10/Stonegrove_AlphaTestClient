-- Invoked only by authenticated server authorization or explicit offline development.
local A={}
function A.towns(world)
 local regions=require('game.regions');local out={}
 for _,map in ipairs(regions.doc and regions.doc.maps or{})do
  for i,o in ipairs(map.data.objects or{})do if o.id=='townCenter'then out[#out+1]={region=map.id,index=i,name=(o.name or'Town')..' ('..map.id..')',x=o.x,y=o.y}end end
 end
 local fallback=world or(_G.ui and ui.world);fallback=fallback and(fallback.overworld or fallback)
 if #out==0 and fallback then for i,v in ipairs(fallback.villages or{})do if not v._authoredProxy then out[#out+1]={region=fallback.regionId or'offline',index=i,name=v.name or('Town '..i),x=v.cx,y=v.cy}end end end
 return out
end
function A.execute(w,a,cmd,sprites)
 if cmd.serverAdmin~=true then return false,'Administrator authorization required'end
 if cmd.action=='level'then
  local level=cmd.amount;if type(level)~='number'or level%1~=0 or level<1 or level>99 then return false,'Choose a level from 1 to 99'end
  if cmd.skill~='All Skills'and not a.skills.data[cmd.skill]then return false,'Unknown skill'end
  for name,s in pairs(a.skills.data)do if cmd.skill=='All Skills'or name==cmd.skill then s.xp=a.skills.xpTable[level];s.level=level end end
  a.player:syncVitals(a.skills);return true,'Skill level set'
 elseif cmd.action=='give'then
  if type(cmd.item)~='string'or not sprites.itemInfo[cmd.item]then return false,'Unknown item'end
  local q=cmd.amount;if type(q)~='number'or q%1~=0 or q<1 or q>1000000 then return false,'Quantity must be 1–1,000,000'end
  local trial=require('game.rune_inventory').clone(a.inv);if not trial:add(cmd.item,q)then return false,'Not enough bag space for that quantity'end
  a.inv.bagSlots=trial.bagSlots;return true,'Granted '..q..' '..cmd.item
 elseif cmd.action=='heal'then
  a.player:syncVitals(a.skills);a.player.hp=a.player.maxHp;a.player.stamina=a.player.maxStamina;a.player.poisonedTimer=0;a.player.slimeCoated=0;return true,'Health and stamina restored'
 elseif cmd.action=='teleport'then
  local chosen;for _,v in ipairs(A.towns(w))do if v.region==cmd.region and v.index==cmd.index then chosen=v;break end end
  if not chosen then return false,'Unknown town'end
  local regions=require('game.regions');local target=regions.doc and regions.get(chosen.region,sprites)or(w.overworld or w);local x,y
  for radius=32,224,16 do for i=0,15 do local angle=i*math.pi/8;local xx,yy=chosen.x+math.cos(angle)*radius,chosen.y+math.sin(angle)*radius;if not x and not target:playerBlocked(xx,yy)then x,y=xx,yy end end;if x then break end end
  if not x then return false,'No safe town arrival point'end
  a.player.x,a.player.y=x,y;a.gather=nil;a.fishing=nil;a.target=nil
  return true,'Teleported to '..chosen.name,{region=chosen.region,x=x,y=y}
 end
 return false,'Unknown admin action'
end
return A
