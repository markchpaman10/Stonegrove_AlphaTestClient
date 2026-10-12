local R={}
function R.draw(world)
 if world.map.authored then return require('game.authored_paths').draw(world) end
 if not R.image then
  local d=love.image.newImageData('assets/paths_tileset.png');d:mapPixel(function(x,y,r,g,b,a) if math.abs(r-62/255)<.001 and math.abs(g-137/255)<.001 and math.abs(b-72/255)<.001 then return r,g,b,0 end;return r,g,b,a end)
  R.image=love.graphics.newImage(d);R.image:setFilter('nearest','nearest');R.quads={}
  for y=0,2 do for x=0,2 do R.quads[y*3+x]=love.graphics.newQuad(96+x*16,y*16,16,16,d:getDimensions()) end end
 end
 if not world.pathBatch then
  local cells={};local function key(x,y)return x..':'..y end
  for _,r in ipairs(world.paths) do for y=math.floor(r.y/16),math.ceil((r.y+r.h)/16)-1 do for x=math.floor(r.x/16),math.ceil((r.x+r.w)/16)-1 do cells[key(x,y)]={x=x,y=y} end end end
  local batch=love.graphics.newSpriteBatch(R.image,10000,'static')
  for _,c in pairs(cells) do local x,y=c.x,c.y;local left=cells[key(x-1,y)];local right=cells[key(x+1,y)];local up=cells[key(x,y-1)];local down=cells[key(x,y+1)]
   local col=not left and 0 or not right and 2 or 1;local row=not up and 0 or not down and 2 or 1
   batch:add(R.quads[row*3+col],x*16,y*16)
  end
  world.pathBatch=batch
 end
 love.graphics.setColor(1,1,1);love.graphics.draw(world.pathBatch)
end
return R

