local N={}
N.def={baseLevel=1,tierMin=1,tierMax=1,melee=1,ranged=1,strength=1,agility=1,health=1,mainSkill='Melee Combat',aggro=95,leash=210,roam=48,speed=28,attackRange=26,rangedRange=120,attackSpeed=1.5}
function N.weaponInfo(e,sprites)local info={};for k,v in pairs(sprites.itemInfo[e.weapon]or{})do info[k]=v end;info.damage=math.max(tonumber(info.damage)or 1,e.level or 1);return info end
function N.appearance(e)
 e.headVariant=math.random(1,2);e.bodyVariant=math.random(1,2);e.direction='down';e.walkTime=0;e.customName=e.customName or'Nagalian'
end
function N.configure(w,e,preserve)
 local level=select(2,require('game.level_zones').range(w.map));e.level=level
 e.stats={melee=level,ranged=level,strength=level,agility=level,health=level};e.maxHp=level*5
 if not preserve then e.hp=e.maxHp end
 if not e.headVariant then N.appearance(e)end
 local options={}
 for name,d in pairs(w.sprites.itemInfo)do local _,required=require('game.progression').requirement(name,d);if d.type=='Weapon'and not d.placeholder and required<=level and w.sprites.itemQuads[name]then options[#options+1]=name end end
 table.sort(options)
 if not preserve or not e.weapon then e.weapon=#options>0 and options[math.random(#options)]or'Copper Dagger'end
 e.nagalianStyle=tostring(e.weapon):find('Bow')and'bow'or tostring(e.weapon):find('Staff')and'magic'or'melee'
 e.mainSkill=e.nagalianStyle=='bow'and'Ranged'or e.nagalianStyle=='magic'and'Magic'or'Melee Combat';e.mainCombat=level;e.arrows=999999
 e.nightOnly=nil;e.dayOnly=nil;e.inactive=false
end
local function safe(w,x,y)
 if not require('game.naga_queen').allowed(w,x,y,30)or w:enemyBlocked(x,y)then return false end
 for _,c in ipairs(w.goblinCamps or{})do if not c.cleared and(x-c.x)^2+(y-c.y)^2<180^2 then return false end end
 for _,e in ipairs(w.enemies)do if not e.dead and(x-e.x)^2+(y-e.y)^2<80^2 then return false end end
 return true
end
function N.generate(w,restore)
 if w.isCave then return end
 local n=0;for _,e in ipairs(w.enemies)do if e.kind=='nagalian'and not e.campId and not e.editorSpawnZone then n=n+1 end end
 local rng=love.math.newRandomGenerator((w.houseSeed or 1)+6639)
 if restore then local camps=0;for _,c in ipairs(w.goblinCamps or{})do if c.kind=='nagalian'then camps=camps+1 end end
  for i=camps+1,2 do for attempt=1,160 do local x=rng:random(180,math.max(180,w.map.width-180));local y=rng:random(180,math.max(180,w.map.height-180));if safe(w,x,y)then local spaced=true;for _,c in ipairs(w.goblinCamps or{})do if(x-c.x)^2+(y-c.y)^2<400^2 then spaced=false end end;if spaced then require('game.goblin_camps').add(w,x,y,rng:random(1,99999999),false,nil,'nagalian');break end end end end
 end
 for i=n+1,6 do for attempt=1,160 do local x=rng:random(100,math.max(100,w.map.width-100));local y=rng:random(100,math.max(100,w.map.height-100));if safe(w,x,y)then local e=w.makeExpansionEnemy('nagalian',x,y,1);N.configure(w,e);e.wildernessNagalian=true;w.enemies[#w.enemies+1]=e;break end end end
end
function N.update(w,dt)
 for _,e in ipairs(w.enemies)do if e.kind=='nagalian'then
  if e.campId and e.campId.cleared and e.dead then e.respawnTimer=1e9 end
  local dx,dy=e.x-(e.nagalianLastX or e.x),e.y-(e.nagalianLastY or e.y)
  if math.abs(dx)+math.abs(dy)>.01 then e.direction=math.abs(dx)>math.abs(dy)and(dx>0 and'right'or'left')or(dy>0 and'down'or'up');e.walkTime=(e.walkTime or 0)+dt else e.walkTime=0 end
  e.nagalianLastX,e.nagalianLastY=e.x,e.y
 end end
end
function N.rangedTurn(w,e,p,d2)
 if e.nagalianStyle=='melee'or d2>120^2 then return false end
 e.state='ranged';local dx,dy=p.x-e.x,p.y-e.y;e.direction=math.abs(dx)>math.abs(dy)and(dx>0 and'right'or'left')or(dy>0 and'down'or'up')
 if e.attackTimer<=0 then e.attackTimer=1.8;require('game.goblins').shoot(w,e,p);local q=w.goblinArrows[#w.goblinArrows];if q and e.nagalianStyle=='magic'then q.magic=true end end
 return true
end
function N.skin(w,e,p,skills,inv,logger)
 if not e.dead or e.skinned then return false,'not_skinnable'end
 if(e.x-p.x)^2+(e.y-p.y)^2>42^2 then return false,'too_far'end
 local knife=p.equipped=='Copper Dagger'or p.equipped=='Copper Knife'or inv:hasItem('Copper Dagger')or inv:hasItem('Copper Knife')
 if not knife then return false,'missing_Copper Dagger'end
 local qty=math.min(5,1+math.floor((skills:get('Skinning').level-1)/20))
 if not inv:canAdd('Raw Cave Snake Hide',qty)then return false,'bag_full'end
 if not inv:add('Raw Cave Snake Hide',qty)then return false,'bag_full'end
 e.skinned=true;skills:addXP('Skinning',12*qty);w:addPopup(e.x,e.y-18,'+'..qty..' SNAKE SKINS','defeat')
 if logger then logger:log('ANIMAL_SKINNED',{enemy='nagalian',item='Raw Cave Snake Hide',quantity=qty,xpGained=12*qty})end
 return true,'Raw Cave Snake Hide'
end
local sheets
local function load()
 sheets={}
 for _,i in ipairs({1,2,3,4})do local im=love.graphics.newImage('assets/nagalian_'..i..'.png');im:setFilter('nearest','nearest');local s={image=im}
  for row,dir in ipairs({'down','right','up'})do s[dir]={};for f=1,4 do s[dir][f]=love.graphics.newQuad((f-1)*16,(row-1)*16,16,16,im:getDimensions())end end;sheets[i]=s
 end
end
function N.draw(sprites,e)
 if not sheets then load()end
 local g=love.graphics;g.push('all');g.translate(e.x,e.y);if e.dead then g.rotate(math.pi/2);g.setColor(.55,.55,.55,.8)end
 local dir=e.direction or'down';local key=dir=='left'and'right'or dir;local flip=dir=='left'and-1 or 1;local f=e.dead and 1 or math.floor((e.walkTime or 0)/.14)%4+1
 local body=sheets[e.bodyVariant==2 and 4 or 1];local head=sheets[e.headVariant==2 and 3 or 2]
 g.draw(body.image,body[key][f],0,0,0,flip,1,8,8);g.draw(head.image,head[key][f],0,0,0,flip,1,8,8)
 if not e.dead then local im=sprites.itemImages[e.weapon];local q=sprites.itemQuads[e.weapon];if im and q then g.draw(im,q,flip*7,1,0,flip,1,8,8)end end
 g.pop();if e.dead then g.setColor(1,1,1);g.print('SKIN',e.x-12,e.y-18)end
end
return N
