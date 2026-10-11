local Select={name='',focus=true,error=nil,dir='down'}
local Names=require('game.character_name')
local Skills=require('game.skills')
local Races=require('game.races')
local Iron=require('game.iron_gear')
local Ears=require('game.race_ears')
local fonts
local function inside(x,y,r) return x>=r.x and x<=r.x+r.w and y>=r.y and y<=r.y+r.h end
function Select.layout(w,h)
 local left=math.max(250,math.floor(w*.30));local top=110;local footer=h-54
 return {name={x=160,y=56,w=w-184,h=34},human={x=24,y=top,w=(left-56)/3,h=32},elf={x=32+(left-56)/3,y=top,w=(left-56)/3,h=32},dwarf={x=40+2*(left-56)/3,y=top,w=(left-56)/3,h=32},
 preview={x=24,y=top+44,w=left-40,h=footer-top-44},skills={x=left,y=top,w=w-left-24,h=footer-top-12},confirm={x=w-224,y=footer,w=200,h=34},rotate={x=48,y=top+180,w=left-88,h=28}}
end
function Select.reset()
 Select.name='';Select.focus=true;Select.all=false;Select.error=nil;Select.dir='down';love.keyboard.setTextInput(true)
end
function Select.getName()
 local name=Names.normalize(Select.name)
 if not name then Select.error='Enter a name (1-24 characters).';Select.focus=true;love.keyboard.setTextInput(true) end
 return name
end
function Select.textinput(text)
 if Select.focus then Select.name=Names.append(Select.all and '' or Select.name,text);Select.all=false;Select.error=nil end
end
function Select.key(key)
 if key=='return' or key=='kpenter' then return Select.getName() and 'confirm' or nil end
 if key=='tab' then Select.focus=not Select.focus;love.keyboard.setTextInput(Select.focus);return end
 if key=='escape' then Select.focus=false;love.keyboard.setTextInput(false);return end
 if not Select.focus then return end
 if key=='a' and (love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')) then Select.all=true
 elseif key=='backspace' then Select.name=Select.all and '' or Names.backspace(Select.name);Select.all=false
 elseif key=='v' and (love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')) then Select.textinput(love.system.getClipboardText()) end
 Select.error=nil
end
function Select.click(mx,my,button,w,h)
 if button~=1 then return end
 local r=Select.layout(w,h);Select.all=false;Select.focus=inside(mx,my,r.name);love.keyboard.setTextInput(Select.focus)
 if inside(mx,my,r.human) then return 'Human' end
 if inside(mx,my,r.elf) then return 'Elf' end
 if inside(mx,my,r.dwarf) then return 'Dwarf' end
 if inside(mx,my,r.rotate) then local dirs={'down','right','up','left'};for i,d in ipairs(dirs) do if d==Select.dir then Select.dir=dirs[i%4+1];break end end end
 if inside(mx,my,r.confirm) and Select.getName() then return 'confirm' end
end
local function panel(r)
 love.graphics.setColor(.10,.13,.12);love.graphics.rectangle('fill',r.x,r.y,r.w,r.h,7,7)
 love.graphics.setColor(.27,.34,.28);love.graphics.rectangle('line',r.x,r.y,r.w,r.h,7,7)
end
function Select.drawPreview(s,race,x,y,scale,dir,frame)
 dir=dir or 'down';frame=frame or 1;local key=dir=='left' and 'right' or dir;local flip=dir=='left' and -1 or 1
 love.graphics.push('all');love.graphics.translate(x,y);love.graphics.scale(scale,scale);love.graphics.setColor(1,1,1)
 local function item(name,ix)
  local image=s.itemImages[name];if not image then return end;local quad=s.itemQuads[name]
  if quad then love.graphics.draw(image,quad,ix,6,0,.7,.7,8,8)
  else local iw,ih=image:getDimensions();love.graphics.draw(image,ix,6,0,.7,.7,iw/2,ih/2) end
 end
 if dir=='up' then item('Iron Sword',flip*9);item('Iron Shield',-flip*9) end
 require('game.humanoid').draw(s.bodyImage,s.player.body[key][frame],0,0,flip,race,'body')
 Iron.draw(s,'Iron Armor',0,0,dir,frame,race);Iron.draw(s,'Iron Boots',0,0,dir,frame,race)
 require('game.humanoid').draw(s.headImage,s.player.head[key][frame],0,0,flip,race,'head');require('game.humanoid').beard(s,race,0,0,dir,frame)
 Ears.draw(s,race,0,0,dir,frame)
 if dir~='up' then item('Iron Sword',flip*9);item('Iron Shield',-flip*9) end
 love.graphics.pop()
end
function Select.draw(s,race,w,h,skills,player,equipment)
 fonts=fonts or {small=love.graphics.newFont(12),normal=love.graphics.newFont(14),title=love.graphics.newFont(24)}
 local r=Select.layout(w,h);love.graphics.push('all');love.graphics.clear(.045,.06,.055)
 love.graphics.setFont(fonts.title);love.graphics.setColor(1,.86,.57);love.graphics.print('Create your character',24,16)
 love.graphics.setFont(fonts.normal);love.graphics.setColor(.8,.85,.78);love.graphics.print('Character name',24,65)
 panel(r.name);love.graphics.setColor(Select.focus and 1 or .5,.72,.4);love.graphics.rectangle('line',r.name.x,r.name.y,r.name.w,r.name.h,7,7)
 love.graphics.setColor(1,.94,.79);local text=Select.name
 if text=='' then love.graphics.setColor(.5,.57,.5);text='Enter your name' end
 if Select.focus and Select.all then love.graphics.setColor(.28,.4,.35);love.graphics.rectangle('fill',r.name.x+9,r.name.y+5,fonts.normal:getWidth(Select.name)+2,24);love.graphics.setColor(1,.94,.79) end
 love.graphics.print(text,r.name.x+10,r.name.y+8)
 if Select.focus and math.floor(love.timer.getTime()*2)%2==0 then love.graphics.setColor(1,.9,.65);local cx=r.name.x+10+(Select.name=='' and 0 or fonts.normal:getWidth(Select.name));love.graphics.line(cx,r.name.y+7,cx,r.name.y+26) end
 for _,v in ipairs({{'Human',r.human},{'Elf',r.elf},{'Dwarf',r.dwarf}}) do panel(v[2]);love.graphics.setColor(race==v[1] and 1 or .6,race==v[1] and .82 or .7,.45);love.graphics.rectangle('line',v[2].x,v[2].y,v[2].w,v[2].h,7,7);love.graphics.printf(v[1],v[2].x,v[2].y+8,v[2].w,'center') end
 panel(r.preview);love.graphics.setColor(.85,.88,.78);love.graphics.printf('Iron outfit preview',r.preview.x,r.preview.y+12,r.preview.w,'center')
 Select.drawPreview(s,race,r.preview.x+r.preview.w/2,r.preview.y+72,7,Select.dir,1)
 panel(r.rotate);love.graphics.setColor(.88,.86,.68);love.graphics.printf('Turn character',r.rotate.x,r.rotate.y+6,r.rotate.w,'center')
 love.graphics.setFont(fonts.small);love.graphics.setColor(.73,.79,.7);love.graphics.printf('Iron armor, boots, sword, shield\nNo helmet',r.preview.x+8,r.rotate.y+38,r.preview.w-16,'center')
 local statsY=r.rotate.y+66
 love.graphics.setColor(1,.86,.57);love.graphics.printf('Starting stats',r.preview.x,statsY,r.preview.w,'center')
 local health=skills:get('Health').level;local agility=skills:get('Agility').level
 local Combat=require('game.combat');equipment=equipment or {};local strength=skills:get('Strength').level;local magic=skills:get('Magic').level
 love.graphics.setColor(.85,.9,.8);love.graphics.printf('Health '..Races.maxHealth(race,health)..'   |   Stamina '..Races.maxStamina(race,agility)..'\nWalk '..player.speed..'   |   Sprint '..string.format('%.1f',player.speed*1.65)..'\nCombat level '..require('game.progression').combatLevel(skills)..'   |   Defence '..Combat.defense(equipment)..'\nMax hit '..Combat.maxDamage(require('game.quality').info(s.itemInfo[equipment.weapon],require('game.quality').object(equipment,'weapon')),strength)..'   |   Magic hit '..Combat.magicDamage(magic)..'\nHealing '..Combat.healing(magic),r.preview.x+8,statsY+20,r.preview.w-16,'center')
 panel(r.skills);love.graphics.setFont(fonts.normal);love.graphics.setColor(1,.86,.57);love.graphics.print('All skills',r.skills.x+12,r.skills.y+10)
 love.graphics.setFont(fonts.small);love.graphics.setColor(.72,.79,.7);love.graphics.printf('Level / XP / racial XP bonus',r.skills.x+12,r.skills.y+12,r.skills.w-24,'right')
 local rows=math.ceil(#Skills.names/2);local colW=(r.skills.w-24)/2;local rowH=math.min(28,(r.skills.h-40)/rows)
 for i,name in ipairs(Skills.names) do local col=math.floor((i-1)/rows);local row=(i-1)%rows;local x=r.skills.x+12+col*colW;local y=r.skills.y+35+row*rowH;local skill=skills:get(name);local bonus=math.floor((Races.multiplier(race,name)-1)*100+.5)
  if row%2==0 then love.graphics.setColor(.13,.17,.14);love.graphics.rectangle('fill',x-3,y-2,colW-8,rowH) end
  love.graphics.setColor(.86,.9,.8);love.graphics.print(name,x,y)
  love.graphics.setColor(bonus>0 and .8 or .5,bonus>0 and .9 or .6,.6);love.graphics.printf(string.format('%d / %g / +%d%%',skill.level,skill.xp,bonus),x,y,colW-16,'right')
 end
 panel(r.confirm);love.graphics.setFont(fonts.normal);love.graphics.setColor(1,.88,.57);love.graphics.printf('Enter world',r.confirm.x,r.confirm.y+9,r.confirm.w,'center')
 love.graphics.setFont(fonts.small);love.graphics.setColor(Select.error and 1 or .65,Select.error and .45 or .75,.6)
 love.graphics.print(Select.error or 'Choose a name and race. Hover a race for traits; Enter to start.',24,h-43)
 local mx,my=love.mouse.getPosition();local hovered
 for _,v in ipairs({{'Human',r.human},{'Elf',r.elf},{'Dwarf',r.dwarf}}) do if inside(mx,my,v[2]) then hovered=v[1];break end end
 if hovered then
  local text=Races.description(hovered);local width=math.min(360,w-48);local _,lines=fonts.small:getWrap(text,width-24);local height=42+#lines*fonts.small:getHeight()*1.2
  local tip={x=math.min(w-width-12,mx+12),y=math.min(h-height-12,my+24),w=width,h=height};panel(tip)
  love.graphics.setColor(1,.86,.57);love.graphics.print(hovered..' traits',tip.x+12,tip.y+10);love.graphics.setColor(.85,.9,.8);love.graphics.printf(text,tip.x+12,tip.y+30,width-24,'left')
 end
 love.graphics.pop()
end
return Select
