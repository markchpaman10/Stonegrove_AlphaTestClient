local M={}
local function valid(w,e,t)
 if not t or(t.hp or 0)<=0 or t.dead or t.inactive or(t.waitingInTown and not require('game.party').present(w,t))or(t.x-e.x)^2+(t.y-e.y)^2>250^2 then return false end
 if t.onlineId and w.onlineActors then for _,a in ipairs(w.onlineActors)do if a.player==t then return true end end;return false end
 return true
end
function M.target(w,boss,fallback)
 local t=require('game.party').target(boss);if valid(w,boss,t)then return t end
 if w.onlineActors then local best;fallback=nil;for _,a in ipairs(w.onlineActors)do local p=a.player;local d=(p.x-boss.x)^2+(p.y-boss.y)^2;if valid(w,boss,p)and(not best or d<best)then fallback,best=p,d end end end
 return valid(w,boss,fallback)and fallback or nil
end
function M.link(boss,minion)
 boss.minionBossId=boss.minionBossId or tostring(boss.netId or('slimeKing:'..boss.spawnX..':'..boss.spawnY));minion.minionBossId=boss.minionBossId
end
function M.follow(w,minion,fallback)
 if not minion.summoned then return nil end
 local boss,best;for _,e in ipairs(w.enemies)do if e.kind=='slimeBoss'and not e.dead and not e.inactive and e.aggro then
  if minion.minionBossId then if e.minionBossId==minion.minionBossId then boss=e;break end
  else local d=(e.x-minion.x)^2+(e.y-minion.y)^2;if d<=250^2 and(not best or d<best)then boss,best=e,d end end
 end end
 if boss then M.link(boss,minion)end
 local t=boss and M.target(w,boss,fallback)or nil;require('game.party').setTarget(minion,t);if t then minion.aggro=true;minion.state='chase' end;return t
end
return M
