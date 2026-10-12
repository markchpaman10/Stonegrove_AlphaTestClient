-- Shared food, processing and catch timing definitions.
local F={data={['Manta Ray']={level=20,x=64,y=0,extra=3,cook=2,process=1.5,fillets=4},Tuna={level=30,x=0,y=16,extra=4,cook=2.5,process=2,fillets=5,heals={70,85,100,115}},Swordfish={level=40,x=0,y=0,extra=5,cook=3,process=2.5,fillets=6},Shark={level=60,x=64,y=16,extra=6,cook=4,process=3,fillets=8,heals={120,145,170,195}}},processed={}}
for n in pairs(F.data)do F.processed['Raw '..n]=n end
function F.fillets(name,level)local d=F.data[name];return d and d.fillets+math.min(4,math.floor((level or 1)/20))end
function F.duration(name)local d=F.data[name];return d and d.process or .5 end
function F.configure(recipes)
 for _,station in ipairs({'stove','campfire'})do
  for _,r in ipairs(recipes[station])do local d=F.data[r.output];if d then r.duration=d.cook end end
  for n,d in pairs(F.data)do recipes[station][#recipes[station]+1]={name='Cook Prepared '..n,output='Raw '..n,qty=1,skill='Cooking',level=d.level,xp=require('game.whole_fish').xp[n],duration=d.cook,needs={{'Raw '..n,1}}}end
 end
end
function F.command(w,a,cmd)
 local bag=a.inv:getBag(cmd.bag);local obj=bag and bag.slots[cmd.slot];local d=obj and F.data[obj.name]
 if not d then return false,'Select a whole high-tier fish'end
 if a.skills:get('Cooking').level<7 then return false,'Requires Cooking 7'end
 local gear=a.equipment or{};if not require('game.tool_slot').has(a.inv,gear,'Copper Knife',a.player)then return false,'Need a knife'end
 local trial=require('game.rune_inventory').clone(a.inv);local input=trial:getBag(cmd.bag).slots[cmd.slot];input.qty=(input.qty or 1)-1;if input.qty<=0 then trial:getBag(cmd.bag).slots[cmd.slot]=nil end
 local output='Raw '..obj.name;if not require('game.quality').add(trial,output,1,a.skills:get('Cooking').level,require('game.inventory').add)then return false,'Make room for the prepared fish'end
 a.inv.bagSlots=trial.bagSlots;a.skills:addXP('Cooking',math.ceil(d.level/2));return true,'Prepared '..output
end
function F.install(UI)
 local options=UI.contextOptions;UI.contextOptions=function(u,it)local rows=options(u,it);if F.data[it.name]then table.insert(rows,1,'Process Fish')end;return rows end
 local use=UI.doContextOption;UI.doContextOption=function(u,opt)if opt~='Process Fish'then return use(u,opt)end;local c=u.context;u.context=nil;if not c then return false end;local bag=u.inv:getBag(c.bag);local it=bag and bag.slots[c.slot];return require('game.fieldcraft_ui').timedOffline(u,{op='fishProcess',bag=c.bag,slot=c.slot,fish=it and it.name})end
end
function F.load(s)
 local im=love.graphics.newImage('assets/high_tier_fish.png');im:setFilter('nearest','nearest');local food=require('game.food')
 for name,d in pairs(F.data)do
  local function icon(n,x,typ,detail)s.itemImages[n]=im;s.itemQuads[n]=love.graphics.newQuad(x,d.y,16,16,im:getDimensions());s.itemInfo[n]={title=n,type=typ,detail=detail,heal=food.healing[n]}end
  icon(name,d.x,'Raw Food','Fishing '..d.level..' with a Pine pole or better. Right-click Process Fish: prepared raw food. Cooking '..d.level..' whole ('..d.cook..'s), or prepare fillets with a knife at Cooking 7 ('..d.process..'s). Longer catch: +'..d.extra..'s.')
  icon('Raw '..name,d.x+16,'Raw Food','Prepared '..name..'. Cook at Cooking '..d.level..' ('..d.cook..'s). Right-click the whole fish to Process with a knife at Cooking 7.')
  for i,g in ipairs({'D','C','B','A'})do local n='Cooked '..name..' '..g;if d.heals then food.healing[n]=d.heals[i]end;icon(n,d.x+32,'Food','Grade '..g..'. Cooking '..d.level..'. Restores '..food.healing[n]..' health.')end
  food.healing['Burnt '..name]=1;icon('Burnt '..name,d.x+48,'Burnt Food','Restores 1 health; sells for 1 copper.')
 end
end
function F.isFood(name)return type(name)=='string'and(name:match('^Cooked Tuna [DCBA]$')or name:match('^Cooked Shark [DCBA]$')or name:match('^Cooked Manta Ray [DCBA]$'))~=nil end
return F
