local Houses={}
local Modular=require("game.modular_houses")
local groundWindows={{19,35},{19,35},{3,18},{3,37}}
local doorOffsets={6,6,36,27}

function Houses.addWindows(house,rng)
 house.windows={}
 local function add(floor,x)
  house.windows[#house.windows+1]={floor=floor,x=x,variant=rng:random(1,6)}
 end
 local candidates={}
 for _,x in ipairs(groundWindows[house.ground]) do
  -- Pillar posts occupy these ground-floor columns; don't hide a window behind them.
  local behindPost=house.upper==3 and ((x+3<31 and x+14>27) or (x+3<54 and x+14>50))
  if not behindPost then candidates[#candidates+1]=x end
 end
 for _,x in ipairs(candidates) do if rng:random()<.75 then add(1,x) end end
 if #house.windows==0 and #candidates>0 then add(1,candidates[rng:random(1,#candidates)]) end
 if house.upper then
  local positions=house.upper==3 and {4,22,40} or {3,19,35}
  local count=#house.windows
  for _,x in ipairs(positions) do if rng:random()<.65 then add(2,x) end end
  if #house.windows==count then add(2,positions[rng:random(1,#positions)]) end
 end
end

function Houses.load()
 local image=love.graphics.newImage('assets/houses.png')
 image:setFilter('nearest','nearest')
 local function part(x,y,w,h)
  return {quad=love.graphics.newQuad(x,y,w,h,image:getDimensions()),w=w,h=h}
 end
 local windows=love.graphics.newImage('assets/house_windows.png')
 windows:setFilter('nearest','nearest')
 local windowQuads={}
 for i=1,6 do windowQuads[i]=love.graphics.newQuad((i-1)*16,0,16,16,windows:getDimensions()) end
 local doors=love.graphics.newImage('assets/house_doors.png')
 doors:setFilter('nearest','nearest')
 local doorQuads={}
 -- Door art is offset differently within the last two cells. Crop to the
 -- painted 11x14 door so each style fits inside the existing frame exactly.
 for i=1,4 do doorQuads[i]=love.graphics.newQuad((i-1)*16+(i<=2 and 2 or 3),2,11,14,doors:getDimensions()) end
 return {modular=Modular.load(),image=image,windows=windows,windowQuads=windowQuads,doors=doors,doorQuads=doorQuads,
  ground={part(0,0,53,16),part(0,16,53,16),part(0,32,53,16),part(0,48,53,16)},
  upper={part(0,64,53,16),part(0,80,53,16),part(144,0,60,32)},
  roofs={part(79,5,49,11),part(73,21,55,11)}}
end

-- A local generator avoids changing combat or resource random sequences.
-- Lot positions stay anchored to the existing workshop roads.
function Houses.generate(lots,seed)
 local rng=love.math.newRandomGenerator(seed)
 local windowRng=love.math.newRandomGenerator(seed+7919)
 local doorRng=love.math.newRandomGenerator(seed+15401)
 for _,house in ipairs(lots) do
  if Modular.is(house) then Modular.configure(house) else
  house.ground=rng:random(1,4)
  house.upper=rng:random()<.6 and rng:random(1,3) or nil
  house.roof=house.upper==3 and 2 or 1
  house.story=house.upper~=nil
  Houses.addWindows(house,windowRng)
  house.door=doorRng:random(1,4)
  end
 end
end

function Houses.bounds(house)
 if Modular.is(house) then return Modular.bounds(house) end
 -- Same ground footprint for every floor combination; roofs do not block walking.
 return math.floor(house.x)-26,math.floor(house.y)+2,53,16
end

function Houses.draw(parts,house,inside)
 if Modular.is(house) then return Modular.draw(parts.modular,house,inside) end
 local left,top=Houses.bounds(house)
 local ground=parts.ground[house.ground]
 love.graphics.setColor(1,1,1)
 love.graphics.draw(parts.image,ground.quad,left,top)
 love.graphics.draw(parts.doors,parts.doorQuads[house.door or 1],left+doorOffsets[house.ground],top+2)
 for _,window in ipairs(house.windows or {}) do if window.floor==1 then
  love.graphics.draw(parts.windows,parts.windowQuads[window.variant],left+window.x,top)
 end end
 local roofTop=top-10
 local roofLeft=left+2
 if house.upper then
  local upper=parts.upper[house.upper]
  local upperLeft=house.upper==3 and left-3 or left
  love.graphics.draw(parts.image,upper.quad,upperLeft,top-16)
  for _,window in ipairs(house.windows or {}) do if window.floor==2 then
   love.graphics.draw(parts.windows,parts.windowQuads[window.variant],upperLeft+window.x,top-16)
  end end
  roofTop=top-26
  roofLeft=house.upper==3 and upperLeft+2 or left+2
 end
 local roof=parts.roofs[house.roof]
 love.graphics.draw(parts.image,roof.quad,roofLeft,roofTop)
end

return Houses
