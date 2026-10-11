local R={}
function R.draw(w)
 if not w.authoredPathBatches then
  w.authoredPathBatches={}
  for _,style in ipairs({'dirt','gravel'})do
   local image=love.graphics.newImage('assets/'..style..'_path_autotile.png');image:setFilter('nearest','nearest')
   local cells={};local function key(x,y)return x..':'..y end
   for _,p in ipairs(w.map.authored.paths or {})do if (p.style or 'dirt')==style then cells[key(p.x/16,p.y/16)]={x=p.x/16,y=p.y/16}end end
   local batch=love.graphics.newSpriteBatch(image,1000,'static');local quads={}
   for y=0,2 do for x=0,2 do quads[y*3+x]=love.graphics.newQuad(96+x*16,y*16,16,16,image:getDimensions())end end
   for _,c in pairs(cells)do local x,y=c.x,c.y;local col=not cells[key(x-1,y)]and 0 or not cells[key(x+1,y)]and 2 or 1;local row=not cells[key(x,y-1)]and 0 or not cells[key(x,y+1)]and 2 or 1;batch:add(quads[row*3+col],x*16,y*16)end
   w.authoredPathBatches[#w.authoredPathBatches+1]=batch
  end
 end
 love.graphics.setColor(1,1,1);for _,b in ipairs(w.authoredPathBatches)do love.graphics.draw(b)end
end
return R
