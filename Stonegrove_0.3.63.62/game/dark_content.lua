-- Supplied artwork is used without resampling. Undead are NPC/enemy appearances.
local D={defs={}}
D.defs.skeleton={baseLevel=10,tierMin=1,tierMax=1,melee=10,ranged=0,strength=10,agility=8,health=10,mainSkill='Melee Combat',aggro=85,leash=180,roam=35,speed=25,attackRange=25,rangedRange=0,attackSpeed=1.5}
D.defs.ghost={baseLevel=10,tierMin=1,tierMax=1,melee=10,ranged=0,strength=8,agility=10,health=10,mainSkill='Melee Combat',aggro=85,leash=180,roam=40,speed=28,attackRange=25,rangedRange=0,attackSpeed=1.5}
function D.isUndead(kind)return kind=='skeleton'or kind=='ghost'end
function D.load(s)
 local function image(i)local im=love.graphics.newImage('assets/dark_content_'..i..'.png');im:setFilter('nearest','nearest');return im end
 for name,i in pairs({['Black Dye']=1,['Black Cape']=2,['Black Hood']=3,['Black Linen Cloth']=4,["Death's Robes"]=8})do s.itemImages[name]=image(i);s.itemQuads[name]=nil end
 s.paperDolls=s.paperDolls or{}
 for _,d in ipairs({{'Black Cape',5,'cape'},{'Black Hood',6,'head'},{"Death's Robes",7,'body'}})do
  local im=image(d[2]);local doll={image=im,frames={},w=16,h=16}
  for row,dir in ipairs({'up','right','down'})do doll.frames[dir]={};for frame=1,4 do doll.frames[dir][frame]=love.graphics.newQuad((frame-1)*16,(row-1)*16,16,16,im:getDimensions())end end
  s.paperDolls[d[1]]={doll=doll,slot=d[3],ax=8,ay=8}
 end
 -- Black berries share the established berry silhouette and use a dark palette.
 local data=love.image.newImageData('assets/itemBerry_purple.png')
 data:mapPixel(function(x,y,r,g,b,a)return r*.3,g*.3,b*.3,a end)
 s.itemImages['Black Berries']=love.graphics.newImage(data);s.itemImages['Black Berries']:setFilter('nearest','nearest')
 s.undead={}
 for kind,i in pairs({skeleton=9,ghost=10})do
  local im=image(i);local parts={image=im,body={},head={}}
  for _,part in ipairs({'body','head'})do for row,dir in ipairs({'up','right','down'})do parts[part][dir]={};for frame=1,4 do parts[part][dir][frame]=love.graphics.newQuad((frame-1)*16,(row-1)*16+(part=='head'and 48 or 0),16,16,im:getDimensions())end end end
  s.undead[kind]=parts
 end
end
function D.draw(s,e,shadow)
 local kind=e.race=='Ghost'and'ghost'or e.kind;local parts=s.undead and s.undead[kind];if not parts then return false end
 local dx,dy=(e.x or 0)-(e._undeadX or e.x or 0),(e.y or 0)-(e._undeadY or e.y or 0)
 if not shadow then
  if math.abs(dx)+math.abs(dy)>.01 then e.direction=math.abs(dx)>math.abs(dy)and(dx<0 and'left'or'right')or(dy<0 and'up'or'down');e._undeadWalk=(e._undeadWalk or 0)+math.sqrt(dx*dx+dy*dy);e._undeadFrame=1+math.floor(e._undeadWalk/4)%4 else e._undeadFrame=e.frame or 1 end
  e._undeadX,e._undeadY=e.x,e.y
 end
 local dir=e.direction or'down';local key=dir=='left'and'right'or dir;local frame=math.max(1,math.min(4,e._undeadFrame or e.frame or 1));local flip=dir=='left'and-1 or 1
 love.graphics.push('all');love.graphics.setColor(shadow and .035 or 1,shadow and .045 or 1,shadow and .05 or 1,shadow and .25 or 1)
 local H=require('game.humanoid');local render=shadow and H.shadow or H.draw
 for _,part in ipairs({'body','head'})do render(parts.image,parts[part][key][frame],e.x,e.y,flip,'Human',part)end
 if not shadow then local P=require('game.paperdoll');for _,slot in ipairs({'body','legs','head','cape'})do P.gear(s,(e.equipment or{})[slot],e.x,e.y,dir,frame,'Human')end end
 love.graphics.pop();return true
end
return D
