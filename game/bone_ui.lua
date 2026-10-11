local U={};local B=require('game.bone_religion')
function U.install(UI)
 local context=UI.contextOptions;UI.contextOptions=function(u,it)
  local rows=context(u,it);if B.piles[it.name]then table.insert(rows,1,(it.qty or 1)>1 and'Separate Bone Pile Stack'or'Separate Bone Pile')elseif B.parts[B.base(it.name)]then table.insert(rows,1,'Bury Bone');if B.cursed(it.name)and not it.blessed then table.insert(rows,1,'Bless Cursed Bones')end end;return rows
 end
 local use=UI.doContextOption;UI.doContextOption=function(u,opt)
  local ops={['Separate Bone Pile Stack']='boneSeparate',['Separate Bone Pile']='boneSeparate',['Bury Bone']='boneBury',['Bless Cursed Bones']='boneBless'}
  if not ops[opt]then return use(u,opt)end;local c=u.context;u.context=nil;if not c then return false end
  return require('game.fieldcraft_ui').command(u,{op=ops[opt],bag=c.bag,slot=c.slot})
 end
 local tooltip=UI.drawTooltip;UI.drawTooltip=function(u,it,x,y,w,h,override)
  if B.is(it.name)then local info={};for k,v in pairs(override or u.sprites.itemInfo[it.name]or{})do info[k]=v end
   local p=require('game.profile').active;local owner=p and tostring(p.id)..':'..p.slot or'offline';info.detail=(info.detail or'')..'\n'..(it.boneOwner==owner and'Your credited kill.'or'Not your kill: no blessing or burial XP.')..(it.blessed and' Blessed.'or'');override=info
  end;return tooltip(u,it,x,y,w,h,override)
 end
 local F=require('game.fieldcraft_ui');local drawables=F.drawables;F.drawables=function(u,camera,add)
  drawables(u,camera,add);u.burialImage=u.burialImage or love.graphics.newImage('assets/grave5.png');u.burialImage:setFilter('nearest','nearest')
  for _,v in ipairs(u.world.burialGraves or{})do local g=v;add(g.y+8,function()love.graphics.setColor(g.blessed and .8 or 1,1,g.blessed and .65 or 1);love.graphics.draw(u.burialImage,g.x-8,g.y-8);love.graphics.setColor(1,1,1)end,g.x)end
 end
 local help=require('game.help');local previousHelp=help.world;help.world=function(u,x,y)
  for _,g in ipairs(u.world.burialGraves or{})do if(x-g.x)^2+(y-g.y)^2<14^2 then return help.tip((g.playerName or'Adventurer').."'s Burial Marker",g.bone..'\nTime remaining: '..math.ceil(g.remaining)..'s\nOwner Religion at burial: '..g.ownerLevel..'\n'..(g.blessed and'Blessed by '..(g.blessedBy or'Unknown')or'Right-click to bless once for 3 base Religion XP.')..'\nFive nearby markers create hallowed ground (up to 2× Religion XP at average level 50).')end end
  return previousHelp(u,x,y)
 end
 local click=F.worldClick;F.worldClick=function(u,camera,x,y,button)
  if u.burialContext then local c=u.burialContext;u.burialContext=nil;if button==1 and x>=c.x and x<=c.x+140 and y>=c.y and y<=c.y+28 then return F.command(u,{op='boneGraveBless',id=c.id})end;return true end
  local sw,sh=love.graphics.getDimensions();local wx,wy=camera:toWorld(x,y,sw,sh)
  for _,g in ipairs(u.world.burialGraves or{})do if(wx-g.x)^2+(wy-g.y)^2<14^2 then if button==2 then u.burialContext={x=math.min(x,sw-145),y=math.min(y,sh-32),id=g.id}end;return true end end
  return click(u,camera,x,y,button)
 end
 local draw=UI.draw;UI.draw=function(u,...)draw(u,...);local factor=B.factor(u.world,u.player);if factor>1 then love.graphics.setColor(.85,.9,.6);love.graphics.printf(string.format('HALLOWED GROUND   Religion XP ×%.2f',factor),love.graphics.getWidth()/2-220,90,440,'center');love.graphics.setColor(1,1,1)end;if u.burialContext then local c=u.burialContext;love.graphics.setColor(.06,.07,.06,.95);love.graphics.rectangle('fill',c.x,c.y,140,28);love.graphics.setColor(1,1,1);love.graphics.print('Bless burial marker',c.x+7,c.y+6)end end
end
return U
