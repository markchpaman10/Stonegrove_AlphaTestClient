-- Precipitation samples depend only on particle index, never time or gameplay RNG.
local noiseSamples={}
local function noise(n)
 local value=noiseSamples[n]
 if value==nil then
  local v=math.sin(n*12.9898+78.233)*43758.5453
  value=v-math.floor(v);noiseSamples[n]=value
 end
 return value
end
local Weather={}
Weather.__index=Weather

local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function dist2(x1,y1,x2,y2) local dx,dy=x1-x2,y1-y2;return dx*dx+dy*dy end

function Weather.new(map)
 local self=setmetatable({map=map,time=0,regions={},drops={},puddles={},nextShift=0},Weather)
 local w,h=map.width,map.height
 -- Regional weather cells. They drift slowly, so weather never blankets the whole island.
 self.regions={
  {kind="snow",x=w*.32,y=h*.17,r=520,vx=4,vy=1,intensity=.58,wind=.55},
  {kind="rain",x=w*.68,y=h*.42,r=470,vx=-5,vy=2,intensity=.70,wind=.75},
  {kind="wind",x=w*.48,y=h*.70,r=560,vx=3,vy=-2,intensity=.55,wind=1.00}
 }
 return self
end

function Weather:update(dt)
 self.time=self.time+dt
 local w,h=self.map.width,self.map.height
 for _,r in ipairs(self.regions) do
  r.x=r.x+r.vx*dt;r.y=r.y+r.vy*dt
  if r.x<r.r then r.x=r.r;r.vx=math.abs(r.vx) elseif r.x>w-r.r then r.x=w-r.r;r.vx=-math.abs(r.vx) end
  if r.y<r.r then r.y=r.r;r.vy=math.abs(r.vy) elseif r.y>h-r.r then r.y=h-r.r;r.vy=-math.abs(r.vy) end
 end
 for i=#self.puddles,1,-1 do local p=self.puddles[i];p.life=p.life-dt;if p.life<=0 then table.remove(self.puddles,i) end end
end

function Weather:at(x,y)
 local rain,snow,wind=0,0,0
 for _,r in ipairs(self.regions) do
  local d=math.sqrt(dist2(x,y,r.x,r.y))
  if d<r.r then
   local f=(1-d/r.r)*r.intensity
   if r.kind=="rain" then rain=math.max(rain,f) elseif r.kind=="snow" then snow=math.max(snow,f) end
   wind=math.max(wind,f*(r.wind or 1))
  end
 end
 -- Northern climate has a mild permanent snow bias.
 local north=clamp((self.map.height*.30-y)/(self.map.height*.18),0,1)
 snow=math.max(snow,north*.32)
 return rain,snow,wind
end

function Weather.updateCover(n,snow,dt)
 local field=n.depleted and 'stumpSnow'or'snowCovered'
 local depth=n.snowDepth;if depth==nil then depth=n[field]and .75 or 0 end
 depth=clamp(depth+(snow>.12 and .04 or snow<.035 and -.008 or 0)*(dt or 1),0,1);n.snowDepth=depth
 if depth>=.65 then n[field]=true elseif depth<=.15 then n[field]=false end
end
function Weather:windAt(x,y)
 local _,_,wind=self:at(x,y)
 if wind<=.02 then return 0 end
 return math.sin(self.time*1.7+x*.017+y*.009)*wind
end

function Weather:drawGround(cx,cy,viewW,viewH)
 local rain,snow=self:at(cx,cy)
 if snow>.04 then
  -- Sparse translucent snow cover. This is intentionally cosmetic until snow-specific art arrives.
  local left,right=cx-viewW/2-24,cx+viewW/2+24
  local top,bottom=cy-viewH/2-24,cy+viewH/2+24
  love.graphics.setColor(.92,.96,1,.10+snow*.16)
  local step=32
  for y=math.floor(top/step)*step,bottom,step do
   for x=math.floor(left/step)*step,right,step do
    if self.map:isLand(x,y) then
     local n=math.sin(x*.071+y*.113)*.5+.5
     if n<.60+snow*.28 then love.graphics.rectangle("fill",x,y,step+1,step+1) end
    end
   end
  end
 end
 -- Temporary puddles appear only in local rain and fade after the rain cell moves on.
 if rain>.16 and #self.puddles<36 and math.random()<.035 then
  local x=cx+(math.random()-.5)*viewW*.85;local y=cy+(math.random()-.5)*viewH*.85
  if self.map:isLand(x,y) then self.puddles[#self.puddles+1]={x=x,y=y,rx=3+math.random()*7,ry=1.5+math.random()*3,life=18+math.random()*24} end
 end
 for _,p in ipairs(self.puddles) do
  if math.abs(p.x-cx)<viewW/2+20 and math.abs(p.y-cy)<viewH/2+20 then
   love.graphics.setColor(.18,.38,.48,.20*clamp(p.life/8,0,1));love.graphics.ellipse("fill",p.x,p.y,p.rx,p.ry)
  end
 end
 love.graphics.setColor(1,1,1,1)
end

function Weather:drawPrecipitation(cx,cy,w,h,zoom)
 local rain,snow,wind=self:at(cx,cy)

 if rain>.04 then
  local count=math.floor(14+rain*170);local hard=rain>.55
  love.graphics.setLineWidth(hard and 2 or 1);love.graphics.setColor(.68,.84,.96,.24+rain*.42)
  for i=1,count do
   local phase=noise(i*19.17)*1000
   local speed=220+noise(i*7.31)*170+rain*120
   local y=(noise(i*31.7)*h+self.time*speed+phase)%h
   local x=(noise(i*53.9)*w+self.time*(wind*55-18)+noise(i*91.3)*37)%w
   local len=(hard and 10 or 4)+noise(i*11.8)*(hard and 15 or 7)+rain*5
   local slant=-1.5-wind*(3+noise(i*17.2)*5)
   love.graphics.line(x,y,x+slant,y+len)
  end
  love.graphics.setLineWidth(1)
 end
 if snow>.04 then
  local count=math.floor(10+snow*145);love.graphics.setColor(.97,.99,1,.32+snow*.45)
  for i=1,count do
   local phase=noise(i*23.4)*900
   local speed=18+noise(i*5.7)*30+snow*20
   local y=(noise(i*37.1)*h+self.time*speed+phase)%h
   local drift=math.sin(self.time*(.7+noise(i*3.1)) + i)*10
   local x=(noise(i*61.2)*w+drift+self.time*wind*(8+noise(i*9.4)*18))%w
   local size=1+math.floor(noise(i*13.6)*2+snow*1.5)
   love.graphics.line(x,y,x+wind*2,y+size)
  end
 end
 love.graphics.setColor(1,1,1,1)
end

function Weather:drawScreenEffects(cx,cy,w,h,zoom)
 local rain,snow=self:at(cx,cy);local storm=math.max(rain,snow)
 if storm>.03 then love.graphics.setColor(.035,.055,.07,.06+storm*.16);love.graphics.rectangle("fill",0,0,w,h) end
 self:drawPrecipitation(cx,cy,w,h,zoom)
 love.graphics.setColor(1,1,1,1)
end

return Weather
