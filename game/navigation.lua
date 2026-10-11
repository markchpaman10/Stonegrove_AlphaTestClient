local N={}
local routes=setmetatable({},{__mode='k'})
local grids=setmetatable({},{__mode='k'})
local T=16
function N.forget(actor) routes[actor]=nil end
local directions={{1,0},{-1,0},{0,1},{0,-1}}
local sides={1,-1}
local function key(x,y) return y*1000+x end
function N.refresh(w,cx,cy,radius)
 local g={};radius=radius or 1200;local r2=radius*radius;local function near(x,y) return not cx or (x-cx)^2+(y-cy)^2<=r2 end;local function rect(x,y,ww,hh,pad)
  for cy=math.floor((y-pad)/T),math.floor((y+hh+pad)/T) do for cx=math.floor((x-pad)/T),math.floor((x+ww+pad)/T) do
   local px,py=cx*T+8,cy*T+8;if px>=x-pad and px<=x+ww+pad and py>=y-pad and py<=y+hh+pad then g[key(cx,cy)]=true end
  end end
 end
 for _,r in ipairs(w.fenceRails or {}) do rect(r.x,r.y-4,r.w,r.h,6) end
 for _,h in ipairs(w.houses or {}) do local x,y,ww,hh=require('game.houses').bounds(h);local M=require('game.modular_houses')
  if M.is(h) then
   for cy=math.floor((y-10)/T),math.floor((y+hh+6)/T) do for cx=math.floor((x-6)/T),math.floor((x+ww+6)/T) do
    if M.blocked(h,cx*T+8,cy*T+12,5) then g[key(cx,cy)]=true end
   end end
  else rect(x,y-4,ww,hh,6) end
 end
 for _,v in ipairs(w.villages or {}) do
  for _,name in ipairs({'bankChest','smelter','anvil','tanningVat','hideStretcher','spinningWheel','loom','metalLoom','alchemy','tailoring'}) do local st=v[name];if st then rect(st.x-8,st.y-5,16,16,5) end end
 end
 for _,list in ipairs({w.tradeKeepers or {},w.traders or {},w.healers or {}}) do for _,npc in ipairs(list) do rect(npc.x-7,npc.y-7,14,14,5) end end
 for _,n in ipairs(w.nodes or {}) do if near(n.x,n.y) and not n.depleted and (n.kind=='tree' or (n.kind=='oak' or n.kind=='poplar') or n.kind=='copper' or n.kind=='tin' or n.kind=='iron' or n.kind=='coal') then rect(n.x-6,n.y-2,12,12,9) end end
 for _,c in ipairs(w.playerCamps or{})do rect(c.x-16,c.y-15,32,20,5);for _,s in ipairs(c.structures or{})do rect(s.x-8,s.y-8,16,16,5)end end
 grids[w]=g
end
function N.begin(w,dt,player)
 w.navClock=(w.navClock or 0)+dt;w.navBudget=2;w.navEscortBudget=1
 if not grids[w] or w.navClock>=(w.navRefresh or 0) then N.refresh(w,player and player.x,player and player.y,1200);w.navRefresh=w.navClock+3 end
end
local function free(w,x,y,a)
 return x>=0 and y>=0 and x<w.map.cols and y<w.map.rows and not grids[w][key(x,y)] and w.map:isLand(x*T+8,y*T+8) and (not a.pasture or require('game.fences').inside(a.pasture,x*T+8,y*T+8,18))
end
function N.path(w,a,tx,ty)
 if not grids[w] then N.refresh(w) end
 local sx,sy=math.floor(a.x/T),math.floor(a.y/T);local gx,gy=math.floor(tx/T),math.floor(ty/T)
 if not free(w,gx,gy,a) then local found=false;for r=1,5 do for dy=-r,r do for dx=-r,r do if not found and free(w,gx+dx,gy+dy,a) then gx,gy=gx+dx,gy+dy;found=true end end end;if found then break end end;if not found then return {} end end
 local heap={};local function push(n) local i=#heap+1;while i>1 do local p=math.floor(i/2);if heap[p].f<=n.f then break end;heap[i]=heap[p];i=p end;heap[i]=n end
 local function pop() local root=heap[1];local last=table.remove(heap);if #heap>0 then local i=1;while i*2<=#heap do local c=i*2;if heap[c+1] and heap[c+1].f<heap[c].f then c=c+1 end;if heap[c].f>=last.f then break end;heap[i]=heap[c];i=c end;heap[i]=last end;return root end
 local start={x=sx,y=sy,g=0,f=0};push(start);local best={[key(sx,sy)]=0};local visits=0
 while #heap>0 and visits<16000 do local n=pop();visits=visits+1
  if n.x==gx and n.y==gy then local out={};while n.parent do out[#out+1]={x=n.x*T+8,y=n.y*T+8};n=n.parent end;for i=1,math.floor(#out/2) do local j=#out-i+1;out[i],out[j]=out[j],out[i] end;return out end
  for _,d in ipairs(directions) do local x,y=n.x+d[1],n.y+d[2];local k=key(x,y);local cost=n.g+1
   if (not best[k] or cost<best[k]) and free(w,x,y,a) then best[k]=cost;push({x=x,y=y,g=cost,f=cost+math.abs(x-gx)+math.abs(y-gy),parent=n}) end
  end
 end
 return {}
end
function N.move(w,a,tx,ty,speed,dt)
 if (tx-a.x)^2+(ty-a.y)^2<9 then return end
 local now=w.navClock or 0;local r=routes[a]
 if r and r.retryAt and now<r.retryAt then return end
 if not r or r.retryAt or now-r.time>2 or (r.tx-tx)^2+(r.ty-ty)^2>48^2 then
  local budget=a.navPriority and "navEscortBudget" or "navBudget";if (w[budget] or 0)>0 then w[budget]=w[budget]-1;r={points=N.path(w,a,tx,ty),i=1,tx=tx,ty=ty,time=now};routes[a]=r end
 end
 local goal=r and r.points[r.i];if not goal then if r then r.retryAt=now+1;r.time=now end;return end
 local dx,dy=goal.x-a.x,goal.y-a.y;local dist=math.sqrt(dx*dx+dy*dy)
 if dist<3 then r.i=r.i+1;return end
 local step=math.min(dist,speed*dt);local x,y=a.x+dx/dist*step,a.y+dy/dist*step
 if not w:enemyBlocked(x,y,a) then a.x,a.y=x,y;r.stuck=0 else
  -- Sidestep temporary actors without abandoning the static fence route.
  for _,sign in ipairs(sides) do local xx,yy=a.x-dy/dist*step*sign,a.y+dx/dist*step*sign
   if not w:enemyBlocked(xx,yy,a) then a.x,a.y=xx,yy;break end
  end
  r.stuck=(r.stuck or 0)+dt;if r.stuck>.5 then N.refresh(w,a.x,a.y,1200);r.time=now-3;r.stuck=0 end
 end
end
return N
