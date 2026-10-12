local R={}
R.milestoneLevels={1,10,20,30,40,50,60,75,90,99}
R.milestones={[1]='Blessing',[10]='Patient Faith',[20]='Efficient Invocation',[30]='Devotion',[40]='Spiritual Ward',[50]='Greater Blessing',[60]='Divine Favor',[75]='Sacred Resolve',[90]='Exalted Devotion',[99]='Consecration'}
R.blessXP={['Charred Wood']=4,['Fish Bones']=4,['Stone Gravel']=4,['Stone Pieces']=4,['Carved Feather']=5,['Green Slime Tube']=6,['Carved Onyx']=8,['Cave Snake Fang']=6}
function R.requiredLevel(name)
 local level
 for _,spell in pairs(require('game.magic_system').spells)do if spell.rune==name then level=math.min(level or 99,spell.level or 1)end end
 if name=='Stone Pieces'then return R.requiredLevel('Stone Gravel')end
 return level or 1
end
function R.canBless(skills,name)return R.level(skills)>=R.requiredLevel(name)end
-- Total modifiers replace previous tiers. Faith trades physical attack speed
-- for stronger hits, protection and more efficient offensive spellcasting.
local totals={
 [1]={physicalDamage=.005},
 [10]={physicalDamage=.01,physicalRes=.01,attackSpeed=-.005},
 [20]={physicalDamage=.02,physicalRes=.015,runeSave=.02,attackSpeed=-.01},
 [30]={physicalDamage=.03,physicalRes=.02,runeSave=.03,magicDamage=.03,attackSpeed=-.015},
 [40]={physicalDamage=.04,physicalRes=.03,runeSave=.04,magicDamage=.04,attackSpeed=-.02},
 [50]={physicalDamage=.05,physicalRes=.04,runeSave=.05,magicDamage=.05,attackSpeed=-.025},
 [60]={physicalDamage=.06,physicalRes=.05,runeSave=.06,magicDamage=.06,attackSpeed=-.03},
 [75]={physicalDamage=.08,physicalRes=.06,runeSave=.08,magicDamage=.08,attackSpeed=-.04},
 [90]={physicalDamage=.10,physicalRes=.08,runeSave=.10,magicDamage=.10,attackSpeed=-.05},
 [99]={physicalDamage=.12,physicalRes=.10,runeSave=.12,magicDamage=.12,attackSpeed=-.06}
}
local effects={{'physicalDamage','Physical damage'},{'physicalRes','Physical damage reduction'},{'magicDamage','Offensive spell damage'},{'runeSave','Chance to preserve a spell rune'},{'attackSpeed','Physical attack speed'}}
local function tier(level)local chosen=1;for _,v in ipairs(R.milestoneLevels)do if level>=v then chosen=v end end;return chosen end
local function percent(n)return string.format('%+.1f%%',n*100)end
function R.description(level)
 level=tier(level);local values=totals[level];local lines={'Automatic passive milestone at Religion '..level..'. Total effects replace previous milestones; they do not stack.'}
 for _,e in ipairs(effects)do if values[e[1]]then lines[#lines+1]=e[2]..': '..percent(values[e[1]])end end
 if values.attackSpeed then lines[#lines+1]='Tradeoff: physical attacks have a longer cooldown. Spell cooldowns are unchanged.'end
 lines[#lines+1]='Successful spell casts award '..(level>=75 and 3 or level>=30 and 2 or 1)..' base Religion XP.'
 lines[#lines+1]='Train by carving Feathers or blessing rune materials. Religion Altars award 2x blessing XP per item, without an action cap. Rune materials require Religion equal to their matching spell\'s Magic level. Race XP bonuses apply.'
 return table.concat(lines,'\n')
end
function R.unlocks()local rows={};for _,name in ipairs(require('game.rune_quality').names)do rows[#rows+1]={level=R.requiredLevel(name),text='Bless '..name,detail='Blessing requires Religion '..R.requiredLevel(name)..'. Awards '..(R.blessXP[name]or 4)..' base XP per item, doubled at a Religion Altar. Grades are preserved.'}end;for _,level in ipairs(R.milestoneLevels)do rows[#rows+1]={level=level,text=R.milestones[level],detail=R.description(level)}end;for _,g in ipairs(require('game.gravestones').types)do rows[#rows+1]={level=g.level,text=g.name,detail=g.hp..' HP; protects carried belongings for 1 minute after death. Higher Religion blessings add time, without healing the grave.'}end;table.sort(rows,function(a,b)return a.level<b.level end);return rows end
function R.carveFeather(inv,skills)
 local trial=require('game.rune_inventory').clone(inv)
 if not trial:removeItems('Feather',1)then return false,'Need a Feather'end
 if not require('game.quality').add(trial,'Carved Feather',1,skills:get('Religion').level,require('game.inventory').add)then return false,'Bags full'end
 inv.bagSlots=trial.bagSlots
 local old,new,total,gained=skills:addXP('Religion',4)
 return true,'Carved Feather',gained or 4
end
function R.level(skills) local s=skills and skills:get('Religion');return math.max(1,math.min(99,s and s.level or 1)) end
function R.modifiers(skills) return totals[tier(R.level(skills))] or totals[1] end
function R.physicalDamage(skills,v) return v*(1+(R.modifiers(skills).physicalDamage or 0)) end
function R.physicalTaken(skills,v) return v*(1-(R.modifiers(skills).physicalRes or 0)) end
function R.magicDamage(skills,v) return v*(1+(R.modifiers(skills).magicDamage or 0)) end
function R.magicHealing(skills,v) return v*(1+(R.modifiers(skills).magicHeal or 0)) end
function R.maxHealth(skills,v) return v*(1+(R.modifiers(skills).maxHealth or 0)) end
function R.attackCooldown(skills,v) return v/(1+(R.modifiers(skills).attackSpeed or 0)) end
function R.runePreserved(skills) return math.random()<(R.modifiers(skills).runeSave or 0) end
function R.spellXP(skills) local level=R.level(skills);return level>=75 and 3 or level>=30 and 2 or 1 end
function R.startAnimation(ui) if ui and ui.player then ui.player.religionBlessAnim={t=0,duration=.8} end end
function R.updateAnimation(player,dt) local a=player and player.religionBlessAnim;if a then a.t=a.t+dt;if a.t>=a.duration then player.religionBlessAnim=nil end end end
function R.blessInventory(ui,altar)
 if require("game.multiplayer").active then return require("game.fieldcraft_ui").command(ui,{op="bless",altar=altar==true},function(ok)if ok then R.startAnimation(ui)end end)end
 local stacks,units,xp,locked=0,0,0,0
 for bi=1,4 do local bag=ui.inv.bagSlots[bi];if bag then for si=1,bag.size do local v=bag.slots[si];local info=v and ui.sprites.itemInfo[v.name];local base=v and R.blessXP[v.name];if v and (base or (info and info.blessable)) and not v.blessed then local qty=v.qty or 1;if R.canBless(ui.skills,v.name)then v.blessed=true;stacks=stacks+1;units=units+qty;xp=xp+(base or 4)*qty else locked=locked+qty end end end end end
 if units>0 then
  if altar then xp=xp*2 end
  local old,new,total,gained=ui.skills:addXP('Religion',xp);R.startAnimation(ui);require('game.audio').play('bless_runes',ui.player.x,ui.player.y)
  ui.world:addPopup(ui.player.x,ui.player.y-22,(altar and 'ALTAR BLESSING +' or 'BLESSED ')..units..'  RELIGION +'..math.floor(gained or xp)..' XP','defeat')
  if ui.logger then ui.logger:log('RUNE_MATERIALS_BLESSED',{stacks=stacks,qty=units,religionXp=gained or xp,altar=tostring(altar==true),level=new,totalXp=total}) end
  return true,units,gained or xp
 end
 ui.world:addPopup(ui.player.x,ui.player.y-22,locked>0 and'RELIGION LEVEL TOO LOW FOR THESE MATERIALS'or'NOTHING TO BLESS','miss');return false,0,0
end
return R
