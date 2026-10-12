local F={logSeconds=20,charredPerLog=5}
-- Fuel uses elapsed real time, independently of simulation dt and UI pauses.
local epoch,monotonic=os.time(),love and love.timer and love.timer.getTime()
function F.now()
 if monotonic then return epoch+love.timer.getTime()-monotonic end
 return os.time()
end
function F.stamp(f) f.burnUpdatedAt=F.now();return f end
local function queued(f)
 if f.queuedLogs==nil then f.queuedLogs=math.max(0,(f.burnedLogs or 1)-(f.completedLogs or 0)-1)end
 return f.queuedLogs
end
function F.add(f)
 f.queuedLogs=queued(f)+1;f.burnedLogs=(f.burnedLogs or 1)+1
end
local function advance(w,dt,player,logger,realNow)
 for i=#w.campfires,1,-1 do local f=w.campfires[i]
  if not f.permanent then
   local elapsed=dt
   if realNow then
    elapsed=math.max(0,realNow-(tonumber(f.burnUpdatedAt)or realNow))
    f.burnUpdatedAt=realNow
   end
   local remaining=f.bonfire and(queued(f)+1)or 1;f.timer=f.timer-elapsed
   if f.timer<=0 then
    local completed=f.bonfire and math.min(remaining,math.floor(-f.timer/F.logSeconds)+1)or 1
    f.completedLogs=(f.completedLogs or 0)+completed;local charred=completed*F.charredPerLog
    require('game.rune_drops').drop(w,'Charred Wood',charred,f,player)
    if logger then logger:log(f.bonfire and'BONFIRE_LOG_BURNED'or'CAMPFIRE_LOG_BURNED',{x=f.x,y=f.y,logs=completed,charredWood=charred,remainingLogs=remaining-completed})end
    if remaining>completed then f.queuedLogs=remaining-completed-1;f.timer=f.timer+completed*F.logSeconds
    else table.remove(w.campfires,i);if logger then logger:log(f.bonfire and'BONFIRE_EXPIRED'or'CAMPFIRE_EXPIRED',{x=f.x,y=f.y,charredWood=charred,logs=f.burnedLogs or 1})end end
   end
  end
 end
 if not realNow or dt>0 then require('game.rune_drops').retry(w,player,dt)end
end
function F.update(w,dt,player,logger) advance(w,dt,player,logger) end
function F.realtime(w,player,logger,now)
 if not w then return end
 now=now or F.now()
 local elapsed=math.max(0,now-(w._fireClock or now));w._fireClock=now
 advance(w,elapsed,player,logger,now)
end
-- Cached regions and cave instances keep burning even when their simulation stops.
function F.tickWorlds(active,player,logger)
 local seen={};local now=F.now()
 local function visit(w)
  if not w or seen[w]then return end;seen[w]=true
  F.realtime(w,w==active and player or nil,logger,now)
  visit(w.overworld)
  for _,cave in pairs(w.caveInstances or {})do visit(cave)end
 end
 visit(active)
 for _,w in pairs(require('game.regions').cache or {})do visit(w)end
end
function F.export(w)
 -- Cave saves use a shallow overworld proxy to reposition mercenaries only.
 -- Fuel/retry state must be advanced on the real world, never that proxy.
 w=w._fireSource or w
 F.realtime(w)
 local out={savedAt=F.now(),fires={},charred={},pending={}}
 for _,f in ipairs(w.campfires or{})do if not f.permanent then out.fires[#out.fires+1]={x=f.x,y=f.y,timer=f.timer,burnUpdatedAt=f.burnUpdatedAt,bonfire=f.bonfire,buffId=f.buffId,burnedLogs=f.burnedLogs,completedLogs=f.completedLogs,queuedLogs=f.bonfire and queued(f)or nil}end end
 for _,g in ipairs(w.groundItems or{})do if g.name=='Charred Wood'then out.charred[#out.charred+1]={name=g.name,x=g.x,y=g.y,lit=g.lit,expiresAt=g.expiresAt,object=require('game.items').copy(g.object)}end end
 for _,p in ipairs(w.pendingRuneDrops or{})do if p.name=='Charred Wood'then out.pending[#out.pending+1]={name=p.name,qty=p.qty,source={x=p.source.x,y=p.source.y}}end end
 return out
end
function F.restore(w,data)
 if type(data)~='table'then return end
 for i=#w.campfires,1,-1 do if not w.campfires[i].permanent then table.remove(w.campfires,i)end end
 for _,f in ipairs(data.fires or{})do local permanent=false;for _,existing in ipairs(w.campfires)do if existing.permanent and(existing.x-f.x)^2+(existing.y-f.y)^2<1 then permanent=true;break end end;if not permanent then local copy={};for _,key in ipairs({'x','y','timer','burnUpdatedAt','bonfire','burnedLogs','completedLogs','queuedLogs','buffId'})do copy[key]=f[key]end;copy.burnUpdatedAt=copy.burnUpdatedAt or data.savedAt or F.now();w.campfires[#w.campfires+1]=copy end end
 for i=#w.groundItems,1,-1 do if w.groundItems[i].name=='Charred Wood'then table.remove(w.groundItems,i)end end
 for _,g in ipairs(data.charred or{})do w.groundItems[#w.groundItems+1]={name='Charred Wood',x=g.x,y=g.y,lit=g.lit,expiresAt=g.expiresAt,object=require('game.items').copy(g.object)}end
 w.pendingRuneDrops=w.pendingRuneDrops or{};for i=#w.pendingRuneDrops,1,-1 do if w.pendingRuneDrops[i].name=='Charred Wood'then table.remove(w.pendingRuneDrops,i)end end
 for _,p in ipairs(data.pending or{})do w.pendingRuneDrops[#w.pendingRuneDrops+1]={name='Charred Wood',qty=p.qty,source={x=p.source.x,y=p.source.y}}end
 require("game.ground_lifetime").update(w)
 F.realtime(w)
end
return F
