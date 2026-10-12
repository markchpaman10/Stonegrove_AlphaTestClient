local NodeIndex=require("game.node_index")
local Expansion=require("game.expansion")
local Villages=require("game.villages")
local Houses=require("game.houses")
local Combat=require("game.combat")
local Map=require("game.map")
local Zones=require("game.zones")
local Shop=require("game.shop")
local World={};World.__index=World
local function hasToolEquivalent(inventory,equipped,tool)
 return require('game.tool_slot').has(inventory,equipped,tool)
end
local defs={tree={skill="Woodcutting",item="Pine Logs",tool="Copper Axe",xp=25,hp=6,respawn=300,reach=21,level=1},oak={skill="Woodcutting",item="Oak Logs",tool="Copper Axe",xp=55,hp=9,respawn=600,reach=24,level=require("game.unlocks").extra.Woodcutting[2][1]},copper={skill="Mining",item="Small Copper Chunk",tool="Copper Pickaxe",xp=17.5,hp=4,respawn=300,reach=19},tin={skill="Mining",item="Tin ore",tool="Copper Pickaxe",xp=17.5,hp=4,respawn=300,reach=38},hemp={skill="Fletching",item="Hemp Fibers",tool="Copper Dagger",xp=0,hp=2,respawn=180,reach=38},flax={skill="Jewel Crafting",item="Flax",tool=nil,xp=0,hp=2,respawn=240,reach=38},blueMushroom={skill="Alchemy",item="Large Blue Mushroom",tool=nil,xp=4,hp=1,respawn=180,reach=34},brownMushroom={skill="Alchemy",item="Brown Mushroom",tool=nil,xp=3,hp=1,respawn=150,reach=34},bushRoot={skill="Alchemy",item="Bush Root",tool=nil,xp=4,hp=1,respawn=240,reach=34},bushGreens={skill="Alchemy",item="Bush Greens",tool=nil,xp=3,hp=1,respawn=180,reach=34},purpleBerry={skill="Alchemy",item="Purple Berries",tool=nil,xp=4,hp=1,respawn=210,reach=34},redBerry={skill="Alchemy",item="Red Berries",tool=nil,xp=3,hp=1,respawn=180,reach=34}}
defs.poplar={skill="Woodcutting",item="Poplar Logs",tool="Copper Axe",xp=85,hp=12,respawn=900,reach=24,level=30}
defs.coal={skill="Mining",item="Small Coal Chunk",tool="Copper Pickaxe",xp=55,hp=7,respawn=480,reach=24,level=27}
defs.iron={skill="Mining",item="Small Iron Chunk",tool="Copper Pickaxe",xp=40,hp=6,respawn=420,reach=24,level=15}
local function addPatch(nodes,cx,cy,kind,count,radius) for i=1,count do local a=math.random()*math.pi*2;local r=math.sqrt(math.random())*radius;nodes[#nodes+1]={x=cx+math.cos(a)*r,y=cy+math.sin(a)*r,kind=kind,hp=defs[kind].hp,maxHp=defs[kind].hp,depleted=false,respawnTimer=0,shake=0} end end
local function addBerryBush(nodes,x,y,berryType)
 local count=math.random(1,5)
 nodes[#nodes+1]={x=x,y=y,kind="berryBush",berryType=berryType,stage="berries",berryCount=count,hp=count,maxHp=count,depleted=false,respawnTimer=0,shake=0}
end
local function clearForHubOrPath(x,y,cx,cy)
 if math.abs(x-cx)<62 then return false end
 local dx,dy=x-cx,y-cy
 return dx*dx+dy*dy>=245*245
end
local enemyDefs={
 goblin={baseLevel=3,tierMin=1,tierMax=1,melee=3,ranged=0,strength=2,agility=2,health=2,mainSkill="Melee Combat",aggro=80,leash=150,roam=40,speed=28,attackRange=25,rangedRange=0,attackSpeed=1.5},
 slime={baseLevel=3,tierMin=1,tierMax=3,melee=2,ranged=3,strength=2,agility=1,health=2,mainSkill="Ranged",aggro=72,leash=170,roam=45,speed=24,attackRange=26,rangedRange=68,attackSpeed=1.55},
 rat={baseLevel=1,tierMin=1,tierMax=1,melee=1,ranged=0,strength=1,agility=1,health=1,mainSkill="Melee Combat",aggro=50,leash=135,roam=32,speed=24,attackRange=25,rangedRange=0,attackSpeed=1.75},
 wolf={baseLevel=4,tierMin=1,tierMax=3,melee=3,ranged=0,strength=3,agility=2,health=2,mainSkill="Melee Combat",aggro=95,leash=210,roam=58,speed=38,attackRange=30,rangedRange=0,attackSpeed=1.15},
 chicken={baseLevel=1,tierMin=1,tierMax=1,melee=1,ranged=0,strength=1,agility=1,health=1,mainSkill="Melee Combat",aggro=0,leash=80,roam=28,speed=22,attackRange=20,rangedRange=0,attackSpeed=2.0},
 cow={baseLevel=2,tierMin=1,tierMax=1,melee=1,ranged=0,strength=2,agility=1,health=3,mainSkill="Melee Combat",aggro=0,leash=100,roam=35,speed=18,attackRange=24,rangedRange=0,attackSpeed=2.2}
}
for kind,def in pairs(Expansion.defs) do enemyDefs[kind]=def end
local function makeEnemy(kind,x,y,tier)
 local customId=kind and kind:match('^custom:(.+)$');local custom=customId and require('game.custom_content').monster(customId);local realKind=custom and (custom.baseSprite=='humanoid'and'goblin'or custom.baseSprite or'rat') or (customId and 'rat' or kind)
 local d=custom and {baseLevel=tonumber(custom.level)or 1,tierMin=1,tierMax=1,melee=tonumber(custom.melee)or 1,ranged=tonumber(custom.ranged)or 0,strength=tonumber(custom.strength)or 1,agility=tonumber(custom.agility)or 1,health=tonumber(custom.health)or 1,mainSkill=(tonumber(custom.ranged)or 0)>0 and 'Ranged' or 'Melee Combat',aggro=tonumber(custom.aggro)or 60,leash=180,roam=40,speed=tonumber(custom.speed)or 24,attackRange=26,rangedRange=80,attackSpeed=1.5} or enemyDefs[realKind];tier=tier or math.random(d.tierMin,d.tierMax)
 local stats={melee=d.melee*tier,ranged=d.ranged*tier,strength=d.strength*tier,agility=d.agility*tier,health=d.health*tier}
 local main=(d.mainSkill=="Ranged") and stats.ranged or stats.melee
 local maxHp=math.max(5,stats.health*5)
 local result={id=customId,humanoid=custom and custom.baseSprite=='humanoid',race=custom and custom.race,gender=custom and custom.gender,equipment=custom and require('game.custom_content').equipment(custom),kind=realKind,customDefinition=custom and d or nil,customMonster=customId,customName=custom and custom.name or nil,x=x,y=y,spawnX=x,spawnY=y,tier=tier,level=d.baseLevel*tier,stats=stats,mainSkill=d.mainSkill,mainCombat=main,hp=maxHp,maxHp=maxHp,attackTimer=math.random()*d.attackSpeed,respawnTimer=0,dead=false,skinned=false,state="idle",roamTimer=math.random()*2+1,roamX=x,roamY=y,aggro=false,poisonTimer=0}
 if custom and realKind=='goblin'then require('game.goblins').equip(result);result.headVariant=1;result.bodyVariant=1;result.direction='down';result.walkTime=0 end
 if realKind=='nagalian'then require('game.nagalians').appearance(result)end
 return result
end
function World.new(sprites,authored)
 math.randomseed(((authored and authored.seed or os.time())+(SG_SERVER_GENERATION or 0))%2147483647)
 local map=Map.new(authored);if map.authored and map.authored.levelZones then local ok,why=require('game.level_zones').validate(map.authored);assert(ok,why)end;local firstSite=Zones.villageSites(map)[1];local cx,cy=firstSite.x,firstSite.y
 local townTypes={'large','medium','small'};local townType=townTypes[math.random(1,#townTypes)]
 local self=setmetatable({sprites=sprites,map=map,placedContainers={},nodes={},swings={},gather=nil,groundItems={},copperSawmill={x=cx+450,y=cy+90},ironSawmill={x=cx+480,y=cy+90},steelSawmill={x=cx+510,y=cy+90},bankChest={x=cx,y=cy+24},shopkeeper={x=cx,y=cy},mercRecruiter={x=cx+30,y=cy},bankClerk={x=cx-30,y=cy},mercs={},smelter={x=cx-150,y=cy-96},anvil={x=cx,y=cy-126},tanningVat={x=cx+150,y=cy-96,jobs={}},hideStretcher={x=cx+184,y=cy+10,state="empty",timer=0},spinningWheel={x=cx+120,y=cy+132},alchemy={x=cx-120,y=cy+132},stove={x=cx-184,y=cy+10},magicAltar={x=cx+250,y=cy-150},religionAltar={x=cx+250,y=cy-115},socketTable={x=cx+285,y=cy-80},enchantAltar={x=cx+335,y=cy-80},inscription={x=cx+335,y=cy+10},metalLoom={x=cx+405,y=cy+90},loom={x=cx+365,y=cy+90},tailoring={x=cx+335,y=cy+90},enemies={},sheep={},farmAnimals={},popups={},combatTarget=nil,targetedEnemy=nil,enemyProjectiles={},playerArrows={},mercArrows={},magicProjectiles={},magicEffects={},juiceParticles={},slimePuddles={},grass={},campfires={},fishing=nil,houses={},paths={},notifications={},tradeKeepers={},healers={},traders={},standingTorches={},townType=townType},World)
 -- Village pass: one home/workshop for every permanent crafting station.
 -- The crafting table sits outside its matching house, facing the market center.
 self.houses={
  {x=cx-170,y=cy-125,roof=1,room=1,story=false,station="smelter"},
  {x=cx,y=cy-165,roof=2,room=2,story=true,station="anvil"},
  {x=cx+170,y=cy-125,roof=1,room=2,story=false,station="tanningVat"},
  {x=cx+220,y=cy+10,roof=2,room=1,story=true,station="hideStretcher"},
  {x=cx+145,y=cy+165,roof=1,room=1,story=false,station="spinningWheel"},
  {x=cx-145,y=cy+165,roof=2,room=2,story=false,station="alchemy"},
  {x=cx-220,y=cy+10,roof=1,room=2,story=true,station="stove"},
  {x=cx+285,y=cy-185,roof=2,room=2,story=false,station="magicAltar"},{x=cx+285,y=cy-145,roof=1,room=1,story=false,station="religionAltar"},
  {x=cx+335,y=cy-120,roof=1,room=1,story=false,station="socketTable"},
  {x=cx+405,y=cy-70,roof=2,room=2,story=false,station="enchantAltar"},
  {x=cx+405,y=cy+20,roof=1,room=2,story=false,station="inscription"},
  {x=cx+405,y=cy+110,roof=2,room=1,story=false,station="tailoring"},
  {x=cx-300,y=cy+205,roof=1,room=1,story=false,station="healer"},
  {x=cx-300,y=cy+65,station="fisherman"}
 }
 self.houseSeed=(authored and authored.seed) or love.math.random(1,2147483646)
 Houses.generate(self.houses,self.houseSeed)
 -- Standing town torches automatically follow the day/night cycle.
 for _,house in ipairs(self.houses) do self.standingTorches[#self.standingTorches+1]={x=house.x+30,y=house.y+18} end
 -- Gravel lanes run from the central market to each workshop/home.
 self.paths={
  -- 32px village roads: a small market square with clean orthogonal lanes.
  {x=cx-48,y=cy-32,w=96,h=64},
  {x=cx-16,y=cy-132,w=32,h=112},
  {x=cx-16,y=cy+20,w=32,h=112},
  {x=cx-187,y=cy-16,w=139,h=32},
  {x=cx+48,y=cy-16,w=139,h=32},
  {x=cx-170,y=cy-108,w=170,h=32},
  {x=cx,y=cy-108,w=170,h=32},
  {x=cx-145,y=cy+108,w=145,h=32},
  {x=cx,y=cy+108,w=145,h=32},
  {x=cx+170,y=cy-108,w=120,h=32},
  {x=cx+234,y=cy-150,w=32,h=74},
  {x=cx+250,y=cy-96,w=190,h=32},
  {x=cx+319,y=cy-185,w=32,h=310},
  {x=cx+389,y=cy-86,w=32,h=212},
  {x=cx-300,y=cy+160,w=32,h=65},
  {x=cx-300,y=cy+144,w=155,h=32},
  {x=cx-316,y=cy+90,w=32,h=70}
 }
 Villages.build(self)
 self.villages[1].townType=townType
 -- Test build: Area 1 rolls one of the three town archetypes each new world.
 -- Large keeps the complete service town. Medium keeps all crafting stations but trims vendor stock.
 -- Small is deliberately just a roadside settlement with houses and basic commerce.
 if townType=='small' then
  local kept={}
  for i=1,math.min(4,#self.houses) do
   local h=self.houses[((self.houseSeed+i*5)%#self.houses)+1]
   kept[#kept+1]={x=h.x,y=h.y,station=nil}
  end
  self.houses=kept;Houses.generate(self.houses,self.houseSeed+313)
  self.paths={{x=cx-48,y=cy-32,w=96,h=64}}
  self.standingTorches={}
  for _,key in ipairs(Villages.keys) do if key~='mercRecruiter' then self[key]={x=-10000,y=-10000} end end
  self.villages[1].bankChest=self.bankChest;self.villages[1].bankClerk=self.bankClerk
 elseif townType=='medium' then
  -- Medium towns have a bank but no bank-expansion clerk.
  self.bankClerk={x=-10000,y=-10000};self.villages[1].bankClerk=self.bankClerk
  -- Permanent central cooking fire. math.huge keeps the existing campfire renderer/interactions.
  self.campfires[#self.campfires+1]={x=cx,y=cy+42,timer=math.huge,permanent=true}
 end
 require("game.fences").prepare(self)
 -- Central general trader: convenient liquidation at only 25% of the normal generated sell value.
 -- Kept beside the banker/recruiter without overlapping the bank chest.
 self.traders={{x=cx,y=cy-30,race=((self.houseSeed+911)%2==0) and "Elf" or "Human",trade="Trader",shop=Shop.trader(nil,"Trader")}}
 -- Trade-house keepers replace the old master shop. Their race is deterministic from the
 -- saved house seed, so a keeper does not randomly change species every time the game starts.
 local tradeTools={fisherman={"Fishing Pole","Oak Fishing Pole","Poplar Fishing Pole","Crab Pot","Copper Dagger"},
  smelter={"Copper Tongs","Iron Tongs"},anvil={"Copper Hammer","Iron Hammer","Iron Shield","Iron Sword","Iron Axe","Iron Pickaxe"},tanningVat={"Copper Dagger"},hideStretcher={"Copper Dagger","Quiver"},
  spinningWheel={"Shears"},alchemy={"Copper Dagger"},stove={"Flint and Steel","Torch","Copper Dagger"},magicAltar={"Staff","Spellbook"},
  socketTable={"Chisel"},enchantAltar={"Chisel"},inscription={"Inscription Pen and Ink"},tailoring={"Needle","Shears"}
 }
 local tradeNames={fisherman="Fishing Supplies",smelter="Smelting Supplies",anvil="Smithing Supplies",tanningVat="Tanning Supplies",hideStretcher="Leatherworking Supplies",spinningWheel="Spinning Supplies",alchemy="Alchemy Supplies",stove="Cooking Supplies",magicAltar="Magic Supplies",socketTable="Jewelcraft Supplies",enchantAltar="Enchanting Supplies",inscription="Inscription Supplies",tailoring="Tailoring Supplies"}
 local tradeMaterials={fisherman={"Small Fish","Large Fish","Eel","Raw Fish Fillet"},
  smelter={"Small Copper Chunk","Large Copper Chunk","Copper Bar","Bronze bar","Small Iron Chunk","Large Iron Chunk","Iron Bar"},anvil={"Copper Bar","Bronze bar","Copper Arrowheads","Iron Bar","Iron Arrowheads"},
  tanningVat={"Raw Hide","Torn Hide","Soaked Hide","Large Raw Leather","Large Soaked Leather","Extra Large Raw Hide","Extra Large Soaked Hide"},hideStretcher={"Soaked Hide","Leather","Large Soaked Leather","Large Leather","Extra Large Soaked Hide","Extra Large Leather","Rawhide String","Pine Wood Parts","Oak Wood Parts"},
  spinningWheel={"Wool","Wool Thread","Hemp Fibers","Flax","Linen Cloth","Bow String"},alchemy={"Empty Flask","Empty Tube","Large Blue Mushroom","Brown Mushroom","Bush Root","Bush Greens","Purple Berries","Red Berries","Green Slime Jar","Giga Rat Blood","Pickled Large Meat","Pickled Small Meat","Potent Slime Jar","Slime-coated Bones"},
  stove={"Large Fish","Small Fish","Eel","Raw Fish Fillet","Large Meat","Small Meat"},magicAltar={"Pine Staff","Oak Staff","Spellbook","Stone Gravel","Charred Wood","Fish Bones","Carved Feather","Carved Onyx","Green Slime Tube"},
  socketTable={"Ruby-bearing Rock","Sapphire-bearing Rock","Emerald-bearing Rock","Rough Ruby","Rough Sapphire","Rough Emerald","Cut Ruby","Cut Sapphire","Cut Emerald"},
  enchantAltar={"Ruby Dust","Sapphire Dust","Emerald Dust","Melee Skill Page","Ranged Skill Page"},
  inscription={"Empty Spell Page","Melee Skill Page","Ranged Skill Page"},
  tailoring={"Wool","Wool Thread","Flax","Linen Cloth","Hemp Fibers","Cloth Strip","Dyed Blue Cloth Strip","Leather"}
 }
 require("game.vendor_catalog").complete(sprites,tradeTools,tradeMaterials)
 local raceIndex=0
 for _,house in ipairs(self.houses) do
  if tradeTools[house.station] then
   raceIndex=raceIndex+1
   local race=((self.houseSeed+raceIndex*37)%2==0) and "Elf" or "Human"
   local village=Villages.nearestData(self,house.x,house.y);local station=village and village[house.station]
   local candidates={{house.x,house.y+30},{house.x-36,house.y+10},{house.x+36,house.y+10}};local nx,ny=candidates[1][1],candidates[1][2];local best=-1
   for _,c in ipairs(candidates) do if self.map:isLand(c[1],c[2]) then local score=station and ((c[1]-station.x)^2+(c[2]-station.y)^2) or 0;if score>best then nx,ny,best=c[1],c[2],score end end end
   self.tradeKeepers[#self.tradeKeepers+1]={x=nx,y=ny,race=race,trade=house.station,shop=(function()
    local accepted,stock,seen={},{},{}
    if townType~='medium' then for _,v in ipairs(tradeTools[house.station] or {}) do accepted[v]=true;if not seen[v] then stock[#stock+1]=v;seen[v]=true end end end
    local mats=tradeMaterials[house.station] or {}
    local limit=townType=='medium' and math.min(#mats,math.max(1,math.ceil(#mats*.45))) or #mats
    for i=1,limit do local v=mats[i];accepted[v]=true;if not seen[v] then stock[#stock+1]=v;seen[v]=true end end
    return Shop.trade(nil,tradeNames[house.station],stock,accepted,tradeMaterials[house.station] or {},tradeTools[house.station] or {})
   end)()}
  elseif house.station=="healer" then
   raceIndex=raceIndex+1
   local race=((self.houseSeed+raceIndex*37)%2==0) and "Elf" or "Human"
   self.healers[#self.healers+1]={x=house.x,y=house.y+30,race=race}
  end
 end
 -- Central Misc Supplies vendor: convenience tools/items that are not tied to a dedicated trade house.
 local miscStock,miscAccepted=require("game.vendor_catalog").misc(sprites,self.tradeKeepers)
 for _,v in ipairs(self.villages) do
  self.tradeKeepers[#self.tradeKeepers+1]={x=v.cx+62,y=v.cy-30,race="Human",trade="misc",shop=Shop.trade(nil,"Misc Supplies",miscStock,miscAccepted,{},miscStock)}
 end
 -- Hostile wildlife lives well north of the settlement for this first island pass.
 self.enemies={makeEnemy("rat",cx-210,250),makeEnemy("rat",cx-135,305),makeEnemy("rat",cx+25,225),makeEnemy("wolf",cx+175,245),makeEnemy("wolf",cx+260,330),makeEnemy("slime",cx-25,365),makeEnemy("slime",cx+105,390)}
 for _,e in ipairs(self.enemies) do
  if e.kind=="rat" then e.dayOnly=true elseif e.kind=="wolf" then e.nightOnly=true;e.inactive=true end
 end
 -- Rats are common wilderness wildlife. Add a larger population across safe land away from villages.
 for i=1,28 do
  for attempt=1,200 do
   local x,y=math.random(100,map.width-100),math.random(100,map.height-100)
   if map:isLand(x,y) and Expansion.clearVillage(self,x,y,40) and not self:enemyBlocked(x,y) then local e=makeEnemy("rat",x,y,1);e.dayOnly=true;if e.kind=='nagalian'then require('game.nagalians').configure(self,e)end;self.enemies[#self.enemies+1]=e;break end
  end
 end
 -- Move legacy northern spawns inland when the expanded coastline covers their old coordinates.
 for _,e in ipairs(self.enemies) do
  while not map:isLand(e.x,e.y) and e.y<cy do e.y=e.y+16 end
  e.spawnY=e.y;e.roamY=e.y
 end
 -- Resources are distributed across the island, with denser woodland away from the central settlement.
 local patches={
 {cx-610,cy-300,"tree",78,280},{cx-650,cy+230,"tree",92,315},{cx-430,cy+500,"tree",58,245},
 {cx+590,cy-330,"tree",62,250},{cx+610,cy+300,"tree",70,270},{cx+350,cy+520,"tree",50,220},
 {cx-720,cy-40,"tree",48,210},{cx+720,cy+20,"tree",48,210},{cx-120,cy-560,"tree",42,190},{cx+150,cy+570,"tree",42,190},
 {cx-430,cy-80,"hemp",18,175},{cx+420,cy-40,"hemp",18,180},{cx-260,cy+330,"hemp",15,150},{cx+270,cy+330,"hemp",15,150},
 {cx-500,cy+130,"copper",34,170},{cx+500,cy+150,"copper",34,170},{cx-390,cy-390,"copper",24,135},{cx+390,cy-390,"copper",24,135},
 {cx-690,cy-170,"copper",22,130},{cx+690,cy-170,"copper",22,130},{cx-180,cy+560,"copper",20,125},{cx+190,cy+560,"copper",20,125},
 {cx-330,cy-210,"blueMushroom",10,175},{cx+330,cy-210,"brownMushroom",12,180},
 -- Expanded wilderness regions: broad forests and mining country well outside the towns.
 {cx-1500,cy-760,"oak",45,220},{cx-1320,cy+720,"tree",135,390},{cx+1450,cy-720,"oak",45,220},{cx+1370,cy+760,"tree",140,400},
 {cx-520,cy-1180,"tree",95,310},{cx+580,cy+1160,"tree",100,320},
 {cx-900,cy+1250,"flax",42,260},{cx+250,cy+1450,"flax",50,300},{cx+1100,cy+1180,"flax",38,240},
 {cx-1120,cy-180,"copper",55,220},{cx+1160,cy+120,"copper",58,225},{cx-720,cy+980,"copper",45,190},{cx+760,cy-980,"copper",45,190},
 {cx-1550,cy+250,"hemp",34,230},{cx+1540,cy-240,"hemp",34,230}
 }
 for _,p in ipairs(patches) do addPatch(self.nodes,p[1],p[2],p[3],p[4],p[5]) end
 for i=1,5200 do
  local x=math.random(90,map.width-90);local y=math.random(90,map.height-90)
  if map:isLand(x,y) and clearForHubOrPath(x,y,cx,cy) then
   local roll=math.random();local kind=(roll<.48) and "tree" or ((roll<.58) and "oak" or ((roll<.72) and "hemp" or "copper"))
   self.nodes[#self.nodes+1]={x=x,y=y,kind=kind,hp=defs[kind].hp,maxHp=defs[kind].hp,depleted=false,respawnTimer=0,shake=0}
  end
 end
 for i=1,90 do
  local x=math.random(100,map.width-100);local y=math.random(100,map.height-100)
  if map:isLand(x,y) and clearForHubOrPath(x,y,cx,cy) then addBerryBush(self.nodes,x,y,({'Red Berries','Purple Berries','Black Berries'})[(i%3)+1]) end
 end
 -- Cull anything that happened to scatter into water.
 for i=#self.nodes,1,-1 do if not map:isLand(self.nodes[i].x,self.nodes[i].y) then table.remove(self.nodes,i) end end
 
 -- Farm animals, including sheep, live around the three towns. Sheep are passive and regrow wool after shearing.
 for vi,v in ipairs(self.villages or {}) do
  local sheepN=(townType=='large' and 18) or (townType=='medium' and 5) or 0
  local chickenN=(townType=='large' and 14) or (townType=='medium' and 6) or 4
  local cowN=(townType=='large' and 7) or (townType=='medium' and 3) or 2
  for i=1,sheepN do local a=(i/math.max(1,sheepN))*math.pi*2+.25;local r=(townType=='large' and 330 or 180)+(i%3)*18;local x,y=v.cx+math.cos(a)*r,v.cy+math.sin(a)*r;if map:isLand(x,y) then self.sheep[#self.sheep+1]={x=x,y=y,homeX=x,homeY=y,wool=true,woolTimer=0,moveTimer=math.random()*3,vx=0,vy=0,townAnimal=true} end end
  for i=1,chickenN do local a=(i/chickenN)*math.pi*2;local r=(townType=='large' and 340 or 155)+(i%3)*22;local x,y=v.cx+math.cos(a)*r,v.cy+math.sin(a)*r;if map:isLand(x,y) then local e=makeEnemy("chicken",x,y,1);e.variant=(i%3==0) and "rooster" or "hen";e.hitRadius=8;e.townAnimal=true;self.enemies[#self.enemies+1]=e end end
  for i=1,cowN do local a=(i/cowN)*math.pi*2+.5;local r=(townType=='large' and 375 or 195);local x,y=v.cx+math.cos(a)*r,v.cy+math.sin(a)*r;if map:isLand(x,y) then local e=makeEnemy("cow",x,y,1);e.variant=(i%2)+1;e.hitRadius=14;e.townAnimal=true;self.enemies[#self.enemies+1]=e end end
 end
 -- Rebuild trees and ore as zone-aware wilderness resources. Each new world gets a different
 -- scatter, while the resource tier follows the region the player is exploring.
 for i=#self.nodes,1,-1 do local k=self.nodes[i].kind;if k=='tree' or (k=='oak' or k=='poplar') or k=='copper' or k=='tin' or k=='iron' or k=='coal' then table.remove(self.nodes,i) end end
 for i=1,5600 do
  for attempt=1,40 do
   local x,y=math.random(90,map.width-90),math.random(90,map.height-90)
   if map:isLand(x,y) and Expansion.clearVillage(self,x,y,55) and not require('game.authored_world').protected(self,x,y,0) then
    local zone=Zones.at(map,x,y);local kind=Zones.resourceKind(zone,math.random());local d=defs[kind]
    self.nodes[#self.nodes+1]={x=x,y=y,kind=kind,hp=d.hp,maxHp=d.hp,depleted=false,respawnTimer=0,shake=0,zone=zone}
    break
   end
  end
 end

 -- Decorative grass: deliberately excessive across open land. Keep the actual gravel roads and
 -- immediate building footprints readable, but otherwise let the island look properly overgrown.
 local function onVillagePath(x,y)
  for _,r in ipairs(self.paths) do if x>=r.x-8 and x<=r.x+r.w+8 and y>=r.y-8 and y<=r.y+r.h+8 then return true end end
  return false
 end
 local function nearHouse(x,y)
  for _,h in ipairs(self.houses) do if math.abs(x-h.x)<62 and math.abs(y-h.y)<58 then return true end end
  return false
 end
 for i=1,15000 do
  local x=math.random(24,map.width-24);local y=math.random(24,map.height-24)
  if map:isLand(x,y) and not onVillagePath(x,y) and not nearHouse(x,y) then self.grass[#self.grass+1]={x=x,y=y,variant=math.random(1,4)} end
 end
 Expansion.populate(self,makeEnemy)
 -- Area 1 content pass: the starting region intentionally contains only rats,
 -- normal trees, hemp and copper. Later zones are added outward from this baseline.
 for i=#self.enemies,1,-1 do local e=self.enemies[i];if e.kind~='rat' and not e.townAnimal then table.remove(self.enemies,i) end end
 self.farmAnimals={}
 for i=#self.nodes,1,-1 do
  local k=self.nodes[i].kind
  if k~='tree' and k~='hemp' and k~='copper' then table.remove(self.nodes,i) end
 end
 -- Area 1 density pass. Build resources in natural-looking clusters instead of
 -- sprinkling single nodes uniformly across a continent-sized zone.
 self.nodes={}
 local function validResourceSpot(x,y,margin)
  return x>80 and y>80 and x<map.width-80 and y<map.height-80
   and map:isLand(x,y) and Expansion.clearVillage(self,x,y,margin or 65)
   and clearForHubOrPath(x,y,cx,cy)
 end
 local function addNode(kind,x,y)
  local d=defs[kind]
  self.nodes[#self.nodes+1]={x=x,y=y,kind=kind,hp=d.hp,maxHp=d.hp,depleted=false,respawnTimer=0,shake=0,zone=1}
 end
 local function scatterClusters(kind,clusterCount,minPer,maxPer,radius)
  for c=1,clusterCount do
   local ax,ay
   for attempt=1,100 do
    local tx,ty=math.random(100,map.width-100),math.random(100,map.height-100)
    if validResourceSpot(tx,ty,85) then ax,ay=tx,ty;break end
   end
   if ax then
    local wanted=math.random(minPer,maxPer)
    for i=1,wanted do
     for attempt=1,24 do
      local angle=math.random()*math.pi*2
      -- sqrt(random) spreads points through the patch instead of making a bullseye.
      local dist=math.sqrt(math.random())*radius
      local x,y=ax+math.cos(angle)*dist,ay+math.sin(angle)*dist
      if validResourceSpot(x,y,60) then addNode(kind,x,y);break end
     end
    end
   end
  end
 end
 -- Dense woodland groves, hemp beds and smaller wild patches. These are intentionally
 -- far denser than 0.2.86, but clustered so open travel corridors still occur naturally.
 scatterClusters('tree',720,14,28,230)
 scatterClusters('hemp',360,7,16,145)
 -- A light background scatter prevents the spaces between clusters from feeling sterile.
 for i=1,2400 do
  local kind=(i<=1900) and 'tree' or 'hemp'
  for attempt=1,40 do
   local x,y=math.random(90,map.width-90),math.random(90,map.height-90)
   if validResourceSpot(x,y,65) then addNode(kind,x,y);break end
  end
 end
 -- Alchemy forage belongs in the FINAL resource pass too. Earlier world-generation
 -- creates these, but self.nodes is deliberately rebuilt above for Area 1 density,
 -- so mushrooms/bushes must be repopulated here rather than silently disappearing.
 scatterClusters('blueMushroom',24,4,8,115)
 scatterClusters('brownMushroom',30,5,10,125)
 for i=1,180 do
  for attempt=1,40 do
   local x,y=math.random(90,map.width-90),math.random(90,map.height-90)
   if validResourceSpot(x,y,65) then
    addBerryBush(self.nodes,x,y,({'Red Berries','Purple Berries','Black Berries'})[math.random(1,3)])
    break
   end
  end
 end
 -- Resource placement is complete here; use spatial collision during actor placement too.
 self._nodeIndexEnabled=true
 -- Rat population is rebuilt below as packs and loose wilderness spawns.
 for i=#self.enemies,1,-1 do if self.enemies[i].kind=='rat' then table.remove(self.enemies,i) end end
 local function addRat(x,y)
  for _,e in ipairs(self.enemies) do if e.kind=="rat" and (e.x-x)^2+(e.y-y)^2<56^2 then return false end end
  if map:isLand(x,y) and Expansion.clearVillage(self,x,y,55) and not self:enemyBlocked(x,y) then
   local e=makeEnemy('rat',x,y,1);e.dayOnly=true;e.zone=1
   self.enemies[#self.enemies+1]=e;return true
  end
 end
 -- Packs create visible wildlife hotspots; loose rats keep travel from becoming empty.
 for pack=1,40 do
  local ax,ay
  for attempt=1,80 do
   local x,y=math.random(120,map.width-120),math.random(120,map.height-120)
   if map:isLand(x,y) and Expansion.clearVillage(self,x,y,120) then ax,ay=x,y;break end
  end
  if ax then
   for i=1,math.random(3,5) do
    local a=math.random()*math.pi*2;local r=math.random(25,135)
    addRat(ax+math.cos(a)*r,ay+math.sin(a)*r)
   end
  end
 end
 for i=1,180 do
  for attempt=1,60 do
   local x,y=math.random(100,map.width-100),math.random(100,map.height-100)
   if addRat(x,y) then break end
  end
 end
 -- WoW/GW2-style regional combat bands. Farm animals remain low-level village creatures;
 -- wilderness enemies inherit the level range of the zone where they spawned.
 for _,e in ipairs(self.enemies) do
  if e.kind~='chicken' and e.kind~='cow' then
   local level,zone=Zones.level(map,e.x,e.y);e.zone=zone;e.level=level;e.tier=1
   local ranged=(e.stats and e.stats.ranged or 0)>0;e.stats=e.stats or {}
   e.stats.melee=level;e.stats.ranged=ranged and level or 0;e.stats.strength=math.max(1,math.floor(level*.65));e.stats.agility=math.max(1,math.floor(level*.8));e.stats.health=level
   e.mainCombat=ranged and e.stats.ranged or e.stats.melee;e.maxHp=math.max(5,level*5);e.hp=e.maxHp
  end
 end
 self.goblinSpawnTimer=90
 if math.random()<.25 then self:trySpawnGoblin() end
 for i=#self.nodes,1,-1 do local n=self.nodes[i];local clear=true
  for _,h in ipairs(self.houses) do if math.abs(n.x-h.x)<40 and math.abs(n.y-h.y)<40 then clear=false end end
  for _,p in ipairs(self.paths) do if n.x>p.x-8 and n.x<p.x+p.w+8 and n.y>p.y-8 and n.y<p.y+p.h+8 then clear=false end end
  if not clear then table.remove(self.nodes,i) end
 end
 require("game.fences").build(self)
 require("game.ore_seams").generate(self)
 -- World Editor test-map pass. Authored layout wins; wilderness resources remain procedural.
 local a=self.map.authored
 if a then
  self.paths={};for _,c in ipairs(a.paths or {}) do self.paths[#self.paths+1]={x=c.x,y=c.y,w=16,h=16} end;self.pathBatch=nil
  -- Authored fence collision. The editor stores the tall wall brush as style='largeGate'.
  -- Previously those tiles were deliberately excluded from fenceRails, so they rendered as
  -- walls but were completely absent from player/enemy/navigation collision. Build collision
  -- rails for BOTH normal fences and tall-wall autotiles.
  self.fenceRails={};self.largeGateTiles={};local fs,gs={},{}
  for _,c in ipairs(a.fences or {}) do
   local k=c.x..":"..c.y
   if c.style=='largeGate' then self.largeGateTiles[#self.largeGateTiles+1]={x=c.x,y=c.y};gs[k]=true else fs[k]=true end
  end
  local function addAuthoredRail(c,set,tall)
   local l=set[(c.x-16)..":"..c.y];local r=set[(c.x+16)..":"..c.y];local u=set[c.x..":"..(c.y-16)];local d=set[c.x..":"..(c.y+16)]
   if not l and not r and not u and not d then if ((c.rotation or 0)%2)==0 then l=true else u=true end end
   -- Tall-wall art is 32 px high and is drawn upward from the authored tile. Its physical
   -- footing is near the bottom of that sprite, hence the +8 y offset for horizontal walls.
   local ry=tall and (c.y+8) or c.y
   if l or r then self.fenceRails[#self.fenceRails+1]={x=c.x,y=ry,w=16,h=tall and 4 or 2,vertical=false,tallWall=tall} end
   if u or d then self.fenceRails[#self.fenceRails+1]={x=c.x,y=c.y,w=tall and 4 or 2,h=16,vertical=true,tallWall=tall} end
  end
  for _,c in ipairs(a.fences or {}) do if c.style=='largeGate' then addAuthoredRail(c,gs,true) else addAuthoredRail(c,fs,false) end end
  self.houses={};self.standingTorches={};self.largeGates={};self.watchTowers={};self.villages={}
  for _,o in ipairs(a.objects or {}) do
   if require('game.modular_houses').is(o) then self.houses[#self.houses+1]=require('game.modular_houses').configure(require('game.rune_inventory').copy(o))
   elseif o.id=='house1' or o.id=='house2' then self.houses[#self.houses+1]={x=o.x,y=o.y,roof=((o.variant or 1)-1)%2+1,room=(o.id=='house2') and 2 or 1,story=o.id=='house2'}
   elseif o.id=='standingTorch' then self.standingTorches[#self.standingTorches+1]={x=o.x,y=o.y}
   elseif o.id=='largeGate' then self.largeGates[#self.largeGates+1]={x=o.x,y=o.y,rotation=o.rotation or 0}
   elseif o.id=='watchTower' then self.watchTowers[#self.watchTowers+1]={x=o.x,y=o.y,roof=o.towerRoof~=false,ladder=o.towerLadder==true}
   elseif o.id=='bankChest' then self.bankChest={x=o.x,y=o.y}
   elseif o.id=='mercRecruiter' then self.mercRecruiter={x=o.x,y=o.y}
   elseif o.id=='bankClerk' then self.bankClerk={x=o.x,y=o.y}
   elseif o.id=='smelter' or o.id=='anvil' or o.id=='spinningWheel' or o.id=='alchemy' or o.id=='stove' or o.id=='magicAltar' or o.id=='religionAltar' or o.id=='socketTable' or o.id=='enchantAltar' or o.id=='inscription' or o.id=='tailoring' or o.id=='loom' or o.id=='metalLoom' then self[o.id]={x=o.x,y=o.y}
   elseif o.id=='tanningVat' then self.tanningVat={x=o.x,y=o.y,jobs={}}
   elseif o.id=='hideStretcher' then self.hideStretcher={x=o.x,y=o.y,state='empty',timer=0}
   end
  end
  require('game.houses').generate(self.houses,24681357)
  -- Authored-map exclusion geometry. Procedural wilderness must respect everything the mapper placed.
  local function inTownZone(x,y,pad) for _,z in ipairs(a.townZones or {})do if x>=z.x-pad and x<=z.x+z.w+pad and y>=z.y-pad and y<=z.y+z.h+pad then return true end end return false end
  local function nearPath(x,y,pad) for _,p in ipairs(self.paths or {}) do if x>=p.x-pad and x<=p.x+p.w+pad and y>=p.y-pad and y<=p.y+p.h+pad then return true end end return false end
  local function nearObject(x,y,pad) for _,o in ipairs(a.objects or {}) do if math.abs(x-o.x)<=pad and math.abs(y-o.y)<=pad then return true end end return false end
  local function nearHouse(x,y,pad) for _,h in ipairs(self.houses or {}) do if require("game.modular_houses").is(h) then local l,t,w,d=Houses.bounds(h);if x>=l-pad and x<=l+w+pad and y>=t-pad and y<=t+d+pad then return true end elseif math.abs(x-h.x)<=pad+34 and math.abs(y-h.y)<=pad+30 then return true end end return false end
  -- Trees/nodes never occupy authored paths, houses, NPCs, stations, torches, livestock, etc.
  for i=#self.nodes,1,-1 do local n=self.nodes[i];if not self.map:isLand(n.x,n.y) or inTownZone(n.x,n.y,0) or nearPath(n.x,n.y,18) or nearObject(n.x,n.y,28) or nearHouse(n.x,n.y,26) then table.remove(self.nodes,i) end end
  -- On authored maps, explicit editor spawn zones own wilderness enemy placement. Town animals remain authored/gameplay entities.
  if #(a.spawnZones or {})>0 then for i=#self.enemies,1,-1 do if not self.enemies[i].townAnimal then table.remove(self.enemies,i) end end end
  for i=#self.enemies,1,-1 do local e=self.enemies[i];if not self.map:isLand(e.x,e.y) or inTownZone(e.x,e.y,48) or nearPath(e.x,e.y,64) or nearObject(e.x,e.y,72) or nearHouse(e.x,e.y,96) then table.remove(self.enemies,i) end end
  local function safeEnemyPoint(x,y) return not require('game.regions').edgeProtected(self.map,x,y,64) and self.map:isLand(x,y) and not inTownZone(x,y,48) and not nearPath(x,y,64) and not nearObject(x,y,72) and not nearHouse(x,y,96) and not self:enemyBlocked(x,y) end
  for zoneIndex,z in ipairs(a.spawnZones or {}) do
   local kind=z.enemy or 'rat';local cid=kind:match('^custom:(.+)$');local cd=cid and require('game.custom_content').monster(cid);local def=cd and {baseLevel=tonumber(cd.level)or 1,melee=tonumber(cd.melee)or 1,ranged=tonumber(cd.ranged)or 0,strength=tonumber(cd.strength)or 1,agility=tonumber(cd.agility)or 1,health=tonumber(cd.health)or 1,mainSkill=(tonumber(cd.ranged)or 0)>0 and 'Ranged' or 'Melee Combat'} or enemyDefs[kind] or (cid and enemyDefs.rat)
   if def then for n=1,math.min(500,math.max(0,math.floor((tonumber(z.count) or 1)*math.max(0,math.min(3,tonumber(z.density)or 1))))) do for attempt=1,80 do
    local x=z.x+math.random()*math.max(1,z.w);local y=z.y+math.random()*math.max(1,z.h)
    local spaced=true;if kind=="rat" then for _,e in ipairs(self.enemies) do if e.kind=="rat" and (e.x-x)^2+(e.y-y)^2<48^2 then spaced=false;break end end end;if spaced and safeEnemyPoint(x,y) and(kind~='nagaQueen'or require('game.naga_queen').allowed(self,x,y))then local e=makeEnemy(kind,x,y,1);if e.kind=='nagaQueen'then e.hitRadius=36;e.customName='Naga Queen'end;local lv=e.kind=='nagaQueen'and math.max(1,math.min(100,tonumber(z.level)or 12))or e.kind=='nagalian'and select(2,require('game.level_zones').range(map))or require('game.level_zones').spawnLevel(map,z,x,y);local scale=math.max(e.kind=='nagaQueen'and 0 or .5,lv/math.max(1,def.baseLevel or 1));e.level=lv;e.stats.melee=math.max(1,math.floor(def.melee*scale+.5));e.stats.ranged=math.max(0,math.floor(def.ranged*scale+.5));e.stats.strength=math.max(1,math.floor(def.strength*scale+.5));e.stats.agility=math.max(1,math.floor(def.agility*scale+.5));e.stats.health=math.max(1,math.floor(def.health*scale+.5));e.mainCombat=(def.mainSkill=='Ranged') and e.stats.ranged or e.stats.melee;e.maxHp=math.max(5,e.stats.health*5);e.hp=e.maxHp;e.editorSpawnZone=zoneIndex;if kind=='goblin' then require('game.goblins').equip(e);e.headVariant=math.random(1,2);e.bodyVariant=math.random(1,3);e.direction='down';e.walkTime=0 end;if e.kind=='nagalian'then require('game.nagalians').configure(self,e)end;self.enemies[#self.enemies+1]=e;break end
   end end end
  end
 end
 if a then require('game.authored_world').finish(self,a,makeEnemy) end
 self.customNPCs={};if a then for _,o in ipairs(a.objects or {})do local id=o.id and o.id:match('^customNPC:(.+)$');local d=id and require('game.custom_content').npc(o.npcDefinition and o.npcDefinition~=''and o.npcDefinition or id);if d then self.customNPCs[#self.customNPCs+1]={x=o.x,y=o.y,homeX=o.x,homeY=o.y,id=id,name=d.name or id,editorLabel=d.editorLabel or'',race=d.race or'Human',gender=d.gender,role=d.role or'Citizen',dialogue=d.dialogue or'',behavior=d.behavior or'Stand Still',wanderRadius=tonumber(d.wanderRadius) or 72,eventId=o.eventId~=nil and o.eventId or d.eventId,storyEventId=o.storyEventId~=nil and o.storyEventId or d.storyEventId,questIds={o.questId~=nil and o.questId or d.quest1,d.quest2,d.quest3,d.quest4,d.quest5,d.quest6,d.quest7,d.quest8,d.quest9,d.quest10,d.quest11,d.quest12},key=d.appearanceKey or id,equipment=require('game.custom_content').equipment(d)} end end end
 if a then for _,o in ipairs(a.objects or{})do local id=o.id and o.id:match('^customItem:(.+)$');if id and require('game.custom_content').item(id)then self:addGroundItem(id,o.x,o.y,false,{name=id,qty=math.max(1,math.floor(tonumber(o.qty)or 1))})end end end
 require('game.npc_bindings').apply(self)
 require('game.level_zones').populate(self)
 -- Final world-creation resource overlap cleanup. Resource clusters are intentionally
 -- generous during generation, then this spatial pass removes physical overlaps once.
 -- Keeping the first valid resource makes the result deterministic for a given world seed
 -- and avoids the old O(n^2) all-resource collision scan on these very large maps.
 do
  local cellSize=32
  local grid={}
  local kept={}
  local function resourceRadius(n)
   local k=n.kind
   if k=='tree' or (k=='oak' or k=='poplar') then return 13 end
   if k=='copper' or k=='tin' or k=='iron' or k=='coal' then return 12 end
   if k=='blueMushroom' or k=='brownMushroom' then return 9 end
   if k=='bushRoot' or k=='bushGreens' or k=='purpleBerry' or k=='redBerry' or k=='berryBush' then return 12 end
   if k=='hemp' or k=='flax' then return 9 end
   return 10
  end
  local function key(gx,gy) return gx..':'..gy end
  for _,n in ipairs(self.nodes) do
   local r=resourceRadius(n)
   local gx,gy=math.floor(n.x/cellSize),math.floor(n.y/cellSize)
   local overlaps=false
   for yy=gy-1,gy+1 do
    for xx=gx-1,gx+1 do
     local bucket=grid[key(xx,yy)]
     if bucket then
      for _,other in ipairs(bucket) do
       local rr=r+other._overlapRadius
       local dx,dy=n.x-other.x,n.y-other.y
       if dx*dx+dy*dy<rr*rr then overlaps=true;break end
      end
     end
     if overlaps then break end
    end
    if overlaps then break end
   end
   if not overlaps then
    n._overlapRadius=r
    kept[#kept+1]=n
    local k=key(gx,gy);grid[k]=grid[k] or {};grid[k][#grid[k]+1]=n
   end
  end
  for _,n in ipairs(kept) do n._overlapRadius=nil end
  self.nodes=kept
 end
 require('game.goblin_camps').generate(self)
 self._nodeIndexEnabled=true
 require("game.wildlife").update(self,10)
 require('game.resource_placement').clean(self)
 require('game.nagalians').generate(self)
 require('game.town_decorations').setup(self)
 require("game.cursed_enemies").world(self)
 return self
end
-- Rare encounters: bounded population and collision-safe wilderness positions.
function World:trySpawnGoblin(player)
 if not self.isCave then return false end
 local count=0;for _,e in ipairs(self.enemies) do if e.kind=="goblin" and not e.dead then count=count+1 end end
 if count>=4 then return false end
 for attempt=1,100 do
  local x,y=math.random(64,self.map.width-64),math.random(64,self.map.height-64)
  local cx,cy=self.map.width/2,self.map.height/2
  local away=not player or (x-player.x)^2+(y-player.y)^2>160^2
  if away and Expansion.clearVillage(self,x,y,30) and clearForHubOrPath(x,y,cx,cy) and not self:enemyBlocked(x,y) then
   local e=makeEnemy("goblin",x,y,1);e.nightOnly=true;e.inactive=not self._nightState
   require("game.goblins").equip(e)
   e.headVariant=math.random(1,2);e.bodyVariant=math.random(1,3);e.direction="down";e.walkTime=0
   self.enemies[#self.enemies+1]=e;return true,e
  end
 end
 return false
end
function World:zoneAt(x,y) return Zones.at(self.map,x,y) end
function World:zoneInfo(x,y) local id=Zones.at(self.map,x,y);return id,Zones.info(self.map,x,y) end
function World:playerInZone(id) local p=self.playerRef;return p and Zones.at(self.map,p.x,p.y)==id end
function World:bankChestAt(x,y) if self.authoredObjects then return require("game.authored_world").at(self,x,y,"bankChest") end;local dx,dy=x-self.bankChest.x,y-self.bankChest.y;return dx*dx+dy*dy<18*18 end
function World:stationAt(x,y) if self.authoredObjects then for _,id in ipairs({'smelter','anvil','tanningVat','hideStretcher','spinningWheel','loom','metalLoom','alchemy','stove','magicAltar','religionAltar','socketTable','enchantAltar','inscription','tailoring'})do local o=require('game.authored_world').at(self,x,y,id);if o then return id,o end end end;for _,v in ipairs({{"smelter",self.smelter},{"anvil",self.anvil},{"tanningVat",self.tanningVat},{"hideStretcher",self.hideStretcher},{"spinningWheel",self.spinningWheel},{"loom",self.loom},{"metalLoom",self.metalLoom},{"alchemy",self.alchemy},{"stove",self.stove},{"magicAltar",self.magicAltar},{"religionAltar",self.religionAltar},{"socketTable",self.socketTable},{"enchantAltar",self.enchantAltar},{"inscription",self.inscription},{"tailoring",self.tailoring}}) do local dx,dy=x-v[2].x,y-v[2].y;if dx*dx+dy*dy<16*16 then return v[1] end end;for _,f in ipairs(self.campfires) do local dx,dy=x-f.x,y-f.y;if dx*dx+dy*dy<18*18 then return "campfire",f end end end
function World:bankClerkAt(x,y) if self.authoredObjects then return require("game.authored_world").at(self,x,y,"bankClerk") end;local dx,dy=x-self.bankClerk.x,y-self.bankClerk.y;return dx*dx+dy*dy<14*14 end
function World:shopkeeperAt(x,y) return false end
function World:tradeKeeperAt(x,y) for _,n in ipairs(self.tradeKeepers) do local dx,dy=x-n.x,y-n.y;if dx*dx+dy*dy<14*14 then return n end end;for _,n in ipairs(self.traders or {}) do local dx,dy=x-n.x,y-n.y;if dx*dx+dy*dy<14*14 then return n end end end
function World:healerAt(x,y) for _,n in ipairs(self.healers) do local dx,dy=x-n.x,y-n.y;if dx*dx+dy*dy<14*14 then return n end end end
function World:useHealer(player,inventory,logger)
 if (player.slimeCoated or 0)>0 then self:addPopup(player.x,player.y-20,"SLIME BLOCKS HEALING","miss");return false,"slimed" end
 if player.hp>=player.maxHp then self:addPopup(player.x,player.y-20,"ALREADY HEALTHY","miss");return false,"full_health" end
 local cost=500
 if inventory:moneyCopper()<cost then self:addPopup(player.x,player.y-20,"NEED 5 SILVER","miss");return false,"not_enough_currency" end
 if not inventory:removeMoney(cost) then return false,"currency_error" end
 local healed=player.maxHp-player.hp;player.hp=player.maxHp;self:addPopup(player.x,player.y-20,"HEALED +"..math.floor(healed),"defeat")
 if logger then logger:log("HEALER_USED",{cost=cost,healed=healed}) end
 return true,healed
end
function World:mercRecruiterAt(x,y) if self.authoredObjects then return require("game.authored_world").at(self,x,y,"mercRecruiter") end;local dx,dy=x-self.mercRecruiter.x,y-self.mercRecruiter.y;return dx*dx+dy*dy<14*14 end

function World:emitJuice(x,y,kind,count,color)
 count=count or 5
 for i=1,count do
  local a=math.random()*math.pi*2;local sp=10+math.random()*22
  self.juiceParticles[#self.juiceParticles+1]={x=x,y=y,vx=math.cos(a)*sp,vy=math.sin(a)*sp-8,kind=kind or "dust",color=color,time=.35+math.random()*.25,maxTime=.6}
 end
end
function World:enemyJuiceColor(enemy)
 if not enemy then return {.85,.85,.85} end
 local s=self.sprites
 return (s and s.objectColors and s.objectColors[enemy.kind]) or {.85,.85,.85}
end
function World:objectJuiceColor(kind)
 local s=self.sprites
 return (s and s.objectColors and s.objectColors[kind]) or {.85,.85,.85}
end
function World:craftJuice(station,player,item)
 require("game.audio").craft(station,item,player.x,player.y)
 local st=self[station];local x,y=(st and st.x or player.x),(st and st.y or player.y)
 local kind=(station=="anvil" and "spark") or (station=="smelter" and "ember") or (station=="alchemy" and "bubble") or (station=="stove" and "steam") or (station=="spinningWheel" and "fiber") or "craft"
 self:emitJuice(x,y-5,kind,station=="anvil" and 10 or 6,self:objectJuiceColor(station));self:addPopup(x,y-20,"CRAFTED "..string.upper(item or "ITEM"),"defeat")
end
function World:createCampfire(player,inventory,skills,logger,fuelChoice)
 if inventory:countItem("Flint and Steel")<1 then return false,"missing_flint_and_steel" end
 local fuel=fuelChoice or (inventory:countItem("Pine Logs")>0 and "Pine Logs" or (inventory:countItem("Oak Logs")>0 and "Oak Logs" or "Logs"));if fuel~="Pine Logs" and fuel~="Oak Logs" and fuel~="Logs" and fuel~="Poplar Logs" then return false,"invalid_fuel" end;if inventory:countItem(fuel)<1 then return false,"missing_logs" end
 if fuel=="Oak Logs" then local ok,why=require("game.unlocks").action(skills,"oakFire");if not ok then self:addPopup(player.x,player.y-24,why);return false,why end end
 local x,y=player.x+18,player.y+8;if not self.map:isLand(x,y) then x,y=player.x-18,player.y+8 end
 if not self.map:isLand(x,y) then return false,"no_safe_ground" end
 local minCampfireDistance=48
 for _,fire in ipairs(self.campfires or {}) do local dx,dy=fire.x-x,fire.y-y;if dx*dx+dy*dy<minCampfireDistance*minCampfireDistance then self:addPopup(player.x,player.y-24,"TOO CLOSE TO ANOTHER FIRE","miss");if logger then logger:log("CAMPFIRE_BLOCKED",{reason="too_close",minimumDistance=minCampfireDistance}) end;return false,"campfire_too_close" end end
 local fmLevel=skills:get("Firemaking").level
 local isBonfire=fmLevel>=10
 local burnedPine,burnedOak=0,0
 inventory:removeItems(fuel,1);if fuel=="Oak Logs" then burnedOak=1 else burnedPine=1 end
 local duration=isBonfire and require("game.fire_fuel").logSeconds or 20
 local fire={x=x,y=y,timer=duration,bonfire=isBonfire,burnedLogs=1,queuedLogs=0,completedLogs=0,buffId=tostring(os.time())..":"..math.random(1,999999999)}
 require("game.fire_fuel").stamp(fire);self.campfires[#self.campfires+1]=fire;if isBonfire then require("game.bonfire_buff").grant(player,fire)end
 local baseXp=burnedPine*20+burnedOak*30
 local old,new,total,gained=skills:addXP("Firemaking",baseXp);self:addPopup(player.x,player.y-22,(isBonfire and "BONFIRE +" or "FIREMAKING +")..math.floor(gained or baseXp).." XP","defeat")
 if logger then logger:log(isBonfire and "BONFIRE_CREATED" or "CAMPFIRE_CREATED",{duration=duration,x=math.floor(x),y=math.floor(y),logs=fire.burnedLogs,pine=burnedPine,oak=burnedOak,firemakingXp=gained or baseXp,totalXp=total});if new>old then logger:log("SKILL_LEVEL_UP",{skill="Firemaking",from=old,to=new,totalXp=total}) end end
 return true,isBonfire and "bonfire_created" or "campfire_created"
end
function World:campfireNear(player) for _,f in ipairs(self.campfires) do local dx,dy=f.x-player.x,f.y-player.y;if dx*dx+dy*dy<=75*75 then return f end end end
function World:bonfireNear(player) for _,f in ipairs(self.campfires) do local dx,dy=f.x-player.x,f.y-player.y;if f.bonfire and dx*dx+dy*dy<=75*75 then return f end end end
function World:addBonfireLog(player,inventory,skills,logger,fuel,expectedFire)
 require("game.fire_fuel").realtime(self,player,logger)
 local fire=expectedFire or self:bonfireNear(player);local present=false
 for _,f in ipairs(self.campfires)do if f==fire then present=true;break end end
 if not present or not fire.bonfire or (fire.x-player.x)^2+(fire.y-player.y)^2>75^2 then return false,"no_bonfire_near" end
 if fuel~="Pine Logs" and fuel~="Oak Logs" and fuel~="Logs" and fuel~="Poplar Logs" then return false,"invalid_fuel" end
 if fuel=="Oak Logs" and skills:get("Firemaking").level<11 then return false,"Firemaking level 11 required" end
 if inventory:countItem(fuel)<1 then return false,"missing_logs" end
 inventory:removeItems(fuel,1);require("game.fire_fuel").add(fire);player.bonfireLastSource=nil;require("game.bonfire_buff").grant(player,fire)
 local baseXp=(fuel=="Oak Logs") and 30 or 20
 local old,new,total,gained=skills:addXP("Firemaking",baseXp)
 self:addPopup(player.x,player.y-22,"BONFIRE LOG ADDED +"..math.floor(gained or baseXp).." XP","defeat")
 if logger then logger:log("BONFIRE_REFUELED",{fuel=fuel,duration=require("game.fire_fuel").logSeconds,queuedLogs=fire.queuedLogs,currentLogRemaining=fire.timer,firemakingXp=gained or baseXp,totalXp=total});if new>old then logger:log("SKILL_LEVEL_UP",{skill="Firemaking",from=old,to=new,totalXp=total}) end end
 return true,"bonfire_refueled"
end
local function circleHit(ax,ay,ar,bx,by,br) local dx,dy=ax-bx,ay-by;local rr=ar+br;return dx*dx+dy*dy<rr*rr end
function World:playerBlocked(x,y,oldX,oldY)
 if require("game.fences").blocked(self,x,y) then return true,"fence" end
 local px,py=x,y+5;local pr=5
 if not self.map:isLand(px,py) then return true,"water" end
 if circleHit(px,py,pr,self.bankChest.x,self.bankChest.y+3,11) then return true,"bank" end
 if circleHit(px,py,pr,self.bankClerk.x,self.bankClerk.y+4,7) then return true,"bankclerk" end
 if circleHit(px,py,pr,self.mercRecruiter.x,self.mercRecruiter.y+4,7) then return true,"mercRecruiter" end
 for _,n in ipairs(self.tradeKeepers) do if circleHit(px,py,pr,n.x,n.y+4,7) then return true,"tradeKeeper" end end;for _,n in ipairs(self.traders or {}) do if circleHit(px,py,pr,n.x,n.y+4,7) then return true,"trader" end end
 for _,n in ipairs(self.healers) do if circleHit(px,py,pr,n.x,n.y+4,7) then return true,"healer" end end
 if circleHit(px,py,pr,self.smelter.x,self.smelter.y+3,8) then return true,"smelter" end
 if circleHit(px,py,pr,self.anvil.x,self.anvil.y+3,8) then return true,"anvil" end
 if circleHit(px,py,pr,self.tanningVat.x,self.tanningVat.y+3,8) then return true,"tanningVat" end
 if circleHit(px,py,pr,self.hideStretcher.x,self.hideStretcher.y+3,8) then return true,"hideStretcher" end
 if circleHit(px,py,pr,self.spinningWheel.x,self.spinningWheel.y+3,8) then return true,"spinningWheel" end
 if circleHit(px,py,pr,self.alchemy.x,self.alchemy.y+3,8) then return true,"alchemy" end;if circleHit(px,py,pr,self.stove.x,self.stove.y+3,8) then return true,"stove" end
 for _,h in ipairs(self.houses) do
  local left,top,width,height=Houses.bounds(h)
  if (require("game.modular_houses").is(h) and require("game.modular_houses").blocked(h,px,py,pr)) or (not require("game.modular_houses").is(h) and px+pr>left and px-pr<left+width and py+pr>top and py-pr<top+height) then return true,"house" end
 end
 for _,e in ipairs(self.enemies) do if not e.inactive and not e.dead and circleHit(px,py,pr,e.x,e.y+4,7) and not (oldX and (x-e.x)^2+(y-e.y)^2>(oldX-e.x)^2+(oldY-e.y)^2) then return true,e.kind end end
 for _,n in ipairs(NodeIndex.at(self,x,y)) do
  if n.kind=="tree" or (n.kind=="oak" or n.kind=="poplar") then if circleHit(px,py,pr,n.x,n.y+9,6) then return true,n.kind end
  elseif not n.depleted and n.kind~="hemp" and n.kind~="berryBush" and n.kind~="blueMushroom" and n.kind~="brownMushroom" and n.kind~="bushRoot" and n.kind~="bushGreens" and n.kind~="purpleBerry" and n.kind~="redBerry" then if circleHit(px,py,pr,n.x,n.y+3,9) then return true,n.kind end end
 end
 return false,nil
end
function World:resolvePlayerMovement(player,oldX,oldY)
 self.playerRef=player;local dx,dy=player.x-oldX,player.y-oldY;local length=math.sqrt(dx*dx+dy*dy)
 local steps=math.max(1,math.ceil(length/3));local x,y=oldX,oldY;local blocked=false
 for i=1,steps do
  local sx,sy=dx/steps,dy/steps;local nx,ny=x+sx,y+sy;local hit,kind=self:playerBlocked(nx,ny,x,y)
  if hit then
   blocked=true;local moved=false
   if kind=='tree'or (kind=='oak' or kind=='poplar')or kind=='copper'or kind=='tin'or kind=='iron'or kind=='coal'then
    local angle=math.atan2(sy,sx);local distance=math.sqrt(sx*sx+sy*sy)
    for _,offset in ipairs({.35,-.35,.7,-.7,1.05,-1.05,1.35,-1.35,1.55,-1.55,math.pi/2,-math.pi/2})do
     local ax,ay=x+math.cos(angle+offset)*distance,y+math.sin(angle+offset)*distance
     if not self:playerBlocked(ax,ay,x,y)then nx,ny=ax,ay;moved=true;break end
    end
   end
   if not moved then nx=x+sx;ny=y;if self:playerBlocked(nx,ny,x,y)then nx=x end;ny=y+sy;if self:playerBlocked(nx,ny,x,y)then ny=y end end
  end;x,y=nx,ny
 end
 player.x,player.y=math.max(8,math.min(self.map.width-8,x)),math.max(8,math.min(self.map.height-8,y));return blocked
end
function World:unstuckPlayer(player,logger)
 if self.isCave then player.x,player.y=self.arrival.x,self.arrival.y;self.gather=nil;self.combatTarget=nil;return true end
 local ox,oy=player.x,player.y
 for radius=16,320,16 do for step=0,15 do local a=step*math.pi/8;local x,y=ox+math.cos(a)*radius,oy+math.sin(a)*radius;if self.map:isLand(x,y) and not self:playerBlocked(x,y) then player.x,player.y=x,y;if logger then logger:log("PLAYER_UNSTUCK",{fromX=math.floor(ox),fromY=math.floor(oy),toX=math.floor(x),toY=math.floor(y)}) end;self:addPopup(x,y-18,"UNSTUCK","defeat");return true end end end
 player.x,player.y=self.map.width/2,self.map.height/2+55;if logger then logger:log("PLAYER_UNSTUCK",{fallback="town_center"}) end;return true
end
function World:getDef(kind) return defs[kind] end
function World:addGroundItem(name,x,y,lit,obj) require("game.audio").play(name=="Fish Bones" and "fish_bones_drop" or tostring(name):find("Hide",1,true) and "hide_drop" or "loot_drop",x,y);self.groundItems[#self.groundItems+1]={name=name,x=x,y=y,lit=lit or name=="Lit Torch",object=obj,expiresAt=os.time()+300,bagOwner=(not SG_SERVER and require("game.bag_system").defs[require("game.bag_system").name(name)])and require("game.profile").active and(tostring(require("game.profile").active.id)..":"..require("game.profile").active.slot)or(not SG_SERVER and require("game.bag_system").defs[require("game.bag_system").name(name)]and"offline"or nil)} end
function World:groundItemAt(x,y)
 require("game.ground_lifetime").update(self)
 local best,bestI,bestD=nil,nil,math.huge
 for i=#self.groundItems,1,-1 do local g=self.groundItems[i];local dx,dy=x-g.x,y-g.y;local d=dx*dx+dy*dy;if d<14*14 and d<bestD then best,bestI,bestD=g,i,d end end
 return best,bestI
end
function World:takeGroundItem(index) return table.remove(self.groundItems,index) end
function World:resourceInfo(kind) return defs[kind] end
function World:nodeAt(x,y) local best,bestD=nil,99999;for _,n in ipairs(NodeIndex.at(self,x,y)) do if not n.depleted then local dx,dy=x-n.x,y-n.y;local d=dx*dx+dy*dy;if d<bestD and d<18*18 then best,bestD=n,d end end end;return best end
function World:startGather(node,player,skills,inventory,logger)
 if not node or node.depleted then return false,"depleted" end
 local prospect=require("game.prospecting")
 if prospect.isOre(node) and not node.prospected then
  if not prospect.canAuto(node,skills) then self:addPopup(player.x,player.y-24,"Prospect this ore first (right-click)");return false,"prospecting_required" end
  local d=defs[node.kind];if (node.x-player.x)^2+(node.y-player.y)^2>d.reach^2 then return false,"too_far" end
  if not hasToolEquivalent(inventory,player.equipped,d.tool) then return false,"missing_"..d.tool end
  prospect.identify(self,node,player,skills,logger)
 end
 if node.kind=="berryBush" then
  local item,xp;if node.stage=="berries" then item=node.berryType;xp=4 elseif node.stage=="greens" then item="Bush Greens";xp=4 elseif node.stage=="root" then item="Bush Root";xp=6 else return false,"depleted" end
  local dx,dy=node.x-player.x,node.y-player.y;if dx*dx+dy*dy>34*34 then return false,"too_far" end
  self.gather={node=node,skill="Alchemy",item=item,xp=xp,timer=.8,hitsLeft=1,bushStage=node.stage}
  if logger then logger:log("BUSH_GATHER_STARTED",{stage=node.stage,item=item,berryType=node.berryType}) end;return true
 end
 local d=defs[node.kind];local dx,dy=node.x-player.x,node.y-player.y;if d.level and skills:get(d.skill).level<d.level then return false,"requires_"..d.skill.."_"..d.level end;if dx*dx+dy*dy>d.reach*d.reach then return false,"too_far" end;if d.tool and not hasToolEquivalent(inventory,player.equipped,d.tool) then if logger then logger:log("GATHER_BLOCKED_NO_TOOL",{resource=node.kind,requiredTool=d.tool}) end;return false,"missing_"..d.tool end;local level=skills:get(d.skill).level;self.gather={node=node,skill=d.skill,item=d.item,xp=d.xp,timer=.8,hitsLeft=math.random(1,math.max(1,5-math.floor((level-1)/20)))};if logger then logger:log("GATHER_STARTED",{resource=node.kind,skill=d.skill,level=level,hp=node.hp,tool=d.tool}) end;return true end
function World:stopGather(reason,logger) if self.gather and logger then logger:log("GATHER_STOPPED",{reason=reason or "unknown",resource=self.gather.node.kind}) end;self.gather=nil end
function World:useTanningVat(inventory,skills,logger)
 local ok,why=require("game.unlocks").action(skills,"leather");if not ok then if self.playerRef then self:addPopup(self.playerRef.x,self.playerRef.y-24,why) end;return false,why end
 local occupied=0;for _,j in ipairs(self.tanningVat.jobs) do occupied=occupied+(j.slots or (j.output=="Extra Large Soaked Hide" and 2 or 1)) end;local free=2-occupied;if free<=0 then return false,"vat_full" end
 local raw=inventory:countItem("Extra Large Raw Hide")>0 and "Extra Large Raw Hide" or (inventory:countItem("Large Raw Leather")>0 and "Large Raw Leather" or "Raw Hide");if inventory:countItem("Raw Cave Snake Hide")>0 then raw="Raw Cave Snake Hide" end;local size=(raw=="Raw Cave Snake Hide" or raw=="Extra Large Raw Hide" or raw=="Large Raw Leather") and 2 or 1;if free<size then return false,"vat_full" end;local count=math.min(math.floor(free/size),inventory:countItem(raw));if count<=0 then return false,"no_raw_hide" end
 if not inventory:removeItems(raw,count) then return false,"remove_failed" end
 for i=1,count do self.tanningVat.jobs[#self.tanningVat.jobs+1]={timer=30,slots=size,output=raw=="Raw Cave Snake Hide" and "Soaked Cave Snake Hide" or raw=="Raw Hide" and "Soaked Hide" or (raw=="Large Raw Leather" and "Large Soaked Leather" or "Extra Large Soaked Hide")} end
 if logger then logger:log("TANNING_VAT_LOADED",{hides=count,capacity=2}) end;return true,count
end
function World:useHideStretcher(inventory,skills,logger) return require('game.hide_processing').use(self,inventory,skills,logger) end
function World:update(dt,player,inventory,skills,logger)
 require("game.ground_lifetime").update(self)
 require("game.cursed_enemies").world(self);if not SG_SERVER and not self.onlineShared then require("game.bone_religion").update(self,dt)end
 require("game.shellfish").update(self,dt)
 require("game.navigation").begin(self,dt,player);self._navigationPrepared=true
 require("game.wildlife").update(self,dt)
 -- Lightweight authored NPC behavior. Story/quest escorts temporarily take control elsewhere.
 for _,cn in ipairs(self.customNPCs or{})do
  if cn.behavior=='Wander' and not cn.questControlled then
   cn.moveTimer=(cn.moveTimer or 0)-dt
   if cn.moveTimer<=0 then local a=math.random()*math.pi*2;cn.vx=math.cos(a)*12;cn.vy=math.sin(a)*12;cn.moveTimer=1.2+math.random()*2.8 end
   local nx,ny=cn.x+(cn.vx or 0)*dt,cn.y+(cn.vy or 0)*dt;local r=math.max(8,tonumber(cn.wanderRadius) or 72)
   if self.map:isLand(nx,ny) and ((nx-cn.homeX)^2+(ny-cn.homeY)^2)<=r*r and not require('game.fences').blocked(self,nx,ny,cn) then cn.x,cn.y=nx,ny else cn.vx,cn.vy=-(cn.vx or 0),-(cn.vy or 0) end
  end
 end
 if self.isCave then for _,n in ipairs(self.nodes)do if n.depleted then n.respawnTimer=1e9 end end end
 Villages.nearest(self,player.x,player.y)
 self:updateFishing(dt,player,skills,inventory,logger)
 for i=#self.juiceParticles,1,-1 do local p=self.juiceParticles[i];p.time=p.time-dt;p.x=p.x+p.vx*dt;p.y=p.y+p.vy*dt;p.vy=p.vy+35*dt;p.vx=p.vx*.96;if p.time<=0 then table.remove(self.juiceParticles,i) end end
 for _,e in ipairs(self.enemies) do local dx,dy=e.x-player.x,e.y-player.y;if dx*dx+dy*dy<900*900 then e.hitFlash=math.max(0,(e.hitFlash or 0)-dt);e.hitKickX=(e.hitKickX or 0)*math.max(0,1-dt*10);e.hitKickY=(e.hitKickY or 0)*math.max(0,1-dt*10) else e.hitFlash=0;e.hitKickX=0;e.hitKickY=0 end end
 require("game.fire_fuel").realtime(self,player,logger)
 local function stationSkills(owner)if owner then for _,a in ipairs(self.onlineActors or{})do if a.id==owner then return a.skills end end end;return skills end
 for _,v in ipairs(self.villages) do
 for i=#v.tanningVat.jobs,1,-1 do local j=v.tanningVat.jobs[i];j.timer=j.timer-dt;if j.timer<=0 then table.remove(v.tanningVat.jobs,i);self:addGroundItem(j.output or "Soaked Hide",v.tanningVat.x+math.random(-5,5),v.tanningVat.y+12,nil,{name=j.output or "Soaked Hide",qty=1,qualityGrade=require('game.quality').roll(stationSkills(j.onlineOwner):get("Leatherworking").level)});local old,new,xp=stationSkills(j.onlineOwner):addXP("Leatherworking",5);if logger then logger:log("TANNING_VAT_FINISHED",{item="Soaked Hide",xpGained=5,totalXp=xp,level=new});if new>old then logger:log("SKILL_LEVEL_UP",{skill="Leatherworking",from=old,to=new,totalXp=xp}) end end end end
 require('game.hide_processing').update(v.hideStretcher,dt,stationSkills(v.hideStretcher.onlineOwner),logger)
 end
 for i=#self.swings,1,-1 do self.swings[i].time=self.swings[i].time-dt;if self.swings[i].time<=0 then table.remove(self.swings,i) end end
 -- Resource regrowth is background simulation; ticking the entire world node list at
 -- 10 Hz instead of every rendered frame removes thousands of needless updates.
 self._nodeTick=(self._nodeTick or 0)+dt
 local nodeDt=0
 if self._nodeTick>=0.10 then nodeDt=self._nodeTick;self._nodeTick=0 end
 for _,n in ipairs(self.nodes) do
 n.shake=math.max(0,n.shake-dt)
 if nodeDt>0 then
 if n.kind=="berryBush" then
  if n.stage=="greens" and (n.berryRegrowTimer or 0)>0 then n.berryRegrowTimer=n.berryRegrowTimer-nodeDt;if n.berryRegrowTimer<=0 then n.stage="berries";n.berryCount=math.random(1,5);n.hp=n.berryCount;n.maxHp=n.hp;if logger then logger:log("BERRIES_REGROWN",{x=n.x,y=n.y,berryType=n.berryType,count=n.berryCount}) end end
  elseif n.stage=="root" and (n.greenRegrowTimer or 0)>0 then n.greenRegrowTimer=n.greenRegrowTimer-nodeDt;if n.greenRegrowTimer<=0 then n.stage="greens";n.hp=1;n.maxHp=1;n.berryRegrowTimer=45;if logger then logger:log("BUSH_GREENS_REGROWN",{x=n.x,y=n.y,berryType=n.berryType}) end end end
 elseif n.depleted then n.respawnTimer=n.respawnTimer-nodeDt;if n.respawnTimer<=0 then n.depleted=false;n.hp=n.maxHp;n.resourceCycle=(n.resourceCycle or 0)+1;n.prospected=false;n.stumpSnow=false;n.snowCovered=(n.snowDepth or 0)>=.65;if logger then logger:log("RESOURCE_RESPAWNED",{x=n.x,y=n.y,resource=n.kind,x=math.floor(n.x),y=math.floor(n.y)}) end end end
 end
end;self:updatePlayerStatus(dt,player,logger)
 for _,sh in ipairs(self.sheep) do
 if sh.dead then sh.respawnTimer=(sh.respawnTimer or 300)-dt;if sh.respawnTimer<=0 then sh.dead=false;sh.hp=5;sh.x,sh.y=sh.homeX,sh.homeY;sh.wool=true;sh.nagaKilled=nil end
 else
 if not sh.wool then sh.woolTimer=sh.woolTimer-dt;if sh.woolTimer<=0 then sh.wool=true;if logger then logger:log("SHEEP_WOOL_REGROWN",{x=math.floor(sh.x),y=math.floor(sh.y)}) end end end
 sh.moveTimer=sh.moveTimer-dt
 if sh.moveTimer<=0 then local a=math.random()*math.pi*2;sh.vx=math.cos(a)*10;sh.vy=math.sin(a)*10;sh.moveTimer=1.5+math.random()*2.5 end
 local nx,ny=sh.x+sh.vx*dt,sh.y+sh.vy*dt
 if not require("game.fences").blocked(self,nx,ny,sh) and self.map:isLand(nx,ny) and ((nx-sh.homeX)^2+(ny-sh.homeY)^2)<95^2 then sh.x,sh.y=nx,ny else sh.vx,sh.vy=-sh.vx,-sh.vy end
 end
end
self:updateGather(dt,player,inventory,skills,logger)
end
function World:updatePlayerStatus(dt,player,logger)

 if (player.poisonedTimer or 0)>0 then player.poisonedTimer=math.max(0,player.poisonedTimer-dt);player.poisonTick=(player.poisonTick or 0)-dt;if player.poisonTick<=0 then player.poisonTick=1;require("game.audio").play("player_hurt",player.x,player.y);player.damageSerial=(player.damageSerial or 0)+1;player.lastDamageSource="Poison";player.hp=math.max(0,player.hp-1);self:addPopup(player.x,player.y-14,"POISON 1","damage");if logger then logger:log("POISON_TICK",{damage=1,hp=player.hp,remaining=string.format("%.2f",player.poisonedTimer)}) end end end
end
function World:updateGather(dt,player,inventory,skills,logger)
local g=self.gather;if not g then return end;local n=g.node
 if n.kind=="berryBush" then
  local dx,dy=n.x-player.x,n.y-player.y;if dx*dx+dy*dy>34*34 then self:stopGather("moved_out_of_range",logger);return end
  if not inventory:canAdd(g.item,1) then self:addPopup(player.x,player.y-24,"FULL INVENTORY","miss");self:stopGather("bag_full",logger);return end
  g.timer=g.timer-dt;if g.timer>0 then return end;n.shake=.12
  if not inventory:add(g.item,1) then self:addPopup(player.x,player.y-24,"FULL INVENTORY","miss");self:stopGather("bag_full",logger);return end
  n.hp=n.hp-1;local oldLv,newLv,total=skills:addXP("Alchemy",g.xp)
  if logger then logger:log("BUSH_LAYER_GAIN",{stage=n.stage,item=g.item,remaining=math.max(0,n.hp),xpGained=g.xp,totalXp=total}) end
  if newLv>oldLv and logger then logger:log("SKILL_LEVEL_UP",{skill="Alchemy",from=oldLv,to=newLv,totalXp=total}) end
  if n.hp<=0 then
   if n.stage=="berries" then n.stage="greens";n.hp=1;n.maxHp=1;n.berryRegrowTimer=45
   elseif n.stage=="greens" then n.stage="root";n.hp=1;n.maxHp=1;n.greenRegrowTimer=60
   elseif n.stage=="root" then n.stage="gone";n.depleted=true;n.hp=0;n.berryRegrowTimer=0;n.greenRegrowTimer=0 end
   if logger then logger:log("BUSH_LAYER_REMOVED",{newStage=n.stage,berryType=n.berryType}) end;self.gather=nil;return
  end
  g.timer=.8;return
 end
 local d=defs[n.kind];if d.tool and not hasToolEquivalent(inventory,player.equipped,d.tool) then self:stopGather("required_tool_missing",logger);return end;if n.depleted then self:stopGather("depleted",logger);return end;local dx,dy=n.x-player.x,n.y-player.y;if dx*dx+dy*dy>d.reach*d.reach then self:stopGather("moved_out_of_range",logger);return end;if not inventory:canAdd(d.item,1) then self:addPopup(player.x,player.y-24,"FULL INVENTORY","miss");self:stopGather("bag_full",logger);return end;g.timer=g.timer-dt;if g.timer>0 then return end;n.shake=.12;player:pulseTool(.24);self:emitJuice(n.x,n.y-4,(n.kind=="tree" or (n.kind=="oak" or n.kind=="poplar")) and "wood" or (n.kind=="copper" and "copper" or "leaf"),(n.kind=="tree" or (n.kind=="oak" or n.kind=="poplar")) and 5 or 4,self:objectJuiceColor(n.kind));g.hitsLeft=g.hitsLeft-1;if logger then logger:log("RESOURCE_HIT",{x=n.x,y=n.y,resource=n.kind,hp=n.hp,hitsUntilGather=g.hitsLeft}) end;if g.hitsLeft<=0 then local gatheredItem=d.item;if n.kind=="coal" and skills:get("Mining").level>=37 and math.random(1,100)<=25 then gatheredItem="Large Coal Chunk" end;if n.kind=="iron" and skills:get("Mining").level>=30 and math.random(1,100)<=25 then gatheredItem="Large Iron Chunk" end;if n.kind=="copper" and skills:get("Mining").level>=require("game.unlocks").extra.Mining[2][1] and math.random(1,100)<=12 then gatheredItem="Large Copper Chunk" end;if not inventory:add(gatheredItem,1) then self:addPopup(player.x,player.y-24,"FULL INVENTORY","miss");self:stopGather("bag_full",logger);return end;require("game.quests").event(self,"gather",gatheredItem,1);n.hp=n.hp-1;self:addPopup(n.x,n.y-18,"+"..gatheredItem,"defeat");local old,new,xp=skills:addXP(d.skill,d.xp);if logger then logger:log("RESOURCE_GAIN",{resource=n.kind,item=gatheredItem,resourceHp=n.hp,xpGained=d.xp,totalXp=xp,skill=d.skill,level=new}) end;if new>old and logger then logger:log("SKILL_LEVEL_UP",{skill=d.skill,from=old,to=new,totalXp=xp}) end;
 if require("game.prospecting").isOre(n) then require("game.rune_drops").drop(self,"Stone Gravel",4,n,player);if logger then logger:log("STONE_GRAVEL_DROPPED",{qty=4,resource=n.kind}) end;if math.random(1,50)==1 then if inventory:canAdd("Rough Onyx",1) and inventory:add("Rough Onyx",1) then self:addPopup(n.x,n.y-30,"RARE FIND: Rough Onyx","defeat");if logger then logger:log("ROUGH_ONYX_FOUND",{resource=n.kind}) end elseif logger then logger:log("ROUGH_ONYX_LOST",{reason="bag_full",resource=n.kind}) end end end
 -- Jewel-bearing stones are rare bonus finds from ordinary copper mining, not world nodes.
 if n.kind=="copper" then
  local roll=math.random(1,400);local jewel=nil
  if roll==1 then jewel="Emerald-bearing Rock" elseif roll<=3 then jewel="Sapphire-bearing Rock" elseif roll<=7 then jewel="Ruby-bearing Rock" end
  if jewel then
   if inventory:canAdd(jewel,1) and inventory:add(jewel,1) then self:addPopup(n.x,n.y-30,"RARE FIND: "..jewel,"defeat");self:emitJuice(n.x,n.y-5,"copper",10,self:objectJuiceColor("copper"));if logger then logger:log("RARE_JEWEL_ROCK_FOUND",{item=jewel,roll=roll}) end
   elseif logger then logger:log("RARE_JEWEL_ROCK_LOST",{item=jewel,reason="bag_full",roll=roll}) end
  end
 end
 if n.hp<=0 then self:emitJuice(n.x,n.y,(n.kind=="tree" or (n.kind=="oak" or n.kind=="poplar")) and "wood" or "copper",12,self:objectJuiceColor(n.kind));n.shake=.3;n.hp=0;n.depleted=true;n.stumpSnow=(n.kind=="tree" or (n.kind=="oak" or n.kind=="poplar")) and (n.snowCovered==true) or false;n.respawnTimer=d.respawn;if logger then logger:log("RESOURCE_DEPLETED",{x=n.x,y=n.y,resource=n.kind,respawnSeconds=d.respawn}) end;self.gather=nil;return end;local level=skills:get(d.skill).level;g.hitsLeft=math.random(1,math.max(1,5-math.floor((level-1)/20))) end;g.timer=.8 end

function World:enemyAt(x,y)
 local best,bestD=nil,math.huge
 for _,e in ipairs(self.enemies) do if not e.inactive and not e.cagedLocked and not e.dead then local dx,dy=x-e.x,y-e.y;local d=dx*dx+dy*dy;local r=e.hitRadius or 14;if d<r*r and d<bestD then best,bestD=e,d end end end
 return best
end
function World:animalCarcassAt(x,y)
 local best,bestD=nil,math.huge
 for _,e in ipairs(self.enemies) do if not e.inactive and e.dead and (e.kind=="rat" or e.kind=="wolf" or e.kind=="boar" or e.kind=="gigaRat" or e.kind=="caveSnake" or e.kind=="cow" or e.kind=="nagalian") and not e.skinned then local dx,dy=x-e.x,y-e.y;local d=dx*dx+dy*dy;local r=e.hitRadius or 16;if d<r*r and d<bestD then best,bestD=e,d end end end
 return best
end
function World:skinAnimal(enemy,player,skills,inventory,logger)
 if enemy and enemy.kind=='nagalian'then return require('game.nagalians').skin(self,enemy,player,skills,inventory,logger)end
 local handled,why=require('game.skinning_fallback').try(self,enemy,player,skills,inventory,logger);if handled~=nil then return handled,why end
 if enemy and (enemy.kind=="cow" or enemy.kind=="boar") then local ok,why=require("game.unlocks").action(skills,"largeHide");if not ok then self:addPopup(player.x,player.y-24,why);return false,why end end
 if enemy then local ok,result=Expansion.skin(self,enemy,player,skills,inventory);if ok~=nil then return ok,result end end
 if not enemy or not enemy.dead or enemy.skinned or (enemy.kind~="rat" and enemy.kind~="wolf" and enemy.kind~="cow") then return false,"not_skinnable" end
 local dx,dy=enemy.x-player.x,enemy.y-player.y;if dx*dx+dy*dy>42*42 then return false,"too_far" end
 if not hasToolEquivalent(inventory,player.equipped,"Copper Dagger") then if logger then logger:log("SKINNING_BLOCKED_NO_KNIFE",{enemy=enemy.kind}) end;return false,"missing_Copper Dagger" end
 if not inventory:canAdd(enemy.kind=="cow" and "Large Raw Leather" or "Raw Hide",2) then return false,"bag_full" end
 local level=skills:get("Skinning").level
 local rawChance=math.min(95,25+level*3+(level>=5 and 15 or 0))
 local item=(enemy.kind=="cow") and "Large Raw Leather" or ((math.random(1,100)<=rawChance) and "Raw Hide" or "Torn Hide")
 local meat=(enemy.kind=="wolf" or enemy.kind=="cow") and "Large Meat" or "Small Meat"
 if enemy.kind=='wolf'and not enemy.wolfHeadRolled then enemy.wolfHeadRolled=true;enemy.wolfHeadDrop=math.random()<.10 end
 local trial=require('game.rune_inventory').clone(inventory)
 if not trial:add(item,1)or not trial:add(meat,1)or(enemy.kind=='wolf'and enemy.wolfHeadDrop and not trial:add('Wolf Head',1))then return false,'bag_full'end
 inventory.bagSlots=trial.bagSlots
 if enemy.kind=='wolf'and enemy.wolfHeadDrop then self:addPopup(enemy.x,enemy.y-30,'WOLF HEAD','defeat');if logger then logger:log('WOLF_HEAD_SKINNED',{item='Wolf Head',quantity=1,enemy='wolf'})end end
 enemy.skinned=true;local old,new,xp=skills:addXP("Skinning",16)
 self:addPopup(enemy.x,enemy.y-12,item=="Raw Hide" and "RAW HIDE" or "TORN HIDE",item=="Raw Hide" and "defeat" or "miss")
 if logger then logger:log("ANIMAL_SKINNED",{x=enemy.x,y=enemy.y,enemy=enemy.kind,item=item,meat=meat,skill="Skinning",level=new,xpGained=16,totalXp=xp,rawHideChance=rawChance}) end
 if new>old and logger then logger:log("SKILL_LEVEL_UP",{skill="Skinning",from=old,to=new,totalXp=xp}) end
 return true,item
end
local function fishingWait(level)
 return math.max(5,math.random(75,125)/10-math.min(2.0,level*0.05))
end
function World:fishAt(x,y,player,skills,inventory,logger)
 if self.fishing then return false,"already_fishing" end
 local tx=math.floor(x/16)+1;local ty=math.floor(y/16)+1
 if not self.map:isBeachCell(tx,ty) and not self.map:isBeachWaterCell(tx,ty) then return false,"not_fishing_beach" end
 -- Authored fishing markers designate shoreline fishing spots. Legacy maps with no markers keep normal shoreline fishing.
 local authored=self.map.authored;local markers={}
 if authored then for _,o in ipairs(authored.objects or {}) do if o.id=="fishingMarker" then markers[#markers+1]=o end end end
 if #markers>0 then local marked=false;for _,m in ipairs(markers) do local mdx,mdy=x-m.x,y-m.y;if mdx*mdx+mdy*mdy<=128*128 then marked=true;break end end;if not marked then return false,"not_fishing_zone" end end
 local dx,dy=x-player.x,y-player.y;if dx*dx+dy*dy>80*80 then return false,"too_far" end
 local F=require("game.fishing_tiers");if require("game.shellfish").levels[player.equipped]then return false,"Right-click the pot in inventory to place it"end;local lvl=skills:get("Fishing").level;local tool=F.select(player,inventory,lvl);if not tool then return false,"missing_Fishing Pole"end;if lvl<F.tools[tool]then return false,"Requires Fishing level "..F.tools[tool]end
 if not inventory:canAdd(require("game.fishing_tiers").sample(tool,skills:get("Fishing").level),1) then return false,"bag_full" end
 local lvl=skills:get("Fishing").level
 -- Fishing is intentionally a wait rather than an instant click reward. Higher levels trim the wait modestly.
 local wait=fishingWait(lvl)
 require("game.audio").play("bobber_splash",x,y);self.fishing={timer=wait,startX=player.x,startY=player.y,castX=x,castY=y,level=lvl,tool=tool,loaded=false}
 player:pulseTool(wait)
 self:addPopup(player.x,player.y-18,"FISHING...","miss")
 if logger then logger:log("FISHING_STARTED",{level=lvl,wait=string.format("%.1f",wait)}) end
 return true,"waiting"
end
function World:updateFishing(dt,player,skills,inventory,logger)
 if self.fishing and require("game.shellfish").levels[self.fishing.tool]then self.fishing=nil;return end
 local f=self.fishing;if not f then return end;local F=require("game.fishing_tiers");local tool=f.tool or"Fishing Pole"
 local dx,dy=player.x-f.startX,player.y-f.startY
 if dx*dx+dy*dy>28*28 then self.fishing=nil;self:addPopup(player.x,player.y-18,"CANCELLED","miss");if logger then logger:log("FISHING_CANCELLED",{reason="moved_away"}) end;return end
 if not inventory:canAdd(F.sample(tool,skills:get("Fishing").level),1) then self.fishing=nil;self:addPopup(player.x,player.y-18,"FULL INVENTORY","miss");return end
 if not F.has(tool,player,inventory)or skills:get("Fishing").level<F.tools[tool]then self.fishing=nil;return end
 f.timer=f.timer-dt;if f.timer>0 then return end
 require("game.audio").play("fish_bite",f.castX,f.castY)
 -- Schedule another cast for successes and misses; keep the original position.
 f.timer=fishingWait(skills:get("Fishing").level)
 local lvl=skills:get("Fishing").level
 -- Low Fishing levels miss often; the chance improves steadily but never becomes completely guaranteed here.
 local catchChance=math.min(95,48+lvl*3)
 if not f.pendingCatch and math.random(1,100)>catchChance then self:addPopup(player.x,player.y-18,"NO CATCH","miss");if logger then logger:log("FISHING_FAILED",{level=lvl,catchChance=catchChance}) end;return end
 if not inventory:canAdd(F.sample(tool,skills:get("Fishing").level),1) then self.fishing=nil;self:addPopup(player.x,player.y-18,"FULL INVENTORY","miss");return end
 local roll=math.random(1,100)+math.min(25,lvl)
 local fish,qty,xpPer;if f.pendingCatch then fish,qty,xpPer=f.pendingCatch.fish,f.pendingCatch.qty,f.pendingCatch.xp;f.pendingCatch=nil else fish,qty,xpPer=F.catch(tool,lvl,roll);local d=require('game.high_tier_fish').data[fish];if d then f.pendingCatch={fish=fish,qty=qty,xp=xpPer};f.timer=d.extra;player:pulseTool(d.extra);self:addPopup(player.x,player.y-18,'LANDING FISH...','miss');return end end;if not inventory:canAdd(fish,qty)then self.fishing=nil;self:addPopup(player.x,player.y-18,"FULL INVENTORY","miss");return end
 if not inventory:add(fish,qty) then self.fishing=nil;return end;require("game.quests").event(self,"gather",fish,qty);f.loaded=tool=="Crab Pot";local xpGain=xpPer*qty
 require("game.audio").play("water_splash",player.x,player.y);local old,new,total=skills:addXP("Fishing",xpGain);player:pulseTool(.5);self:emitJuice(player.x,player.y+6,"water",9);self:addPopup(player.x,player.y-18,fish,"defeat");self:addPopup(player.x+12,player.y-6,"+"..xpGain.." XP","miss")
 if logger then logger:log("FISH_CAUGHT",{fish=fish,qty=qty,tool=tool,xpGained=xpGain,totalXp=total,level=new,catchChance=catchChance});if new>old then logger:log("SKILL_LEVEL_UP",{skill="Fishing",from=old,to=new,totalXp=total}) end end
 if not inventory:canAdd(F.sample(tool,skills:get("Fishing").level),1) then self.fishing=nil;self:addPopup(player.x,player.y-30,"FULL INVENTORY","miss") end
end
function World:startCombat(enemy,player,logger,range)
 if not enemy or enemy.dead then return false,"no_target" end
 local mage=(player.equipment or{}).offhand=='Spellbook'or(player.equipped or''):find('Staff',1,true);range=range or(mage and 210 or 180);local dx,dy=enemy.x-player.x,enemy.y-player.y;if dx*dx+dy*dy>range*range then return false,"too_far" end
 self.targetedEnemy=enemy;enemy.aggro=true;enemy.state="chase"
 if self.gather then self:stopGather("combat_started",logger) end
 if self.combatTarget and self.combatTarget~=enemy and logger then logger:log("COMBAT_TARGET_CHANGED",{from=self.combatTarget.kind,to=enemy.kind}) end
 self.combatTarget=enemy
 if logger then logger:log("AUTO_COMBAT_STARTED",{target=enemy.kind}) end
 return true,"engaged"
end
function World:stopCombat(reason,logger)
 if self.combatTarget and logger then logger:log("AUTO_COMBAT_STOPPED",{target=self.combatTarget.kind,reason=reason or "unknown"}) end
 self.combatTarget=nil
end

function World:addPopup(x,y,text,kind)
 if tostring(text):find("FULL INVENTORY",1,true) or tostring(text):find("BAGS FULL",1,true) or tostring(text):find("SPELLBOOK FULL",1,true) then require("game.audio").play("inventory_full",x,y) end
 local clear=false
 while not clear do clear=true;for _,p in ipairs(self.popups) do if math.abs(p.x-x)<100 and math.abs(p.y-y)<18 then y=p.y-20;clear=false;break end end end
 self.popups[#self.popups+1]={x=x,y=y,text=tostring(text),kind=kind or "damage",time=.8}
end
local function addSkillXP(skills,name,amount,logger)
 local old,new,xp=skills:addXP(name,amount);if old and logger then logger:log("COMBAT_XP",{skill=name,xpGained=amount,totalXp=xp,level=new});if new>old then logger:log("SKILL_LEVEL_UP",{skill=name,from=old,to=new,totalXp=xp}) end end
end
function World:bowRange(player)
 return player.race=="Elf" and 175 or 140
end
function World:dropScattered(name,cx,cy,index,total)
 local n=math.max(1,total or 1);local i=(index or 1)-1;local a=(i/n)*math.pi*2+0.45;local r=n==1 and 10 or 12+6*(i%2);self:addGroundItem(name,cx+math.cos(a)*r,cy+10+math.sin(a)*r)
end
function World:defeatEnemy(enemy,skills,logger)
 if not enemy or enemy.dead then return false end
 require("game.quests").event(self,"kill",enemy.kind,1);enemy.dead=true;enemy.fangPoison=nil;enemy.aggro=false;enemy.state="dead";enemy.respawnTimer=240
 if self.combatTarget==enemy then self:stopCombat("target_defeated",logger) end
 if enemy.kind=="nagaQueen"then require("game.naga_queen").onDeath(self,enemy)end
 self:addPopup(enemy.x,enemy.y-20,"DEFEATED","defeat")
 local drops={}
 if enemy.customMonster then local d=require('game.custom_content').monster(enemy.customMonster);for _,k in ipairs({'1','2'})do local n=d and d['drop'..k];local q=tonumber(d and d['drop'..k..'Qty'])or 0;for i=1,q do if n and n~=''then drops[#drops+1]=n end end end
 elseif enemy.kind=="skeleton" then drops[#drops+1]="Bones"
 elseif enemy.kind=="slime" then
  if math.random(1,10)==1 then drops[#drops+1]="Green Slime Jar" end
 elseif enemy.kind=="chicken" then
  drops[#drops+1]="Raw Chicken";drops[#drops+1]="Feather"
 elseif enemy.kind=="rat" or enemy.kind=="wolf" then
  drops[#drops+1]="Bones";enemy.skinned=false
 elseif enemy.kind=="cow" then
  enemy.skinned=false
 end
 local forcedBones=false;for di,dn in ipairs(drops) do if dn=="Bones" then forcedBones=true else self:dropScattered(dn,enemy.x,enemy.y,di,#drops)end end;require("game.bone_religion").drop(self,enemy,nil,forcedBones)
 if #drops>0 then self:addPopup(enemy.x,enemy.y-5,"DROP!","defeat") end
 if logger then logger:log("ENEMY_DEFEATED",{x=enemy.x,y=enemy.y,enemy=enemy.kind,respawnSeconds=240,drops=table.concat(drops,",")}) end
 return true
end
function World:resolvePlayerArrow(p,skills,logger)
 skills=p.skills or skills;logger=p.logger or logger
 local enemy=p.target
 if not enemy or enemy.dead then return end
 if not p.hit then self:addPopup(enemy.x,enemy.y-12,"MISS","miss");if logger then logger:log("COMBAT_MISS",{x=enemy.x,y=enemy.y,target=enemy.kind,weapon="Bow",rangedLevel=p.ranged}) end;return end
 local dealt=p.damage;require("game.party").threat(self,enemy,p.owner or self.playerRef,dealt);enemy.hp=math.max(0,enemy.hp-dealt);local kx,ky=enemy.x-p.sx,enemy.y-p.sy;local kd=math.max(1,math.sqrt(kx*kx+ky*ky));enemy.hitKickX=kx/kd*2;enemy.hitKickY=ky/kd*2;enemy.hitFlash=.11;self:emitJuice(enemy.x,enemy.y-3,"hit",5,self:enemyJuiceColor(enemy));self:addPopup(enemy.x,enemy.y-12,dealt,"damage")
 addSkillXP(skills,"Ranged",dealt*4,logger);addSkillXP(skills,"Strength",dealt*4,logger);addSkillXP(skills,"Health",dealt*1.33,logger)
 if logger then logger:log("COMBAT_HIT",{x=enemy.x,y=enemy.y,target=enemy.kind,weapon="Bow",damage=dealt,targetHp=enemy.hp}) end
 if enemy.hp<=0 then self:defeatEnemy(enemy,skills,logger)elseif dealt>0 then require('game.fang_poison').apply(self,enemy,p.ammoType,skills,logger,p.owner)end
end
function World:attackEnemy(enemy,player,skills,equipment,sprites,logger,equipmentSockets)
 player.gear=equipment
 if not enemy or enemy.dead then return false,"no_target" end
 local weapon=player.equipped;if weapon=="Copper Knife" then return false,"utility_tool" end;local eligible=require("game.progression").canEquip(skills,weapon or "",sprites.itemInfo[weapon]);if not eligible then return false,"equipment_level" end;local isRanged=(weapon=="Bow" or tostring(weapon):match(" Bow$"));local range=isRanged and self:bowRange(player) or (38+math.max(0,(enemy.hitRadius or 14)-14));local dx,dy=enemy.x-player.x,enemy.y-player.y;if dx*dx+dy*dy>range*range then return false,"too_far" end
 if player.attackCooldown>0 then return false,"cooldown" end
 local ammoType=require('game.advanced_gear').arrowType(equipment.ammo)
 if isRanged then local ammo=equipment.ammo;local checkedAmmoType=type(ammo)=="table" and (require('game.advanced_gear').isQuiver(ammo.name) and ammo.arrowType or ammo.name) or nil;if type(ammo)~="table" or not require('game.advanced_gear').isArrow(ammoType) or (ammo.qty or 0)<=0 then self:addPopup(player.x,player.y-18,"EQUIP ARROWS","miss");if logger then logger:log("COMBAT_ATTACK_BLOCKED",{reason="no_ammo",target=enemy.kind}) end;return false,"no_ammo" end end
 if isRanged and ammoType=='Snake Fang Arrows'and skills:get('Ranged').level<30 then return false,'ammo_level'end
 if isRanged and equipment.ammo.name=='Cave Snake Quiver'and skills:get('Ranged').level<30 then return false,'ammo_level'end
 if not player:spendStamina(7,skills,logger,"combat") then player:staminaWarning(self,logger,"combat");player.attackCooldown=.35;return false,"no_stamina" end
 if not isRanged then require("game.audio").play("swing",player.x,player.y) end;local info=require('game.quality').info(weapon and sprites.itemInfo[weapon]or nil,require('game.quality').object(equipment,'weapon'));local speed=(info and info.attackSpeed) or 1.15;if (player.burst or 0)>0 and not isRanged then speed=speed/4 end;local accuracy=(info and info.accuracy) or 0;speed=require("game.religion").attackCooldown(skills,speed);player.attackCooldown=speed;player:pulseTool(math.min(.28,speed*.45))
 local eb=Combat.enchantBonuses(equipmentSockets);for k,v in pairs(Combat.gearBonuses(player.gear or {})) do eb[k]=(eb[k] or 0)+v end;local melee=skills:get("Melee Combat").level+(isRanged and 0 or eb.melee);local ranged=skills:get("Ranged").level+(isRanged and eb.ranged or 0);local combatLevel=isRanged and ranged or melee;local strength=skills:get("Strength").level;local hitChance=math.min(.95,.68+combatLevel*.008+accuracy*.012);local maxDamage=Combat.maxDamage(info,strength);local dealt=math.floor((math.random(1,maxDamage)+eb.damage)*10+.5)/10;dealt=math.floor(require("game.religion").physicalDamage(skills,dealt)*10+.5)/10;if isRanged and ammoType=="Iron Arrows" then dealt=dealt+1 end;if (player.warriorYell or 0)>0 and not isRanged then dealt=math.floor(dealt*1.25*10+.5)/10 end
 if isRanged then equipment.ammo.qty=equipment.ammo.qty-1;if equipment.ammo.qty<=0 then if require('game.advanced_gear').isQuiver(equipment.ammo.name) then equipment.ammo.qty=0;equipment.ammo.arrowType=nil else equipment.ammo=nil end end;local d=math.max(1,math.sqrt(dx*dx+dy*dy));self.playerArrows[#self.playerArrows+1]={x=player.x,y=player.y-3,sx=player.x,sy=player.y-3,vx=dx/d*220,vy=dy/d*220,target=enemy,life=d/220,hit=math.random()<=hitChance,damage=dealt,ranged=ranged,ammoType=ammoType,owner=player,skills=skills,logger=logger};if logger then logger:log("BOW_FIRED",{target=enemy.kind,range=math.floor(d),ammoRemaining=equipment.ammo and equipment.ammo.qty or 0,race=player.race}) end;return true,"fired" end
 if math.random()>hitChance then self:addPopup(enemy.x,enemy.y-12,"MISS","miss");if logger then logger:log("COMBAT_MISS",{x=enemy.x,y=enemy.y,target=enemy.kind,weapon=weapon or "unarmed",meleeLevel=melee}) end;return true,"miss" end
 require("game.party").threat(self,enemy,player,dealt);enemy.hp=math.max(0,enemy.hp-dealt);local kx,ky=enemy.x-player.x,enemy.y-player.y;local kd=math.max(1,math.sqrt(kx*kx+ky*ky));enemy.hitKickX=kx/kd*2;enemy.hitKickY=ky/kd*2;enemy.hitFlash=.11;self:emitJuice(enemy.x,enemy.y-3,"hit",5,self:enemyJuiceColor(enemy));self:addPopup(enemy.x,enemy.y-12,dealt,"damage");addSkillXP(skills,"Melee Combat",dealt*4,logger);addSkillXP(skills,"Strength",dealt*4,logger);addSkillXP(skills,"Health",dealt*1.33,logger);if not weapon then addSkillXP(skills,"Love Making",dealt*12,logger) end
 if logger then logger:log("COMBAT_HIT",{x=enemy.x,y=enemy.y,target=enemy.kind,weapon=weapon or "unarmed",damage=dealt,targetHp=enemy.hp}) end
 if enemy.hp<=0 then self:defeatEnemy(enemy,skills,logger) end
 return true,"hit"
end
local function enemyDef(e) return e.customDefinition or enemyDefs[e.kind] end
function World:enemyBlocked(x,y,ignoreEnemy)
 if require("game.fences").blocked(self,x,y,ignoreEnemy) then return true end
 local p=self.playerRef;if p and (x-p.x)^2+(y-p.y)^2<13^2 then return true end
 if not self.map:isLand(x,y+4) then return true end
 local px,py=x,y+4;local pr=5
 if circleHit(px,py,pr,self.bankChest.x,self.bankChest.y+3,11) then return true end
 for _,n in ipairs(self.tradeKeepers) do if circleHit(px,py,pr,n.x,n.y+4,7) then return true end end;for _,n in ipairs(self.traders or {}) do if circleHit(px,py,pr,n.x,n.y+4,7) then return true end end
 for _,n in ipairs(self.healers) do if circleHit(px,py,pr,n.x,n.y+4,7) then return true end end
 for _,st in ipairs({self.smelter,self.anvil,self.tanningVat,self.hideStretcher,self.spinningWheel,self.loom,self.metalLoom,self.alchemy,self.tailoring}) do if circleHit(px,py,pr,st.x,st.y+3,8) then return true end end
 for _,n in ipairs(NodeIndex.at(self,x,y)) do if not n.depleted and (n.kind=="tree" or (n.kind=="oak" or n.kind=="poplar") or n.kind=="copper" or n.kind=="tin" or n.kind=="iron" or n.kind=="coal") then local nr=(n.kind=="tree" or (n.kind=="oak" or n.kind=="poplar")) and 6 or 9;local ny=(n.kind=="tree" or (n.kind=="oak" or n.kind=="poplar")) and n.y+9 or n.y+3;if circleHit(px,py,pr,n.x,ny,nr) then return true end end end
 for _,house in ipairs(self.houses) do
  local left,top,width,height=Houses.bounds(house)
  if (require("game.modular_houses").is(house) and require("game.modular_houses").blocked(house,px,py,pr)) or (not require("game.modular_houses").is(house) and px+pr>left and px-pr<left+width and py+pr>top and py-pr<top+height) then return true end
 end
 for _,other in ipairs(self.enemies) do if other~=ignoreEnemy and not other.inactive and not other.dead and circleHit(px,py,pr,other.x,other.y+4,6) then return true end end
 return false
end
local function moveToward(world,e,tx,ty,speed,dt)
 require('game.navigation').move(world,e,tx,ty,speed,dt)
end
function World:enemyMainText(e) return e.mainSkill.." "..e.mainCombat end
function World:projectileBlocked(x,y)
 if require("game.fences").blocked(self,x,y) then return true end
 if not self.map:isLand(x,y+4) then return true end
 for _,h in ipairs(self.houses) do local left,top,width,height=Houses.bounds(h);if (require("game.modular_houses").is(h) and require("game.modular_houses").blocked(h,x,y,0)) or (not require("game.modular_houses").is(h) and x>left and x<left+width and y>top and y<top+height) then return true end end
 for _,n in ipairs(NodeIndex.at(self,x,y)) do if not n.depleted and (n.kind=="tree" or (n.kind=="oak" or n.kind=="poplar") or n.kind=="copper" or n.kind=="tin" or n.kind=="iron" or n.kind=="coal") then local nr=(n.kind=="tree" or (n.kind=="oak" or n.kind=="poplar")) and 6 or 9;local ny=(n.kind=="tree" or (n.kind=="oak" or n.kind=="poplar")) and n.y+9 or n.y+3;if circleHit(x,y,2,n.x,ny,nr) then return true end end end
 for _,st in ipairs({self.bankChest,self.smelter,self.anvil,self.tanningVat,self.hideStretcher,self.spinningWheel,self.loom,self.metalLoom,self.alchemy,self.stove,self.magicAltar,self.religionAltar,self.socketTable,self.enchantAltar,self.inscription,self.tailoring}) do if st and circleHit(x,y,2,st.x,st.y+3,8) then return true end end
 return false
end

function World:fireSlimeProjectile(e,player,logger)
 local dx,dy=player.x-e.x,player.y-e.y;local d=math.sqrt(dx*dx+dy*dy);if d<1 then d=1 end
 self.enemyProjectiles[#self.enemyProjectiles+1]={x=e.x,y=e.y,vx=dx/d*105,vy=dy/d*105,targetX=player.x,targetY=player.y,life=math.min(1.5,d/105+.1),owner=e}
 if logger then logger:log("SLIME_RANGED_ATTACK",{tier=e.tier,ranged=e.stats.ranged,targetX=math.floor(player.x),targetY=math.floor(player.y)}) end
end

function World:setNightState(isNight,logger)
 if self.isCave then return end
 if self._nightState==isNight then return end
 self._nightState=isNight
 if isNight then require('game.caves').ensure(self);require('game.caves').replenish(self);for i=1,4 do self:trySpawnGoblin(self.playerRef) end end
 for _,e in ipairs(self.enemies) do
  local shouldActive=not e.cagedLocked and not ((e.nightOnly and not isNight) or (e.dayOnly and isNight))
  if shouldActive and e.inactive then
   e.inactive=false;e.aggro=false;e.state="idle";e.x,e.y=e.spawnX,e.spawnY
   if not e.dead then
    if self:playerInZone(3) and e.kind=="slimeBoss" then self.notifications[#self.notifications+1]={text="BOSS SLIME HAS APPEARED!",t=5}
    elseif self:playerInZone(3) and e.kind=="gigaRat" then self.notifications[#self.notifications+1]={text="GIGA RAT HAS APPEARED!",t=5} end
   end
   if logger then logger:log("ENEMY_TIME_ACTIVATED",{enemy=e.kind,night=tostring(isNight)}) end
  elseif not shouldActive and not e.inactive then
   e.inactive=true;e.aggro=false
   if self.targetedEnemy==e then self.targetedEnemy=nil end
   if self.combatTarget==e then self:stopCombat("time_of_day",logger) end
   if logger then logger:log("ENEMY_TIME_DESPAWNED",{enemy=e.kind,night=tostring(isNight)}) end
  end
 end
end

function World:updateCombat(dt,player,skills,equipment,sprites,logger,equipmentSockets,inventory)
 require('game.caves').cleared(self)
 if self.isCave then for _,e in ipairs(self.enemies)do if e.dead then e.respawnTimer=1e9 end end end
 player.gear=equipment
 if not self._navigationPrepared then require("game.navigation").begin(self,dt,player) end;self._navigationPrepared=nil
 require("game.party").update(self,dt,player,sprites,inventory,equipment)
 for i=#self.enemies,1,-1 do local e=self.enemies[i];if (e.kind=="goblin"or e.kind=="nagalian") and e.dead then
  require("game.goblins").drop(self,e)
  if self.targetedEnemy==e then self.targetedEnemy=nil end
  if self.combatTarget==e then self:stopCombat("target_defeated",logger) end
  if e.kind=='goblin'and not e.editorSpawnZone then table.remove(self.enemies,i)end
 end end
 require('game.goblin_camps').update(self)
 require('game.nagalians').update(self,dt)
 self.goblinSpawnTimer=(self.goblinSpawnTimer or 90)-dt
 if self.goblinSpawnTimer<=0 then
  self.goblinSpawnTimer=90
  if self._nightState then self:trySpawnGoblin(player) end
 end
 require("game.bonfire_buff").visit(self,player);local baseMaxHp=require("game.races").maxHealth(player.race,skills:get("Health").level);player.maxHp=require("game.bonfire_buff").active(player) and math.max(baseMaxHp+1,math.floor(baseMaxHp*1.2+.5)) or baseMaxHp;if player.hp>player.maxHp then player.hp=player.maxHp end
 local target=self.combatTarget
 if target then
  if target.dead then self:stopCombat("target_dead",logger)
  else local tdx,tdy=target.x-player.x,target.y-player.y;local attackRange=(player.equipped=="Bow" or tostring(player.equipped):match(" Bow$")) and self:bowRange(player) or (38+math.max(0,(target.hitRadius or 14)-14));if tdx*tdx+tdy*tdy<=attackRange^2 and player.attackCooldown<=0 then self:attackEnemy(target,player,skills,equipment,sprites,logger,equipmentSockets) end end
 end
 for i=#self.popups,1,-1 do local p=self.popups[i];p.time=p.time-dt;p.y=p.y-dt*10;if p.time<=0 then table.remove(self.popups,i) end end
 for i=#self.playerArrows,1,-1 do local p=self.playerArrows[i];p.x=p.x+p.vx*dt;p.y=p.y+p.vy*dt;p.life=p.life-dt;if p.life<=0 then self:resolvePlayerArrow(p,skills,logger);table.remove(self.playerArrows,i) end end
 -- Enemy projectiles land as poison puddles.
 for i=#self.enemyProjectiles,1,-1 do local p=self.enemyProjectiles[i];p.x=p.x+p.vx*dt;p.y=p.y+p.vy*dt;p.life=p.life-dt;if p.life<=0 then self.slimePuddles[#self.slimePuddles+1]={x=p.targetX,y=p.targetY,time=7,inside=0,tick=0};table.remove(self.enemyProjectiles,i);if logger then logger:log("SLIME_PUDDLE_CREATED",{x=math.floor(p.targetX),y=math.floor(p.targetY),duration=7}) end end end
 for i=#self.slimePuddles,1,-1 do local puddle=self.slimePuddles[i];puddle.time=puddle.time-dt
  local players={player};if self.onlineActors then players={};for _,a in ipairs(self.onlineActors)do players[#players+1]=a.player end end
  puddle.onlineInside=puddle.onlineInside or{}
  for _,p in ipairs(players)do local key=p.onlineId or 0;local inside=puddle.onlineInside[key]or puddle.inside or 0
   if(p.x-puddle.x)^2+(p.y-puddle.y)^2<=15^2 then inside=inside+dt;if inside>=1 and(p.poisonImmuneTimer or 0)<=0 then p.poisonedTimer=4;p.poisonTick=math.min(p.poisonTick or 0,.05)end else inside=0 end
   puddle.onlineInside[key]=inside;if key==0 then puddle.inside=inside end
  end
  if puddle.time<=0 then table.remove(self.slimePuddles,i)end
 end
 for _,e in ipairs(self.enemies) do
  local player,skills,equipment=player,skills,equipment
  local inherited=require('game.slime_minions').follow(self,e,player)
  if self.onlineActors then local nearest,best;local threat=inherited or require('game.party').target(e);for _,a in ipairs(self.onlineActors)do local dd=(a.player.x-e.x)^2+(a.player.y-e.y)^2;if threat==a.player and(inherited or dd<=250^2)then nearest=a;break end;if not best or dd<best then nearest,best=a,dd end end;if nearest then player,skills,equipment=nearest.player,nearest.skills,nearest.equipment end end
  local d=enemyDef(e);if inherited then local original=d;d={};for k,v in pairs(original)do d[k]=v end;d.leash=math.max(300,d.leash or 0)end
  if e.kind=='nagaQueen'then
   if e.dead and not e.nagaWasDead then require('game.naga_queen').onDeath(self,e);e.nagaWasDead=true;e.respawnTimer=require('game.naga_queen').respawn;e.nagaPhase='rest';e.nagaTimer=8
   elseif not e.dead and e.nagaWasDead then e.nagaWasDead=nil;e.nagaLootDropped=nil;e.nagaPhase='rest';e.nagaTimer=8 end
  end
  if e.cagedLocked then
   e.aggro=false;e.state='caged';e.x,e.y=e.spawnX,e.spawnY;e.roamX,e.roamY=e.spawnX,e.spawnY
  elseif e.inactive then
   e.aggro=false
  elseif e.dead then
   e.respawnTimer=e.respawnTimer-dt;if e.respawnTimer<=0 and not e.inactive and (e.x-player.x)^2+(e.y-player.y)^2>110^2 then require("game.cursed_enemies").reset(e);e.dead=false;e.skinned=false;e.wolfHeadRolled=nil;e.wolfHeadDrop=nil;e.lootDropped=nil;if e.kind=='nagalian'then require('game.nagalians').configure(self,e)end;if e.editorSpawnZone and e.kind=="goblin" then require("game.goblins").equip(e) end;e.expansionLoot=nil;e.skinDrops=nil;e.lootPaid=nil;e.randomLoot=nil;e.snakeLoot=nil;e.huntingXpAwarded=nil;e.x,e.y=e.spawnX,e.spawnY;e.hp=e.maxHp;e.attackTimer=d.attackSpeed;e.aggro=false;e.state="idle";e.roamTimer=1;if self:playerInZone(3) and e.kind=="slimeBoss" then self.notifications[#self.notifications+1]={text="BOSS SLIME HAS APPEARED!",t=5} elseif self:playerInZone(3) and e.kind=="gigaRat" then self.notifications[#self.notifications+1]={text="GIGA RAT HAS APPEARED!",t=5} end;if logger then logger:log("ENEMY_RESPAWNED",{x=e.x,y=e.y,enemy=e.kind,tier=e.tier,level=e.level}) end end
  elseif (e.x-player.x)^2+(e.y-player.y)^2>1100^2 and not e.aggro and e.state~="return" then
   -- Off-camera wilderness AI sleeps. It wakes seamlessly as the player approaches.
   e.state="idle";e.roamTimer=math.min(e.roamTimer or 1,1)
  elseif require('game.naga_queen').turn(self,e,dt,player,skills) then
  elseif require("game.party").enemyTurn(self,e,dt) then
  else
   local pdx,pdy=player.x-e.x,player.y-e.y;local playerD2=pdx*pdx+pdy*pdy;if (e.kind=='rat' or e.kind=='wolf' or e.kind=='boar' or e.kind=='gigaRat' or e.kind=='cow' or e.kind=='chicken') and e.aggro and math.abs(pdx)>.5 then e.facing=pdx>0 and -1 or 1 elseif e.kind=="gigaRat" and math.abs(pdx)>.5 then e.facing=pdx>0 and -1 or 1 end;local sdx,sdy=e.x-e.spawnX,e.y-e.spawnY;local spawnD2=sdx*sdx+sdy*sdy
   if not e.aggro and e.state~="return" and playerD2<=d.aggro*d.aggro then e.aggro=true;e.state="chase";self.targetedEnemy=e;if logger then logger:log("ENEMY_AGGRO",{x=e.x,y=e.y,enemy=e.kind,tier=e.tier,level=e.level,mainSkill=e.mainSkill,mainCombat=e.mainCombat}) end end
   if e.aggro and (spawnD2>d.leash*d.leash or playerD2>d.leash*d.leash) then e.aggro=false;e.state="return";if self.targetedEnemy==e then self.targetedEnemy=nil end;if self.combatTarget==e then self:stopCombat("enemy_disengaged",logger) end;if logger then logger:log("ENEMY_DISENGAGE",{enemy=e.kind,reason="leash"}) end end
   if e.aggro then
    e.attackTimer=e.attackTimer-dt
    if e.kind=='nagalian'and require('game.nagalians').rangedTurn(self,e,player,playerD2)then
    elseif e.kind=="goblin" and e.weapon=="Bow" and (e.arrows or 0)>0 and playerD2<=120^2 then
     e.state="ranged";if e.attackTimer<=0 then e.attackTimer=1.8;require("game.goblins").shoot(self,e,player) end
    elseif e.kind=="slime" and playerD2>d.attackRange*d.attackRange and playerD2<=d.rangedRange*d.rangedRange then
     e.state="ranged";if e.attackTimer<=0 then e.attackTimer=d.attackSpeed;self:fireSlimeProjectile(e,player,logger) end
    elseif playerD2>d.attackRange*d.attackRange then e.state="chase";moveToward(self,e,player.x,player.y,d.speed,dt)
    else
     e.state="combat";if e.attackTimer<=0 then
      e.attackTimer=d.attackSpeed;local agility=skills:get("Agility").level;local evade=math.min(.45,.08+(agility-1)*.006)
      if math.random()<evade then self:addPopup(player.x,player.y-14,"MISS","miss");addSkillXP(skills,"Agility",2,logger);if logger then logger:log("ENEMY_MISS",{enemy=e.kind,tier=e.tier,melee=e.stats.melee,agilityLevel=agility}) end
      else local defence=Combat.defense(equipment);if (player.warriorYell or 0)>0 then defence=defence+4 end;if require("game.bonfire_buff").active(player) then defence=math.floor(defence*1.2+.5) end;local raw=require("game.progression").roll(e.stats.melee,e.kind=='nagalian'and require('game.nagalians').weaponInfo(e,self.sprites)or{damage=math.max(1,e.stats.melee)},e.stats.strength);local blocked=math.max(0,math.min(raw-1,math.floor(defence/3)));local dealt=math.max(0,raw-blocked);dealt=math.floor(require("game.religion").physicalTaken(skills,dealt)*10+.5)/10;if dealt>0 then player.damageSerial=(player.damageSerial or 0)+1;player.lastDamageSource=e.customName or e.kind end;player.hp=math.max(0,player.hp-dealt);require("game.survival_foraging").damage(player,skills,dealt,e.netId or (e.kind..":"..e.x..":"..e.y));self:emitJuice(player.x,player.y-3,"playerhit",5);self:addPopup(player.x,player.y-14,dealt,"damage");if blocked>0 then self:addPopup(player.x+10,player.y-4,"DEF -"..blocked,"defence") end;addSkillXP(skills,"Agility",1,logger);if logger then logger:log("PLAYER_DAMAGED",{x=player.x,y=player.y,enemy=e.kind,tier=e.tier,enemyMelee=e.stats.melee,raw=raw,defence=defence,blocked=blocked,damage=dealt,hp=player.hp,maxHp=player.maxHp}) end end
     end
    end
   elseif e.state=="return" then
    moveToward(self,e,e.spawnX,e.spawnY,d.speed*1.1,dt);local rx,ry=e.x-e.spawnX,e.y-e.spawnY;if rx*rx+ry*ry<5*5 then e.x,e.y=e.spawnX,e.spawnY;e.state="idle";e.roamTimer=1;if logger then logger:log("ENEMY_RESET",{enemy=e.kind}) end end
   else
    e.state="roam";e.roamTimer=e.roamTimer-dt;if e.roamTimer<=0 then local a=math.random()*math.pi*2;local r=math.sqrt(math.random())*d.roam;e.roamX=e.spawnX+math.cos(a)*r;e.roamY=e.spawnY+math.sin(a)*r;e.roamTimer=math.random()*3+1;if logger then logger:log("ENEMY_ROAM",{enemy=e.kind,x=math.floor(e.roamX),y=math.floor(e.roamY)}) end end;moveToward(self,e,e.roamX,e.roamY,d.speed*.35,dt)
   end
  end
 end
 require("game.fang_poison").update(self,dt)
 require("game.goblins").updateShots(self,dt,player)
 Expansion.update(self,dt,player)
 if player.hp<=0 then self:respawnPlayer(player,logger)end
 if self.targetedEnemy and self.targetedEnemy.dead then self.targetedEnemy=nil end
end

function World:respawnPlayer(player,logger)
 local a;for _,actor in ipairs(self.onlineActors or{})do if actor.player==player then a=actor;break end end;a=a or self.graveActor
 if a then require("game.gravestones").die(self,a);player.graveDeathPending=true end
require("game.audio").play("death_jingle");for _,qs in pairs(player.quests or {})do if qs.active and qs.active.kind=="escort" then qs.active=nil;self.notifications[#self.notifications+1]={text="Escort failed: you were defeated.",t=6}end end;if self.isCave then self.caveExitRequested=true;self.deathRespawn=true end;self:stopCombat("player_defeated",logger);for _,e in ipairs(self.enemies) do e.aggro=false;if not e.dead then e.state="return" end end;local rx,ry=self.map.width/2,self.map.height/2+55;local best=math.huge;for _,v in ipairs(self.villages or {}) do local dx,dy=v.cx-player.x,v.cy-player.y;local dd=dx*dx+dy*dy;if dd<best then best=dd;rx,ry=v.cx,v.cy+35 end end;local sx,sy=require("game.respawn").player(self,player.x,player.y,player,a and a.campOwner);if sx then rx,ry=sx,sy end;player.x,player.y=rx,ry;player.hp=player.maxHp;player.lastDamageSource=nil;player.slimeCoated=0;player.slimeBreathTick=0;player.poisonedTimer=0;player.poisonTick=0;self:addPopup(player.x,player.y-14,"RESPAWN","defeat");if logger then logger:log("PLAYER_RESPAWNED",{}) end 
end
function World:addSwing(s) if s then require("game.audio").play("swing",s.x,s.y);self.swings[#self.swings+1]=s end end

function World:sheepAt(x,y)
 local best,bestD=nil,math.huge
 for i=#self.sheep,1,-1 do local sh=self.sheep[i];local dx,dy=x-sh.x,y-sh.y;local d=dx*dx+dy*dy;if not sh.dead and d<=18*18 and d<bestD then best,bestD=sh,d end end
 return best
end
function World:canShearSheep(sh,player,inventory,equipment)
 equipment=equipment or {}
 if not sh or sh.dead then return false,"no_sheep" end
 local dx,dy=sh.x-player.x,sh.y-player.y;if dx*dx+dy*dy>42*42 then return false,"too_far" end
 if not sh.wool then return false,"already_shorn" end
 local function equippedName(v) return type(v)=="table" and v.name or v end
 local hasShears=inventory:countItem("Shears")>0 or (equippedName(equipment.weapon)=="Shears" or equippedName(equipment.offhand)=="Shears")
 if not hasShears then return false,"requires_shears" end
 if not inventory:canAdd("Wool",1) then return false,"bag_full" end
 return true
end
function World:shearSheep(sh,player,inventory,equipment,logger)
 local ok,why=self:canShearSheep(sh,player,inventory,equipment);if not ok then return false,why end
 inventory:add("Wool",1);sh.wool=false;sh.woolTimer=60
 if logger then logger:log("SHEEP_SHEARED",{x=sh.x,y=sh.y,item="Wool",regrowSeconds=60}) end
 return true,"Wool"
end

require("game.world_jobs").install(World)
require("game.fieldcraft").install(World)
require("game.survival_foraging").install(World)
require('game.lumber').installWorld(World)
return World
