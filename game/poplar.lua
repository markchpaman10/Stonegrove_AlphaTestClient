local P={}
-- Upgrade persisted resource layouts once, preserving placements and harvest state.
function P.restore(w)
 if w.isCave then return 0 end
 for _,n in ipairs(w.nodes or{})do if n.kind=='poplar'then return 0 end end
 local L=require('game.level_zones');local eligible,changed=0,0
 for _,n in ipairs(w.nodes or{})do
  if(n.kind=='tree'or n.kind=='oak')and not n.questSpawnKey and not n.quest and not n.questId and not n.authored then
   local z=L.at(w.map,n.x,n.y);local level=n.resourceLevel or L.target(w.map,z)
   if z and level>=30 and(z.resourceMode~='custom'or(z.resources or{}).poplar==true)then
    eligible=eligible+1
    if eligible%5==1 then local oldMax=n.maxHp or w:resourceInfo(n.kind).hp;n.kind='poplar';n.maxHp=12;n.hp=n.depleted and 0 or math.max(1,math.ceil((n.hp or 1)/math.max(1,oldMax)*12));n.hp=math.min(12,n.hp);changed=changed+1 end
   end
  end
 end
 if changed>0 then require('game.node_index').invalidate(w);require('game.navigation').refresh(w)end
 return changed
end
return P
