local C={}
local function q(x,y,w,h,img) local iw,ih=img:getDimensions();return love.graphics.newQuad(x,y,w,h,iw,ih) end
local function hash(s)
 local h=2166136261
 for i=1,#s do h=(h*16777619+s:byte(i))%2147483647 end
 return h
end
local function pick(list,n) return list[(n%#list)+1] end
function C.load()
 local self={clothes={},hair=nil,hairStyles={},beardStyles={}}
 local files={"npc_clothes_01.png","npc_clothes_02.png","npc_clothes_03.png","npc_clothes_04.png","npc_clothes_05.png","npc_dress_01.png","npc_dress_02.png"}
 for i,f in ipairs(files) do local img=love.graphics.newImage("assets/"..f);img:setFilter("nearest","nearest");self.clothes[i]={image=img,down={}};for frame=1,4 do self.clothes[i].down[frame]=q((frame-1)*16,32,16,16,img) end end
 self.hair=love.graphics.newImage("assets/npc_hair_beards.png");self.hair:setFilter("nearest","nearest")
 -- Source sheet is organized as 4-frame x 3-direction cosmetic sets, separated by 16px gaps.
 -- Top band contains beard/facial-hair sets; the next two bands contain the supplied hair sets.
 for _,tx in ipairs({0,5,10,21,26,31,40,45,50}) do self.beardStyles[#self.beardStyles+1]={x=tx*16,y=0,down=q(tx*16,32,16,16,self.hair)} end
 self.beardStyles[#self.beardStyles+1]={x=46*16,y=49*16,down=q(46*16,51*16,16,16,self.hair)}
 for _,tx in ipairs({0,5,10,15,20,25,30,35,40,45,50,55}) do self.hairStyles[#self.hairStyles+1]={x=tx*16,y=4*16,down=q(tx*16,6*16,16,16,self.hair)} end
 for _,tx in ipairs({0,5,10,15,20,25,30,35,40,45,50}) do self.hairStyles[#self.hairStyles+1]={x=tx*16,y=8*16,down=q(tx*16,10*16,16,16,self.hair)} end
 -- Cosmetic cells include the head outline. Align that outline, not the
 -- highest hair pixel (ponytails and tufts extend above the crown).
 -- Only styles 5-12 have their whole head template shifted down two pixels.
 for i=5,12 do self.hairStyles[i].oy=-2 end
 local style=self.beardStyles[3];style.frames={}
 for row,dir in ipairs({'up','right','down'}) do style.frames[dir]={};for frame=1,4 do style.frames[dir][frame]=(dir=='down' and frame==1) and style.down or q(style.x+(frame-1)*16,style.y+(row-1)*16,16,16,self.hair) end end
 return setmetatable(self,{__index=C})
end
function C:appearance(key,race,forceGender)
 local h=hash(tostring(key)..":"..tostring(race or "Human"));local gender=forceGender or ((h%2==0) and "female" or "male")
 local clothes
 if gender=="female" then clothes=6+(math.floor(h/7)%2) else clothes=1+(math.floor(h/7)%5) end
 local hair=1+(math.floor(h/31)%#self.hairStyles)
 local beard=nil;if gender=="male" and math.floor(h/97)%3~=0 then beard=1+(math.floor(h/97)%#self.beardStyles) end
 if race=='Dwarf' then beard=3 end
 return {gender=gender,clothes=clothes,hair=hair,beard=beard}
end
function C.hideHair(npc,opts)
 return (opts and opts.helmet) or (npc.equipment and npc.equipment.head~=nil) or false
end
local function frameQuad(style,image,dir,frame)
 local key=dir=='left'and'right'or dir;style._frames=style._frames or{};local tag=key..frame;local quad=style._frames[tag]
 if not quad then local row=key=='up'and 0 or key=='right'and 1 or 2;quad=q((style.x or 0)+(frame-1)*16,(style.y or 0)+row*16,16,16,image);style._frames[tag]=quad end;return quad
end
function C:drawShadow(npc,sprites,key,opts)
 if npc.race=='Ghost'then return require('game.dark_content').draw(sprites,npc,true)end
 opts=opts or {};local race=npc.race or opts.race or 'Human';local app=npc.cosmetics or self:appearance(key or npc.name or npc.trade or 'npc',race,opts.gender);npc.cosmetics=app
 local H=require('game.humanoid');local x,y=npc.x,npc.y;local dir=npc.direction or'down';local frame=npc.frame or 1;local key=dir=='left'and'right'or dir;local flip=dir=='left'and-1 or 1;love.graphics.setColor(.035,.045,.05,.28)
 H.shadow(sprites.bodyImage,sprites.player.body[key][frame],x,y,flip,race,'body')
 local cloth=self.clothes[app.clothes];if cloth then H.shadow(cloth.image,frameQuad(cloth,cloth.image,dir,frame),x,y,flip,race,'body') end
 H.shadow(sprites.headImage,sprites.player.head[key][frame],x,y,flip,race,'head')
 if race=='Dwarf' then H.shadow(self.hair,frameQuad(self.beardStyles[3],self.hair,dir,frame),x,y,flip,race,'head')
 elseif app.gender~='female' and app.beard and not C.hideHair(npc,opts) then H.shadow(self.hair,frameQuad(self.beardStyles[app.beard],self.hair,dir,frame),x,y,flip,race,'head') end
 if app.hair and not C.hideHair(npc,opts) then local st=self.hairStyles[app.hair];H.shadow(self.hair,frameQuad(st,self.hair,dir,frame),x+(st.ox or 0),y+(st.oy or 0)*-.32,flip,race,'head') end
 love.graphics.setColor(1,1,1,1)
end
function C:draw(npc,sprites,key,opts)
 if npc.race=='Ghost'then return require('game.dark_content').draw(sprites,npc,false)end
 opts=opts or {};local race=npc.race or opts.race or 'Human';local app=npc.cosmetics or self:appearance(key or npc.name or npc.trade or 'npc',race,opts.gender);npc.cosmetics=app
 local H=require('game.humanoid');local x,y=npc.x,npc.y;local dir=npc.direction or'down';local frame=npc.frame or 1;local key=dir=='left'and'right'or dir;local flip=dir=='left'and-1 or 1;love.graphics.setColor(1,1,1)
 if npc.id then local P=require('game.paperdoll');if dir~='up'then P.gear(sprites,(npc.equipment or{}).cape,x,y,dir,frame,race)end;if dir=='up'then P.held(sprites,(npc.equipment or{}).weapon,x,y,dir,1,frame,race);P.held(sprites,(npc.equipment or{}).offhand,x,y,dir,-1,frame,race)end end
 H.draw(sprites.bodyImage,sprites.player.body[key][frame],x,y,flip,race,'body')
 local cloth=self.clothes[app.clothes];if cloth then H.draw(cloth.image,frameQuad(cloth,cloth.image,dir,frame),x,y,flip,race,'body') end
 if npc.id then local P=require('game.paperdoll');for _,slot in ipairs({'body','legs'})do P.gear(sprites,(npc.equipment or{})[slot],x,y,dir,frame,race)end end
 if npc.id and dir=='up'then require('game.paperdoll').gear(sprites,(npc.equipment or{}).cape,x,y,dir,frame,race)end
 H.draw(sprites.headImage,sprites.player.head[key][frame],x,y,flip,race,'head')
 if race=='Dwarf' then H.beard(sprites,race,x,y,dir,frame)
 elseif app.gender~='female' and app.beard and not C.hideHair(npc,opts) then H.draw(self.hair,frameQuad(self.beardStyles[app.beard],self.hair,dir,frame),x,y,flip,race,'head') end
 if app.hair and not C.hideHair(npc,opts) then local st=self.hairStyles[app.hair];H.draw(self.hair,frameQuad(st,self.hair,dir,frame),x+(st.ox or 0),y+(st.oy or 0),flip,race,'head') end
 if npc.id then local P=require('game.paperdoll');P.gear(sprites,(npc.equipment or{}).head,x,y,dir,frame,race);if dir~='up'then P.held(sprites,(npc.equipment or{}).weapon,x,y,dir,1,frame,race);P.held(sprites,(npc.equipment or{}).offhand,x,y,dir,-1,frame,race)end end
 require('game.race_ears').draw(sprites,race,x,y,dir,frame,C.hideHair(npc,opts))
end
return C
