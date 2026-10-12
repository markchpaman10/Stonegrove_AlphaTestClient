-- Short, meandering deposits with occasional side branches and walkable gaps.
local M={}
function M.generate(w)
 require("game.node_index").invalidate(w)
 for i=#w.nodes,1,-1 do if w.nodes[i].kind=='copper' or w.nodes[i].kind=='iron' or w.nodes[i].kind=='coal' then table.remove(w.nodes,i) end end
 local function clear(x,y,placed)
  for _,d in ipairs({{0,0},{-18,0},{18,0},{0,-18},{0,18}}) do if not w.map:isLand(x+d[1],y+d[2]) then return false end end
  if not require('game.expansion').clearVillage(w,x,y,100) or w:enemyBlocked(x,y) then return false end
  for _,p in ipairs(w.paths) do if x>p.x-24 and x<p.x+p.w+24 and y>p.y-24 and y<p.y+p.h+24 then return false end end
  for _,n in ipairs(w.nodes) do if (x-n.x)^2+(y-n.y)^2<28^2 then return false end end
  for _,n in ipairs(placed) do if (x-n.x)^2+(y-n.y)^2<30^2 then return false end end
  return true
 end
 w.oreSeams={}
 for seam=1,360 do
  local kind='copper'
  for attempt=1,160 do
   local x,y=math.random(100,w.map.width-100),math.random(100,w.map.height-100)
   local angle=math.random()*math.pi*2;local points={};local wanted=math.random(7,14)
   for step=1,wanted do
    if not clear(x,y,points) then break end
    points[#points+1]={x=x,y=y}
    if step>1 and math.random()<.23 then
     local side=angle+math.pi/2;local bx,by=x+math.cos(side)*38,y+math.sin(side)*38
     if clear(bx,by,points) then points[#points+1]={x=bx,y=by} end
    end
    angle=angle+(math.random()-.5)*.85
    local distance=math.random(30,46);x=x+math.cos(angle)*distance;y=y+math.sin(angle)*distance
   end
   if #points>=4 then
    local d=w:resourceInfo(kind);w.oreSeams[#w.oreSeams+1]={kind=kind,points=points}
    for _,p in ipairs(points) do w.nodes[#w.nodes+1]={kind=kind,x=p.x,y=p.y,hp=d.hp,maxHp=d.hp,depleted=false,respawnTimer=0,shake=0,seam=seam} end
    break
   end
  end
 end
 require('game.navigation').refresh(w)
end
return M
