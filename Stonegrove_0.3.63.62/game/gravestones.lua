-- Shared corpse rules. Protected contents are never included in public snapshots.
local G={lifetime=60,brokenLifetime=10800,castTime=.5,reach=55}
local R=require('game.rune_inventory')
G.types={{level=10,name='Wooden Grave Marker',hp=20,intact=5,broken=4,animation=6},{level=30,name='Stone Tombstone',hp=50,intact=2,broken=3,animation=1},{level=60,name='Stone Statue',hp=200,intact=8,broken=7,animation=9}}
function G.type(level)local chosen;for _,v in ipairs(G.types)do if level>=v.level then chosen=v end end;return chosen end
function G.owner(a)return a.campOwner or(a.id and(tostring(a.id)..':'..a.slot))or'offline'end
function G.at(w,x,y)for _,v in ipairs(w.gravestones or{})do if(x-v.x)^2+(y-v.y)^2<=14^2 then return v end end end
function G.flatten(contents)
 local out={};for _,bag in pairs(contents.bags or{})do
  local obj=R.copy(bag);obj.qty=1;obj.slots=nil;obj.size=nil;out[#out+1]=obj
  for _,it in pairs(bag.slots or{})do out[#out+1]=R.copy(it)end
 end
 for slot,name in pairs(contents.equipment or{})do if name then local obj=R.copy((contents.equipmentItems or{})[slot])or(type(name)=='table'and R.copy(name)or{name=name,qty=1});if(contents.sockets or{})[slot]then obj.sockets=R.copy(contents.sockets[slot])end;out[#out+1]=obj end end
 for _,name in pairs(contents.potionBelt or{})do if name then out[#out+1]={name=name,qty=1}end end
 return out
end
function G.breakGrave(w,g)
 if g.broken then return false end;w.graveRevision=(w.graveRevision or 0)+1;g.broken=true;g.hp=0;g.remaining=0;g.brokenRemaining=G.brokenLifetime
 for i,obj in ipairs(G.flatten(g.contents or{}))do local angle=i*2.399963;local radius=10+math.sqrt(i)*3;w:addGroundItem(obj.name,g.x+math.cos(angle)*radius,g.y+math.sin(angle)*radius,false,obj);local drop=w.groundItems[#w.groundItems];if drop then drop.graveLoot=true;if require("game.bag_system").defs[require("game.bag_system").name(obj.name)]then drop.bagOwner=g.owner end end end
 g.contents=nil;return true
end
function G.die(w,a,cause)
 local p=a.player;w.gravestones=w.gravestones or{};w.graveSerial=(w.graveSerial or 0)+1;w.graveRevision=(w.graveRevision or 0)+1
 local contents={bags=R.copy(a.inv.bagSlots),equipment=R.copy(a.equipment or{}),equipmentItems=R.copy(a.equipmentItems or{}),sockets=R.copy(a.sockets or a.equipmentSockets or{}),potionBelt=R.copy(a.potionBelt or{})}
 local t=G.type(a.skills:get('Religion').level)
 local g={id=w.graveSerial,owner=G.owner(a),playerName=p.name or'Adventurer',cause=cause or p.lastDamageSource or'Unknown cause',name=t and t.name or'Unmarked remains',typeLevel=t and t.level or 0,x=p.x,y=p.y,hp=t and t.hp or 0,maxHp=t and t.hp or 0,remaining=G.lifetime,blessingLevel=0,contents=contents}
 w.gravestones[#w.gravestones+1]=g
 a.inv.bagSlots={};a.inv.activeBag=1;a.equipment={};a.equipmentItems={};a.sockets={};a.equipmentSockets={};a.potionBelt={};p.equipped=nil;p.equipment=a.equipment;require("game.tool_slot").bind(a)
 if not t then G.breakGrave(w,g);table.remove(w.gravestones)end
 return g
end
function G.near(a,g)return g and(g.x-a.player.x)^2+(g.y-a.player.y)^2<=G.reach^2 end
function G.bless(w,a,g)
 if not G.near(a,g)then return false,'Move nearer to the grave'end
 if g.broken or g.recovered then return false,'This grave is no longer intact'end
 local level=a.skills:get('Religion').level;if level<=(g.blessingLevel or 0)then return false,'A stronger Religion level is required'end
 w.graveRevision=(w.graveRevision or 0)+1;g.blessingLevel=level;g.blessedBy=a.player.name;g.remaining=g.remaining+level*60;g.blessAnimation=.8
 a.skills:addXP('Religion',math.min(25,5+level*.2));return true,'Blessing extended the grave by '..level..' minutes'
end
function G.recover(w,a,g)
 if not G.near(a,g)then return false,'Move nearer to the grave'end
 if g.broken or g.recovered then return false,'This grave is no longer intact'end
 if g.owner~=G.owner(a)then return false,'Only the deceased player can recover this grave'end
 -- Restore the original bag containers first; never require an empty player to own a bag.
 local trial=R.clone(a.inv);local c=g.contents;if not c then return false,'Connect to the server to recover these belongings'end;local currentBags=R.copy(trial.bagSlots);local extras={}
 trial.bagSlots=R.copy(c.bags or{});trial.activeBag=1;trial:applyStrengthBagBonus(a.skills:get('Strength').level)
 for _,bag in pairs(currentBags)do local free;for slot=1,trial:bagSlotCount()do if not trial.bagSlots[slot]then free=slot;break end end;if free then trial.bagSlots[free]=bag else for _,obj in ipairs(G.flatten({bags={bag}}))do extras[#extras+1]=obj end end end
 for _,obj in ipairs(extras)do if not trial:addItemObject(obj)then return false,'Make room for your current belongings first'end end
 local equipment=R.copy(a.equipment or{});local objects=R.copy(a.equipmentItems or{});local sockets=R.copy(a.sockets or a.equipmentSockets or{})
 for slot,name in pairs(c.equipment or{})do if equipment[slot]then local obj=objects[slot]or(type(equipment[slot])=='table'and equipment[slot]or{name=equipment[slot],qty=1});obj=R.copy(obj);if sockets[slot]then obj.sockets=R.copy(sockets[slot])end;if not trial:addItemObject(obj)then return false,'Make room for your current gear first'end end;equipment[slot]=R.copy(name);objects[slot]=R.copy((c.equipmentItems or{})[slot]);sockets[slot]=R.copy((c.sockets or{})[slot])end
 local belt=R.copy(a.potionBelt or{});for slot,name in pairs(c.potionBelt or{})do if belt[slot]and not trial:add(belt[slot],1)then return false,'Make room for your current belt first'end;belt[slot]=name end
 a.inv.bagSlots=trial.bagSlots;a.inv.activeBag=trial.activeBag;a.equipment=equipment;a.equipmentItems=objects;a.sockets=sockets;a.equipmentSockets=sockets;a.potionBelt=belt;a.player.equipped=equipment.weapon;a.player.equipment=equipment;require('game.quality').bind(equipment,objects);require('game.tool_slot').bind(a)
 w.graveRevision=(w.graveRevision or 0)+1;g.contents=nil;g.recovered=true;g.remaining=0;g.brokenRemaining=G.brokenLifetime;return true,'Belongings recovered'
end
function G.start(w,a,op,id)
 if a.graveCast then return false,'Already performing a grave action'end
 local target;for _,g in ipairs(w.gravestones or{})do if g.id==id then target=g end end
 if not G.near(a,target)then return false,'Move nearer to the grave'end
 if target.broken or target.recovered then return false,'This grave is no longer intact'end
 if op=='recover'and target.owner~=G.owner(a)then return false,'Only the deceased player can recover this grave'end
 if op=='bless'and a.skills:get('Religion').level<=target.blessingLevel then return false,'A stronger Religion level is required'end
 if op~='bless'and op~='recover'then return false,'Unknown grave action'end
 a.graveCast={id=id,op=op,timer=0,hp=a.player.hp,damageSerial=a.player.damageSerial or 0,x=a.player.x,y=a.player.y};return true,'started'
end
function G.tickCast(w,a,dt)
 local c=a.graveCast;if not c then return end;local target;for _,g in ipairs(w.gravestones or{})do if g.id==c.id then target=g end end
 if (a.player.damageSerial or 0)~=c.damageSerial or a.player.hp<c.hp or a.player.hp<=0 or not G.near(a,target)or(a.player.x-c.x)^2+(a.player.y-c.y)^2>4 then a.graveCast=nil;return false,'Grave action interrupted'end
 c.hp=a.player.hp;c.timer=c.timer+dt;if c.timer<G.castTime then return end;a.graveCast=nil
 return(c.op=='bless'and G.bless or G.recover)(w,a,target)
end
function G.update(w,dt)
 if w.onlineShared then return end
 for i=#(w.gravestones or{}),1,-1 do local g=w.gravestones[i];g.blessAnimation=math.max(0,(g.blessAnimation or 0)-dt)
  if g.broken or g.recovered then g.brokenRemaining=(g.brokenRemaining or G.brokenLifetime)-dt;if g.brokenRemaining<=0 then table.remove(w.gravestones,i)end
  else g.remaining=g.remaining-dt;if g.hp<=0 or g.remaining<=0 then G.breakGrave(w,g)end end
 end
end
function G.enemyAttacks(w,dt)
 for _,e in ipairs(w.enemies or{})do if not e.dead and not e.inactive and not e.aggro then
  e.graveAttackTimer=(e.graveAttackTimer or 0)-dt
  local intelligent=e.kind=='goblin'or e.kind=='nagalian';local radius=intelligent and 90 or 24;local nearest,dist
  for _,g in ipairs(w.gravestones or{})do local d=(g.x-e.x)^2+(g.y-e.y)^2;if not g.broken and not g.recovered and d<radius^2 and(not dist or d<dist)then nearest,dist=g,d end end
  if nearest then if dist>20^2 and intelligent then local len=math.sqrt(dist);e.x=e.x+(nearest.x-e.x)/len*math.min(28*dt,len-18);e.y=e.y+(nearest.y-e.y)/len*math.min(28*dt,len-18)
   elseif dist<=24^2 and e.graveAttackTimer<=0 then nearest.hp=math.max(0,nearest.hp-math.max(1,math.floor((e.level or 1)/6)));e.graveAttackTimer=intelligent and 2 or 8;if nearest.hp<=0 then G.breakGrave(w,nearest)end end
  end
 end end
end
return G
