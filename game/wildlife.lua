-- Eggs come from living chickens and remain reachable; bound local ground loot.
local W={}
function W.update(w,dt)
 if w.isCave then return end
 w.eggClock=(w.eggClock or 0)+dt
 if w.eggClock<10 then return end;w.eggClock=w.eggClock%10
 for _,e in ipairs(w.enemies or {}) do if e.kind=='chicken' and not e.dead and not e.inactive then
  e.eggTimer=(e.eggTimer or 0)-10
  if e.eggTimer<=0 then
   local nearby=0;for _,g in ipairs(w.groundItems or {}) do if g.name=='Egg' and (g.x-e.x)^2+(g.y-e.y)^2<64^2 then nearby=nearby+1 end end
   if nearby<2 then
    for i=0,15 do local angle=i*math.pi/8;local x,y=e.x+math.cos(angle)*28,e.y+math.sin(angle)*28
     local clear=not w:playerBlocked(x,y);for j=1,7 do if w:playerBlocked(e.x+(x-e.x)*j/7,e.y+(y-e.y)*j/7) then clear=false;break end end
     if clear then w:addGroundItem('Egg',x,y);break end
    end
   end
   e.eggTimer=180
  end
 end end
end
return W
