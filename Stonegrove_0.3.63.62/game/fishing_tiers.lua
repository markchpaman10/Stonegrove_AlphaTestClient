-- Shared client/server fishing tiers, yields and original sprite frames.
local F={tools={['Fishing Pole']=1,['Oak Fishing Pole']=5,['Poplar Fishing Pole']=20,['Shrimp Pot']=6,['Crab Pot']=12,['Lobster Pot']=30}}
function F.select(player,inv,level)
 if F.tools[player.equipped] then return player.equipped end
 for _,name in ipairs({'Poplar Fishing Pole','Oak Fishing Pole','Fishing Pole'})do if level>=F.tools[name] and inv:hasItem(name)then return name end end
 for _,name in ipairs({'Poplar Fishing Pole','Oak Fishing Pole'})do if inv:hasItem(name)then return name end end
end
function F.has(name,player,inv)return player.equipped==name or inv:hasItem(name)end
function F.capacity(level)return 10 end
function F.catch(tool,level,roll)
 if require('game.shellfish').levels[tool]then return nil,0,0 end
 if level>=60 and roll>=120 then return 'Shark',1,180 end
 if level>=30 and roll>=90 and roll<100 then return 'Tuna',1,80 end
 if tool=='Fishing Pole'and level>=20 and roll>=80 and roll<90 then return 'Manta Ray',1,35 end
 if level>=40 and roll>=100 then return 'Swordfish',1,120 end
 if tool=='Poplar Fishing Pole'then return 'Manta Ray',1,35 end
 if tool=='Oak Fishing Pole'and level<7 then return 'Small Fish',1,8 end
 if tool=='Oak Fishing Pole'then return level>=10 and roll>=105 and 'Eel'or'Large Fish',1,level>=10 and roll>=105 and 20 or 14 end
 local fish=level>=10 and roll>=105 and'Eel'or(level>=7 and roll>=62 and'Large Fish'or'Small Fish');return fish,1,fish=='Eel'and 20 or fish=='Large Fish'and 14 or 8
end
function F.largeFillets(level)return 2+math.floor((math.max(7,math.min(99,level or 7))-7)*3/92)end
function F.sample(tool,level)return tool=='Crab Pot'and'Crab'or tool=='Poplar Fishing Pole'and'Manta Ray'or tool=='Oak Fishing Pole'and(level or 7)>=7 and'Large Fish'or'Small Fish'end
function F.configure(recipes)
 for _,v in ipairs({{'Shrimp Pot',6,'Pine Logs',2,18},{'Oak Fishing Pole',5,'Oak Logs',1,15},{'Poplar Fishing Pole',20,'Poplar Logs',1,40},{'Crab Pot',12,'Oak Logs',3,30},{'Lobster Pot',30,'Oak Logs',3,60}})do
 recipes.woodcraft[#recipes.woodcraft+1]={name=v[1],output=v[1],qty=1,skill='Woodworking',level=v[2],xp=v[5],tool='Copper Dagger',needs={{v[3],v[4]},{'Rawhide String',(require('game.shellfish').levels[v[1]]~=nil)and 3 or 1}},byproducts={}}
 end
 -- Filleting now uses an inventory action that creates harvestable parts.
end
function F.load(s)
 local function image(file)local im=love.graphics.newImage('assets/'..file);im:setFilter('nearest','nearest');return im end
 local function frame(name,im,n,typ,detail)local w,h=im:getDimensions();s.itemImages[name]=im;s.itemQuads[name]=love.graphics.newQuad(n*16,0,16,16,w,h);s.itemInfo[name]={title=name,type=typ,detail=detail}end
 local meat=image('crabMeatSheet.png');local manta=image('mantaRaySheet.png');local pot=image('crabPotSheet.png')
 frame('Crab',image('itemCrab.png'),0,'Raw Food','Prepare meat with a Knife at Cooking 30 in the Woodworking / Fletching menu.')
 for _,v in ipairs({{'Crab Meat',meat,12},{'Manta Ray',manta,20}})do
 frame(v[1],v[2],0,'Raw Food','Cook at a stove or campfire. Requires Cooking '..v[3]..'.')
 for _,grade in ipairs({'D','C','B','A'})do frame('Cooked '..v[1]..' '..grade,v[2],1,'Food','Grade '..grade..'.')end
 frame('Burnt '..v[1],v[2],2,'Burnt Food','Restores 1 health and sells for exactly 1 copper.')
 end
 local lobster=image('lobsterPartsSheet.png');local pieces=image('lobsterPiecesSheet.png');local lm=image('lobsterMeatSheet.png');local crab=image('crabPartsSheet.png')
 frame('Crab',crab,0,'Raw Food','Cooking 12: right-click Break with a knife.')
 frame('Crab Parts',crab,1,'Shellfish Parts','Right-click Harvest in inventory for 1-5 raw Crab Meat.')
 local lw,lh=lobster:getDimensions();s.itemImages.Lobster=lobster;s.itemQuads.Lobster=love.graphics.newQuad(0,0,16,16,lw,lh);s.itemInfo.Lobster={title='Lobster',type='Raw Food',detail='Cooking 30: right-click Break with a knife.'}
 s.itemImages['Lobster Parts']=lobster;s.itemQuads['Lobster Parts']=love.graphics.newQuad(0,16,16,16,lw,lh);s.itemInfo['Lobster Parts']={title='Lobster Parts',type='Shellfish Parts',detail='Right-click Harvest in inventory for 1-5 raw Lobster Meat.'}
 s.lobsterPieceImage=pieces;s.lobsterPieceQuads={};local pw,ph=pieces:getDimensions();for i=0,2 do s.lobsterPieceQuads[i+1]=love.graphics.newQuad(i*16,0,16,16,pw,ph)end
 frame('Lobster Meat',lm,0,'Raw Food','Cook at Cooking 30. Stackable.')
 for _,grade in ipairs({'D','C','B','A'})do frame('Cooked Lobster Meat '..grade,lm,1,'Food','Grade '..grade..'. Potion belt compatible.')end;frame('Burnt Lobster Meat',lm,2,'Burnt Food','Restores 1 health.')
 s.fishingTierImages={};s.fishingTierQuads={}
 for _,v in ipairs({{'Shrimp Pot','shrimpPotSheet.png'},{'Oak Fishing Pole','toolOakFishingPole.png'},{'Poplar Fishing Pole','toolPoplarFishingPole.png'},{'Crab Pot','crabPotSheet.png'},{'Lobster Pot','lobsterPotSheet.png'}})do
 local im=v[1]=='Crab Pot'and pot or image(v[2]);frame(v[1],im,0,'Tool','Fishing '..F.tools[v[1]]..'. Equip to select, then click nearby shoreline water. '..(v[1]=='Crab Pot'and'Catches 1-10 crabs based on Fishing level.'or v[1]=='Poplar Fishing Pole'and'Catches Manta Ray.'or'Large Fish unlock at Fishing 7; Eels at 10. Oak poles catch Small Fish before level 7.'))
 if require('game.shellfish').levels[v[1]]then s.itemInfo[v[1]].type='Fishing Pot';s.itemInfo[v[1]].detail='Fishing '..F.tools[v[1]]..'. Right-click Place at the shore. Recover with left-click; Empty drops catches. Shrimp capacity increases to 15 at Fishing 20; other pots hold 10. Counts visible at Fishing 50. Placed pots are lost on logout.'end
 s.fishingTierImages[v[1]]=im;local w,h=im:getDimensions();s.fishingTierQuads[v[1]]={rest=love.graphics.newQuad(0,0,16,16,w,h),cast=love.graphics.newQuad(16,0,16,16,w,h),hook=love.graphics.newQuad(((require('game.shellfish').levels[v[1]]~=nil)and 1 or 2)*16,0,16,16,w,h)}
 end
end
function F.drawHeld(s,name,f,x,y,rot,sx,sy)
 local im=(s.fishingTierImages or{})[name]or s.fishingPoleImage;local q=(s.fishingTierQuads or{})[name]or s.fishingPoleQuads
 local phase=not f and'rest'or name=='Crab Pot'and(f.loaded and'hook'or'rest')or(f.timer<.5 and'hook'or'cast')
 love.graphics.draw(im,q[phase],x,y,rot,sx,sy,8,8)
end
return F
