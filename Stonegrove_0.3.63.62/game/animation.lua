local A={}
local states=setmetatable({},{__mode='k'})
function A.updateEntity(e,dt)
 local s=states[e]
 if not s then s={x=e.x,y=e.y,hp=e.hp,phase=(e.x+e.y)*.07,time=0,weight=0,combat=0};states[e]=s end
 local d=math.sqrt((e.x-s.x)^2+(e.y-s.y)^2)
 s.x,s.y=e.x,e.y;s.time=s.time+dt
 if d<64 then s.phase=s.phase+d*.35 end
 local moving=d>.01 and d<64 and not e.dead and not e.inactive
 s.weight=s.weight+((moving and 1 or 0)-s.weight)*math.min(1,dt*12)
 s.combat=math.max(0,s.combat-dt)
 if e.hp and s.hp and e.hp<s.hp then s.combat=3 end;s.hp=e.hp
end
function A.update(world,player,dt)
 A.updateEntity(player,dt)
 player.combatBarAlpha=math.max(0,math.min(1,(player.combatBarAlpha or 0)+(A.playerCombat(world,player) and dt*5 or -dt)))
 for _,list in ipairs({world.enemies,world.mercs,world.sheep,world.traders,world.tradeKeepers,world.healers,world.questNPCs or {}}) do for _,e in ipairs(list or {}) do A.updateEntity(e,dt) end end
end
function A.enemyCombat(world,e)
 return not e.dead and not e.inactive and (e.aggro or world.combatTarget==e or (states[e] and states[e].combat>0)) or false
end
function A.playerCombat(world,p)
 if (states[p] and states[p].combat>0) or (p.slimeCoated or 0)>0 or (p.poisonedTimer or 0)>0 then return true end
 for _,e in ipairs(world.enemies) do if A.enemyCombat(world,e) and (e.x-p.x)^2+(e.y-p.y)^2<200^2 then return true end end
 return false
end
function A.pose(e)
 local s=states[e];if not s or e.dead or e.inactive then return 0,0,1,1 end
 local wave=math.sin(s.phase);local angle=wave*.055*s.weight;local bob=-math.abs(math.cos(s.phase))*1.2*s.weight
 local sx,sy=1,1
 if e.kind=='slimeBoss' or e.kind=='slime' then local pulse=math.sin(s.time*3+s.phase*.2);sx=1+pulse*.055;sy=1-pulse*.055;angle=angle*.6;bob=bob*1.4
 elseif e.kind=='gigaRat' then angle=wave*.022*s.weight;bob=bob*1.8;sy=1+math.sin(s.time*2)*.018 end
 return angle,bob,sx,sy
end
function A.begin(e)
 local angle,bob,sx,sy=A.pose(e)
 love.graphics.push();love.graphics.translate(e.x,e.y+8+bob);love.graphics.rotate(angle);love.graphics.scale(sx*(e.visualScale or 1),sy*(e.visualScale or 1));love.graphics.translate(-e.x,-e.y-8)
end
function A.finish() love.graphics.pop() end
function A.title(t) return 1+math.sin(t*math.pi/9)*.035,math.sin(t*math.pi/11)*.035 end
return A
