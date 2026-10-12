-- Friendly player selection uses multiplayer identities, never enemy IDs.
local T={}
function T.clear()T.id=nil end
function T.allowed(u)
 if not u.equipment or u.equipment.offhand~='Spellbook'then return false end
 for _,page in pairs(u.spellPages or{})do if(require('game.magic_system').spells[page]or{}).heal then return true end end
 return false
end
local function same(u,p)
 local c=require('game.presence').context(u.world,u.player)
 return p.worldId==c.worldId and p.regionId==c.regionId and p.area==c.area and p.caveId==c.caveId and p.caveSeed==c.caveSeed
end
function T.resolve(u,id)
 if not T.allowed(u)then T.clear();return nil end;id=id or T.id;local M=require('game.multiplayer');if not id or not M.active or not M.ready then return nil end
 for _,p in ipairs(M.peers or{})do if p.id==id and same(u,p)then return p end end
end
function T.at(u,x,y)
 if not T.allowed(u)then T.clear();return nil end
 local M=require('game.multiplayer');if not M.active or not M.ready then return nil end
 local best,dist
 for _,p in ipairs(M.peers or{})do if same(u,p)then local dx,dy=x-(p.drawX or p.x),y-(p.drawY or p.y);local d=dx*dx+dy*dy;if d<18^2 and(not dist or d<dist)then best,dist=p,d end end end
 return best
end
function T.click(u,x,y)
 local p=T.at(u,x,y);if not p then return false end
 return T.select(u,p)
end
function T.select(u,p)
 if not T.allowed(u)then T.clear();return false end
 T.id=p.id;u.world:stopCombat('friendly_target',u.logger);u.world.targetedEnemy=nil;u.world:stopGather('friendly_target',u.logger)
 u.world:addPopup(u.player.x,u.player.y-24,'Healing target: '..p.name,'defeat');return true
end
function T.draw(u,camera,w,h)
 if not T.id then return end;local p=T.resolve(u);if not p then T.clear();return end
 local g=love.graphics;g.push('all');local x,y=camera:toScreen(p.drawX or p.x,p.drawY or p.y,w,h)
 g.setColor(.25,1,.5,.9);g.circle('line',x,y,18);g.setColor(.02,.04,.03,.9);g.rectangle('fill',16,h-144,300,48,5,5)
 g.setColor(.65,1,.75);g.printf('Healing target: '..p.name,24,h-138,284);g.setColor(1,1,1);g.print(string.format('%d / %d HP - Escape: clear',p.hp or 0,p.maxHp or 0),24,h-119);g.pop()
end
return T
