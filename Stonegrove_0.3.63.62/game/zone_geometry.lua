-- Rectangular unions retain gaps and concave boundaries; bounds are only an index.
local G={}
function G.copy(v)if type(v)~='table'then return v end;local c={};for k,x in pairs(v)do c[k]=G.copy(x)end;return c end
function G.parts(z)return z.rects or{z}end
function G.contains(z,x,y)
 for _,r in ipairs(G.parts(z))do if x>=r.x and x<r.x+r.w and y>=r.y and y<r.y+r.h then return true end end;return false
end
function G.priorityAt(z,x,y)for _,r in ipairs(G.parts(z))do if x>=r.x and x<r.x+r.w and y>=r.y and y<r.y+r.h then return r.priority or G.area(z)end end;return math.huge end
function G.area(z)local a=0;for _,r in ipairs(G.parts(z))do a=a+r.w*r.h end;return a end
function G.sample(z,rng,weighted)
 rng=rng or math.random;local total=weighted and G.weightedArea(z)or G.area(z);if total<=0 then return end;local pick=rng()*total;for _,r in ipairs(G.parts(z))do local a=r.w*r.h*(weighted and((r.settings or z).density or 1)or 1);if pick<a then return r.x+rng()*r.w,r.y+rng()*r.h end;pick=pick-a end;local r=G.parts(z)[1];return r.x,r.y
end
function G.touch(a,b)
 if a.x>b.x+b.w or b.x>a.x+a.w or a.y>b.y+b.h or b.y>a.y+a.h then return false end
 for _,r in ipairs(G.parts(a))do for _,s in ipairs(G.parts(b))do if r.x<=s.x+s.w and s.x<=r.x+r.w and r.y<=s.y+s.h and s.y<=r.y+r.h then return true end end end;return false
end
local function settings(z)return {level=z.level,density=z.density or 1,resourceMode=z.resourceMode or'auto',resources=G.copy(z.resources or{}),enemies=z.enemies~=false}end
local function signature(s,priority)local keys={};for k,v in pairs(s.resources or{})do if v then keys[#keys+1]=k end end;table.sort(keys);return tostring(s.level)..':'..tostring(s.density)..':'..tostring(s.enemies)..':'..s.resourceMode..':'..table.concat(keys,',')..':'..tostring(priority)end
function G.localSettings(z,x,y)
 for _,r in ipairs(G.parts(z))do if x>=r.x and x<r.x+r.w and y>=r.y and y<r.y+r.h then if not r.settings then return z end;local out=G.copy(r.settings);out.x,out.y,out.w,out.h=z.x,z.y,z.w,z.h;return out end end
end
function G.weightedArea(z)local a=0;for _,r in ipairs(G.parts(z))do a=a+r.w*r.h*((r.settings or z).density or 1)end;return a end
function G.propagate(z,old)
 for _,r in ipairs(z.rects or{})do r.settings=r.settings or settings(old);for _,key in ipairs({'level','density','resourceMode','enemies'})do if z[key]~=old[key]then r.settings[key]=z[key]end end;local function equal(a,b)for k,v in pairs(a or{})do if(b or{})[k]~=v then return false end end;for k,v in pairs(b or{})do if(a or{})[k]~=v then return false end end;return true end;if not equal(z.resources,old.resources)then r.settings.resources=G.copy(z.resources or{})end end
end
function G.compatible(a,b)
 if(a.resourceMode or'auto')~=(b.resourceMode or'auto')then return false end
 if a.resourceMode=='custom'then for k,v in pairs(a.resources or{})do if(v==true)~=((b.resources or{})[k]==true)then return false end end;for k,v in pairs(b.resources or{})do if(v==true)~=((a.resources or{})[k]==true)then return false end end end;return true
end
function G.union(a,b,chosen)
 local inputs={};local ys,xs,seenY,seenX={},{},{},{}
 for _,z in ipairs({a,b})do for _,r in ipairs(G.parts(z))do local v=G.copy(r);v.settings=v.settings or settings(z);v.priority=v.priority or G.area(z);inputs[#inputs+1]=v;for _,y in ipairs({r.y,r.y+r.h})do if not seenY[y]then seenY[y]=true;ys[#ys+1]=y end end;for _,x in ipairs({r.x,r.x+r.w})do if not seenX[x]then seenX[x]=true;xs[#xs+1]=x end end end end
 table.sort(ys);table.sort(xs);local rects,previous={},{}
 for i=1,#ys-1 do local y,h=ys[i],ys[i+1]-ys[i];local runs={}
  for j=1,#xs-1 do local x,w=xs[j],xs[j+1]-xs[j];local best
   for _,r in ipairs(inputs)do if r.x<=x and r.x+r.w>=x+w and r.y<=y and r.y+r.h>=y+h and(not best or r.priority<=best.priority)then best=r end end
   if best then local sig=signature(best.settings,best.priority);local last=runs[#runs];if last and last.x+last.w==x and last.sig==sig then last.w=last.w+w else runs[#runs+1]={x=x,y=y,w=w,h=h,settings=G.copy(best.settings),priority=best.priority,sig=sig}end end
  end
  local current={};for _,r in ipairs(runs)do local key=r.x..':'..r.w..':'..r.sig;local prev=previous[key];if prev and prev.y+prev.h==y then prev.h=prev.h+h;current[key]=prev else r.sig=nil;rects[#rects+1]=r;current[key]=r end end;previous=current
 end
 if #rects>4096 then return nil end
 local z=G.copy(chosen or a);local x,y,right,bottom=math.huge,math.huge,-math.huge,-math.huge
 for _,r in ipairs(rects)do x=math.min(x,r.x);y=math.min(y,r.y);right=math.max(right,r.x+r.w);bottom=math.max(bottom,r.y+r.h)end
 z.x,z.y,z.w,z.h=x,y,right-x,bottom-y;z.rects=rects;return z
end
function G.merge(list,selected)
 local out={};for _,z in ipairs(list)do out[#out+1]=z end;local chosen=out[selected or 0];local merged=0;local again=true
 while again do again=false;for i=1,#out do for j=i+1,#out do if G.compatible(out[i],out[j])and G.touch(out[i],out[j])then
  local source=chosen==out[j]and out[j]or out[i];local z=G.union(out[i],out[j],source);if z then if chosen==out[i]or chosen==out[j]then chosen=z end;out[i]=z;table.remove(out,j);merged=merged+1;again=true;break end
 end end;if again then break end end end
 local index;for i,z in ipairs(out)do if z==chosen then index=i end end;return out,index,merged
end
local outlines=setmetatable({},{__mode='k'})
function G.draw(z,fill,line)
 -- Fill disjoint rectangles, then split their edges to omit interior seams.
 local g=love.graphics;g.setColor(unpack(fill));for _,r in ipairs(G.parts(z))do g.rectangle('fill',r.x,r.y,r.w,r.h)end;g.setColor(unpack(line))
 local lines=outlines[z];if not lines then lines={};outlines[z]=lines;local parts=G.parts(z)
 for _,r in ipairs(parts)do for _,side in ipairs({'top','bottom','left','right'})do
  local horizontal=side=='top'or side=='bottom';local pos=horizontal and(side=='top'and r.y or r.y+r.h)or(side=='left'and r.x or r.x+r.w)
  local start=horizontal and r.x or r.y;local finish=start+(horizontal and r.w or r.h);local cuts={start,finish}
  for _,s in ipairs(parts)do for _,v in ipairs(horizontal and{s.x,s.x+s.w}or{s.y,s.y+s.h})do if v>start and v<finish then cuts[#cuts+1]=v end end end;table.sort(cuts)
  for i=1,#cuts-1 do local mid=(cuts[i]+cuts[i+1])/2;local offset=(side=='top'or side=='left')and-.01 or .01;local inside=horizontal and G.contains(z,mid,pos+offset)or not horizontal and G.contains(z,pos+offset,mid)
   if not inside and cuts[i+1]>cuts[i]then if horizontal then lines[#lines+1]={cuts[i],pos,cuts[i+1],pos}else lines[#lines+1]={pos,cuts[i],pos,cuts[i+1]}end end
  end
 end end
 end;for _,v in ipairs(lines)do g.line(unpack(v))end
end
return G
