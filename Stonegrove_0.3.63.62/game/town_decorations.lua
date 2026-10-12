-- Authored town props. Random frame is chosen once on placement, never on draw.
local D={}
D.entries={
 {id='townSupplyBox',name='Supply Box',img='town_decoration_1.png',width=16,height=16,frames=1},
 {id='townJar',name='Town Jar',img='town_decoration_2.png',width=16,height=16,frames=1},
 {id='townPoleBundle',name='Pole Bundle',img='town_decoration_3.png',width=16,height=32,frames=1},
 {id='townHangingBow',name='Hanging Bow',img='town_decoration_4.png',width=16,height=16,frames=1},
 {id='townLogPile',name='Log Pile',img='town_decoration_5.png',width=32,height=16,frames=1},
 {id='townRack',name='Town Rack (random frame)',img='town_decoration_6.png',width=32,height=16,frames=6}}
local byId,images,quads={},{},{}
for _,d in ipairs(D.entries)do byId[d.id]=d end
function D.get(id)return byId[id]end
function D.placeFrame(id)local d=byId[id];return d and math.random(1,d.frames)end
function D.frame(o)
 local d=byId[o.id];if not d then return nil end
 local n=tonumber(o.decorFrame)
 if not n or n~=n or math.abs(n)==math.huge then n=math.floor((tonumber(o.x)or 0)*31+(tonumber(o.y)or 0)*17+(tonumber(o.rotation)or 0)*7)%d.frames+1 end
 return math.max(1,math.min(d.frames,math.floor(n)))
end
function D.image(name)
 if not images[name]then local im=love.graphics.newImage('assets/'..name);im:setFilter('nearest','nearest');images[name]=im end
 return images[name]
end
function D.draw(o,image)
 local d=byId[o.id];if not d or o.eventHidden then return false end
 local im=(image or D.image)(d.img);if not im then return false end
 local index=D.frame(o);quads[im]=quads[im]or{};local q=quads[im][index]
 if not q then q=love.graphics.newQuad(0,(index-1)*d.height,d.width,d.height,im:getDimensions());quads[im][index]=q end
 love.graphics.setColor(1,1,1);love.graphics.draw(im,q,o.x,o.y,((o.rotation or 0)%4)*math.pi/2,1,1,d.width/2,d.height/2);return true
end
function D.setup(w)
 w.townDecorations={}
 for _,o in ipairs((w.map.authored or{}).objects or{})do if byId[o.id]then local p={};for k,v in pairs(o)do p[k]=v end;p.decorFrame=D.frame(o);w.townDecorations[#w.townDecorations+1]=p end end
end
function D.drawWorld(w,add)
 for _,o in ipairs(w.townDecorations or{})do local prop=o;local d=byId[o.id];local half=((o.rotation or 0)%2==1 and d.width or d.height)/2;add(o.y+half,function()D.draw(prop)end,o.x)end
end
return D
