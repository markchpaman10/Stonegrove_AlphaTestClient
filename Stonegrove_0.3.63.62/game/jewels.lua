local J={cuts=require('game.jewel_progression').cuts}
function J.process(ui,bi,slot)
 local b=ui.inv:getBag(bi);local obj=b and b.slots[slot];if not obj then return false,'empty' end
 local carve=obj.name=='Cut Onyx';local def=J.cuts[obj.name];if not carve and not def then return false,'invalid' end
 if not ui.inv:hasItem('Chisel') and ui.player.equipped~='Chisel' then return false,'missing_chisel' end
 if not ui.inv:hasItem('Copper Hammer') and ui.player.equipped~='Copper Hammer' then ui.world:addPopup(ui.player.x,ui.player.y-22,'NEED COPPER HAMMER','miss');return false,'missing_hammer' end
 local level=ui.skills:get('Jewel Crafting').level
 if not carve and level<def.level then ui.world:addPopup(ui.player.x,ui.player.y-22,'JEWEL CRAFTING '..def.level..' REQUIRED','miss');return false,'level' end
 local chance=carve and 1 or require('game.jewel_progression').cutChance(level)
 -- Check room for either outcome before making a roll; never consume a stacked rough gem without room.
 if (obj.qty or 1)>1 and (not ui.inv:canAdd(carve and 'Carved Onyx' or def.out,carve and 3 or 1) or (not carve and not ui.inv:canAdd(obj.name:gsub('Rough ','')..' Dust',1))) then ui.world:addPopup(ui.player.x,ui.player.y-22,'FULL INVENTORY','miss');return false,'bags_full' end
 local success=carve or math.random()<=chance
 local output=carve and 'Carved Onyx' or success and def.out or obj.name:gsub('Rough ','')..' Dust';local qty=carve and 3 or 1
 if (obj.qty or 1)==1 then b.slots[slot]={name=output,qty=qty,qualityGrade=require('game.quality').roll(level)} else obj.qty=obj.qty-1;assert(require('game.quality').add(ui.inv,output,qty,level,require('game.inventory').add)) end
 if success then ui.skills:addXP('Jewel Crafting',carve and 12 or def.xp) end
 ui.world:addPopup(ui.player.x,ui.player.y-22,(success and '+' or 'GEM BROKE: ')..qty..' '..string.upper(output),success and 'defeat' or 'miss')
 ui:log(carve and 'ONYX_CARVED' or success and 'JEWEL_CUT' or 'JEWEL_CUT_FAILED',{rough=obj.name,cut=output,qty=qty,chance=chance})
 return true,output
end
return J
