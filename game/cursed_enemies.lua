local C={chance=.05}
local R=require('game.rune_inventory')
function C.reset(e)
 if e.curseBase then local b=e.curseBase;e.level=b.level;e.stats=R.copy(b.stats);e.maxHp=b.maxHp;e.mainCombat=b.mainCombat;e.customName=b.customName end
 e.curseBase=nil;e.curseRolled=nil;e.cursed=false;e.boneDamage=nil;e.boneOwner=nil;e.bonePileDropped=nil
end
function C.apply(e,roll)
 if e.curseRolled or e.dead then return false end;e.curseRolled=true;e.cursed=roll<C.chance
 if not e.cursed then return false end
 local lv=math.max(1,e.level or 1);e.curseBase={level=e.level,stats=R.copy(e.stats or{}),maxHp=e.maxHp,mainCombat=e.mainCombat,customName=e.customName}
 e.level=lv+1;for k,v in pairs(e.stats or{})do if type(v)=='number'and v>0 then e.stats[k]=v+1 end end
 local extra=math.max(1,math.ceil((e.maxHp or 5)/lv));e.maxHp=(e.maxHp or 5)+extra;e.hp=math.min(e.maxHp,(e.hp or 5)+extra);e.mainCombat=(e.mainCombat or lv)+1
 local name=e.customName or({slimeBoss='Slime King',gigaRat='Giga Rat',caveSnake='Cave Snake',nagaQueen='Naga Queen'})[e.kind]or(e.kind:sub(1,1):upper()..e.kind:sub(2));e.customName='Cursed '..name
 return true
end
function C.world(w)
 if w.onlineShared and not SG_SERVER then return end
 w._curseRng=w._curseRng or love.math.newRandomGenerator((w.houseSeed or 24681357)+7739)
 for _,e in ipairs(w.enemies or{})do if e.dead then require('game.bone_religion').drop(w,e,{kind='environment'})elseif not e.curseRolled then C.apply(e,w._curseRng:random())end end
end
function C.draw(s,e)
 if not e.cursed or e.dead or e.inactive then return end
 if not s.cursedAura then s.cursedAura=love.graphics.newImage('assets/cursed_aura.png');s.cursedAura:setFilter('nearest','nearest');s.cursedAuraQuads={};for i=0,4 do s.cursedAuraQuads[i+1]=love.graphics.newQuad(i*16,0,16,16,s.cursedAura:getDimensions())end end
 local frame=math.floor(love.timer.getTime()/.12)%5+1;local scale=math.max(1,math.min(3,(e.hitRadius or 14)/14));love.graphics.setColor(1,1,1);love.graphics.draw(s.cursedAura,s.cursedAuraQuads[frame],e.x,e.y+5,0,scale,scale,8,8)
end
return C
