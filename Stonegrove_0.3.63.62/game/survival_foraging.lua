local M={}
local eligible={['Red Berries']=true,['Purple Berries']=true,['Brown Mushroom']=true,['Large Blue Mushroom']=true,['Bush Root']=true,['Bush Greens']=true}
function M.food(a,name)
 local t=os.time();local d=require('game.fieldcraft').config(a)
 if name:find('Burnt',1,true)==1 then return end
 if eligible[name]or name:find('Cooked',1,true)or name:find('Jerky',1,true)then
  if t>=(d.foodNext or 0)then d.foodNext=t+30;a.skills:addXP('Survival',2)end
 end
end
function M.damage(player,skills,damage,encounter)
 if damage<=0 or player.hp<=0 or player.hp>player.maxHp*.1 then return end
 local t=love.timer.getTime();player.survivalHits=player.survivalHits or{};local key=tostring(encounter or'unknown');local n=player.survivalHits[key]or{count=0,time=0}
 if n.count<3 and t>=n.time then n.count=n.count+1;n.time=t+30;player.survivalHits[key]=n;skills:addXP('Survival',math.min(5,damage))end
end
function M.install(W)
 local gather=W.updateGather
 W.updateGather=function(w,dt,p,inv,skills,logger)
  local g=w.gather;local name=g and g.item;local before=name and inv:countItem(name)
  local result=gather(w,dt,p,inv,skills,logger)
  if name and eligible[name]then local gained=inv:countItem(name)-before;if gained>0 then skills:addXP('Foraging',gained*4)end end
  return result
 end
end
return M
