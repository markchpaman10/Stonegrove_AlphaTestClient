local M={}
function M.clean(w)
 local fences=require('game.fences');local houses=require('game.houses');local removed=0
 for i=#w.nodes,1,-1 do local n=w.nodes[i];local bad=false
  for _,h in ipairs(w.houses or{})do local x,y,width,height=houses.bounds(h);if n.x+10>x and n.x-10<x+width and n.y+12>y and n.y-10<y+height then bad=true;break end end
  if not bad then for _,o in ipairs({{0,0},{-8,0},{8,0},{0,-8},{0,8}})do if fences.blocked(w,n.x+o[1],n.y+o[2])then bad=true;break end end end
  if bad then table.remove(w.nodes,i);removed=removed+1 end
 end
 if removed>0 then require('game.node_index').invalidate(w);require('game.navigation').refresh(w)end
 return removed
end
return M
