local D={open=false,scroll=0}
local function node()for _,n in ipairs(D.graph and D.graph.nodes or{})do if n.id==D.node then return n end end end
local function responses()local out={};for _,r in ipairs((node()or{}).responses or{})do if require('game.content_rules').allowed(r.rule,D.ui and D.ui.skills,D.ui and D.ui.player)then out[#out+1]=r end end;return out end
function D.show(npc,context,quest)D.npc=npc;D.ui=context or ui;D.graph=require('game.content_rules').dialogue(npc,quest);D.node=D.graph and D.graph.start;D.open=true;D.scroll=0 end
function D.key(key)if not D.open then return false end;if key=='escape'then D.open=false elseif key=='return'and not D.graph then D.open=false end;return true end
function D.click(x,y,b)if not D.open then return false end;if b~=1 then return true end;for _,r in ipairs(D.buttons or{})do if x>=r.x and x<r.x+r.w and y>=r.y and y<r.y+r.h then if r.next and r.next~=''then D.node=r.next;D.scroll=0 else D.open=false end;return true end end;return true end
function D.wheel(delta)if not D.open then return false end;D.scroll=math.max(0,D.scroll-delta*25);return true end
function D.draw()
 if not D.open then return end;if D.ui and D.ui.player and(D.npc.x-D.ui.player.x)^2+(D.npc.y-D.ui.player.y)^2>90^2 then D.open=false;return end
 love.graphics.push('all');local w,h=love.graphics.getDimensions();local x,y=w/2-300,h/2-230;local g=love.graphics
 g.setColor(0,0,0,.65);g.rectangle('fill',0,0,w,h);g.setColor(.07,.07,.05,.99);g.rectangle('fill',x,y,600,460,6,6);g.setColor(1,.85,.55);g.print(D.npc.name..' — '..(D.npc.role or'Citizen'),x+20,y+18)
 local text=(node()or{}).text or D.npc.dialogue or'';local _,lines=g.getFont():getWrap(text,560);D.scroll=math.min(D.scroll,math.max(0,#lines*g.getFont():getHeight()-200));g.setScissor(x+18,y+52,564,200);g.setColor(1,1,1);g.printf(text,x+20,y+52-D.scroll,560,'left');g.setScissor();D.buttons={}
 local choices=responses();for i,r in ipairs(choices)do if i<=4 then local b={x=x+20,y=y+266+(i-1)*36,w=560,h=32,next=r.next};D.buttons[#D.buttons+1]=b;g.setColor(.18,.25,.22);g.rectangle('fill',b.x,b.y,b.w,b.h,4);g.setColor(1,1,1);g.printf(r.text,b.x+8,b.y+8,b.w-16,'left')end end
 local b={x=x+20,y=y+416,w=560,h=28};D.buttons[#D.buttons+1]=b;g.setColor(1,.85,.55);g.print('Close (Escape)',b.x,b.y+5);g.pop()
end
D.responses=responses;D.currentNode=node
return D
