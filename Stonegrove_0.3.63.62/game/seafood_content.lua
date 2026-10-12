local S={tailHealing={70,85,100,115},surfHealing={85,100,115,130}}
function S.tailChance(level)return .05+.10*math.max(0,math.min(69,(level or 30)-30))/69 end
function S.isFood(name)return type(name)=='string'and(require('game.high_tier_fish').isFood(name)or name:match('^Cooked Lobster Tail [DCBA]$')or name:match('^Surf and Turf [DCBA]$'))~=nil end
function S.stackable(name)return require('game.high_tier_fish').processed[name]~=nil or name=='Burnt Tuna'or name=='Burnt Shark'or name=='Raw Lobster Tail'or S.isFood(name)or name=='Burnt Lobster Tail'or name=='Burnt Surf and Turf'end
function S.configure(recipes)
 for _,station in ipairs({'stove','campfire'})do
  recipes[station][#recipes[station]+1]={name='Cook Lobster Tail',output='Cooked Lobster Tail',qty=1,level=30,skill='Cooking',xp=90,seafood=true,needs={{'Raw Lobster Tail',1}}}
  recipes[station][#recipes[station]+1]={name='Surf and Turf',output='Surf and Turf',qty=1,level=30,skill='Cooking',xp=110,seafood=true,needs={{'Raw Lobster Tail',1},{'Large Meat',1}}}
 end
end
function S.cook(r,station,inv,skills,logger)
 local trial=require('game.rune_inventory').clone(inv)
 for _,n in ipairs(r.needs)do if not trial:removeItems(n[1],n[2])then return false,'missing_'..n[1]end end
 local level=skills:get('Cooking').level;local burnt=math.random(1,100)<=math.max(3,(station=='campfire'and 52 or 32)-level)
 local output=burnt and(r.output=='Surf and Turf'and'Burnt Surf and Turf'or'Burnt Lobster Tail')or(r.output..' '..require('game.quality').roll(level))
 if not trial:add(output,1)then return false,'bags_full'end
 inv.bagSlots=trial.bagSlots;local old,new,total=skills:addXP('Cooking',r.xp)
 if logger then logger:log('FOOD_COOKED',{raw=r.output,output=output,cookingLevel=new,xpGained=r.xp,totalXp=total});if new>old then logger:log('SKILL_LEVEL_UP',{skill='Cooking',from=old,to=new,totalXp=total})end end
 return true,output,r.xp
end
function S.load(s)
 local plate=love.graphics.newImage('assets/surfAndTurf.png');plate:setFilter('nearest','nearest')
 local tail=love.graphics.newImage('assets/lobsterTailSheet.png');tail:setFilter('nearest','nearest')
 local function icon(name,image,x,typ,detail,heal)
  s.itemImages[name]=image;s.itemQuads[name]=x and love.graphics.newQuad(x,0,16,16,image:getDimensions())or nil
  s.itemInfo[name]={title=name,type=typ,detail=detail,heal=heal}
 end
 icon('Raw Lobster Tail',tail,0,'Raw Food','Rare bonus when breaking lobsters. Cooking increases the chance from 5% at 30 to 15% at 99. Cook at level 30, or combine with 1 raw Large Meat for Surf and Turf.')
 local food=require('game.food')
 for i,grade in ipairs({'D','C','B','A'})do
  local name='Cooked Lobster Tail '..grade;food.healing[name]=S.tailHealing[i];icon(name,tail,16,'Food','Cooking 30: 1 Raw Lobster Tail. Grade '..grade..'.',S.tailHealing[i])
  name='Surf and Turf '..grade;food.healing[name]=S.surfHealing[i];icon(name,plate,nil,'Food','Cooking 30: 1 Raw Lobster Tail + 1 raw Large Meat. Grade '..grade..'.',S.surfHealing[i])
 end
 food.healing['Burnt Lobster Tail']=1;icon('Burnt Lobster Tail',tail,32,'Burnt Food','Burnt lobster tail. Restores 1 health.',1)
 food.healing['Burnt Surf and Turf']=1;icon('Burnt Surf and Turf',s.itemImages['Burnt Large Meat']or plate,nil,'Burnt Food','Burnt Surf and Turf. Restores 1 health.',1)
 local d=s.itemInfo['Lobster'];if d then d.detail=(d.detail or'')..' Break all carried lobsters with a knife at Cooking 30. Rare bonus Raw Lobster Tail: 5% at 30, rising to 15% at 99.'end
end
return S
