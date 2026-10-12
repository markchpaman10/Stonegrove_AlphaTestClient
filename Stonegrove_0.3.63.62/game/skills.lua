local Races=require("game.races")
local Skills={}; Skills.__index=Skills
local names={"Prospecting","Mining","Woodcutting","Woodworking","Smithing","Melee Combat","Strength","Agility","Health","Skinning","Leatherworking","Fletching","Ranged","Alchemy","Jewel Crafting","Magic","Fishing","Cooking","Enchanting","Inscription","Tailoring","Commanding","Firemaking","Religion","Love Making","Fieldcraft","Survival","Foraging"}
Skills.names=names
local function buildTable()
  local t={[1]=0}; local points=0
  for level=1,98 do
    points=points+math.floor(level+300*(2^(level/7)))
    t[level+1]=math.floor(points/4)
  end
  return t
end
local xpTable=buildTable()
function Skills.new()
  local self=setmetatable({race="Human",data={},xpTable=xpTable,pendingLevelUps={}},Skills)
  for _,n in ipairs(names) do self.data[n]={xp=0,level=1} end
  return self
end
function Skills:levelForXP(xp)
  local low,high=1,99
  while low<high do
    local mid=math.floor((low+high+1)/2)
    if xp>=self.xpTable[mid] then low=mid else high=mid-1 end
  end
  return low
end
local legacy={Crafting='Jewel Crafting',['Jewel Cutting']='Jewel Crafting'}
local function xp(v) local n=type(v)=='table' and tonumber(v.xp) or 0;if not n or n~=n or n==math.huge then return 0 end;return math.max(0,n) end
function Skills:load(saved)
 saved=saved or {};for name,v in pairs(self.data) do
  local amount=xp(saved[name]);if name=='Religion' and not saved[name] and saved.Hunting then amount=xp(saved.Hunting) end;if name=='Jewel Crafting' and not saved[name] then amount=xp(saved.Crafting)+xp(saved['Jewel Cutting']) end
  v.xp=amount;v.level=self:levelForXP(amount)
 end
 self.pendingLevelUps={};self.pendingGains={}
end
function Skills:setRace(race) self.race=Races.normalize(race) end
function Skills:xpMultiplier(name) return Races.multiplier(self.race,legacy[name] or name)*require('game.content_rules').skillMultiplier(legacy[name]or name) end
function Skills:addXP(name,amount)
  name=legacy[name] or name;local s=self.data[name]; if not s then return nil end
  local context=self.fieldcraftContext;if name=="Religion"and context then amount=amount*require("game.bone_religion").factor(context.world,context.actor.player)end
  local gained=amount*self:xpMultiplier(name)
  self.pendingGains=self.pendingGains or {};if gained>0 then self.pendingGains[name]=(self.pendingGains[name] or 0)+gained end
  local old=s.level; s.xp=s.xp+gained; s.level=self:levelForXP(s.xp)
  if name=="Strength"and self.bagInventory then self.bagInventory:applyStrengthBagBonus(s.level)end
  if s.level>old then require("game.audio").play("skill_level_up");self.pendingLevelUps[#self.pendingLevelUps+1]={skill=name,level=s.level} end
  if gained>0 then require('game.fieldcraft').activity(self,name,gained);local context=self.fieldcraftContext;if context and context.actor.activityHighWater then context.actor.activityHighWater[name]=math.max(context.actor.activityHighWater[name]or 0,s.xp)end end
  if self.onGain and gained>0 then self.onGain(name,gained)end
  return old,s.level,s.xp,gained
end
function Skills:get(name) return self.data[legacy[name] or name] end
return Skills
