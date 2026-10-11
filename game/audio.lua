-- Shared event routing; each completed action owns its cue once.
local C=require('game.sound_catalog')
local A={enabled=true,volume=.65,ready=false,clock=0,pools={},last={},distance=0,serial=0,active={},decodeErrors={},categories={combat=1,ambience=1,gathering=1,crafting=1,ui=1,footsteps=1},voiceSettings={}}
local function canonical(event) return C.aliases[event] or event end
local footsteps={footstep_grass=true,footstep_stone=true,footstep_snow=true}
local function clamp(v,default)
 v=tonumber(v);if not v or v~=v then return default end;return math.max(0,math.min(1,v))
end
A.cueCategories={}
for cue,files in pairs(C.sounds) do
 local folder=files[1]:match('/([^/]+)/[^/]+$');local category='ui'
 if folder=='combat' or folder=='creatures' or folder=='instance_merc' or folder=='magic_runes' then category='combat'
 elseif folder=='environment' then category=footsteps[cue] and 'footsteps' or 'ambience'
 elseif folder=='gathering' or folder=='fishing' then category='gathering'
 elseif folder=='crafting' then category='crafting' end
 A.cueCategories[cue]=category
end
for _,cue in ipairs({'bless_runes','spell_page_write','spell_page_insert'}) do A.cueCategories[cue]='crafting' end
A.cueCategories.target_lock='combat';A.cueCategories.boss_defeat='combat'
function A.gain(category) return A.enabled and A.volume*(A.categories[category] or 1) or 0 end
function A.saveSettings()
 local rows={'return {enabled='..tostring(A.enabled)..',volume='..string.format('%.4f',A.volume)..',categories={'}
 for _,key in ipairs({'combat','ambience','gathering','crafting','ui','footsteps'}) do rows[#rows+1]=key..'='..string.format('%.4f',A.categories[key])..',' end
 rows[#rows+1]='}}';return love.filesystem.write('audio_settings.lua',table.concat(rows))
end
function A.refreshVolumes()
 for _,source in ipairs(A.active) do local v=A.voiceSettings[source];if v then source:setVolume(v.base*A.gain(v.category)) end end
 A.rainVolume=(A.rainBase or 0)*A.gain('ambience')
 if A.rainSource then A.rainSource:setVolume(A.rainVolume);if A.rainVolume<=0 then A.rainSource:stop() elseif A.rainVolume>.005 and not A.rainSource:isPlaying() and #A.active<16 then A.rainSource:play() end end
end
function A.setVolume(key,value)
 if key=='master' then A.volume=clamp(value,A.volume) elseif A.categories[key]~=nil then A.categories[key]=clamp(value,A.categories[key]) else return false end
 A.refreshVolumes();return true
end
function A.resetSettings() A.enabled=true;A.volume=.65;for k in pairs(A.categories) do A.categories[k]=1 end;A.refreshVolumes();A.saveSettings() end
function A.init()
 if A.ready then return end;A.ready=true
 if love.filesystem.getInfo('audio_settings.lua') then local ok,v=pcall(function()return love.filesystem.load('audio_settings.lua')()end);if ok and type(v)=='table' then A.enabled=v.enabled~=false;A.volume=clamp(v.volume,.65);if type(v.categories)=='table' then for key in pairs(A.categories) do A.categories[key]=clamp(v.categories[key],1) end end end end
 if not love.audio or not love.audio.newSource then return end
 for event,files in pairs(C.sounds) do local pool={};A.pools[event]=pool
  for _,path in ipairs(files) do local ok,source=pcall(love.audio.newSource,path,'static');if ok then pool[#pool+1]=source else A.decodeErrors[#A.decodeErrors+1]=path..': '..tostring(source) end end
  -- Six-variant actions need no clones. Single cues get two overlapping voices.
  if #pool==1 and event~='rain' then pool[2]=pool[1]:clone() end
 end
 for alias,event in pairs(C.aliases) do A.pools[alias]=A.pools[event] end
 A.rainSource=A.pools.rain and A.pools.rain[1];if A.rainSource then A.rainSource:setLooping(true) end
end
local function prune()
 for i=#A.active,1,-1 do if not A.active[i]:isPlaying() then A.voiceSettings[A.active[i]]=nil;table.remove(A.active,i) end end
end
function A.stop()
 for _,pool in pairs(A.pools) do for _,s in ipairs(pool) do s:stop() end end
 A.active={};A.voiceSettings={};A.rainVolume=0;A.rainBase=0
end
function A.toggle()
 A.enabled=not A.enabled;if not A.enabled then A.stop() end
 A.refreshVolumes();A.saveSettings();return A.enabled
end
function A.update(dt,player)
 A.clock=A.clock+math.max(0,dt);A.listener=player;prune()
end
function A.play(event,x,y)
 if not event or not A.ready or not A.enabled then return false end
 event=canonical(event);local pool=A.pools[event];if not pool or #pool==0 then return false end
 local cooldown=footsteps[event] and .12 or event=='inventory_full' and .4 or .06
 if A.last[event] and A.clock-A.last[event]<cooldown then return false end
 local category=A.cueCategories[event] or 'ui';local volume=1
 if x and y and not A.listener then return false end -- world generation has no listener yet
 if x and y and A.listener then local d2=(x-A.listener.x)^2+(y-A.listener.y)^2;if d2>=550^2 then return false end;volume=volume*(1-math.sqrt(d2)/550) end
 volume=volume*(footsteps[event] and .25 or event=='player_hurt' and .5 or event=='campfire_pop' and .25 or .75)
 local base=volume;volume=base*A.gain(category);if volume<=0 then return false end
 prune();if #A.active+(A.rainSource and A.rainSource:isPlaying() and 1 or 0)>=16 then return false end
 A.serial=A.serial+1;local start=(A.serial-1)%#pool+1
 for i=0,#pool-1 do local s=pool[(start+i-1)%#pool+1];if not s:isPlaying() then s:setVolume(volume);s:setPitch(1+((A.serial%5)-2)*.025);s:play();A.voiceSettings[s]={base=base,category=category};A.active[#A.active+1]=s;A.last[event]=A.clock;return true end end
 return false
end
function A.movement(player,oldX,oldY,w)
 local d=math.sqrt((player.x-oldX)^2+(player.y-oldY)^2)
 if d>20 then A.distance=0;return end;if d==0 then return end
 A.distance=A.distance+d;if A.distance>=25 then A.distance=A.distance%25;A.play(w.isCave and 'stoneStep' or (A.snow or 0)>.12 and 'snowStep' or 'step',player.x,player.y) end
end
local craftSounds={anvil='smith_hammer',smelter='smelting',alchemy='alchemy_mix',spinningWheel='spinning_wheel',tailoring='sewing',sewing='sewing',leathercraft='sewing',woodcraft='knife_cut',fletching='fletching',inscription='spell_page_write',stove='cooking_sizzle',campfire='cooking_sizzle'}
function A.craft(station,item,x,y)
 A.play(tostring(item):find('Burnt',1,true) and 'cooking_burnt' or craftSounds[station] or 'craft_complete',x,y)
end
local hurtSounds={rat='rat_hurt',gigaRat='rat_hurt',wolf='wolf_hurt',boar='boar_hurt',chicken='chicken_hurt',slime='slime_hit',slimeBoss='slime_hit'}
function A.hurt(kind,x,y) local cue=hurtSounds[kind];if cue then A.play(cue,x,y) end end
function A.death(kind,x,y)
 local boss=kind=='gigaRat' or kind=='slimeBoss' or kind=='caveSnake'
 A.play(boss and 'boss_defeat' or kind=='rat' and 'rat_death' or kind=='wolf' and 'wolf_death' or 'enemy_death',x,y)
end
local events={
 POTION_USED='potion',ITEM_EATEN='potion',NOTIFICATIONS_TOGGLED='click',
 ITEM_EQUIPPED='equip',ITEM_UNEQUIPPED='equip',AMMO_EQUIPPED='equip',POTION_BELT_EQUIPPED='equip',POTION_BELT_UNEQUIPPED='equip',MERCENARY_EQUIPPED='equip',MERCENARY_UNEQUIPPED='equip',
 BANK_OPENED='open',SHOP_OPENED='open',CRAFTING_OPENED='open',SOCKET_TABLE_OPENED='open',ENCHANT_ALTAR_OPENED='open',MERCENARY_RECRUITER_OPENED='open',MERCENARY_SKILLS_OPENED='open',BANK_CLERK_OPENED='open',MAGIC_ALTAR_INTERACTED='open',LEATHERWORKING_OPENED='open',
 INVENTORY_DRAG_STARTED='item_select',INVENTORY_MOVED='item_move',POTION_BELT_DRAG='item_move',BANK_SLOTS_SWAPPED='item_move',BANK_EXPANDED='coins',GROUND_ITEMS_AREA_PICKUP='pickup',
 RUNE_BAG_OPENED='rune_bag',AMMO_CONTAINER_OPENED='rune_bag',RUNE_BAG_SLOT_DEPOSIT='rune_bag',RUNE_BAG_SLOT_WITHDRAW='rune_bag',QUIVER_LOADED='item_move',QUIVER_RELOADED='item_move',QUIVER_UNLOADED='item_move',QUIVER_SLOT_DEPOSIT='item_move',QUIVER_SLOT_WITHDRAW='item_move',
 SPELL_PAGE_ADDED='spell_page_insert',SPELL_PAGE_REMOVED='ui_back',SPELL_HOTBAR_REMOVED='ui_back',ABILITY_HOTBAR_REMOVED='ui_back',ABILITY_HOTBAR_SET='item_select',
 SOCKET_ITEM_SELECTED='item_select',ENCHANT_GEM_SELECTED='item_select',ENCHANT_PAGE_SELECTED='item_select',
 RUNE_MATERIALS_BLESSED='bless_runes',RUNE_MATERIAL_PREPARED='knife_cut',ONYX_CARVED='knife_cut',SLIME_TUBE_FILLED='alchemy_mix',
 FISH_FILLETED='fillet_fish',ARROWS_ASSEMBLED='fletching',IRON_ARROW_ASSEMBLED='fletching',BOWS_STRUNG='fletching',CLOTH_DYED='alchemy_mix',JEWEL_CUT='knife_cut',JEWEL_EXTRACT='mining_clink',GEM_ENCHANTED='bless_runes',GEM_SOCKETED='craft_complete',SOCKET_CREATED='craft_complete',SOCKET_BROKEN='error',
 CRAFT_BATCH_STARTED='craft_start',CRAFT_BATCH_FINISHED='craft_complete',ITEM_USE_BATCH_STARTED='craft_start',ITEM_USE_BATCH_FINISHED='craft_complete',
 ANIMAL_SKINNED='skinning',SHEEP_SHEARED='shearing',ORE_PROSPECTED='prospecting',PROSPECTING_AREA_COMPLETE='prospecting',
 TANNING_VAT_LOADED='tanning',HIDE_STRETCHER_LOADED='tanning',TANNING_VAT_FINISHED='craft_complete',HIDE_STRETCHER_FINISHED='craft_complete',LEATHER_COLLECTED_FROM_STRETCHER='pickup',
 BUSH_LAYER_GAIN='pickup',RESOURCE_RESPAWNED='resource_respawn',SHEEP_WOOL_REGROWN='resource_respawn',BERRIES_REGROWN='resource_respawn',BUSH_GREENS_REGROWN='resource_respawn',
 CAMPFIRE_CREATED='fire_ignite',CAMPFIRE_EXPIRED='fire_extinguish',TORCH_LIT='fire_ignite',
 FISHING_STARTED='cast_line',FISHING_FAILED='bobber_splash',FISH_CAUGHT='fish_catch',
 BOW_FIRED='bow_shot',COMBAT_MISS='miss',ENEMY_MISS='miss',AUTO_COMBAT_STARTED='target_lock',COMBAT_TARGET_CHANGED='target_lock',SLIME_RANGED_ATTACK='slime_projectile',SLIME_PUDDLE_CREATED='slime_hit',
 ROUGH_ONYX_FOUND='rare_drop',RARE_JEWEL_ROCK_FOUND='rare_drop',HEALER_USED='healer_cast',MERCENARY_RECRUITED='merc_recruit',MERCENARY_FIRED='ui_back',PLAYER_RESPAWNED='player_death',
 GROUND_ITEM_PICKUP_BLOCKED='inventory_full',ITEM_EQUIP_BLOCKED='error',ITEM_UNEQUIP_BLOCKED='inventory_full',POTION_USE_BLOCKED='error',POTION_BELT_UNEQUIP_BLOCKED='inventory_full',JEWEL_CUT_BLOCKED='error',JEWEL_CUT_FAILED='error',JEWEL_EXTRACT_BLOCKED='error',JEWEL_EXTRACT_FAILED='error',GEM_SOCKET_FAILED='error',ONYX_CARVE_BLOCKED='error',COMBAT_ATTACK_BLOCKED='warning',GATHER_BLOCKED='error',ITEM_EAT_BLOCKED='error',ITEM_USE_TARGET_INVALID='error',
}
local transactions={SHOP_BUY='shop_buy',SHOP_SELL='shop_sell',SHOP_SELL_ALL='shop_sell',BANK_WITHDRAW='bank_withdraw',BANK_DEPOSIT='bank_deposit',BANK_DEPOSIT_ALL='bank_deposit',BANK_DEPOSIT_EVERYTHING='bank_deposit',BANK_DEPOSIT_DRAG='bank_deposit',BANK_DEPOSIT_CLICK='bank_deposit',BAG_EQUIP_ATTEMPT='equip',RUNE_BAG_STORE='rune_bag'}
local ores={copper=true,tin=true,iron=true,coal=true}
function A.event(event,data)
 if not A.ready or not A.enabled then return end
 data=data or {};local cue=events[event]
 if transactions[event] then
  -- Shop also logs an internal receipt; only the UI's result plays the transaction cue.
  if data.success==nil then return end
  cue=(data.success==true or data.success=='true') and transactions[event] or 'error'
 elseif (event=='AMMO_CONTAINER_DRAG_DEPOSIT' or event=='POTION_BELT_EQUIP_ATTEMPT') and data.success=='false' then cue='error' -- success has its own completed-action event
 elseif event=='ITEM_USED_ON_ITEM' then
  if data.result=='woodworking_opened' or data.result=='sewing_opened' or data.result=='leatherworking_opened' then cue='open' elseif data.success=='false' then cue='error' end
 elseif (event=='MAGIC_HOTKEY' or event=='ABILITY_HOTKEY') and data.success=='false' and data.result~='cooldown' then cue='error'
 elseif event=='MENU_CHANGED' or event=='BAG_TOGGLED' then cue=data.state=='closed' and 'close' or (tostring(data.menu):find('bag',1,true) and 'bag_open' or 'open')
 elseif event=='GROUND_ITEM_PICKED_UP' then cue=data.item=='Egg' and 'egg_pickup' or tostring(data.item):find('Coin',1,true) and 'coin_pickup' or 'pickup'
 elseif event=='RESOURCE_HIT' then cue=(data.resource=='tree' or data.resource=='oak') and 'wood' or ores[data.resource] and 'mine' or 'knife_cut'
 elseif event=='RESOURCE_DEPLETED' then cue=(data.resource=='tree' or data.resource=='oak') and 'tree_fall' or ores[data.resource] and 'ore_break' or 'pickup'
 elseif event=='ENEMY_DEFEATED' then A.death(data.enemy,data.x,data.y);return
 elseif event=='ENEMY_AGGRO' and data.enemy=='gigaRat' then cue='giga_rat_roar'
 elseif event=='ENEMY_RESPAWNED' and (data.enemy=='gigaRat' or data.enemy=='slimeBoss' or data.enemy=='caveSnake') then cue=data.enemy=='gigaRat' and 'giga_rat_roar' or 'boss_spawn'
 elseif event=='COMBAT_HIT' then cue=data.weapon=='Bow' and 'arrow_impact' or tostring(data.weapon):find('Dagger',1,true) and 'dagger_hit' or 'sword_hit';A.hurt(data.target,data.x,data.y)
 elseif event=='PLAYER_DAMAGED' then cue=(tonumber(data.damage) or 0)>0 and 'player_hurt' or 'block';if (tonumber(data.blocked) or 0)>0 then A.play('armor_hit',data.x,data.y) end
 end
 if cue then A.play(cue,data.x,data.y) end
end
A.ui=A.event
function A.environment(dt,p,w,weather)
 if not A.ready then return end
 local rain,snow=0,0;if not w.isCave and weather then rain,snow=weather:at(p.x,p.y) end;A.snow=snow
 local target=A.enabled and rain*.22 or 0;A.rainBase=(A.rainBase or 0)+(target-(A.rainBase or 0))*math.min(1,dt*3);A.rainVolume=A.rainBase*A.gain('ambience')
 local s=A.rainSource;if s then s:setVolume(A.rainVolume);if A.rainVolume>.005 then if not s:isPlaying() and #A.active<16 then s:play() end elseif s:isPlaying() then s:stop() end end
 A.ambientTimer=(A.ambientTimer or 0)-dt;if A.ambientTimer>0 then return end;A.ambientTimer=2.5
 if not A.enabled then return end
 -- Nearby fires only. No random audio draws, and no effects issued from render callbacks.
 local nearest,best=nil,100^2;for _,f in ipairs(w.campfires or {}) do local d=(f.x-p.x)^2+(f.y-p.y)^2;if d<best then nearest=f;best=d end end
 if nearest then A.play('campfire_pop',nearest.x,nearest.y) end
end
return A
