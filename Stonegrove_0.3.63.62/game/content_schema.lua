local S={version=1}
local function f(key,label,kind,default,min,max,choices)return {key=key,label=label,kind=kind or 'text',default=default,min=min,max=max,choices=choices}end
local common={f('id','Stable ID','text','new_record'),f('name','Display name','text','New record'),f('enabled','Enabled','bool',true)}
local condition={f('skill','Required skill','skill','Magic'),f('level','Required level','number',1,1,99),f('quest','Completed quest ID','quest','')}
local drop={f('item','Item','item','Pine Logs'),f('chance','Drop chance (percent)','number',100,0,100),f('min','Minimum quantity','number',1,1,100),f('max','Maximum quantity','number',1,1,100)}
S.groups={
 {key='shops',name='Shop',fields={f('trade','Vendor trade (blank = all)','trade',''),f('title','Match shop title (blank = all)','text',''),f('restock','Restock seconds','number',1800,10,86400),f('stock','Stock and prices','list',{},nil,nil,{f('item','Item','item','Pine Logs'),f('qty','Stock quantity','number',10,0,10000),f('buy','Buy price (copper)','number',1,1,1000000),f('sell','Sell price (copper)','number',1,0,1000000),f('accepted','Accept sales','bool',true)})}},
 {key='recipes',name='Recipe',fields={f('station','Station','station','woodcraft'),f('baseName','Existing recipe to balance (blank = new)','recipe',''),f('skill','Skill','skill','Woodworking'),f('level','Required level','number',1,1,99),f('xp','XP per craft','number',10,0,100000),f('duration','Cast seconds','number',2,.1,120),f('tool','Required tool (optional)','item',''),f('output','Output (new recipes)','item','Pine Planks'),f('qty','Output quantity','number',1,1,1000),f('needs','Ingredients (new recipes)','list',{},nil,nil,{f('item','Item','item','Pine Logs'),f('qty','Quantity','number',1,1,1000)}),f('rule','Progression rule','progression','')}},
 {key='lootTables',name='Loot Table',fields={f('target','Enemy kind / custom ID','enemy','rat'),f('replace','Replace regular item drops','bool',false),f('drops','Drop rolls','list',{},nil,nil,drop)}},
 {key='equipment',name='Equipment',fields={f('item','Equipment item','item','Copper Longsword'),f('damage','Damage','number',3,0,10000),f('defence','Defence','number',0,0,10000),f('accuracy','Accuracy','number',1,0,1000),f('attackSpeed','Attack interval (seconds)','number',1,.1,60),f('requiredLevel','Required level','number',1,1,99),f('requiredSkill','Required skill','skill','Melee Combat'),f('rule','Progression rule','progression','')}},
 {key='equipmentSets',name='Equipment Set',fields={f('pieces','Required pieces','list',{},nil,nil,{f('slot','Slot','slot','body'),f('item','Item','item','Copper Armor')}),f('minimum','Minimum equipped pieces','number',2,1,6),f('defence','Defence bonus','number',0,0,1000),f('melee','Melee bonus','number',0,0,1000),f('ranged','Ranged bonus','number',0,0,1000),f('magic','Magic bonus','number',0,0,1000),f('damage','Damage bonus','number',0,0,1000)}},
 {key='bosses',name='World Boss',fields={f('target','Enemy kind / custom ID','enemy','nagaQueen'),f('rule','Spawn progression rule','progression',''),f('respawn','Respawn seconds','number',600,10,86400),f('announcement','Spawn announcement','text','A world boss has appeared!'),f('abilities','Abilities','list',{},nil,nil,{f('name','Ability name','text','Shockwave'),f('cooldown','Cooldown seconds','number',10,1,120),f('radius','Radius (pixels)','number',60,1,300),f('damage','Damage','number',5,0,1000)}),f('drops','Special drop rolls','list',{},nil,nil,drop)}},
 {key='skills',name='Skill',fields={f('skill','Skill','skill','Woodworking'),f('xpMultiplier','XP multiplier','number',1,0,10),f('milestones','Guide milestones','list',{},nil,nil,{f('level','Level','number',10,1,99),f('name','Unlock description','text','New ability')})}},
 {key='progression',name='Progression',fields={f('conditions','All prerequisites','list',{},nil,nil,condition),f('targetType','Gate type','choice','manual',nil,nil,{'manual','recipe','equipment','enemy'}),f('target','Gate target ID / name','text','')}},
 {key='dialogues',name='Dialogue',fields={f('npc','NPC ID (optional)','npc',''),f('quest','Quest ID (optional)','quest',''),f('start','Starting node ID','text','start'),f('nodes','Conversation nodes','list',{},nil,nil,{f('id','Node ID','text','start'),f('text','NPC dialogue','text','Welcome.'),f('responses','Responses','list',{},nil,nil,{f('text','Player response','text','Goodbye.'),f('next','Next node ID (blank = close)','text',''),f('rule','Progression rule','progression','')})})}},
 {key='spawns',name='Spawn Schedule',fields={f('zone','Level Editor spawn placement','spawn',''),f('startHour','Active from hour','number',0,0,23),f('endHour','Active until hour (same = all day)','number',0,0,23),f('respawn','Respawn seconds','number',240,10,86400),f('rule','Progression rule','progression','')}}
}
S.byKey={};for _,g in ipairs(S.groups)do local a={};for _,v in ipairs(common)do a[#a+1]=v end;for _,v in ipairs(g.fields)do a[#a+1]=v end;g.fields=a;S.byKey[g.key]=g end
function S.copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=S.copy(x)end;return t end
function S.defaults(fields)local t={};for _,v in ipairs(fields)do t[v.key]=S.copy(v.default)end;return t end
function S.empty()local t={version=1};for _,g in ipairs(S.groups)do t[g.key]={}end;return t end
function S.validate(data)
 if type(data)~='table'or data.version~=1 then return false,'Unsupported content data'end
 local function fields(row,defs,path)
  for _,d in ipairs(defs)do local v=row[d.key];if d.kind=='number'and type(v)=='number'and({qty=true,min=true,max=true,level=true,requiredLevel=true,minimum=true,startHour=true,endHour=true})[d.key]and v%1~=0 then return false,path..': '..d.label..' must be a whole number'end;if d.kind=='choice'and v~=nil then local found=false;for _,c in ipairs(d.choices)do if c==v then found=true end end;if not found then return false,path..': invalid '..d.label end end;if v==nil then return false,path..': missing '..d.label end;if v~=nil then
   if d.kind=='number'then if type(v)~='number'or v~=v or v<d.min or v>d.max then return false,path..': '..d.label..' must be '..d.min..'–'..d.max end
   elseif d.kind=='bool'then if type(v)~='boolean'then return false,path..': invalid '..d.label end
   elseif d.kind=='list'then if type(v)~='table'or #v>(d.key=='stock'and 1000 or d.key=='drops'and 20 or 200) then return false,path..': invalid list'end;for i,x in ipairs(v)do if type(x)~='table'then return false,path..': invalid row'end;local ok,e=fields(x,d.choices,path..' / '..d.label..' '..i);if not ok then return false,e end end
   elseif type(v)~='string'or #v>4000 then return false,path..': invalid '..d.label end
  end end;return true
 end
 local indexes={};local targets={}
 for _,g in ipairs(S.groups)do local rows=data[g.key]or{};if type(rows)~='table'or #rows>1000 then return false,'Invalid '..g.name end;indexes[g.key]={};for _,row in ipairs(rows)do if type(row)~='table'or type(row.id)~='string'or not row.id:match('^[%w_%-]+$')or indexes[g.key][row.id]then return false,g.name..': missing, invalid or duplicate ID'end;indexes[g.key][row.id]=row;if ({equipment='item',skills='skill',spawns='zone',bosses='target'})[g.key]then local target=row[({equipment='item',skills='skill',spawns='zone',bosses='target'})[g.key]];targets[g.key]=targets[g.key]or{};if target and targets[g.key][target]then return false,g.name..': duplicate target '..target end;if target then targets[g.key][target]=true end end;local ok,e=fields(row,g.fields,g.name..' '..row.id);if not ok then return false,e end;if g.key=='recipes'and row.baseName==''then if #(row.needs or{})==0 then return false,row.id..': add at least one ingredient'end;if require('game.fieldcraft_content').protected(row.output)or require('game.bone_religion').is(row.output)then return false,row.id..': this output uses a specialized ownership handler'end end;if row.drops then for _,d in ipairs(row.drops)do if require('game.bone_religion').is(d.item)then return false,row.id..': bone rewards use the kill-owned bone system'end;if d.min>d.max then return false,row.id..': minimum exceeds maximum'end end end end end
 local function rule(id,where)if id and id~=''and not indexes.progression[id]then return false,where..': missing progression rule '..id end;return true end
 for _,g in ipairs(S.groups)do for _,r in ipairs(data[g.key]or{})do local ok,e=rule(r.rule,r.id);if not ok then return false,e end end end
 for _,r in ipairs(data.dialogues or{})do local nodes={};for _,n in ipairs(r.nodes or{})do if not n.id or n.id==''or nodes[n.id]then return false,r.id..': duplicate or missing node ID'end;nodes[n.id]=n end;if not nodes[r.start]then return false,r.id..': starting node does not exist'end;for _,n in ipairs(r.nodes or{})do if #(n.responses or{})>4 then return false,r.id..': use at most four responses per node'end;for _,a in ipairs(n.responses or{})do if a.next~=''and not nodes[a.next]then return false,r.id..': response links to missing node '..a.next end;local ok,e=rule(a.rule,r.id);if not ok then return false,e end end end end
 return true
end
function S.references(data,items,npcs,monsters,quests,zones,recipes)
 local function present(id,map,what,where)if id and id~=''and not map[id]then return false,where..': unknown '..what..' '..id end;return true end
 local function nested(row,defs,where)
  for _,f in ipairs(defs)do local v=row[f.key];local map=({item=items,npc=npcs,quest=quests,enemy=monsters,skill={}})[f.kind]
   if f.kind=='skill'then for _,name in ipairs(require('game.skills').names)do map[name]=true end end
   if map then local ok,e=present(v,map,f.kind,where);if not ok then return false,e end end
   if f.kind=='list'then for _,x in ipairs(v or{})do local ok,e=nested(x,f.choices,where);if not ok then return false,e end end end
  end;return true
 end
 for _,g in ipairs(S.groups)do for _,r in ipairs(data[g.key]or{})do local ok,e=nested(r,g.fields,g.name..' '..r.id);if not ok then return false,e end
  if g.key=='spawns'then local ok,e=present(r.zone,zones,'spawn placement',r.id);if not ok then return false,e end end
  if g.key=='recipes'and r.baseName~=''and recipes then local found=false;for _,x in ipairs(recipes[r.station]or{})do if x.name==r.baseName then found=true;break end end;if not found then return false,r.id..': original recipe not found at selected station'end end
 end end;return true
end
return S
