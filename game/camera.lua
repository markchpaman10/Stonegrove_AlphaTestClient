local Camera={}
Camera.__index=Camera
function Camera.new()
  return setmetatable({x=0,y=0,zoom=4.0,minZoom=2.5,maxZoom=5.0,zoomStep=0.25,reach=0.42,speed=16.0},Camera)
end
function Camera:reset(x,y) self.x,self.y=x,y end
function Camera:adjustZoom(wheelY)
  if wheelY==0 then return self.zoom end
  self.zoom=math.max(self.minZoom,math.min(self.maxZoom,self.zoom+wheelY*self.zoomStep))
  return self.zoom
end
function Camera:update(dt,px,py,mx,my,w,h)
  local enabled=love.mouse.isDown(3);local sx,sy=enabled and(mx-w/2)or 0,enabled and(my-h/2)or 0
  local tx=px+(sx/self.zoom)*self.reach
  local ty=py+(sy/self.zoom)*self.reach
  local blend=1-math.exp(-self.speed*dt)
  self.x=self.x+(tx-self.x)*blend; self.y=self.y+(ty-self.y)*blend
end
function Camera:toWorld(mx,my,w,h) return self.x+(mx-w/2)/self.zoom,self.y+(my-h/2)/self.zoom end
function Camera:toScreen(wx,wy,w,h) return math.floor(w/2+(wx-self.x)*self.zoom+.5),math.floor(h/2+(wy-self.y)*self.zoom+.5) end
function Camera:begin(w,h)
  love.graphics.push(); love.graphics.translate(math.floor(w/2),math.floor(h/2)); love.graphics.scale(self.zoom); love.graphics.translate(-math.floor(self.x),-math.floor(self.y))
end
function Camera:finish() love.graphics.pop() end
return Camera
