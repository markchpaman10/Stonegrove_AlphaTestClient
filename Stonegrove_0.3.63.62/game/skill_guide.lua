local RenderCache=require("game.render_cache")
local Guide={}
local groups={Combat={'Melee Combat','Strength','Agility','Ranged','Magic','Health','Commanding'},Gathering={'Mining','Woodcutting','Fishing','Skinning','Religion'},Production={'Woodworking','Smithing','Leatherworking','Fletching','Alchemy','Jewel Crafting','Cooking','Enchanting','Inscription','Tailoring'},Other={'Firemaking','Prospecting','Love Making','Fieldcraft','Survival','Foraging'}}
local function inside(mx,my,x,y,w,h) return mx>=x and my>=y and mx<x+w and my<y+h end
function Guide.install(UI)
 local draw=UI.drawSkills
 function UI:drawSkills()
  if not self.skillGuide then return draw(self) end
  local name=self.skillGuide;local x,y,w,h=self:rect('skills');local skill=self.skills:get(name)
  local rows=require('game.unlocks').list(name,self.crafting);local first=math.max(0,math.min(self.guideScroll or 0,math.max(0,#rows-4)));self.guideScroll=first
  love.graphics.setColor(.07,.065,.05,.98);love.graphics.rectangle('fill',x,y,w,h,5,5)
  love.graphics.setColor(.72,.62,.40);love.graphics.rectangle('line',x,y,w,h,5,5)
  love.graphics.setColor(1,1,1);love.graphics.print(name..' - Level '..skill.level,x+12,y+8)
  love.graphics.setColor(.4,.10,.08);love.graphics.rectangle('fill',x+w-26,y+4,20,20);love.graphics.setColor(1,1,1);love.graphics.print('X',x+w-21,y+6)
  love.graphics.setColor(.72,.62,.40);love.graphics.rectangle('line',x+12,y+34,86,25,3,3);love.graphics.setColor(1,1,1);love.graphics.print('< All skills',x+18,y+40)
  love.graphics.setColor(.85,.78,.55);love.graphics.print(name=='Tailoring' and 'Open Tailoring >' or name=='Fletching'and'Open Fletching >'or name=='Leatherworking' and 'Open Leatherworking >' or name=='Religion' and 'Passive tiers: hover for effects' or 'Unlocked / Locked',x+125,y+41)
  local nextXP=skill.level<99 and self.skills.xpTable[skill.level+1] or skill.xp
  love.graphics.setColor(.8,.8,.76);love.graphics.print(string.format('XP: %.1f / %g',skill.xp,nextXP),x+14,y+70)
  if name=='Health' then love.graphics.print(string.format('HP: %g / %g',self.player.hp,self.player.maxHp),x+190,y+70)
  elseif name=='Agility' then love.graphics.print(string.format('SP: %.0f / %g',self.player.stamina,self.player.maxStamina),x+190,y+70) end
  local base=self.skills.xpTable[skill.level];local progress=skill.level==99 and 1 or (skill.xp-base)/math.max(1,nextXP-base)
  love.graphics.setColor(.18,.18,.14);love.graphics.rectangle('fill',x+14,y+92,w-28,6);love.graphics.setColor(.45,.72,.3);love.graphics.rectangle('fill',x+14,y+92,(w-28)*progress,6)
  local mx,my=love.mouse.getPosition()
  for i=1,4 do local row=rows[first+i];if row then
   local py=y+110+(i-1)*45;local unlocked=skill.level>=row.level and not row.placeholder
   love.graphics.setColor(.12,.11,.085);love.graphics.rectangle('fill',x+12,py,w-24,41,3,3)
   love.graphics.setColor(unlocked and .95 or .57,unlocked and .84 or .55,unlocked and .55 or .53)
   love.graphics.print('Lv '..row.level,x+18,py+10);local ability=row.text:match('^Ability: (.+)$');if ability then local a=require('game.abilities').byName(ability);self._abilityImages=self._abilityImages or {};local img=self._abilityImages[ability];if a and not img then img=love.graphics.newImage(a.asset);img:setFilter('nearest','nearest');self._abilityImages[ability]=img end;if img and a then local iw,ih=img:getDimensions();local q=RenderCache.quad(0,0,a.fw,a.fh,iw,ih);love.graphics.setColor(1,1,1);love.graphics.draw(img,q,x+72,py+20,0,math.min(1.5,28/a.fw),math.min(1.5,28/a.fh),a.fw/2,a.fh/2) end;love.graphics.setColor(unlocked and .95 or .57,unlocked and .84 or .55,unlocked and .55 or .53);love.graphics.printf(ability..'  (drag to weapon hotbar)',x+94,py+6,w-112,'left') elseif row.icon then self:drawItemSprite({name=row.icon,qty=1},x+65,py+10,22);love.graphics.setColor(unlocked and .95 or .57,unlocked and .84 or .55,unlocked and .55 or .53);love.graphics.printf(row.text,x+94,py+6,w-112,'left')else love.graphics.printf(row.text,x+65,py+6,w-86,'left')end
   if inside(mx,my,x+12,py,w-24,41) then local detail=row.detail or name..' level '..row.level..' required.';local title=row.text;local typ=(unlocked and 'Unlocked' or 'Locked')..(name=='Religion' and ' Passive Tier' or '');if ability then local a=require('game.abilities').byName(ability);title=ability;typ=(unlocked and 'Unlocked' or 'Locked')..' Melee Ability';if a then detail=a.desc..' Cooldown: '..tostring(a.cooldown)..'s. Unlocks at Melee Combat level '..row.level..'. Drag this ability to the melee weapon hotbar.' end else local spell=row.text:match('^Spell: (.+)$');if spell then title=spell;typ=(unlocked and 'Unlocked' or 'Locked')..' Magic Spell';for page,sp in pairs(require('game.magic_system').spells) do if sp.name==spell then detail='Requires Magic level '..tostring(sp.level or row.level)..'. Uses 1 blessed '..sp.rune..' per cast, taking it from the Rune Bag first and inventory second. The matching physical Spell Page must be installed in the equipped Spellbook.';break end end end end;self.hoverTooltip={item={name=row.text,qty=1},info={title=title,type=typ,detail=detail}} end
  end end
  love.graphics.setColor(.75,.73,.66);love.graphics.print(string.format('Scroll: %d-%d of %d',#rows>0 and first+1 or 0,math.min(first+4,#rows),#rows),x+14,y+304)
 end
 local press=UI.mousepressed
 function UI:mousepressed(mx,my,button,w,h)
  if self.open.skills and button==1 and not (self.context or self.shopContext or self.equipmentContext or self.mercContext or self.bagContext) then
   local x,y,pw,ph=self:rect('skills')
   if inside(mx,my,x,y+30,pw,ph-30) then
    if self.skillGuide=='Fletching'and inside(mx,my,x+125,y+34,190,25)then self:openCrafting('woodcraft','skill_guide');local recipes=self.crafting:getRecipes('woodcraft');for i,r in ipairs(recipes)do if r.skill=='Fletching'and(self.skills:get('Fletching').level<30 or r.output=='Poplar Bow')then self.craftScroll.woodcraft=(i-1)*72;break end end;return true end
    if self.skillGuide=='Tailoring' and inside(mx,my,x+125,y+34,190,25) then self:openCrafting('tailoring','skill_guide');return true end
    if self.skillGuide=='Leatherworking' and inside(mx,my,x+125,y+34,190,25) then self:openCrafting('leathercraft','skill_guide');return true end
    if self.skillGuide then if inside(mx,my,x+12,y+34,86,25) then self.skillGuide=nil;self.guideScroll=0;return true end;local rows=require('game.unlocks').list(self.skillGuide,self.crafting);local first=math.max(0,math.min(self.guideScroll or 0,math.max(0,#rows-4)));for i=1,4 do local row=rows[first+i];local py=y+110+(i-1)*45;if row and inside(mx,my,x+12,py,pw-24,41) then local ability=row.text:match('^Ability: (.+)$');if ability and self.skills:get(self.skillGuide).level>=row.level then self.abilityDrag={name=ability};return true end end end;return true end
    local list=groups[self.skillsTab] or groups.Combat
    for i,name in ipairs(list) do local py=y+70+(i-1)*34-self.skillsScroll
     if py>=y+70 and py+30<=y+318 and inside(mx,my,x+16,py,304,30) then self.skillGuide=name;self.guideScroll=0;return true end
    end
   end
  end
  return press(self,mx,my,button,w,h)
 end
 local wheel=UI.wheelmoved
 function UI:wheelmoved(dx,dy,mx,my)
  if self.open.skills and self.skillGuide and inside(mx,my,self:rect('skills')) then
   local rows=require('game.unlocks').list(self.skillGuide,self.crafting)
   self.guideScroll=math.max(0,math.min(math.max(0,#rows-4),(self.guideScroll or 0)-dy));return true
  end
  return wheel(self,dx,dy,mx,my)
 end
end
return Guide
