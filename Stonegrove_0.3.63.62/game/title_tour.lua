local T={}
-- Tour the towns on the displayed map without moving the character.
function T.new(world)
 local points={};local a=world.map.authored or{}
 local function add(x,y)
  if type(x)~='number'or type(y)~='number'then return end
  for _,p in ipairs(points)do if (p.x-x)^2+(p.y-y)^2<1 then return end end
  points[#points+1]={x=x,y=y}
 end
 for _,z in ipairs(a.townZones or{})do add(z.x+z.w/2,z.y+z.h/2)end
 for _,o in ipairs(a.objects or{})do if o.id=='townCenter'then
  local inside=false;for _,z in ipairs(a.townZones or{})do if o.x>=z.x and o.x<=z.x+z.w and o.y>=z.y and o.y<=z.y+z.h then inside=true;break end end
  if not inside then add(o.x,o.y)end
 end end
 if #points==0 then for _,v in ipairs(world.villages or{})do add(v.cx,v.cy)end end
 if #points<=1 then
  local cx=points[1]and points[1].x or world.map.width/2;local cy=points[1]and points[1].y or world.map.height/2
  local rx=math.min(600,world.map.width*.3);local ry=math.min(400,world.map.height*.3)
  add(math.max(0,cx-rx),math.max(0,cy-ry));add(math.min(world.map.width,cx+rx),math.max(0,cy-ry))
  add(math.min(world.map.width,cx+rx),math.min(world.map.height,cy+ry));add(math.max(0,cx-rx),math.min(world.map.height,cy+ry))
 end
 return {world=world,points=points,index=#points>1 and 2 or 1,direction=1,x=points[1].x,y=points[1].y,wait=.75}
end
function T.update(t,dt,w,h,zoom)
 dt=math.max(0,math.min(dt,.05))
 if t.wait>0 then t.wait=math.max(0,t.wait-dt)else
  local p=t.points[t.index];local dx,dy=p.x-t.x,p.y-t.y;local distance=math.sqrt(dx*dx+dy*dy);local step=90*dt
  if distance<=step then
   t.x,t.y=p.x,p.y;t.wait=2
   if #t.points>1 then
    if t.index==#t.points then t.direction=-1 elseif t.index==1 then t.direction=1 end
    t.index=t.index+t.direction
   end
  else t.x=t.x+dx/distance*step;t.y=t.y+dy/distance*step end
 end
 local function clamp(v,size,margin)if size<=margin*2 then return size/2 end;return math.max(margin,math.min(size-margin,v))end
 return clamp(t.x,t.world.map.width,w/(2*zoom)),clamp(t.y,t.world.map.height,h/(2*zoom))
end
return T
