-- Chunked editor terrain renderer. Keeps Stonegrove autotile visuals while avoiding
-- rebuilding/drawing the entire 640x480 map after every brush stroke.
local T={CHUNK=32}
local function quad(image,x,y,w,h) return love.graphics.newQuad(x,y,w,h,image:getDimensions()) end
function T.load()
 if T.images then return end
 local original=love.image.newImageData('assets/terrain_tileset.png')
 local coast=original:clone()
 coast:mapPixel(function(x,y,r,g,b,a)
  if math.abs(r-18/255)<.001 and math.abs(g-78/255)<.001 and math.abs(b-137/255)<.001 then return r,g,b,0 end
  return r,g,b,a
 end)
 local grass=original:clone()
 grass:mapPixel(function(x,y,r,g,b,a)
  if y<48 then
   if math.abs(r-115/255)<.001 and math.abs(g-62/255)<.001 and math.abs(b-57/255)<.001 then return 62/255,137/255,72/255,a end
   return r,g,b,0
  end
  return r,g,b,a
 end)
 T.images={water=love.graphics.newImage(original),coast=love.graphics.newImage(coast),grass=love.graphics.newImage(grass)}
 for _,im in pairs(T.images) do im:setFilter('nearest','nearest') end
 T.water=quad(T.images.water,128,64,16,16) -- static water for editor performance
 T.variants={};for y=0,1 do for x=0,1 do T.variants[#T.variants+1]=quad(T.images.grass,64+x*16,64+y*16,16,16) end end
 T.parts={}
 for _,band in ipairs({0,112,224}) do
  local im=band==0 and T.images.grass or T.images.coast
  local p={full=quad(im,112,band+16,16,16),corners={}}
  for index,d in ipairs({{-1,-1},{1,-1},{-1,1},{1,1}}) do
   local dx,dy=d[1],d[2]
   p.corners[index]={dx=dx,dy=dy,
    outer=quad(im,dx<0 and 96 or 120,band+(dy<0 and 0 or 24),24,24),
    horizontal=quad(im,112,band+(dy<0 and 0 or 24),8,24),
    vertical=quad(im,dx<0 and 96 or 120,band+16,24,8),
    inner=quad(im,dx<0 and 168 or 156,band+(dy<0 and 24 or 12),12,12)}
  end
  T.parts[band]=p
 end
end
function T.kind(horizontal,vertical,diagonal)
 if not horizontal and not vertical then return 'outer' end
 if not horizontal then return 'vertical' end
 if not vertical then return 'horizontal' end
 if not diagonal then return 'inner' end
 return 'full'
end
local function addCell(batch,parts,x,y,present)
 local north,south,west,east=present(x,y-1),present(x,y+1),present(x-1,y),present(x+1,y)
 local diagonals={present(x-1,y-1),present(x+1,y-1),present(x-1,y+1),present(x+1,y+1)}
 local px,py=(x-1)*16,(y-1)*16
 if north and south and west and east and diagonals[1] and diagonals[2] and diagonals[3] and diagonals[4] then batch:add(parts.full,px,py);return true end
 for i,c in ipairs(parts.corners) do
  local h=c.dx<0 and west or c.dx>0 and east; local v=c.dy<0 and north or c.dy>0 and south
  local kind=T.kind(h,v,diagonals[i]);local q=kind=='full' and parts.full or c[kind]
  local _,_,w,hh=q:getViewport();batch:add(q,px+(c.dx>0 and 8 or 0),py+(c.dy>0 and 8 or 0),0,8/w,8/hh)
 end
 return false
end
local function cache(map)
 if not map._terrainChunks then map._terrainChunks={} end
 return map._terrainChunks
end
local function chunkKey(cx,cy) return cx..':'..cy end
local function buildChunk(map,cx,cy)
 T.load()
 local cs=T.CHUNK; local x0=cx*cs+1;local y0=cy*cs+1;local x1=math.min(map.cols,x0+cs-1);local y1=math.min(map.rows,y0+cs-1)
 local cells=(x1-x0+1)*(y1-y0+1)
 local b={water=love.graphics.newSpriteBatch(T.images.water,cells,'static'),coast=love.graphics.newSpriteBatch(T.images.coast,cells*4,'static'),grass=love.graphics.newSpriteBatch(T.images.grass,cells*4,'static'),details=love.graphics.newSpriteBatch(T.images.grass,cells,'static')}
 local function land(x,y)return map:landAt(x,y) end
 local function grassy(x,y) return land(x,y) and land(x-1,y) and land(x+1,y) and land(x,y-1) and land(x,y+1) end
 for y=y0,y1 do for x=x0,x1 do
  local px,py=(x-1)*16,(y-1)*16
  if not grassy(x,y) then b.water:add(T.water,px,py) end
  if land(x,y) then
   local beach=y<=math.floor(map.rows*.29) or y>=math.ceil(map.rows*.72)
   addCell(b.coast,T.parts[beach and 224 or 112],x,y,land)
   if grassy(x,y) then
    local full=addCell(b.grass,T.parts[0],x,y,grassy)
    local hash=(x*73856093+y*19349663)%2147483647
    if full and hash%7<3 then b.details:add(T.variants[hash%4+1],px,py) end
   end
  end
 end end
 cache(map)[chunkKey(cx,cy)]=b
 return b
end
function T.invalidateAll(map) map._terrainChunks={} end
function T.invalidateCell(map,tx,ty)
 local c=cache(map);local cs=T.CHUNK
 -- Autotiles inspect neighbours, so dirty the changed chunk and adjacent chunks near boundaries.
 local cx=math.floor(tx/cs);local cy=math.floor(ty/cs)
 for yy=cy-1,cy+1 do for xx=cx-1,cx+1 do
  if xx>=0 and yy>=0 and xx<math.ceil(map.cols/cs) and yy<math.ceil(map.rows/cs) then c[chunkKey(xx,yy)]=nil end
 end end
end
function T.draw(map,left,top,right,bottom)
 T.load();local cs=T.CHUNK
 left=left or 0;top=top or 0;right=right or map.cols-1;bottom=bottom or map.rows-1
 local cx0=math.max(0,math.floor(left/cs));local cy0=math.max(0,math.floor(top/cs));local cx1=math.min(math.ceil(map.cols/cs)-1,math.floor(right/cs));local cy1=math.min(math.ceil(map.rows/cs)-1,math.floor(bottom/cs))
 love.graphics.setColor(1,1,1)
 for cy=cy0,cy1 do for cx=cx0,cx1 do local b=cache(map)[chunkKey(cx,cy)] or buildChunk(map,cx,cy);love.graphics.draw(b.water);love.graphics.draw(b.coast);love.graphics.draw(b.grass);love.graphics.draw(b.details) end end
end
return T
