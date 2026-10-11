local ShopTabs=require('game.shop_skill_tabs')
local CookingTabs=require('game.cooking_tabs')
local RenderCache=require("game.render_cache")
local Combat=require("game.combat")
local UI={};UI.__index=UI
local skillNames={"Mining","Woodcutting","Smithing","Melee Combat","Strength","Agility","Health","Skinning","Leatherworking","Fletching","Ranged","Alchemy","Jewel Crafting","Fishing","Cooking","Enchanting","Inscription","Tailoring","Commanding"}
local skillIcons={Mining="Copper Pickaxe",Woodcutting="Copper Axe",Smithing="Copper Hammer",["Melee Combat"]="Copper Longsword",Strength="Copper Axe",Agility="Copper Dagger",Health="Health Flask",Skinning="Copper Dagger",Leatherworking="Leather",Fletching="Bow String",Ranged="Copper Longsword",Alchemy="Empty Flask",Fishing="Fishing Pole",Cooking="__CRAFT_TABLE__",["Jewel Crafting"]="Chisel",Enchanting="Cut Ruby",Inscription="Inscription Pen and Ink",Tailoring="Needle",Commanding="__COMMANDING__"}
local function inside(mx,my,x,y,w,h) return mx>=x and mx<=x+w and my>=y and my<=y+h end
local function box(x,y,w,h,title) love.graphics.setColor(.08,.075,.06,.96);love.graphics.rectangle("fill",x,y,w,h,5,5);love.graphics.setColor(.72,.62,.40);love.graphics.rectangle("line",x,y,w,h,5,5);love.graphics.setColor(1,1,1);love.graphics.print(title,x+10,y+8);love.graphics.setColor(.35,.12,.10);love.graphics.rectangle("fill",x+w-26,y+5,20,20,3,3);love.graphics.setColor(1,1,1);love.graphics.printf("X",x+w-26,y+7,20,"center") end
function UI.new(inv,logger,skills,sprites,player,world,shop,crafting)
 return setmetatable({open={inventory=false,equipment=false,skills=false,bank=false,shop=false,smelter=false,anvil=false,woodcraft=false,loom=false,spinningWheel=false,alchemy=false,sewing=false,stove=false,leathercraft=false,campfire=false,spellbook=false,socketTable=false,enchantAltar=false,inscription=false,tailoring=false,mercenary=false,mercBand=false,bankClerk=false,mercSkills=false,ammoContainer=false},bagOpen={false,false,false,false},bagPos={{x=780,y=82},{x=470,y=82},{x=160,y=82},{x=780,y=390}},inv=inv,logger=logger,skills=skills,sprites=sprites,player=player,world=world,shop=shop,crafting=crafting,equipment={weapon=nil,head=nil,body=nil,legs=nil,cape=nil,offhand=nil,ammo=nil},equipmentItems={},equipmentSockets={weapon={},head={},body={},legs={},cape={},offhand={}},socketTarget=nil,enchantGem=nil,enchantPage=nil,spellPages={nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},equipmentContext=nil,shopContext=nil,bankContext=nil,mercContext=nil,dragSlot=nil,dragBagIndex=nil,context=nil,windowDrag=nil,hoverTooltip=nil,useTarget=nil,craftScroll={smelter=0,anvil=0,woodcraft=0,loom=0,spinningWheel=0,alchemy=0,sewing=0,stove=0,leathercraft=0,campfire=0,inscription=0,tailoring=0},skillsScroll=0,skillsTab="Combat",shopScroll=0,bankPage=1,bagnonMode=false,bagContext=nil,potionBelt={nil,nil,nil,nil},hudScale={bagBar=1,potionBelt=1},hudPos={bagBar=nil,potionBelt=nil,menuButtons=nil,magicHotbar=nil,weaponHotbar=nil,notifications=nil},hudDrag=nil,magicCast=nil,abilityHotbar={nil,nil,nil,nil},weaponHotbars={},abilityDrag=nil,weaponHotbarPress=nil,magicHotbarPress=nil,selectedMerc=1,zOrder={"equipment","skills","inventory","bank","shop","smelter","anvil","woodcraft","loom","spinningWheel","alchemy","sewing","stove","leathercraft","campfire","spellbook","socketTable","enchantAltar","inscription","tailoring","mercenary","mercBand","mercSkills","bankClerk"},pos={fieldcraft={x=100,y=90},inventory={x=780,y=82},equipment={x=24,y=82},skills={x=405,y=82},bank={x=365,y=330},shop={x=670,y=330},smelter={x=350,y=180},anvil={x=630,y=180},woodcraft={x=520,y=220},loom={x=560,y=180},spinningWheel={x=560,y=180},alchemy={x=600,y=210},sewing={x=540,y=220},stove={x=620,y=240},leathercraft={x=570,y=230},campfire={x=620,y=240},spellbook={x=520,y=180},socketTable={x=500,y=180},enchantAltar={x=540,y=210},inscription={x=575,y=245},tailoring={x=560,y=230},mercenary={x=520,y=210},mercBand={x=430,y=160},mercSkills={x=835,y=160},bankClerk={x=520,y=250},ammoContainer={x=1040,y=180}},levelToasts={},notificationsEnabled=true},UI)
end
function UI:log(e,d) if self.logger then self.logger:log(e,d) else require("game.audio").event(e,d) end end
function UI:bringToFront(name) for i=#self.zOrder,1,-1 do if self.zOrder[i]==name then table.remove(self.zOrder,i);break end end;self.zOrder[#self.zOrder+1]=name end
function UI:toggle(name,source) if name=="inventory" then local bi=self.inv.activeBag or 1;self.bagOpen[bi]=not self.bagOpen[bi];self.open.inventory=self.bagOpen[1] or self.bagOpen[2] or self.bagOpen[3] or self.bagOpen[4];self.context=nil;self:log("MENU_CHANGED",{menu="bag"..bi,state=self.bagOpen[bi] and "open" or "closed",source=source or "unknown"});return end;self.open[name]=not self.open[name];if self.open[name] then self:bringToFront(name) end;self.context=nil;self:log("MENU_CHANGED",{menu=name,state=self.open[name] and "open" or "closed",source=source or "unknown"}) end
function UI:openBank(source)
 self.open.bank=true;self:bringToFront("bank");self.context=nil
 for i=1,self.inv:bagSlotCount() do if self.inv.bagSlots[i] then self.bagOpen[i]=true end end
 self.open.inventory=true
 self:log("BANK_OPENED",{source=source or "chest",allBagsOpened="true"})
end
function UI:openCrafting(station,source) self.open[station]=true;self:bringToFront(station);self.context=nil;self:log("CRAFTING_OPENED",{station=station,source=source or "station"}) end
function UI:maxSockets() return require("game.sockets").limit(self.skills:get("Jewel Crafting").level) end
function UI:openSocketTable(source) self.open.socketTable=true;self:bringToFront("socketTable");self.socketTarget=nil;for i=1,self.inv:bagSlotCount() do if self.inv.bagSlots[i] then self.bagOpen[i]=true end end;self.open.inventory=true;self:log("SOCKET_TABLE_OPENED",{level=self.skills:get("Jewel Crafting").level,maxSockets=self:maxSockets(),source=source or "table"}) end
function UI:drawSocketTable()
 local x,y,w,h=self:rect('socketTable');box(x,y,w,h,'Jeweler - Permanent Sockets')
 local S=require('game.sockets');local lv=self.skills:get('Jewel Crafting').level
 love.graphics.setColor(.8,.76,.68);love.graphics.print('Jewel Crafting Lv '..lv..'   New item limit: '..self:maxSockets(),x+16,y+38)
 love.graphics.print(lv>=70 and 'Jewel extraction: GUARANTEED' or 'Extraction from jewel-bearing rocks can fail until level 70.',x+16,y+60)
 local obj=S.target(self);love.graphics.setColor(1,1,1)
 if obj then
  local total,broken,filled=S.summary(obj);love.graphics.print('Selected: '..obj.name,x+16,y+92)
  love.graphics.print(string.format('%d/%d created | %d filled | %d broken',total,obj.socketMax or self:maxSockets(),filled,broken),x+16,y+114)
  S.drawRow(self,obj,x+16,y+141,24)
 else love.graphics.print('Right-click bag equipment > Select Socket Item',x+16,y+92) end
 love.graphics.setColor(.15,.13,.08);love.graphics.rectangle('fill',x+16,y+183,190,30,4,4);love.graphics.setColor(1,.86,.48);love.graphics.print('Create Socket (Chisel)',x+25,y+192)
 love.graphics.setColor(.8,.76,.68);love.graphics.printf('Creating a position can permanently break it. Chance: '..string.format('%.1f%%',math.min(.98,.55+lv*.006)*100)..'. Broken positions count toward the item limit.',x+16,y+230,w-32,'left')
 love.graphics.printf('Right-click a Cut Gem > Socket Gem to fill the first open position. Insertion is guaranteed. Plain gems give no stats; enchanted gems provide their listed bonus.',x+16,y+273,w-32,'left')
end
function UI:openEnchantAltar(source) self.open.enchantAltar=true;self:bringToFront("enchantAltar");self.enchantGem=nil;self.enchantPage=nil;for i=1,self.inv:bagSlotCount() do if self.inv.bagSlots[i] then self.bagOpen[i]=true end end;self.open.inventory=true;self:log("ENCHANT_ALTAR_OPENED",{source=source or "altar"}) end
function UI:drawEnchantAltar() local x,y,w,h=self:rect("enchantAltar");box(x,y,w,h,"Enchanting Altar - Enchanting Lv "..self.skills:get("Enchanting").level);love.graphics.setColor(.82,.76,.68);love.graphics.print("1) Select Cut Gem   2) Select Spell/Skill Page",x+16,y+40);love.graphics.print("3) Right-click matching Gem Dust -> Enchant",x+16,y+62);love.graphics.setColor(1,1,1);love.graphics.print("Gem: "..(self.enchantGem and self.enchantGem.name or "none"),x+16,y+92);love.graphics.print("Page: "..(self.enchantPage and self.enchantPage.name or "none"),x+16,y+114);love.graphics.setColor(.72,.68,.60);love.graphics.printf("Dust limit: Onyx/Ruby 10 | Sapphire 20 | Emerald 30. Only that many dust are consumed. Each dust adds +0.1; effect caps remain 10/20/30. Spell pages add that spell's damage/effect; combat skill pages add effective Melee, Ranged, or Magic while socketed.",x+16,y+145,w-32,"left") end
function UI:enchantGemWithDust(dustQty)
 local ok,result=require('game.enchanting').enchant(self,dustQty)
 local message=ok and ('ENCHANTED +'..string.format('%.1f',result)) or ({no_selection='SELECT GEM + PAGE',stale_selection='SELECTION MOVED - SELECT AGAIN',not_enough_dust='NEED MATCHING GEM DUST',already_enchanted='GEM ALREADY ENCHANTED',unsupported_page='UNSUPPORTED PAGE',invalid_dust='INVALID DUST AMOUNT'})[result] or 'CANNOT ENCHANT'
 self.world:addPopup(self.player.x,self.player.y-22,message,ok and 'defeat' or 'miss');return ok,result
end
function UI:commandSlots() local lv=self.skills:get("Commanding").level;if lv>=10 then return 3 elseif lv>=5 then return 2 else return 1 end end
function UI:openMercenary(source) self.open.mercenary=true;self:bringToFront("mercenary");self.selectedMerc=math.max(1,math.min(self.selectedMerc or 1,#self.world.mercs));self:log("MERCENARY_RECRUITER_OPENED",{source=source or "recruiter"}) end
function UI:recruitMerc(role) local max=self:commandSlots();if #self.world.mercs>=max then self.world:addPopup(self.player.x,self.player.y-22,"COMMANDING LIMIT "..max,"miss");return false end;local n=#self.world.mercs+1;local gear={weapon=nil,offhand=nil,body=nil,head=nil,ammo=nil};self.world.mercs[#self.world.mercs+1]={name=role.." Mercenary "..n,role=role,x=self.player.x+18*n,y=self.player.y+18,hp=5,maxHp=5,equipment=gear,cooldown=0};require("game.party").initialize(self.world.mercs[#self.world.mercs]);require("game.party").recall(self.world,self.world.mercs[#self.world.mercs],self.player);self.selectedMerc=#self.world.mercs;local old,new,xp=self.skills:addXP("Commanding",5);self.world:addPopup(self.player.x,self.player.y-24,"RECRUITED "..string.upper(role),"defeat");self:log("MERCENARY_RECRUITED",{role=role,count=#self.world.mercs,commandingXp=xp});return true end
function UI:drawMercenary()
 local x,y,w,h=self:rect("mercenary");box(x,y,w,h,"Mercenary Recruiter - Commanding Lv "..self.skills:get("Commanding").level)
 love.graphics.setColor(.8,.76,.68);love.graphics.print("Band slots: "..#self.world.mercs.."/"..self:commandSlots().."   Lv5: 2 mercs   Lv10: 3 mercs",x+16,y+38)
 local roles={"Tank","Healer","Ranged"};for i,r in ipairs(roles) do local bx=x+16+(i-1)*118;love.graphics.setColor(.12,.10,.08,.95);love.graphics.rectangle("fill",bx,y+66,108,30,4,4);love.graphics.setColor(.65,.53,.34);love.graphics.rectangle("line",bx,y+66,108,30,4,4);love.graphics.setColor(1,1,1);love.graphics.printf("Recruit "..r,bx,y+73,108,"center") end
 love.graphics.setColor(.72,.68,.60);love.graphics.print("Your band",x+16,y+112)
 for i,m in ipairs(self.world.mercs) do local yy=y+132+(i-1)*46;love.graphics.setColor(i==self.selectedMerc and .22 or .08,.16,.10,.92);love.graphics.rectangle("fill",x+16,yy,w-32,40,4,4);love.graphics.setColor(1,1,1);love.graphics.print(i..". "..m.name.."   ["..m.role.."]",x+24,yy+5);local e=m.equipment or {};love.graphics.setColor(.72,.72,.68);love.graphics.printf((e.weapon or "No weapon").." | "..(e.body or "No body armor").." | "..(e.offhand or "No offhand"),x+24,yy+21,w-52,"left") end
 love.graphics.setColor(.68,.64,.58);love.graphics.printf("Select a merc here, then use the Mercenaries button on the HUD to manage equipment and stats.",x+16,y+h-55,w-32,"left")
end
function UI:drawMercSkills()
 local m=self.world.mercs[self.selectedMerc or 1];local x,y,w,h=self:rect("mercSkills");box(x,y,w,h,"Mercenary Skills")
 if not m then love.graphics.setColor(.75,.72,.65);love.graphics.print("No mercenary selected.",x+18,y+48);return end
 require("game.party").initialize(m)
 love.graphics.setColor(1,.9,.62);love.graphics.print(m.name,x+18,y+40);love.graphics.setColor(.78,.73,.65);love.graphics.print("Role: "..tostring(m.role or "Mercenary").."  Combat "..require("game.progression").combatLevel(m),x+18,y+62)
 local names={"Melee Combat","Ranged","Magic","Strength","Agility","Health"};local yy=y+94
 for _,name in ipairs(names) do local v=(m.combatSkills or {})[name] or {level=1,xp=0};love.graphics.setColor(1,1,1);love.graphics.print(name,x+18,yy);love.graphics.setColor(.95,.78,.42);love.graphics.printf("Lv "..tostring(v.level or 1),x+160,yy,62,"right");love.graphics.setColor(.66,.64,.60);love.graphics.printf(math.floor(v.xp or 0).." XP",x+232,yy,100,"right");yy=yy+34 end
 love.graphics.setColor(.62,.60,.56);love.graphics.printf("Mercenary combat skills gain XP while that mercenary fights and performs its role.",x+18,y+h-52,w-36,"left")
end
function UI:drawMercBand()
 local x,y,w,h=self:rect("mercBand");box(x,y,w,h,"Mercenary Band")
 if #self.world.mercs==0 then love.graphics.setColor(.75,.72,.65);love.graphics.printf("No mercenaries recruited. Visit the recruiter in the village center.",x+18,y+48,w-36,"left");return end
 self.selectedMerc=math.max(1,math.min(self.selectedMerc or 1,#self.world.mercs));local m=self.world.mercs[self.selectedMerc];m.equipment=m.equipment or {}
 love.graphics.setColor(.82,.76,.66);love.graphics.print("Commanding Lv "..self.skills:get("Commanding").level,x+18,y+38)
 for i,mm in ipairs(self.world.mercs) do local bx=x+18+(i-1)*112;love.graphics.setColor(i==self.selectedMerc and .22 or .10,.14,.09,.95);love.graphics.rectangle("fill",bx,y+62,104,28,4,4);love.graphics.setColor(.62,.50,.32);love.graphics.rectangle("line",bx,y+62,104,28,4,4);love.graphics.setColor(1,1,1);love.graphics.printf(tostring(i)..". "..mm.role,bx,y+69,104,"center") end
 love.graphics.setColor(1,1,1);love.graphics.print(m.name.."   ["..m.role.."]",x+18,y+108);love.graphics.setColor(.75,.72,.66);love.graphics.print("HP: "..math.floor(m.hp or 0).." / "..math.floor(m.maxHp or 10),x+18,y+132)
 local status=m.waitingInTown and string.format("Waiting in town %s: %d, %d",m.waitingRegionId or "",m.x,m.y) or ((m.hp or 0)<=0 and ("Defeated - respawn in "..math.ceil(m.recover or 20).."s") or "Following / assisting");love.graphics.printf(status,x+18,y+148,w-36,"left")
 local prog=require("game.progression");love.graphics.setColor(.85,.77,.45);love.graphics.print(string.format("Melee %d   Ranged %d   Magic %d",prog.level(m,"Melee Combat"),prog.level(m,"Ranged"),prog.level(m,"Magic")),x+18,y+420);love.graphics.print("Iron/reinforced gear: levels 20-30",x+18,y+440)
 local e=m.equipment
 local rows={{"HEAD","head"},{"BODY","body"},{"BOOTS","legs"},{"CAPE","cape"},{"WEAPON","weapon"},{"OFFHAND","offhand"},{"AMMO","ammo"}}
 for i,r in ipairs(rows) do local yy=y+164+(i-1)*42;love.graphics.setColor(.10,.09,.08,.95);love.graphics.rectangle("fill",x+18,yy,w-36,34,4,4);love.graphics.setColor(.50,.40,.27);love.graphics.rectangle("line",x+18,yy,w-36,34,4,4);love.graphics.setColor(.72,.68,.60);love.graphics.print(r[1],x+28,yy+9);love.graphics.setColor(1,1,1);local val=e[r[2]];local label=type(val)=="table" and (require('game.advanced_gear').isQuiver(val.name) and (val.arrowType and ((val.arrowType).." x"..tostring(val.qty or 0)) or "Quiver (Empty)") or (val.name.." x"..tostring(val.qty or 1))) or (val or "Empty");love.graphics.print(label,x+128,yy+9) end
 love.graphics.setColor(.68,.64,.58);love.graphics.printf("Right-click a merc tab to fire them. Right-click equipment rows to unequip. Right-click compatible bag gear and choose Give to Merc.",x+18,y+h-54,w-36,"left")
end
function UI:openShop(source,shop) if shop then self.shop=shop end;self.shopScroll=0;ShopTabs.select(self,"All");ShopTabs.fit(self);self.open.shop=true;self:bringToFront("shop");self.context=nil;self:log("SHOP_OPENED",{source=source or "shopkeeper"}) end
function UI:close(name,source) self.open[name]=false;self.context=nil;self:log("MENU_CHANGED",{menu=name,state="closed",source=source or "close_button"}) end
function UI:rect(name) local p=self.pos[name];if self.craftScroll[name]~=nil then return p.x,p.y,480,CookingTabs.is(name)and 384 or 352 end;if name=="inventory" then return p.x,p.y,286,300 elseif name=="equipment" then return p.x,p.y,290,562 elseif name=="skills" then return p.x,p.y,340,330 elseif name=="bank" then return p.x,p.y,270,565 elseif name=="alchemy" then return p.x,p.y,440,230 elseif name=="shop" then return p.x,p.y,270,320+ShopTabs.offset(self) elseif name=="spellbook" then return p.x,p.y,390,250 elseif name=="socketTable" then return p.x,p.y,500,350 elseif name=="enchantAltar" then return p.x,p.y,430,230 elseif name=="inscription" then return p.x,p.y,360,230 elseif name=="tailoring" then return p.x,p.y,360,230 elseif name=="mercenary" then return p.x,p.y,390,340 elseif name=="mercBand" then return p.x,p.y,430,528 elseif name=="mercSkills" then return p.x,p.y,360,350 elseif name=="bankClerk" then return p.x,p.y,330,190 elseif name=="smelter" or name=="anvil" or name=="woodcraft" or name=="loom" or name=="spinningWheel" or name=="sewing" or name=="stove" or name=="leathercraft" or name=="campfire" then return p.x,p.y,300,230 else return p.x,p.y,270,285 end end
function UI:ensureHudPos(w,h)
 if not self.hudPos.bagBar then self.hudPos.bagBar={x=w-190,y=h-72} end
 if not self.hudPos.potionBelt then self.hudPos.potionBelt={x=w-190,y=h-132} end
 if not self.hudPos.menuButtons then self.hudPos.menuButtons={x=math.max(0,w-736),y=h-72} end
 if not self.hudPos.magicHotbar then self.hudPos.magicHotbar={x=math.max(8,(w-326)/2),y=h-132} end
 if not self.hudPos.weaponHotbar then self.hudPos.weaponHotbar={x=math.max(8,(w-220)/2),y=h-190} end
 if not self.hudPos.notifications then self.hudPos.notifications={x=math.max(0,(w-360)/2),y=24} end
 local belt,bags=self.hudPos.potionBelt,self.hudPos.bagBar;if math.abs(belt.x-(bags.x-190))<1 and math.abs(belt.y-bags.y)<1 then belt.x=bags.x;belt.y=math.max(0,bags.y-60) end
end
function UI:rescaleLayout(oldW,oldH,newW,newH)
 if not oldW or not oldH or oldW<=0 or oldH<=0 then return end
 local sx,sy=newW/oldW,newH/oldH
 for _,p in pairs(self.hudPos) do if p then p.x=p.x*sx;p.y=p.y*sy end end
 for _,p in pairs(self.pos) do p.x=p.x*sx;p.y=p.y*sy end
 for _,p in ipairs(self.bagPos) do p.x=p.x*sx;p.y=p.y*sy end
end
function UI:bagBarRect(w,h) self:ensureHudPos(w,h);local p=self.hudPos.bagBar;local sc=self.hudScale.bagBar or 1;local width=(12+54*self.inv:bagSlotCount())*sc;p.x=math.max(0,math.min(p.x,w-width-4));p.y=math.max(0,math.min(p.y,h-54*sc-4));return p.x,p.y,width,54*sc end
function UI:bagSlotRect(i,w,h) local x,y=self:bagBarRect(w,h);local sc=self.hudScale.bagBar or 1;return x+8*sc+(i-1)*54*sc,y+6*sc,44*sc,42*sc end
function UI:potionBeltRect(w,h) self:ensureHudPos(w,h);local p=self.hudPos.potionBelt;local scale=self.hudScale.potionBelt or 1;return p.x,p.y,180*scale,54*scale end

function UI:magicHotbarRect(w,h) self:ensureHudPos(w,h);local p=self.hudPos.magicHotbar;return p.x,p.y,326,54 end
function UI:notificationRect(w,h) self:ensureHudPos(w,h);local p=self.hudPos.notifications;local count=math.min(2,#self.levelToasts)+math.min(3,#self.world.notifications);return p.x,p.y,360,math.max(46,count*52-6) end
function UI:magicHotbarSpell(slot) return self.spellPages[slot] end
function UI:castMagicSlot(slot) return require('game.magic_system').cast(self,slot) end
function UI:updateMagic(dt)
 require('game.magic_system').update(self,dt);require('game.abilities').update(self,dt)
 while #self.skills.pendingLevelUps>0 do local u=table.remove(self.skills.pendingLevelUps,1);self.levelToasts[#self.levelToasts+1]={skill=u.skill,level=u.level,t=0.5} end
 for i=#self.levelToasts,1,-1 do local n=self.levelToasts[i];n.t=(n.t or .5)-dt;if n.t<=0 then table.remove(self.levelToasts,i) end end
 for i=#self.world.notifications,1,-1 do local n=self.world.notifications[i];n.t=(n.t or 1.5)-dt;if n.t<=0 then table.remove(self.world.notifications,i) end end
end
function UI:magicCastCount() local n=0;for i=1,6 do if self.spellPages[i] then n=n+1 end end;return n end
function UI:weaponHotbarRect(w,h) self:ensureHudPos(w,h);local p=self.hudPos.weaponHotbar;return p.x,p.y,220,54 end
function UI:weaponHotbarSlotAt(mx,my,w,h) local x,y=self:weaponHotbarRect(w,h);for i=1,4 do local px=x+7+(i-1)*53;if inside(mx,my,px,y+6,46,42) then return i end end end
function UI:currentWeaponHotbar()
 local weapon=self.equipment.weapon;if not weapon or not require('game.abilities').hasWeapon(self) then return nil end
 local obj=require('game.items').equipped(self,'weapon');obj.hotbar=obj.hotbar or {};return obj.hotbar
end
function UI:castAbilitySlot(i) local bar=self:currentWeaponHotbar();local n=bar and bar[i];if not n then return false,"empty" end;if not require('game.abilities').isMeleeWeapon(self) then return false,'wrong_weapon' end;return require("game.abilities").cast(self,n) end
function UI:menuButtonsRect(w,h) self:ensureHudPos(w,h);local p=self.hudPos.menuButtons;return p.x,p.y,456,54 end
function UI:potionSlotRect(i,w,h) local x,y=self:potionBeltRect(w,h);local scale=self.hudScale.potionBelt or 1;return x+7+(i-1)*43*scale,y+6,38*scale,42*scale end
function UI:potionSlotAt(mx,my,w,h) for i=1,4 do local x,y,bw,bh=self:potionSlotRect(i,w,h);if inside(mx,my,x,y,bw,bh) then return i end end end
function UI:isPotion(name) local info=self.sprites.itemInfo[name];return info and info.type=="Potion" end
function UI:equipPotionFromBag(bi,slot,target) local b=self.inv:getBag(bi);local it=b and b.slots[slot];if not it or not self:isPotion(it.name) then return false,"not_potion" end;target=target or (function() for i=1,4 do if not self.potionBelt[i] then return i end end end)();if not target then return false,"belt_full" end;local old=self.potionBelt[target];self.potionBelt[target]=it.name;b.slots[slot]=old and {name=old,qty=1} or nil;self:log("POTION_BELT_EQUIPPED",{item=it.name,slot=target,replaced=old or "none"});return true,target end
function UI:usePotion(slot) local name=self.potionBelt[slot];if not name then return false,"empty" end;local used=false;local nextPotion=nil;if name=="Health Flask" then local before=self.player.hp;self.player.hp=math.min(self.player.maxHp,self.player.hp+40);used=self.player.hp>before elseif name=="Health Tube" then local before=self.player.hp;self.player.hp=math.min(self.player.maxHp,self.player.hp+20);used=self.player.hp>before elseif name=="Antipoison Flask" then self.player.poisonedTimer=0;self.player.poisonTick=0;self.player.poisonImmuneTimer=3;used=true elseif name=="Antipoison Tube" then self.player.poisonedTimer=0;self.player.poisonTick=0;used=true elseif name=="Stamina Potion (3/3)" or name=="Stamina Potion (2/3)" or name=="Stamina Potion (1/3)" then self.player.stamina=math.min(self.player.maxStamina,self.player.stamina+30);self.player.secondWind=math.max(self.player.secondWind or 0,10);used=true;if name=="Stamina Potion (3/3)" then nextPotion="Stamina Potion (2/3)" elseif name=="Stamina Potion (2/3)" then nextPotion="Stamina Potion (1/3)" end end;if used then self.potionBelt[slot]=nextPotion;self:log("POTION_USED",{item=name,slot=slot,hp=self.player.hp,stamina=self.player.stamina,staminaRegenSeconds=string.format("%.2f",self.player.secondWind or 0),remaining=nextPotion or "empty"});return true,name end;self:log("POTION_USE_BLOCKED",{item=name,slot=slot,reason="no_effect_needed"});return false,"no_effect_needed" end
function UI:bagWindowRect(bi) local p=self.bagPos[bi];local b=self.inv:getBag(bi);return p.x,p.y,286,math.max(300,146+math.ceil((b and b.size or 10)/5)*43) end
function UI:itemGridOrigin(bi) local x,y=self:bagWindowRect(bi or self.inv.activeBag);return x+39,y+132 end
function UI:slotAt(mx,my,bi) local bag=self.inv:getBag(bi);if not bag then return nil end;local sx,sy=self:itemGridOrigin(bi);for row=0,math.ceil(bag.size/5)-1 do for col=0,4 do local i=row*5+col+1;if i<=bag.size then local x,y=sx+col*43,sy+row*43;if inside(mx,my,x,y,38,38) then return i end end end end end
function UI:bankSlotAt(mx,my) local x,y=self:rect("bank");local sx,sy=x+20,y+72;local page=math.max(1,math.min(self.bankPage or 1,math.ceil((self.inv.bankSize or 25)/50)));local first=(page-1)*50+1;local last=math.min(first+49,self.inv.bankSize or 25);for i=first,last do local localIndex=i-first;local row=math.floor(localIndex/5);local col=localIndex%5;if inside(mx,my,sx+col*47,sy+row*43,38,38) then return i end end end
function UI:bagSlotAt(mx,my,w,h) for i=1,self.inv:bagSlotCount() do local x,y,bw,bh=self:bagSlotRect(i,w,h);if inside(mx,my,x,y,bw,bh) then return i end end end
function UI:drawBagIcon(bag,x,y,scale)
 if bag then self:drawItemSprite({name=bag.name,qty=1,qualityGrade=bag.qualityGrade},x,y,16*scale)end
end
function UI:drawItemSprite(it,x,y,size,bank) local img=self.sprites.itemImages[it.name];if img then
 local function drawIcon(ox,oy)
  ox,oy=ox or 0,oy or 0
  if require('game.advanced_gear').isQuiver(it.name) and self.sprites.quiverQuads then local quad=(it.arrowType and (it.qty or 0)>0) and (it.name=='Cave Snake Quiver'and self.sprites.caveSnakeQuiverQuads or self.sprites.quiverQuads).copper or(it.name=='Cave Snake Quiver'and self.sprites.caveSnakeQuiverQuads or self.sprites.quiverQuads).empty;local sc=(size-4)/16;love.graphics.draw(img,quad,x+size/2+ox,y+size/2+oy,0,sc,sc,8,8) elseif self.sprites.itemQuads and self.sprites.itemQuads[it.name] then local quad=self.sprites.itemQuads[it.name];local _,_,iw,ih=quad:getViewport();local sc=(require('game.shellfish').levels[it.name]or it.name=='Cover Tent')and 1 or math.min((size-4)/iw,(size-4)/ih);love.graphics.draw(img,quad,x+size/2+ox,y+size/2+oy,0,sc,sc,iw/2,ih/2) elseif it.name=="Fishing Pole" and self.sprites.fishingPoleQuads then local sc=(size-4)/16;love.graphics.draw(img,self.sprites.fishingPoleQuads.rest,x+size/2+ox,y+size/2+oy,0,sc,sc,8,8) else local cq=self.sprites.coinQuads and self.sprites.coinQuads[it.name];if cq then local quad=(bank and (it.qty or 1)>10000) and cq.pile or cq.single;local sc=(size-4)/16;love.graphics.draw(img,quad,x+size/2+ox,y+size/2+oy,0,sc,sc,8,8) else local iw,ih=img:getDimensions();local sc=(require('game.shellfish').levels[it.name]or it.name=='Cover Tent')and 1 or math.min((size-4)/iw,(size-4)/ih);love.graphics.draw(img,x+size/2+ox,y+size/2+oy,0,sc,sc,iw/2,ih/2) end end
 end
 if it.blessed then
  if not self._blessOutlineShader then self._blessOutlineShader=love.graphics.newShader([[vec4 effect(vec4 color, Image texture, vec2 tc, vec2 sc){vec4 px=Texel(texture,tc);if(px.a<0.05)return vec4(0.0);return vec4(1.0,0.84,0.08,px.a)*color.a;}]]) end
  love.graphics.setShader(self._blessOutlineShader);love.graphics.setColor(1,1,1,1)
  for _,o in ipairs({{-2,0},{2,0},{0,-2},{0,2},{-1,-1},{1,-1},{-1,1},{1,1}}) do drawIcon(o[1],o[2]) end
  love.graphics.setShader()
 end
 if it.name=="Onyx Dust" then love.graphics.setColor(.45,.50,.62) else love.graphics.setColor(1,1,1) end;drawIcon();love.graphics.setColor(1,1,1)
if require('game.advanced_gear').isQuiver(it.name) then if it.arrowType and (it.qty or 0)>0 then love.graphics.setColor(1,1,1);love.graphics.printf(tostring(it.qty),x+2,y+size-15,size-5,"right") end elseif (it.qty or 1)>1 then love.graphics.setColor(1,1,1);love.graphics.printf(tostring(it.qty),x+2,y+size-15,size-5,"right") end end
end
function UI:priceText(c)
 c=math.max(0,math.floor(c or 0));local g=math.floor(c/10000);local s=math.floor((c%10000)/100);local cp=c%100
 local t={};if g>0 then t[#t+1]=g.."g" end;if s>0 then t[#t+1]=s.."s" end;if cp>0 or #t==0 then t[#t+1]=cp.."c" end;return table.concat(t," ")
end
function UI:drawTooltip(it,mx,my,w,h,overrideInfo)
 if overrideInfo and not self.inv:isBagItem(it.name)and self.sprites.itemInfo[it.name] then local base=self.sprites.itemInfo[it.name];local copy={};for k,v in pairs(overrideInfo) do copy[k]=v end;copy.detail=(base.detail or "").."\n"..(copy.detail or "");overrideInfo=copy end
 local info=overrideInfo or self.sprites.itemInfo[it.name] or {title=it.name,type="Item",detail=""};if not overrideInfo and require('game.advanced_gear').isQuiver(it.name) then local loaded=(it.arrowType and (it.qty or 0)>0) and (tostring(it.qty).."x "..it.arrowType) or "Empty";info={title=it.name,type="Ammo",detail=(info.detail or "").." Loaded: "..loaded..". Holds unlimited arrows of one type."} end;if it.enchantValue then info={title=it.enchantName or info.title,type="Enchanted "..(info.type or "Gem"),detail=(info.detail or "").."\nEnchant: "..(it.enchantSpell or it.enchantSkill or "Unknown").." +"..string.format("%.1f",it.enchantValue).." ("..tostring(it.enchantDust or 0).." dust)"} end;if it.sockets then local copy={};for k,v in pairs(info) do copy[k]=v end;copy.detail=(info.detail or '')..require('game.sockets').detail(it);info=copy end
 if self.inv:isCurrency(it.name) and not overrideInfo then info={title=it.name,type="Currency",detail=self.inv:moneyText()}
 elseif not overrideInfo then local bits={info.detail or ""};if info.damage then bits[#bits+1]="Damage: "..info.damage.."   Speed: "..string.format("%.2fs",info.attackSpeed or 1) end;if info.defence then bits[#bits+1]="Defence: "..info.defence end;info={title=info.title,type=info.type,detail=table.concat(bits,"  ")} end
 local skillHint=nil;local typ=tostring(info.type or "");if typ:find("Fish") or it.name:find("Fish",1,true) or it.name:find("Chicken",1,true) or it.name:find("Meat",1,true) then skillHint="Cooking" elseif typ:find("Potion") or typ:find("Alchemy") then skillHint="Alchemy" elseif typ:find("Leather") or it.name:find("Hide",1,true) then skillHint="Leatherworking" elseif typ:find("Ore") or it.name:find("Copper Chunk",1,true) then skillHint="Mining" elseif it.name:find("Log",1,true) then skillHint="Woodcutting" end;if skillHint then info={title=info.title,type=info.type,detail=(info.detail or "").."\n"..skillHint.." level: "..self.skills:get(skillHint).level} end
 info=require("game.help").enrich(self,it,info)
 if require("game.help").skills[it.name] then info.detail=(info.detail or "").."\n"..require("game.help").skills[it.name] end
 local font=love.graphics.getFont();local tw=math.min(330,math.max(220,w-16));local textW=tw-18
 local _,detailLines=font:getWrap(info.detail or "",textW);local th=56+math.max(1,#detailLines)*font:getHeight()
 local x,y=mx+14,my+14;if x+tw>w then x=mx-tw-14 end;if y+th>h then y=my-th-14 end;x=math.max(4,math.min(x,w-tw-4));y=math.max(4,math.min(y,h-th-4))
 love.graphics.setColor(.035,.032,.025,.98);love.graphics.rectangle("fill",x,y,tw,th,5,5);love.graphics.setColor(.72,.62,.40);love.graphics.rectangle("line",x,y,tw,th,5,5);love.graphics.setColor(1,.9,.62);love.graphics.print(info.title,x+9,y+7);love.graphics.setColor(.78,.78,.74);love.graphics.print(info.type,x+9,y+27);love.graphics.setColor(1,1,1);love.graphics.printf(info.detail or "",x+9,y+48,textW,"left")
end
function UI:drawSpellbook()
 local x,y,w,h=self:rect("spellbook");box(x,y,w,h,"Magic Altar - Spellbook")
 love.graphics.setColor(.82,.76,.68);love.graphics.print("Right-click a Spell Page in your bag -> Add to Spellbook",x+16,y+40)
 love.graphics.print("Click an installed page below to remove it.",x+16,y+62)
 for i=1,6 do local px=x+18+(i-1)*58;local py=y+98;love.graphics.setColor(.08,.07,.06,.95);love.graphics.rectangle("fill",px,py,48,48,5,5);love.graphics.setColor(.72,.62,.40);love.graphics.rectangle("line",px,py,48,48,5,5);local name=self.spellPages[i];if name then self:drawItemSprite({name=name,qty=1},px+5,py+5,38) end;love.graphics.setColor(.8,.76,.65);love.graphics.printf(tostring(i),px,py+52,48,"center") end
 love.graphics.setColor(.72,.68,.60);love.graphics.printf("Installed pages are physical spellbook contents, not permanent learned spells. Equip a Spellbook offhand to show the spell hotbar.",x+16,y+176,w-32,"left")
end
function UI:drawMagicHotbar(w,h)
 if self.equipment.offhand~="Spellbook" then return end
 local x,y,bw,bh=self:magicHotbarRect(w,h);love.graphics.setColor(.05,.05,.04,.92);love.graphics.rectangle("fill",x,y,bw,bh,7,7)
 for i=1,6 do local px=x+7+(i-1)*53;local py=y+6;love.graphics.setColor(.12,.11,.09,.96);love.graphics.rectangle("fill",px,py,46,42,6,6);love.graphics.setColor(.55,.42,.24);love.graphics.rectangle("line",px,py,46,42,6,6);local name=self.spellPages[i];if name then self:drawItemSprite({name=name,qty=1},px+6,py+3,36) end;love.graphics.setColor(.8,.76,.65);love.graphics.print(tostring(i),px+3,py+2) end
end
function UI:drawWeaponHotbar(w,h)
 if not require('game.abilities').hasWeapon(self) then return end
 local bar=self:currentWeaponHotbar();local x,y,bw,bh=self:weaponHotbarRect(w,h);love.graphics.setColor(.05,.05,.04,.92);love.graphics.rectangle('fill',x,y,bw,bh,7,7)
 self._abilityImages=self._abilityImages or {}
 for i=1,4 do local px=x+7+(i-1)*53;love.graphics.setColor(.12,.11,.09,.96);love.graphics.rectangle('fill',px,y+6,46,42,6,6);love.graphics.setColor(.62,.48,.26);love.graphics.rectangle('line',px,y+6,46,42,6,6);local n=bar and bar[i];if n then local a=require('game.abilities').byName(n);if a then local img=self._abilityImages[n];if not img then img=love.graphics.newImage(a.asset);img:setFilter('nearest','nearest');self._abilityImages[n]=img end;local iw,ih=img:getDimensions();local q=RenderCache.quad(0,0,a.fw,a.fh,iw,ih);love.graphics.setColor(1,1,1);love.graphics.draw(img,q,px+23,y+27,0,math.min(2,34/a.fw),math.min(2,34/a.fh),a.fw/2,a.fh/2);local cd=(self.player.abilityCooldowns and self.player.abilityCooldowns[n]) or 0;if cd>0 then love.graphics.setColor(0,0,0,.6);love.graphics.rectangle('fill',px,y+6,46,42);love.graphics.setColor(1,1,1);love.graphics.printf(string.format('%.0f',cd),px,y+19,46,'center') end end end;love.graphics.setColor(.8,.76,.65);love.graphics.print(tostring(i),px+3,y+8) end
end

function UI:draw(w,h) require("game.options_menu").ui=self;
 self.hoverTooltip=nil
 love.graphics.setColor(1,1,1);love.graphics.print(require("game.logger").VERSION,12,10)
 local pbx,pby,pbw,pbh=self:potionBeltRect(w,h);love.graphics.setColor(.05,.05,.04,.92);love.graphics.rectangle("fill",pbx,pby,pbw,pbh,7,7);for i=1,4 do local x,y,sw,sh=self:potionSlotRect(i,w,h);love.graphics.setColor(.12,.11,.09,.96);love.graphics.rectangle("fill",x,y,sw,sh,7,7);love.graphics.setColor(.55,.42,.24);love.graphics.rectangle("line",x,y,sw,sh,7,7);local pn=self.potionBelt[i];if pn then self:drawItemSprite({name=pn,qty=1},x+(sw-math.min(sw,sh))/2,y+(sh-math.min(sw,sh))/2,math.min(sw,sh)) end;love.graphics.setColor(.8,.76,.65);love.graphics.print("F"..tostring(i),x+3,y+2) end
 local bx,by,bw,bh=self:bagBarRect(w,h);love.graphics.setColor(.05,.05,.04,.92);love.graphics.rectangle("fill",bx,by,bw,bh,7,7);for i=1,self.inv:bagSlotCount() do local x,y,sw,sh=self:bagSlotRect(i,w,h);love.graphics.setColor(.12,.11,.09,.96);love.graphics.rectangle("fill",x,y,sw,sh,8,8);love.graphics.setColor(i==self.inv.activeBag and .95 or .48,i==self.inv.activeBag and .78 or .39,.28);love.graphics.rectangle("line",x,y,sw,sh,8,8);local bag=self.inv.bagSlots[i];if bag then self:drawBagIcon(bag,x+6*(self.hudScale.bagBar or 1),y+5*(self.hudScale.bagBar or 1),2*(self.hudScale.bagBar or 1));local mx,my=love.mouse.getPosition();if inside(mx,my,x,y,sw,sh)then self.hoverTooltip={item={name=bag.name,qty=1,qualityGrade=bag.qualityGrade},info=nil}end else love.graphics.setColor(.55,.5,.4);love.graphics.printf("BAG",x,y+15,sw,"center") end end
 self:drawMagicHotbar(w,h)
 self:drawWeaponHotbar(w,h)
 local mbx,mby,mbw,mbh=self:menuButtonsRect(w,h);love.graphics.setColor(.05,.05,.04,.92);love.graphics.rectangle("fill",mbx,mby,mbw,mbh,7,7);for i,t in ipairs({{"Equipment","equipment"},{"Skills","skills"},{"Mercenaries","mercBand"}}) do local x=mbx+8+(i-1)*110;local y=mby+12;love.graphics.setColor(self.open[t[2]] and 1 or .75,self.open[t[2]] and .82 or .66,.45);love.graphics.rectangle("line",x,y,102,30,4,4);love.graphics.setColor(1,1,1);love.graphics.printf(t[1],x,y+7,102,"center") end;local nx=mbx+338;love.graphics.setColor(self.notificationsEnabled and .75 or .38,self.notificationsEnabled and .66 or .38,.45);love.graphics.rectangle("line",nx,mby+12,102,30,4,4);love.graphics.setColor(1,1,1);love.graphics.printf(self.notificationsEnabled and "Notices ON" or "Notices OFF",nx,mby+19,102,"center")

 for _,name in ipairs(self.zOrder) do if self.open[name] then local _mx,_my=love.mouse.getPosition();local _x,_y,_ww,_hh=self:rect(name);if inside(_mx,_my,_x,_y,_ww,_hh) then self.hoverTooltip=nil end;if name=="fieldcraft" then require("game.fieldcraft_ui").draw(self,w,h)elseif name=="equipment" then self:drawEquipment() elseif name=="skills" then self:drawSkills() elseif name=="inventory" then elseif name=="bank" then self:drawBank(w,h) elseif name=="shop" then self:drawShop(w,h) elseif name=="socketTable" then self:drawSocketTable() elseif name=="enchantAltar" then self:drawEnchantAltar() elseif name=="mercenary" then self:drawMercenary() elseif name=="mercBand" then self:drawMercBand() elseif name=="mercSkills" then self:drawMercSkills() elseif name=="bankClerk" then self:drawBankClerk() elseif name=="spellbook" then self:drawSpellbook() elseif name=="smelter" or name=="anvil" or name=="woodcraft" or name=="loom" or name=="spinningWheel" or name=="alchemy" or name=="sewing" or name=="stove" or name=="leathercraft" or name=="campfire" or name=="inscription" or name=="tailoring" then self:drawCrafting(name,w,h) end end end
 if self.bagnonMode then local any=false;for i=1,self.inv:bagSlotCount() do if self.bagOpen[i] then any=true end end;if any then self:drawCombinedInventory(w,h) end else for bi=1,4 do if self.bagOpen[bi] and self.inv.bagSlots[bi] then self:drawInventory(w,h,bi) end end end
 if self.open.ammoContainer then self:drawAmmoContainer() end
 if self.context then self:drawContext(w,h) end;if self.bankContext then self:drawBankContext(w,h) end;if self.shopContext then self:drawShopContext(w,h) end;if self.equipmentContext then self:drawEquipmentContext(w,h) end;if self.mercContext then self:drawMercContext(w,h) end;if self.bagContext then local c=self.bagContext;local x,y=c.x,c.y;if x+190>w then x=w-194 end;if y+55>h then y=h-59 end;c.drawX,c.drawY=x,y;love.graphics.setColor(.035,.032,.025,.99);love.graphics.rectangle("fill",x,y,190,55,4,4);love.graphics.setColor(.72,.62,.40);love.graphics.rectangle("line",x,y,190,55,4,4);love.graphics.setColor(1,1,1);love.graphics.print("Unequip Bag",x+10,y+12);love.graphics.print("Cancel",x+10,y+39) end
 if self.useTarget then local mx,my=love.mouse.getPosition();love.graphics.setColor(1,.9,.62);love.graphics.print("Use "..self.useTarget.tool.." -> click "..(self.useTarget.tool=="Needle" and "Leather / Dyed Blue Cloth Strip" or (self.useTarget.tool=="Blue Dye" and "Cloth Strip" or (self.useTarget.tool=="Copper Dagger" and "Logs / Fish" or (self.useTarget.tool=="Flint and Steel" and "Logs" or (self.useTarget.tool=="Copper Arrowheads" and "Arrow Shafts" or (self.useTarget.tool=="Bow String" and "Unstrung Bow" or (self.useTarget.tool=="Chisel" and "Jewel-bearing Rock / Rough Jewel / Cut Onyx" or "valid item"))))))),mx+16,my-18) end
 if self.abilityDrag then local mx,my=love.mouse.getPosition();local a=require("game.abilities").byName(self.abilityDrag.name);if a then self._abilityImages=self._abilityImages or {};local img=self._abilityImages[a.name];if not img then img=love.graphics.newImage(a.asset);img:setFilter("nearest","nearest");self._abilityImages[a.name]=img end;local iw,ih=img:getDimensions();local q=RenderCache.quad(0,0,a.fw,a.fh,iw,ih);love.graphics.setColor(1,1,1);love.graphics.draw(img,q,mx+12,my+12,0,2,2,a.fw/2,a.fh/2) end end
 if self.magicPageDrag then local mx,my=love.mouse.getPosition();self:drawItemSprite({name=self.magicPageDrag.page,qty=1},mx+8,my+8,36) end
 if self.dragSlot then local b=self.inv:getBag(self.dragBagIndex);local it=b and b.slots[self.dragSlot];if it then local mx,my=love.mouse.getPosition();self:drawItemSprite(it,mx+8,my+8,32) end end
 self:ensureHudPos(w,h);local np=self.hudPos.notifications
 if self.notificationsEnabled then
 for i,t in ipairs(self.levelToasts) do if i>2 then break end;local tw,th=300,46;local tx=np.x+30;local ty=np.y+(i-1)*52;love.graphics.setColor(.035,.032,.025,.96);love.graphics.rectangle("fill",tx,ty,tw,th,6,6);love.graphics.setColor(1,.78,.28);love.graphics.rectangle("line",tx,ty,tw,th,6,6);love.graphics.setColor(1,.9,.62);love.graphics.printf("LEVEL UP!  "..t.skill.."  Lv "..t.level,tx,ty+14,tw,"center") end
 for i,t in ipairs(self.world.notifications) do if i>3 then break end;local tw,th=360,46;local tx=np.x;local ty=np.y+(math.min(2,#self.levelToasts)+i-1)*52;love.graphics.setColor(.035,.032,.025,.97);love.graphics.rectangle("fill",tx,ty,tw,th,6,6);love.graphics.setColor(.92,.32,.22);love.graphics.rectangle("line",tx,ty,tw,th,6,6);love.graphics.setColor(1,.82,.62);love.graphics.printf(t.text,tx,ty+14,tw,"center") end
 end
 -- Tooltip rendering is last in main.lua so maps and HUD cannot cover it.
end
function UI:drawBankClerk() local x,y,w,h=self:rect("bankClerk");box(x,y,w,h,"Bank Clerk");local money=self.inv:moneyCopper();local cap=self.inv.bankSize or 25;local cost=self.inv:bankUpgradeCost();love.graphics.setColor(.82,.76,.66);love.graphics.print("Coins carried across all bags:",x+18,y+42);love.graphics.setColor(1,.9,.62);love.graphics.print(self.inv:moneyText(money),x+18,y+66);love.graphics.setColor(.75,.72,.65);love.graphics.print("Bank capacity: "..tostring(cap).." slots",x+18,y+94);love.graphics.setColor(.12,.11,.09,.96);love.graphics.rectangle("fill",x+18,y+126,w-36,34,5,5);love.graphics.setColor(.72,.62,.40);love.graphics.rectangle("line",x+18,y+126,w-36,34,5,5);love.graphics.setColor(1,1,1);love.graphics.printf(cap<250 and ("Buy +25 Bank Slots - "..self.inv:moneyText(cost)) or "Bank Capacity Maximum",x+18,y+136,w-36,"center") end
function UI:drawSkills()
 local x,y=self:rect("skills");box(x,y,340,330,"Skills - Combat "..require("game.progression").combatLevel(self.skills))
 local tabs={"Combat","Gathering","Production","Other"};local groups={Combat={"Melee Combat","Strength","Agility","Ranged","Magic","Health","Commanding"},Gathering={"Mining","Woodcutting","Fishing","Skinning","Religion"},Production={"Woodworking","Smithing","Leatherworking","Fletching","Alchemy","Jewel Crafting","Cooking","Enchanting","Inscription","Tailoring"},Other={"Firemaking","Prospecting","Love Making","Fieldcraft","Survival","Foraging"}}
 for i,t in ipairs(tabs) do local bx=x+12+(i-1)*80;love.graphics.setColor(self.skillsTab==t and .28 or .10,.10,.08,.96);love.graphics.rectangle("fill",bx,y+34,74,26,4,4);love.graphics.setColor(.62,.50,.32);love.graphics.rectangle("line",bx,y+34,74,26,4,4);love.graphics.setColor(1,1,1);love.graphics.printf(t,bx,y+41,74,"center") end
 local list=groups[self.skillsTab] or groups.Combat;self.skillsScroll=math.min(self.skillsScroll,math.max(0,#list-7)*34);local sx,sy=x+16,y+70;local mx,my=love.mouse.getPosition()
 for i,n in ipairs(list) do local py=sy+(i-1)*34-self.skillsScroll;if py>=sy and py+30<=y+318 then love.graphics.setColor(.08,.07,.06,.94);love.graphics.rectangle("fill",sx,py,304,30,4,4);love.graphics.setColor(.48,.39,.28);love.graphics.rectangle("line",sx,py,304,30,4,4);local sk=self.skills:get(n);love.graphics.setColor(1,1,1);love.graphics.print(n..(n=="Health" and string.format(" %g/%g",self.player.hp,self.player.maxHp) or n=="Agility" and string.format(" %.0f/%g SP",self.player.stamina,self.player.maxStamina) or ""),sx+10,py+7);love.graphics.setColor(1,.9,.62);love.graphics.printf("Lv "..sk.level,sx+220,py+7,72,"right");if inside(mx,my,sx,py,304,30) then local nextXP=sk.level>=99 and sk.xp or self.skills.xpTable[sk.level+1];local into=sk.level>=99 and 0 or (sk.xp-self.skills.xpTable[sk.level]);local need=sk.level>=99 and 0 or (nextXP-self.skills.xpTable[sk.level]);self.hoverTooltip={item={name=n,qty=1},info={title=n.."  Lv "..sk.level,type="Skill - XP x"..tostring(self.skills:xpMultiplier(n)),detail=(sk.level>=99 and ("MAX LEVEL   Total XP: "..sk.xp) or ("XP: "..into.." / "..need.."   XP to next: "..(need-into).."\nTotal XP: "..sk.xp))}} end end end
end
function UI:equipmentSlotAt(mx,my)
 local x,y=self:rect("equipment");for i,n in ipairs({"head","body","legs","cape","weapon","offhand","ammo","tool"}) do local sy=y+40+(i-1)*48;if inside(mx,my,x+18,sy,38,38) then return n end end
end
function UI:drawEquipment()
 local x,y,w,h=self:rect("equipment");box(x,y,w,h,"Equipment");local mx,my=love.mouse.getPosition()
 for i,n in ipairs({"head","body","legs","cape","weapon","offhand","ammo","tool"}) do
  local sy=y+40+(i-1)*48;love.graphics.setColor(.12,.11,.09,.96);love.graphics.rectangle("fill",x+18,sy,38,38,4,4);love.graphics.setColor(.48,.39,.28);love.graphics.rectangle("line",x+18,sy,38,38,4,4);love.graphics.setColor(.75,.72,.65);love.graphics.print(n=="legs" and "BOOTS" or n:upper(),x+68,sy+4)
  local it=self.equipment[n];if it then local obj=require("game.items").equipped(self,n);self:drawItemSprite(obj,x+18,sy,38);require("game.sockets").drawRow(self,obj,x+68,sy+23,18);if inside(mx,my,x+18,sy,38,38) then self.hoverTooltip={item=obj,info=nil} end end
 end
 local bonus=Combat.enchantBonuses(self.equipmentSockets);for k,v in pairs(Combat.gearBonuses(self.equipment)) do bonus[k]=(bonus[k] or 0)+v end
 local melee=self.skills:get("Melee Combat").level+bonus.melee
 local ranged=self.skills:get("Ranged").level+bonus.ranged
 local magic=self.skills:get("Magic").level+bonus.magic
 local strength=self.skills:get("Strength").level
 local info=require('game.quality').info(self.sprites.itemInfo[self.equipment.weapon],require('game.quality').object(self.equipment,'weapon'))
 local damage=Combat.maxDamage(info,strength)+bonus.damage
 love.graphics.setColor(.82,.76,.66);love.graphics.print("COMBAT STATS",x+18,y+428)
 love.graphics.setColor(1,1,1)
 love.graphics.print(string.format("Melee: %g   Ranged: %g",melee,ranged),x+18,y+447)
 love.graphics.print(string.format("Magic: %g   Strength: %g",magic,strength),x+18,y+467)
 love.graphics.print(string.format("Max hit: %g   Defense: %g",damage,Combat.defense(self.equipment)),x+18,y+487)
 love.graphics.print(string.format("Health: %g / %g",self.player.hp,self.player.maxHp),x+18,y+511)
 love.graphics.print(string.format("Stamina: %.1f / %g",self.player.stamina,self.player.maxStamina),x+18,y+531)
end
function UI:combinedRect() local p=self.pos.inventory;local total=0;for i=1,self.inv:bagSlotCount() do local b=self.inv.bagSlots[i];if b then total=total+b.size end end;local rows=math.max(1,math.ceil(total/8));return p.x,p.y,370,104+rows*43 end
function UI:combinedSlotAt(mx,my) local x,y=self:combinedRect();local sx,sy=x+14,y+88;local flat=0;for bi=1,4 do local b=self.inv.bagSlots[bi];if b then for si=1,b.size do flat=flat+1;local col=(flat-1)%8;local row=math.floor((flat-1)/8);if inside(mx,my,sx+col*43,sy+row*43,38,38) then return bi,si end end end end end
function UI:drawCombinedInventory(w,h) local x,y,cw,ch=self:combinedRect();local total,used=0,0;for bi=1,4 do local b=self.inv.bagSlots[bi];if b then total=total+b.size;used=used+self.inv:usedSlots(bi) end end;box(x,y,cw,ch,"Inventory   "..used.."/"..total);require("game.tool_slot_ui").drawButton(self,"inventory");local sx,sy=x+14,y+88;local flat=0;local mx,my=love.mouse.getPosition();for bi=1,4 do local b=self.inv.bagSlots[bi];if b then for si=1,b.size do flat=flat+1;local col=(flat-1)%8;local row=math.floor((flat-1)/8);local px,py=sx+col*43,sy+row*43;love.graphics.setColor(.08,.07,.06,.90);love.graphics.rectangle("fill",px,py,38,38,4,4);love.graphics.setColor(.48,.39,.28);love.graphics.rectangle("line",px,py,38,38,4,4);if self:isSelectedUseSlot(bi,si) then love.graphics.setLineWidth(3);love.graphics.setColor(1,.85,.12,1);love.graphics.rectangle("line",px-2,py-2,42,42,5,5);love.graphics.setLineWidth(1) end;local it=b.slots[si];if it then self:drawItemSprite(it,px,py,38);if inside(mx,my,px,py,38,38) then self.hoverTooltip={item=it,info=nil} end end end end end end
function UI:drawInventory(w,h,bi) local bag=self.inv:getBag(bi);if not bag then return end;local x,y,bw,bh=self:bagWindowRect(bi);box(x,y,bw,bh,bag.name.."   "..self.inv:usedSlots(bi).."/"..bag.size);love.graphics.setColor(1,1,1);self:drawBagIcon(bag,x+15,y+34,4);require("game.tool_slot_ui").drawButton(self,"bag"..bi);local sx,sy=self:itemGridOrigin(bi);local mx,my=love.mouse.getPosition();for r=0,math.ceil(bag.size/5)-1 do for c=0,4 do local i=r*5+c+1;if i<=bag.size then local px,py=sx+c*43,sy+r*43;love.graphics.setColor(.08,.07,.06,.78);love.graphics.rectangle("fill",px,py,38,38,4,4);love.graphics.setColor(.48,.39,.28);love.graphics.rectangle("line",px,py,38,38,4,4);if self:isSelectedUseSlot(bi,i) then love.graphics.setLineWidth(3);love.graphics.setColor(1,.85,.12,1);love.graphics.rectangle("line",px-2,py-2,42,42,5,5);love.graphics.setLineWidth(1) end;local it=bag.slots[i];if it then self:drawItemSprite(it,px,py,38);if inside(mx,my,px,py,38,38) then local info=nil;if self.open.shop and (not self.shop.tradeOnly or self.shop.traderOnly) and not self.inv:isCurrency(it.name) then local base=self.sprites.itemInfo[it.name] or {title=it.name,type="Item",detail=""};info={title=base.title,type=base.type,detail="Sell to shop: "..self:priceText(self.shop:sellPrice(it.name))} end;self.hoverTooltip={item=it,info=info} end end end end end end
function UI:drawBank(w,h)
 local x,y=self:rect("bank");local cap=self.inv.bankSize or 25;local pages=math.max(1,math.ceil(cap/50));self.bankPage=math.max(1,math.min(self.bankPage or 1,pages));box(x,y,270,565,"Bank   "..self.inv:bankUsed().."/"..cap)
 -- Each tab grows from 25 to 50 slots before the next tab is unlocked.
 local tabY=y+38;local tabW=math.min(42,math.floor(226/pages));local totalW=tabW*pages;local tabX=x+20
 for pg=1,pages do local tx=tabX+(pg-1)*tabW;love.graphics.setColor(pg==self.bankPage and .28 or .11,pg==self.bankPage and .23 or .10,pg==self.bankPage and .14 or .08,.96);love.graphics.rectangle("fill",tx,tabY,tabW-2,24,4,4);love.graphics.setColor(.72,.62,.40);love.graphics.rectangle("line",tx,tabY,tabW-2,24,4,4);love.graphics.setColor(1,1,1);love.graphics.printf(tostring(pg),tx,tabY+5,tabW-2,"center") end
 local sx,sy=x+20,y+72;local mx,my=love.mouse.getPosition();local first=(self.bankPage-1)*50+1;local last=math.min(first+49,cap)
 for i=first,last do local li=i-first;local r=math.floor(li/5);local c=li%5;local px,py=sx+c*47,sy+r*43;love.graphics.setColor(.08,.07,.06,.9);love.graphics.rectangle("fill",px,py,38,38,4,4);love.graphics.setColor(.48,.39,.28);love.graphics.rectangle("line",px,py,38,38,4,4);local it=self.inv.bank[i];if it then self:drawItemSprite(it,px,py,38,true);if inside(mx,my,px,py,38,38) then self.hoverTooltip={item=it,info=nil} end end end
 local by=y+522;love.graphics.setColor(.12,.11,.09,.96);love.graphics.rectangle("fill",x+20,by,226,30,5,5);love.graphics.setColor(.72,.62,.40);love.graphics.rectangle("line",x+20,by,226,30,5,5);love.graphics.setColor(1,1,1);love.graphics.printf("DEPOSIT ALL INVENTORY",x+20,by+7,226,"center")
end
function UI:drawBankContext(w,h)
 local c=self.bankContext;if not c then return end;local it=self.inv.bank[c.slot];if not it then self.bankContext=nil;return end
 local opts={"Withdraw","Withdraw 10","Withdraw 100","Cancel"};local cw,ch=160,24+#opts*25;local x,y=c.x,c.y;if x+cw>w then x=w-cw-4 end;if y+ch>h then y=h-ch-4 end;c.drawX,c.drawY,c.options=x,y,opts
 love.graphics.setColor(.035,.032,.025,.99);love.graphics.rectangle("fill",x,y,cw,ch,4,4);love.graphics.setColor(.72,.62,.40);love.graphics.rectangle("line",x,y,cw,ch,4,4);love.graphics.setColor(1,.9,.62);love.graphics.print(it.name,x+8,y+5);for i,opt in ipairs(opts) do love.graphics.setColor(1,1,1);love.graphics.print(opt,x+10,y+22+(i-1)*25) end
end
function UI:doBankContext(opt)
 local c=self.bankContext;if not c then return end;local it=self.inv.bank[c.slot];if not it then self.bankContext=nil;return end
 if opt~="Cancel" then local amount=(opt=="Withdraw 100" and 100) or (opt=="Withdraw 10" and 10) or 1;local ok,name,qty=self.inv:withdrawBankSlotAmount(c.slot,amount);self:log("BANK_WITHDRAW",{slot=c.slot,item=name or it.name,requested=amount,qty=qty or 0,success=tostring(ok)});if not ok and name=="bags_full" then self.world:addPopup(self.player.x,self.player.y-24,"FULL INVENTORY","miss") end end
 self.bankContext=nil
end
function UI:sellShopInventory()
 local ok,result,count=self.shop:sellInventory(self.inv);self.world:addPopup(self.player.x,self.player.y-24,ok and('SOLD '..count..' ITEMS')or('SALE '..tostring(result)),ok and'defeat'or'miss');self:log('SHOP_SELL_INVENTORY',{success=tostring(ok),count=count or 0});return ok
end
function UI:shopDoubleClick(slot,mx,my)
 local now=love.timer.getTime();local row=self.shop.slots[slot];self.selectedShopRow=row;self.selectedShop=self.shop;local last=self.lastShopClick
 if row and last and last.shop==self.shop and last.row==row and last.slot==slot and now>=last.time and now-last.time<=.35 then self.lastShopClick=nil;self.shopContext={slot=slot,x=mx,y=my};self:doShopContext('Buy 1');return true end
 self.lastShopClick=row and{shop=self.shop,row=row,slot=slot,time=now}or nil;return false
end
function UI:shopSlotAt(mx,my) local x,y=self:rect("shop");local offset=ShopTabs.offset(self);local rows,indices=ShopTabs.view(self);local sx,sy=x+20,y+66+offset;local startRow=math.floor((self.shopScroll or 0)/40);for row=0,4 do for col=0,4 do local i=(startRow+row)*5+col+1;if inside(mx,my,sx+col*47,sy+row*40,38,34) then return indices[i] end end end end
function UI:drawShop(w,h) local x,y=self:rect("shop");local offset=ShopTabs.offset(self);local rows,indices=ShopTabs.view(self);box(x,y,270,320+offset,(self.shop.title or "Shop - All Items").."   "..self.inv:moneyText());love.graphics.setColor(.75,.72,.65);love.graphics.print(self.shop.traderOnly and "Buys goods cheap - 25% value" or (self.shop.tradeOnly and "Trade goods" or ("Seed "..self.shop.seed.."   changes in "..self.shop:secondsToChange().."s")),x+12,y+34);ShopTabs.draw(self,x,y);local sx,sy=x+20,y+66+offset;local mx,my=love.mouse.getPosition();local startRow=math.floor((self.shopScroll or 0)/40);for r=0,4 do for c=0,4 do local i=(startRow+r)*5+c+1;local px,py=sx+c*47,sy+r*40;love.graphics.setColor(.08,.07,.06,.9);love.graphics.rectangle("fill",px,py,38,34,4,4);love.graphics.setColor(.48,.39,.28);love.graphics.rectangle("line",px,py,38,34,4,4);local it=rows[i];if it then self:drawItemSprite(it.object or it,px+2,py,34);if inside(mx,my,px,py,38,34) then local display=it.object or it;local unit=math.max(1,math.floor(self.shop:buyPrice(it.name)*(it.priceMult or 1)));self.hoverTooltip={item=display,info={title=(display.blessed and "Blessed " or "")..it.name,type="Shop stock x"..it.qty,detail=self.shop.tradeOnly and ("Buy: "..self:priceText(unit).."   Matching goods: +10c sell bonus") or ("Buy: "..self:priceText(unit).."   Sell: "..self:priceText(self.shop:sellPrice(it.name)))}} end end end end
 local totalRows=math.ceil(#rows/5);local maxRows=math.max(0,totalRows-5)
 if maxRows>0 then local trackH=194;local thumbH=math.max(28,trackH*(5/totalRows));local maxScroll=maxRows*40;local thumbY=y+66+offset+(trackH-thumbH)*((self.shopScroll or 0)/maxScroll);love.graphics.setColor(.12,.11,.09,.95);love.graphics.rectangle("fill",x+258,y+66+offset,5,trackH,2,2);love.graphics.setColor(.72,.62,.40);love.graphics.rectangle("fill",x+258,thumbY,5,thumbH,2,2) end
 love.graphics.setColor(.12,.11,.09);love.graphics.rectangle('fill',x+12,y+274+offset,118,30,4,4);love.graphics.rectangle('fill',x+138,y+274+offset,120,30,4,4);love.graphics.setColor(1,1,1);love.graphics.printf('Sell Inventory',x+12,y+282+offset,118,'center');love.graphics.printf('Buy Max',x+138,y+282+offset,120,'center')
end
function UI:craftRecipes(station)return CookingTabs.view(self,station)end
function UI:craftRecipeAt(station,mx,my)
 local x,y,w,h=self:rect(station);local first=math.floor((self.craftScroll[station] or 0)/72);local recipes,indices=self:craftRecipes(station)
 for row=0,3 do if inside(mx,my,x+16,y+CookingTabs.rowY(station)+row*72,w-32,68) then local i=first+row+1;if recipes[i] then return indices and indices[i]or i end end end
end
function UI:drawCrafting(station)
 local x,y,w,h=self:rect(station);local recipes=self:craftRecipes(station)
 box(x,y,w,h,((require("game.help").stations[station] or {})[1] or station).." - "..(CookingTabs.is(station)and CookingTabs.selected(self,station)or"scroll for recipes"))
 CookingTabs.draw(self,station)
 local first=math.floor((self.craftScroll[station] or 0)/72)
 for row=0,3 do local r=recipes[first+row+1];if r then
  local py=y+CookingTabs.rowY(station)+row*72
  love.graphics.setColor(.12,.11,.09);love.graphics.rectangle("fill",x+16,py,w-32,68,4,4)
  self:drawItemSprite({name=r.output,qty=1},x+18,py+17,34)
  local unlocked=self.skills:get(r.skill).level>=(r.level or 1)and not r.placeholder;love.graphics.setColor(unlocked and 1 or .68,unlocked and 1 or .55,unlocked and 1 or .50);love.graphics.print((r.displayName or r.name)..((r.qty or 1)>1 and (" x"..r.qty) or ""),x+58,py+3)
  local req={};if r.stationRequirement then req[#req+1]='At '..require('game.advanced_gear').stationName(r.stationRequirement) end;if r.tool and(r.tailoring or r.advancedRecipe) then req[#req+1]="Requires "..r.tool end;if r.placeholder then req[1]="Not in yet"end;for _,n in ipairs(r.needs) do req[#req+1]=n[2].."x "..(n[3] and "Blessed " or "")..((self.sprites.itemInfo[n[1]]or{}).title or n[1])..(r.tailoring and (" ("..require('game.tailoring_content').count(self.inv,n[1])..")")or "") end
  love.graphics.setColor(.75,.73,.66);love.graphics.printf(table.concat(req," + "),x+58,py+18,w-82,"left")
  love.graphics.setColor(.85,.77,.45);love.graphics.print(r.placeholder and(r.skill.." "..(r.level or 1).." | Not in yet")or string.format("%s %d%s | +%g XP | %.1fs",r.skill,r.level or 1,unlocked and "" or " (LOCKED)",(r.xp or 0)*self.skills:xpMultiplier(r.skill),(r.duration or .5)*math.max(1,r.qty or 1)),x+58,py+52)
 end end
 love.graphics.setColor(1,1,1);love.graphics.print(string.format("Recipes %d-%d / %d",math.min(first+1,#recipes),math.min(first+4,#recipes),#recipes),x+16,y+h-24)
end
local RUNE_MATERIALS={['Cave Snake Fang']=true,['Charred Wood']=true,['Fish Bones']=true,['Stone Gravel']=true,['Carved Feather']=true,['Carved Onyx']=true,['Green Slime Tube']=true}
function UI:runeBag() local b=self.equipment.ammo;return type(b)=="table" and b.name=="Rune Bag" and b or nil end
function UI:ensureRuneBag(b)return require('game.rune_quality').ensure(b)end
function UI:storeBlessedInRuneBag(name)
 local rb=self:ensureRuneBag(self:runeBag());if not rb or not RUNE_MATERIALS[name]then return false,'no_rune_bag'end
 local moved=0;for _,bag in pairs(self.inv.bagSlots)do for si,it in pairs(bag.slots)do if it.name==name and it.blessed then local n=require('game.rune_quality').deposit(rb,it);moved=moved+n;it.qty=(it.qty or 1)-n;if it.qty<=0 then bag.slots[si]=nil end end end end
 return moved>0,moved>0 and moved or(rb.materials[name]>=require('game.rune_quality').capacity(rb) and'rune_bag_full'or'none')
end
function UI:countSpellRuneMaterial(name)local rb=self:ensureRuneBag(self:runeBag());return(rb and rb.materials[name]or 0)+self.inv:countBlessed(name)end
function UI:consumeSpellRuneMaterial(name,qty)
 qty=math.max(0,math.floor(qty or 0));if self:countSpellRuneMaterial(name)<qty then return false end
 local fromBag=0;for i=1,qty do local _,b=require('game.rune_quality').select(self,name);if b then fromBag=fromBag+1 end;require('game.rune_quality').consume(self,name)end;return true,fromBag,qty-fromBag
end
function UI:openRuneBag(b)
 b=self:ensureRuneBag(b);if not b then return end;local parts={};for _,n in ipairs({'Charred Wood','Fish Bones','Stone Gravel','Carved Feather','Carved Onyx','Green Slime Tube','Cave Snake Fang'}) do parts[#parts+1]=n.." "..tostring(b.materials[n] or 0).."/"..require("game.rune_quality").capacity(b) end
 self.world:addPopup(self.player.x,self.player.y-22,"RUNE BAG: "..table.concat(parts," | "),"defeat");self:log("RUNE_BAG_OPENED",b.materials)
end
function UI:ammoContainerRect()
 local p=self.pos.ammoContainer or {x=1040,y=180};self.pos.ammoContainer=p
 local a=self.equipment.ammo;local name=type(a)=="table" and a.name or a
 return p.x,p.y,(name=="Rune Bag") and 356 or 190,(name=="Rune Bag") and 158 or 116
end
function UI:ammoContainerSlotAt(mx,my)
 if not self.open.ammoContainer then return nil end
 local a=self.equipment.ammo;local name=type(a)=="table" and a.name or a;if name~="Rune Bag" and not require('game.advanced_gear').isQuiver(name) then return nil end
 local x,y=self:ammoContainerRect();local count=name=="Rune Bag" and 7 or 1
 for i=1,count do local col=(i-1)%6;local row=math.floor((i-1)/6);if inside(mx,my,x+16+col*46,y+48+row*46,40,40) then return i end end
end
function UI:drawAmmoContainer()
 local a=self.equipment.ammo;local name=type(a)=="table" and a.name or a;if name~="Rune Bag" and not require('game.advanced_gear').isQuiver(name) then self.open.ammoContainer=false;return end
 local x,y,w,h=self:ammoContainerRect();box(x,y,w,h,name)
 local mx,my=love.mouse.getPosition()
 if name=="Rune Bag" then
  self:ensureRuneBag(a);local names={'Charred Wood','Fish Bones','Stone Gravel','Carved Feather','Carved Onyx','Green Slime Tube','Cave Snake Fang'}
  for i,n in ipairs(names) do local px=x+16+(i-1)*46;local py=y+48;love.graphics.setColor(.08,.07,.06,.94);love.graphics.rectangle('fill',px,py,40,40,4,4);love.graphics.setColor(.72,.62,.24);love.graphics.rectangle('line',px,py,40,40,4,4);local q=a.materials[n] or 0;if q>0 then self:drawItemSprite({name=n,qty=q,blessed=true},px+1,py+1,38) end;if inside(mx,my,px,py,40,40) then self.hoverTooltip={item={name=n,qty=q,blessed=true},info={title=n,type='Rune Bag Slot',detail='Blessed '..n..' '..q..'/'..require('game.rune_quality').capacity(a)..'. '..require('game.rune_quality').detail(a,n)..'\nDrag here to store; click to withdraw all grades.'}} end end
  love.graphics.setColor(.72,.68,.60);love.graphics.print('50 of each blessed material',x+16,y+100)
 else
  local px,py=x+16,y+48;love.graphics.setColor(.08,.07,.06,.94);love.graphics.rectangle('fill',px,py,40,40,4,4);love.graphics.setColor(.72,.62,.40);love.graphics.rectangle('line',px,py,40,40,4,4);if a.arrowType and (a.qty or 0)>0 then self:drawItemSprite({name=a.arrowType,qty=a.qty},px+1,py+1,38) end;if inside(mx,my,px,py,40,40) then self.hoverTooltip={item={name=a.arrowType or 'Quiver',qty=a.qty or 0},info={title=a.arrowType or 'Empty Quiver Slot',type='Quiver Slot',detail='Drag arrows here to load them. Click the loaded slot to withdraw the stack.'}} end
 end
end
function UI:depositIntoAmmoContainer(bi,slot,targetSlot)
 local b=self.inv:getBag(bi);local it=b and b.slots[slot];local a=self.equipment.ammo;if not it or type(a)~='table' then return false end
 if require('game.advanced_gear').isQuiver(a.name) then
  local info=self.sprites.itemInfo[it.name];if not info or info.type~='Ammo' or require('game.advanced_gear').isQuiver(it.name) or it.name=='Rune Bag' then return false end
  if a.arrowType and a.arrowType~=it.name then self.world:addPopup(self.player.x,self.player.y-22,'QUIVER HOLDS '..string.upper(a.arrowType),'miss');return false end
  local qty=it.qty or 1;a.arrowType=it.name;a.qty=(a.qty or 0)+qty;b.slots[slot]=nil;self:log('QUIVER_SLOT_DEPOSIT',{item=it.name,qty=qty,total=a.qty});return true
 elseif a.name=='Rune Bag' and RUNE_MATERIALS[it.name] then
  if not it.blessed then self.world:addPopup(self.player.x,self.player.y-22,'MATERIAL MUST BE BLESSED','miss');return false end
  self:ensureRuneBag(a);local room=require('game.rune_quality').capacity(a)-(a.materials[it.name] or 0);local move=math.min(room,it.qty or 1);if move<=0 then self.world:addPopup(self.player.x,self.player.y-22,'RUNE BAG SLOT FULL','miss');return false end
  require("game.rune_quality").deposit(a,it,move);it.qty=(it.qty or 1)-move;if it.qty<=0 then b.slots[slot]=nil end;self:log('RUNE_BAG_SLOT_DEPOSIT',{item=it.name,qty=move,total=a.materials[it.name]});return true
 end
 return false
end
function UI:withdrawAmmoContainerSlot(slot)
 local a=self.equipment.ammo;if type(a)~='table' then return false end
 if require('game.advanced_gear').isQuiver(a.name) and slot==1 and a.arrowType and (a.qty or 0)>0 then local n,q=a.arrowType,a.qty;if self.inv:canAdd(n,q) then self.inv:add(n,q);a.arrowType=nil;a.qty=0;self:log('QUIVER_SLOT_WITHDRAW',{item=n,qty=q});return true else self.world:addPopup(self.player.x,self.player.y-22,'FULL INVENTORY','miss') end
 elseif a.name=='Rune Bag' then local names={'Charred Wood','Fish Bones','Stone Gravel','Carved Feather','Carved Onyx','Green Slime Tube','Cave Snake Fang'};local n=names[slot];self:ensureRuneBag(a);local q=n and (a.materials[n] or 0) or 0;if q>0 then if require("game.rune_quality").withdraw(a,n,self.inv)then self:log('RUNE_BAG_SLOT_WITHDRAW',{item=n,qty=q});return true else self.world:addPopup(self.player.x,self.player.y-22,'FULL INVENTORY','miss') end end
 end
 return false
end
function UI:isUseSource(it)
 if not it then return false end
 local n=it.name
 return n=="Copper Dagger" or n=="Copper Knife" or n=="Needle" or n=="Blue Dye" or n=="Flint and Steel" or n=="Bow String" or n=="Copper Arrowheads" or n=="Chisel" or n=="Empty Tube"
end
function UI:isUseCompatible(tool,it)
 if not tool or not it then return false end
 local n=it.name
 if tool=="Flint and Steel" then return n=="Pine Logs" or n=="Oak Logs" or n=="Logs" end
 if tool=="Copper Dagger" or tool=="Copper Knife" then return n=="Pine Logs" or n=="Oak Logs" or n=="Logs" or n=="Feather" or n=="Small Fish" or n=="Large Fish" or n=="Eel" or n=="Swordfish" or n=="Tuna" or n=="Shark" or n=="Manta Ray" end
 if tool=="Needle" then return n=="Dyed Blue Cloth Strip" or n=="Dark Blue Cloth" or n=="Linen Thread" or n:find("Leather",1,true)~=nil or n:find("Hide",1,true)~=nil end
 if tool=="Blue Dye" then return n=="Cloth Strip" end
 if tool=="Bow String" then return n=="Pine Unstrung Bow" or n=="Oak Unstrung Bow" or n=="Unstrung Bow" end
 if tool=="Copper Arrowheads" then return n=="Pine Arrow Shafts" or n=="Oak Arrow Shafts" or n=="Arrow Shafts" end
 if tool=="Chisel" then return n=="Cut Onyx" or n=="Rough Onyx" or n=="Ruby-bearing Rock" or n=="Sapphire-bearing Rock" or n=="Emerald-bearing Rock" or n=="Rough Ruby" or n=="Rough Sapphire" or n=="Rough Emerald" end
 if tool=="Empty Tube" then return n=="Green Slime Jar" end
 return false
end
function UI:selectUseItem(bi,slot,it)
 if not self:isUseSource(it) then return false end
 self.useTarget={tool=it.name,bag=bi,slot=slot}
 self.context=nil
 self:log("ITEM_USE_TARGET_STARTED",{tool=it.name,source="left_click"})
 return true
end
function UI:isSelectedUseSlot(bi,slot)
 return self.useTarget and self.useTarget.bag==bi and self.useTarget.slot==slot
end
function UI:cancelItemUse(reason)
 if not self.useTarget then return false end
 local tool=self.useTarget.tool
 self.useTarget=nil
 self:log("ITEM_USE_CANCELLED",{reason=reason or "cancelled",tool=tool})
 return true
end
function UI:contextOptions(it) local info=self.sprites.itemInfo[it.name];local typ=info and info.type or "Item";local o={};if (it.name=="Pine Logs" or it.name=="Oak Logs" or it.name=="Poplar Logs" or it.name=="Logs") then o[#o+1]="Add to Bonfire" end;local loadedQuiver=(require('game.advanced_gear').isQuiver(it.name) and it.arrowType and (it.qty or 0)>0);if loadedQuiver then o[#o+1]="Unload Quiver" end;if typ=="Ammo" and not require('game.advanced_gear').isQuiver(it.name) and it.name~="Rune Bag" and type(self.equipment.ammo)=="table" and require('game.advanced_gear').isQuiver(self.equipment.ammo.name) then local q=self.equipment.ammo;if not q.arrowType or q.arrowType==it.name then o[#o+1]="Load Quiver" end end;if it.name~="Rune Bag" and (self.open.mercenary or self.open.mercBand) and #self.world.mercs>0 and (typ=="Weapon" or typ=="Tool" or typ=="Head Armor" or typ=="Body Armor" or typ=="Foot Armor" or typ=="Cape" or typ=="Offhand" or typ=="Ammo") then o[#o+1]="Give to Merc" end;if self.open.socketTable and (typ=="Weapon" or typ=="Head Armor" or typ=="Body Armor" or typ=="Foot Armor" or typ=="Cape" or typ=="Offhand") then o[#o+1]="Select Socket Item";o[#o+1]="Create Socket" end;if self.open.socketTable and typ=="Cut Jewel" then o[#o+1]="Socket Gem" end;if self.open.enchantAltar and typ=="Cut Jewel" then o[#o+1]="Select Enchant Gem" end;if self.open.enchantAltar and (typ=="Spell Page" or typ=="Skill Page") then o[#o+1]="Select Enchant Page" end;if self.open.spellbook and typ=="Spell Page" and it.name~="Empty Spell Page" then o[#o+1]="Add to Spellbook" end;if self.open.enchantAltar and typ=="Gem Dust" and self.enchantGem and self.enchantPage and it.name==((self.enchantGem.name or ""):gsub("^Cut ","").." Dust") then o[#o+1]="Enchant with 1 Dust";if (it.qty or 1)>=5 then o[#o+1]="Enchant with 5 Dust" end;o[#o+1]="Enchant with All Dust" end;if it.name=="Copper Dagger" or it.name=="Copper Knife" or it.name=="Needle" or it.name=="Blue Dye" or it.name=="Dark Blue Dye" or it.name=="Dark Blue Cloth" or it.name=="Flint and Steel" or it.name=="Bow String" or it.name=="Copper Arrowheads" or it.name=="Iron Arrowheads" or it.name=="Chisel" or it.name=="Empty Tube" then o[#o+1]="Use" end;if RUNE_MATERIALS[it.name] or (info and info.blessable) then o[#o+1]="Bless";if it.blessed and RUNE_MATERIALS[it.name] and self:runeBag() then o[#o+1]="Store in Rune Bag" end end;if it.name=="Brown Mushroom" or it.name=="Red Berries" or it.name=="Purple Berries" or (info and (info.type=="Food" or info.type=="Burnt Food")) then o[#o+1]="Eat" end;if typ=="Weapon" or typ=="Tool" or typ=="Head Armor" or typ=="Body Armor" or typ=="Foot Armor" or typ=="Cape" or typ=="Offhand" then o[#o+1]="Equip" end;if typ=="Ammo" then o[#o+1]="Equip Ammo" end;if typ=="Potion" then o[#o+1]="Equip Potion" end;if self.inv:isBagItem(it.name) then o[#o+1]="Equip Bag" end;if self.open.bank and not loadedQuiver then o[#o+1]="Deposit";o[#o+1]="Deposit All" end;if self.open.shop and not loadedQuiver and self.shop:acceptsSale(it.name) and not self.inv:isCurrency(it.name) then o[#o+1]="Sell ("..self.shop:sellPrice(it.name).."c)";local count=self.inv:countItem(it.name);if count>1 then o[#o+1]="Sell All ("..(self.shop:sellPrice(it.name)*count).."c)" end end;if not loadedQuiver then o[#o+1]="Drop" end;o[#o+1]="Cancel";return o end
function UI:drawContext(w,h) local c=self.context;if not c then return end;local bag=self.inv:getBag(c.bag);local it=bag and bag.slots[c.slot];if not it then self.context=nil;return end;local opts=self:contextOptions(it);local cw,ch=150,24+#opts*25;local x,y=c.x,c.y;if x+cw>w then x=w-cw-4 end;if y+ch>h then y=h-ch-4 end;c.drawX,c.drawY,c.options=x,y,opts;love.graphics.setColor(.035,.032,.025,.99);love.graphics.rectangle("fill",x,y,cw,ch,4,4);love.graphics.setColor(.72,.62,.40);love.graphics.rectangle("line",x,y,cw,ch,4,4);love.graphics.setColor(1,.9,.62);love.graphics.print(it.name,x+8,y+5);for i,opt in ipairs(opts) do love.graphics.setColor(1,1,1);love.graphics.print(opt,x+10,y+22+(i-1)*25) end end
function UI:doContextOption(opt) local c=self.context;if not c then return end;local b=self.inv:getBag(c.bag);local it=b and b.slots[c.slot];if not it then self.context=nil;return end
 if not self.finishingCraft and (opt=="Create Socket" or opt=="Socket Gem" or opt:find("Enchant with",1,true)) then
 if self.craftJob then return end
 local ctx={bag=c.bag,slot=c.slot};local amount=opt=="Enchant with All Dust" and (it.qty or 1) or opt=="Enchant with 5 Dust" and math.min(5,it.qty or 1) or 1
 if opt:find('Enchant with',1,true)then local color=self.enchantGem and self.enchantGem.name:match('^Cut (%a+)$');local def=require('game.enchanting').gems[color];amount=math.min(amount,def and def.maxDust or amount)end;self.context=nil;self.craftJob={name=opt,timer=0,duration=.5*amount,x=self.player.x,y=self.player.y,finish=function()
  if b.slots[ctx.slot]~=it then return end
  self.finishingCraft=true;self.context=ctx;self:doContextOption(opt);self.finishingCraft=false
 end};return
 end
 if opt=="Equip" or opt=="Equip Ammo" or opt=="Give to Merc" then local actor=(opt=="Equip" or opt=="Equip Ammo") and self.skills or self.world.mercs[self.selectedMerc or 1];if actor then local ok,skill,level=require("game.progression").canEquip(actor,it.name,self.sprites.itemInfo[it.name]);if not ok then self.world:addPopup(self.player.x,self.player.y-25,skill.." level "..level.." required");self.context=nil;return end end end
 if opt=="Use" and (it.name=="Dark Blue Dye" or it.name=="Dark Blue Cloth") then self:openCrafting("tailoring","material");self.context=nil;return end
 if opt=="Add to Bonfire" then local ok,res=require("game.bonfire_ui").start(self,it.name);self:log("BONFIRE_REFUEL_ATTEMPT",{fuel=it.name,success=tostring(ok),result=tostring(res)});if not ok then self.world:addPopup(self.player.x,self.player.y-22,tostring(res):upper(),"miss") end;self.context=nil;return end
 if opt=="Give to Merc" then
  local m=self.world.mercs[self.selectedMerc or 1];if m then
   local info=self.sprites.itemInfo[it.name] or {};local slot=(info.type=='Head Armor' and 'head') or (info.type=='Body Armor' and 'body') or (info.type=='Foot Armor' and 'legs') or (info.type=='Cape' and 'cape') or (info.type=='Offhand' and 'offhand') or (info.type=='Ammo' and 'ammo') or 'weapon'
   local ok,incoming,old=require('game.items').equipFromBag(self,c.bag,c.slot,slot,m)
   if ok then self:log('MERCENARY_EQUIPPED',{merc=m.name,item=incoming.name,slot=slot,replaced=old and old.name or 'none'}) else self.world:addPopup(self.player.x,self.player.y-22,'NO ROOM FOR OFFHAND','miss') end
  end
 elseif opt=="Select Socket Item" then self.socketTarget={bag=c.bag,slot=c.slot,item=it};require("game.sockets").normalize(it);self:log("SOCKET_ITEM_SELECTED",{item=it.name,sockets=#it.sockets,maxSockets=self:maxSockets()})
 elseif opt=="Create Socket" then self.socketTarget={bag=c.bag,slot=c.slot,item=it};require("game.sockets").create(self)
 elseif opt=="Socket Gem" then require("game.sockets").insert(self,c.bag,c.slot)
 elseif opt=="Select Enchant Gem" then self.enchantGem={bag=c.bag,slot=c.slot,name=it.name,item=it};self:log("ENCHANT_GEM_SELECTED",{gem=it.name})
 elseif opt=="Select Enchant Page" then self.enchantPage={bag=c.bag,slot=c.slot,name=it.name,item=it};self:log("ENCHANT_PAGE_SELECTED",{page=it.name})
 elseif opt=="Add to Spellbook" then
  local duplicate=false;for i=1,6 do if self.spellPages[i]==it.name then duplicate=true;break end end
  if duplicate then self.world:addPopup(self.player.x,self.player.y-22,"PAGE ALREADY IN SPELLBOOK","miss") else local slot=nil;for i=1,6 do if not self.spellPages[i] then slot=i;break end end;if not slot then self.world:addPopup(self.player.x,self.player.y-22,"SPELLBOOK FULL","miss") else self.spellPages[slot]=it.name;b.slots[c.slot]=nil;self.world:addPopup(self.player.x,self.player.y-22,"PAGE ADDED TO SPELLBOOK","defeat");self:log("SPELL_PAGE_ADDED",{page=it.name,slot=slot}) end end
 elseif opt=="Enchant with 1 Dust" then self:enchantGemWithDust(1)
 elseif opt=="Enchant with 5 Dust" then self:enchantGemWithDust(math.min(5,it.qty or 1))
 elseif opt=="Enchant with All Dust" then self:enchantGemWithDust(it.qty or 1)
 elseif opt=="Bless" then require("game.religion").blessInventory(self,false)
 elseif opt=="Eat" and it.name=="Potent Antidote" then self.player.poisonedTimer=0;self.player.poisonTick=0;self.player.slimeCoated=0;self.player.slimeBreathTick=0;self.player.poisonImmuneTimer=15;b.slots[c.slot]=nil
 elseif opt=="Unload Quiver" and require('game.advanced_gear').isQuiver(it.name) then local aq=it.qty or 0;if it.arrowType and aq>0 and self.inv:canAdd(it.arrowType,aq) then local arrowType=it.arrowType;it.arrowType=nil;it.qty=1;self.inv:add(arrowType,aq);self:log("QUIVER_UNLOADED",{arrowType=arrowType,qty=aq,source="inventory"}) else self.world:addPopup(self.player.x,self.player.y-22,"NOT ENOUGH BAG SPACE","miss") end
 elseif opt=="Store in Rune Bag" then local ok,res=self:storeBlessedInRuneBag(it.name);self.world:addPopup(self.player.x,self.player.y-22,ok and ("RUNE BAG +"..tostring(res).." "..string.upper(it.name)) or (res=="rune_bag_full" and "RUNE BAG MATERIAL FULL" or "CANNOT STORE"),ok and "defeat" or "miss");self:log("RUNE_BAG_STORE",{item=it.name,success=tostring(ok),result=tostring(res)})
 elseif opt=="Load Quiver" then local q=self.equipment.ammo;if type(q)=="table" and require('game.advanced_gear').isQuiver(q.name) and (not q.arrowType or q.arrowType==it.name) then local amount=it.qty or 1;local existing=q.arrowType and (q.qty or 0) or 0;q.arrowType=it.name;q.qty=existing+amount;b.slots[c.slot]=nil;self:log("QUIVER_LOADED",{arrowType=it.name,qty=amount,total=q.qty}) end
 elseif opt=="Eat" then local heal=require("game.food").healing[it.name] or (self.sprites.itemInfo[it.name] and self.sprites.itemInfo[it.name].heal) or 1;local before=self.player.hp;if before<self.player.maxHp then self.player.hp=math.min(self.player.maxHp,before+heal);it.qty=(it.qty or 1)-1;if it.qty<=0 then b.slots[c.slot]=nil end;self:log("ITEM_EATEN",{item=it.name,heal=self.player.hp-before,hp=self.player.hp}) else self:log("ITEM_EAT_BLOCKED",{item=it.name,reason="full_health"}) end;elseif opt=="Use" then
 if it.name=="Flint and Steel" and self.equipment.offhand=="Torch" then self.equipment.offhand="Lit Torch";if self.equipmentItems.offhand then self.equipmentItems.offhand.name="Lit Torch" end;self.world:addPopup(self.player.x,self.player.y-22,"TORCH LIT","defeat");self:log("TORCH_LIT",{source="flint_and_steel"})
 else self.useTarget={tool=it.name,bag=c.bag,slot=c.slot};self.open.inventory=true;self:bringToFront("inventory");self:log("ITEM_USE_TARGET_STARTED",{tool=it.name,source="context_menu"}) end
 elseif opt=="Equip Ammo" then local meta=self.sprites.itemInfo[it.name];if meta and meta.customEquipment and not require('game.progression').canEquip(self.skills,it.name,meta)then self.world:addPopup(self.player.x,self.player.y-24,'EQUIPMENT LEVEL REQUIRED','miss');self.context=nil;return end;local old=self.equipment.ammo;local moved={};for k,v in pairs(it) do moved[k]=v end;self.equipment.ammo=moved;if moved.name=="Rune Bag" then self:ensureRuneBag(moved) end;b.slots[c.slot]=old and (function() local r={};for k,v in pairs(old) do r[k]=v end;return r end)() or nil;self:log("AMMO_EQUIPPED",{item=it.name,qty=self.equipment.ammo.qty,replaced=old and old.name or "none"}) elseif opt=="Equip Potion" then local ok,res=self:equipPotionFromBag(c.bag,c.slot);self:log("POTION_BELT_EQUIP_ATTEMPT",{success=tostring(ok),result=tostring(res)}) elseif opt=="Equip Bag" then local target=nil;for i=1,self.inv:bagSlotCount() do if not self.inv.bagSlots[i] then target=i;break end end;if target then local ok,res=self.inv:equipBagFromItem(c.bag,c.slot,target);self:log("BAG_EQUIP_ATTEMPT",{success=tostring(ok),result=res,target=target}) else self:log("BAG_EQUIP_ATTEMPT",{success="false",result="no_empty_bag_slot"}) end elseif opt=="Equip" then
 local info=self.sprites.itemInfo[it.name] or {};local slot=info.slot or (info.type=="Head Armor" and "head") or (info.type=="Body Armor" and "body") or (info.type=="Foot Armor" and "legs") or (info.type=="Cape" and "cape") or (info.type=="Offhand" and "offhand") or "weapon"
 if info.customEquipment and not require('game.progression').canEquip(self.skills,it.name,info) then self.world:addPopup(self.player.x,self.player.y-24,'EQUIPMENT LEVEL REQUIRED','miss');self.context=nil;return end
 local ok,incoming,old,off=require('game.items').equipFromBag(self,c.bag,c.slot,slot)
 if not ok then self:log('ITEM_EQUIP_BLOCKED',{item=it.name,reason=incoming});self.context=nil;return end
 if off then self:log('ITEM_UNEQUIPPED',{item=off.name,slot='offhand',reason='two_handed_bow'}) end
 self:log("ITEM_EQUIPPED",{item=it.name,slot=slot,replaced=old and old.name or "none"}) elseif opt=="Deposit" then local ok,name,qty=self.inv:depositSlot(c.bag,c.slot);self:log("BANK_DEPOSIT",{item=name or it.name,qty=qty or 0,success=tostring(ok)}) elseif opt=="Deposit All" then local targetName=it.name;local ok,name,qty=self.inv:depositAll(targetName);self:log("BANK_DEPOSIT_ALL",{item=name or targetName,qty=qty or 0,success=tostring(ok)}) elseif opt:sub(1,8)=="Sell All" then local targetName=it.name;local ok,price,qty=self.shop:sellAll(targetName,self.inv);self:log("SHOP_SELL_ALL",{item=targetName,qty=qty or 0,price=type(price)=="number" and price or 0,result=tostring(price),success=tostring(ok)}) elseif opt:sub(1,4)=="Sell" then local d=self.inv:removeSlot(c.bag,c.slot);if d then local ok,price=self.shop:sellObject(d,self.inv);if not ok then b.slots[c.slot]=d end;self:log("SHOP_SELL",{item=d.name,qty=d.qty or 1,price=type(price)=="number" and price or 0,result=tostring(price),success=tostring(ok)}) end elseif opt=="Drop" then local d=self.inv:removeSlot(c.bag,c.slot);if d then self.world:addGroundItem(d.name,self.player.x+10,self.player.y+8,nil,d);self:log("ITEM_DROPPED",{item=d.name}) end end;self.context=nil end
function UI:startWindowDrag(name,mx,my) local x,y=self:rect(name);self.windowDrag={name=name,ox=mx-x,oy=my-y};self.context=nil;self:log("WINDOW_DRAG_STARTED",{window=name}) end
function UI:drawShopContext(w,h)
 local c=self.shopContext;if not c then return end;local it=self.shop.slots[c.slot];if not it then self.shopContext=nil;return end
 local opts={"Buy 1","Buy 10","Buy All","Cancel"};local cw,ch=150,24+#opts*25;local x,y=c.x,c.y;if x+cw>w then x=w-cw-4 end;if y+ch>h then y=h-ch-4 end
 c.drawX,c.drawY,c.options=x,y,opts;love.graphics.setColor(.035,.032,.025,.99);love.graphics.rectangle("fill",x,y,cw,ch,4,4);love.graphics.setColor(.72,.62,.40);love.graphics.rectangle("line",x,y,cw,ch,4,4);love.graphics.setColor(1,.9,.62);love.graphics.print(it.name,x+8,y+5)
 for i,opt in ipairs(opts) do love.graphics.setColor(1,1,1);love.graphics.print(opt,x+10,y+22+(i-1)*25) end
end
function UI:doShopContext(opt)
 local c=self.shopContext;if not c then return end
 if opt~="Cancel" then local qty=opt=="Buy 1" and 1 or (opt=="Buy 10" and 10 or "all");local ok,name,total,bought=self.shop:buy(c.slot,self.inv,qty);if not ok then local why=name;local msg=(why=="not_enough_currency" and "NOT ENOUGH MONEY") or (why=="bags_full" and "NOT ENOUGH INVENTORY SPACE") or "PURCHASE FAILED";self.world:addPopup(self.player.x,self.player.y-24,msg,"miss") end;self:log("SHOP_BUY",{slot=c.slot,item=name or "none",qty=bought or 0,totalPrice=type(total)=="number" and total or 0,result=tostring(total),success=tostring(ok)}) end
 self.shopContext=nil
end
function UI:drawEquipmentContext(w,h)
 local c=self.equipmentContext;if not c then return end;local equipped=self.equipment[c.slot];local name=type(equipped)=="table" and equipped.name or equipped;if not name then self.equipmentContext=nil;return end
 local opts=(name=="Rune Bag" or require('game.advanced_gear').isQuiver(name)) and {"Open","Unequip","Cancel"} or (name=="Lit Torch") and {"Unequip","Drop Lit Torch","Cancel"} or (require('game.advanced_gear').isQuiver(name) and type(equipped)=="table" and (equipped.qty or 0)>0) and {"Reload Quiver","Unload Quiver","Unequip","Cancel"} or (require('game.advanced_gear').isQuiver(name) and type(equipped)=="table") and {"Reload Quiver","Unequip","Cancel"} or {"Unequip","Cancel"};local cw,ch=160,24+#opts*25;local x,y=c.x,c.y;if x+cw>w then x=w-cw-4 end;if y+ch>h then y=h-ch-4 end;c.drawX,c.drawY=x,y
 love.graphics.setColor(.035,.032,.025,.99);love.graphics.rectangle("fill",x,y,cw,ch,4,4);love.graphics.setColor(.72,.62,.40);love.graphics.rectangle("line",x,y,cw,ch,4,4);love.graphics.setColor(1,.9,.62);love.graphics.print(name,x+8,y+5);love.graphics.setColor(1,1,1);for i,opt in ipairs(opts) do love.graphics.print(opt,x+10,y+22+(i-1)*25) end;c.options=opts
end
function UI:drawMercContext(w,h)
 local c=self.mercContext;if not c then return end
 local m=self.world.mercs[c.index];if not m then self.mercContext=nil;return end
 local cw,ch=170,74;local x,y=c.x,c.y;if x+cw>w then x=w-cw-4 end;if y+ch>h then y=h-ch-4 end;c.drawX,c.drawY=x,y
 love.graphics.setColor(.035,.032,.025,.99);love.graphics.rectangle("fill",x,y,cw,ch,4,4);love.graphics.setColor(.72,.62,.40);love.graphics.rectangle("line",x,y,cw,ch,4,4);love.graphics.setColor(1,.9,.62);love.graphics.print(m.name,x+8,y+5);love.graphics.setColor(1,.72,.62);love.graphics.print("Fire Mercenary",x+10,y+27);love.graphics.setColor(1,1,1);love.graphics.print("Cancel",x+10,y+52)
end
function UI:fireMerc(index)
 local m=self.world.mercs[index];if not m then return false end
 for _,slot in ipairs({'head','body','legs','weapon','offhand','ammo'}) do local obj=require('game.items').equipped(m,slot)
  if obj then if not self.inv:addItemObject(obj) then self.world:addGroundItem(obj.name,self.player.x+math.random(-8,8),self.player.y+math.random(-8,8),nil,obj) end;require('game.items').setEquipped(m,slot,nil) end
 end
 table.remove(self.world.mercs,index);self.selectedMerc=math.max(1,math.min(self.selectedMerc or 1,#self.world.mercs));self.world:addPopup(self.player.x,self.player.y-22,'MERCENARY FIRED','miss');self:log('MERCENARY_FIRED',{name=m.name,role=m.role,count=#self.world.mercs});return true
end
function UI:mousepressed(mx,my,button,w,h)
 if self.lastShopSellClick and(button~=1 or(mx-self.lastShopSellClick.x)^2+(my-self.lastShopSellClick.y)^2>25)then self.lastShopSellClick=nil end
 if self.lastShopClick and(button~=1 or not self.open.shop or self:shopSlotAt(mx,my)~=self.lastShopClick.slot)then self.lastShopClick=nil end
 if not self.context and self.open.socketTable and button==1 then local x,y=self:rect("socketTable");if inside(mx,my,x+16,y+183,190,30) then local obj=require("game.sockets").target(self);if obj then local t=self.socketTarget;self.context={bag=t.bag,slot=t.slot};self:doContextOption("Create Socket") else self.world:addPopup(self.player.x,self.player.y-22,"SELECT WEAPON/ARMOR FIRST","miss") end;return true end end
 if self.mercContext then
  if button==1 then local c=self.mercContext;if c.drawX and inside(mx,my,c.drawX,c.drawY+20,170,50) then local idx=math.floor((my-(c.drawY+20))/25)+1;if idx==1 then self:fireMerc(c.index) end;self.mercContext=nil;return true end end;self.mercContext=nil;return true
 end
 if self.bagContext then local c=self.bagContext;if button==1 and c.drawX and inside(mx,my,c.drawX,c.drawY,190,55) then local row=math.floor((my-c.drawY)/27)+1;if row==1 then local ok,res=self.inv:unequipBag(c.slot);self.world:addPopup(self.player.x,self.player.y-22,ok and "BAG UNEQUIPPED" or "NOT ENOUGH ROOM IN OTHER BAGS",ok and "defeat" or "miss") end;self.bagContext=nil;return true end;self.bagContext=nil;return true end
 if self.bankContext then
  if button==1 then local c=self.bankContext;if c.drawX and inside(mx,my,c.drawX,c.drawY+20,160,#(c.options or {})*25) then local idx=math.floor((my-(c.drawY+20))/25)+1;local opt=(c.options or {})[idx];if opt then self:doBankContext(opt);return true end end end;self.bankContext=nil;return true
 end
 if self.shopContext then
  if button==1 then local c=self.shopContext;if c.drawX and inside(mx,my,c.drawX,c.drawY+20,150,100) then local idx=math.floor((my-(c.drawY+20))/25)+1;local opts={"Buy 1","Buy 10","Buy All","Cancel"};if opts[idx] then self:doShopContext(opts[idx]);return true end end end;self.shopContext=nil;return true
 end
 if self.equipmentContext then
  if button==1 then local c=self.equipmentContext;local opts=c.options or {"Unequip","Cancel"};if c.drawX and inside(mx,my,c.drawX,c.drawY+20,160,#opts*25) then local idx=math.floor((my-(c.drawY+20))/25)+1;local choice=opts[idx];local equipped=self.equipment[c.slot];local name=type(equipped)=="table" and equipped.name or equipped
    if choice=="Drop Lit Torch" and name=="Lit Torch" then self.world:addGroundItem("Lit Torch",self.player.x+10,self.player.y+8,true,require("game.items").equipped(self,c.slot));require("game.items").setEquipped(self,c.slot,nil);self:log("TORCH_DROPPED_LIT",{x=self.player.x+10,y=self.player.y+8})
    elseif choice=="Reload Quiver" and require('game.advanced_gear').isQuiver(name) and type(equipped)=="table" then local arrowType=equipped.arrowType;if not arrowType then local supported={"Snake Fang Arrows","Iron Arrows","Copper Arrows"};for _,candidate in ipairs(supported) do if self.inv:countItem(candidate)>0 then arrowType=candidate;break end end end;if arrowType then local amount=self.inv:countItem(arrowType);if amount>0 and self.inv:removeItems(arrowType,amount) then equipped.arrowType=arrowType;equipped.qty=(equipped.qty or 0)+amount;self.world:addPopup(self.player.x,self.player.y-22,"QUIVER +"..tostring(amount),"defeat");self:log("QUIVER_RELOADED",{arrowType=arrowType,qty=amount,total=equipped.qty}) else self.world:addPopup(self.player.x,self.player.y-22,"NO ARROWS TO RELOAD","miss") end else self.world:addPopup(self.player.x,self.player.y-22,"NO ARROWS TO RELOAD","miss") end
    elseif choice=="Unload Quiver" and require('game.advanced_gear').isQuiver(name) and type(equipped)=="table" and equipped.arrowType and (equipped.qty or 0)>0 then local aq=equipped.qty;if self.inv:canAdd(equipped.arrowType,aq) then self.inv:add(equipped.arrowType,aq);self:log("QUIVER_UNLOADED",{arrowType=equipped.arrowType,qty=aq});equipped.arrowType=nil;equipped.qty=0 else self.world:addPopup(self.player.x,self.player.y-22,"NOT ENOUGH BAG SPACE","miss") end
    elseif choice=="Open" and (name=="Rune Bag" or require('game.advanced_gear').isQuiver(name)) then self.open.ammoContainer=true;self:log("AMMO_CONTAINER_OPENED",{item=name})
    elseif choice=="Unequip" and name then local storeName=(name=="Lit Torch") and "Torch" or name;local ok;if c.slot=="ammo" and type(equipped)=="table" then if require('game.advanced_gear').isQuiver(equipped.name) or equipped.name=="Rune Bag" then local obj={};for k,v in pairs(equipped) do obj[k]=v end;ok=self.inv:addItemObject(obj) else ok=self.inv:add(equipped.name,equipped.qty or 1) end else local obj=require("game.items").equipped(self,c.slot);if obj.name~=storeName then obj=require("game.items").copy(obj);obj.name=storeName end;ok=self.inv:addItemObject(obj) end;if ok then if c.slot=="ammo" then self.open.ammoContainer=false end;require("game.items").setEquipped(self,c.slot,nil);if c.slot=="weapon" then self.player.equipped=nil end;self:log("ITEM_UNEQUIPPED",{item=storeName,slot=c.slot,extinguished=tostring(name=="Lit Torch")}) else self:log("ITEM_UNEQUIP_BLOCKED",{item=name,slot=c.slot,reason="bags_full"}) end end
    self.equipmentContext=nil;return true end end;self.equipmentContext=nil;return true
 end
 if self.context then if button==1 then local c=self.context;local x,y=c.drawX,c.drawY;local opts=c.options or {};if x and inside(mx,my,x,y+20,150,#opts*25) then local idx=math.floor((my-(y+20))/25)+1;if opts[idx] then self:doContextOption(opts[idx]);return true end end;self.context=nil;return true else self.context=nil;return true end end
 -- Ammo containers are real slot inventories: click a loaded slot to pull it back out.
 if self.open.ammoContainer then local x,y,ww,hh=self:ammoContainerRect();if button==1 and inside(mx,my,x+ww-28,y+3,24,24) then self.open.ammoContainer=false;return true elseif button==1 and inside(mx,my,x,y,ww,30) then self.windowDrag={name='ammoContainer',ox=mx-x,oy=my-y};return true end;local asi=self:ammoContainerSlotAt(mx,my);if asi and button==1 then self:withdrawAmmoContainerSlot(asi);return true end end
 -- Combined inventory uses one normal slot grid with no bag artwork.
 if self.bagnonMode then local any=false;for i=1,self.inv:bagSlotCount() do if self.bagOpen[i] then any=true end end;if any then local x,y,ww,hh=self:combinedRect();if button==1 and inside(mx,my,x+ww-28,y+3,24,24) then for i=1,self.inv:bagSlotCount() do self.bagOpen[i]=false end;self.open.inventory=false;return true elseif button==1 and inside(mx,my,x,y,ww,30) then self.windowDrag={name="inventory",ox=mx-x,oy=my-y};return true end end end
 -- Each equipped bag is its own draggable window and can stay open with the others.
 if not self.bagnonMode then for bi=self.inv:bagSlotCount(),1,-1 do if self.bagOpen[bi] and self.inv.bagSlots[bi] then local x,y,ww,hh=self:bagWindowRect(bi);if button==1 and inside(mx,my,x+ww-28,y+3,24,24) then self.bagOpen[bi]=false;self.open.inventory=self.bagOpen[1] or self.bagOpen[2] or self.bagOpen[3] or self.bagOpen[4];self:log("BAG_TOGGLED",{bagSlot=bi,state="closed",source="close_button"});return true elseif button==1 and inside(mx,my,x,y,ww,30) then self.windowDrag={name="bag",bag=bi,ox=mx-x,oy=my-y};self.inv:setActiveBag(bi);self.context=nil;self:log("WINDOW_DRAG_STARTED",{window="bag"..bi});return true end end end end
 -- Window headers are draggable. Check bank first because windows may overlap.
 for zi=#self.zOrder,1,-1 do local name=self.zOrder[zi];if self.open[name] then local x,y,ww=self:rect(name);if button==1 and inside(mx,my,x+ww-28,y+3,24,24) then self:close(name,"close_button");return true elseif button==1 and inside(mx,my,x,y,ww,30) then self:bringToFront(name);self:startWindowDrag(name,mx,my);return true end end end
 if self.open.equipment then local es=self:equipmentSlotAt(mx,my);if es and self.equipment[es] then if button==2 then self.equipmentContext={slot=es,x=mx,y=my};return true end end end
 if not self.inputPanel then
 self:ensureHudPos(w,h)
 if button==1 and love.keyboard.isDown("lctrl","rctrl") and require("game.abilities").hasWeapon(self) then local ax,ay,aw,ah=self:weaponHotbarRect(w,h);if inside(mx,my,ax,ay,aw,ah) then self.hudDrag={name="weaponHotbar",ox=mx-ax,oy=my-ay};return true end end
 if button==1 and love.keyboard.isDown("lctrl","rctrl") and self.equipment.offhand=="Spellbook" then local hx,hy,hw,hh=self:magicHotbarRect(w,h);if inside(mx,my,hx,hy,hw,hh) then self.hudDrag={name="magicHotbar",ox=mx-hx,oy=my-hy};self:log("HUD_DRAG_STARTED",{hud="magicHotbar"});return true end end
 if button==1 and love.keyboard.isDown("lctrl","rctrl") and (#self.levelToasts>0 or #self.world.notifications>0) then local nx,ny,nw,nh=self:notificationRect(w,h);if inside(mx,my,nx,ny,nw,nh) then self.hudDrag={name="notifications",ox=mx-nx,oy=my-ny};self:log("HUD_DRAG_STARTED",{hud="notifications"});return true end end
 if button==1 then
  local bx,by,bw,bh=self:bagBarRect(w,h)
  if inside(mx,my,bx,by,bw,bh) and not self:bagSlotAt(mx,my,w,h) then self.hudDrag={name="bagBar",ox=mx-bx,oy=my-by};self:log("HUD_DRAG_STARTED",{hud="bagBar"});return true end
  local px,py,pw,ph=self:potionBeltRect(w,h)
  if inside(mx,my,px,py,pw,ph) and not self:potionSlotAt(mx,my,w,h) then self.hudDrag={name="potionBelt",ox=mx-px,oy=my-py};self:log("HUD_DRAG_STARTED",{hud="potionBelt"});return true end
  local ex,ey,ew,eh=self:menuButtonsRect(w,h)
  if inside(mx,my,ex,ey,ew,eh) and not inside(mx,my,ex+8,ey+6,104,42) and not inside(mx,my,ex+118,ey+6,104,42) and not inside(mx,my,ex+228,ey+6,104,42) and not inside(mx,my,ex+338,ey+6,104,42) then self.hudDrag={name="menuButtons",ox=mx-ex,oy=my-ey};self:log("HUD_DRAG_STARTED",{hud="menuButtons"});return true end
 end
 if require("game.abilities").hasWeapon(self) then
  local as=self:weaponHotbarSlotAt(mx,my,w,h)
  if as then
   local bar=self:currentWeaponHotbar()
   if button==2 then if bar and bar[as] then local removed=bar[as];bar[as]=nil;self:log("ABILITY_HOTBAR_REMOVED",{ability=removed,slot=as,weapon=self.equipment.weapon,source="right_click"}) end;return true end
   if button==1 then self.weaponHotbarPress={slot=as,x=mx,y=my,weapon=self.equipment.weapon,name=bar and bar[as]};return true end
  end
 end
 if self.equipment.offhand=="Spellbook" then local hx,hy=self:magicHotbarRect(w,h);for i=1,6 do if inside(mx,my,hx+7+(i-1)*53,hy+6,46,42) then
  if button==2 then local page=self.spellPages[i];if page then if self.inv:add(page,1) then self.spellPages[i]=nil;self:log("SPELL_HOTBAR_REMOVED",{page=page,slot=i,source="right_click"}) else self.world:addPopup(self.player.x,self.player.y-22,"BAGS FULL","miss") end end;return true end
  if button==1 then self.magicHotbarPress={slot=i,x=mx,y=my,page=self.spellPages[i]};return true end
 end end end
 local ps=self:potionSlotAt(mx,my,w,h);if ps then if button==1 then self:usePotion(ps);return true elseif button==2 then local name=self.potionBelt[ps];if name then if self.inv:add(name,1) then self.potionBelt[ps]=nil;self:log("POTION_BELT_UNEQUIPPED",{item=name,slot=ps}) else self:log("POTION_BELT_UNEQUIP_BLOCKED",{item=name,slot=ps,reason="bags_full"}) end end;return true end end
 local bs=self:bagSlotAt(mx,my,w,h);if bs then local bag=self.inv.bagSlots[bs];if bag then if button==2 then self.bagContext={slot=bs,x=mx,y=my};return true end;self.inv:setActiveBag(bs);if self.bagnonMode then local any=false;for i=1,self.inv:bagSlotCount() do if self.bagOpen[i] then any=true end end;for i=1,self.inv:bagSlotCount() do self.bagOpen[i]=self.inv.bagSlots[i] and not any or false end else self.bagOpen[bs]=not self.bagOpen[bs] end;self.open.inventory=self.bagOpen[1] or self.bagOpen[2] or self.bagOpen[3] or self.bagOpen[4];self:log("BAG_TOGGLED",{bagSlot=bs,state=self.bagOpen[bs] and "open" or "closed",combined=tostring(self.bagnonMode)}) end;return true end
 local mbx,mby=self:menuButtonsRect(w,h)
 if inside(mx,my,mbx+8,mby+6,104,42) then self:toggle("equipment","mouse_tab");return true end
 if inside(mx,my,mbx+118,mby+6,104,42) then self:toggle("skills","mouse_tab");return true end
 if inside(mx,my,mbx+228,mby+6,104,42) then self:toggle("mercBand","mouse_tab");return true end
 if inside(mx,my,mbx+338,mby+6,104,42) then self.notificationsEnabled=not self.notificationsEnabled;if not self.notificationsEnabled then self.levelToasts={};self.world.notifications={} end;self:log("NOTIFICATIONS_TOGGLED",{enabled=tostring(self.notificationsEnabled)});return true end
 end
 if self.open.skills and button==1 then local x,y=self:rect("skills");for i,t in ipairs({"Combat","Gathering","Production","Other"}) do if inside(mx,my,x+12+(i-1)*80,y+34,74,26) then self.skillsTab=t;self.skillsScroll=0;return true end end end
 if self.open.mercBand then local x,y,w2,h2=self:rect("mercBand");if inside(mx,my,x,y,w2,h2) then self:bringToFront("mercBand");if button==1 then for i,m in ipairs(self.world.mercs) do local bx=x+18+(i-1)*112;if inside(mx,my,bx,y+62,104,28) then self.selectedMerc=i;self.open.mercSkills=true;self:bringToFront("mercSkills");self:log("MERCENARY_SKILLS_OPENED",{merc=m.name,role=m.role});return true end end end;if button==2 then
  for i,m in ipairs(self.world.mercs) do local bx=x+18+(i-1)*112;if inside(mx,my,bx,y+62,104,28) then self.selectedMerc=i;self.mercContext={index=i,x=mx,y=my};return true end end
  local m=self.world.mercs[self.selectedMerc or 1];if m then m.equipment=m.equipment or {};for i,key in ipairs({"head","body","legs","cape","weapon","offhand","ammo"}) do local yy=y+164+(i-1)*42;if inside(mx,my,x+18,yy,w2-36,34) and m.equipment[key] then local equipped=m.equipment[key];local name=type(equipped)=="table" and equipped.name or equipped;local qty=type(equipped)=="table" and (equipped.qty or 1) or 1;if self.inv:addItemObject(require("game.items").equipped(m,key)) then require("game.items").setEquipped(m,key,nil);self.world:addPopup(self.player.x,self.player.y-22,"UNEQUIPPED "..string.upper(name),"defeat");self:log("MERCENARY_UNEQUIPPED",{merc=m.name,item=name,slot=key}) else self.world:addPopup(self.player.x,self.player.y-22,"BAGS FULL","miss") end;return true end end end end;return true end end
 if self.open.spellbook then local x,y,w2,h2=self:rect("spellbook");if inside(mx,my,x,y,w2,h2) then self:bringToFront("spellbook");if button==1 then for i=1,6 do local px=x+18+(i-1)*58;local py=y+98;if inside(mx,my,px,py,48,48) and self.spellPages[i] then local page=self.spellPages[i];if self.inv:add(page,1) then self.spellPages[i]=nil;self.world:addPopup(self.player.x,self.player.y-22,"PAGE REMOVED","defeat");self:log("SPELL_PAGE_REMOVED",{page=page,slot=i}) else self.world:addPopup(self.player.x,self.player.y-22,"BAGS FULL","miss") end;return true end end end;return true end end
 if self.open.mercenary then local x,y,w2,h2=self:rect("mercenary");if inside(mx,my,x,y,w2,h2) then self:bringToFront("mercenary");if button==1 then for i,role in ipairs({"Tank","Healer","Ranged"}) do local bx=x+16+(i-1)*118;if inside(mx,my,bx,y+66,108,30) then self:recruitMerc(role);return true end end;for i,m in ipairs(self.world.mercs) do if inside(mx,my,x+16,y+132+(i-1)*46,w2-32,40) then self.selectedMerc=i;return true end end end;return true end end
 if self.open.smelter or self.open.anvil or self.open.woodcraft or self.open.loom or self.open.spinningWheel or self.open.alchemy or self.open.sewing or self.open.stove or self.open.leathercraft or self.open.campfire or self.open.inscription or self.open.tailoring then for _,station in ipairs({"smelter","anvil","woodcraft","loom","spinningWheel","alchemy","sewing","stove","leathercraft","campfire","inscription","tailoring"}) do if self.open[station] then local x,y,ww,hh=self:rect(station);if inside(mx,my,x,y,ww,hh) then self:bringToFront(station);local tab=CookingTabs.tabAt(self,station,mx,my);if tab then if button==1 then CookingTabs.select(self,station,tab)end;return true end;local ri=self:craftRecipeAt(station,mx,my);if ri and button==1 then self:startCraft(station,ri);return true end;return true end end end end
 if self.open.bankClerk then local x,y,ww,hh=self:rect("bankClerk");if inside(mx,my,x,y,ww,hh) then self:bringToFront("bankClerk");if button==1 and inside(mx,my,x+18,y+126,ww-36,34) and (self.inv.bankSize or 25)<250 then local cost=self.inv:bankUpgradeCost();if self.inv:moneyCopper()>=cost then self.inv:removeMoney(cost);local newSize=self.inv:upgradeBank(25);self.world:addPopup(self.player.x,self.player.y-24,"BANK EXPANDED TO "..tostring(newSize).." SLOTS","defeat");self:log("BANK_EXPANDED",{slots=newSize,cost=cost,tabs=math.ceil(newSize/50)}) else self.world:addPopup(self.player.x,self.player.y-24,"NEED "..string.upper(self.inv:moneyText(cost)),"miss") end end;return true end end
 if self.open.shop then local x,y,ww,hh=self:rect("shop");local offset=ShopTabs.offset(self);local tab=ShopTabs.tabAt(self,mx,my);if tab then if button==1 then ShopTabs.select(self,tab)end;return true end;if button==1 and inside(mx,my,x+12,y+274+offset,118,30)then self:sellShopInventory();return true end;if button==1 and inside(mx,my,x+138,y+274+offset,120,30)then if self.selectedShop==self.shop then for i,row in ipairs(self.shop.slots)do if row==self.selectedShopRow then self.shopContext={slot=i};self:doShopContext('Buy All');break end end end;return true end;if inside(mx,my,x,y,ww,hh) then self:bringToFront("shop") end;local s=self:shopSlotAt(mx,my);if s then if button==2 then self.lastShopClick=nil;self.shopContext={slot=s,x=mx,y=my};return true elseif button==1 then self:shopDoubleClick(s,mx,my);return true end end;local x,y,ww,hh=self:rect("shop");if inside(mx,my,x,y,ww,hh) then return true end end
 if self.open.bank then local x,y,ww,hh=self:rect("bank");if inside(mx,my,x,y,ww,hh) then self:bringToFront("bank") end;if button==1 and inside(mx,my,x+20,y+522,226,30) then local ok,count=self.inv:depositEverything();self:log("BANK_DEPOSIT_EVERYTHING",{success=tostring(ok),items=count or 0});return true end;local pages=math.max(1,math.ceil((self.inv.bankSize or 25)/50));local tabW=math.min(42,math.floor(226/pages));if button==1 and inside(mx,my,x+20,y+38,tabW*pages,24) then local pg=math.floor((mx-(x+20))/tabW)+1;if pg>=1 and pg<=pages then self.bankPage=pg;self.bankContext=nil;return true end end;local s=self:bankSlotAt(mx,my);if s and button==2 and self.inv.bank[s] then self.bankContext={slot=s,x=mx,y=my};return true elseif s and button==1 then return true end;local x,y,ww,hh=self:rect("bank");if inside(mx,my,x,y,ww,hh) then return true end end
 self._combinedClickBag=nil;local displayMx,displayMy=mx,my;if self.bagnonMode then local cbi,csi=self:combinedSlotAt(mx,my);if cbi then self._combinedClickBag=cbi; local sx,sy=self:itemGridOrigin(cbi);local col=(csi-1)%5;local row=math.floor((csi-1)/5);mx,my=sx+col*43+10,sy+row*43+10 end end
 for bi=self.inv:bagSlotCount(),1,-1 do if self.bagOpen[bi] and self.inv.bagSlots[bi] then local x,y,ww,hh=self:bagWindowRect(bi);local s=self:slotAt(mx,my,bi);if self.bagnonMode and bi~=self._combinedClickBag then s=nil end;if s then self.inv:setActiveBag(bi);local b=self.inv:getBag(bi);local it=b.slots[s];if button==1 and self.useTarget then if it and self:isUseCompatible(self.useTarget.tool,it) then self:startItemUse(bi,s) else self:cancelItemUse("incompatible_inventory_target") end;return true elseif button==2 and it then self.context={bag=bi,slot=s,x=displayMx,y=displayMy};return true elseif button==1 then if it then if ShopTabs.sellClick(self,bi,s,displayMx,displayMy)then return true end;local info=self.sprites.itemInfo[it.name];if it.name=="Brown Mushroom" or it.name=="Red Berries" or it.name=="Purple Berries" or (info and (info.type=="Food" or info.type=="Burnt Food")) then self.context={bag=bi,slot=s,x=displayMx,y=displayMy};self:doContextOption("Eat");self.context=nil;return true end;self.dragSlot=s;self.dragBagIndex=bi;self.dragStartX=displayMx;self.dragStartY=displayMy;self:log("INVENTORY_DRAG_STARTED",{bag=bi,slot=s,item=it.name}) end;return true end elseif not self.bagnonMode and inside(mx,my,x,y,ww,hh) then self.inv:setActiveBag(bi);if button==1 and self.useTarget then self:cancelItemUse("blank_inventory_area") end;return true end end end
 for zi=#self.zOrder,1,-1 do local name=self.zOrder[zi];if name~="inventory" and self.open[name] then local x,y,ww,hh=self:rect(name);if inside(mx,my,x,y,ww,hh) then if button==1 and self.useTarget then self:cancelItemUse("other_ui") end;return true end end end
 if button==1 and self.useTarget then self:cancelItemUse("outside_inventory");return true end
 return false
end
function UI:performItemUse(bi,s)
 local b=self.inv:getBag(bi);local it=b and b.slots[s];if not b or not self.useTarget then return end
 local requirement=it and require("game.unlocks").itemUse(self.useTarget.tool,it.name)
 if requirement then local ok,why=require("game.unlocks").check(self.skills,requirement[1],requirement[2]);if not ok then self.world:addPopup(self.player.x,self.player.y-24,why);self.useTarget=nil;return false,why end end
 if it and self.useTarget.tool=="Flint and Steel" and (it.name=="Pine Logs" or it.name=="Oak Logs" or it.name=="Poplar Logs" or it.name=="Logs") then local ok,res;if require('game.multiplayer').active then ok,res=require('game.fieldcraft_ui').command(self,{op='fireCreate',fuel=it.name})else ok,res=self.world:createCampfire(self.player,self.inv,self.skills,self.logger,it.name)end;self:log("ITEM_USED_ON_ITEM",{tool=self.useTarget.tool,target=it.name,result=tostring(res),success=tostring(ok)});self.useTarget=nil
 elseif it and (self.useTarget.tool=="Copper Dagger" or self.useTarget.tool=="Copper Knife") and (it.name=="Pine Logs" or it.name=="Oak Logs" or it.name=="Poplar Logs" or it.name=="Logs") then self.open.woodcraft=true;self:bringToFront("woodcraft");self:log("ITEM_USED_ON_ITEM",{tool=self.useTarget.tool,target=it.name,result="woodworking_opened"});self.useTarget=nil
 elseif it and self.useTarget.tool=="Needle" and (it.name=="Dyed Blue Cloth Strip" or it.name=="Dark Blue Cloth") then self.open.tailoring=true;self:bringToFront("tailoring");self:log("ITEM_USED_ON_ITEM",{tool=self.useTarget.tool,target=it.name,result="sewing_opened"});self.useTarget=nil
 elseif it and self.useTarget.tool=="Needle" and (it.name:find("Leather",1,true) or it.name:find("Hide",1,true) or it.name=="Linen Thread") then self.open.leathercraft=true;self:bringToFront("leathercraft");self:log("ITEM_USED_ON_ITEM",{tool=self.useTarget.tool,target=it.name,result="leatherworking_opened"});self.useTarget=nil
 elseif it and self.useTarget.tool=="Blue Dye" and it.name=="Cloth Strip" then
  local dyeBag,dyeSlot=self.useTarget.bag,self.useTarget.slot
  local dye=self.inv.bagSlots[dyeBag] and self.inv.bagSlots[dyeBag].slots[dyeSlot]
  if dye and dye.name=="Blue Dye" then
   self.inv:removeItems("Blue Dye",1);self.inv:removeItems("Cloth Strip",1);require('game.quality').add(self.inv,"Dyed Blue Cloth Strip",1,self.skills:get('Tailoring').level,require('game.inventory').add)
   local old,new,total=self.skills:addXP("Tailoring",3);self:log("CLOTH_DYED",{dye="Blue Dye",target="Cloth Strip",output="Dyed Blue Cloth Strip",xpGained=3,totalXp=total})
   if new>old then self:log("SKILL_LEVEL_UP",{skill="Tailoring",from=old,to=new,totalXp=total}) end
  end
  self.useTarget=nil
 elseif it and (self.useTarget.tool=="Copper Dagger" or self.useTarget.tool=="Copper Knife") and it.name=="Feather" then
  if require('game.multiplayer').active then self.useTarget=nil;return require('game.fieldcraft_ui').command(self,{op='carveFeather'},function(ok)if ok then self:continueFeatherBatch()else self.featherBatch=nil end end)end
  local ok,result,xp=require('game.religion').carveFeather(self.inv,self.skills)
  if ok then self.world:addPopup(self.player.x,self.player.y-22,'CARVED FEATHER  +'..tostring(xp)..' RELIGION XP','defeat');self:log('RUNE_MATERIAL_PREPARED',{source='Feather',output='Carved Feather',qty=1,skill='Religion',xpGained=xp,totalXp=self.skills:get('Religion').xp})
  else self.world:addPopup(self.player.x,self.player.y-22,result,'miss')end
  self.useTarget=nil
 elseif it and self.useTarget.tool=="Chisel" and it.name=="Cut Onyx" then
  require('game.jewels').process(self,bi,s);self.useTarget=nil
 elseif it and self.useTarget.tool=="Empty Tube" and it.name=="Green Slime Jar" then
  local remaining=it.slimeRemaining or 5
  if remaining>0 and self.inv:canAdd("Green Slime Tube",1) then self.inv:removeItems("Empty Tube",1);require('game.quality').add(self.inv,"Green Slime Tube",1,self.skills:get('Alchemy').level,require('game.inventory').add);remaining=remaining-1;if remaining<=0 then b.slots[s]=nil;self.inv:add("Empty Flask",1) else it.slimeRemaining=remaining end;self.world:addPopup(self.player.x,self.player.y-22,"GREEN SLIME TUBE "..(5-remaining).."/5","defeat");self:log("SLIME_TUBE_FILLED",{remaining=remaining,capacity=5}) end;self.useTarget=nil
 elseif it and self.useTarget.tool=="Bow String" and (it.name=="Pine Unstrung Bow" or it.name=="Oak Unstrung Bow" or it.name=="Unstrung Bow") then
  local wood=it.name:match("^(%a+) Unstrung Bow$") or "Pine";local unstrung=wood.." Unstrung Bow";local bow=wood.." Bow";local n=math.min(1,self.inv:countItem("Bow String"),self.inv:countItem(unstrung));if n>0 and self.inv:canAdd(bow,n) then self.inv:removeItems("Bow String",n);self.inv:removeItems(unstrung,n);require('game.quality').add(self.inv,bow,n,self.skills:get('Fletching').level,require('game.inventory').add);local old,new,total=self.skills:addXP("Fletching",n*6);self:log("BOWS_STRUNG",{qty=n,xpGained=n*6,totalXp=total});if new>old then self:log("SKILL_LEVEL_UP",{skill="Fletching",from=old,to=new,totalXp=total}) end end;self.useTarget=nil
 elseif it and self.useTarget.tool=="Copper Arrowheads" and (it.name=="Pine Arrow Shafts" or it.name=="Oak Arrow Shafts" or it.name=="Arrow Shafts") then
  local shafts=it.name;local n=math.min(1,self.inv:countItem("Copper Arrowheads"),self.inv:countItem(shafts));if n>0 and self.inv:canAdd("Copper Arrows",n) then self.inv:removeItems("Copper Arrowheads",n);self.inv:removeItems(shafts,n);require('game.quality').add(self.inv,"Copper Arrows",n,self.skills:get('Fletching').level,require('game.inventory').add);local old,new,total=self.skills:addXP("Fletching",n);self:log("ARROWS_ASSEMBLED",{qty=n,xpGained=n,totalXp=total});if new>old then self:log("SKILL_LEVEL_UP",{skill="Fletching",from=old,to=new,totalXp=total}) end end;self.useTarget=nil
 elseif it and self.useTarget.tool=="Iron Arrowheads" and (it.name=="Pine Arrow Shafts" or it.name=="Oak Arrow Shafts" or it.name=="Arrow Shafts") then
  local ok,reason=require("game.unlocks").check(self.skills,"Fletching",20);if not ok then self.world:addPopup(self.player.x,self.player.y-22,"FLETCHING 20 REQUIRED","miss")
  elseif self.inv:countItem("Feather")<1 then self.world:addPopup(self.player.x,self.player.y-22,"NEED FEATHER","miss")
  elseif self.inv:canAdd("Iron Arrows",1) then local shafts=it.name;self.inv:removeItems("Iron Arrowheads",1);self.inv:removeItems("Feather",1);self.inv:removeItems(shafts,1);require('game.quality').add(self.inv,"Iron Arrows",1,self.skills:get('Fletching').level,require('game.inventory').add);local old,new,total=self.skills:addXP("Fletching",3);self:log("IRON_ARROW_ASSEMBLED",{shaft=shafts,qty=1,xpGained=3,totalXp=total});if new>old then self:log("SKILL_LEVEL_UP",{skill="Fletching",from=old,to=new,totalXp=total}) end end;self.useTarget=nil
 elseif it and self.useTarget.tool=="Chisel" and (it.name=="Ruby-bearing Rock" or it.name=="Sapphire-bearing Rock" or it.name=="Emerald-bearing Rock") then
  local extracts={ ["Ruby-bearing Rock"]={out="Rough Ruby",xp=4},["Sapphire-bearing Rock"]={out="Rough Sapphire",xp=6},["Emerald-bearing Rock"]={out="Rough Emerald",xp=8} };local r=extracts[it.name]
  if self.inv:countItem("Copper Hammer")<1 and self.player.equipped~="Copper Hammer" then self.world:addPopup(self.player.x,self.player.y-22,"NEED COPPER HAMMER","miss");self:log("JEWEL_EXTRACT_BLOCKED",{stone=it.name,reason="missing_hammer"})
  else local stone=it.name;local lv=self.skills:get("Jewel Crafting").level;local chance=require('game.jewel_progression').extractionChance(lv);if math.random()<=chance then b.slots[s]={name=r.out,qty=1,qualityGrade=require('game.quality').roll(lv)};local old,new,total=self.skills:addXP("Jewel Crafting",r.xp);self.world:addPopup(self.player.x,self.player.y-22,"EXTRACTED "..string.upper(r.out),"defeat");self:log("JEWEL_EXTRACT",{stone=stone,rough=r.out,chance=chance,xpGained=r.xp,totalXp=total});if new>old then self:log("SKILL_LEVEL_UP",{skill="Jewel Crafting",from=old,to=new,totalXp=total}) end else local dust=r.out:gsub("Rough ","").." Dust";b.slots[s]={name=dust,qty=1,qualityGrade=require('game.quality').roll(lv)};self.world:addPopup(self.player.x,self.player.y-22,"GEM BROKE - "..string.upper(dust),"miss");self:log("JEWEL_EXTRACT_FAILED",{stone=stone,dust=dust,chance=chance}) end end;self.useTarget=nil
 elseif it and self.useTarget.tool=="Chisel" and require('game.jewels').cuts[it.name] then
  require('game.jewels').process(self,bi,s);self.useTarget=nil
 elseif it and (self.useTarget.tool=="Copper Dagger" or self.useTarget.tool=="Copper Knife") and (it.name=="Small Fish" or it.name=="Large Fish" or it.name=="Eel" or it.name=="Swordfish" or it.name=="Tuna" or it.name=="Shark" or it.name=="Manta Ray") then
  local fish=it.name;local yield=require("game.high_tier_fish").data[fish] and require("game.high_tier_fish").fillets(fish,self.skills:get("Cooking").level) or fish=="Small Fish" and 1 or (fish=="Large Fish" and require('game.fishing_tiers').largeFillets(self.skills:get("Cooking").level) or math.max(1,math.min(5,math.random(1,2)+math.floor(self.skills:get("Cooking").level/20))))
  if self.inv:canAdd("Raw Fish Fillet",yield) then self.inv:removeItems(fish,1);require('game.rune_drops').drop(self.world,'Fish Bones',3,self.player,self.player);for n=1,yield do require('game.quality').add(self.inv,"Raw Fish Fillet",1,self.skills:get('Cooking').level,require('game.inventory').add) end;local old,new,total=self.skills:addXP("Cooking",yield*2);self:log("FISH_FILLETED",{fish=fish,fillets=yield,cookingLevel=new,totalXp=total});if new>old then self:log("SKILL_LEVEL_UP",{skill="Cooking",from=old,to=new,totalXp=total}) end end
  self.useTarget=nil
 else self:log("ITEM_USE_TARGET_INVALID",{tool=self.useTarget.tool,target=it and it.name or "empty"});self.useTarget=nil end
end
function UI:findInventoryItem(name)
 for bi=1,4 do local b=self.inv:getBag(bi);if b then for si=1,b.size do local it=b.slots[si];if it and it.name==name then return bi,si,it end end end end
 return nil
end
function UI:isBatchableItemUse(tool,target)
 if tool=="Copper Dagger" or tool=="Copper Knife" then return target=="Feather" or target=="Small Fish" or target=="Large Fish" or target=="Eel" or target=="Swordfish" or target=="Tuna" or target=="Shark" or target=="Manta Ray" end
 if tool=="Blue Dye" then return target=="Cloth Strip" end
 if tool=="Bow String" then return target=="Pine Unstrung Bow" or target=="Oak Unstrung Bow" or target=="Unstrung Bow" end
 if tool=="Copper Arrowheads" then return target=="Pine Arrow Shafts" or target=="Oak Arrow Shafts" or target=="Arrow Shafts" end
 if tool=="Chisel" then return target=="Cut Onyx" or target=="Rough Onyx" or target=="Ruby-bearing Rock" or target=="Sapphire-bearing Rock" or target=="Emerald-bearing Rock" or target=="Rough Ruby" or target=="Rough Sapphire" or target=="Rough Emerald" end
 if tool=="Empty Tube" then return target=="Green Slime Jar" end
 return false
end
function UI:continueFeatherBatch()
 local batch=self.featherBatch;if not batch then return false end
 if self.inv:countItem('Feather')<1 or (self.player.x-batch.x)^2+(self.player.y-batch.y)^2>4 or not require('game.tool_slot').has(self.inv,nil,'Copper Knife',self.player)then self.featherBatch=nil;return false end
 if self.campPending or self.craftJob then return false end
 return require('game.fieldcraft_ui').command(self,{op='carveFeather'},function(ok)if ok then self:continueFeatherBatch()else self.featherBatch=nil end end)
end
function UI:queueItemBatchStep(tool,targetName)
 if targetName=='Feather'and require('game.multiplayer').active then self.featherBatch={x=self.player.x,y=self.player.y};self.useTarget=nil;return self:continueFeatherBatch()end
 if self.craftJob or self.magicCast or self.world.workJob then return false end
 local tbi,tsi,target=self:findInventoryItem(targetName);if not target then self:log("ITEM_USE_BATCH_FINISHED",{tool=tool,target=targetName,reason="no_targets"});return false end
 local sbi,ssi,source,equipped=self:findUseSource(tool);if not source then self:log("ITEM_USE_BATCH_FINISHED",{tool=tool,target=targetName,reason="no_tool_or_material"});return false end
 if not self:isUseCompatible(tool,target) then return false end
 local requirement=require("game.unlocks").itemUse(tool,targetName)
 if requirement then local ok,why=require("game.unlocks").check(self.skills,requirement[1],requirement[2]);if not ok then self.world:addPopup(self.player.x,self.player.y-24,why);return false end end
 local use={tool=tool,bag=sbi,slot=ssi,equipmentSlot=equipped and "tool"or nil,equippedName=equipped and source.name or nil}
 self.craftJob={name=tool.." + "..targetName,timer=0,duration=require("game.high_tier_fish").duration(targetName),x=self.player.x,y=self.player.y,batch=true,itemUseBatch=true,finish=function()
  local nb,ns,nt=self:findInventoryItem(targetName);local ub,us,ut,eq=self:findUseSource(tool)
  if not nt or not ut then return end
  local before=self.inv:countItem(targetName);self.useTarget={tool=tool,bag=ub,slot=us,equipmentSlot=eq and "tool"or nil,equippedName=eq and ut.name or nil};self:performItemUse(nb,ns);if self.inv:countItem(targetName)>=before then self.world:addPopup(self.player.x,self.player.y-22,"BATCH STOPPED: CHECK REQUIREMENTS / BAG SPACE","miss");return end
  -- performItemUse intentionally handles exactly one item. Queue another timed
  -- cycle only if the same input type and required source still exist.
  self:queueItemBatchStep(tool,targetName)
 end}
 return true
end
function UI:startItemUse(bi,slot)
 if self.craftJob or self.magicCast or self.world.workJob then return false end
 local b=self.inv:getBag(bi);local it=b and b.slots[slot];local use=self.useTarget
 if not it or not use then return false end
 local tool=use.tool
 local requirement=require("game.unlocks").itemUse(tool,it.name)
 if requirement then local ok,why=require("game.unlocks").check(self.skills,requirement[1],requirement[2]);if not ok then self.world:addPopup(self.player.x,self.player.y-24,why);return false,why end end
 if self:isBatchableItemUse(tool,it.name) then
  local targetName=it.name;self.useTarget=nil;self:log("ITEM_USE_BATCH_STARTED",{tool=tool,target=targetName});return self:queueItemBatchStep(tool,targetName)
 end
 if tool=="Needle" or ((tool=="Copper Knife" or tool=="Copper Dagger") and it.name:find("Logs")) then self:performItemUse(bi,slot);return true end
 local tb=self.inv:getBag(use.bag);local originalTool=use.equipmentSlot and require("game.tool_slot").object(self)or(tb and tb.slots[use.slot])
 self.useTarget=nil
 self.craftJob={name=tool.." + "..it.name,timer=0,duration=require("game.high_tier_fish").duration(it.name),x=self.player.x,y=self.player.y,finish=function()
  if b.slots[slot]~=it then return end;if use.equipmentSlot then local current=require("game.tool_slot").object(self);if not current or current.name~=originalTool.name then return end elseif not tb or tb.slots[use.slot]~=originalTool then return end
  self.useTarget=use;self:performItemUse(bi,slot)
 end}
 return true
end
function UI:pointerOverUI(mx,my,w,h)
 self:ensureHudPos(w,h)
 for _,name in ipairs(self.zOrder) do if self.open[name] then local x,y,ww,hh=self:rect(name);if inside(mx,my,x,y,ww,hh) then return true end end end
 if self.open.ammoContainer then local x,y,ww,hh=self:ammoContainerRect();if inside(mx,my,x,y,ww,hh) then return true end end
 if self.bagnonMode then local any=false;for i=1,self.inv:bagSlotCount() do if self.bagOpen[i] then any=true end end;if any then local x,y,ww,hh=self:combinedRect();if inside(mx,my,x,y,ww,hh) then return true end end else for i=1,self.inv:bagSlotCount() do if self.bagOpen[i] and self.inv.bagSlots[i] then local x,y,ww,hh=self:bagWindowRect(i);if inside(mx,my,x,y,ww,hh) then return true end end end end
 local x,y,ww,hh=self:bagBarRect(w,h);if inside(mx,my,x,y,ww,hh) then return true end;x,y,ww,hh=self:potionBeltRect(w,h);if inside(mx,my,x,y,ww,hh) then return true end;x,y,ww,hh=self:menuButtonsRect(w,h);if inside(mx,my,x,y,ww,hh) then return true end
 if require("game.abilities").hasWeapon(self) then local x,y,ww,hh=self:weaponHotbarRect(w,h);if inside(mx,my,x,y,ww,hh) then return true end end
 if self.equipment.offhand=="Spellbook" then local x,y,ww,hh=self:magicHotbarRect(w,h);if inside(mx,my,x,y,ww,hh) then return true end end
 return false
end
function UI:mousemoved(mx,my,dx,dy,w,h)
 if self.weaponHotbarPress and self.weaponHotbarPress.name then local p=self.weaponHotbarPress;if math.sqrt((mx-p.x)^2+(my-p.y)^2)>8 then local bar=self:currentWeaponHotbar();if bar and self.equipment.weapon==p.weapon and bar[p.slot]==p.name then bar[p.slot]=nil;self.abilityDrag={name=p.name,source='hotbar',fromSlot=p.slot,weapon=p.weapon};self:log('ABILITY_HOTBAR_DRAG_STARTED',{ability=p.name,slot=p.slot,weapon=p.weapon}) end;self.weaponHotbarPress=nil;return true end end
 if self.magicHotbarPress and self.magicHotbarPress.page then local p=self.magicHotbarPress;if math.sqrt((mx-p.x)^2+(my-p.y)^2)>8 then self.magicHotbarPress=nil;self.magicPageDrag={page=p.page,fromSlot=p.slot};return true end end
 if self.hudDrag then local d=self.hudDrag;local sizes={bagBar={174*(self.hudScale.bagBar or 1),54*(self.hudScale.bagBar or 1)},potionBelt={180*(self.hudScale.potionBelt or 1),54*(self.hudScale.potionBelt or 1)},menuButtons={456,54},magicHotbar={326,54},weaponHotbar={220,54},notifications={360,math.max(46,math.min(2,#self.levelToasts)*52+math.min(3,#self.world.notifications)*52-6)}};local z=sizes[d.name];local p=self.hudPos[d.name];p.x=math.max(0,math.min(w-z[1],mx-d.ox));p.y=math.max(0,math.min(h-z[2],my-d.oy));return true end
 if self.windowDrag then local d=self.windowDrag;if d.name=="bag" then local p=self.bagPos[d.bag];local _,_,bw,bh=self:bagWindowRect(d.bag);p.x=math.max(0,math.min(w-bw,mx-d.ox));p.y=math.max(0,math.min(h-bh,my-d.oy)) else local _,_,ww,hh=self:rect(d.name);if d.name=="inventory" and self.bagnonMode then _,_,ww,hh=self:combinedRect() elseif d.name=="ammoContainer" then _,_,ww,hh=self:ammoContainerRect() end;self.pos[d.name].x=math.max(0,math.min(w-ww,mx-d.ox));self.pos[d.name].y=math.max(0,math.min(h-hh,my-d.oy)) end;return true end return false end
function UI:wheelmoved(dx,dy,mx,my)
 if self.open.skills then local x,y,w,h=self:rect("skills");if inside(mx,my,x,y,w,h) then local counts={Combat=7,Gathering=5,Production=11,Other=3};local maxScroll=math.max(0,((counts[self.skillsTab] or 0)-7)*34);self.skillsScroll=math.max(0,math.min(maxScroll,(self.skillsScroll or 0)-dy*34));return true end end
 if self.open.shop then local x,y,w,h=self:rect("shop");if inside(mx,my,x,y,w,h) then local rows=ShopTabs.view(self);local totalRows=math.ceil(#rows/5);local maxScroll=math.max(0,(totalRows-5)*40);self.shopScroll=math.max(0,math.min(maxScroll,(self.shopScroll or 0)-dy*40));return true end end
 for zi=#self.zOrder,1,-1 do
  local station=self.zOrder[zi]
  if (station=="smelter" or station=="anvil" or station=="woodcraft" or station=="loom" or station=="spinningWheel" or station=="alchemy" or station=="sewing" or station=="stove" or station=="leathercraft" or station=="campfire" or station=="inscription" or station=="tailoring") and self.open[station] then
   local x,y,w,h=self:rect(station)
   if inside(mx,my,x,y,w,h) then
    local recipes=self:craftRecipes(station);local maxScroll=math.max(0,(#recipes-4)*72)
    self.craftScroll[station]=math.max(0,math.min(maxScroll,(self.craftScroll[station] or 0)-dy*72))
    self:log("CRAFTING_SCROLLED",{station=station,offset=math.floor(self.craftScroll[station])})
    return true
   end
  end
 end
 return false
end
function UI:mousereleased(mx,my,button,w,h)
 if button==1 and self.weaponHotbarPress then local p=self.weaponHotbarPress;self.weaponHotbarPress=nil;if p.weapon==self.equipment.weapon and p.name then self:castAbilitySlot(p.slot) end;return true end
 if button==1 and self.magicHotbarPress then local p=self.magicHotbarPress;self.magicHotbarPress=nil;if p.page and self.spellPages[p.slot]==p.page then self:castMagicSlot(p.slot) end;return true end
 if button==1 and self.magicPageDrag then local d=self.magicPageDrag;self.magicPageDrag=nil;local hx,hy=self:magicHotbarRect(w,h);local target=nil;for i=1,6 do if inside(mx,my,hx+7+(i-1)*53,hy+6,46,42) then target=i;break end end;if target then if target~=d.fromSlot then self.spellPages[d.fromSlot],self.spellPages[target]=self.spellPages[target],self.spellPages[d.fromSlot] end else if self.inv:add(d.page,1) then self.spellPages[d.fromSlot]=nil;self:log('SPELL_HOTBAR_REMOVED',{page=d.page,slot=d.fromSlot,source='drag'}) else self.world:addPopup(self.player.x,self.player.y-22,'BAGS FULL','miss') end end;return true end
 if button==1 and self.abilityDrag then local d=self.abilityDrag;local slot=self:weaponHotbarSlotAt(mx,my,w,h);local bar=self:currentWeaponHotbar();if slot and bar and require('game.abilities').isMeleeWeapon(self) then bar[slot]=d.name;self:log("ABILITY_HOTBAR_SET",{ability=d.name,slot=slot,weapon=self.equipment.weapon}) elseif d.source=='hotbar' then self:log('ABILITY_HOTBAR_REMOVED',{ability=d.name,slot=d.fromSlot,weapon=d.weapon,source='drag'}) end;self.abilityDrag=nil;return true end
 if button==1 and self.hudDrag then local d=self.hudDrag;local p=self.hudPos[d.name];self:log("HUD_DRAG_ENDED",{hud=d.name,x=math.floor(p.x),y=math.floor(p.y)});self.hudDrag=nil;return true end
 if button==1 and self.windowDrag then local d=self.windowDrag;local p=d.name=="bag" and self.bagPos[d.bag] or self.pos[d.name];self:log("WINDOW_DRAG_ENDED",{window=d.name=="bag" and ("bag"..d.bag) or d.name,x=math.floor(p.x),y=math.floor(p.y)});self.windowDrag=nil;return true end
 if button~=1 or not self.dragSlot then return false end;local from,bi=self.dragSlot,self.dragBagIndex;local startX,startY=self.dragStartX,self.dragStartY;self.dragSlot,self.dragBagIndex,self.dragStartX,self.dragStartY=nil,nil,nil,nil
 local sourceBag=self.inv:getBag(bi);local sourceItem=sourceBag and sourceBag.slots[from]
 local movedDistance=startX and startY and math.sqrt((mx-startX)^2+(my-startY)^2) or 999
 local releasedBag,releasedSlot=nil,nil
 if self.bagnonMode then releasedBag,releasedSlot=self:combinedSlotAt(mx,my) else for targetBi=4,1,-1 do if self.bagOpen[targetBi] and self.inv.bagSlots[targetBi] then local slot=self:slotAt(mx,my,targetBi);if slot then releasedBag,releasedSlot=targetBi,slot;break end end end end
 -- While the bank is open, a stationary left-click on an inventory item is a quick deposit.
 -- This is deliberately checked before click-to-Use; dragging still follows the normal drag path.
 if sourceItem and self.open.bank and movedDistance<=8 and releasedBag==bi and releasedSlot==from then
  local ok,name,qty=self.inv:depositSlot(bi,from)
  self:log('BANK_DEPOSIT_CLICK',{item=name or sourceItem.name,qty=qty or 0,success=tostring(ok)})
  if not ok then self.world:addPopup(self.player.x,self.player.y-22,name=='bank_full' and 'BANK FULL' or 'CANNOT DEPOSIT','miss') end
  return true
 end
 if sourceItem and self:isUseSource(sourceItem) and movedDistance<=8 and releasedBag==bi and releasedSlot==from then self:selectUseItem(bi,from,sourceItem);return true end
 local ammoTarget=self:ammoContainerSlotAt(mx,my);if ammoTarget and sourceItem then local ok=self:depositIntoAmmoContainer(bi,from,ammoTarget);self:log('AMMO_CONTAINER_DRAG_DEPOSIT',{item=sourceItem.name,success=tostring(ok)});return true end
 local potionTarget=self:potionSlotAt(mx,my,w,h);if potionTarget then local ok,res=self:equipPotionFromBag(bi,from,potionTarget);self:log("POTION_BELT_DRAG",{success=tostring(ok),result=tostring(res),slot=potionTarget});return true end
 if self.open.bank then local bs=self:bankSlotAt(mx,my);if bs then local ok,name,qty=self.inv:depositSlot(bi,from);self:log("BANK_DEPOSIT_DRAG",{item=name or "unknown",qty=qty or 0,success=tostring(ok)});return true end end
 local bagTarget=self:bagSlotAt(mx,my,w,h);if bagTarget then local ok,res=self.inv:equipBagFromItem(bi,from,bagTarget);self:log("BAG_EQUIP_ATTEMPT",{success=tostring(ok),result=res});if ok then self.inv:setActiveBag(bagTarget) end;return true end
 local destBag,destSlot=nil,nil;if self.bagnonMode then destBag,destSlot=self:combinedSlotAt(mx,my) else for targetBi=4,1,-1 do if self.bagOpen[targetBi] and self.inv.bagSlots[targetBi] then local slot=self:slotAt(mx,my,targetBi);if slot then destBag,destSlot=targetBi,slot;break end end end end;if destBag then local ok,action,count=self.inv:moveSlotBetween(bi,from,destBag,destSlot);self:log("INVENTORY_MOVED",{fromBag=bi,from=from,toBag=destBag,to=destSlot,result=action or "failed",amount=count or 0,success=tostring(ok)});return true end;return true
end
function UI:drawHelp(w,h,camera,minimap)
 if self.toolContext or self.abilityDrag or self.magicPageDrag or self.weaponHotbarPress or self.magicHotbarPress or self.dragSlot or self.context or self.bankContext or self.shopContext or self.equipmentContext or self.mercContext or self.bagContext or self.windowDrag or self.hudDrag then return end
 local mx,my=love.mouse.getPosition();local H=require("game.help")
 local hover,blocked=H.ui(self,mx,my,w,h)
 if minimap and mx>=minimap[1] and my>=minimap[2] and mx<minimap[1]+minimap[3] and my<minimap[2]+minimap[4] then hover=H.tip("Minimap","Your marker shows your location; numbered markers are villages. Hold Ctrl and drag to reposition.");blocked=true end
 if not blocked and camera then local x,y=camera:toWorld(mx,my,w,h);hover=H.world(self,x,y) end
 if hover then self:drawTooltip(hover.item,mx,my,w,h,hover.info) end
end
require("game.rune_ui").install(UI)
require("game.craft_jobs").install(UI)
require("game.skill_guide").install(UI)
require("game.resizable").install(UI)
require("game.bank_drag").install(UI)
require("game.bonfire_ui").install(UI)
require("game.fieldcraft_ui").install(UI)
require("game.shellfish_ui").install(UI)
require("game.tailoring_content").install(UI)
require("game.advanced_gear").install(UI)
require('game.craft_amount').install(UI)
require('game.quality').installUI(UI)
require('game.gravestone_ui').install(UI);require('game.bone_ui').install(UI);require('game.high_tier_fish').install(UI)
require("game.tool_slot_ui").install(UI)
return UI
