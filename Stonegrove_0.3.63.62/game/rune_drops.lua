-- Use existing ground items, finding reachable space with the world collision query.
local D={}
function D.position(w,source,player)
 local old=w.playerRef;w.playerRef=nil
 local function clear(x,y) return w.map:isLand(x,y) and not w:playerBlocked(x,y) and not w:enemyBlocked(x,y) end
 local queue={{x=player.x,y=player.y}};local seen={['0:0']=true};local head=1
 while head<=#queue and head<=1600 do
  local p=queue[head];head=head+1
  local distance=(p.x-source.x)^2+(p.y-source.y)^2
  if distance>=32^2 and distance<=90^2 and clear(p.x,p.y) then w.playerRef=old;return p.x,p.y end
  for _,v in ipairs({{8,0},{-8,0},{0,8},{0,-8}}) do local x,y=p.x+v[1],p.y+v[2];local k=math.floor(x-player.x)..':'..math.floor(y-player.y)
   if not seen[k] and (x-player.x)^2+(y-player.y)^2<=144^2 then seen[k]=true
    if clear(x,y) and clear((x+p.x)/2,(y+p.y)/2) then queue[#queue+1]={x=x,y=y} end
   end
  end
 end
 w.playerRef=old;return nil
end
function D.drop(w,name,qty,source,player)
 -- Expired remote fires use their own origin; mining and filleting use the player.
 local origin=player
 if not origin or (origin.x-source.x)^2+(origin.y-source.y)^2>120^2 then origin=source end
 local x,y=D.position(w,source,origin)
 if not x then w.pendingRuneDrops=w.pendingRuneDrops or {};w.pendingRuneDrops[#w.pendingRuneDrops+1]={name=name,qty=qty,source={x=source.x,y=source.y}};return false end
 for i=1,qty do w:addGroundItem(name,x,y) end;return true
end
function D.retry(w,player,dt)
 w.runeDropTimer=(w.runeDropTimer or 0)-dt;if w.runeDropTimer>0 then return end;w.runeDropTimer=1
 local pending=w.pendingRuneDrops or {};w.pendingRuneDrops={}
 for _,d in ipairs(pending) do D.drop(w,d.name,d.qty,d.source,player) end
end
return D
