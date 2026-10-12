local P={slots={head='Head Armor',body='Body Armor',legs='Foot Armor',cape='Cape',weapon='Weapon',offhand='Offhand'}}
function P.safe(path) return type(path)=='string' and path:match('^assets/imported/[%w_%-]+%.png$')~=nil end
function P.load(s,d,root)
 if not d.spritePath or d.spritePath=='' then return end
 assert(P.safe(d.spritePath),'Paper doll must be an imported project PNG')
 s.paperDolls=s.paperDolls or {};s._paperCache=s._paperCache or {}
 local fw,fh=tonumber(d.frameWidth)or 16,tonumber(d.frameHeight)or 16
 local key=d.spritePath..':'..fw..':'..fh;local doll=s._paperCache[key]
 if not doll then
  local source=d.spritePath;if root then local f=assert(io.open(root..'/'..source,'rb'));source=love.filesystem.newFileData(f:read('*a'),d.spritePath);f:close() end
  local image=love.graphics.newImage(source);image:setFilter('nearest','nearest');local iw,ih=image:getDimensions();assert(iw>=fw*4 and ih>=fh*3,'Sheet needs 4 columns and 3 rows')
  doll={image=image,frames={},w=fw,h=fh};for row,dir in ipairs({'up','right','down'})do doll.frames[dir]={};for col=1,4 do doll.frames[dir][col]=love.graphics.newQuad((col-1)*fw,(row-1)*fh,fw,fh,iw,ih)end end;s._paperCache[key]=doll
 end
 s.paperDolls[d.id]={doll=doll,slot=d.equipSlot,ax=tonumber(d.anchorX)or fw/2,ay=tonumber(d.anchorY)or fh/2}
 s.itemImages[d.id]=doll.image;s.itemQuads[d.id]=doll.frames.down[1]
end
function P.draw(s,name,x,y,dir,frame,race)
 local p=s.paperDolls and s.paperDolls[name];if not p then return false end
 frame=frame or 1;dir=dir or'down';local key=dir=='left'and'right'or dir;local offset,sy=require('game.humanoid').metrics(race,p.slot=='head'and'head'or'body')
 local ay=p.footSlot and(8-(frame%2==0 and 13 or 14))or p.ay
 love.graphics.setColor(1,1,1);love.graphics.draw(p.doll.image,p.doll.frames[key][frame or 1],x,y+offset,0,dir=='left'and-1 or 1,sy,p.ax,ay);return true
end
function P.gear(s,name,x,y,dir,frame,race)
 if not name or name==''then return false end;if P.draw(s,name,x,y,dir,frame,race)then return true end
 if name=='Cape'then local key=dir=='left'and'right'or dir;require('game.humanoid').draw(s.capeImage,s.cape[key][frame or 1],x,y,dir=='left'and-1 or 1,race,'body');return true end
 if require('game.iron_gear').draw(s,name,x,y,dir,frame,race)then return true end
 for _,set in ipairs({'Copper','Leather','Wizard'})do local body=set=='Wizard'and'Wizard Robes'or set..' Armor';local head=set=='Wizard'and'Wizard Hat'or set..' Helm';local part=name==body and'body'or name==head and'helm'
  if part then local key=dir=='left'and'right'or dir;require('game.humanoid').draw(s['armor'..set..'Image'],s['armor'..set][part][key][frame or 1],x,y,dir=='left'and-1 or 1,race,part=='helm'and'head'or'body');return true end
 end
 return false
end
function P.held(s,name,x,y,dir,side,frame,race)
 if not name then return end;if P.draw(s,name,x,y,dir,frame or 1,race)then return end
 local image=s.itemImages[name];if not image then return end;local q=s.itemQuads[name];love.graphics.setColor(1,1,1)
 if q then love.graphics.draw(image,q,x+side*(dir=='left'and-1 or 1)*6,y+2,0,.65,.65,8,8)else local iw,ih=image:getDimensions();love.graphics.draw(image,x+side*(dir=='left'and-1 or 1)*6,y+2,0,.65,.65,iw/2,ih/2)end
end
return P
