-- Quads are immutable rectangles; share them across projectile/effect draws.
local R={}
local quads={}
local title,size
function R.quad(x,y,w,h,iw,ih)
 local a=quads[iw];if not a then a={};quads[iw]=a end
 local b=a[ih];if not b then b={};a[ih]=b end
 local c=b[w];if not c then c={};b[w]=c end
 local d=c[h];if not d then d={};c[h]=d end
 local e=d[x];if not e then e={};d[x]=e end
 local q=e[y]
 if not q then q=love.graphics.newQuad(x,y,w,h,iw,ih);e[y]=q end
 return q
end
function R.titleFont(px)
 if size~=px then title=love.graphics.newFont(px);size=px end
 return title
end
return R
