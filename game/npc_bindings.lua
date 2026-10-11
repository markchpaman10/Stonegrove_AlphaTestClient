local B={}
B.ids={bagKeeper=true,skillVendor=true,shopkeeper=true,trader=true,healer=true,guard=true,mercRecruiter=true,bankClerk=true,questGather=true,questKill=true,questEscort=true,questCave=true,questCamp=true,questStory=true}
function B.apply(w)
 local actors={};for _,list in ipairs({w.bagKeepers or{},w.customNPCs or{},w.tradeKeepers or{},w.traders or{},w.healers or{},w.guards or{},w.questNPCs or{}})do for _,npc in ipairs(list)do if not npc.linkedCustom then actors[#actors+1]=npc end end end
 for _,key in ipairs({'mercRecruiter','bankClerk'})do if w[key]then actors[#actors+1]=w[key]end end
 for _,npc in ipairs(actors)do for _,o in ipairs((w.map.authored or{}).objects or{})do if B.ids[o.id]and (npc.x-o.x)^2+(npc.y-o.y)^2<1 then
  local d=o.npcDefinition and require('game.custom_content').npc(o.npcDefinition)
  if d then npc.race=d.race or npc.race;npc.gender=d.gender;npc.name=d.name or npc.name;npc.key=d.appearanceKey or d.id;npc.equipment=require('game.custom_content').equipment(d);npc.dialogue=d.dialogue or npc.dialogue end
  npc.eventId=o.eventId~=nil and o.eventId or d and d.eventId;npc.storyEventId=o.storyEventId~=nil and o.storyEventId or d and d.storyEventId
  npc.id=npc.id or o.id..':'..o.x..':'..o.y;npc.linkKey=((w.map.authored or{}).regionId or'root')..':'..o.id..':'..o.x..':'..o.y
  if o.questId~=nil or d then npc.questIds={o.questId~=nil and o.questId or d.quest1,d and d.quest2,d and d.quest3,d and d.quest4,d and d.quest5,d and d.quest6,d and d.quest7,d and d.quest8,d and d.quest9,d and d.quest10,d and d.quest11,d and d.quest12}end
 end end end
 w.interactionNPCs=actors;return actors
end
return B
