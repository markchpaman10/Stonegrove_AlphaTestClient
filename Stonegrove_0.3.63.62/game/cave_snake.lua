local S={}
S.def={baseLevel=30,tierMin=1,tierMax=1,melee=26,ranged=0,strength=15,agility=20,health=40,mainSkill='Melee Combat',aggro=125,leash=220,roam=32,speed=28,attackRange=30,rangedRange=0,attackSpeed=2}
function S.load(s)
 local function img(name)local im=love.graphics.newImage('assets/'..name..'.png');im:setFilter('nearest','nearest');return im end
 s.snake={move=img('snake_move'),dead=img('snake_dead'),frames={}}
 for i=1,3 do s.snake.frames[i]=love.graphics.newQuad(0,(i-1)*16,48,16,48,48)end
 local function item(name,image,typ,detail,x)
  s.itemImages[name]=image;s.itemQuads[name]=love.graphics.newQuad(x or 0,0,16,16,image:getDimensions());s.itemInfo[name]={title=name,type=typ,detail=detail}
 end
 item('Raw Cave Snake Hide',img('snake_hide_raw'),'Skinned Hide','Skin a cave snake boss with a Copper Knife or Dagger. Soak this hide in a tanning vat; it occupies the whole vat.')
 item('Soaked Cave Snake Hide',img('snake_hide_soaked'),'Material','Place on a hide stretcher to make Cave Snake Leather.')
 item('Cave Snake Leather',img('snake_leather'),'Material','Processed boss hide. Keep for future snake-leather equipment; no equipment recipe yet.')
 item('Cave Snake Fang',img('snake_fang'),'Alchemy Material','Dropped by a cave snake boss. Right-click > Bless to prepare for a future poison spell. No potion or spell recipe yet.')
 s.itemInfo['Cave Snake Fang'].blessable=true
 local meat=img('snake_meat')
 item('Cave Snake Meat',meat,'Raw Food','Skin a cave snake boss. Cook at a stove or campfire with Cooking 25. Grade D restores 65 HP; C/B/A restore 80/95/110 HP.')
 item('Burnt Cave Snake Meat',meat,'Burnt Food','Burnt cave snake meat. Restores 1 health.',32)
 for _,grade in ipairs({'D','C','B','A'})do item('Cooked Cave Snake Meat '..grade,meat,'Food','Cooked cave snake meat. Right-click > Eat.',16)end
end
function S.update(w,dt)
 for _,e in ipairs(w.enemies)do if e.kind=='caveSnake' then
  local dx,dy=e.x-(e.snakeX or e.x),e.y-(e.snakeY or e.y);e.snakeMoving=dx*dx+dy*dy>.0001
  if e.snakeMoving then e.snakeAngle=math.atan2(dy,dx)-math.pi;e.snakeTime=(e.snakeTime or 0)+dt end
  if e.aggro and not e.snakeMoving and w.playerRef then e.snakeAngle=math.atan2(w.playerRef.y-e.y,w.playerRef.x-e.x)-math.pi end
  e.snakeX,e.snakeY=e.x,e.y
  if e.dead and not e.snakeLoot then e.snakeLoot=true;require('game.cave_loot').drop(w,e)end
 end end
end
function S.frame(e)
 if not e.snakeMoving or e.state=='combat' then return 2 end
 return math.floor((e.snakeTime or 0)/.16)%3+1
end
function S.draw(s,e)
 if e.dead then love.graphics.setColor(1,1,1);love.graphics.draw(s.snake.dead,e.x,e.y,0,1,1,24,24);love.graphics.print('SKIN',e.x-12,e.y-30)
 else love.graphics.setColor(1,(e.hitFlash or 0)>0 and .5 or 1,(e.hitFlash or 0)>0 and .5 or 1);love.graphics.draw(s.snake.move,s.snake.frames[S.frame(e)],e.x,e.y,e.snakeAngle or 0,1,1,24,8)end
end
return S
