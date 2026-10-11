local U={};local G=require('game.gravestones')
local function actor(u)local p=require('game.profile').active;u.campOwner=p and(tostring(p.id)..':'..p.slot)or'offline';u.sockets=u.equipmentSockets;return u end
local function command(u,op,g)
 if require('game.multiplayer').active then return require('game.multiplayer').command({kind='grave',op=op,target=g.id})end
 return G.start(u.world,actor(u),op,g.id)
end
function U.install(UI)
 local F=require('game.fieldcraft_ui');local create=UI.new;UI.new=function(...)local u=create(...);u.world.graveActor=actor(u);U.current=u;return u end;local World=require("game.world");local combat=World.updateCombat;World.updateCombat=function(w,dt,p,...)if U.current and U.current.player==p and not require("game.multiplayer").active then w.graveActor=actor(U.current)end;return combat(w,dt,p,...)end;local H=require('game.help');local help=H.world
 H.world=function(u,x,y)local g=G.at(u.world,x,y);if not g then return help(u,x,y)end
  local remaining=math.max(0,math.ceil(g.remaining or 0));local status=g.broken and'Broken'or g.recovered and'Recovered'or(g.blessingLevel or 0)>0 and'Blessed'or'Unblessed'
  return H.tip((g.playerName or'Adventurer').."'s Grave",g.name..' • '..status..'\nKilled by '..(g.cause or'Unknown cause')..'\nGravestone HP: '..math.ceil(g.hp or 0)..' / '..g.maxHp..'\nTime remaining: '..math.floor(remaining/60)..'m '..(remaining%60)..'s\nBlessing strength: Religion '..(g.blessingLevel or 0)..'\nBlessed by: '..(g.blessedBy or'Nobody')..'\n'..((g.broken or g.recovered)and'Grave history preserved.'or'Contents protected. Owner: left-click Recover. Right-click Bless.'))
 end
 local update=F.update;F.update=function(u,...)
  update(u,...);local w=u.world;w.graveActor=actor(u);local now=love.timer.getTime();local dt=math.max(0,math.min(.2,now-(u.graveLastUpdate or now)));u.graveLastUpdate=now
  if not require('game.multiplayer').active then if u.player.graveDeathPending then u.player.graveDeathPending=nil;u.graveEpoch=(u.graveEpoch or 0)+1;if w.isCave and w.deathRespawn then u.graveSaveAfterCave=true else require('game.save').write(u.player,u.inv,u.skills,u,u.logger)end end;G.update(w,dt);G.enemyAttacks(w,dt);local ok,reason=G.tickCast(w,u,dt);if ok~=nil then w:addPopup(u.player.x,u.player.y-24,reason,ok and'heal'or'miss');if ok then require('game.save').write(u.player,u.inv,u.skills,u,u.logger)end end end
 end
 local Cave=require("game.caves");local leave=Cave.leave;Cave.leave=function(u)local w=leave(u);if u.graveSaveAfterCave then u.graveSaveAfterCave=nil;require("game.save").write(u.player,u.inv,u.skills,u,u.logger)end;return w end
 local drawables=F.drawables;F.drawables=function(u,camera,add)
  drawables(u,camera,add);u.graveImages=u.graveImages or{};local images=u.graveImages
  for _,g in ipairs(u.world.gravestones or{})do local grave=g;local t=G.type(grave.typeLevel);if t then
   add(grave.y+8,function()
    local index=(grave.broken or grave.recovered)and t.broken or t.intact;local animated=(grave.blessAnimation or 0)>0;if animated then index=t.animation end
    if not images[index]then images[index]=love.graphics.newImage('assets/grave'..index..'.png');images[index]:setFilter('nearest','nearest')end
    love.graphics.setColor(1,1,1);if animated then local frame=math.min(3,math.floor((.8-grave.blessAnimation)/.2));local q=love.graphics.newQuad(frame*16,0,16,16,64,16);love.graphics.draw(images[index],q,grave.x-8,grave.y-8)else love.graphics.draw(images[index],grave.x-8,grave.y-8)end
   end,grave.x)
  end end
 end
 local click=F.worldClick;F.worldClick=function(u,camera,x,y,button)
  if u.graveContext then local c=u.graveContext;u.graveContext=nil;if button==1 and x>=c.x and x<=c.x+120 and y>=c.y and y<=c.y+28 then local ok,why=command(u,'bless',c.grave);if not ok then u.world:addPopup(u.player.x,u.player.y-24,why,'miss')end end;return true end
  local sw,sh=love.graphics.getDimensions();local wx,wy=camera:toWorld(x,y,sw,sh);local g=G.at(u.world,wx,wy)
  if g then if g.broken or g.recovered then return true end;if button==2 then u.graveContext={x=math.min(x,sw-125),y=math.min(y,sh-32),grave=g}else local ok,why=command(u,'recover',g);if not ok then u.world:addPopup(u.player.x,u.player.y-24,why,'miss')end end;return true end
  return click(u,camera,x,y,button)
 end
 local draw=UI.draw;UI.draw=function(u,...)
  draw(u,...);local g=love.graphics;if u.graveContext then local c=u.graveContext;g.setColor(.06,.07,.06,.95);g.rectangle('fill',c.x,c.y,120,28);g.setColor(1,1,1);g.print('Bless grave',c.x+7,c.y+6)end
  local c=u.graveCast;if c then local sw,sh=g.getDimensions();local progress=math.min(1,((c.timer or 0)+(c.receivedAt and math.max(0,love.timer.getTime()-c.receivedAt)or 0))/G.castTime);g.setColor(.05,.07,.05,.95);g.rectangle('fill',sw/2-100,sh*.65,200,24);g.setColor(.5,.7,.95);g.rectangle('fill',sw/2-98,sh*.65+2,196*progress,20);g.setColor(1,1,1);g.printf(c.op=='bless'and'Blessing grave'or'Recovering belongings',sw/2-98,sh*.65+4,196,'center')end;g.setColor(1,1,1)
 end
end
return U

