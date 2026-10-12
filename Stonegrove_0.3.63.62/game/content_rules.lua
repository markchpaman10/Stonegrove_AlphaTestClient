-- Optional, shared project overrides. Empty projects preserve the original rules.
local R={};local cache,ordered,indexed,doc;local states=setmetatable({},{__mode='k'})
function R.data()local d=require('content_data');if d~=doc then doc=d;cache={};ordered={};indexed={};for _,g in ipairs(require('game.content_schema').groups)do cache[g.key]={};ordered[g.key]={};indexed[g.key]={};for _,r in ipairs(d[g.key]or{})do if r.enabled~=false then cache[g.key][r.id]=r;ordered[g.key][#ordered[g.key]+1]=r;local key=({bosses="target",spawns="zone",equipment="item",skills="skill"})[g.key];if key then indexed[g.key][r[key]]=r end end end end end;return d end
function R.list(k)R.data();return ordered[k]or{} end
function R.rows(k)R.data();return cache[k]or{}end
function R.allowed(id,skills,player)
 if not id or id==''then return true end;local r=R.rows('progression')[id];if not r then return false,'Missing progression rule'end
 for _,c in ipairs(r.conditions or{})do if c.skill and c.skill~=''then local s=skills and skills.get and skills:get(c.skill);local combat=skills and skills.combatSkills and skills.combatSkills[c.skill];local lv=s and s.level or combat and combat.level or 1;if lv<(c.level or 1)then return false,c.skill..' level '..c.level..' required'end end
  if c.quest and c.quest~=''then local q=player and player.quests or{};local legacy=q['custom:'..c.quest];if not(q.__completedIds and q.__completedIds[c.quest])and not(legacy and(legacy.completed or 0)>0)then return false,'Complete quest '..c.quest end end
 end;return true
end
function R.gate(kind,target,skills,player)
 for _,r in ipairs(R.list('progression'))do if r.targetType==kind and r.target==target then local ok,e=R.allowed(r.id,skills,player);if not ok then return false,e end end end;return true
end
function R.skillMultiplier(name)R.data();local r=indexed.skills[name];return r and r.xpMultiplier or 1 end
function R.milestones(name)local out={};for _,r in ipairs(R.list('skills'))do if r.skill==name then for _,m in ipairs(r.milestones or{})do out[#out+1]={level=m.level,text=m.name}end end end;return out end
function R.equipment(name,info)
 R.data();local r=indexed.equipment[name];if r then local out={};for k,v in pairs(info or{})do out[k]=v end;for _,k in ipairs({'damage','defence','accuracy','attackSpeed','requiredSkill','requiredLevel'})do if r[k]~=nil then out[k]=r[k]end end;out.customEquipment=true;out.contentRule=r.rule;return out end;return info
end
function R.setBonuses(eq)
 local out={};for _,r in ipairs(R.list('equipmentSets'))do local n=0;for _,p in ipairs(r.pieces or{})do local name=type(eq[p.slot])=='table'and eq[p.slot].name or eq[p.slot];if name==p.item then n=n+1 end end;if n>0 and n>=(r.minimum or #(r.pieces or{}))then for _,k in ipairs({'defence','melee','ranged','magic','damage'})do out[k]=(out[k]or 0)+(r[k]or 0)end end end;return out
end
function R.recipes(recipes)
 for _,r in ipairs(R.list('recipes'))do local list=recipes[r.station];if list then
  if r.baseName and r.baseName~=''then for _,b in ipairs(list)do if b.name==r.baseName then for _,k in ipairs({'level','xp','duration','tool'})do if r[k]~=nil then b[k]=r[k]~=''and r[k]or nil end end;b.contentRule=r.rule end end
  else local needs={};for _,n in ipairs(r.needs or{})do needs[#needs+1]={n.item,n.qty}end;list[#list+1]={name=r.name,output=r.output,qty=r.qty or 1,skill=r.skill,level=r.level,xp=r.xp,duration=r.duration,tool=r.tool~=''and r.tool or nil,needs=needs,contentRecipe=true,contentRule=r.rule,contentId=r.id}end
 end end
end
function R.shop(shop,trade)
 for _,r in ipairs(R.list('shops'))do if (not r.trade or r.trade==''or r.trade==trade)and(not r.title or r.title==''or r.title==shop.title)then shop.contentProfile=r.id;shop.contentPrices={};shop.contentRestock=r.restock or 1800;shop.contentRestocked=os.time();shop.slots={};shop.accepted={};for _,s in ipairs(r.stock or{})do shop.slots[#shop.slots+1]={name=s.item,qty=s.qty};shop.contentPrices[s.item]={buy=s.buy,sell=s.sell,accepted=s.accepted};shop.accepted[s.item]=s.accepted end;break end end;return shop
end
function R.restock(shop,force)
 if not shop.contentProfile then return nil end
 local t=os.time();if not force and t-(shop.contentRestocked or t)<shop.contentRestock then return false end
 local r=R.rows('shops')[shop.contentProfile];if not r then return false end;local owned={};for _,s in ipairs(shop.slots)do if s.object then owned[#owned+1]=s end end;shop.slots={};for _,s in ipairs(r.stock or{})do shop.slots[#shop.slots+1]={name=s.item,qty=s.qty}end;for _,s in ipairs(owned)do shop.slots[#shop.slots+1]=s end;shop.contentRestocked=t;return true
end
local function matches(r,e)return r.target==(e.customMonster and'custom:'..e.customMonster or e.kind)end
function R.rolls(drops,w,e)
 for _,d in ipairs(drops or{})do if math.random()*100<d.chance then local qty=math.random(d.min,d.max);for i=1,qty do w:addGroundItem(d.item,e.x+(i%4)*3,e.y+math.floor(i/4)%4*3,false,{name=d.item,qty=1})end end end
end
function R.loot(w,e,base)
 -- Bone rewards always follow the original ownership and cursed-bone pipeline.
 local replace=false;for _,r in ipairs(R.list('lootTables'))do if matches(r,e)then replace=replace or r.replace;R.rolls(r.drops,w,e)end end
 for _,r in ipairs(R.list('bosses'))do if matches(r,e)then e.respawnTimer=r.respawn or e.respawnTimer;R.rolls(r.drops,w,e)end end
 if replace then local bones={};for _,n in ipairs(base)do if n=='Bones'then bones[#bones+1]=n end end;return bones end;return base
end
local function inHours(r,h)local a,b=r.startHour or 0,r.endHour or 0;if a==b then return true end;if a<b then return h>=a and h<b end;return h>=a or h<b end
function R.enemyTick(w,e,dt,player,skills,eq)
 R.data();local schedule=indexed.spawns[e.spawnPlacementId];local target=e.customMonster and'custom:'..e.customMonster or e.kind;local boss=indexed.bosses[target];local gated=false;for _,r in ipairs(R.list('progression'))do if r.targetType=='enemy'and r.target==target then gated=true;break end end;if not schedule and not boss and not gated then return end
 local state=states[e];if not state then state={timers={},dead=e.dead};states[e]=state end
 local enabled=not schedule or inHours(schedule,math.floor((w.contentDayTime or .3)*24))
 local function allowed(rule)local ok=R.allowed(rule,skills,player);if not ok and w.onlineActors then for _,a in ipairs(w.onlineActors)do if R.allowed(rule,a.skills,a.player)then return true end end end;return ok end
 enabled=enabled and(not schedule or allowed(schedule.rule))and(not boss or allowed(boss.rule))
 local ok=R.gate('enemy',target,skills,player);if not ok and w.onlineActors then for _,a in ipairs(w.onlineActors)do if R.gate('enemy',target,a.skills,a.player)then ok=true;break end end end;enabled=enabled and ok
 if not enabled then if not state.hidden then state.wasInactive=e.inactive;state.hidden=true end;e.inactive=true;e.aggro=false;if w.combatTarget==e then w:stopCombat('spawn_unavailable')end;return elseif state.hidden then e.inactive=state.wasInactive;state.hidden=nil end
 if e.dead and not state.dead then e.respawnTimer=boss and boss.respawn or schedule and schedule.respawn or e.respawnTimer end
 if not e.dead and state.dead then state.timers={};state.announced=nil end;state.dead=e.dead
 if not boss or e.dead or e.inactive then return end
 if not state.announced then state.announced=true;if boss.announcement and boss.announcement~=''then w.notifications[#w.notifications+1]={text=boss.announcement,t=6}end end
 if not e.aggro then return end
 for i,a in ipairs(boss.abilities or{})do state.timers[i]=(state.timers[i]or a.cooldown)-dt;if state.timers[i]<=0 then state.timers[i]=a.cooldown
  local actors=w.onlineActors or{{player=player,skills=skills,equipment=eq}};for _,target in ipairs(actors)do local p=target.player;if p.hp>0 and(p.x-e.x)^2+(p.y-e.y)^2<=a.radius^2 then local damage=require('game.combat').mitigate(a.damage,target.equipment,target.skills:get('Agility').level);if damage>0 then p.hp=math.max(0,p.hp-damage);p.damageSerial=(p.damageSerial or 0)+1;p.lastDamageSource=boss.name..': '..a.name;require('game.survival_foraging').damage(p,target.skills,damage,e.netId or e.kind);w:addPopup(p.x,p.y-14,damage,'damage')end end end
 end end
end
function R.dialogue(npc,quest)for _,r in ipairs(R.list('dialogues'))do if (r.npc and r.npc~=''and r.npc==npc.id)or(quest and r.quest==quest)then return r end end end
return R

