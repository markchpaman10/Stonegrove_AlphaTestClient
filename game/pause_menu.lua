local M={open=false,help=false}
local actions={'Resume','Help','Unstuck','Options','Exit to Launcher'}
local function rowTop(y,i)return i==#actions and y+410 or y+58+(i-1)*58 end
function M.layout() local w,h=love.graphics.getDimensions();return (w-620)/2,(h-460)/2 end
function M.key(k) if k=='escape' then if M.help then M.help=false else M.open=not M.open end;return true end;return M.open end
function M.click(x,y,button,ui)
 if not M.open then return false end;if button~=1 then return true end
 local ox,oy=M.layout();if M.help then if x>=ox+20 and x<=ox+150 and y>=oy+410 and y<=oy+446 then M.help=false end;return true end
 for i,name in ipairs(actions) do local top=rowTop(oy,i);if x>=ox+24 and x<=ox+596 and y>=top and y<=top+44 then
  if name=='Options' then require('game.options_menu').show() elseif name=='Help' then M.help=true elseif name=='Resume'then M.open=false;M.help=false elseif name=='Exit to Launcher'then M.open=false;M.help=false;local L=require('game.launcher');if L.screen=='game'and not L.offline then L.returnSlots()else love.event.quit()end elseif name=='Unstuck' then ui.world:unstuckPlayer(ui.player,ui.logger);M.open=false end
  return true
 end end;return true
end
function M.draw()
 if not M.open then return end;local x,y=M.layout();local w,h=love.graphics.getDimensions()
 love.graphics.setColor(0,0,0,.65);love.graphics.rectangle('fill',0,0,w,h);love.graphics.setColor(.08,.075,.055,.99);love.graphics.rectangle('fill',x,y,620,460,8,8);love.graphics.setColor(1,.85,.55);love.graphics.print(M.help and 'Help / Controls' or 'Paused',x+24,y+20)
 if M.help then
  love.graphics.setColor(1,1,1);love.graphics.printf('WASD: move   Shift: sprint   Mouse wheel: scroll lists\nHold middle mouse: camera look\nI: inventory   E: equipment   K: skills   M: mercenaries   U: unstuck\nLeft-click resources: gather. Walk away to cancel.\nLeft-click enemies: engage. Mercenaries assist in your fights.\nClick a villager or station to trade, recruit or craft.\nClick the bank chest to store items; drag bank items to sort.\nRight-click bag items for use, equipment and trading actions.\nF1-F4: potions\nCtrl + drag the minimap to move it.\nDrag panel borders/corners to resize windows.\n\nMercenaries start at level 1 and gain combat XP.\nTank: Taunt (1), Shield Bash (5), area Taunt (10).\nRanger: Double Shot (5), Triple Shot (15), 8s cooldown.\nHealer: First Aid (1), Healing Pulse (Magic 5).\nHealer attacks: Water (1), Earth (2), Air (3), Fire (10).\nGive ranged mercenaries a bow and arrows through their menu.',x+24,y+56,572,'left')
  love.graphics.rectangle('line',x+20,y+410,130,36);love.graphics.print('Back',x+64,y+420)
 else for i,name in ipairs(actions) do local top=rowTop(y,i);love.graphics.setColor(.65,.54,.35);love.graphics.rectangle('line',x+24,top,572,44,4,4);love.graphics.setColor(1,1,1);love.graphics.printf(name,x+24,top+14,572,'center') end end
end
return M
