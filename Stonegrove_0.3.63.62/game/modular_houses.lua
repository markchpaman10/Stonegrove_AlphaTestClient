-- Same-world interiors: no teleport, per-frame randomization, or saved preview state.
local H={}
function H.is(h) return h and (h.id=='modularHouse' or h.id=='modularHouse1' or h.id=='modularHouse2' or h.modular==true) end
local function choice(v,n,fallback)
 v=tonumber(v);if not v or v~=v then return fallback end
 return math.max(1,math.min(n,math.floor(v)))
end
function H.configure(h)
 -- Coordinate hash also gives old/imported authored objects stable defaults.
 local seed=math.abs(math.floor((h.x or 0)*7387+(h.y or 0)*1931+(h.variant or 1)*8191))
 h.modular=true
 h.houseRoof=choice(h.houseRoof,4,seed%4+1)
 h.houseWall=choice(h.houseWall,2,math.floor(seed/7)%2+1)
 h.houseInterior=choice(h.houseInterior,2,math.floor(seed/11)%2+1)
 h.houseDoor=choice(h.houseDoor,2,math.floor(seed/17)%2+1)
 h.houseDoorPosition=choice(h.houseDoorPosition,3,math.floor(seed/29)%3+1)
 h.houseWindow=choice(h.houseWindow,2,math.floor(seed/23)%2+1)
 h.houseFloors=h.id=='modularHouse1' and 1 or h.id=='modularHouse2' and 2 or choice(h.houseFloors,2,math.floor(seed/31)%2+1)
 h.story=h.houseFloors==2
 return h
end
function H.place(h,rng)
 for k,n in pairs({houseRoof=2,houseWall=2,houseInterior=2,houseDoor=2,houseDoorPosition=3,houseWindow=2,houseFloors=2}) do h[k]=rng:random(1,n) end
 return H.configure(h)
end
function H.bounds(h) return math.floor(h.x)-31,math.floor(h.y)-35,62,53 end
function H.door(h)
 H.configure(h);local l=math.floor(h.x)-31;return l+({17,31,45})[h.houseDoorPosition],math.floor(h.y)+8
end
function H.doorAt(h,x,y)
 local dx,dy=H.door(h);return math.abs(x-dx)<=13 and y>=dy-12 and y<=dy+10
end
function H.lightBounds(w,p)
 for _,h in ipairs(w.houses or{})do if H.is(h)and H.inside(h,p.x,p.y+4)then return h.x-34,h.y-35,69,53,h end end
end
function H.inside(h,x,y)
 local l,t,w,d=H.bounds(h)
 return x>l+3 and x<l+w-3 and y>t+4 and y<t+d-2
end
function H.blocked(h,x,y,r)
 local l,t,w,d=H.bounds(h);r=r or 0
 local function hit(a,b,c,e) return x+r>a and x-r<a+c and y+r>b and y-r<b+e end
 local door=H.door(h)-l;local left,right=door-13,door+13
 return hit(l,t,3,d) or hit(l+w-3,t,3,d) or hit(l,t,w,4)
     or hit(l,t+d-3,left,3) or hit(l+right,t+d-3,w-right,3)
end
function H.hit(h,x,y)
 H.configure(h)
 return math.abs(x-h.x)<=35 and y>=h.y-(h.houseFloors==2 and 85 or 61) and y<=h.y+18
end
function H.load(image)
 local im=image or love.graphics.newImage('assets/modular_houses.png');im:setFilter('nearest','nearest')
 local function p(x,y,w,h) return {q=love.graphics.newQuad(x,y,w,h,im:getDimensions()),w=w,h=h} end
 return {image=im,walls={p(19,120,62,24),p(92,120,62,24)},
  roofs={p(172,7,69,55),p(254,9,69,55),p(175,74,65,24),p(260,75,65,24)},
  gables={p(175,74,65,24),p(260,75,65,24)},
  rooms={p(172,155,69,53),p(269,155,69,53)},
  doors={p(110,33,22,20),p(112,60,22,20)},windows={p(98,39,9,11),p(99,67,9,11)}}
end
function H.draw(parts,h,interior)
 H.configure(h);love.graphics.setColor(1,1,1)
 local function draw(p,x,y) love.graphics.draw(parts.image,p.q,x,y) end
 if interior then draw(parts.rooms[h.houseInterior],h.x-34,h.y-35);return end
 local l=h.x-31;local top=h.y-6
 local wall=parts.walls[h.houseWall]
 local door=H.door(h);draw(wall,l,top);draw(parts.doors[h.houseDoor],door-11,top+4)
 for _,x in ipairs({3,26,47})do if l+x+9<=door-12 or l+x>=door+12 then draw(parts.windows[h.houseWindow],l+x,top+10)end end
 if h.houseFloors==2 then
  top=top-24;draw(wall,l,top)
  for _,x in ipairs({5,26,47}) do draw(parts.windows[h.houseWindow],l+x,top+6) end
 end
 -- Entries 3/4 in old maps selected a gable alone. They now retain their
 -- saved value while rendering the matching complete blue/red roof assembly.
 local roof=parts.roofs[(h.houseRoof-1)%2+1]
 draw(parts.gables[h.houseWall],h.x-32,top-23)
 draw(roof,h.x-math.floor(roof.w/2),top-roof.h+2)
end
return H
