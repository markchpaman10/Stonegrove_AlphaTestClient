local S={}
local meat={rat='Small Meat',wolf='Large Meat',cow='Large Meat',boar='Large Meat',gigaRat='Giga Rat Meat',caveSnake='Cave Snake Meat'}
function S.required(e)return tonumber(e.skinningLevel or e.skinLevel)or((e.kind=='cow'or e.kind=='boar')and require('game.unlocks').actions.largeHide[2]or 1)end
function S.try(w,e,p,skills,inv,logger)
 if not e or not meat[e.kind]then return nil end
 local required=S.required(e);local level=skills:get('Skinning').level;if level>=required then return nil end
 if not e.dead or e.skinned or e.inactive then return false,'not_skinnable'end
 local reach=(e.kind=='cow'or e.kind=='wolf'or e.kind=='rat'and not w.isCave)and 42 or 70
 if(e.x-p.x)^2+(e.y-p.y)^2>reach^2 then return false,'too_far'end
 if level<required-10 then local why='Requires Skinning level '..required..' (partial skinning starts at '..math.max(1,required-10)..')';w:addPopup(p.x,p.y-24,why);return false,why end
 if p.equipped~='Copper Knife'and p.equipped~='Copper Dagger'and not inv:hasItem('Copper Knife')and not inv:hasItem('Copper Dagger')then return false,'missing_Copper_Dagger_or_Copper_Knife'end
 local trial=require('game.rune_inventory').clone(inv)
 if not trial:add(meat[e.kind],1)or not trial:add('Torn Hide',1)then return false,'bag_full'end
 inv.bagSlots=trial.bagSlots;e.skinned=true;local old,new,total=skills:addXP('Skinning',6)
 w:addPopup(e.x,e.y-24,'PARTIAL SKIN: 1 '..meat[e.kind]..' + 1 Torn Hide','defeat')
 if logger then logger:log('ANIMAL_SKINNED',{enemy=e.kind,partial=true,meat=meat[e.kind],item='Torn Hide',requiredLevel=required,level=new,xpGained=6,totalXp=total});if new>old then logger:log('SKILL_LEVEL_UP',{skill='Skinning',from=old,to=new,totalXp=total})end end
 return true,'Torn Hide'
end
return S
