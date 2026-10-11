local B={duration=300}
function B.active(p)return (tonumber(p.bonfireBuffUntil)or 0)>require('game.fire_fuel').now()end
function B.grant(p,fire)
 local key=fire.buffId or(tostring(fire.x)..':'..tostring(fire.y)..':'..tostring(fire.burnedLogs or 1))
 if p.bonfireLastSource==key then return end
 p.bonfireLastSource=key;p.bonfireBuffUntil=require('game.fire_fuel').now()+B.duration
end
function B.visit(w,p)local f=w:bonfireNear(p);if f then B.grant(p,f)end end
return B
