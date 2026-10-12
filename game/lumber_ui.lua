local U={};local L=require('game.lumber')
local function owner()local p=require('game.profile').active;return p and tostring(p.id)..':'..p.slot or'offline'end
local function selected(u)
 local c=u.containerSelection;if not c then return end
 if c.id then for _,v in ipairs(u.world.placedContainers or{})do if v.id==c.id and v.owner==owner()and(v.x-u.player.x)^2+(v.y-u.player.y)^2<=55^2 then return v.object end end
 else local b=u.inv:getBag(c.bag);local obj=b and b.slots[c.slot];if obj and obj.name==c.name then return L.normalize(obj)end end
 u.containerSelection=nil
end
local function mills(w)if w.authoredObjects then return w.authoredObjects end;local out={};for _,v in ipairs(w.villages or{w})do for id in pairs(L.mills)do if v[id]then out[#out+1]={id=id,x=v[id].x,y=v[id].y}end end end;return out end
local function command(u,op,extra)
 local c=u.containerSelection or{};local cmd={op=op,id=c.id,bag=c.bag,slot=c.slot,name=c.name};for k,v in pairs(extra or{})do cmd[k]=v end
 return require('game.fieldcraft_ui').command(u,cmd)
end
function U.install(UI)
 local context=UI.contextOptions;function UI:contextOptions(it)
  local rows=context(self,it);if L.defs[it.name]then table.insert(rows,1,'Open Container');table.insert(rows,2,'Place Container')elseif selected(self)then table.insert(rows,1,'Store in Container')end;return rows
 end
 local use=UI.doContextOption;function UI:doContextOption(opt)
  local c=self.context;if c and(opt=='Open Container'or opt=='Place Container')then local b=self.inv:getBag(c.bag);local obj=b and b.slots[c.slot];if not obj or not L.defs[obj.name]then return false end;self.context=nil;self.containerSelection={bag=c.bag,slot=c.slot,name=obj.name};if opt=='Place Container'then local ok=command(self,'containerPlace');self.containerSelection=nil;return ok end;return true
  elseif c and opt=='Store in Container'then self.context=nil;return command(self,'containerStore',{sourceBag=c.bag,sourceSlot=c.slot})end
  return use(self,opt)
 end
 local tooltip=UI.drawTooltip;function UI:drawTooltip(it,x,y,w,h,override)
  if L.defs[it.name]then local info={};for k,v in pairs(override or self.sprites.itemInfo[it.name]or{})do info[k]=v end;info.detail=(info.detail or'')..'\nStorage: '..L.used(it)..' / '..L.capacity(it)..' slots.';override=info end;return tooltip(self,it,x,y,w,h,override)
 end
 local draw=UI.draw;function UI:draw(...)
  draw(self,...);local obj=selected(self);if not obj then return end
  local x,y=math.max(10,love.graphics.getWidth()-660),100;local cols=5;local rows=math.ceil(L.capacity(obj)/cols);local g=love.graphics
  g.setColor(.06,.07,.06,.97);g.rectangle('fill',x,y,320,88+rows*45);g.setColor(1,1,1);g.print(obj.name..' ['..(obj.qualityGrade or'D')..']',x+10,y+8);g.print('X',x+295,y+8);g.print('Right-click inventory items to store.',x+10,y+32)
  local mx,my=love.mouse.getPosition();for i=1,L.capacity(obj)do local px=x+12+((i-1)%cols)*57;local py=y+58+math.floor((i-1)/cols)*45;g.setColor(.3,.3,.25);g.rectangle('line',px,py,40,40);local it=(obj.contents or{})[i];if it then self:drawItemSprite(it,px,py,40);g.setColor(1,1,1);g.print(tostring(it.qty or 1),px+2,py+27);if mx>=px and mx<px+40 and my>=py and my<py+40 then self:drawTooltip(it,mx,my,love.graphics.getDimensions())end end end
  if self.containerSelection.id then g.setColor(1,1,1);g.print('Retrieve container',x+10,y+62+rows*45)end;g.setColor(1,1,1)
 end
 local mouse=UI.mousepressed;function UI:mousepressed(mx,my,b,...)
  local obj=selected(self);if obj then local x,y=math.max(10,love.graphics.getWidth()-660),100;local rows=math.ceil(L.capacity(obj)/5)
   if mx>=x and mx<=x+320 and my>=y and my<=y+88+rows*45 then
    if b==1 and my<y+28 and mx>x+280 then self.containerSelection=nil
    elseif b==1 and my>=y+58 and my<y+58+rows*45 then local col=math.floor((mx-x-12)/57);local row=math.floor((my-y-58)/45);if col>=0 and col<5 then local i=row*5+col+1;if obj.contents and obj.contents[i]then command(self,'containerWithdraw',{contentSlot=i})end end
    elseif b==1 and self.containerSelection.id and my>=y+58+rows*45 then command(self,'containerRetrieve');self.containerSelection=nil end;return true
   end
  end;return mouse(self,mx,my,b,...)
 end
 local F=require('game.fieldcraft_ui');local click=F.worldClick;function F.worldClick(u,camera,x,y,b)
  local wx,wy=camera:toWorld(x,y,love.graphics.getDimensions())
  for _,v in ipairs(u.world.placedContainers or{})do if(wx-v.x)^2+(wy-v.y)^2<14^2 then if v.owner==owner()and(v.x-u.player.x)^2+(v.y-u.player.y)^2<=55^2 then u.containerSelection={id=v.id,name=v.object.name}elseif b==2 and v.owner==owner()then return click(u,camera,x,y,b)else u.world:addPopup(u.player.x,u.player.y-24,'Container belongs to another player or is too far','miss')end;return true end end
  for _,o in ipairs(mills(u.world))do if L.mills[o.id]and math.abs(wx-o.x)<10 and math.abs(wy-o.y)<18 then if(o.x-u.player.x)^2+(o.y-u.player.y)^2<=55^2 then if u.skills:get('Woodworking').level<10 then u.world:addPopup(u.player.x,u.player.y-24,'Requires Woodworking 10','miss')else u:openCrafting('woodcraft','sawmill')end elseif b==2 then return click(u,camera,x,y,b)end;return true end end
  return click(u,camera,x,y,b)
 end
 local drawables=F.drawables;function F.drawables(u,camera,add)
  drawables(u,camera,add)
  for _,o in ipairs(mills(u.world))do local tier=L.mills[o.id];if tier then local v=o;add(v.y+16,function()love.graphics.setColor(1,1,1);love.graphics.draw(u.sprites.sawmills,u.sprites.sawmillQuads[tier],v.x-8,v.y-16)end,v.x)end end
  for _,o in ipairs(u.world.placedContainers or{})do local v=o;add(v.y+8,function()u:drawItemSprite(v.object,v.x-8,v.y-8,16)end,v.x)end
 end
 local help=require('game.help');local previous=help.world;function help.world(u,x,y)
  for _,o in ipairs(mills(u.world))do if L.mills[o.id]and math.abs(x-o.x)<10 and math.abs(y-o.y)<18 then return help.tip(({'Copper','Iron','Steel'})[L.mills[o.id]]..' Sawmill','Woodworking 10 to use. Processes pine / oak / poplar according to mill tier. Higher skill gives extra planks and less sawdust.')end end
  for _,v in ipairs(u.world.placedContainers or{})do if(x-v.x)^2+(y-v.y)^2<14^2 then return help.tip(v.object.name,'Storage '..L.used(v.object)..' / '..L.capacity(v.object)..'. Owner-only opening and retrieval.')end end
  return previous(u,x,y)
 end
 local player=require('game.player');local update=player.update;function player:update(dt,...)
  local count=0;for _,bag in pairs(L.inventories[self] and L.inventories[self].bagSlots or{})do for _,obj in pairs(bag.slots or{})do if L.defs[obj.name]and L.used(obj)>0 then count=count+1 end end end
  self.containerBurden=math.min(3,count);local speed=self.speed;self.speed=speed*(1-self.containerBurden*.05);local result=update(self,dt,...);self.speed=speed;return result
 end
 local spend=player.spendStamina;function player:spendStamina(amount,skills,logger,source)if source=='sprint'then amount=amount*(1+(self.containerBurden or 0)*.15)end;return spend(self,amount,skills,logger,source)end
 local key=UI.keypressed;function UI:keypressed(k,...)if k=='escape'and self.containerSelection then self.containerSelection=nil;return true end;if key then return key(self,k,...)end end
 local new=UI.new;function UI.new(...)local u=new(...);L.inventories[u.player]=u.inv;return u end
end
return U
