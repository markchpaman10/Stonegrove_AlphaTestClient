-- Queued player intent only. Inventory, harvest and combat use the existing actions.
local C={}
local Nav=require('game.navigation')
local function near(a,x,y,r)return a and(a.x-x)^2+(a.y-y)^2<r*r end
function C.cancel()local q=C.pending;if q and q.phase=='prospect'and q.ui and q.ui.craftJob and q.ui.craftJob.prospecting then q.ui.craftJob=nil end;C.pending=nil end
function C.pick(u,x,y)
 local w=u.world;require('game.quests').setup(w)
 local H=require('game.modular_houses');for _,house in ipairs(w.houses or{})do if H.is(house)and H.doorAt(house,x,y)then local dx=H.door(house);return{world=w,kind='house',house=house,x=dx,y=house.y-9,range=3}end end
 local function result(a,kind,range,list)return {world=w,target=a,kind=kind,range=range,list=list,x=a.x,y=a.y}end
 local keeper=require('game.bag_keeper').at(w,x,y);if keeper then return result(keeper,'interact',45,'bagKeepers')end
 local peer=require('game.player_target').at(u,x,y);if peer then return result(peer,'friendly',160)end
 for _,a in ipairs(w.questNPCs or{})do if near(a,x,y,20)then return result(a,'interact',50,'questNPCs')end end
 for _,list in ipairs({'customNPCs','tradeKeepers','traders','healers'})do for _,a in ipairs(w[list]or{})do if near(a,x,y,18)then return result(a,'interact',45,list)end end end
 for _,camp in ipairs(w.playerCamps or{})do for _,a in ipairs(camp.structures or{})do if near(a,x,y,16)then return result(a,'interact',45)end end;if near(camp,x,y,25)then return result(camp,'interact',45)end end
 local a,kind=require('game.caves').at(w,x,y);if a then return result(a,'interact',45,w.isCave and(kind=='chest'and'caveChests'or nil)or'caveEntrances')end
 local station,object=w:stationAt(x,y);if station then return result(object or w[station],'interact',45)end
 for _,key in ipairs({'bankChest','bankClerk','mercRecruiter'})do local a=w[key];if near(a,x,y,18)then return result(a,'interact',45)end end
 for _,camp in ipairs(w.goblinCamps or{})do if near(camp.cage,x,y,42)then return result(camp.cage,'interact',45)end end
 local enemy=w:enemyAt(x,y);if enemy and not enemy.dead and not enemy.inactive then return result(enemy,'attack',26,'enemies')end
 local node=w:nodeAt(x,y);if node then local d=w:resourceInfo(node.kind);return result(node,'harvest',math.max(18,(d and d.reach or 34)-2),'nodes')end
 local ground=w:groundItemAt(x,y);if ground then return result(ground,'interact',24,'groundItems')end
 local sheep=w:sheepAt(x,y);if sheep then return result(sheep,'interact',30,'sheep')end
 local corpse=w:animalCarcassAt(x,y);if corpse then return result(corpse,'interact',50,'enemies')end
 local E=require('game.events');for _,e in ipairs(E.entries or{})do if e.trigger=='interact'then local a=e.target and e.target~=''and E.resolve(u,e.target)or{x=tonumber(e.x)or 0,y=tonumber(e.y)or 0};if a and near(a,x,y,tonumber(e.radius)or 24)then return result(a,'interact',45)end end end
 if w.map:isBeachCell(math.floor(x/16)+1,math.floor(y/16)+1)or w.map:isBeachWaterCell(math.floor(x/16)+1,math.floor(y/16)+1)then return {world=w,kind='interact',x=x,y=y,range=40}end
 return {world=w,kind='move',x=x,y=y,range=5}
end
local function path(u,q)
 Nav.refresh(u.world,u.player.x,u.player.y,math.max(1200,math.sqrt((q.x-u.player.x)^2+(q.y-u.player.y)^2)+160))
 if q.kind=='house'and not require('game.modular_houses').inside(q.house,u.player.x,u.player.y+4)then
  q.points=Nav.path(u.world,u.player,q.x,q.house.y+32)
  if #q.points==0 and not near(u.player,q.x,q.house.y+32,16)then q.index=1;q.repath=0;return end
  for _,y in ipairs({q.house.y+32,q.house.y+8,q.y})do q.points[#q.points+1]={x=q.x,y=y}end
 else q.points=Nav.path(u.world,u.player,q.x,q.y)end;q.index=1;q.repath=0
end
function C.start(u,x,y,dispatch)
 C.cancel();local q=C.pick(u,x,y);q.dispatch=dispatch;q.ui=u;C.pending=q
 u.world:stopGather('right_click_travel',u.logger);u.world:stopCombat('right_click_travel',u.logger);u.world.fishing=nil;u.world.workJob=nil;u.craftJob=nil;u.magicCast=nil;u.useTarget=nil
 path(u,q);q.lastX,q.lastY=u.player.x,u.player.y;q.stuck=0
 if q.kind=='move'and #q.points>0 then local goal=q.points[#q.points];if u.world:playerBlocked(q.x,q.y)then q.x,q.y=goal.x,goal.y end end
 return true
end
function C.direction(u,dt,dx,dy)
 local q=C.pending;if not q then return dx,dy end
 if dx~=0 or dy~=0 then C.cancel();return dx,dy end
 if u.world~=q.world or(u.player.hp or 1)<=0 then C.cancel();return 0,0 end
 q.check=(q.check or 0)-dt
 if q.target and q.list and q.check<=0 then q.check=.25;local found
  for _,a in ipairs(u.world[q.list]or{})do if a==q.target or(q.target.netId and a.netId==q.target.netId)then found=a;break end end
  if not found then C.cancel();return 0,0 end;q.target=found
 end
 if q.kind=='friendly'then local keeper=require('game.bag_keeper').at(w,x,y);if keeper then return result(keeper,'interact',45,'bagKeepers')end
 local peer=require('game.player_target').resolve(u,q.target.id);if not peer then C.cancel();return 0,0 end;q.target=peer end
 if q.target then if q.kind=='harvest'and q.target.depleted or q.kind=='attack'and(q.target.dead or q.target.inactive)then C.cancel();return 0,0 end;q.x,q.y=q.target.x,q.target.y end
 local p=u.player;local dist=math.sqrt((q.x-p.x)^2+(q.y-p.y)^2)
 if q.phase=='prospect'then if u.craftJob then return 0,0 end;if not q.target.prospected then C.cancel();return 0,0 end;q.phase=nil end
 if dist<=q.range then
  if q.kind=='harvest'then local P=require('game.prospecting');if P.isOre(q.target)and not q.target.prospected and not P.canAuto(q.target,u.skills)then if P.start(u,q.target)then q.phase='prospect'else C.cancel()end;return 0,0 end end
  C.cancel();if q.kind=='friendly'then require('game.player_target').select(u,q.target)elseif q.kind~='move'and q.kind~='house'then q.dispatch(q.x,q.y)end;return 0,0
 end
 q.repath=q.repath+dt
 if q.repath>1.5 and q.target then path(u,q)end
 local goal=q.points[q.index]
 while goal and near(goal,p.x,p.y,5)do q.index=q.index+1;goal=q.points[q.index]end
 local tx,ty=goal and goal.x or q.x,goal and goal.y or q.y
 if math.abs(p.x-q.lastX)+math.abs(p.y-q.lastY)<.05 then q.stuck=q.stuck+dt else q.stuck=0 end;q.lastX,q.lastY=p.x,p.y
 if q.stuck>1 then path(u,q);q.failures=(q.failures or 0)+1;q.stuck=0 end
 if(q.failures or 0)>=3 then C.cancel();u.world:addPopup(p.x,p.y-24,'Cannot reach that destination','miss');return 0,0 end
 return tx-p.x,ty-p.y
end
function C.draw(camera,w,h)
 local q=C.pending;if not q then return end;local x,y=camera:toScreen(q.x,q.y,w,h);love.graphics.push('all');love.graphics.setColor(q.kind=='attack'and 1 or .65,q.kind=='attack'and .35 or .9,.4,.85);love.graphics.circle('line',x,y,9);love.graphics.line(x-12,y,x+12,y);love.graphics.line(x,y-12,x,y+12);love.graphics.pop()
end
return C
