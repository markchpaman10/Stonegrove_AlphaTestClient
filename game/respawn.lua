-- Choose real town centers before service proxies, and validate every spawn.
local R={}
function R.safe(w,x,y,actor)
 local function valid(px,py)
  if px<12 or py<12 or px>w.map.width-12 or py>w.map.height-12 or w:playerBlocked(px,py) then return false end
  for _,list in ipairs({w.mercs or {},w.guards or {},w.questNPCs or {},w.sheep or {}}) do
   for _,a in ipairs(list) do if a~=actor and not a.inactive and (a.hp or 1)>0 and (a.x-px)^2+(a.y-py)^2<20^2 then return false end end
  end
  for _,e in ipairs(w.enemies or {}) do if not e.dead and not e.inactive and (e.x-px)^2+(e.y-py)^2<32^2 then return false end end
  return true
 end
 if valid(x,y) then return x,y end
 for radius=16,320,16 do for i=0,31 do local angle=i*math.pi/16;local px,py=x+math.cos(angle)*radius,y+math.sin(angle)*radius;if valid(px,py) then return px,py end end end
end
function R.town(w,x,y,actor)
 local towns={}
 for _,o in ipairs((w.map.authored or {}).objects or {}) do if o.id=='townCenter' then towns[#towns+1]={x=o.x,y=o.y} end end
 if #towns==0 then for _,v in ipairs(w.villages or {}) do towns[#towns+1]={x=v.cx,y=v.cy} end end
 table.sort(towns,function(a,b)return (a.x-x)^2+(a.y-y)^2<(b.x-x)^2+(b.y-y)^2 end)
 for _,t in ipairs(towns) do local px,py=R.safe(w,t.x,t.y+35,actor);if px then return px,py,(t.x-x)^2+(t.y-y)^2 end end
 local start=(w.map.authored or {}).playerStart or {x=w.map.width/2,y=w.map.height/2}
 local px,py=R.safe(w,start.x,start.y,actor);return px,py,math.huge
end
-- Player camps are compared with the town center, not its safety-adjusted spawn.
function R.player(w,x,y,actor,owner)
 local tx,ty,townDistance=R.town(w,x,y,actor)
 if owner then
  local closest,dist
  for _,camp in ipairs(w.playerCamps or{})do
   local d=(camp.x-x)^2+(camp.y-y)^2
   if camp.owner==owner and camp.tent and d<(townDistance or math.huge)and(not dist or d<dist)then closest,dist=camp,d end
  end
  if closest then local px,py=R.safe(w,closest.x,closest.y+24,actor);if px then return px,py,'camp' end end
 end
 return tx,ty,'town'
end
return R
