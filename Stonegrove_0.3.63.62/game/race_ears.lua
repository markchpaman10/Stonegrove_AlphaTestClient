-- Shared race overlay: full 16x16 frames align exactly with the head sheet.
local E={}
function E.draw(s,race,x,y,dir,frame,helmet)
 if helmet then return false end
 local ears=s.raceEars and (s.raceEars[race] or s.raceEars.Human)
 if not ears then return false end
 dir=dir or 'down';local key=dir=='left' and 'right' or dir
 local quad=ears.frames[key][frame or 1]
 love.graphics.setColor(1,1,1)
 require('game.humanoid').draw(ears.image,quad,x,y,dir=='left' and -1 or 1,race,'head')
 return true
end
return E
