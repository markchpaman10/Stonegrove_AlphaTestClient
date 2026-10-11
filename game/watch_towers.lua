local T={}
local function load()
 if T.roof then return end
 T.roof=love.graphics.newImage('assets/tower_roof.png')
 T.open=love.graphics.newImage('assets/tower_open.png')
 T.tiles=love.graphics.newImage('assets/tower_tiles.png')
 T.roof:setFilter('nearest','nearest');T.open:setFilter('nearest','nearest');T.tiles:setFilter('nearest','nearest')
 T.ladder=love.graphics.newQuad(38,35,10,29,T.tiles:getDimensions())
 T.lower=love.graphics.newQuad(0,16,32,32,32,48)
 T.top=love.graphics.newQuad(0,0,32,16,32,48)
end
function T.draw(world,addDrawable)
 load()
 for _,v in ipairs(world.watchTowers or {}) do
  local t=v;local im=t.roof and T.roof or T.open
  -- Lower supports sort normally with actors.
  addDrawable(t.y+8,function()
   love.graphics.setColor(1,1,1)
   love.graphics.draw(im,T.lower,t.x-16,t.y-8)
   if t.ladder then love.graphics.draw(T.tiles,T.ladder,t.x+5,t.y-20) end
  end,t.x)
  -- The upper platform/roof deliberately sorts above characters near the tower.
  addDrawable(t.y+32,function()
   love.graphics.setColor(1,1,1)
   love.graphics.draw(im,T.top,t.x-16,t.y-24)
  end,t.x)
 end
end
return T
