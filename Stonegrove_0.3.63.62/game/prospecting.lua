local P={}
local names={copper='Copper',iron='Iron',tin='Tin',coal='Coal'}
function P.isOre(n) return n and names[n.kind]~=nil end
function P.autoLevel(n) return ({copper=15,iron=27})[n.kind] end
function P.canAuto(n,skills) local lv=P.autoLevel(n);return lv and skills:get('Prospecting').level>=lv end
function P.identify(w,n,player,skills,logger,quiet)
 if n.prospected then return false end
 n.prospected=true;skills:addXP('Prospecting',20)
 if not quiet then w:addPopup(player.x,player.y-24,'Identified: '..names[n.kind]..' ore') end
 if logger then logger:log('ORE_PROSPECTED',{ore=n.kind,skill='Prospecting',baseXP=20}) end
 return true
end
P.AREA_RADIUS=96
function P.duration(level) return math.max(.65,5/(1+.06*(math.max(1,level)-1))) end
function P.nodeAt(w,x,y)
 local best,dist=nil,18^2
 for _,n in ipairs(require("game.node_index").at(w,x,y)) do if P.isOre(n) then local d=(x-n.x)^2+(y-n.y)^2;if d<dist then best,dist=n,d end end end
 return best
end
function P.tooltip(ui,n)
 local H=require('game.help');local status=n.prospected and 'Prospected: Yes.' or 'Prospected: No.'
 local title=n.prospected and (names[n.kind]..' Ore') or 'Unidentified Ore'
 local body=status..' '
 if n.depleted then body=body..'Depleted. Wait for the rock to replenish. ' end
 if not n.prospected then body=body..'Left-click attempts automatic identification if your Prospecting level qualifies. '..string.format('Right-click to approach, prospect nearby ore in a 96px area, then mine (%.1fs). Prospect before mining. No tool or level required.',P.duration(ui.skills:get('Prospecting').level))
 elseif not n.depleted then local d=ui.world:resourceInfo(n.kind);body=body..'Contains '..names[n.kind]..'. Left-click to mine. Requires '..d.tool..' and Mining '..(d.level or 1)..'.' end
 return H.tip(title,body)
end
function P.start(ui,n)
 local w,p=ui.world,ui.player
 local function fail(msg) w:addPopup(p.x,p.y-24,msg);return false,msg end
 if not P.isOre(n) then return false,'Not ore' end
 if n.prospected then return fail('Already prospected: '..names[n.kind]) end
 if (p.x-n.x)^2+(p.y-n.y)^2>40^2 then return fail('Move closer to prospect') end
 if ui.craftJob or ui.magicCast or w.workJob then return fail('Finish your current action first') end
 if (p.hp or 1)<=0 or w.combatTarget or require('game.animation').playerCombat(w,p) then return fail('Cannot prospect in combat') end
 w:stopGather('prospecting',ui.logger);w.fishing=nil
 ui.craftJob={name='Prospecting ore',prospecting=true,timer=0,duration=P.duration(ui.skills:get('Prospecting').level),x=p.x,y=p.y,
 validate=function() return (p.hp or 1)>0 and not w.combatTarget and not require('game.animation').playerCombat(w,p) end,
 finish=function()
  local count=0
  for _,other in ipairs(w.nodes) do
   if P.isOre(other) and not other.prospected and (other.x-n.x)^2+(other.y-n.y)^2<=P.AREA_RADIUS^2 then
    if P.identify(w,other,p,ui.skills,ui.logger,true) then count=count+1 end
   end
  end
  if count>0 then w:addPopup(p.x,p.y-24,'Prospected '..count..' ore node'..(count==1 and '' or 's')) end
  if ui.logger then ui.logger:log('PROSPECTING_AREA_COMPLETE',{nodes=count,radius=P.AREA_RADIUS}) end
 end}
 return true
end
-- Match knowledge to the same ore and position, never to a different random node.
function P.save(w)
 local out={};for _,n in ipairs(w.nodes) do if P.isOre(n) and n.prospected then out[n.kind..':'..n.x..':'..n.y]=n.resourceCycle or 0 end end;return out
end
function P.load(w,known)
 if type(known)~='table' then return end
 for _,n in ipairs(w.nodes) do if P.isOre(n) then local v=known[n.kind..':'..n.x..':'..n.y];n.prospected=(v==true and(n.resourceCycle or 0)==0)or(type(v)=='number'and v==(n.resourceCycle or 0)) end end
end
return P
