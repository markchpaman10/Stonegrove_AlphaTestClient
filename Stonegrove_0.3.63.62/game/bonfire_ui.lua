-- One completed cast adds one log. Repeating uses the existing skill cast bar.
local B={castSeconds=2}
function B.start(ui,fuel,continuing)
 local w,p=ui.world,ui.player
 if ui.skills:get('Firemaking').level<10 then return false,'Firemaking level 10 required'end
 if ui.craftJob or ui.magicCast or w.workJob then return false,'busy' end
 require('game.fire_fuel').realtime(w,p,ui.logger)
 local fire=continuing or w:bonfireNear(p)
 if not fire then return false,'no_bonfire_near' end
 if fuel~='Pine Logs' and fuel~='Oak Logs' and fuel~='Logs'and fuel~='Poplar Logs'then return false,'invalid_fuel'end
 if fuel=='Oak Logs' and ui.skills:get('Firemaking').level<11 then return false,'Firemaking level 11 required'end
 if ui.inv:countItem(fuel)<1 then return false,'missing_logs'end
 if not continuing then
  w:stopGather('bonfire_refuel',ui.logger);w.fishing=nil;w:stopCombat('bonfire_refuel',ui.logger)
 end
 local function valid()
  if ui.world~=w or ui.magicCast or w.workJob or w.gather or w.fishing or w.combatTarget or p.hp<=0 or ui.inv:countItem(fuel)<1 then return false end
  if (fire.x-p.x)^2+(fire.y-p.y)^2>75^2 then return false end
  for _,f in ipairs(w.campfires)do if f==fire then return true end end
  return false
 end
 if not valid()then return false,'no_bonfire_near'end
 if require('game.multiplayer').active then return require('game.fieldcraft_ui').command(ui,{op='fireRefuel',fuel=fuel,fireId=fire.netId},function(ok)if ok and ui.world==w then B.start(ui,fuel)end end)end
 local completed=false
 ui.craftJob={name='Adding '..fuel..' to Bonfire',timer=0,duration=B.castSeconds,x=p.x,y=p.y,
  bonfireRefuel=true,validate=valid,finish=function()
   if completed or not valid()then return end;completed=true
   local ok,why=w:addBonfireLog(p,ui.inv,ui.skills,ui.logger,fuel,fire)
   if ok then B.start(ui,fuel,fire)
   else w:addPopup(p.x,p.y-22,tostring(why),'miss')end
  end}
 if not continuing then ui:log('BONFIRE_REFUEL_STARTED',{fuel=fuel,castSeconds=B.castSeconds})end
 return true,'bonfire_refuel_started'
end
function B.drawBuff(ui,x,y,w,h)
 ui.bonfireBuffRect=nil
 if not require('game.bonfire_buff').active(ui.player)then return end
 local remaining=math.max(0,ui.player.bonfireBuffUntil-require('game.fire_fuel').now())
 x=math.max(4,math.min(w-126,x));y=math.max(4,math.min(h-38,y))
 ui.bonfireBuffRect={x=x,y=y,w=122,h=34}
 local g=love.graphics
 g.setColor(.055,.035,.018,.96);g.rectangle('fill',x,y,122,34,5,5)
 g.setColor(1,.64,.16);g.rectangle('line',x,y,122,34,5,5)
 -- Static flame emblem avoids loading another sheet or animating a HUD icon.
 g.setColor(1,.39,.08);g.polygon('fill',x+7,y+25,x+5,y+17,x+12,y+5,x+13,y+14,x+19,y+10,x+24,y+23,x+18,y+28,x+11,y+28)
 g.setColor(1,.85,.29);g.polygon('fill',x+11,y+25,x+13,y+17,x+19,y+26)
 g.setColor(1,.89,.66);g.print('Bonfire +20%',x+30,y+2)
 g.setColor(.9,.8,.65);g.print(string.format('%d:%02d',math.floor(remaining/60),math.floor(remaining%60)),x+30,y+17)
 local mx,my=love.mouse.getPosition()
 if mx>=x and mx<x+122 and my>=y and my<y+34 then
  ui:drawTooltip({name='Bonfire Bonus'},mx,my,w,h,{title='Bonfire Bonus',type='Active buff',detail='+20% maximum Health and Defence for 5 minutes, even after leaving the fire.\nBuff remaining: '..math.ceil(remaining)..' seconds. Add a log to refresh.'})
 end
 g.setColor(1,1,1)
end
function B.hover(ui,x,y)
 local r=ui.bonfireBuffRect
 return r and require('game.bonfire_buff').active(ui.player) and x>=r.x and x<r.x+r.w and y>=r.y and y<r.y+r.h
end
function B.install(UI)
 local pressed,pointer,help=UI.mousepressed,UI.pointerOverUI,UI.drawHelp
 function UI:mousepressed(x,y,...)
  if B.hover(self,x,y)then return true end
  return pressed(self,x,y,...)
 end
 function UI:pointerOverUI(x,y,...)
  if B.hover(self,x,y)then return true end
  return pointer(self,x,y,...)
 end
 function UI:drawHelp(...)
  local x,y=love.mouse.getPosition();if B.hover(self,x,y)then return end
  return help(self,...)
 end
end
return B
