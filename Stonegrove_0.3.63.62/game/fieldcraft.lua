-- Shared offline/server camp rules. No graphics, account tokens or client totals.
local F={};local C=require('game.fieldcraft_content');local R=require('game.rune_inventory')
local function inside(c,x,y,pad)local t=C.tents[c.tent];pad=pad or 0;return math.abs(x-c.x)<t.width/2+pad and math.abs(y-c.y)<t.height/2+pad end
local function refresh(w)w.campRevision=(w.campRevision or 0)+1;require('game.node_index').invalidate(w);require('game.navigation').refresh(w)end
function F.config(a)a.fieldcraft=a.fieldcraft or{layout={},built={},recovery={},regions={}};local d=a.fieldcraft;for _,k in ipairs({'layout','built','recovery','regions'})do d[k]=d[k]or{}end;return d end
function F.capacity(a,c)local n=C.tents[c.tent].storage;for _,s in ipairs(c.structures or{})do n=n+(C.structure(s.id).storage or 0)end;return n end
function F.slot(c,index)
 local t=C.tents[c.tent];local coords={{-t.width/2+20,-t.height/2+20},{t.width/2-20,-t.height/2+20},{-t.width/2+20,0},{t.width/2-20,0},{0,-t.height/2+20}};local p=coords[index];return p and c.x+p[1],p and c.y+p[2]
end
function F.valid(w,a,tent,x,y)
 local t=C.tents[tent];if not t then return false,'Unknown Tent'end
 if a.skills:get('Fieldcraft').level<t.level then return false,'Fieldcraft level '..t.level..' required'end
 if type(x)~='number'or type(y)~='number'or x~=x or y~=y or math.abs(x)>1e7 or math.abs(y)>1e7 then return false,'Invalid position'end
 if w.isCave then return false,'Camps require open land'end
 if(x-a.player.x)^2+(y-a.player.y)^2>160^2 then return false,'Place your camp nearby'end
 if math.abs(a.player.x-x)<23 and a.player.y>y-23 and a.player.y<y+13 then return false,'Move clear of the Tent entrance before deploying'end
 local c={tent=tent,x=x,y=y}
 for px=x-t.width/2-8,x+t.width/2+8,8 do for py=y-t.height/2-8,y+t.height/2+8,8 do
  if not w.map:isLand(px,py)or require('game.fences').blocked(w,px,py)then return false,'Water or blocked terrain'end
 end end
 for _,v in ipairs(w.villages or{})do if(v.cx-x)^2+(v.cy-y)^2<250^2 then return false,'Too close to town'end end
 for _,h in ipairs(w.houses or{})do local hx,hy,hw,hh=require('game.houses').bounds(h);if x+t.width/2>hx-24 and x-t.width/2<hx+hw+24 and y+t.height/2>hy-24 and y-t.height/2<hy+hh+24 then return false,'Blocked building or entrance'end end
 for _,name in ipairs({'questNPCs','customNPCs','tradeKeepers','traders','healers','guards','enemies','sheep','farmAnimals','caveEntrances','townDecorations','authoredObjects','portals','restrictedAreas'})do for _,n in ipairs(w[name]or{})do
  if not n.dead and not n.inactive and not(name=='authoredObjects'and F.suppressible({kind=n.id}))and inside(c,n.x or -1e9,n.y or -1e9,32)then return false,'Protected object or nearby character'end
 end end
 for _,n in ipairs(w.nodes or{})do if inside(c,n.x,n.y,16)and not F.suppressible(n)then return false,'Resource or quest object blocks this camp'end end
 for _,other in ipairs(w.playerCamps or{})do local ot=C.tents[other.tent];if math.abs(x-other.x)<(t.width+ot.width)/2+24 and math.abs(y-other.y)<(t.height+ot.height)/2+24 then return false,'Another camp is too close'end end
 for _,other in ipairs(w.onlineActors or{})do if other~=a and inside(c,other.player.x,other.player.y,20)then return false,'Another player is inside the footprint'end end
 return true
end
function F.suppressible(n)return not n.quest and not n.questId and({tree=true,oak=true,poplar=true,berryBush=true,blueMushroom=true,brownMushroom=true,bushRoot=true,bushGreens=true,purpleBerry=true,redBerry=true,hemp=true,flax=true})[n.kind]end
function F.suppress(w,c)
 c.suppressed={};for i=#w.nodes,1,-1 do local n=w.nodes[i];if inside(c,n.x,n.y,16)and F.suppressible(n)then c.suppressed[#c.suppressed+1]={node=n,index=i};if w.gather and w.gather.node==n then w.gather=nil end;for _,other in ipairs(w.onlineActors or{})do if other.gather and other.gather.node==n then other.gather=nil end end;table.remove(w.nodes,i)end end;refresh(w)
end
function F.restore(w,c)
 -- Timers remain at their pre-placement value. No instant respawn by camp cycling.
 for i=#(c.suppressed or{}),1,-1 do local d=c.suppressed[i];local found=false;for _,n in ipairs(w.nodes)do if n==d.node or(d.node.netId and n.netId==d.node.netId)then found=true;break end end;if not found then table.insert(w.nodes,math.min(d.index,#w.nodes+1),d.node)end end;c.suppressed={};refresh(w)
end
function F.near(a,c)return c and(a.player.x-c.x)^2+(a.player.y-c.y)^2<=100^2 end
function F.owned(w,a)for _,c in ipairs(w.playerCamps or{})do if c.owner==a.campOwner then return c end end end
function F.find(w,a)
 local c=F.owned(w,a);if c then return w,c end
 for _,other in pairs(require('game.regions').cache or{})do c=F.owned(other,a);if c then return other,c end end
end
function F.remove(w,a,c,destroy)
 local d=F.config(a)
 if destroy then for _,v in pairs(c.storage or{})do d.recovery[#d.recovery+1]=R.copy(v)end end
 for i=#(w.campfires or{}),1,-1 do if w.campfires[i].fieldcraftCamp==c.owner then table.remove(w.campfires,i)end end
 F.restore(w,c);for i=#w.playerCamps,1,-1 do if w.playerCamps[i]==c then table.remove(w.playerCamps,i)end end
 d.active=nil;d.activeTent=nil;d.activeStorage=nil;refresh(w)
end
function F.rebuild(w,a,c)
 for i=#w.campfires,1,-1 do if w.campfires[i].fieldcraftCamp==c.owner then table.remove(w.campfires,i)end end
 c.structures={};local d=F.config(a);local slots=C.slots(a.skills:get('Fieldcraft').level,c.tent)
 for index=1,slots do local id=d.layout[index];local s=C.structure(id);if s and d.built[id]and a.skills:get('Fieldcraft').level>=s.level then local x,y=F.slot(c,index);c.structures[#c.structures+1]={id=id,slot=index,x=x,y=y,qualityGrade=(d.quality or{})[id]};if id=='fire'then w.campfires[#w.campfires+1]={x=x,y=y,timer=1e9,permanent=true,fieldcraftCamp=c.owner}end end end;refresh(w)
end
local function material(inv,needs)for _,n in ipairs(needs)do if inv:countItem(n[1])<n[2]then return false,'Need '..n[2]..' '..n[1]end end;return true end
function F.bind(w,a) a.skills.fieldcraftContext={world=w,actor=a} end
function F.activity(skills,name,gained)
 if name=='Fieldcraft'or gained<=0 then return end
 local context=skills.fieldcraftContext;if not context then return end
 local w,a=context.world,context.actor;local c=F.owned(w,a);if not c or(a.player.x-c.x)^2+(a.player.y-c.y)^2>100^2 then return end
 skills:addXP('Fieldcraft',math.min(5,gained*.1))
end
function F.command(w,a,cmd,clock)
 F.bind(w,a)
 clock=clock or os.time();local d=F.config(a);w.playerCamps=w.playerCamps or{};local c=F.owned(w,a)
 if cmd.op=='deploy'then
  if c or d.active then return false,'Only one camp per character'end
  if a.player.hp<=0 or w.combatTarget or a.target then return false,'Cannot deploy in combat'end
  local ok,why=F.valid(w,a,cmd.tent,cmd.x,cmd.y);if not ok then return false,why end
  if a.inv:countItem(cmd.tent)<1 then return false,'Craft a Tent first'end
  local tentItem;for _,bag in pairs(a.inv.bagSlots)do for _,it in pairs(bag.slots)do if it.name==cmd.tent then tentItem=R.copy(it);break end end;if tentItem then break end end;local t=C.tents[cmd.tent];a.inv:removeItems(cmd.tent,1);c={owner=a.campOwner,name=(a.player.name or'Adventurer').."'s Camp",tent=cmd.tent,tentItem=tentItem,x=cmd.x,y=cmd.y,storage={},structures={}};w.playerCamps[#w.playerCamps+1]=c;d.active=true;d.activeTent=cmd.tent;F.suppress(w,c);F.rebuild(w,a,c)
  local region=w.regionId or'wilderness';if not d.regions[region]then d.regions[region]=true;a.skills:addXP('Fieldcraft',5)end
  return true,'Camp deployed. '..C.warning
 elseif cmd.op=='recover'then
  if not next(d.recovery)then return false,'No items to recover from lost camps.'end
  local trial=R.clone(a.inv);for _,v in ipairs(d.recovery)do if not trial:addItemObject(R.copy(v))then return false,'Make room in your bags for recovered items'end end;a.inv.bagSlots=trial.bagSlots;d.recovery={};return true,'Recovered camp storage'
 end
 if not c then return false,'Deploy your camp first'end
 if not F.near(a,c)then return false,'Move closer to your camp'end
 if cmd.op=='pack'then
  if next(c.storage)then return false,'Empty all camp storage before packing up your camp.'end
  if a.target or w.combatTarget or a.player.hp<=0 then return false,'Cannot pack in combat'end
  if not a.inv:canAddObject(c.tentItem or{name=c.tent,qty=1})then return false,'Make room for your Tent'end
  a.inv:addItemObject(c.tentItem or{name=c.tent,qty=1});F.remove(w,a,c,false);return true,'Camp packed'
 elseif cmd.op=='build'then
  local s=C.structure(cmd.structure);local slot=cmd.slot
  if not s or type(slot)~='number'or slot%1~=0 or slot<1 or slot>C.slots(a.skills:get('Fieldcraft').level,c.tent)then return false,'Choose an available building slot'end
  if a.skills:get('Fieldcraft').level<s.level then return false,'Fieldcraft level '..s.level..' required'end
  for _,st in ipairs(c.structures)do if st.slot==slot then return false,'Building slot occupied'end;if st.id==s.id then return false,'This structure is already active'end end
  local bx,by=F.slot(c,slot);if(bx-a.player.x)^2+(by-a.player.y)^2<18^2 then return false,'Move clear of the building slot'end;for _,other in ipairs(w.onlineActors or{})do if other~=a and(bx-other.player.x)^2+(by-other.player.y)^2<18^2 then return false,'Another player occupies that building slot'end end
  if not d.built[s.id]then local ok,why=material(a.inv,s.needs);if not ok then return false,why end;for _,v in ipairs(s.needs)do a.inv:removeItems(v[1],v[2])end;d.built[s.id]=true;d.quality=d.quality or{};d.quality[s.id]=require('game.quality').roll(a.skills:get('Fieldcraft').level);a.skills:addXP('Fieldcraft',s.xp)end
  d.layout[slot]=s.id;F.rebuild(w,a,c);return true,s.name..' constructed'
 elseif cmd.op=='layout'then
  local slot=cmd.slot;if type(slot)~='number'or slot%1~=0 or slot<1 or slot>5 then return false,'Invalid slot'end
  if next(c.storage)then return false,'Empty all camp storage before changing your layout.'end
  d.layout[slot]=nil;F.rebuild(w,a,c);return true,'Slot cleared; paid structure remains unlocked'
 elseif cmd.op=='deposit'then
  local b=a.inv:getBag(cmd.bag);local obj=b and b.slots[cmd.slot];if not obj then return false,'Item moved; try again'end
  local free;for i=1,F.capacity(a,c)do if not c.storage[i]then free=i;break end end;if not free then return false,'Camp storage full'end
  c.storage[free]=R.copy(obj);b.slots[cmd.slot]=nil;return true,'Stored. '..C.warning
 elseif cmd.op=='withdraw'then
  local obj=c.storage[cmd.slot];if not obj then return false,'Storage slot empty'end
  if not a.inv:addItemObject(R.copy(obj))then return false,'Bags full'end;c.storage[cmd.slot]=nil;return true,'Withdrawn'
 elseif cmd.op=='rest'then
  if a.target or w.combatTarget then return false,'Cannot rest in combat'end
  if clock<(d.restNext or 0)then return false,'Rest XP cooldown: '..math.ceil(d.restNext-clock)..'s'end
  d.restNext=clock+300;a.skills:addXP('Fieldcraft',20);return true,'Rested: +20 Fieldcraft XP'
 end
 return false,'Unknown camp action'
end
function F.public(w)
 local out={};for _,c in ipairs(w.playerCamps or{})do out[#out+1]={owner=c.owner,name=c.name,tent=c.tent,x=c.x,y=c.y,structures=R.copy(c.structures)}end;return out
end
function F.install(W)
 local blocked=W.playerBlocked;W.playerBlocked=function(w,x,y,...)
  for _,c in ipairs(w.playerCamps or{})do if math.abs(x-c.x)<16 and y<c.y+5 and y>c.y-15 then return true,'tent'end;for _,s in ipairs(c.structures or{})do if(s.x-x)^2+(s.y-y)^2<10^2 then return true,'camp structure'end end end
  return blocked(w,x,y,...)
 end
end
return F
