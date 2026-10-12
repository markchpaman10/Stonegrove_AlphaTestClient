-- Static terrain thumbnails are built once, not thousands of rectangles per frame.
local M={};local cache=setmetatable({},{__mode='k'})
function M.get(data)
 local entry=cache[data];local revision=data.terrainRevision or 0
 if entry and entry.revision==revision then return entry.canvas end
 local cols,rows=data.cols,data.rows;local width,height=math.min(512,cols),math.min(512,rows);local g=love.graphics
 local canvas=g.newCanvas(width,height,{dpiscale=1});canvas:setFilter('nearest','nearest');g.push('all');g.setCanvas(canvas);g.setStencilTest();g.setScissor();g.clear(.055,.2,.3,1);g.setColor(.22,.46,.24)
 local sx,sy=width/cols,height/rows
 if data.landCells then for _,id in ipairs(data.landCells)do g.rectangle('fill',(id%cols)*sx,math.floor(id/cols)*sy,math.ceil(sx),math.ceil(sy))end
 else for y,row in ipairs(data.mask or{})do for x,land in ipairs(row)do if land then g.rectangle('fill',(x-1)*sx,(y-1)*sy,math.ceil(sx),math.ceil(sy))end end end end
 local authored=data.authored or data;g.setColor(.55,.49,.33);for _,p in ipairs(authored.paths or{})do g.rectangle('fill',p.x/16*sx,p.y/16*sy,math.max(1,(p.w or 16)/16*sx),math.max(1,(p.h or 16)/16*sy))end
 g.pop();cache[data]={revision=revision,canvas=canvas};return canvas
end
return M
