local Map={};Map.__index=Map
local TILE=16
local function q(img,col,row) return love.graphics.newQuad(col*TILE,row*TILE,TILE,TILE,img:getDimensions()) end
local function makeLandTiles(img)
 return {
  inner=q(img,6,0),
  south=q(img,2,0),west=q(img,3,0),north=q(img,4,0),east=q(img,5,0),
  southeast=q(img,4,1),southwest=q(img,5,1),northeast=q(img,3,1),northwest=q(img,2,1),
  concaveNW=q(img,1,1),concaveNE=q(img,0,1),concaveSW=q(img,1,0),concaveSE=q(img,0,0)
 }
end
local function makeWaterTiles(img)
 return {
  inner=q(img,0,0),
  south=q(img,1,0),west=q(img,2,0),north=q(img,3,0),east=q(img,4,0),
  southeast=q(img,3,1),southwest=q(img,4,1),northeast=q(img,2,1),northwest=q(img,1,1)
 }
end
function Map.new(override)
 local self=setmetatable({},Map)
 self.tile=TILE;self.cols=640;self.rows=480;self.width=self.cols*TILE;self.height=self.rows*TILE
 self.land=love.graphics.newImage('assets/island_autotile.png')
 self.water=love.graphics.newImage('assets/water_autotile.png')
 self.sandLand=love.graphics.newImage('assets/sand_land_autotile.png')
 self.sandWater=love.graphics.newImage('assets/sand_water_autotile.png')
 for _,img in ipairs({self.land,self.water,self.sandLand,self.sandWater}) do img:setFilter('nearest','nearest') end
 self.landTile=makeLandTiles(self.land);self.waterTile=makeWaterTiles(self.water)
 self.sandLandTile=makeLandTiles(self.sandLand);self.sandWaterTile=makeWaterTiles(self.sandWater)
 self.mask={}
 local ok,authored=true,override;if not authored then ok,authored=pcall(function() local chunk=love.filesystem.load('current.lua');return chunk and chunk() end)end
 local hasAuthored=ok and type(authored)=='table' and authored.format=='StonegroveMap'
 local function inPoly(nx,ny,pts)
  local inside=false;local j=#pts
  for i=1,#pts do
   local xi,yi=pts[i][1],pts[i][2];local xj,yj=pts[j][1],pts[j][2]
   if ((yi>ny)~=(yj>ny)) and nx < (xj-xi)*(ny-yi)/(yj-yi)+xi then inside=not inside end
   j=i
  end
  return inside
 end
 -- AREA 1 MAP PASS. This is deliberately only the starting 1-10 region.
 -- North and west are future seamless connections to the rest of the continent.
 -- East and south form Area 1's actual coastline from the supplied grid sketch.
 -- This is not an island and there are no artificial rivers between future zones.
 if not hasAuthored then
 for y=1,self.rows do self.mask[y]={};for x=1,self.cols do
  local nx,ny=x/self.cols,y/self.rows
  local land=true
  -- Broad eastern coast: Area 1 narrows slightly toward the south-east.
  local eastCoast=.96 - math.max(0,ny-.22)*.18
  if nx>eastCoast then land=false end
  -- Southern coast curves upward at both ends, producing the large Area 1 peninsula.
  local southCoast=.94 - .16*((nx-.60)/.60)^2
  if ny>southCoast then land=false end
  -- Round the south-east corner without creating a separate bay/channel.
  local dx,dy=(nx-.78)/.24,(ny-.77)/.20
  if nx>.72 and ny>.70 and dx*dx+dy*dy>1.35 then land=false end
  self.mask[y][x]=land
 end end
 end
 -- Authored test-map override. current.lua is the World Editor export bundled at game root.
 
 if hasAuthored then
  self.cols=authored.cols or self.cols;self.rows=authored.rows or self.rows;self.width=self.cols*TILE;self.height=self.rows*TILE
  self.mask={};for y=1,self.rows do self.mask[y]={};for x=1,self.cols do self.mask[y][x]=false end end
  for _,idx in ipairs(authored.landCells or {}) do local y=math.floor(idx/self.cols)+1;local x=(idx%self.cols)+1;if self.mask[y] then self.mask[y][x]=true end end
  self.authored=authored
 end
 return self
end
function Map:landAt(x,y) if y>=1 and y<=self.rows and x>=1 and x<=self.cols then return self.mask[y][x] or false end;return require('game.regions').landAt(self,x,y)end
function Map:isShoreCell(x,y)
 if not self:landAt(x,y) then return false end
 return not self:landAt(x,y-1) or not self:landAt(x,y+1) or not self:landAt(x-1,y) or not self:landAt(x+1,y)
end
-- The first fishing beaches are deliberately limited to the north and south coasts.
-- Dirt shoreline everywhere else remains decorative/non-walkable.
function Map:isBeachCell(x,y)
 if not self:isShoreCell(x,y) then return false end
 return y<=math.floor(self.rows*.29) or y>=math.ceil(self.rows*.72)
end
function Map:isBeachWaterCell(x,y)
 if self:landAt(x,y) then return false end
 return self:isBeachCell(x,y-1) or self:isBeachCell(x,y+1) or self:isBeachCell(x-1,y) or self:isBeachCell(x+1,y)
end
function Map:isLand(x,y)
 if x<0 or y<0 or x>=self.width or y>=self.height then return false end
 local tx=math.floor(x/TILE)+1;local ty=math.floor(y/TILE)+1
 if not self:landAt(tx,ty) then return false end
 -- Dark-brown dirt shoreline is not walkable. Light-brown north/south sand is.
 if self:isShoreCell(tx,ty) and ty>math.floor(self.rows*.29) and ty<math.ceil(self.rows*.72) then return false end
 return true
end
function Map:landQuad(x,y,tiles)
 tiles=tiles or self.landTile
 local n=self:landAt(x,y-1);local s=self:landAt(x,y+1);local w=self:landAt(x-1,y);local e=self:landAt(x+1,y)
 if not s and not e then return tiles.southeast end
 if not s and not w then return tiles.southwest end
 if not n and not e then return tiles.northeast end
 if not n and not w then return tiles.northwest end
 if not s then return tiles.south end;if not n then return tiles.north end;if not w then return tiles.west end;if not e then return tiles.east end
 if not self:landAt(x-1,y-1) then return tiles.concaveNW end;if not self:landAt(x+1,y-1) then return tiles.concaveNE end
 if not self:landAt(x-1,y+1) then return tiles.concaveSW end;if not self:landAt(x+1,y+1) then return tiles.concaveSE end
 return tiles.inner
end
function Map:waterQuad(x,y,tiles)
 tiles=tiles or self.waterTile
 local n=self:landAt(x,y-1);local s=self:landAt(x,y+1);local w=self:landAt(x-1,y);local e=self:landAt(x+1,y)
 if s and e then return tiles.southeast end;if s and w then return tiles.southwest end;if n and e then return tiles.northeast end;if n and w then return tiles.northwest end
 if s then return tiles.south end;if n then return tiles.north end;if w then return tiles.west end;if e then return tiles.east end
 return tiles.inner
end
function Map:buildBatches() require('game.terrain').build(self) end
function Map:draw() require('game.terrain').draw(self) end
return Map
