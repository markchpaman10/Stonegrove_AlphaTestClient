local Q={}
local okQD,QUEST_DATA=pcall(require,'quest_data');if not okQD or type(QUEST_DATA)~='table' then QUEST_DATA={quests={}} end
local Nav=require('game.navigation')
local types={questGather='Gathering requests',questKill='Hunting contracts',questEscort='Town escorts',questCave='Cave clearing contracts',questCamp='Goblin camp contracts',questStory='Story quest'}
local gather={{item='Pine Logs',skill='Woodcutting',level=1},{item='Small Copper Chunk',skill='Mining',level=1},{item='Small Fish',skill='Fishing',level=1},{item='Oak Logs',skill='Woodcutting',level=11},{item='Small Iron Chunk',skill='Mining',level=15}}
local function distance(a,b)return (a.x-b.x)^2+(a.y-b.y)^2 end
local function note(w,text)w.notifications[#w.notifications+1]={text=text,t=6}end
local function root(w)return w.overworld or w end

local function cleanupQuestEnemies(w,key)
 for i=#(w.enemies or {}),1,-1 do local e=w.enemies[i];if e.questSpawnKey==key and not e.dead then table.remove(w.enemies,i) end end
end
local function questSpawnSafe(w,x,y)
 if not w.map:isLand(x,y) or require('game.regions').edgeProtected(w.map,x,y,72) or w:enemyBlocked(x,y) then return false end
 if not require('game.expansion').clearVillage(w,x,y,90) then return false end
 local a=w.map.authored or {}
 for _,p in ipairs(a.paths or {}) do if x>=p.x-80 and x<=p.x+96 and y>=p.y-80 and y<=p.y+96 then return false end end
 for _,o in ipairs(a.objects or {}) do if math.abs(x-o.x)<=110 and math.abs(y-o.y)<=110 then return false end end
 for _,h in ipairs(w.houses or {}) do if math.abs(x-h.x)<=135 and math.abs(y-h.y)<=130 then return false end end
 return true
end
local function spawnKillTargets(w,p,n,a)
 if not w.makeExpansionEnemy then return 0 end
 cleanupQuestEnemies(w,n.key)
 local made=0
 for i=1,a.count do
  local placed=false
  for attempt=1,220 do
   local ang=math.random()*math.pi*2;local dist=math.random(260,720);local x=p.x+math.cos(ang)*dist;local y=p.y+math.sin(ang)*dist
   if x>80 and y>80 and x<w.map.width-80 and y<w.map.height-80 and questSpawnSafe(w,x,y) then
    local e=w.makeExpansionEnemy(a.target,x,y,1);e.questSpawnKey=n.key;e.questTarget=true;e.inactive=false;e.nightOnly=nil;e.dayOnly=nil;e.aggro=false;e.state='idle';w.enemies[#w.enemies+1]=e;made=made+1;placed=true;break
   end
  end
  if not placed then
   for attempt=1,300 do local x=math.random(100,w.map.width-100);local y=math.random(100,w.map.height-100);if questSpawnSafe(w,x,y) then local e=w.makeExpansionEnemy(a.target,x,y,1);e.questSpawnKey=n.key;e.questTarget=true;e.inactive=false;e.nightOnly=nil;e.dayOnly=nil;e.aggro=false;e.state='idle';w.enemies[#w.enemies+1]=e;made=made+1;break end end
  end
 end
 return made
end

local function questSite(w,p)
 for attempt=1,500 do local ang=math.random()*math.pi*2;local dist=math.random(420,1100);local x=p.x+math.cos(ang)*dist;local y=p.y+math.sin(ang)*dist
  if x>160 and y>160 and x<w.map.width-160 and y<w.map.height-160 and questSpawnSafe(w,x,y) then return x,y end end
 for attempt=1,500 do local x=math.random(180,w.map.width-180);local y=math.random(180,w.map.height-180);if questSpawnSafe(w,x,y)then return x,y end end
end
local function cleanupQuestStructure(w,key)
 for i=#(w.goblinCamps or {}),1,-1 do local c=w.goblinCamps[i];if c.questSpawnKey==key then for j=#(w.enemies or {}),1,-1 do if w.enemies[j].campId==c and not w.enemies[j].dead then table.remove(w.enemies,j)end end;table.remove(w.goblinCamps,i)end end
 for i=#(w.caveEntrances or {}),1,-1 do local e=w.caveEntrances[i];if e.questSpawnKey==key then w.caveInstances[e.id]=nil;table.remove(w.caveEntrances,i)end end
end
function Q.setup(w)
 if w.questNPCs then return end
 w.questNPCs={};w.questTowns={};w.questDestinations={}
 for _,o in ipairs((w.map.authored or {}).objects or {})do
  if types[o.id] then w.questNPCs[#w.questNPCs+1]={id=o.id,key=((w.map.authored or {}).regionId and (w.map.authored.regionId..':') or '')..o.id..':'..o.x..':'..o.y,x=o.x,y=o.y,homeX=o.x,homeY=o.y,race='Human',name=types[o.id]}
  elseif o.id=='townCenter' then local d={id=o.id,x=o.x,y=o.y,name=o.name or o.townName};w.questTowns[#w.questTowns+1]=d;w.questDestinations[#w.questDestinations+1]=d elseif o.id=='storyPOI' then w.questDestinations[#w.questDestinations+1]={id=o.id,x=o.x,y=o.y,name=o.name} end
 end
 -- NPC Editor quest links. A single authored NPC can own an ordered quest line.
 local questById={};for _,cq in ipairs(QUEST_DATA.quests or{})do if cq.id then questById[cq.id]=cq end end
 for _,cn in ipairs(require('game.npc_bindings').apply(w))do
  local linked={};for _,qid in ipairs(cn.questIds or{})do if qid and qid~='' and questById[qid]then linked[#linked+1]=questById[qid]end end
  if #linked>0 then w.questNPCs[#w.questNPCs+1]={id='linkedCustomNPC',key='npcquests:'..tostring(cn.linkKey or cn.id),x=cn.x,y=cn.y,homeX=cn.homeX or cn.x,homeY=cn.homeY or cn.y,race=cn.race,name=cn.name,customQuests=linked,sourceNPC=cn,linkedCustom=true}end
 end
 -- Authored quests made in QuestEditor. Legacy giver-marker links remain supported.
 for _,cq in ipairs(QUEST_DATA.quests or {})do
  local rid,kind,x,y=tostring(cq.giverRef or ''):match('^([^:]+):([^:]+):([%-%.%d]+):([%-%.%d]+)$');x=tonumber(x);y=tonumber(y)
  local doc=require('game.regions').doc;local oldIndex=tonumber(rid);if oldIndex and doc and doc.maps and doc.maps[oldIndex]then rid=doc.maps[oldIndex].id end
  local mapId=(w.map.authored or{}).regionId
  if x and y and (rid=='root' or not mapId or rid==mapId) then
   local found=false;for _,o in ipairs((w.map.authored or {}).objects or {})do if o.id==kind and math.abs(o.x-x)<1 and math.abs(o.y-y)<1 then found=true;break end end
   if found then for i=#w.questNPCs,1,-1 do local gn=w.questNPCs[i];if gn.id=='questStory' and math.abs(gn.x-x)<1 and math.abs(gn.y-y)<1 then table.remove(w.questNPCs,i) end end;w.questNPCs[#w.questNPCs+1]={id='customQuest',key='custom:'..tostring(cq.id),x=x,y=y,homeX=x,homeY=y,race=require('game.races').normalize(cq.giverRace),name=cq.giverName or 'Quest Giver',customQuest=cq} end
  end
 end
end
function Q.state(p,n)
 p.quests=p.quests or {};p.quests[n.key]=p.quests[n.key] or {completed=0,cooldown=0}
 return p.quests[n.key]
end
function Q.event(w,kind,target,amount)
 local p=w.questPlayer;if not p then return end
 for _,s in pairs(p.quests or {})do local a=s.active
  if a and a.kind==kind and a.target==target then a.progress=math.min(a.count,a.progress+(amount or 1))end
 end
end
function Q.offer(w,p,skills,n)
 local s=Q.state(p,n);local cycle=s.completed or 0
 if n.customQuest or n.customQuests then
  local c=n.customQuest
  if n.customQuests then c=n.customQuests[math.min((s.completed or 0)+1,#n.customQuests)];if (s.completed or 0)>=#n.customQuests and not(c and c.repeatable)then return nil,'No more quests are available from '..(n.name or'this NPC')..'.' end end
  if (c.requiredLevel or 1)>1 and skills:get('Health').level<(c.requiredLevel or 1) then return nil,'Requires level '..c.requiredLevel..'.' end
  local o=c.objective or {};local r=c.rewards or {};local coinType=r.coinType or 'Copper';local coinMult=coinType=='Gold' and 10000 or coinType=='Silver' and 100 or 1;return {kind=o.kind or 'gather',target=o.target,count=math.max(1,o.count or 1),progress=0,coins=(r.coins or 0)*coinMult,coinAmount=r.coins or 0,coinType=coinType,xp=r.xp or 0,skill=r.xpSkill,title=c.title or c.id or 'Quest',custom=true,rewardItems=r.items or {},dialogue=c.dialogue or {},description=c.description or '',story=c.story,giverRef=c.giverRef,repeatable=c.repeatable,cooldown=c.cooldown or 300}
 end
 if n.id=='questGather' then
  local choices={};for _,v in ipairs(gather)do if skills:get(v.skill).level>=v.level then choices[#choices+1]=v end end
  local v=choices[cycle%#choices+1];return {kind='gather',target=v.item,skill=v.skill,count=8,progress=0,coins=30,xp=40,title='Gather 8 '..v.item}
 elseif n.id=='questCave' then return {kind='clearCave',count=1,progress=0,coins=180,title='Clear a dangerous cave'}
 elseif n.id=='questCamp' then return {kind='clearCamp',count=1,progress=0,coins=160,title='Clear a goblin camp'}
 elseif n.id=='questKill' then
  local choices={'rat','wolf','boar'};local seen={rat=true,wolf=true,boar=true};for _,e in ipairs(w.enemies or {})do if not e.townAnimal and not e.kind:find('Boss') and e.kind~='gigaRat' and e.kind~='caveSnake' and e.kind~='nagaQueen' and e.kind~='goblin' and not seen[e.kind] then seen[e.kind]=true;choices[#choices+1]=e.kind end end
  table.sort(choices)
  local target=choices[cycle%#choices+1];return {kind='kill',target=target,count=5,progress=0,coins=75,title='Defeat 5 '..target}
 elseif n.id=='questStory' then return nil,'This Story Quest NPC is not linked to an authored Story quest in the Quest Editor.'
 else
  local towns=w.questTowns;local home,dist=nil,math.huge
  for _,t in ipairs(towns)do local d=distance(n,t);if d<dist then home,dist=t,d end end
  local choices={};for _,t in ipairs(towns)do if t~=home and distance(n,t)>160^2 then choices[#choices+1]=t end end
  if #choices==0 then return nil,'Place two Town Center markers in different towns, with a walkable route between them.' end
  local t=choices[cycle%#choices+1]
  local destName=t.name or t.townName or string.format('Town at (%d, %d)',t.x,t.y);return {kind='escort',count=2,progress=0,coins=150,title='Escort to '..destName..' and back',destinationName=destName,destX=t.x,destY=t.y,x=n.homeX,y=n.homeY,hp=60,hitTimer=0}
 end
end
function Q.accept(ui,n)
 local w,p=ui.world,ui.player;local s=Q.state(p,n)
 if s.active then return false end
 if (s.cooldown or 0)>0 then note(w,'This quest giver needs '..math.ceil(s.cooldown)..' seconds before offering another quest.');return false end
 if n.id=='questEscort' then for _,v in pairs(p.quests or {})do if v.active and v.active.kind=='escort' then note(w,'Finish or abandon your current escort first.');return false end end end
 local a,err=Q.offer(w,p,ui.skills,n);if not a then note(w,err);return false end
 s.active=a;n.hp=a.hp or 0;n.inactive=false;if a.kind=='story' then a.progress=0;a.storyNode=(a.story and a.story.start) or 'start' end;if a.kind=='kill' then local made=spawnKillTargets(w,p,n,a);if made<a.count then note(w,'Only '..made..' safe quest targets could be placed.') end elseif a.kind=='clearCave' or a.kind=='clearCamp' then local x,y=questSite(w,p);if not x then s.active=nil;note(w,'No safe wilderness site could be found for this contract.');return false end;a.siteX,a.siteY=x,y;if a.kind=='clearCave' then require('game.caves').addQuest(w,x,y,n.key) else require('game.goblin_camps').add(w,x,y,math.random(1,99999999),false,n.key) end end;note(w,'Quest accepted: '..a.title);return true
end
local function rewardCoinText(a)
 if a.custom then local n=a.coinAmount;if n==nil then n=a.coins or 0 end;return tostring(n)..' '..string.lower(a.coinType or 'Copper')..' coins' end
 return tostring(a.coins or 0)..' copper coins'
end
function Q.claim(ui,n)
 local s=Q.state(ui.player,n);local a=s.active;if not a or a.progress<a.count then return false end
 local bonus=a.custom and 0 or (((s.completed+1)%5==0) and 250 or 0)
 if a.kind=='gather' and a.target and ui.inv:countItem(a.target)<a.count then note(ui.world,'You need '..a.count..' '..a.target..' in your bags to turn this quest in.');return false end
 for _,it in ipairs(a.rewardItems or {})do if it.name and it.name~='(none)' and not ui.inv:canAdd(it.name,it.qty or 1)then note(ui.world,'Make room for your quest item rewards, then claim again.');return false end end
 if a.kind=='gather' and a.target then if not ui.inv:removeItems(a.target,a.count) then note(ui.world,'Quest turn-in failed: the required '..a.target..' could not be removed.');return false end end
 if not ui.inv:addMoney((a.coins or 0)+bonus)then if a.kind=='gather' and a.target then ui.inv:add(a.target,a.count) end;note(ui.world,'Make room for your quest reward coins, then claim again.');return false end
 for _,it in ipairs(a.rewardItems or {})do if it.name and it.name~='(none)' then ui.inv:add(it.name,it.qty or 1) end end
 if a.xp and a.xp>0 and a.skill and a.skill~='' then local _,_,_,gained=ui.skills:addXP(a.skill,a.xp);note(ui.world,a.skill..' +'..math.floor(gained or a.xp)..' XP')end
 cleanupQuestEnemies(root(ui.world),n.key);cleanupQuestStructure(root(ui.world),n.key);s.completed=s.completed+1;s.active=nil;s.cooldown=a.cooldown or 300;n.inactive=true;n.x,n.y=n.homeX,n.homeY
 require('game.audio').play('quest_complete');note(ui.world,'Quest complete: '..rewardCoinText(a)..(bonus>0 and ' + 250 coin loyalty bonus!' or ''));return true
end
local storyNode
function Q.update(ui,dt)
 local w,p=ui.world,ui.player;local over=root(w);over.questPlayer=p;Q.setup(over);if w.isCave then local key=w.entry and w.entry.questSpawnKey;if key then local s=p.quests and p.quests[key];if s and s.active and s.active.kind=='clearCave' then local alive=false;for _,e in ipairs(w.enemies or {})do if not e.dead then alive=true;break end end;if not alive and s.active.progress<1 then s.active.progress=1;note(w,'Cave cleared! Return to the quest giver.')end end end;return end
 for _,n in ipairs(w.questNPCs)do
  if n.linkedCustom and n.sourceNPC then n.x,n.y=n.sourceNPC.x,n.sourceNPC.y;n.homeX,n.homeY=n.sourceNPC.homeX or n.homeX,n.sourceNPC.homeY or n.homeY end
  local s=Q.state(p,n);if (s.cooldown or 0)>0 then s.cooldown=math.max(0,s.cooldown-dt) end;local a=s.active
  if a and a.kind=='story' and a.storyEscort then
   local e=a.storyEscort;n.inactive=false;n.hp=n.hp>0 and n.hp or e.hp or 60;e.hp=n.hp
   if p.hp<=0 or e.hp<=0 then a.storyEscort=nil;n.hp=0;n.x,n.y=n.homeX,n.homeY;a.storyNode=(a.story and a.story.start) or 'start';note(w,'Story escort failed. Talk to the quest giver to try again.')
   else local pd=distance(n,p);n.navPriority=true;if pd>32^2 then Nav.move(w,n,p.x,p.y,72,dt) end
    for _,enemy in ipairs(w.enemies or {})do if not enemy.dead and not enemy.inactive and not enemy.townAnimal and distance(enemy,n)<90^2 and not require('game.party').target(enemy) then require('game.party').threat(w,enemy,n,1) end end
    if distance(n,{x=e.destX,y=e.destY})<56^2 and distance(n,p)<90^2 then a.storyEscort=nil;n.hp=0;a.storyNode=e.arrivalNode;if not storyNode(a) then a.storyNode=(a.story and a.story.start) or 'start';note(w,'Arrival dialogue node was not found; returned to the story start.') else note(w,'Destination reached. Talk to '..(n.name or 'the traveler')..' to continue the story.');ui.questPanel=n end end
   end
  elseif a and a.kind=='escort' then
   n.x,n.y=a.x,a.y;n.inactive=a.progress>=2;n.hp=n.hp or a.hp;a.hp=n.hp
   if p.hp<=0 then s.active=nil;n.inactive=true;n.hp=0;n.x,n.y=n.homeX,n.homeY;note(w,'Escort failed: you were defeated.')
   elseif a.progress<2 then
    local pd=distance(n,p);n.navPriority=true;if pd>32^2 then Nav.move(w,n,p.x,p.y,72,dt) end
    a.x,a.y=n.x,n.y
    for _,e in ipairs(w.enemies or {})do if not e.dead and not e.inactive and not e.townAnimal and distance(e,n)<90^2 and not require('game.party').target(e) then
     require('game.party').threat(w,e,n,1)
    end end
    if a.hp<=0 then s.active=nil;n.inactive=true;n.hp=0;n.x,n.y=n.homeX,n.homeY;note(w,'Escort failed: the traveler died. Return to the quest giver to retry.')
    elseif a.progress==0 and distance(n,{x=a.destX,y=a.destY})<56^2 and distance(n,p)<90^2 then a.progress=1;note(w,'Destination reached. Escort the traveler back to the quest starting point.')
    elseif a.progress==1 and distance(n,{x=n.homeX,y=n.homeY})<56^2 and distance(n,p)<90^2 then a.progress=2;n.inactive=true;note(w,'Escort complete! Talk to the traveler to claim your reward.')end
   end
  elseif not (a and a.kind=='story') then n.inactive=true;n.hp=0;n.x,n.y=n.homeX,n.homeY else n.inactive=false end
 end
 -- Linked custom NPCs physically become the escort instead of spawning a duplicate quest character.
 for _,n in ipairs(w.questNPCs or{})do if n.linkedCustom and n.sourceNPC then local s=Q.state(p,n);local a=s.active;local moving=a and (a.kind=='escort' or (a.kind=='story' and a.storyEscort));n.sourceNPC.questControlled=moving and true or false;if moving then n.sourceNPC.x,n.sourceNPC.y=n.x,n.y else n.x,n.y=n.sourceNPC.x,n.sourceNPC.y end end end
 for key,s in pairs(p.quests or {})do local a=s.active;if a and a.kind=='clearCamp' and a.progress<1 then local camp=nil;for _,c in ipairs(w.goblinCamps or {})do if c.questSpawnKey==key then camp=c;break end end;if camp then local alive=false;for _,e in ipairs(w.enemies or {})do if e.campId==camp and e.kind=='goblin' and not e.dead then alive=true;break end end;if not alive then a.progress=1;note(w,'Goblin camp cleared! Return to the quest giver.')end end end end
 if ui.questPanel then local n=ui.questPanel;if distance(n,p)>90^2 then ui.questPanel=nil end end
end
function Q.click(ui,x,y)
 Q.setup(ui.world)
 local candidates={};for _,n in ipairs(ui.world.questNPCs)do if n.linkedCustom then candidates[#candidates+1]=n end end;for _,n in ipairs(ui.world.questNPCs)do if not n.linkedCustom then candidates[#candidates+1]=n end end
 for _,n in ipairs(candidates)do if distance(n,{x=x,y=y})<20^2 and(not n.linkedCustom or Q.state(ui.player,n).active or Q.offer(ui.world,ui.player,ui.skills,n))then
  if distance(n,ui.player)>65^2 then note(ui.world,'Move closer to talk to the quest giver.')else ui.questPanel=n end;return true
 end end
 return false
end
local icon,frames
local function loadIcon()
 if icon then return end;icon=love.graphics.newImage('assets/quest_progress.png');icon:setFilter('nearest','nearest');frames={}
 for i=0,5 do frames[i]=love.graphics.newQuad(i*16,0,16,16,icon:getDimensions())end
end
function Q.drawNPC(w,p,sprites,n)
 sprites.npcCosmetics:drawShadow(n,sprites,n.key);sprites.npcCosmetics:draw(n,sprites,n.key)
 loadIcon();local s=Q.state(p,n);local ready=s.active and s.active.progress>=s.active.count;local available=not s.active and (s.cooldown or 0)<=0;local frame=ready and 5 or (s.completed%5);if s.completed>0 and frame==0 then frame=5 end
 love.graphics.setColor((available or ready) and 1 or .38,(available or ready) and 1 or .38,(available or ready) and 1 or .38,1);love.graphics.draw(icon,frames[frame],n.x-8,n.y-30);love.graphics.setColor(1,1,1,1)
 if s.active and (s.active.kind=='escort' or (s.active.kind=='story' and s.active.storyEscort)) then local hp=s.active.kind=='escort' and s.active.hp or (s.active.storyEscort.hp or 60);love.graphics.setColor(.18,.06,.04);love.graphics.rectangle('fill',n.x-12,n.y-14,24,3);love.graphics.setColor(.2,.85,.3);love.graphics.rectangle('fill',n.x-12,n.y-14,24*hp/60,3)end
end
local panelPos={x=nil,y=nil,dragging=false,offX=0,offY=0}
local tracker={x=nil,y=nil,w=318,h=0,dragging=false,offX=0,offY=0}
local function rect()local w,h=love.graphics.getDimensions();local width=math.min(440,w-24);panelPos.x=panelPos.x or (w-width)/2;panelPos.y=panelPos.y or math.max(12,(h-300)/2);panelPos.x=math.max(4,math.min(w-width-4,panelPos.x));panelPos.y=math.max(4,math.min(h-304,panelPos.y));return panelPos.x,panelPos.y,width,300 end
function Q.panelMouseMoved(x,y) if not panelPos.dragging then return false end;local w,h=love.graphics.getDimensions();local pw=math.min(440,w-24);panelPos.x=math.max(4,math.min(w-pw-4,x-panelPos.offX));panelPos.y=math.max(4,math.min(h-304,y-panelPos.offY));return true end
function Q.panelMouseReleased(b) if b==1 and panelPos.dragging then panelPos.dragging=false;return true end;return false end
function Q.mousepressed(x,y,b) if b~=1 then return false end;if tracker.h>0 and tracker.x and x>=tracker.x and x<=tracker.x+tracker.w and y>=tracker.y and y<=tracker.y+tracker.h then tracker.dragging=true;tracker.offX=x-tracker.x;tracker.offY=y-tracker.y;return true end;return false end
function Q.mousemoved(x,y) if tracker.dragging then local w,h=love.graphics.getDimensions();tracker.x=math.max(4,math.min(w-tracker.w-4,x-tracker.offX));tracker.y=math.max(4,math.min(h-tracker.h-4,y-tracker.offY));return true end;return Q.panelMouseMoved(x,y) end
function Q.mousereleased(b) local used=false;if b==1 and tracker.dragging then tracker.dragging=false;used=true end;return Q.panelMouseReleased(b) or used end
storyNode=function(a)
 if not a or not a.story then return nil end
 local id=a.storyNode or a.story.start or 'start'
 for _,node in ipairs(a.story.nodes or {})do if node.id==id then return node end end
 return (a.story.nodes or {})[1]
end
local function storyDestination(w,ref)
 local rid,kind,x,y=tostring(ref or ''):match('^([^:]+):([^:]+):([%-%.%d]+):([%-%.%d]+)$');x=tonumber(x);y=tonumber(y);if not x or not y then return nil end
 for _,d in ipairs(w.questDestinations or {})do if d.id==kind and math.abs(d.x-x)<1 and math.abs(d.y-y)<1 then return d end end
end
local function storyChoose(ui,n,index)
 local s=Q.state(ui.player,n);local a=s.active;if not a or a.kind~='story' then return false end
 local node=storyNode(a);local r=node and (node.responses or {})[index];if not r or not r.text or r.text=='' then return false end
 if r.action=='goto' then a.storyNode=r.target;if not storyNode(a) then note(ui.world,'Story node "'..tostring(r.target)..'" was not found.');a.storyNode=node.id end
 elseif r.action=='escort' then local d=storyDestination(root(ui.world),r.destination);if not d then note(ui.world,'Story escort destination was not found. Check the World Editor marker and resave the quest.');return true end;a.storyEscort={destX=d.x,destY=d.y,destinationName=d.name or (d.id=='townCenter' and 'Town' or 'Point of Interest'),arrivalNode=r.target or '',hp=60};n.hp=60;n.inactive=false;ui.questPanel=nil;note(ui.world,'Escort started: travel with '..(n.name or 'the traveler')..' to the marked destination.')
 elseif r.action=='complete' then a.progress=a.count or 1;return Q.claim(ui,n)
 elseif r.action=='end' then ui.questPanel=nil end
 return true
end
function Q.panelClick(ui,x,y,b)
 if not ui.questPanel then return false end
 local n=ui.questPanel;local px,py,pw,ph=rect();if x<px or y<py or x>=px+pw or y>=py+ph then return false end
 if b==1 then
  local ss=Q.state(ui.player,n);local aa=ss.active;if aa and aa.kind=='story' then for i=1,3 do local yy=py+168+(i-1)*38;if x>=px+16 and x<=px+pw-16 and y>=yy and y<=yy+32 then storyChoose(ui,n,i);return true end end end
  if x>=px+pw-34 and x<=px+pw and y>=py and y<=py+32 then ui.questPanel=nil
  elseif x>=px and x<=px+pw-34 and y>=py and y<=py+34 then panelPos.dragging=true;panelPos.offX=x-px;panelPos.offY=y-py
  elseif x>=px+16 and x<=px+pw-16 and y>=py+224 and y<=py+260 then
   if distance(n,ui.player)>65^2 then ui.questPanel=nil;return true end
   local s=Q.state(ui.player,n);if not s.active then Q.accept(ui,n)elseif s.active.progress>=s.active.count then Q.claim(ui,n)end
  elseif x>=px+16 and x<=px+pw-16 and y>=py+266 and y<=py+296 then cleanupQuestEnemies(root(ui.world),n.key);cleanupQuestStructure(root(ui.world),n.key);Q.state(ui.player,n).active=nil;n.inactive=true;n.hp=0;n.x,n.y=n.homeX,n.homeY;ui.questPanel=nil;note(ui.world,'Quest abandoned.')end
 end
 return true
end
function Q.drawMinimap(ui,x,y,mw,mh)
 local w,p=ui.world,ui.player;Q.setup(w);if w.isCave then return end
 for _,st in pairs(p.quests or {})do local a=st.active;if a and (a.kind=='clearCave' or a.kind=='clearCamp') and a.progress<1 and a.siteX then local mx=x+(a.siteX/w.map.width)*mw;local my=y+(a.siteY/w.map.height)*mh;love.graphics.setColor(1,.65,.12,1);love.graphics.circle('fill',mx,my,4);love.graphics.setColor(1,1,.5,1);love.graphics.circle('line',mx,my,6)end end
 for _,e in ipairs(w.enemies or {}) do if e.questTarget and e.questSpawnKey and not e.dead and not e.inactive then
  local active=false;for key,s in pairs(p.quests or {}) do if key==e.questSpawnKey and s.active and s.active.kind=='kill' and s.active.target==e.kind then active=true;break end end
  if active then local mx=x+(e.x/w.map.width)*mw;local my=y+(e.y/w.map.height)*mh;love.graphics.setColor(1,.2,.08,1);love.graphics.circle('fill',mx,my,3.5);love.graphics.setColor(1,.85,.35,1);love.graphics.circle('line',mx,my,5) end
 end end
end
function Q.drawUI(ui,camera,minimap)
 local w,p=ui.world,ui.player;Q.setup(w)
 local sw,sh=love.graphics.getDimensions()
 -- Track active quests without requiring an open dialogue.
 local lines={};for _,s in pairs(p.quests or {})do local a=s.active;if a then
  local text=a.title..'  '..a.progress..'/'..a.count
  if a.kind=='story' and a.storyEscort then text=text..'  Escort to '..(a.storyEscort.destinationName or 'destination')..'  HP '..math.ceil(a.storyEscort.hp or 60)..'/60' elseif a.kind=='escort' then text=text..(a.progress==0 and ('  Destination: '..(a.destinationName or 'marked town')) or a.progress==1 and '  Return to quest giver' or '  Ready to claim');text=text..'  HP '..math.ceil(a.hp)..'/60' end
  lines[#lines+1]=text
 end end
 local defaultY=12;if minimap and minimap[1]+minimap[3]>sw-330 then defaultY=minimap[2]+minimap[4]+12 end
 table.sort(lines);if #lines>0 then tracker.h=24+36*#lines;tracker.x=tracker.x or (sw-330);tracker.y=tracker.y or defaultY;tracker.x=math.max(4,math.min(sw-tracker.w-4,tracker.x));tracker.y=math.max(4,math.min(sh-tracker.h-4,tracker.y));love.graphics.setColor(.04,.04,.03,.88);love.graphics.rectangle('fill',tracker.x,tracker.y,tracker.w,tracker.h,4);love.graphics.setColor(.8,.65,.3,1);love.graphics.setLineWidth(2);love.graphics.rectangle('line',tracker.x,tracker.y,tracker.w,tracker.h,4);love.graphics.setLineWidth(1);love.graphics.setColor(1,.88,.6);love.graphics.print('Active quests',tracker.x+10,tracker.y+4);for i,t in ipairs(lines)do love.graphics.printf(t,tracker.x+10,tracker.y-6+i*36,298,'left')end else tracker.h=0 end
 for _,n in ipairs(w.questNPCs)do local a=Q.state(p,n).active;if a and a.kind=='story' and a.storyEscort then local e=a.storyEscort;local sx,sy=camera:toScreen(e.destX,e.destY,sw,sh);sx=math.max(30,math.min(sw-90,sx));sy=math.max(40,math.min(sh-40,sy));love.graphics.setColor(.75,.45,1);love.graphics.circle('line',sx,sy,10);love.graphics.print('Story escort destination',sx-55,sy+12) elseif a and a.kind=='escort' and a.progress<2 then
  local tx,ty=a.destX,a.destY;if a.progress==1 then tx,ty=n.homeX,n.homeY end
  local sx,sy=camera:toScreen(tx,ty,sw,sh);sx=math.max(30,math.min(sw-90,sx));sy=math.max(40,math.min(sh-40,sy));love.graphics.setColor(1,.8,.2);love.graphics.circle('line',sx,sy,10);love.graphics.print(a.progress==0 and 'Escort destination' or 'Return here',sx-35,sy+12)
 end end
 -- Kill-quest target guidance: arrows clamp to the screen edge and point toward each living spawned target.
 for _,e in ipairs(w.enemies or {}) do if e.questTarget and e.questSpawnKey and not e.dead and not e.inactive then
  local active=false;for key,s in pairs(p.quests or {}) do if key==e.questSpawnKey and s.active and s.active.kind=='kill' and s.active.target==e.kind then active=true;break end end
  if active then local sx,sy=camera:toScreen(e.x,e.y,sw,sh);local margin=42;if sx<margin or sx>sw-margin or sy<margin or sy>sh-margin then local dx,dy=sx-sw/2,sy-sh/2;local len=math.max(1,math.sqrt(dx*dx+dy*dy));dx,dy=dx/len,dy/len;local scale=math.min((sw/2-margin)/math.max(.001,math.abs(dx)),(sh/2-margin)/math.max(.001,math.abs(dy)));local ax,ay=sw/2+dx*scale,sh/2+dy*scale;local ang=math.atan2(dy,dx);love.graphics.setColor(1,.28,.12,.95);love.graphics.push();love.graphics.translate(ax,ay);love.graphics.rotate(ang);love.graphics.polygon('fill',14,0,-9,-8,-5,0,-9,8);love.graphics.pop() else love.graphics.setColor(1,.28,.12,.9);love.graphics.circle('line',sx,sy,12) end end
 end end
 for _,s in pairs(p.quests or {})do local a=s.active;if a and (a.kind=='clearCave' or a.kind=='clearCamp') and a.progress<1 and a.siteX then local sx,sy=camera:toScreen(a.siteX,a.siteY,sw,sh);local margin=42;if sx<margin or sx>sw-margin or sy<margin or sy>sh-margin then local dx,dy=sx-sw/2,sy-sh/2;local len=math.max(1,math.sqrt(dx*dx+dy*dy));dx,dy=dx/len,dy/len;local scale=math.min((sw/2-margin)/math.max(.001,math.abs(dx)),(sh/2-margin)/math.max(.001,math.abs(dy)));local ax,ay=sw/2+dx*scale,sh/2+dy*scale;love.graphics.setColor(1,.65,.12,.95);love.graphics.push();love.graphics.translate(ax,ay);love.graphics.rotate(math.atan2(dy,dx));love.graphics.polygon('fill',14,0,-9,-8,-5,0,-9,8);love.graphics.pop()end end end
 local n=ui.questPanel
 if not n then
  local mx,my=love.mouse.getPosition();local wx,wy=camera:toWorld(mx,my,sw,sh)
  for _,v in ipairs(w.questNPCs)do if distance(v,{x=wx,y=wy})<20^2 then local s=Q.state(p,v);ui:drawTooltip({name=v.name},mx,my,sw,sh,{title=v.name,type='Quest giver',detail='Left-click nearby to accept or claim. Completed: '..s.completed..'. Every 5 quests awards 250 bonus copper coins.'});break end end;return
 end
 local x,y,width,height=rect();love.graphics.setColor(.055,.05,.035,.98);love.graphics.rectangle('fill',x,y,width,height,6);love.graphics.setColor(.8,.65,.3);love.graphics.rectangle('line',x,y,width,height,6);love.graphics.print(n.name,x+16,y+12);love.graphics.print('X',x+width-24,y+12)
 local s=Q.state(p,n);local a,err=s.active;if not a then a,err=Q.offer(w,p,ui.skills,n)end
 if not a then
  love.graphics.setColor(.95,.93,.85);love.graphics.printf(err or 'No quest is available from this character.',x+16,y+42,width-32,'left')
  love.graphics.setColor(.7,.7,.65);love.graphics.print('Completed: '..s.completed..' | Bonus: 250 coins every 5 quests',x+16,y+200)
  love.graphics.setColor(.13,.14,.12);love.graphics.rectangle('fill',x+16,y+224,width-32,36,4);love.graphics.setColor(.7,.7,.65);love.graphics.printf('Quest unavailable',x+16,y+234,width-32,'center');return
 end
 if s.active and a and a.kind=='story' then local node=storyNode(a);love.graphics.setColor(.95,.93,.85);love.graphics.printf((node and node.text) or '...',x+16,y+48,width-32,'left');for i,r in ipairs((node and node.responses) or {})do if i<=3 and r.text and r.text~='' then local yy=y+168+(i-1)*38;love.graphics.setColor(.18,.24,.13);love.graphics.rectangle('fill',x+16,yy,width-32,32,4);love.graphics.setColor(1,1,1);love.graphics.printf(r.text,x+24,yy+8,width-48,'left')end end;love.graphics.setColor(.7,.7,.65);love.graphics.print('Choose a response.',x+16,y+140);return end
 local cooldownText=((s.cooldown or 0)>0 and not s.active) and ('\n\nNext quest available in '..math.ceil(s.cooldown)..' seconds.') or ''
 local dialogue=a.dialogue or {};local body=(a.custom and ((s.active and a.progress>=a.count and dialogue.complete) or (s.active and dialogue.progress) or dialogue.available or a.description or '') or (a.kind=='gather' and 'Only items you gather after accepting count. Required items are consumed when you turn the quest in.' or a.kind=='kill' and 'Player and mercenary kills count. Town guard kills do not.' or a.kind=='clearCave' and 'A dangerous cave has appeared in the wilderness. Enter it and defeat every enemy inside.' or a.kind=='clearCamp' and 'A goblin camp has appeared in the wilderness. Defeat every goblin in the camp.' or 'Follow you to the marked town, then back here. Stay close; protect the traveler from enemies. Only one escort at a time.'))
 local itemText='';for _,it in ipairs(a.rewardItems or {})do if it.name and it.name~='(none)'then itemText=itemText..' + '..(it.qty or 1)..' '..it.name end end
 local text=err or (a.title..'\n\n'..body..'\n\nReward: '..rewardCoinText(a)..((a.xp or 0)>0 and ' + '..a.xp..' '..tostring(a.skill)..' XP' or '')..itemText..(s.active and '\nProgress: '..a.progress..' / '..a.count or '')..cooldownText)
 love.graphics.setColor(.95,.93,.85);love.graphics.printf(text,x+16,y+42,width-32,'left');love.graphics.print('Completed: '..s.completed..' | Bonus: 250 coins every 5 quests',x+16,y+200)
 love.graphics.setColor(.25,.32,.16);love.graphics.rectangle('fill',x+16,y+224,width-32,36,4);love.graphics.setColor(1,1,1);love.graphics.printf(not a and 'Quest unavailable' or not s.active and 'Accept quest' or a.progress>=a.count and 'Claim reward' or 'Quest in progress',x+16,y+234,width-32,'center')
 if s.active then love.graphics.printf('Abandon quest',x+16,y+274,width-32,'center')end
end
return Q

