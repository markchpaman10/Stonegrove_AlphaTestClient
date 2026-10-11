local Goblins={}
function Goblins.load(image)
 local function frames(col,startRow)
  startRow=startRow or 8
  local out={}
  for row,dir in ipairs({'up','right','down'}) do
   out[dir]={}
   for frame=1,4 do out[dir][frame]=love.graphics.newQuad((col+frame-1)*16,(startRow+row-1)*16,16,16,image:getDimensions()) end
  end
  return out
 end
 return {image=image,heads={frames(0),frames(12)},bodies={frames(4),frames(8),frames(4,11)}}
end
function Goblins.draw(sprites,enemy,x,y)
 local dir=enemy.direction or 'down'
 local key=dir=='left' and 'right' or dir
 local frame=math.floor((enemy.walkTime or 0)/.14)%4+1
 local flip=dir=='left' and -1 or 1
 love.graphics.draw(sprites.image,sprites.bodies[enemy.bodyVariant or 1][key][frame],x,y,0,flip,1,8,8)
 love.graphics.draw(sprites.image,sprites.heads[enemy.headVariant or 1][key][frame],x,y,0,flip,1,8,8)
end
function Goblins.equip(e)
 local weapons={'Copper Dagger','Copper Axe','Bow'}
 e.weapon=weapons[math.random(#weapons)];e.arrows=e.weapon=='Bow' and math.random(6,12) or 0
end
function Goblins.drop(world,e)
 if e.lootDropped then return end;e.lootDropped=true
 -- Curated weighted goblin loot. Ordinary goblins get at most one successful
 -- category drops, with food intentionally being the most common reward.
 local gear={'Copper Dagger','Copper Axe','Copper Pickaxe','Copper Helm','Copper Armor','Copper Shield'}
 local materials={'Pine Logs','Small Copper Chunk','Pine Wood Parts','Linen Cloth','Leather','Feather','Stone Gravel'}
 local food={'Small Meat','Large Meat','Small Fish','Cooked Chicken','Egg'}
 local function scatter(name,qty,band)
  for i=1,qty do local a=(i*2.399)+(band or 0);local r=7+((i*7)%20);world:addGroundItem(name,e.x+math.cos(a)*r,e.y+math.sin(a)*r) end
 end
 local rolls={}
 local function chance(p,kind) if math.random()<p then rolls[#rolls+1]=kind end end
 chance(.45,'food');chance(.18,'material');chance(.20,'coins');chance(.08,'ammo');chance(.04,'consumable');chance(.025,'gear');chance(.01,'valuable')
 -- Shuffle successful categories so a freakishly lucky goblin still pays only one.
 for i=#rolls,2,-1 do local j=math.random(i);rolls[i],rolls[j]=rolls[j],rolls[i] end
 for i=1,math.min(1,#rolls) do
  local kind=rolls[i]
  if kind=='food' then scatter(food[math.random(#food)],math.random(1,2),.2)
  elseif kind=='material' then scatter(materials[math.random(#materials)],math.random(1,2),1.0)
  elseif kind=='coins' then scatter('Copper Coins',math.random(1,3),1.8)
  elseif kind=='ammo' then scatter('Copper Arrows',math.random(2,5),2.5)
  elseif kind=='consumable' then scatter((math.random()<.75) and 'Health Tube' or 'Antipoison Tube',1,3.0)
  elseif kind=='gear' then scatter(gear[math.random(#gear)],1,3.5)
  elseif kind=='valuable' then scatter('Rough Onyx',1,4.0) end
 end
end
function Goblins.shoot(world,e,p)
 require("game.audio").play("bow_shot",e.x,e.y);e.arrows=e.arrows-1;world.goblinArrows=world.goblinArrows or {}
 local dx,dy=p.x-e.x,p.y-e.y;local d=math.max(1,math.sqrt(dx*dx+dy*dy))
 world.goblinArrows[#world.goblinArrows+1]={x=e.x,y=e.y,vx=dx/d*150,vy=dy/d*150,life=d/150+.15,damage=require("game.progression").roll(e.stats.ranged,e.kind=='nagalian'and require('game.nagalians').weaponInfo(e,world.sprites)or world.sprites.itemInfo[e.weapon]or world.sprites.itemInfo["Pine Bow"],e.stats.strength)}
end
function Goblins.updateShots(world,dt,p)
 for i=#(world.goblinArrows or {}),1,-1 do
  local a=world.goblinArrows[i];local ox,oy=a.x,a.y;local step=math.min(dt,a.life)
  a.x=a.x+a.vx*step;a.y=a.y+a.vy*step;a.life=a.life-dt
  local dx,dy=a.x-ox,a.y-oy;local n=dx*dx+dy*dy
  local p=p
  if world.onlineActors then local best;for _,actor in ipairs(world.onlineActors)do local candidate=actor.player;local ct=n>0 and math.max(0,math.min(1,((candidate.x-ox)*dx+(candidate.y-oy)*dy)/n))or 0;local dist=(ox+dx*ct-candidate.x)^2+(oy+dy*ct-candidate.y)^2;if not best or dist<best then p,best=candidate,dist end end end
  local t=n>0 and math.max(0,math.min(1,((p.x-ox)*dx+(p.y-oy)*dy)/n)) or 0
  if (ox+dx*t-p.x)^2+(oy+dy*t-p.y)^2<9^2 then require("game.audio").play("arrow_impact",p.x,p.y);require("game.audio").play("player_hurt",p.x,p.y);if(a.damage or 0)>0 then p.damageSerial=(p.damageSerial or 0)+1;p.lastDamageSource="Goblin"end;p.hp=math.max(0,p.hp-(a.damage or 0));a.life=0;world:addPopup(p.x,p.y-16,(a.magic and'MAGIC 'or'ARROW ')..(a.damage or 0),'damage') end
  if a.life<=0 then table.remove(world.goblinArrows,i) end
 end
end
return Goblins
