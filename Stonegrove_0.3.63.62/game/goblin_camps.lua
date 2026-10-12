local G={}
local imgs={}
local function img(path) if not imgs[path] then local im=love.graphics.newImage(path);im:setFilter('nearest','nearest');imgs[path]=im end;return imgs[path] end
local function d2(a,b)return (a.x-b.x)^2+(a.y-b.y)^2 end
local function clear(w,x,y,r)
 if not w.map:isLand(x,y) then return false end
 for _,h in ipairs(w.houses or {})do if (x-h.x)^2+(y-h.y)^2<(r+100)^2 then return false end end
 for _,p in ipairs(w.paths or {})do local cx=math.max(p.x,math.min(x,p.x+(p.w or 16)));local cy=math.max(p.y,math.min(y,p.y+(p.h or 16)));if (x-cx)^2+(y-cy)^2<(r+70)^2 then return false end end
 for _,c in ipairs(w.goblinCamps or {})do if not c.cleared and (x-c.x)^2+(y-c.y)^2<(r+260)^2 then return false end end
 return true
end
local function addEnemy(w,kind,x,y,level,caged)
 local e=w.makeExpansionEnemy and w.makeExpansionEnemy(kind,x,y,1)
 if not e then return end
 local scale=(level or e.level)/math.max(1,e.level);for key,value in pairs(e.stats or{})do e.stats[key]=math.max(key=='ranged'and 0 or 1,math.floor(value*scale+.5))end;e.mainCombat=e.mainSkill=='Ranged'and e.stats.ranged or e.stats.melee
 e.level=level or e.level;e.maxHp=math.max(5,(e.level or 1)*5);e.hp=e.maxHp;e.campAnimal=caged or nil;e.cagedLocked=caged or nil
 if kind=='goblin' then require('game.goblins').equip(e);e.headVariant=math.random(1,2);e.bodyVariant=math.random(1,3) end
 if caged then e.inactive=false;e.aggro=false;e.state='caged';e.roamX=x;e.roamY=y end
 w.enemies[#w.enemies+1]=e;return e
end
local function clearCampArea(w,x,y,r)
 require("game.node_index").invalidate(w)
 -- Camps claim their footprint after wilderness generation. Remove procedural clutter
 -- so tents, fire, cage and goblins never spawn inside trees/resources/other encounters.
 local rr=r*r
 for i=#(w.nodes or {}),1,-1 do local n=w.nodes[i];if (n.x-x)^2+(n.y-y)^2<rr then table.remove(w.nodes,i) end end
 for i=#(w.enemies or {}),1,-1 do local e=w.enemies[i];if not e.townAnimal and not e.editorSpawnZone and (e.x-x)^2+(e.y-y)^2<rr then table.remove(w.enemies,i) end end
 for i=#(w.groundItems or {}),1,-1 do local q=w.groundItems[i];if (q.x-x)^2+(q.y-y)^2<rr then table.remove(w.groundItems,i) end end
 for i=#(w.caveEntrances or {}),1,-1 do local q=w.caveEntrances[i];if (q.x-x)^2+(q.y-y)^2<rr then table.remove(w.caveEntrances,i) end end
 for i=#(w.campfires or {}),1,-1 do local q=w.campfires[i];if not q.goblinCamp and (q.x-x)^2+(q.y-y)^2<rr then table.remove(w.campfires,i) end end
end
function G.add(w,x,y,seed,manual,questKey,enemyKind)
 w.goblinCamps=w.goblinCamps or {};local rng=love.math.newRandomGenerator(seed or math.random(1,99999999))
 clearCampArea(w,x,y,132)
 local lo,hi=require('game.level_zones').encounterRange(w.map,x,y);local c={kind=enemyKind or'goblin',x=x,y=y,seed=seed,manual=manual,questSpawnKey=questKey,questTarget=questKey and true or nil,tents={},decor={},cage=nil}
 local tentCount=rng:random(1,2)
 for i=1,tentCount do local a=(i==1 and -1 or 1);c.tents[#c.tents+1]={x=x+a*rng:random(42,58),y=y-rng:random(18,34),back=rng:random(0,1)==1} end
 local decorImgs={'goblin_decor_plant.png','goblin_decor_logs.png','goblin_decor_rack.png'}
 for i=1,rng:random(2,5)do local ang=rng:random()*math.pi*2;local rr=rng:random(34,78);c.decor[#c.decor+1]={x=x+math.cos(ang)*rr,y=y+math.sin(ang)*rr,img=decorImgs[rng:random(#decorImgs)]}end
 local campfire={x=x,y=y,timer=math.huge,permanent=true,goblinCamp=c};c.campfire=campfire;w.campfires[#w.campfires+1]=campfire
 for i=1,rng:random(2,5)do local ang=rng:random()*math.pi*2;local rr=rng:random(45,90);local e=addEnemy(w,enemyKind or'goblin',x+math.cos(ang)*rr,y+math.sin(ang)*rr,rng:random(lo,hi),false);if e and e.kind=='nagalian'then require('game.nagalians').configure(w,e)end end
 if rng:random()<.70 then local cx,cy=x+rng:random(-80,80),y+rng:random(48,88);local animal=({'boar','wolf','rat'})[rng:random(3)];c.cage={x=cx,y=cy,open=false,animal=animal};local e=addEnemy(w,animal,cx,cy,rng:random(lo,hi),true);if e then c.cage.enemy=e end end
 for _,e in ipairs(w.enemies)do if not e.campId and (e.x-x)^2+(e.y-y)^2<130^2 then e.campId=c;e.questSpawnKey=questKey or e.questSpawnKey end end;w.goblinCamps[#w.goblinCamps+1]=c;return c
end
function G.generate(w)
 if w.isCave then return end;w.goblinCamps=w.goblinCamps or {};local a=w.map.authored
 local manual={};if a then for _,o in ipairs(a.objects or {})do if o.id=='goblinCamp'or o.id=='nagalianCamp'then manual[#manual+1]=o end end end
 for i,o in ipairs(manual)do G.add(w,o.x,o.y,77191+i*997+(SG_SERVER_GENERATION or 0),true,nil,o.id=='nagalianCamp'and'nagalian'or'goblin')end
 local rng=love.math.newRandomGenerator(((w.houseSeed or 72371)+99173+(SG_SERVER_GENERATION or 0))%2147483647);local target=rng:random(4,8)
 for i=1,target do for attempt=1,120 do local x,y=rng:random(180,w.map.width-180),rng:random(180,w.map.height-180);if clear(w,x,y,120)then G.add(w,x,y,rng:random(1,99999999),false,nil,i%2==0 and'nagalian'or'goblin');break end end end
end
function G.update(w)
 for _,c in ipairs(w.goblinCamps or {}) do
  if not c.cleared then
   local alive=false
   for _,e in ipairs(w.enemies or {}) do
    if e.campId==c and e.kind==(c.kind or'goblin') and not e.dead then alive=true;break end
   end
   if not alive then
    c.cleared=true
    -- Remove the physical camp immediately. The lightweight cleared record stays
    -- so quest tracking can observe completion without leaving scenery behind.
    for i=#(w.campfires or {}),1,-1 do if w.campfires[i].goblinCamp==c then table.remove(w.campfires,i) end end
    -- Camp-clear bonus: food-heavy, with a modest material bundle and only a
    -- small chance of one equipment item. This is separate from goblin drops.
    local food={'Small Meat','Large Meat','Small Fish','Cooked Chicken','Egg'}
    local materials={'Pine Logs','Small Copper Chunk','Basic Wood Parts','Linen Cloth','Leather','Feather','Stone Gravel'}
    local gear={'Copper Dagger','Copper Axe','Copper Pickaxe','Copper Helm','Copper Armor','Copper Shield'}
    local function scatter(name,qty,band) for i=1,qty do local a=i*2.399+(band or 0);local r=18+((i*9)%30);w:addGroundItem(name,c.x+math.cos(a)*r,c.y+math.sin(a)*r) end end
    scatter(food[math.random(#food)],math.random(2,4),.4)
    if math.random()<.65 then scatter(materials[math.random(#materials)],math.random(1,3),1.5) end
    if math.random()<.25 then scatter(gear[math.random(#gear)],1,2.7) end
    scatter('Copper Coins',math.random(2,5),3.5)
    -- A surviving caged animal is released when the cage/scenery is torn down.
    if c.cage and c.cage.enemy and not c.cage.enemy.dead then local e=c.cage.enemy;e.cagedLocked=nil;e.campAnimal=nil;e.inactive=false;e.state='idle';e.spawnX,e.spawnY=e.x,e.y end
    if w.addPopup then w:addPopup(c.x,c.y-30,((c.kind=='nagalian'and'NAGALIAN'or'GOBLIN')..' CAMP CLEARED')) end
   end
  end
 end
end
function G.click(w,player,x,y)
 for _,c in ipairs(w.goblinCamps or {})do if not c.cleared then local q=c.cage;if q and not q.open and (x-q.x)^2+(y-q.y)^2<42^2 then
  if (player.x-q.x)^2+(player.y-q.y)^2>70^2 then w:addPopup(player.x,player.y-24,'MOVE CLOSER','miss');return true end
  q.open=true;if q.enemy then q.enemy.inactive=false;q.enemy.campAnimal=nil;q.enemy.cagedLocked=nil;q.enemy.spawnX=q.x+48;q.enemy.spawnY=q.y+24;q.enemy.x=q.x+28;q.enemy.y=q.y+16 end;w:addPopup(q.x,q.y-26,'CAGE OPENED');return true
 end end end;return false
end
function G.draw(w,add)
 for _,c in ipairs(w.goblinCamps or {})do
  if not c.cleared then
  for _,t in ipairs(c.tents)do local tt=t;add(tt.y+20,function()local im=img(tt.back and 'assets/goblin_tent_back.png' or 'assets/goblin_tent_front.png');love.graphics.setColor(1,1,1);love.graphics.draw(im,tt.x,tt.y,0,1,1,im:getWidth()/2,im:getHeight()/2)end)end
  for _,d in ipairs(c.decor)do local dd=d;add(dd.y+8,function()local im=img('assets/'..dd.img);love.graphics.setColor(1,1,1);love.graphics.draw(im,dd.x,dd.y,0,1,1,im:getWidth()/2,im:getHeight()/2)end)end
  if c.cage then local q=c.cage;add(q.y+18,function()local im=img(q.open and 'assets/goblin_cage_open.png' or 'assets/goblin_cage_closed.png');love.graphics.setColor(1,1,1);love.graphics.draw(im,q.x,q.y,0,1,1,im:getWidth()/2,im:getHeight()/2)end)end
  end
 end
end
return G
