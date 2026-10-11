local D={open=false,scroll=0}
function D.show(npc)D.npc=npc;D.open=true;D.scroll=0 end
function D.key(key)if not D.open then return false end;if key=='escape'or key=='return'then D.open=false end;return true end
function D.click(x,y,b)if not D.open then return false end;local w,h=love.graphics.getDimensions();if b==1 and x>w/2+220 and y>h/2+100 then D.open=false end;return true end
function D.wheel(delta)if not D.open then return false end;D.scroll=math.max(0,D.scroll-delta*25);return true end
function D.draw()
 if not D.open then return end;love.graphics.push('all');local w,h=love.graphics.getDimensions();local x,y=w/2-300,h/2-160
 love.graphics.setColor(0,0,0,.65);love.graphics.rectangle('fill',0,0,w,h);love.graphics.setColor(.07,.07,.05,.99);love.graphics.rectangle('fill',x,y,600,320,6,6);love.graphics.setColor(1,.85,.55);love.graphics.print(D.npc.name..' — '..(D.npc.role or'Citizen'),x+20,y+18)
 local _,lines=love.graphics.getFont():getWrap(D.npc.dialogue or'',560);local textHeight=#lines*love.graphics.getFont():getHeight();D.scroll=math.min(D.scroll,math.max(0,textHeight-210));love.graphics.setScissor(x+18,y+52,564,210);love.graphics.setColor(1,1,1);love.graphics.printf(D.npc.dialogue or'',x+20,y+52-D.scroll,560,'left');love.graphics.setScissor();love.graphics.print('Escape: close     Wheel: scroll',x+20,y+286);love.graphics.print('Close',x+525,y+286);love.graphics.pop()
end
return D
