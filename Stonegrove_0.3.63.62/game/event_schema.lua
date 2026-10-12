-- Data-only command catalog shared by the editor, validator and runtime.
local S={commands={},order={},triggers={'interact','touch','autorun','parallel','skill','signal','manual'}}
local function add(id,label,fields)S.order[#S.order+1]=id;S.commands[id]={label=label,fields=fields or{}}end
add('message','Show dialogue',{{'speaker','Speaker'},{'text','Dialogue text'}})
add('choice','Show choices',{{'speaker','Speaker'},{'text','Question'},{'options','Options separated by |'},{'variable','Store chosen number in variable'}})
add('wait','Wait',{{'seconds','Seconds'}})
add('move','Move actor / object',{{'target','Actor / object','target'},{'x','Destination X'},{'y','Destination Y'},{'seconds','Duration (seconds)'},{'through','Ignore collision? true/false'}})
add('teleport','Set actor / object position',{{'target','Actor / object','target'},{'x','Destination X'},{'y','Destination Y'},{'through','Ignore collision? true/false'}})
add('face','Face direction',{{'target','Actor','target'},{'direction','Facing','direction'}})
add('camera','Move camera',{{'x','Camera X'},{'y','Camera Y'},{'seconds','Duration (seconds)'}})
add('camera_follow','Return camera to player')
add('fade','Fade screen',{{'value','Opacity 0-1'},{'seconds','Duration (seconds)'}})
add('variable','Set / add variable',{{'variable','Variable name'},{'operation','set / add','operation'},{'value','Number or text'}})
add('switch','Set switch',{{'variable','Switch name'},{'value','true / false'}})
add('if','Conditional branch',{{'test','Condition','test'},{'key','Variable / switch / skill / item','conditionKey'},{'compare','Comparison','compare'},{'value','Compare value'}})
add('else','Else branch');add('end_if','End branch')
add('label','Label',{{'name','Label name'}});add('jump','Jump to label',{{'name','Label name'}})
add('call','Run another event',{{'event','Event ID','event'},{'wait','Wait until finished? true/false'}})
add('stop','End this event')
add('skill_xp','Give skill XP',{{'skill','Skill','skill'},{'amount','Base XP (racial bonuses apply)'}})
add('skill_set','Set skill level',{{'skill','Skill','skill'},{'level','Level 1-99'}})
add('item','Give / take item',{{'item','Item','item'},{'amount','Quantity (negative = take)'}})
add('equip','Equip actor',{{'target','Actor','target'},{'slot','Equipment slot','slot'},{'item','Item (blank clears)','item'}})
add('race','Change actor race',{{'target','Actor','target'},{'race','Race','race'}})
add('vitals','Set actor health / stamina',{{'target','Actor','target'},{'health','Health (blank unchanged)'},{'stamina','Stamina (blank unchanged)'}})
add('property','Set actor / object property',{{'target','Actor / object','target'},{'property','Existing scalar property name'},{'value','Number, text, true or false'}})
add('spawn_npc','Spawn NPC prefab',{{'npc','NPC definition','npc'},{'x','X'},{'y','Y'}})
add('remove','Remove actor / object',{{'target','Actor / object','target'}})
add('transfer','Transfer player to map',{{'map','Destination map','map'},{'x','X'},{'y','Y'}})
add('sound','Play sound',{{'sound','Sound cue','sound'}})
add('emit','Send event signal',{{'signal','Signal name'}})
function S.boolean(v)return v==true or v=='true'or v=='1'end
function S.validate(doc,context)
 if type(doc)~='table'or type(doc.entries)~='table'then return false,'Invalid event document.'end
 local ids={};for _,e in ipairs(doc.entries)do if type(e.id)~='string'or e.id==''or ids[e.id]then return false,'Every event needs a unique ID.'end;ids[e.id]=true end
 local validTriggers={};for _,v in ipairs(S.triggers)do validTriggers[v]=true end
 for _,e in ipairs(doc.entries)do
  if not validTriggers[e.trigger]then return false,e.id..': choose a trigger.'end
  if context and e.map and e.map~='*'and not context.maps[e.map]then return false,e.id..': unknown map.'end
  for _,key in ipairs({'x','y','radius','cooldown'})do if e[key]~=nil and e[key]~=''then local n=tonumber(e[key]);if not n or n~=n or math.abs(n)==math.huge or (key~='x'and key~='y'and n<0)then return false,e.id..': invalid '..key end end end
  local depth=0;local branches={};local labels={};for _,c in ipairs(e.commands or{})do if c.op=='label'then if not c.name or c.name==''or labels[c.name]then return false,e.id..': labels must be unique and nonempty.'end;labels[c.name]=true end end
  for _,c in ipairs(e.commands or{})do
   local required={move={'target','x','y','seconds'},teleport={'target','x','y'},face={'target','direction'},camera={'x','y','seconds'},wait={'seconds'},variable={'variable'},switch={'variable'},['if']={'test','key','compare','value'},choice={'options','variable'},call={'event'},skill_xp={'skill','amount'},skill_set={'skill','level'},item={'item','amount'},equip={'target','slot'},race={'target','race'},vitals={'target'},spawn_npc={'npc','x','y'},remove={'target'},transfer={'map','x','y'},sound={'sound'},emit={'signal'},property={'target','property','value'}}
   for _,key in ipairs(required[c.op]or{})do if c[key]==nil or c[key]==''then return false,e.id..': '..c.op..' needs '..key end end
   if not S.commands[c.op]then return false,e.id..': unknown command '..tostring(c.op)end
   if c.op=='if'then depth=depth+1;branches[depth]=false elseif c.op=='else'and(depth<1 or branches[depth]) then return false,e.id..': Else has no If.'elseif c.op=='else'then branches[depth]=true elseif c.op=='end_if'then depth=depth-1;if depth<0 then return false,e.id..': End has no If.'end end
   if c.op=='jump'and not labels[c.name]then return false,e.id..': jump label does not exist.'end
   if c.op=='call'and not ids[c.event]then return false,e.id..': called event does not exist.'end
   for _,key in ipairs({'x','y','seconds','amount','level','health','stamina'})do if c[key]~=nil and c[key]~=''then local n=tonumber(c[key]);if not n or n~=n or math.abs(n)==math.huge then return false,e.id..': invalid command '..key end;if key=='seconds'and n<0 then return false,e.id..': duration must be nonnegative.'end end end
   if c.op=='skill_set'and(tonumber(c.level)or 0)<1 or c.op=='skill_set'and(tonumber(c.level)or 100)>99 then return false,e.id..': skill level must be 1-99.'end
   if c.op=='race'and not require('game.races').valid(c.race)then return false,e.id..': invalid race.'end
   if c.op=='equip'and not require('game.paperdoll').slots[c.slot]then return false,e.id..': invalid slot.'end
   if c.op=='face'and not ({up=true,down=true,left=true,right=true})[c.direction]then return false,e.id..': invalid direction.'end
   if c.op=='item'and tonumber(c.amount)%1~=0 then return false,e.id..': item quantity must be an integer.'end
   if c.op=='skill_set'and tonumber(c.level)%1~=0 then return false,e.id..': skill level must be an integer.'end
   if c.op=='if'and not ({variable=true,switch=true,skill=true,item=true,race=true,property=true})[c.test]then return false,e.id..': invalid condition.'end
   if c.op=='if'and not ({['==']=true,['!=']=true,['>=']=true,['<=']=true,['>']=true,['<']=true})[c.compare]then return false,e.id..': invalid comparison.'end
   if c.op=='sound'and not require('game.sound_catalog').sounds[c.sound]then return false,e.id..': unknown sound cue.'end
   if context then
    if c.skill and not context.skills[c.skill]then return false,e.id..': unknown skill.'end
    if c.item and c.item~=''and not context.items[c.item]then return false,e.id..': unknown item.'end
    if c.map and not context.maps[c.map]then return false,e.id..': unknown destination map.'end
    if c.npc and not context.npcs[c.npc]then return false,e.id..': unknown NPC definition.'end
   end
  end
  if depth~=0 then return false,e.id..': close every If with End branch.'end
 end;return true
end
return S
