local Save={}
local function serialize(v,seen)
 local t=type(v)
 if t=="number" or t=="boolean" then return tostring(v) end
 if t=="string" then return string.format("%q",v) end
 if t~="table" then return "nil" end
 seen=seen or {};if seen[v] then return "nil" end;seen[v]=true
 local out={"{"}
 for k,val in pairs(v) do
  local key=type(k)=="number" and ("["..k.."]") or ("["..string.format("%q",k).."]")
  out[#out+1]=key.."="..serialize(val,seen)..","
 end
 out[#out+1]="}";seen[v]=nil;return table.concat(out)
end
local function copyItems(src)
 local out=require('game.items').copy(src or {})
 local migrate={['Woodworking Knife']='Copper Dagger',Logs='Pine Logs',['Basic Wood Parts']='Pine Wood Parts',Staff='Pine Staff',['Arrow Shafts']='Pine Arrow Shafts',['Unstrung Bow']='Pine Unstrung Bow',Bow='Pine Bow'}
 for _,obj in pairs(out) do if type(obj)=='table' then obj.qty=obj.qty or 1;if obj.name then obj.name=migrate[obj.name] or obj.name;obj.name=obj.name:gsub('^Cooked Jerky ','Jerky ') end;if obj.sockets then require('game.sockets').normalize(obj) end end end
 return out
end
function Save.write(player,inv,skills,ui,logger)
 if ui.campPending and not ui.campPending.saving then return false,"camp_transaction" end
 local f=require('game.fieldcraft');local owner=require('game.profile').active;local _,camp=f.find(ui.world,{campOwner=owner and(tostring(owner.id)..':'..owner.slot)or'offline'})
 if not owner then ui.fieldcraft.activeStorage=camp and require('game.rune_inventory').copy(camp.storage)or nil end
 require("game.items").sync(ui);for _,m in ipairs(ui.world.mercs or {}) do require("game.items").sync(m) end
 local caveState;player,ui,caveState=require("game.caves").saveContext(player,ui)
 local bags={}
 for i=1,4 do local b=inv.bagSlots[i];if b then bags[i]={name=b.name,size=b.size,baseSize=b.baseSize,qualityGrade=b.qualityGrade,slots=copyItems(b.slots)} end end
 local hideStations=require('game.hide_processing').export(ui.world)
 local regionId,worldId,regions=require('game.regions').save(ui.world)
 local data={boneClaims=not owner and require("game.bone_religion").export()or nil,burialGraves=require("game.rune_inventory").copy(ui.world.burialGraves or{}),graveEpoch=ui.graveEpoch or 0,gravestones=require("game.rune_inventory").copy(ui.world.gravestones or{}),graveGround=require("game.rune_inventory").copy(ui.world.groundItems or{}),fieldcraft=ui.fieldcraft,fireState=require("game.fire_fuel").export(ui.world.overworld or ui.world),eventState=require("game.events").export(ui),hideStations=hideStations,regionId=regionId,worldId=worldId,regions=regions,quests=player.quests,caves=caveState,version=1,mapVersion=4,houseSeed=ui.world.houseSeed,player={bonfireBuffUntil=player.bonfireBuffUntil,bonfireLastSource=player.bonfireLastSource,name=player.name,race=player.race,x=player.x,y=player.y,hp=player.hp,stamina=player.stamina},
  bagSchemaVersion=inv.bagSchemaVersion,oreKnowledge=require("game.prospecting").save(ui.world),skills={},equipment={},bags=bags,activeBag=inv.activeBag,bank=copyItems(inv.bank),potionBelt={},
  equipmentItems=ui.equipmentItems,merchantItems=require("game.items").shopSnapshot(ui.world),equipmentSockets=ui.equipmentSockets,spellPages=ui.spellPages,abilityHotbar=ui.abilityHotbar,weaponHotbars=ui.weaponHotbars,mercs=ui.world.mercs,bankSize=inv.bankSize,bagnonMode=ui.bagnonMode,uiLayout={hudPos=ui.hudPos,bagPos=ui.bagPos,pos=ui.pos,panelScales=ui.panelScales,hudScale=ui.hudScale}}
 for n,v in pairs(skills.data) do data.skills[n]={xp=v.xp,level=v.level} end
 for k,v in pairs(ui.equipment) do data.equipment[k]=v end
 for i=1,4 do data.potionBelt[i]=ui.potionBelt[i] end
 local ok,msg=love.filesystem.write("character_save.lua","return "..serialize(data))
 if ok then require("game.profile").queue(data) end
 if logger then logger:log("CHARACTER_SAVED",{success=tostring(ok),message=tostring(msg or "")}) end
 return ok,msg
end
function Save.load(player,inv,skills,ui,logger)
 if not love.filesystem.getInfo("character_save.lua") then return false,"no_save" end
 local chunk,err=love.filesystem.load("character_save.lua");if not chunk then return false,err end
 local ok,d=pcall(chunk);if not ok or type(d)~="table" then return false,"bad_save" end
 ui.fieldcraft=type(d.fieldcraft)=="table" and d.fieldcraft or {layout={},built={},recovery={}};if ui.fieldcraft.activeStorage then ui.fieldcraft.recovery=ui.fieldcraft.recovery or{};for _,obj in pairs(ui.fieldcraft.activeStorage)do ui.fieldcraft.recovery[#ui.fieldcraft.recovery+1]=obj end;ui.fieldcraft.activeStorage=nil;ui.world.notifications[#ui.world.notifications+1]={text='Previous camp lost. Stored items are available in Fieldcraft recovery.',t=8}end;ui.fieldcraft.active=nil;ui.fieldcraft.activeTent=nil;ui.fieldcraft.pots={};local potOwner=require('game.profile').active;require('game.shellfish').cleanup(ui.world,potOwner and(tostring(potOwner.id)..':'..potOwner.slot)or'offline')
 player.eventState=type(d.eventState)=="table" and d.eventState or nil
 local migrateRegion=require('game.regions').restore(ui,d)
 if not migrateRegion and type(d.houseSeed)=="number" then ui.world.houseSeed=d.houseSeed;require("game.houses").generate(ui.world.houses,d.houseSeed) end
 if not require("game.profile").active then require("game.bone_religion").restore(d.boneClaims)end;ui.world.burialGraves=d.burialGraves or{}
 if not migrateRegion and d.caves then require('game.caves').restore(ui.world,d.caves) end
 if d.player then player.bonfireBuffUntil=d.player.bonfireBuffUntil;player.bonfireLastSource=d.player.bonfireLastSource;player.name=require("game.character_name").normalize(d.player.name) or "Adventurer";player.race=require("game.races").normalize(d.player.race);player.x=d.player.x or player.x;player.y=d.player.y or player.y;player.hp=d.player.hp or player.hp;player.stamina=d.player.stamina or player.stamina end
 ui.graveEpoch=d.graveEpoch or 0;if not require("game.profile").active then ui.world.gravestones=d.gravestones or{};ui.world.groundItems=d.graveGround or ui.world.groundItems end
 if not migrateRegion then require("game.prospecting").load(ui.world,d.oreKnowledge)end
 player.quests=type(d.quests)=="table" and d.quests or {}
 if migrateRegion and ui.world.regionId then local migrated={};for key,v in pairs(player.quests)do migrated[key:match('^quest%a+:') and (ui.world.regionId..':'..key) or key]=v end;player.quests=migrated end
 skills:setRace(player.race)
 if d.skills then skills:load(d.skills) end
 if d.bags then inv.bagSlots={nil,nil,nil};for i=1,4 do local b=d.bags[i];if b then inv.bagSlots[i]={name=b.name,size=b.size or 6,baseSize=b.baseSize,qualityGrade=b.qualityGrade,slots=copyItems(b.slots)} end end end
 inv.bagSchemaVersion=d.bagSchemaVersion;inv.activeBag=d.activeBag or 1;inv.bank=copyItems(d.bank);inv.bankSize=d.bankSize or inv.bankSize or 25
 if d.equipment then local migrateEq={["Woodworking Knife"]="Copper Dagger",Bow="Pine Bow",Staff="Pine Staff"};for k,v in pairs(d.equipment) do ui.equipment[k]=migrateEq[v] or v end;player.equipped=ui.equipment.weapon end;if d.equipmentSockets then ui.equipmentSockets=d.equipmentSockets end;ui.equipmentItems=copyItems(d.equipmentItems);local f=require('game.fieldcraft');local owner=require('game.profile').active;local _,camp=f.find(ui.world,{campOwner=owner and(tostring(owner.id)..':'..owner.slot)or'offline'})
 if not owner then ui.fieldcraft.activeStorage=camp and require('game.rune_inventory').copy(camp.storage)or nil end
 require("game.items").sync(ui);require("game.items").restoreShops(ui.world,d.merchantItems);require("game.hide_processing").restore(ui.world,d.hideStations)
 if d.uiLayout then ui.panelScales=d.uiLayout.panelScales or {} end
 if d.mercs then ui.world.mercs=d.mercs;for _,m in ipairs(ui.world.mercs) do if m.equipment and m.equipment.weapon=="Woodworking Knife" then m.equipment.weapon="Copper Dagger" end;if m.equipment and m.equipment.weapon=="Bow" then m.equipment.weapon="Pine Bow" end end end
 for _,m in ipairs(ui.world.mercs or {}) do require("game.items").sync(m) end
 if d.potionBelt then for i=1,4 do ui.potionBelt[i]=d.potionBelt[i] end end
 if d.spellPages then for i=1,6 do ui.spellPages[i]=d.spellPages[i] end end
 if d.weaponHotbars then ui.weaponHotbars=d.weaponHotbars elseif d.abilityHotbar then local weapon=ui.equipment.weapon;if weapon then ui.weaponHotbars=ui.weaponHotbars or {};ui.weaponHotbars[weapon]={};for i=1,4 do ui.weaponHotbars[weapon][i]=d.abilityHotbar[i] end end end
 if not d.equipmentItems then local obj=require('game.items').equipped(ui,'weapon');if obj then obj.hotbar=require('game.items').copy(ui.weaponHotbars[obj.name] or d.abilityHotbar or {}) end end
 inv:migrateBags(skills:get("Strength").level);ui.bagnonMode=d.bagnonMode==true
 player.spellCooldowns={}
 if d.uiLayout then
  if d.uiLayout.hudPos then ui.hudPos=d.uiLayout.hudPos end
  if d.uiLayout.bagPos then for i,p in pairs(d.uiLayout.bagPos)do ui.bagPos[i]=p end end
  if d.uiLayout.pos then for k,v in pairs(d.uiLayout.pos) do if ui.pos[k] and type(v)=="table" then ui.pos[k].x=v.x or ui.pos[k].x;ui.pos[k].y=v.y or ui.pos[k].y end end end
  if d.uiLayout.hudScale then ui.hudScale=d.uiLayout.hudScale end
 end
 if not d.mapVersion then
  player.x=player.x+496;player.y=player.y+368
  for _,m in ipairs(ui.world.mercs) do m.x=m.x+496;m.y=m.y+368 end
 end
 if (d.mapVersion or 1)<3 then
  -- Preserve the player's position relative to the nearest old town when moving into the larger world.
  local old={{1520,1136},{704,816},{1856,1696}}
  local new={{ui.world.map.width/2,ui.world.map.height/2},{900,980},{4210,3000}}
  local function migrate(x,y)
   local best=1;local bd=(x-old[1][1])^2+(y-old[1][2])^2
   for i=2,3 do local dd=(x-old[i][1])^2+(y-old[i][2])^2;if dd<bd then best=i;bd=dd end end
   return new[best][1]+(x-old[best][1]),new[best][2]+(y-old[best][2])
  end
  player.x,player.y=migrate(player.x,player.y)
  for _,m in ipairs(ui.world.mercs) do m.x,m.y=migrate(m.x,m.y) end
 end

 if (d.mapVersion or 1)==3 then
  -- 0.1.96/0.1.97 expanded-world builds placed two towns too close to the coastline.
  -- Preserve local position around each town while moving those settlements onto continuous land.
  local old={{ui.world.map.width/2,ui.world.map.height/2},{900,980},{4210,3000}}
  local new={{ui.world.map.width/2,ui.world.map.height/2},{1200,1200},{3750,2650}}
  local function migrateTown(x,y)
   local best=1;local bd=(x-old[1][1])^2+(y-old[1][2])^2
   for i=2,3 do local dd=(x-old[i][1])^2+(y-old[i][2])^2;if dd<bd then best=i;bd=dd end end
   return new[best][1]+(x-old[best][1]),new[best][2]+(y-old[best][2])
  end
  player.x,player.y=migrateTown(player.x,player.y)
  for _,m in ipairs(ui.world.mercs) do m.x,m.y=migrateTown(m.x,m.y) end
 end
 if not ui.world.map:isLand(player.x,player.y) then player.x=ui.world.map.width/2;player.y=ui.world.map.height/2+55 end
 inv:consolidateBars();local ironMoved=inv:migrateIronStacks()
 if ironMoved>0 then ui.world:addPopup(player.x,player.y-24,"Iron stacks split; overflow moved to bank") end
 player:syncVitals(skills);require('game.regions').finishLoad(ui,d,migrateRegion)
 if not migrateRegion then require('game.fire_fuel').restore(ui.world.overworld or ui.world,d.fireState)end
 require('game.villages').nearest(ui.world,player.x,player.y)
 if logger then logger:log("CHARACTER_LOADED",{version=d.version or 0}) end
 require('game.quality').bind(ui.equipment,ui.equipmentItems);require('game.tool_slot').bind(ui)
 return true
end
return Save
