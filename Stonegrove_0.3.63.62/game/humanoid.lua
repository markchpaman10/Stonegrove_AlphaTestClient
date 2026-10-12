-- Shorten the dwarf torso while retaining head size and the same foot anchor.
local H={}
function H.metrics(race,part)
 if race~='Dwarf' then return 0,1 end
 if part=='head' then return 2,1 end
 return 1.6,.8
end
function H.draw(image,quad,x,y,flip,race,part)
 local offset,sy=H.metrics(race,part);love.graphics.draw(image,quad,x,y+offset,0,flip or 1,sy,8,8)
end
function H.shadow(image,quad,x,y,flip,race,part)
 local offset,sy=H.metrics(race,part);love.graphics.draw(image,quad,x,y+8-offset*.32,0,flip or 1,-.32*sy,8,8)
end
function H.beard(s,race,x,y,dir,frame)
 if race~='Dwarf' then return false end
 local style=s.npcCosmetics.beardStyles[3];local key=dir=='left' and 'right' or dir or 'down'
 love.graphics.setColor(1,1,1);H.draw(s.npcCosmetics.hair,style.frames[key][frame or 1],x,y,dir=='left' and -1 or 1,race,'head');return true
end
return H
