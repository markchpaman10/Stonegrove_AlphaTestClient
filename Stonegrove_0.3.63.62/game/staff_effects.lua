-- Pine Staff: half a percentage point per Magic level; never roll for another weapon.
local S={}
function S.chance(weapon,level)
 if weapon~='Pine Staff' then return 0 end
 level=tonumber(level) or 1;if level~=level then level=1 end
 return math.min(50,math.max(0,math.floor(level))*.5)/100
end
function S.saves(weapon,level)
 local chance=S.chance(weapon,level)
 return chance>0 and math.random()<chance or false
end
return S
