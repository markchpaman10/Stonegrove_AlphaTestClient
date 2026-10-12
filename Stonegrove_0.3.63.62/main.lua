RenderCache=require("game.render_cache")
Caves=require("game.caves")
GoblinCamps=require("game.goblin_camps")
Regions=require("game.regions")
Quests=require("game.quests")
WorldMap=require("game.world_map")
Pause=require("game.pause_menu")
local Options=require("game.options_menu")
Animation=require("game.animation")
Expansion=require("game.expansion")
CharacterSelect=require("game.character_select")
local Events=require("game.events")
local ClickActions=require('game.click_actions')
local interactWorld
local selectingCharacter=true
local selectedRace="Human"
local titleActive=true;local titleHasSave=false;local titlePanX=0;local titlePanY=0;local titlePanDX=1;local titlePanDY=1
Weather=require("game.weather");DayNight=require("game.daynight");Save=require("game.save");Crafting=require("game.crafting");Camera=require("game.camera");Sprites=require("game.sprites");Player=require("game.player");Inventory=require("game.inventory");World=require("game.world");UI=require("game.ui");Logger=require("game.logger");Skills=require("game.skills");Shop=require("game.shop")
camera,sprites,player,inventory,world,ui,logger,skills,shop,crafting,weather,dayNight,lightShader=nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil
local lastMove="idle";local moveLogTimer=0;local autosaveTimer=0;local lastWindowW,lastWindowH
local minimap={x=nil,y=12,w=184,h=184,zoom=3,dragging=false,dragOffX=0,dragOffY=0}
local targetUI={x=nil,y=12,dragging=false,dragOffX=0,dragOffY=0}
local function minimapRect(w,h)
 if not minimap.x then minimap.x=w-minimap.w-48 end
 minimap.x=math.max(4,math.min(w-minimap.w-4,minimap.x));minimap.y=math.max(4,math.min(h-minimap.h-4,minimap.y))
 return minimap.x,minimap.y,minimap.w,minimap.h
end
local function pointInMinimap(px,py,w,h) local x,y,mw,mh=minimapRect(w,h);local cx,cy=x+mw/2,y+mh/2;local r=math.min(mw,mh)/2;return (px-cx)^2+(py-cy)^2<=r*r end
local function pointInRect(px,py,x,y,w,h) return px>=x and px<=x+w and py>=y and py<=y+h end
local function log(event,data) if logger then logger:log(event,data) else require("game.audio").event(event,data) end end
local function loadRacePreference()
 if not love.filesystem.getInfo("race_preference.lua") then return nil end
 local chunk=love.filesystem.load("race_preference.lua");if not chunk then return nil end
 local ok,d=pcall(chunk);if not ok then return nil end
 if require("game.races").valid(d) then return d end
 return nil
end
local function saveRacePreference(race)
 if not require("game.races").valid(race) then return false end
 return love.filesystem.write("race_preference.lua","return "..string.format("%q",race))
end
local function confirmCharacter()
 local name=CharacterSelect.getName();if not name then return false end
 player.name=name;player.race=selectedRace;skills:setRace(player.race);player:syncVitals(skills);player.hp=player.maxHp;player.stamina=player.maxStamina
 saveRacePreference(player.race);selectingCharacter=false;require("game.launcher").confirmed=true;love.keyboard.setTextInput(false)
 Save.write(player,inventory,skills,ui,logger);return true
end
function love.textinput(text)
 if selectingCharacter and not titleActive then CharacterSelect.textinput(text) end
end
local function grassGrid() world.map:draw();Regions.drawNeighbors(world) end
local function loadDisplaySettings()
 if not love.filesystem.getInfo("display_save.lua") then return end
 local chunk=love.filesystem.load("display_save.lua");if not chunk then return end;local ok,d=pcall(chunk);if not ok or type(d)~="table" then return end
 if d.width and d.height then pcall(love.window.setMode,d.width,d.height,{resizable=true,minwidth=800,minheight=500,fullscreen=d.fullscreen or false}) end
 if d.maximized and not d.fullscreen and love.window.maximize then pcall(love.window.maximize) end
 if d.minimap then minimap.x=d.minimap.x;minimap.y=d.minimap.y;minimap.zoom=math.max(.55,math.min(8,tonumber(d.minimap.zoom)or 3))end
 if d.targetUI then targetUI.x=d.targetUI.x;targetUI.y=d.targetUI.y end
end
local function saveDisplaySettings()
 local w,h=love.graphics.getDimensions();local fs=love.window.getFullscreen();local maxed=love.window.isMaximized and love.window.isMaximized() or false
 local x=minimap.x and math.floor(minimap.x) or nil;local y=minimap.y and math.floor(minimap.y) or nil
 local tx=targetUI.x and math.floor(targetUI.x) or nil;local ty=targetUI.y and math.floor(targetUI.y) or nil
 local data=string.format("return {width=%d,height=%d,fullscreen=%s,maximized=%s,minimap={x=%s,y=%s,zoom=%g},targetUI={x=%s,y=%s}}",w,h,tostring(fs),tostring(maxed),tostring(x or "nil"),tostring(y or "nil"),minimap.zoom,tostring(tx or "nil"),tostring(ty or "nil"));love.filesystem.write("display_save.lua",data)
end
local loadingSayings={
 'Chasing the cows',
 'Scouting for goblins',
 'Counting suspicious mushrooms',
 'Sharpening copper daggers',
 'Convincing sheep to cooperate',
 'Checking the chicken population',
 'Polishing questionable armor',
 'Refilling the village well',
 'Waking the blacksmith',
 'Hiding snacks from goblins',
 'Untangling fishing line',
 'Sweeping the dungeon entrance',
 'Teaching rats about boundaries',
 'Rebuilding the same fence',
 'Looking for the missing healer',
 'Asking wolves to wait outside',
 'Stacking logs irresponsibly',
 'Testing the tanning vat',
 'Lighting campfires safely-ish',
 'Counting every pine tree',
 'Arguing with the bank clerk',
 'Feeding the mercenaries',
 'Checking goblin cages',
 'Herding livestock away from roads',
 'Dusting off the anvil',
 'Sorting copper chunks',
 'Checking the weather rock',
 'Waiting for the rain to behave',
 'Removing slimes from boots',
 'Restocking suspicious potions',
 'Finding the rune bag',
 'Carving tiny feathers',
 'Inspecting fish bones',
 'Collecting stone gravel',
 'Looking directly at the onyx',
 'Bottling green slime',
 'Winding bow strings',
 'Counting arrows twice',
 'Checking quivers for holes',
 'Polishing the smelter',
 'Cooling hot metal badly',
 'Negotiating with boars',
 'Asking rats who sent them',
 'Mapping the wilderness',
 'Finding north again',
 'Repairing the minimap',
 'Pretending the roads are straight',
 'Planting mushrooms where nobody asked',
 'Moving sheep back into town',
 'Checking the town gates',
 'Testing every torch',
 'Blaming the goblins',
 'Checking boss bedtime',
 'Waiting for wolves to wake up',
 'Sending rats to day shift',
 'Sending wolves to night shift',
 'Checking the cave snakes',
 'Counting mercenary fingers',
 'Looking for loose coins',
 'Restocking the general trader',
 'Overpricing absolutely nothing',
 'Underpaying adventurers consistently',
 'Folding linen bags',
 'Spinning wool dramatically',
 'Spinning flax less dramatically',
 'Drying leather',
 'Stretching hides',
 'Checking the alchemy table',
 'Labeling mystery tubes',
 'Not drinking the green one',
 'Cooking the chicken this time',
 'Burning the chicken anyway',
 'Fishing for something edible',
 'Throwing burnt fish away',
 'Checking tree stumps',
 'Waiting for oak trees',
 'Prospecting shiny rocks',
 'Ignoring obvious danger',
 'Checking collision boxes',
 'Moving invisible walls',
 'Releasing absolutely no caged boars',
 'Locking the goblin cages properly',
 'Counting goblins before they multiply',
 'Checking quest paperwork',
 'Stamping hunting contracts',
 'Misplacing gathering requests',
 'Drawing arrows toward danger',
 'Polishing quest icons',
 'Making completed quests shinier',
 'Putting borders on boxes',
 'Dragging boxes around',
 'Checking cooldown hourglasses',
 'Waking idle NPCs',
 'Sending shopkeepers to work',
 'Checking village fences again',
 'Asking cows to face forward',
 'Teaching boars basic combat etiquette',
 'Turning rats toward the problem',
 'Pointing wolves at adventurers',
 'Packing the world grid',
}
local loadingSayingIndex=love.math.random(#loadingSayings)
local function startupScreen(status)
 local w,h=love.graphics.getDimensions()
 love.graphics.origin()
 love.graphics.clear(0.055,0.065,0.075,1)
 love.graphics.setColor(0.86,0.88,0.82,1)
 local title="STONEGROVE"
 local tw=love.graphics.getFont():getWidth(title)
 love.graphics.print(title,math.floor((w-tw)/2),math.floor(h*.43))
 love.graphics.setColor(0.62,0.66,0.62,1)
 local saying=loadingSayings[loadingSayingIndex];loadingSayingIndex=loadingSayingIndex%#loadingSayings+1
 local msg=(status or "Loading...").."  "..saying.."..."
 local mw=love.graphics.getFont():getWidth(msg)
 love.graphics.print(msg,math.floor((w-mw)/2),math.floor(h*.43)+30)
 love.graphics.setColor(1,1,1,1)
 love.graphics.present()
 love.event.pump()
end
function love.enterSelectedCharacter()
 titleActive=false;camera:reset(player.x,player.y)
end
function love.load()
 ClickActions.cancel();titleActive=true
 startupScreen("Loading Stonegrove...")
 loadDisplaySettings()
 startupScreen("Loading world...")
 love.graphics.setDefaultFilter("nearest","nearest");lightShader=love.graphics.newShader([[
extern vec2 lightCenter;
extern float lightRadius;
extern float lightStrength;
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc){
 float d=distance(sc,lightCenter)/max(lightRadius,1.0);
 float fall=1.0-smoothstep(0.0,1.0,d);
 fall=fall*fall*(3.0-2.0*fall);
 return vec4(1.0,0.58,0.18,fall*lightStrength);
}
]]);logger=Logger.new("gameplay_log.txt");startupScreen("Loading artwork...");sprites=Sprites.load();require("game.audio").init();player=Player.new();inventory=Inventory.new();skills=Skills.new();startupScreen("Building world...");Regions.boot();world=Regions.initial(sprites);player.x,player.y=world.map.width/2,world.map.height/2+55;shop=Shop.new(logger);crafting=Crafting.new();startupScreen("Preparing interface...");ui=UI.new(inventory,logger,skills,sprites,player,world,shop,crafting);local loaded=Save.load(player,inventory,skills,ui,logger);Events.init(ui);world=ui.world;if not loaded and world.map.authored and world.map.authored.playerStart then player.x=world.map.authored.playerStart.x;player.y=world.map.authored.playerStart.y end;titleHasSave=loaded and true or false;local preferredRace=loadRacePreference();if loaded then selectedRace=player.race;selectingCharacter=false;saveRacePreference(player.race) else selectedRace=preferredRace or "Human";selectingCharacter=true;CharacterSelect.reset() end;camera=Camera.new();weather=Weather.new(world.map);dayNight=DayNight.new();titleTour=require('game.title_tour').new(world);titlePanX=titleTour.x;titlePanY=titleTour.y;camera:reset(titlePanX,titlePanY);lastWindowW,lastWindowH=love.graphics.getDimensions();log("GAME_LOADED",{version=Logger.VERSION,x=math.floor(player.x),y=math.floor(player.y),race=player.race,characterSelect=tostring(selectingCharacter)})
end
function love.update(dt)
 if world and player and not titleActive and not selectingCharacter then
  if not require("game.multiplayer").active then require("game.fire_fuel").tickWorlds(world,player,logger)end
  local base=require("game.races").maxHealth(player.race,skills:get("Health").level)
  base=require("game.religion").maxHealth(skills,base);player.maxHp=require("game.bonfire_buff").active(player) and math.max(base+1,math.floor(base*1.2+.5))or base;require("game.religion").updateAnimation(player,dt)
  player.hp=math.min(player.hp,player.maxHp)
 end
 require("game.audio").update(math.min(dt,.05),player)
 if require('game.multiplayer').actionBusy or (require('game.multiplayer').active and not require('game.multiplayer').ready)then return end
 if Pause.open or Options.open or require('game.custom_dialogue').open then return end
 if titleActive then
  ClickActions.cancel();dt=math.min(dt,.05);if weather then weather:update(dt) end;if dayNight then dayNight:update(dt);world.contentDayTime=dayNight.time;world:setNightState(dayNight:isNight(),logger) end
  local w,h=love.graphics.getDimensions();local tour=require('game.title_tour')
  if not titleTour or titleTour.world~=world then titleTour=tour.new(world)end
  titlePanX,titlePanY=tour.update(titleTour,dt,w,h,camera.zoom)
  camera.x=titlePanX;camera.y=titlePanY;return
 end
 if selectingCharacter then return end
 local previousWorld=world;local blocked=Events.update(ui,math.min(dt,.05),camera);world=ui.world;if world~=previousWorld then weather=Weather.new(world.map)end;if blocked then return end
 dt=math.min(dt,.05);if dayNight then dayNight:update(dt);world.contentDayTime=dayNight.time;world:setNightState(dayNight:isNight(),logger) end;if weather then weather:update(dt);world._weatherNodeClock=(world._weatherNodeClock or 0)+dt;if world._weatherNodeClock>=1 then world._weatherNodeClock=0;local wr=1100*1100;for _,n in ipairs(world.nodes or {}) do local dx,dy=n.x-player.x,n.y-player.y;if (n.kind=="tree" or n.kind=="oak" or n.kind=="poplar") and dx*dx+dy*dy<=wr then local _,sn=weather:at(n.x,n.y);require('game.weather').updateCover(n,sn,1) end end end end;local w,h=love.graphics.getDimensions();local mx,my=love.mouse.getPosition();
 local agility=skills:get("Agility").level;player:syncVitals(skills)
 local wantsSprint=(love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift"))
 local movingKeys=love.keyboard.isDown("w") or love.keyboard.isDown("a") or love.keyboard.isDown("s") or love.keyboard.isDown("d")
 player.sprinting=not require('game.admin_menu').open and wantsSprint and (movingKeys or ClickActions.pending~=nil) and player.stamina>0
 if not player.sprinting then player.stamina=math.min(player.maxStamina,player.stamina+(player.secondWind and player.secondWind>0 and 5 or 2)*dt) end
 autosaveTimer=autosaveTimer+dt;if autosaveTimer>=15 then Save.write(player,inventory,skills,ui,logger);autosaveTimer=0 end
local wx,wy=camera:toWorld(mx,my,w,h);local dx=(love.keyboard.isDown("d") and 1 or 0)-(love.keyboard.isDown("a") and 1 or 0);local dy=(love.keyboard.isDown("s") and 1 or 0)-(love.keyboard.isDown("w") and 1 or 0);if require('game.admin_menu').open or WorldMap.open or(ui and ui.craftAmountPrompt)then ClickActions.cancel();dx,dy=0,0 end;dx,dy=ClickActions.direction(ui,dt,dx,dy);local move=(dx==0 and dy==0) and "idle" or (dx..","..dy)
 if move~=lastMove then log("MOVEMENT_STATE",{from=lastMove,to=move,x=string.format("%.1f",player.x),y=string.format("%.1f",player.y)});lastMove=move;moveLogTimer=0;if move~="idle" then if world.gather then world:stopGather("player_moved",logger) end;if world.combatTarget then world:stopCombat("player_moved",logger) end end end
 local lookX,lookY=wx,wy;if ClickActions.pending then lookX,lookY=ClickActions.pending.x,ClickActions.pending.y end
 if world.fishing and world.fishing.castX then lookX,lookY=world.fishing.castX,world.fishing.castY elseif world.gather and world.gather.node then lookX,lookY=world.gather.node.x,world.gather.node.y elseif world.combatTarget and not world.combatTarget.dead then lookX,lookY=world.combatTarget.x,world.combatTarget.y end
 local oldX,oldY=player.x,player.y;player:update(dt,dx,dy,lookX,lookY);if Regions.cross(ui,dx,dy,oldX,oldY)then world=ui.world;weather=Weather.new(world.map);camera:reset(player.x,player.y);oldX,oldY=player.x,player.y end;world:resolvePlayerMovement(player,oldX,oldY);local moved=math.sqrt((player.x-oldX)^2+(player.y-oldY)^2);if player.sprinting and moved>0 then player:spendStamina(math.min(player.stamina,math.max(6,14-agility*.08)*moved/(player.speed*1.65)),skills,logger,"sprint") end;require("game.audio").movement(player,oldX,oldY,world);require("game.audio").environment(dt,player,world,weather);world:update(dt,player,inventory,skills,logger);Quests.update(ui,dt);world:updateCombat(dt,player,skills,ui.equipment,sprites,logger,ui.equipmentSockets,inventory);ui:updateMagic(dt);if world.caveExitRequested then world.caveExitRequested=nil;world=Caves.leave(ui);camera:reset(player.x,player.y) end;inventory:applyStrengthBagBonus(skills:get("Strength").level);shop:update(false);local bdx,bdy=world.bankChest.x-player.x,world.bankChest.y-player.y;if ui.open.bank and not (ui.campBank and require("game.fieldcraft_ui").nearStation(ui,"bank"))and bdx*bdx+bdy*bdy>75*75 then ui:close("bank","too_far");log("BANK_AUTO_CLOSED",{reason="too_far"}) end;local rdx,rdy=world.mercRecruiter.x-player.x,world.mercRecruiter.y-player.y;if ui.open.mercenary and rdx*rdx+rdy*rdy>75*75 then ui:close("mercenary","too_far") end;local kdx,kdy=world.bankClerk.x-player.x,world.bankClerk.y-player.y;if ui.open.bankClerk and kdx*kdx+kdy*kdy>75*75 then ui:close("bankClerk","too_far") end;if ui.open.shop then local near=false;for _,group in ipairs({world.tradeKeepers,world.traders or {}}) do for _,n in ipairs(group) do local dx3,dy3=n.x-player.x,n.y-player.y;if dx3*dx3+dy3*dy3<=75*75 and ui.shop==n.shop then near=true;break end end;if near then break end end;if not near then ui:close("shop","too_far");log("SHOP_AUTO_CLOSED",{reason="too_far"}) end end;for _,station in ipairs({"smelter","anvil","spinningWheel","alchemy","stove","socketTable","enchantAltar"}) do local st=world[station];local dx2,dy2=st.x-player.x,st.y-player.y;if ui.open[station] and not require("game.fieldcraft_ui").nearStation(ui,station)and dx2*dx2+dy2*dy2>75*75 then ui:close(station,"too_far");log("CRAFTING_AUTO_CLOSED",{station=station,reason="too_far"}) end end;if ui.open.campfire and not world:campfireNear(player) then ui:close("campfire","expired_or_too_far") end
 Animation.update(world,player,dt)
 if Events.camera then camera.x,camera.y=Events.camera.x,Events.camera.y elseif world.gather or world.combatTarget or ui:pointerOverUI(mx,my,w,h) then camera:update(dt,player.x,player.y,w/2,h/2,w,h) else camera:update(dt,player.x,player.y,mx,my,w,h) end
end
interactWorld=function(wx,wy)
 local w,h=love.graphics.getDimensions();local x,y=camera:toScreen(wx,wy,w,h);if require('game.player_target').click(ui,wx,wy)then return end;require('game.player_target').clear();if require('game.fieldcraft_ui').worldClick(ui,camera,x,y,1)then return end;if ui.craftJob and ui.craftJob.prospecting then ui.craftJob=nil end; if ui.useTarget then log("ITEM_USE_CANCELLED",{reason="invalid_world_target",tool=ui.useTarget.tool});ui.useTarget=nil end;if Events.interact(ui,wx,wy,'story')then return end;if Quests.click(ui,wx,wy) then return end;if Events.interact(ui,wx,wy,'regular')then return end;for _,npc in ipairs(world.customNPCs or{})do if (npc.x-wx)^2+(npc.y-wy)^2<18^2 and (npc.x-player.x)^2+(npc.y-player.y)^2<=55^2 then require('game.custom_dialogue').show(npc);return end end;for _,cn in ipairs(world.customNPCs or {})do local dx,dy=wx-cn.x,wy-cn.y;if dx*dx+dy*dy<18^2 then local pdx,pdy=player.x-cn.x,player.y-cn.y;if pdx*pdx+pdy*pdy<=55^2 then world:addPopup(cn.x,cn.y-28,(cn.name or'NPC')..': '..(cn.dialogue or''),'defeat') else world:addPopup(player.x,player.y-24,'TOO FAR','miss') end;return end end;if GoblinCamps.click(world,player,wx,wy) then return end;if Caves.click(ui,wx,wy) then world=ui.world;weather=Weather.new(world.map);camera:reset(player.x,player.y);return end;local station,stationObj=world:stationAt(wx,wy);if station then local st=station=="campfire" and stationObj or world[station];local dx,dy=st.x-player.x,st.y-player.y;if dx*dx+dy*dy<=55*55 then if station=="religionAltar" then require('game.religion').blessInventory(ui,true);log('RELIGION_ALTAR_PRAYER',{}) elseif station=="magicAltar" then ui.open.spellbook=true;ui:bringToFront("spellbook");ui.context=nil;log("MAGIC_ALTAR_INTERACTED",{spellbook="open"}) elseif station=="socketTable" then ui:openSocketTable("socket_table");log("SOCKET_TABLE_INTERACTED",{}) elseif station=="enchantAltar" then ui:openEnchantAltar("enchant_altar");log("ENCHANT_ALTAR_INTERACTED",{}) elseif station=="inscription" then ui:openCrafting("inscription","inscription_table");log("INSCRIPTION_TABLE_INTERACTED",{}) elseif station=="tailoring" then ui:openCrafting("tailoring","tailor_table");log("TAILOR_TABLE_INTERACTED",{}) elseif station=="tanningVat" then local ok,res=world:useTanningVat(inventory,skills,logger);log("TANNING_VAT_INTERACTED",{success=tostring(ok),result=tostring(res)}) elseif station=="hideStretcher" then local ok,res=world:useHideStretcher(inventory,skills,logger);log("HIDE_STRETCHER_INTERACTED",{success=tostring(ok),result=tostring(res)});if not ok then world:addPopup(player.x,player.y-24,res=="stretcher_busy" and "HIDE IS DRYING" or res=="no_soaked_hide" and "NEED ONE SOAKED HIDE" or res=="bags_full" and "FULL INVENTORY" or tostring(res),"miss") elseif res=="started" then world:addPopup(player.x,player.y-24,"DRYING ONE HIDE","defeat") elseif res=="collected" then world:addPopup(player.x,player.y-24,"LEATHER COLLECTED","defeat") end else ui:openCrafting(station,"world_station");log("CRAFTING_STATION_INTERACTED",{station=station}) end else log("STATION_TOO_FAR",{station=station}) end;return end;if require('game.bag_keeper').click(ui,wx,wy)then return end;if world:mercRecruiterAt(wx,wy) then local dx,dy=world.mercRecruiter.x-player.x,world.mercRecruiter.y-player.y;if dx*dx+dy*dy<=55*55 then ui:openMercenary("merc_recruiter") else log("MERC_RECRUITER_TOO_FAR",{}) end;return end;if world:bankClerkAt(wx,wy) then local dx,dy=world.bankClerk.x-player.x,world.bankClerk.y-player.y;if dx*dx+dy*dy<=55*55 then ui.open.bankClerk=true;ui:bringToFront("bankClerk");log("BANK_CLERK_OPENED",{money=inventory:moneyCopper(),slots=inventory.bankSize or 25}) else log("BANK_CLERK_TOO_FAR",{}) end;return end;local keeper=world:tradeKeeperAt(wx,wy);if keeper then local dx,dy=keeper.x-player.x,keeper.y-player.y;if dx*dx+dy*dy<=55*55 then ui:openShop(keeper.trade,keeper.shop);log("TRADE_SHOPKEEPER_INTERACTED",{trade=keeper.trade,race=keeper.race}) else log("SHOPKEEPER_TOO_FAR",{trade=keeper.trade}) end;return end;local healer=world:healerAt(wx,wy);if healer then local dx,dy=healer.x-player.x,healer.y-player.y;if dx*dx+dy*dy<=55*55 then local ok,res=world:useHealer(player,inventory,logger);log("HEALER_INTERACTED",{success=tostring(ok),result=tostring(res),race=healer.race}) else log("HEALER_TOO_FAR",{}) end;return end;if world:bankChestAt(wx,wy) then local dx,dy=world.bankChest.x-player.x,world.bankChest.y-player.y;if dx*dx+dy*dy<=55*55 then ui:openBank("bank_chest");log("BANK_CHEST_INTERACTED",{x=math.floor(world.bankChest.x),y=math.floor(world.bankChest.y)});else log("BANK_CHEST_TOO_FAR",{}) end;return end;local ground,groundIndex=world:groundItemAt(wx,wy);if ground then if require('game.multiplayer').pickupClick(world,player,camera,x,y,1,w,h)then return end; local pickupName=(ground.name=="Lit Torch") and "Torch" or ground.name;if (ground.object and inventory:addItemObject(ground.object)) or (not ground.object and inventory:add(pickupName,1)) then world:takeGroundItem(groundIndex);log("GROUND_ITEM_PICKED_UP",{item=pickupName,extinguished=tostring(ground.name=="Lit Torch")}) else world:addPopup(player.x,player.y-24,"FULL INVENTORY","miss");log("GROUND_ITEM_PICKUP_BLOCKED",{item=ground.name,reason="bag_full"}) end;return end;local sheep=world:sheepAt(wx,wy);if sheep then local ok,res=world:shearSheep(sheep,player,inventory,ui.equipment,logger);if not ok and res=="bag_full" then world:addPopup(player.x,player.y-24,"FULL INVENTORY","miss") elseif not ok and res=="requires_shears" then world:addPopup(player.x,player.y-24,"NEED SHEARS IN INVENTORY","miss") end;log("SHEEP_INTERACTED",{success=tostring(ok),result=tostring(res)});return end;local enemy=world:enemyAt(wx,wy);if enemy and not enemy.dead and not enemy.inactive then local ok,result=world:startCombat(enemy,player,logger,ui.equipment.offhand=='Spellbook'and 210 or nil);log(ok and "COMBAT_STARTED" or "COMBAT_START_BLOCKED",{target=enemy.kind,result=result or "unknown",weapon=player.equipped or "unarmed"});return end;local node=world:nodeAt(wx,wy);if node then local ok,reason=world:startGather(node,player,skills,inventory,logger);if not ok then if reason=="bag_full" then world:addPopup(player.x,player.y-24,"FULL INVENTORY","miss") end;log("GATHER_BLOCKED",{resource=node.kind,reason=reason}) end;return end;local carcass=world:animalCarcassAt(wx,wy);if carcass then local ok,result=world:skinAnimal(carcass,player,skills,inventory,logger);if not ok and result=="bag_full" then world:addPopup(player.x,player.y-24,"FULL INVENTORY","miss") end;log("SKINNING_ATTEMPT",{enemy=carcass.kind,success=tostring(ok),result=tostring(result)});return end;local tx,ty=math.floor(wx/16)+1,math.floor(wy/16)+1;if world.map:isBeachCell(tx,ty) or world.map:isBeachWaterCell(tx,ty) then local ok,res=world:fishAt(wx,wy,player,skills,inventory,logger);if not ok and res=="bag_full" then world:addPopup(player.x,player.y-24,"FULL INVENTORY","miss") end;log("FISHING_ATTEMPT",{success=tostring(ok),result=tostring(res)});return end;local swing=player:attack(wx,wy);world:addSwing(swing);log(swing and "ATTACK" or "ATTACK_BLOCKED",{weapon=player.equipped,targetX=string.format("%.1f",wx),targetY=string.format("%.1f",wy)})
end
function love.mousepressed(x,y,b,istouch,presses)
 if Options.click(x,y,b) then return end
 if Pause.click(x,y,b,ui) then return end
 if require("game.multiplayer").actionBusy or (require("game.multiplayer").active and not require("game.multiplayer").ready)then return end
 if not titleActive and not selectingCharacter and Events.click(x,y,b)then return end
 if require('game.custom_dialogue').click(x,y,b) then return end
 if titleActive then
  if b~=1 then return end;local w,h=love.graphics.getDimensions();local bx=32;local gap=10;local bw=240;local bh=42;local bottom=h-34
   local exitY=bottom-bh;local optionsY=exitY-gap-bh;local continueY=optionsY-gap-bh;local newY=continueY-gap-bh
   if x>=bx and x<=bx+bw and y>=newY and y<=newY+bh then if world.isCave then world=Caves.leave(ui) end;world=Regions.newGame(sprites);world.caveEntrances=nil;world.caveInstances=nil;player=Player.new();inventory=Inventory.new();skills=Skills.new();selectedRace="Human";selectingCharacter=true;CharacterSelect.reset();ui=UI.new(inventory,logger,skills,sprites,player,world,shop,crafting);player.x,player.y=world.map.width/2,world.map.height/2+55;if world.map.authored and world.map.authored.playerStart then player.x,player.y=world.map.authored.playerStart.x,world.map.authored.playerStart.y end;titleActive=false;camera:reset(player.x,player.y);Events.init(ui)
   elseif x>=bx and x<=bx+bw and y>=continueY and y<=continueY+bh and titleHasSave then titleActive=false;selectingCharacter=false;camera:reset(player.x,player.y)
   elseif x>=bx and x<=bx+bw and y>=optionsY and y<=optionsY+bh then Options.show()
   elseif x>=bx and x<=bx+bw and y>=exitY and y<=exitY+bh then love.event.quit() end
  return
 end
 if selectingCharacter then
  local w,h=love.graphics.getDimensions();local choice=CharacterSelect.click(x,y,b,w,h)
  if choice=="confirm" then confirmCharacter()
  elseif choice then selectedRace=choice end
  return
 end
 local sw,sh=love.graphics.getDimensions();local mmx,mmy,mmw,mmh=minimapRect(sw,sh)
 if WorldMap.open then WorldMap.mousepressed(x,y,b);return end
 if b==1 then for i=1,2 do if pointInRect(x,y,mmx+6+(i-1)*24,mmy+mmh-25,22,20)then minimap.zoom=math.max(.55,math.min(8,minimap.zoom*1.2^(i==1 and -1 or 1)));return end end end
 if b==1 then local zx=mmx+mmw+8;local zy=mmy+8;if pointInRect(x,y,zx,zy,28,28) then camera:adjustZoom(1);return elseif pointInRect(x,y,zx,zy+34,28,28) then camera:adjustZoom(-1);return end end
 if require('game.presence').hover(x,y,'mini')then return end
 if b==1 and pointInMinimap(x,y,sw,sh) and not (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then WorldMap.openMap(sw,sh);return end
 local target=world.targetedEnemy or world.combatTarget
 if b==1 and target and Animation.enemyCombat(world,target) and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then local name=target.customName or (target.kind=="caveSnake" and "Cave Snake Boss") or target.kind:sub(1,1):upper()..target.kind:sub(2);local text=name.."  Lv "..target.level.."  Tier "..target.tier.."  |  "..world:enemyMainText(target);local pw=math.max(260,love.graphics.getFont():getWidth(text)+28);local px=targetUI.x or ((sw-pw)/2);local py=targetUI.y or 12;if pointInRect(x,y,px,py,pw,42) then targetUI.x=px;targetUI.y=py;targetUI.dragging=true;targetUI.dragOffX=x-px;targetUI.dragOffY=y-py;log("TARGET_UI_DRAG_STARTED",{x=math.floor(px),y=math.floor(py)});return end end
 if b==1 and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) and pointInRect(x,y,mmx-4,mmy-4,mmw+8,mmh+8) then minimap.dragging=true;minimap.dragOffX=x-mmx;minimap.dragOffY=y-mmy;log("MINIMAP_DRAG_STARTED",{x=math.floor(mmx),y=math.floor(mmy)});return end
 log("MOUSE_PRESSED",{button=b,x=x,y=y,presses=presses or 1});local w,h=love.graphics.getDimensions();if Quests.mousepressed(x,y,b) then return end;if Quests.panelClick(ui,x,y,b) then return end;if ui:mousepressed(x,y,b,w,h) then return end;if require("game.fieldcraft_ui").worldClick(ui,camera,x,y,b) then return end;if b==1 and require('game.multiplayer').pickupClick(world,player,camera,x,y,presses or 1,w,h)then return end;if b==1 and (presses or 1)>=2 then local picked=0;for i=#world.groundItems,1,-1 do local g=world.groundItems[i];local dx,dy=g.x-player.x,g.y-player.y;if dx*dx+dy*dy<=80*80 then local pickupName=(g.name=="Lit Torch") and "Torch" or g.name;local ok=(g.object and inventory:addItemObject(g.object)) or (not g.object and inventory:add(pickupName,1));if ok then world:takeGroundItem(i);picked=picked+1 else world:addPopup(player.x,player.y-24,"FULL INVENTORY","miss");break end end end;if picked>0 then log("GROUND_ITEMS_AREA_PICKUP",{count=picked});return end end;if b==2 then local wx,wy=camera:toWorld(x,y,w,h);ClickActions.start(ui,wx,wy,interactWorld);return end;if b==1 then ClickActions.cancel();local wx,wy=camera:toWorld(x,y,w,h);interactWorld(wx,wy)end
end
function love.mousereleased(x,y,b)
 if require("game.multiplayer").actionBusy or (require("game.multiplayer").active and not require("game.multiplayer").ready)then return end
 if require('game.custom_dialogue').open then return end
 if Options.release(x,y,b) then return end
 if Pause.open then return end
 if WorldMap.open then WorldMap.mousereleased(x,y,b);return end
 if selectingCharacter then return end
 if Quests.mousereleased(b) then return end
 if b==1 and targetUI.dragging then targetUI.dragging=false;log("TARGET_UI_DRAG_ENDED",{x=math.floor(targetUI.x),y=math.floor(targetUI.y)});return end
 if b==1 and minimap.dragging then minimap.dragging=false;log("MINIMAP_DRAG_ENDED",{x=math.floor(minimap.x),y=math.floor(minimap.y)});return end
 log("MOUSE_RELEASED",{button=b,x=x,y=y});local w,h=love.graphics.getDimensions();ui:mousereleased(x,y,b,w,h)
end
function love.mousemoved(x,y,dx,dy)
 if require('game.custom_dialogue').open then return end
 if Options.move(x,y) then return end
 if Pause.open then return end
 if WorldMap.open then WorldMap.mousemoved(x,y,dx,dy);return end
 if selectingCharacter then return end
 local w,h=love.graphics.getDimensions()
 if Quests.mousemoved(x,y) then return end
 if targetUI.dragging then local target=world.targetedEnemy or world.combatTarget;local pw=260;if target then local name=target.customName or (target.kind=="caveSnake" and "Cave Snake Boss") or target.kind:sub(1,1):upper()..target.kind:sub(2);local text=name.."  Lv "..target.level.."  Tier "..target.tier.."  |  "..world:enemyMainText(target);pw=math.max(260,love.graphics.getFont():getWidth(text)+28) end;targetUI.x=math.max(4,math.min(w-pw-4,x-targetUI.dragOffX));targetUI.y=math.max(4,math.min(h-42-4,y-targetUI.dragOffY));return end
 if minimap.dragging then minimap.x=math.max(4,math.min(w-minimap.w-4,x-minimap.dragOffX));minimap.y=math.max(4,math.min(h-minimap.h-4,y-minimap.dragOffY));return end
 ui:mousemoved(x,y,dx,dy,w,h)
end
function love.resize(w,h)
 local ow,oh=lastWindowW or w,lastWindowH or h
 if ui then ui:rescaleLayout(ow,oh,w,h) end
 if minimap.x then minimap.x=minimap.x*(w/ow);minimap.y=minimap.y*(h/oh) end
 lastWindowW,lastWindowH=w,h
end
function love.wheelmoved(x,y)
 if require('game.custom_dialogue').wheel(y)then return end
 if Pause.open or Options.open or require('game.custom_dialogue').open then return end
 if selectingCharacter then return end
 local mx,my=love.mouse.getPosition();local sw,sh=love.graphics.getDimensions();if not WorldMap.open and pointInMinimap(mx,my,sw,sh) then minimap.zoom=math.max(.55,math.min(8,minimap.zoom*1.2^y));minimap.canvas=nil;return end;if WorldMap.open then WorldMap.wheel(y,mx,my);return end;ui:wheelmoved(x,y,mx,my)
end
function love.keypressed(k,scancode,isrepeat)
 if k=="escape" and ui and ui.craftJob and ui.craftJob.bonfireRefuel then ui.craftJob=nil;return end
 if not titleActive and not selectingCharacter and Events.key(k)then return end
 if require('game.custom_dialogue').key(k) then return end
 if Options.key(k) then return end
 if WorldMap.open then if k=="escape" then WorldMap.close() end;return end
 if titleActive then return end
 if selectingCharacter then if CharacterSelect.key(k) == 'confirm' then confirmCharacter() end;return end
 if k=="escape"and ClickActions.pending then ClickActions.cancel();return end
 if k=="escape"and require('game.player_target').id then require('game.player_target').clear();return end
 if ui.questPanel then if k=="escape" then ui.questPanel=nil end;return end
 if Pause.key(k) then return end
 if k=="m" then ui:toggle("mercBand","keyboard");return end
 log("KEY_PRESSED",{key=k,scancode=scancode or "",repeatPress=isrepeat and "true" or "false"})
 if k=="f10" then local ok=inventory:addMoney(100*10000);log("DEBUG_GIVE_GOLD",{amount=100,success=tostring(ok),money=inventory:moneyText()})
 elseif k=="u" then world:unstuckPlayer(player,logger);camera:reset(player.x,player.y)
 elseif k=="i" then ui:toggle("inventory","keyboard")
 elseif k=="e" then ui:toggle("equipment","keyboard")
 elseif k=="k" then ui:toggle("skills","keyboard")
 elseif (k=="1" or k=="2" or k=="3" or k=="4") and require("game.abilities").isMeleeWeapon(ui) then local slot=tonumber(k);local ok,res=ui:castAbilitySlot(slot);log("ABILITY_HOTKEY",{key=k,success=tostring(ok),result=tostring(res)})
 elseif (k=="1" or k=="2" or k=="3" or k=="4" or k=="5" or k=="6") and ui.equipment.offhand=="Spellbook" then local slot=tonumber(k);local ok,res=ui:castMagicSlot(slot);log("MAGIC_HOTKEY",{key=k,success=tostring(ok),result=tostring(res)})
 elseif k=="f1" or k=="f2" or k=="f3" or k=="f4" then local slot=tonumber(k:sub(2));local ok,res=ui:usePotion(slot);log("POTION_HOTKEY",{key=k,success=tostring(ok),result=tostring(res)})
 end
end
function love.keyreleased(k,scancode) log("KEY_RELEASED",{key=k,scancode=scancode or ""}) end
function love.quit() require("game.fieldcraft_ui").logout(ui);require("game.audio").saveSettings();if player and inventory and skills and ui and not selectingCharacter and not titleActive then Save.write(player,inventory,skills,ui,logger) end;saveDisplaySettings();if logger then logger:close("quit") end end
local function drawNode(n)
 local sx,sy=0,0;if n.shake>0 then sx=math.random(-1,1);sy=math.random(-1,1) end;love.graphics.setColor(1,1,1)
 if n.kind=="tree" then if not n.depleted then local sh=n.snowCovered and sprites.snowPineImage or sprites.treeImage;local sw,shh=sh:getDimensions();love.graphics.setColor(.035,.045,.05,.22);love.graphics.draw(sh,n.x+sx,n.y+sy+4,0,1,-.28,sw/2,shh);love.graphics.setColor(1,1,1) end;if n.depleted then local img=n.stumpSnow and sprites.snowPineStumpImage or sprites.tree.depleted;local iw,ih=img:getDimensions();love.graphics.draw(img,n.x+sx,n.y+sy,0,1,1,iw/2,ih/2) else local sway=weather and weather:windAt(n.x,n.y)*.035 or 0;local img=n.snowCovered and sprites.snowPineImage or sprites.treeImage;local iw,ih=img:getDimensions();love.graphics.draw(img,n.x+sx,n.y+sy+ih/2,sway,1,1,iw/2,ih) end
 elseif n.kind=="oak"or n.kind=="poplar" then local treeImage=n.kind=="poplar"and sprites.poplarTreeImage or sprites.oakTreeImage;local snowImage=n.kind=="poplar"and sprites.snowPoplarImage or sprites.snowOakImage; if not n.depleted then local sh=n.snowCovered and snowImage or treeImage;local sw,shh=sh:getDimensions();love.graphics.setColor(.035,.045,.05,.22);love.graphics.draw(sh,n.x+sx,n.y+sy+4,0,1,-.28,sw/2,shh);love.graphics.setColor(1,1,1) end;local img=n.depleted and (n.kind=="poplar"and sprites.poplarStumpImage or n.stumpSnow and sprites.snowOakStumpImage or sprites.oakStumpImage) or (n.snowCovered and snowImage or treeImage);local iw,ih=img:getDimensions();local sway=(not n.depleted and weather) and weather:windAt(n.x,n.y)*.03 or 0;local oy=n.depleted and ih/2 or ih;local py=n.depleted and (n.y+sy) or (n.y+sy+ih/2);love.graphics.draw(img,n.x+sx,py,sway,1,1,iw/2,oy)
 elseif n.kind=="copper" then local stage=n.depleted and "depleted" or ((n.hp or n.maxHp)>math.ceil((n.maxHp or 4)/2) and "full" or "mined");local cq=sprites.copper[stage];love.graphics.draw(sprites.copperImage,cq,n.x+sx,n.y+sy,0,1,1,8,8)
 elseif n.kind=="coal" then local stage=n.depleted and "depleted" or (n.hp>math.ceil(n.maxHp/2) and "full" or "mined");if stage=="full" then love.graphics.draw(sprites.copperImage,sprites.copper.full,n.x+sx,n.y+sy,0,1,1,8,8) elseif stage=="mined" then love.graphics.draw(sprites.coalNode,n.x+sx,n.y+sy,0,1,1,8,8) else love.graphics.draw(sprites.ironNode,sprites.ironNodeQuads.depleted,n.x+sx,n.y+sy,0,1,1,8,8) end
 elseif n.kind=="iron" then local stage=n.depleted and "depleted" or (n.hp>math.ceil(n.maxHp/2) and "full" or "mined");local image=stage=="full" and sprites.copperImage or sprites.ironNode;local quad=stage=="full" and sprites.copper.full or sprites.ironNodeQuads[stage];love.graphics.draw(image,quad,n.x+sx,n.y+sy,0,1,1,8,8)
 elseif n.kind=="tin" then local q=sprites.tin[n.depleted and "depleted" or "full"];love.graphics.draw(sprites.tinImage,q,n.x+sx,n.y+sy,0,1,1,8,8)
 elseif n.kind=="hemp" and not n.depleted then love.graphics.draw(sprites.hempImage,n.x+sx,n.y+sy,0,1,1,8,16)
 elseif n.kind=="flax" and not n.depleted then love.graphics.draw(sprites.flaxImage,n.x+sx,n.y+sy,0,1,1,8,8)
 elseif n.kind=="berryBush" and n.stage~="gone" then local base=sprites.itemImages[n.stage=="root" and "Bush Root" or "Bush Greens"];if base then local iw,ih=base:getDimensions();love.graphics.draw(base,n.x+sx,n.y+sy,0,1.35,1.35,iw/2,ih/2) end;if n.stage=="berries" then local berry=sprites.itemImages[n.berryType];if berry then local iw,ih=berry:getDimensions();love.graphics.draw(berry,n.x+sx,n.y+sy-3,0,1.15,1.15,iw/2,ih/2) end end
 elseif not n.depleted then local imgs={blueMushroom="Large Blue Mushroom",brownMushroom="Brown Mushroom"};local img=sprites.itemImages[imgs[n.kind]];if img then love.graphics.draw(img,n.x+sx,n.y+sy,0,1,1,8,8) end end
end
local function drawMinimap(w,h)
 local map=world.map;local x,y,mw,mh=minimapRect(w,h);local cx,cy=x+mw/2,y+mh/2;local radius=math.min(mw,mh)/2
 love.graphics.setColor(.035,.04,.03,.94);love.graphics.circle('fill',cx,cy,radius+4);love.graphics.setColor(.55,.46,.29,1);love.graphics.circle('line',cx,cy,radius+4)
 love.graphics.stencil(function()love.graphics.circle('fill',cx,cy,radius)end,'replace',1);love.graphics.setStencilTest('greater',0)
 love.graphics.setColor(.07,.3,.52,1);love.graphics.circle('fill',cx,cy,radius)
 local viewW=math.max(map.width,map.height)/minimap.zoom;local viewH=viewW;local left=player.x-viewW/2;local top=player.y-viewH/2
 local sx=mw/viewW;local sy=mh/viewH
 love.graphics.setColor(world.isCave and .35 or .24,world.isCave and .41 or .54,world.isCave and .53 or .28,1)
 local terrain=require('game.map_texture').get(map);love.graphics.setColor(world.isCave and .7 or 1,world.isCave and .7 or 1,world.isCave and .8 or 1);love.graphics.draw(terrain,x-left*sx,y-top*sy,0,map.width/terrain:getWidth()*sx,map.height/terrain:getHeight()*sy)
 local function pos(wx,wy)return x+(wx-left)*sx,y+(wy-top)*sy end
 local function dot(wx,wy,kind) local px,py=pos(wx,wy);if (px-cx)^2+(py-cy)^2>radius*radius then return end;if kind=='person'then love.graphics.setColor(.35,.8,1);love.graphics.circle('fill',px,py,2.5)elseif kind=='station'then love.graphics.setColor(1,.68,.18);love.graphics.rectangle('fill',px-2.5,py-2.5,5,5)elseif kind=='town'then love.graphics.setColor(1,.88,.35);love.graphics.circle('fill',px,py,4)else love.graphics.setColor(.82,.55,1);love.graphics.polygon('fill',px,py-3,px-3,py+3,px+3,py+3)end end
 for _,v in ipairs(world.villages or {})do if not v._authoredProxy then dot(v.cx,v.cy,'town')end end
 for _,o in ipairs((world.map.authored or{}).objects or{})do if o.id=='townCenter'then dot(o.x,o.y,'town')end end
 for _,o in ipairs(world.authoredObjects or {})do local id=o.id;if id=='skillVendor'or id=='shopkeeper'or id=='trader'or id=='healer'or id=='guard'or id=='mercRecruiter'or id=='bankClerk'or id=='questGather'or id=='questKill'or id=='questEscort'or id=='questStory'then dot(o.x,o.y,'person')elseif id=='smelter'or id=='anvil'or id=='tanningVat'or id=='hideStretcher'or id=='spinningWheel'or id=='alchemy'or id=='stove'or id=='magicAltar'or id=='religionAltar'or id=='socketTable'or id=='enchantAltar'or id=='inscription'or id=='loom'or id=='metalLoom'or id=='tailoring'or id=='campfire'then dot(o.x,o.y,'station')elseif id=='caveEntrance'then dot(o.x,o.y,'cave')end end
 for _,e in ipairs(world.isCave and {world.exit}or(world.caveEntrances or{}))do if e then dot(e.x,e.y,'cave')end end
 -- Quest targets use the same viewport transform as the zoomed circular map.
 for _,e in ipairs(world.enemies or{})do if e.questTarget and e.questSpawnKey and not e.dead and not e.inactive then local active=false;for key,qs in pairs(player.quests or{})do if key==e.questSpawnKey and qs.active and qs.active.kind=='kill'and qs.active.target==e.kind then active=true;break end end;if active then local qx,qy=pos(e.x,e.y);if(qx-cx)^2+(qy-cy)^2<=radius*radius then love.graphics.setColor(1,.2,.08);love.graphics.circle('fill',qx,qy,3.5);love.graphics.setColor(1,.85,.35);love.graphics.circle('line',qx,qy,5)end end end end
 for _,camp in ipairs(world.playerCamps or{})do local px,py=pos(camp.x,camp.y);love.graphics.setColor(.95,.75,.4);love.graphics.polygon('line',px,py-4,px-4,py+3,px+4,py+3)end
 love.graphics.setColor(1,1,1);local angle=({up=-math.pi/2,down=math.pi/2,left=math.pi,right=0})[player.headDir]or 0;love.graphics.polygon('fill',cx+math.cos(angle)*6,cy+math.sin(angle)*6,cx+math.cos(angle+2.5)*4,cy+math.sin(angle+2.5)*4,cx+math.cos(angle-2.5)*4,cy+math.sin(angle-2.5)*4);love.graphics.circle('fill',cx,cy,2);love.graphics.setColor(.05,.05,.04);love.graphics.circle('line',cx,cy,3)
 require('game.presence').drawMinimap(world,player,x,y,mw,mh,left,top,sx,sy,cx,cy,radius)
 love.graphics.setStencilTest();love.graphics.setColor(.55,.46,.29,1);love.graphics.circle('line',cx,cy,radius);love.graphics.setColor(.9,.88,.76);love.graphics.print(string.format('%.1fx',minimap.zoom),x+mw-36,y+mh-18)
 love.graphics.setColor(.95,.92,.8);love.graphics.print('N',cx-4,y+2);love.graphics.print('E',x+mw-12,cy-7);love.graphics.print('W',x+3,cy-7)
 for i,label in ipairs({'−','+'})do love.graphics.setColor(.05,.09,.07,.9);love.graphics.rectangle('fill',x+6+(i-1)*24,y+mh-25,22,20,3);love.graphics.setColor(1,1,1);love.graphics.printf(label,x+6+(i-1)*24,y+mh-23,22,'center')end
 local orbX=x-14;local hpY=y+42;local stY=y+82;local function orb(cy,frac,label) frac=math.max(0,math.min(1,frac or 0));love.graphics.setColor(.04,.04,.035,.96);love.graphics.circle('fill',orbX,cy,17);love.graphics.setColor(.55,.47,.30);love.graphics.circle('line',orbX,cy,17);love.graphics.setColor(label=='H' and .72 or .30,label=='H' and .16 or .62,label=='H' and .14 or .92,.95);love.graphics.arc('fill',orbX,cy,14,-math.pi/2,-math.pi/2+math.pi*2*frac);love.graphics.setColor(1,1,1);love.graphics.printf(label,orbX-10,cy-7,20,'center') end;orb(hpY,player.hp/math.max(1,player.maxHp),'H');orb(stY,player.stamina/math.max(1,player.maxStamina),'A')
end
function love.draw()
 require("game.presence").beginFrame()
 if selectingCharacter and not titleActive then
  local w,h=love.graphics.getDimensions();CharacterSelect.draw(sprites,selectedRace,w,h,skills,player,ui.equipment)
  return
 end
 local w,h=love.graphics.getDimensions();love.graphics.clear(.035,.045,.03);camera:begin(w,h);grassGrid()
  if weather and not world.isCave then weather:drawGround(camera.x,camera.y,w/camera.zoom,h/camera.zoom) end
 local drawables={}
 local viewHalfW=w/(2*camera.zoom);local viewHalfH=h/(2*camera.zoom);local viewPad=96
 local function visibleXY(x,y,pad) pad=pad or viewPad;return math.abs(x-camera.x)<=viewHalfW+pad and math.abs(y-camera.y)<=viewHalfH+pad end
 local function addDrawable(sortY,fn,x) if math.abs(sortY-camera.y)<=viewHalfH+viewPad and (not x or math.abs(x-camera.x)<=viewHalfW+viewPad) then drawables[#drawables+1]={y=sortY,draw=fn} end end
 Caves.draw(world,addDrawable)
 require('game.town_decorations').drawWorld(world,addDrawable)
 local function addActorDrawable(e,fn) if not e.eventHidden and visibleXY(e.x,e.y,128) then addDrawable(e.y+8,function() Animation.begin(e);require("game.cursed_enemies").draw(sprites,e);fn();Animation.finish() end,e.x) end end
 -- Village roads. The uploaded gravel autotile supplies the palette/texture, while
 -- the road network is laid out as proper wide lanes and a central market square.
 if sprites.gravelFillImage then
  love.graphics.setColor(1,1,1)
  require("game.roads").draw(world)
 end
 if world.map.drawMountains then world.map:drawMountains()end
 for _,g in ipairs(world.grass) do if visibleXY(g.x,g.y,64) then local grass=g;addDrawable(grass.y-20,function() local img=sprites.grassImages[grass.variant];local iw,ih=img:getDimensions();love.graphics.setColor(1,1,1);love.graphics.draw(img,grass.x,grass.y,0,1,1,iw/2,ih/2) end,grass.x) end end
 require("game.fences").draw(world,addDrawable)
 require("game.watch_towers").draw(world,addDrawable)
 for _,hse in ipairs(world.houses) do local house=hse;local mh=require("game.modular_houses");local inside=mh.is(house) and mh.inside(house,player.x,player.y+4);addDrawable(inside and house.y-36 or house.y+18,function()
  if dayNight and dayNight:isNight() then love.graphics.setColor(1,.72,.28,.12);love.graphics.ellipse("fill",house.x,house.y+10,42,28) end;love.graphics.setColor(1,1,1);require("game.houses").draw(sprites.houses,house,inside)
 end) end
 GoblinCamps.draw(world,addDrawable)
 for _,f in ipairs(world.campfires) do local fire=f;addDrawable(fire.y+6,function()
  love.graphics.setColor(1,1,1)
  love.graphics.draw(sprites.campfireBase,fire.x,fire.y,0,1,1,8,8)
  local frame=(math.floor(love.timer.getTime()*8)%4)+1
  love.graphics.draw(sprites.campfireAnim,sprites.campfireQuads[frame],fire.x,fire.y-1,0,1,1,8,8)
 end) end
 for _,t in ipairs(world.standingTorches or {}) do local torch=t;addDrawable(torch.y+8,function() local lit=dayNight and dayNight:isNight();love.graphics.setColor(1,1,1,1);local timg=lit and sprites.torchStandingLitImage or sprites.torchStandingUnlitImage;love.graphics.draw(timg,torch.x,torch.y,0,1,1,8,8) end) end
 for _,village in ipairs(world.villages) do local world=village
 local ciw,cih=sprites.bankChestImage:getDimensions();addDrawable(world.bankChest.y+cih/2,function() love.graphics.setColor(1,1,1);love.graphics.draw(sprites.bankChestImage,world.bankChest.x,world.bankChest.y,0,1,1,ciw/2,cih/2) end)
 local smw,smh=16,16;addDrawable(world.smelter.y+smh/2,function() love.graphics.setColor(1,1,1);love.graphics.draw(sprites.smelterImage,sprites.smelterQuad,world.smelter.x,world.smelter.y,0,1,1,smw/2,smh/2) end)
 local anw,anh=16,16;addDrawable(world.anvil.y+anh/2,function() love.graphics.setColor(1,1,1);love.graphics.draw(sprites.anvilImage,sprites.anvilQuad,world.anvil.x,world.anvil.y,0,1,1,anw/2,anh/2) end)
 local spw,sph=sprites.spinningWheelImage:getDimensions();addDrawable(world.spinningWheel.y+sph/2,function() love.graphics.setColor(1,1,1);love.graphics.draw(sprites.spinningWheelImage,world.spinningWheel.x,world.spinningWheel.y,0,1,1,spw/2,sph/2) end)
 local alw,alh=sprites.alchemyMortarImage:getDimensions();addDrawable(world.alchemy.y+alh/2,function() love.graphics.setColor(1,1,1);love.graphics.draw(sprites.alchemyMortarImage,world.alchemy.x,world.alchemy.y,0,1,1,alw/2,alh/2) end)
 local stw,sth=sprites.stoveImage:getDimensions();addDrawable(world.stove.y+sth/2,function() love.graphics.setColor(1,1,1);love.graphics.draw(sprites.stoveImage,world.stove.x,world.stove.y,0,1,1,stw/2,sth/2) end)
 local maw,mah=sprites.magicAltarImage:getDimensions();addDrawable(world.magicAltar.y+mah/2,function() love.graphics.setColor(1,1,1);love.graphics.draw(sprites.magicAltarImage,world.magicAltar.x,world.magicAltar.y,0,1,1,maw/2,mah/2) end);local ra=world.religionAltar;if ra then addDrawable(ra.y+8,function() love.graphics.setColor(1,1,1);love.graphics.draw(sprites.religionAltarImage,ra.x,ra.y,0,1,1,8,8) end) end
 local jtw,jth=sprites.socketTableImage:getDimensions();addDrawable(world.socketTable.y+jth/2,function() love.graphics.setColor(1,1,1);love.graphics.draw(sprites.socketTableImage,world.socketTable.x,world.socketTable.y,0,1,1,jtw/2,jth/2) end)
 local eaw,eah=sprites.enchantAltarImage:getDimensions();addDrawable(world.enchantAltar.y+eah/2,function() love.graphics.setColor(1,1,1);love.graphics.draw(sprites.enchantAltarImage,world.enchantAltar.x,world.enchantAltar.y,0,1,1,eaw/2,eah/2) end)
 local itw,ith=sprites.inscriptionTableImage:getDimensions();addDrawable(world.inscription.y+ith/2,function() love.graphics.setColor(1,1,1);love.graphics.draw(sprites.inscriptionTableImage,world.inscription.x,world.inscription.y,0,1,1,itw/2,ith/2) end)
 local ml=world.metalLoom;if ml then addDrawable(ml.y+16,function()love.graphics.setColor(1,1,1);love.graphics.draw(sprites.metalLoomImage,ml.x,ml.y,0,1,1,16,16)end)end
 local lw,lh=sprites.loomImage:getDimensions();addDrawable(world.loom.y+lh/2,function()love.graphics.setColor(1,1,1);love.graphics.draw(sprites.loomImage,world.loom.x,world.loom.y,0,1,1,lw/2,lh/2)end)
 local ttw,tth=sprites.tailorTableImage:getDimensions();addDrawable(world.tailoring.y+tth/2,function() love.graphics.setColor(1,1,1);love.graphics.draw(sprites.tailorTableImage,world.tailoring.x,world.tailoring.y,0,1,1,ttw/2,tth/2) end)
 local tvw,tvh=sprites.tanningVatImage:getDimensions();addDrawable(world.tanningVat.y+tvh/2,function() love.graphics.setColor(1,1,1);love.graphics.draw(sprites.tanningVatImage,world.tanningVat.x,world.tanningVat.y,0,1,1,tvw/2,tvh/2);if #world.tanningVat.jobs>0 then love.graphics.print((function() local n=0;for _,j in ipairs(world.tanningVat.jobs) do n=n+(j.slots or (j.output=="Extra Large Soaked Hide" and 2 or 1)) end;return n end)().."/2",world.tanningVat.x-7,world.tanningVat.y-17) end end)
 local hs=world.hideStretcher;local hsimg=hs.state=="empty" and sprites.stretcherEmptyImage or (hs.state=="stretching" and sprites.stretcherSoakedImage or sprites.stretcherDoneImage);local hsw,hsh=hsimg:getDimensions();addDrawable(hs.y+hsh/2,function() love.graphics.setColor(1,1,1);love.graphics.draw(hsimg,hs.x,hs.y,0,1,1,hsw/2,hsh/2) end)
 world.bankClerk.race=world.bankClerk.race or (((world.houseSeed or 1)%2==0) and "Elf" or "Human");addDrawable(world.bankClerk.y+8,function() local k="bankClerk:"..tostring(world.houseSeed);sprites.npcCosmetics:drawShadow(world.bankClerk,sprites,k);sprites.npcCosmetics:draw(world.bankClerk,sprites,k) end)
 world.mercRecruiter.race=world.mercRecruiter.race or ((((world.houseSeed or 1)+1)%2==0) and "Elf" or "Human");addDrawable(world.mercRecruiter.y+8,function() local k="mercRecruiter:"..tostring(world.houseSeed);sprites.npcCosmetics:drawShadow(world.mercRecruiter,sprites,k,{helmet=true});sprites.npcCosmetics:draw(world.mercRecruiter,sprites,k,{helmet=true});love.graphics.setColor(1,1,1);love.graphics.draw(sprites.commanderArmorImage,sprites.commanderRecruitArmorQuad,world.mercRecruiter.x,world.mercRecruiter.y,0,1,1,8,8);love.graphics.draw(sprites.commanderHeadImage,sprites.commanderRecruitHeadQuad,world.mercRecruiter.x,world.mercRecruiter.y-1,0,1,1,8,9) end)
 end
 for i,n in ipairs(world.tradeKeepers) do local npc=n;local cosmeticKey="trade:"..tostring(npc.trade)..":"..i..":"..tostring(world.houseSeed);addActorDrawable(npc,function() sprites.npcCosmetics:drawShadow(npc,sprites,cosmeticKey);sprites.npcCosmetics:draw(npc,sprites,cosmeticKey) end) end
 for i,n in ipairs(world.traders or {}) do local npc=n;local cosmeticKey="trader:"..i..":"..tostring(world.houseSeed);addActorDrawable(npc,function() sprites.npcCosmetics:drawShadow(npc,sprites,cosmeticKey);sprites.npcCosmetics:draw(npc,sprites,cosmeticKey);love.graphics.setColor(1,.86,.45);love.graphics.print("TRADER",npc.x-20,npc.y-24) end) end
 require('game.bag_keeper').draw(world,sprites,addDrawable)
 for i,n in ipairs(world.healers) do local npc=n;local cosmeticKey="healer:"..i..":"..tostring(world.houseSeed);addActorDrawable(npc,function() sprites.npcCosmetics:drawShadow(npc,sprites,cosmeticKey);sprites.npcCosmetics:draw(npc,sprites,cosmeticKey) end) end
 local defenders={};for _,m in ipairs(world.mercs or {}) do if require("game.party").present(world,m) then defenders[#defenders+1]=m end end;for _,m in ipairs(world.guards or {}) do defenders[#defenders+1]=m end;for _,m in ipairs(defenders) do local merc=m;merc.race=merc.race or (((string.byte(merc.name or "M",1)+(world.houseSeed or 1))%2==0) and "Elf" or "Human");addActorDrawable(merc,function() local k="merc:"..tostring(merc.name)..":"..tostring(world.houseSeed);sprites.npcCosmetics:drawShadow(merc,sprites,k);local savedId=merc.id;merc.id=merc.id or'party';local imported={};for slot,name in pairs(merc.equipment or{})do if sprites.paperDolls and sprites.paperDolls[name]then imported[slot]=name end end;local original=merc.equipment;merc.equipment=imported;sprites.npcCosmetics:draw(merc,sprites,k);merc.equipment=original;merc.id=savedId;love.graphics.setColor(1,1,1);local e=merc.equipment or {};if e.body=="Copper Armor" then require('game.humanoid').draw(sprites.armorCopperImage,sprites.armorCopper.body.down[1],merc.x,merc.y,1,merc.race,'body') elseif e.body=="Leather Armor" then require('game.humanoid').draw(sprites.armorLeatherImage,sprites.armorLeather.body.down[1],merc.x,merc.y,1,merc.race,'body') elseif e.body=="Wizard Robes" then require('game.humanoid').draw(sprites.armorWizardImage,sprites.armorWizard.body.down[1],merc.x,merc.y,1,merc.race,'body') end;if e.head=="Copper Helm" then require('game.humanoid').draw(sprites.armorCopperImage,sprites.armorCopper.helm.down[1],merc.x,merc.y,1,merc.race,'head') elseif e.head=="Leather Helm" then require('game.humanoid').draw(sprites.armorLeatherImage,sprites.armorLeather.helm.down[1],merc.x,merc.y,1,merc.race,'head') elseif e.head=="Wizard Hat" then require('game.humanoid').draw(sprites.armorWizardImage,sprites.armorWizard.helm.down[1],merc.x,merc.y,1,merc.race,'head') end;for _,slot in ipairs({"body","legs","head"}) do require("game.iron_gear").draw(sprites,e[slot],merc.x,merc.y,"down",1,merc.race) end;local wi=e.weapon and sprites.itemImages[e.weapon];if wi and not(sprites.paperDolls and sprites.paperDolls[e.weapon])then local iw,ih=wi:getDimensions();if sprites.itemQuads[e.weapon] then love.graphics.draw(wi,sprites.itemQuads[e.weapon],merc.x+6,merc.y+2,0,.65,.65,8,8) else love.graphics.draw(wi,merc.x+6,merc.y+2,0,.65,.65,iw/2,ih/2) end end;if e.offhand=="Copper Shield" or e.offhand=="Iron Shield" then local si=sprites.itemImages[e.offhand];local q=sprites.itemQuads[e.offhand];if q then love.graphics.draw(si,q,merc.x-6,merc.y+2,0,.65,.65,8,8) else love.graphics.draw(si,merc.x-6,merc.y+2,0,.65,.65,8,8) end end end) end
 for _,n in ipairs(world.nodes) do if visibleXY(n.x,n.y,96) then local node=n;local sy=node.kind=="tree" and node.y+16 or node.y+8;addDrawable(sy,function() drawNode(node) end,node.x) end end
 for _,g in ipairs(world.groundItems) do if visibleXY(g.x,g.y,64) then local ground=g;addDrawable(ground.y+6,function() local img=sprites.itemImages[ground.name];if img then local iw,ih=img:getDimensions();love.graphics.setColor(1,1,1);local quad=sprites.itemQuads[ground.name] or (ground.name=="Fishing Pole" and sprites.fishingPoleQuads.rest) or (sprites.coinQuads[ground.name] and sprites.coinQuads[ground.name].single);if quad then local _,_,qw,qh=quad:getViewport();love.graphics.draw(img,quad,ground.x,ground.y,0,1,1,qw/2,qh/2) else love.graphics.draw(img,ground.x,ground.y,0,1,1,iw/2,ih/2) end end end,ground.x) end end
for _,pool in ipairs(world.bossPools or {}) do local p=pool;addDrawable(p.y-3,function() love.graphics.setColor(1,1,1,.85);Expansion.drawPart(sprites.expansion.pools[p.variant],p.x,p.y) end) end
 for _,shot in ipairs(world.bossShots or {}) do local p=shot;addDrawable(p.y+3,function() love.graphics.setColor(1,1,1);if p.nagaSpell then local iw,ih=sprites.magicBoltsImage:getDimensions();local q=RenderCache.quad(((p.row or 2)-1)*16,0,16,16,iw,ih);love.graphics.draw(sprites.magicBoltsImage,q,p.x,p.y,math.atan2(p.vy,p.vx),1,1,8,8)else Expansion.drawPart(sprites.expansion.shots[p.variant],p.x,p.y,1,math.atan2(p.vy,p.vx))end end) end
 for _,target in ipairs(world.mercs) do local t=target;if (t.slimeCoated or 0)>0 then addDrawable(t.y+9,function() love.graphics.setColor(1,1,1,.8);Expansion.drawPart(sprites.expansion.coating,t.x,t.y) end) end end
 if (player.slimeCoated or 0)>0 then addDrawable(player.y+9,function() love.graphics.setColor(1,1,1,.8);Expansion.drawPart(sprites.expansion.coating,player.x,player.y) end) end
 for _,puddle in ipairs(world.slimePuddles) do local p=puddle;addDrawable(p.y-2,function() local iw,ih=sprites.slimePuddleImage:getDimensions();love.graphics.setColor(1,1,1,.78);love.graphics.draw(sprites.slimePuddleImage,p.x,p.y,0,1,1,iw/2,ih/2) end) end
 for _,proj in ipairs(world.enemyProjectiles) do local p=proj;addDrawable(p.y+2,function() local iw,ih=sprites.slimeProjectileImage:getDimensions();love.graphics.setColor(1,1,1);love.graphics.draw(sprites.slimeProjectileImage,p.x,p.y,0,1,1,iw/2,ih/2) end) end
for _,sh in ipairs(world.sheep) do if not sh.dead then local quad=sh.wool and sprites.sheepWoolQuad or sprites.sheepShornQuad;addActorDrawable(sh,function() love.graphics.setColor(1,1,1);love.graphics.draw(sprites.sheepImage,quad,sh.x,sh.y,0,1,1,16,8) end) end end
for _,n in ipairs(world.customNPCs or {}) do local npc=n;addActorDrawable(npc,function() sprites.npcCosmetics:drawShadow(npc,sprites,npc.key);sprites.npcCosmetics:draw(npc,sprites,npc.key,{gender=npc.gender});love.graphics.setColor(1,1,1);love.graphics.print(npc.name,npc.x-20,npc.y-24) end) end
for _,e in ipairs(world.enemies) do if not e.inactive and (e.kind=="chicken" or e.kind=="cow") and (not e.dead or (e.kind=="cow" and not e.skinned)) then local animal=e;addActorDrawable(animal,function() love.graphics.setColor(animal.dead and .55 or 1,animal.dead and .55 or 1,animal.dead and .55 or 1,animal.dead and .8 or 1);if animal.kind=="chicken" then love.graphics.draw(sprites.chickenImage,sprites.chickenQuads[animal.variant or "hen"],animal.x,animal.y,animal.dead and math.pi/2 or 0,1,1,8,8) else local q=sprites.cowQuads[(animal.state=="roam" and math.floor((love.timer.getTime()*2)%2)==0) and "eat" or "stand"];love.graphics.draw(sprites.cowImage,q,animal.x,animal.y,animal.dead and math.pi/2 or 0,1,1,16,8);if animal.dead and not animal.skinned then love.graphics.setColor(1,1,1);love.graphics.print("SKIN",animal.x-12,animal.y-18) end end end) end end
for _,e in ipairs(world.enemies)do if e.kind=='nagaQueen'and not e.inactive then local queen=e;addActorDrawable(queen,function()require('game.naga_queen').draw(sprites,queen)end)end end
for _,e in ipairs(world.enemies)do if e.kind=='nagalian'and not e.inactive and(not e.dead or not e.skinned)then local n=e;addActorDrawable(n,function()require('game.nagalians').draw(sprites,n)end)end end
for _,e in ipairs(world.enemies)do if e.kind=='caveSnake' and not e.inactive and (not e.dead or not e.skinned)then local snake=e;addActorDrawable(snake,function()require('game.cave_snake').draw(sprites,snake)end)end end
for _,e in ipairs(world.enemies) do local enemy=e;if enemy.kind~='nagaQueen'and enemy.kind~='caveSnake'and enemy.kind~='nagalian' and not enemy.inactive and enemy.kind~="chicken" and enemy.kind~="cow" and (not enemy.dead or ((enemy.kind=="rat" or enemy.kind=="wolf" or enemy.kind=="boar" or enemy.kind=="gigaRat") and not enemy.skinned)) then addActorDrawable(enemy,function() local eimg=enemy.kind=="rat" and sprites.ratImage or (enemy.kind=="wolf" and sprites.wolfImage or sprites.slimeImage);local iw,ih=eimg:getDimensions();local part=Expansion.enemyPart(sprites,enemy);if enemy.dead then love.graphics.setColor(.55,.55,.55,.8);if part then Expansion.drawPart(part,enemy.x,enemy.y,enemy.facing or 1,math.pi/2) else love.graphics.draw(eimg,enemy.x,enemy.y,math.pi/2,1,1,iw/2,ih/2) end;love.graphics.setColor(1,1,1);love.graphics.print("SKIN",enemy.x-12,enemy.y-18) else local ex=enemy.x+(enemy.hitKickX or 0);local ey=enemy.y+(enemy.hitKickY or 0);if not part and enemy.kind~="goblin"and not require('game.dark_content').isUndead(enemy.kind)then love.graphics.setColor(.035,.045,.05,.25);love.graphics.draw(eimg,ex,ey+7,0,1,-.28,iw/2,ih/2) end;if (enemy.hitFlash or 0)>0 then love.graphics.setColor(1,.45,.35) else love.graphics.setColor(1,1,1) end;if enemy.humanoid then sprites.npcCosmetics:drawShadow(enemy,sprites,enemy.customMonster);sprites.npcCosmetics:draw(enemy,sprites,enemy.customMonster,{gender=enemy.gender})elseif require('game.dark_content').isUndead(enemy.kind)then require('game.dark_content').draw(sprites,enemy,true);require('game.dark_content').draw(sprites,enemy)elseif part then Expansion.drawPart(part,ex,ey,enemy.facing or 1) elseif enemy.kind=="goblin" then require("game.goblins").draw(sprites.goblins,enemy,ex,ey);local wi=sprites.itemImages[enemy.weapon];if wi and not(sprites.paperDolls and sprites.paperDolls[e.weapon])then local iw,ih=wi:getDimensions();love.graphics.draw(wi,ex+6,ey+2,0,.7,.7,iw/2,ih/2) end else love.graphics.draw(eimg,ex,ey,0,1,1,iw/2,ih/2) end; end end) end end
 for _,a in ipairs(world.goblinArrows or {}) do local arrow=a;addDrawable(a.y+8,function() love.graphics.setColor(1,1,1);if arrow.magic then love.graphics.setColor(.4,.75,1);love.graphics.circle('fill',arrow.x,arrow.y,3)else love.graphics.line(arrow.x,arrow.y,arrow.x-arrow.vx*.045,arrow.y-arrow.vy*.045)end end) end
 for _,a in ipairs(world.playerArrows or {}) do local arrow=a;addDrawable(a.y+8,function() love.graphics.setColor(1,1,1);if arrow.magic then love.graphics.setColor(.4,.75,1);love.graphics.circle('fill',arrow.x,arrow.y,3)else love.graphics.line(arrow.x,arrow.y,arrow.x-arrow.vx*.045,arrow.y-arrow.vy*.045)end end) end
 for _,a in ipairs(world.mercArrows or {}) do local arrow=a;addDrawable(a.y+8,function() love.graphics.setColor(1,1,1);if arrow.magic then local iw,ih=sprites.magicBoltsImage:getDimensions();local q=RenderCache.quad(((arrow.element or 2)-1)*16,0,16,16,iw,ih);love.graphics.draw(sprites.magicBoltsImage,q,arrow.x,arrow.y,math.atan2(arrow.vy,arrow.vx),1,1,8,8) else love.graphics.setColor(1,.9,.65);if arrow.magic then love.graphics.setColor(.4,.75,1);love.graphics.circle('fill',arrow.x,arrow.y,3)else love.graphics.line(arrow.x,arrow.y,arrow.x-arrow.vx*.045,arrow.y-arrow.vy*.045)end end end) end
 for _,m in ipairs(world.magicProjectiles) do local mp=m;addDrawable(mp.y+6,function() local iw,ih=sprites.magicBoltsImage:getDimensions();local boltIndex=math.max(1,math.min(5,mp.row or 1));local quad=RenderCache.quad((boltIndex-1)*16,0,16,16,iw,ih);local isVoid=(mp.row==5);love.graphics.setColor(isVoid and .72 or 1,isVoid and .45 or 1,1,1);local ang=math.atan2(mp.vy or 0,mp.vx or 1);love.graphics.draw(sprites.magicBoltsImage,quad,mp.x,mp.y,ang,1,1,8,8);love.graphics.setColor(1,1,1) end) end
 for _,e in ipairs(world.magicEffects) do local ef=e;addDrawable(ef.y+40,function() local iw,ih=sprites.magicEffectsImage:getDimensions();local frame=math.min(2,math.floor((ef.t/ef.duration)*3));local quad=RenderCache.quad(frame*16,(ef.row-1)*16,16,16,iw,ih);love.graphics.setColor(1,1,1);love.graphics.draw(sprites.magicEffectsImage,quad,ef.x,ef.y,0,1.4,1.4,8,8) end) end
 for _,jp in ipairs(world.juiceParticles or {}) do local p=jp;addDrawable(p.y+20,function()
  local a=math.max(0,math.min(1,p.time/(p.maxTime or .6)));local k=p.kind
  if p.color then love.graphics.setColor(p.color[1],p.color[2],p.color[3],a)
  elseif k=="wood" then love.graphics.setColor(.58,.36,.18,a) elseif k=="copper" or k=="spark" or k=="ember" then love.graphics.setColor(1,.55,.18,a) elseif k=="water" then love.graphics.setColor(.35,.72,1,a) elseif k=="leaf" or k=="fiber" then love.graphics.setColor(.42,.78,.30,a) elseif k=="bubble" then love.graphics.setColor(.72,.35,.9,a) elseif k=="steam" or k=="air" then love.graphics.setColor(.9,.9,.9,a) elseif k=="void" then love.graphics.setColor(.55,.25,.85,a) elseif k=="earth" then love.graphics.setColor(.55,.40,.24,a) elseif k=="playerhit" then love.graphics.setColor(1,.28,.22,a) else love.graphics.setColor(.85,.85,.85,a) end
  love.graphics.rectangle("fill",p.x,p.y,2,2)
 end) end
 addActorDrawable(player,function()require('game.character_renderer').draw(sprites,player,ui.equipment,world);local a=player.religionBlessAnim;if a then local frame=math.min(5,math.floor((a.t/a.duration)*5)+1);love.graphics.setColor(1,1,1);love.graphics.draw(sprites.religionBlessImage,sprites.religionBlessQuads[frame],player.x,player.y-14,0,1,1,8,8) end end)
 require('game.multiplayer').drawActors(world,player,sprites,camera,addActorDrawable,w,h)
 -- Player magic projectiles and centered ability overlays.
 if player.abilityVisual then local v=player.abilityVisual;local a=require('game.abilities').byName(v.name);if a then ui._abilityImages=ui._abilityImages or {};local img=ui._abilityImages[v.name];if not img then img=love.graphics.newImage(a.asset);img:setFilter('nearest','nearest');ui._abilityImages[v.name]=img end;local frame=math.min(a.frames-1,math.floor((v.t/v.duration)*a.frames));local iw,ih=img:getDimensions();local q=a.vertical and RenderCache.quad(0,frame*a.fh,a.fw,a.fh,iw,ih) or RenderCache.quad(frame*a.fw,0,a.fw,a.fh,iw,ih);addDrawable(player.y+30,function() love.graphics.setColor(1,1,1);love.graphics.draw(img,q,player.x,player.y,0,1,1,a.fw/2,a.fh/2) end) end end
 Quests.setup(world);for _,qn in ipairs(world.questNPCs)do if not qn.linkedCustom then local npc=qn;addActorDrawable(npc,function() Quests.drawNPC(world,player,sprites,npc) end)end end
 require("game.fieldcraft_ui").drawables(ui,camera,addDrawable)
 table.sort(drawables,function(a,b) return a.y<b.y end);for _,d in ipairs(drawables) do d.draw() end
 for _,e in ipairs(world.enemies) do if visibleXY(e.x,e.y,80) and Animation.enemyCombat(world,e) then
  local width=e.kind=="gigaRat" and 42 or e.kind=="slimeBoss" and 32 or 20
  local y=e.y-((e.kind=="gigaRat" or e.kind=="slimeBoss") and 22 or 14)
  love.graphics.setColor(.12,.05,.04,.9);love.graphics.rectangle("fill",e.x-width/2,y,width,3)
  love.graphics.setColor(.75,.18,.14);love.graphics.rectangle("fill",e.x-width/2,y,width*math.max(0,e.hp/e.maxHp),3)
 end end
 local barAlpha=player.combatBarAlpha or 0;if barAlpha>0 then
 love.graphics.setColor(.12,.05,.04,.9*barAlpha);love.graphics.rectangle("fill",player.x-12,player.y-18,24,3);love.graphics.setColor(.2,.8,.25,barAlpha);love.graphics.rectangle("fill",player.x-12,player.y-18,24*(player.hp/player.maxHp),3);love.graphics.setColor(.08,.08,.08,.9*barAlpha);love.graphics.rectangle("fill",player.x-12,player.y-14,24,2);love.graphics.setColor(.85,.75,.2,barAlpha);love.graphics.rectangle("fill",player.x-12,player.y-14,24*(player.stamina/player.maxStamina),2)
 end
 require("game.fieldcraft_ui").worldDraw(ui,camera)
 camera:finish()
 -- Day/night darkness and warm local light sources. Weather darkening remains independent.
 if dayNight then
  local dark=world.isCave and .22 or dayNight:darkness();if dark>0.01 then love.graphics.setBlendMode("alpha");local lx,ly,lw,lh,room=require('game.modular_houses').lightBounds(world,player)
   if lx then
    ui.houseLightMask=ui.houseLightMask or love.graphics.newShader('vec4 effect(vec4 c, Image tex, vec2 uv, vec2 xy){vec4 p=Texel(tex,uv);if(p.a<0.01)discard;return p*c;}')
    local sx,sy=camera:toScreen(lx,ly,w,h);local parts=sprites.houses.modular
    love.graphics.stencil(function()love.graphics.setShader(ui.houseLightMask);love.graphics.setColor(1,1,1);love.graphics.draw(parts.image,parts.rooms[room.houseInterior].q,sx,sy,0,camera.zoom,camera.zoom);love.graphics.setShader()end,'replace',1);love.graphics.setStencilTest('equal',0)
   end
   love.graphics.setColor(.015,.025,.055,dark);love.graphics.rectangle("fill",0,0,w,h)
   if lx then love.graphics.setStencilTest('equal',1);love.graphics.setColor(.015,.025,.055,math.min(dark,.06));love.graphics.rectangle('fill',0,0,w,h);love.graphics.setStencilTest()end
   local function lightAt(wx,wy,radius,strength,seed)
    local sx,sy=camera:toScreen(wx,wy,w,h);local phase=love.timer.getTime()*10.5+(seed or 0);local flick=1+math.sin(phase)*.035+math.sin(phase*1.73)*.018;local r=radius*camera.zoom*flick
    if sx+r<0 or sy+r<0 or sx-r>w or sy-r>h then return end
    love.graphics.setBlendMode("add");love.graphics.setShader(lightShader);lightShader:send("lightCenter",{sx,sy});lightShader:send("lightRadius",r);lightShader:send("lightStrength",strength*.32);love.graphics.setColor(1,1,1,1);love.graphics.rectangle("fill",sx-r,sy-r,r*2,r*2);love.graphics.setShader();love.graphics.setBlendMode("alpha")
   end
   if dayNight:isNight() then
    for i,hse in ipairs(world.houses or {}) do if not(lx and require("game.modular_houses").is(hse))then lightAt(hse.x,hse.y+8,58,.9,i)end end
   end
   -- Nearby placed torches/campfires share one light. This prevents stacked or tightly
   -- spaced fire objects from multiplying brightness while keeping every sprite visible.
   local staticLights={}
   if dayNight:isNight() then for _,t in ipairs(world.standingTorches or {}) do staticLights[#staticLights+1]={x=t.x,y=t.y,r=72,s=1.15} end end
   for _,f in ipairs(world.campfires or {}) do staticLights[#staticLights+1]={x=f.x,y=f.y-2,r=88,s=1.3} end
   local clusters={}
   for _,src in ipairs(staticLights) do
    local hit=nil
    for _,c in ipairs(clusters) do local dx,dy=src.x-c.x,src.y-c.y;if dx*dx+dy*dy<=48*48 then hit=c;break end end
    if hit then hit.n=hit.n+1;hit.sumX=hit.sumX+src.x;hit.sumY=hit.sumY+src.y;hit.x=hit.sumX/hit.n;hit.y=hit.sumY/hit.n;hit.r=math.max(hit.r,src.r);hit.s=math.max(hit.s,src.s)
    else clusters[#clusters+1]={x=src.x,y=src.y,sumX=src.x,sumY=src.y,n=1,r=src.r,s=src.s} end
   end
   for i,c in ipairs(clusters) do lightAt(c.x,c.y,c.r,c.s,400+i) end
   if ui.equipment.offhand=="Lit Torch" then lightAt(player.x,player.y,92,1.35,333) end
   for i,g in ipairs(world.groundItems or {}) do if g.name=="Lit Torch" and g.lit~=false then lightAt(g.x,g.y,82,1.2,500+i) end end
  end
 end
 -- Precipitation is drawn after world lighting so rain/snow cannot be hidden by later overlays.
 if weather and not world.isCave then weather:drawScreenEffects(player.x,player.y,w,h,camera.zoom) end
 -- Cheap dawn lens flare: strongest just after sunrise, then fades away.
 if dayNight and not world.isCave then local t=dayNight.time or 0;local dawn=0;if t>=.20 and t<.34 then local u=(t-.20)/.14;dawn=math.sin(u*math.pi) end;if dawn>0 then local sx=w*(.08+.28*((t-.20)/.14));local sy=h*.16;love.graphics.setBlendMode("add");love.graphics.setColor(1,.72,.32,.10*dawn);love.graphics.circle("fill",sx,sy,70+40*dawn);love.graphics.setColor(1,.86,.55,.16*dawn);love.graphics.circle("fill",sx,sy,18+8*dawn);for i=1,3 do local f=i/4;local fx=sx+(w*.5-sx)*f;local fy=sy+(h*.5-sy)*f;love.graphics.setColor(1,.65,.28,.035*dawn);love.graphics.circle("fill",fx,fy,10+i*7) end;love.graphics.setBlendMode("alpha") end end

 -- World feedback is rendered in screen space so fonts stay crisp at every camera/window scale.
 local font=love.graphics.getFont()
 for _,p in ipairs(world.popups) do
  local sx,sy=camera:toScreen(p.x,p.y,w,h);local text=tostring(p.text);local maxText=math.max(80,math.min(260,w-24));local _,lines=font:getWrap(text,maxText-16);local lineCount=math.max(1,#lines);local tw=math.min(maxText,math.max(48,font:getWidth(text)+16));if lineCount>1 then tw=maxText end;local th=lineCount*font:getHeight()+10
  local bx=math.floor(math.max(6,math.min(w-tw-6,sx-tw/2)));local by=math.floor(math.max(6,math.min(h-th-6,sy-th/2)))
  love.graphics.setColor(.035,.035,.03,.90);love.graphics.rectangle("fill",bx,by,tw,th,4,4);love.graphics.setColor(.55,.47,.32,.95);love.graphics.rectangle("line",bx,by,tw,th,4,4)
  if p.kind=="damage" then love.graphics.setColor(1,.55,.48) elseif p.kind=="defeat" then love.graphics.setColor(.65,1,.62) elseif p.kind=="defence" then love.graphics.setColor(.65,.82,1) else love.graphics.setColor(1,.92,.68) end
  love.graphics.printf(text,bx+8,by+5,tw-16,"center")
 end
 if titleActive then
  -- Large angled title across the top. Shadow first keeps it readable over the moving world.
  local titleFont=RenderCache.titleFont(math.max(96,math.min(150,math.floor(w*.085))));local oldFont=love.graphics.getFont();love.graphics.setFont(titleFont);love.graphics.push();love.graphics.translate(w*.50,78);local scale,angle=Animation.title(love.timer.getTime());love.graphics.rotate(angle);love.graphics.scale(scale,scale);love.graphics.setColor(.02,.025,.02,.55);love.graphics.printf("STONEGROVE",-w*.44+3,3,w*.88,"center");love.graphics.setColor(1,.88,.58,.98);love.graphics.printf("STONEGROVE",-w*.44,0,w*.88,"center");love.graphics.pop();love.graphics.setFont(oldFont)
  love.graphics.setColor(1,1,1,.72);love.graphics.print("A wandering world",34,26)
  local bx=32;local gap=10;local bw=240;local bh=42;local bottom=h-34
  local function button(label,y,enabled) love.graphics.setColor(.035,.032,.025,enabled and .72 or .46);love.graphics.rectangle("fill",bx,y,bw,bh,6,6);love.graphics.setColor(enabled and .78 or .32,enabled and .63 or .32,enabled and .32 or .32,.92);love.graphics.rectangle("line",bx,y,bw,bh,6,6);love.graphics.setColor(enabled and 1 or .45,enabled and .91 or .45,enabled and .70 or .45,1);love.graphics.printf(label,bx,y+13,bw,"center") end
  local exitY=bottom-bh;local optionsY=exitY-gap-bh;local continueY=optionsY-gap-bh;local newY=continueY-gap-bh;button("New",newY,true);button("Continue",continueY,titleHasSave);button("Options",optionsY,true);button("Exit",exitY,true)
  local mx,my=love.mouse.getPosition();local label,detail
  if mx>=bx and mx<=bx+bw then
    local rows={{"Exit","Close the game."},{"Options","Adjust audio volumes and display options."},{"Continue",titleHasSave and "Load your saved character and continue." or "No saved character is available."},{"New","Start a new character. This replaces saved character progress when saved."}}
    for i,a in ipairs(rows) do local yy=bottom-bh-(i-1)*(bh+gap);if my>=yy and my<=yy+bh then label,detail=a[1],a[2] end end
  end
  if label then ui:drawTooltip({name=label},mx,my,w,h,{title=label,type="Title menu",detail=detail}) end
  Options.draw();require('game.custom_dialogue').draw();return
 end
 love.graphics.setColor(1,1,1,1);ClickActions.draw(camera,w,h);require('game.player_target').draw(ui,camera,w,h);ui:draw(w,h);drawMinimap(w,h);do local bx,by,bw,bh=minimapRect(w,h);require("game.bonfire_ui").drawBuff(ui,bx,math.min(h-40,by+bh+8),w,h)end;do local mx,my=love.mouse.getPosition();local mx0,my0,mw0,mh0=minimapRect(w,h);local ox=mx0-14;local hy=my0+42;local sy=my0+82;if (mx-ox)^2+(my-hy)^2<=19^2 then ui:drawTooltip({name='Health'},mx,my,w,h,{title='Health',type='Player status',detail=string.format('%d / %d',math.floor(player.hp+0.5),math.floor(player.maxHp+0.5))}) elseif (mx-ox)^2+(my-sy)^2<=19^2 then ui:drawTooltip({name='Stamina'},mx,my,w,h,{title='Stamina',type='Player status',detail=string.format('%d / %d',math.floor(player.stamina+0.5),math.floor(player.maxStamina+0.5))}) end end;do local mx0,my0,mw0,mh0=minimapRect(w,h);local zx,zy=mx0+mw0+8,my0+8;for i,label in ipairs({"+","-"}) do local yy=zy+(i-1)*34;love.graphics.setColor(.04,.04,.035,.94);love.graphics.rectangle("fill",zx,yy,28,28,5,5);love.graphics.setColor(.72,.62,.40);love.graphics.rectangle("line",zx,yy,28,28,5,5);love.graphics.setColor(1,1,1);love.graphics.printf(label,zx,yy+5,28,"center") end end;WorldMap.draw(Regions,world,player)
 local target=world.targetedEnemy or world.combatTarget
 if target and Animation.enemyCombat(world,target) then local name=target.customName or (target.kind=="caveSnake" and "Cave Snake Boss") or target.kind:sub(1,1):upper()..target.kind:sub(2);local text=name.."  Lv "..target.level.."  Tier "..target.tier.."  |  "..world:enemyMainText(target);local pw=math.max(260,love.graphics.getFont():getWidth(text)+28);local px=targetUI.x or ((w-pw)/2);local py=targetUI.y or 12;px=math.max(4,math.min(w-pw-4,px));py=math.max(4,math.min(h-42-4,py));targetUI.x,targetUI.y=px,py;love.graphics.setColor(.05,.045,.035,.94);love.graphics.rectangle("fill",px,py,pw,42,5,5);love.graphics.setColor(.62,.50,.30);love.graphics.rectangle("line",px,py,pw,42,5,5);love.graphics.setColor(1,1,1);love.graphics.printf(text,px+8,py+6,pw-16,"center");love.graphics.setColor(.15,.05,.04);love.graphics.rectangle("fill",px+12,py+27,pw-24,6);love.graphics.setColor(.75,.18,.14);love.graphics.rectangle("fill",px+12,py+27,(pw-24)*(target.hp/target.maxHp),6) end

 if not Pause.open and not WorldMap.open and not require("game.admin_menu").open and not ui.questPanel and not require("game.presence").hover(love.mouse.getPosition())then ui:drawHelp(w,h,camera,{minimapRect(w,h)}) end
 if not Pause.open and not WorldMap.open and not require("game.admin_menu").open then Quests.drawUI(ui,camera,{minimapRect(w,h)}) end
 if not Pause.open and not Options.open and not require("game.custom_dialogue").open and not ui.questPanel then require("game.presence").drawTooltip(w,h)end
 Pause.draw()
 Options.draw()
 require('game.custom_dialogue').draw();Events.draw();require('game.admin_menu').draw()
end


local fieldcraftKey=love.keypressed
love.keypressed=function(k,...)if k=='escape'and ui and(ui.campPlacement or ui.campSelected or ui.potPlacement or ui.shellContext)then ui.campPlacement=nil;ui.campSelected=nil;ui.potPlacement=nil;ui.shellContext=nil;return end;return fieldcraftKey(k,...)end
local offlineChild=false;for _,v in ipairs(arg or {})do if v=='--offline-game'then offlineChild=true;break end end
if offlineChild then
 require('game.launcher').offline=true
else
 require("game.launcher").install()
 require("game.presence").install(require("game.launcher"))
 require('game.multiplayer').install(require('game.launcher'))
end

require('game.admin_menu').install()

local amountKey,amountText=love.keypressed,love.textinput
love.keypressed=function(k,...)if ui and ui.craftAmountPrompt and ui:craftAmountKey(k)then return end;if k=='escape'and ui and ui.craftRecipeContext then ui.craftRecipeContext=nil;return end;return amountKey(k,...)end
love.textinput=function(text)if ui and ui:craftAmountText(text)then return end;if amountText then return amountText(text)end end

local toolKey=love.keypressed
love.keypressed=function(k,...)if k=='escape'and ui and ui.toolContext then ui.toolContext=nil;return end;return toolKey(k,...)end

local featherKeypressed=love.keypressed
love.keypressed=function(key,...)if key=='escape'and ui then ui.featherBatch=nil end;return featherKeypressed(key,...)end
