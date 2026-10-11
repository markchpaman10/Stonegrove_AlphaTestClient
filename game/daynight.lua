local DayNight={};DayNight.__index=DayNight
function DayNight.new()
 return setmetatable({time=.30,dayLength=1200},DayNight)
end
function DayNight:update(dt) self.time=(self.time+dt/self.dayLength)%1 end
function DayNight:sun()
 local t=self.time
 if t<.20 then return 0 elseif t<.28 then return (t-.20)/.08 elseif t<.70 then return 1 elseif t<.80 then return 1-(t-.70)/.10 else return 0 end
end
function DayNight:isNight() return self:sun()<.28 end
function DayNight:darkness() return .62*(1-self:sun()) end
return DayNight
