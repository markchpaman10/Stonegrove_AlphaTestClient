local S={HARD_MAX=6}
function S.limit(level) return require('game.jewel_progression').socketLimit(level) end
function S.normalize(obj)
 obj.sockets=obj.sockets or {}
 for i,s in ipairs(obj.sockets) do
  if type(s)=='string' then s={name=s,qty=1};obj.sockets[i]=s end
  if not s.state then s.state=s.name and 'filled' or 'open' end
 end
 -- Old saves already contain filled gem objects. Retain each enchantment.
 if #obj.sockets>0 or obj.socketMax then obj.socketMax=math.min(6,math.max(#obj.sockets,tonumber(obj.socketMax) or #obj.sockets)) end
 return obj.sockets
end
function S.target(ui)
 local t=ui.socketTarget;local b=t and ui.inv:getBag(t.bag);local obj=b and b.slots[t.slot]
 if not obj or (t.item and t.item~=obj) then ui.socketTarget=nil;return nil end
 local info=ui.sprites.itemInfo[obj.name] or {};if not ({Weapon=true,['Head Armor']=true,['Body Armor']=true,['Foot Armor']=true,Offhand=true})[info.type] then ui.socketTarget=nil;return nil end
 return obj
end
function S.create(ui)
 local obj=S.target(ui);if not obj then return false,'no_target' end
 if not ui.inv:hasItem('Chisel') and ui.player.equipped~='Chisel' then ui.world:addPopup(ui.player.x,ui.player.y-22,'NEED CHISEL','miss');return false,'missing_chisel' end
 local sockets=S.normalize(obj);local level=ui.skills:get('Jewel Crafting').level
 local limit=math.min(6,math.max(S.limit(level),obj.socketMax or 0))
 if #sockets>=limit then ui.world:addPopup(ui.player.x,ui.player.y-22,'NO MORE SOCKET POSITIONS','miss');return false,'full' end
 local chance=require('game.jewel_progression').socketChance(level);local success=math.random()<=chance
 obj.socketMax=limit;sockets[#sockets+1]={state=success and 'open' or 'broken'}
 if success then ui.skills:addXP('Jewel Crafting',18) end
 ui.world:addPopup(ui.player.x,ui.player.y-22,success and 'OPEN SOCKET CREATED' or 'SOCKET PERMANENTLY BROKEN',success and 'defeat' or 'miss')
 ui:log(success and 'SOCKET_CREATED' or 'SOCKET_BROKEN',{item=obj.name,position=#sockets,maxSockets=limit,chance=chance})
 return true,success and 'open' or 'broken'
end
function S.insert(ui,bagIndex,slot)
 local obj=S.target(ui);local b=ui.inv:getBag(bagIndex);local gem=b and b.slots[slot]
 if not obj then return false,'no_target' end
 local info=gem and ui.sprites.itemInfo[gem.name];if not info or info.type~='Cut Jewel' then return false,'not_gem' end
 local sockets=S.normalize(obj);local open
 for i,s in ipairs(sockets) do if s.state=='open' then open=i;break end end
 if not open then ui.world:addPopup(ui.player.x,ui.player.y-22,'CREATE AN OPEN SOCKET FIRST','miss');return false,'no_open_socket' end
 -- Gems are non-stackable, but preserve every field, including enchantment data.
 local moved=require('game.items').copy(gem);moved.qty=1;moved.state='filled';sockets[open]=moved
 if (gem.qty or 1)>1 then gem.qty=gem.qty-1 else b.slots[slot]=nil end
 ui.world:addPopup(ui.player.x,ui.player.y-22,'SOCKETED '..string.upper(gem.name),'defeat')
 ui:log('GEM_SOCKETED',{item=obj.name,gem=gem.name,position=open,sockets=#sockets,maxSockets=obj.socketMax});return true,open
end
function S.summary(obj)
 local sockets=S.normalize(obj);local broken,filled=0,0
 for _,s in ipairs(sockets) do if s.state=='broken' then broken=broken+1 elseif s.state=='filled' then filled=filled+1 end end
 return #sockets,broken,filled
end
function S.detail(obj)
 local total,broken,filled=S.summary(obj)
 if total==0 then return '' end
 local bonus=require('game.combat').enchantBonuses({sockets=obj.sockets});local parts={}
 for _,entry in ipairs({{'melee','Melee Combat'},{'ranged','Ranged'},{'magic','Magic'},{'damage','Attack/spell damage'},{'healing','Healing'}}) do
  if bonus[entry[1]]>0 then parts[#parts+1]=string.format('%s +%.1f',entry[2],bonus[entry[1]]) end
 end
 return string.format('\nSockets: %d/%d positions created; %d filled, %d open, %d broken.\nUsable positions: %d.\n%s',total,obj.socketMax or total,filled,total-broken-filled,broken,total-broken,#parts>0 and table.concat(parts,'\n') or 'No enchantment bonuses.')
end
function S.tip(obj,index)
 local s=S.normalize(obj)[index];if not s then return nil end
 local title,detail
 if s.state=='broken' then title='Broken Socket';detail='Permanently damaged during socket cutting. Cannot hold a gemstone.'
 elseif s.state=='open' then title='Empty Socket';detail='Insert a cut gemstone here. Insertion is guaranteed; no further failure roll.'
 else title=s.enchantName or s.name;detail=s.enchantValue and string.format('%s +%.1f',s.enchantSpell or s.enchantSkill or 'Enchant',s.enchantValue) or 'No enchantment. This plain gem gives no combat bonus.' end
 detail=detail..'\nPermanently belongs to this '..obj.name..'.'
 return {item={name=title,qty=1},info={title=title,type='Socket '..index,detail=detail}}
end
function S.drawRow(ui,obj,x,y,size)
 if not obj or not obj.sockets then return end
 local sockets=S.normalize(obj);local art=ui.sprites.socketImage;local quads=ui.sprites.socketQuads
 local mx,my=love.mouse.getPosition()
 for i,s in ipairs(sockets) do local px=x+(i-1)*(size+3)
  love.graphics.setColor(1,1,1);love.graphics.draw(art,quads[s.state=='broken' and 2 or 1],px,y,0,size/16,size/16)
  if s.state=='filled' then ui:drawItemSprite(s,px+1,y+1,size-2) end
  if mx>=px and my>=y and mx<px+size and my<y+size then ui.hoverTooltip=S.tip(obj,i) end
 end
end
function S.hoverEquipment(ui,mx,my)
 local x,y=ui:rect('equipment')
 for row,slot in ipairs({'head','body','legs','cape','weapon','offhand','ammo','tool'}) do
  local obj=require('game.items').equipped(ui,slot)
  if obj then for i in ipairs(obj.sockets or {}) do local px=x+68+(i-1)*21;local py=y+40+(row-1)*48+23
   if mx>=px and my>=py and mx<px+18 and my<py+18 then return S.tip(obj,i) end
  end end
 end
end
return S
