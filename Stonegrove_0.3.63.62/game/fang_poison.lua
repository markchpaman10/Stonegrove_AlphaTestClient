-- A damaging snake-fang hit can apply two poison ticks. Effects never stack.
local P={chance=.25,duration=2}
function P.apply(w,e,arrow,skills,logger,owner,roll)
 if arrow~='Snake Fang Arrows'or not e or e.dead or e.inactive or e.hp<=0 then return false end
 if (roll or math.random())>=P.chance then return false end
 e.fangPoison={remaining=2,untilTick=1,skills=skills,logger=logger,owner=owner};w:addPopup(e.x,e.y-22,'POISON 2s','damage');return true
end
function P.update(w,dt)
 for _,e in ipairs(w.enemies or{})do local p=e.fangPoison
  if p then if e.dead or e.inactive or e.hp<=0 then e.fangPoison=nil else
   local elapsed=math.min(math.max(0,dt),p.remaining);p.remaining=p.remaining-elapsed;p.untilTick=p.untilTick-elapsed
   while p.untilTick<=.000001 and not e.dead do
    p.untilTick=p.untilTick+1;local damage=math.min(1,e.hp);e.hp=math.max(0,e.hp-damage);w:addPopup(e.x,e.y-14,'POISON '..damage,'damage')
    if p.owner then require('game.party').threat(w,e,p.owner,damage)end
    if p.skills then for skill,xp in pairs({Ranged=4,Strength=4,Health=1.33})do p.skills:addXP(skill,damage*xp)end end
    if p.logger then p.logger:log('SNAKE_FANG_POISON_TICK',{target=e.kind,damage=damage,targetHp=e.hp})end
    if e.hp<=0 then local previous=w.playerRef;if p.owner then w.playerRef=p.owner end;w:defeatEnemy(e,p.skills,p.logger);w.playerRef=previous;e.fangPoison=nil end
   end
   if p.remaining<=0 then e.fangPoison=nil end
  end end
 end
end
return P
