local C={}
local function load(name)local ok,d=pcall(require,name);return ok and d and d.entries or{} end
local function index(rows)local o={}for _,v in ipairs(rows)do if v.id then o[v.id]=v end end return o end
C.items=index(load('item_data'));C.monsters=index(load('monster_data'));C.npcs=index(load('npc_data'))
function C.equipment(d) local out={};for slot in pairs(require('game.paperdoll').slots)do local n=d['equip_'..slot];if n and n~=''then out[slot]=n end end;return out end
function C.applySprites(s)
 for id,old in pairs(s._customOverrides or{})do s.itemInfo[id]=old.info;s.itemImages[id]=old.image;s.itemQuads[id]=old.quad end;s._customOverrides={};s.paperDolls={};s.paperErrors={}
 for id,d in pairs(C.items)do
  s._customOverrides[id]={info=s.itemInfo[id],image=s.itemImages[id],quad=s.itemQuads[id]}
  local base=d.iconBase;if base and s.itemImages[base]then s.itemImages[id]=s.itemImages[base];s.itemQuads[id]=s.itemQuads[base]end
  local info={};for k,v in pairs(s.itemInfo[id]or s.itemInfo[base]or{})do info[k]=v end
  info.title=d.name or id;info.type=d.type or info.type or'Custom Item';info.detail=d.detail or'Custom item.';if d.equipSlot and d.equipSlot~='' then info.type=require('game.paperdoll').slots[d.equipSlot];info.slot=d.equipSlot;info.customEquipment=true end
  for _,k in ipairs({'damage','defence','attackSpeed','accuracy','requiredLevel'})do if d[k] and d[k]~=''then info[k]=tonumber(d[k])end end;if d.requiredSkill and d.requiredSkill~=''then info.requiredSkill=d.requiredSkill end
  s.itemInfo[id]=info;local ok,err=pcall(require('game.paperdoll').load,s,d,C.assetRoot);if not ok then s.paperErrors=s.paperErrors or{};s.paperErrors[d.id]=tostring(err)end
 end
 local function icon(id,seen)
  if s.paperDolls[id]then return s.itemImages[id],s.itemQuads[id]end
  local d=C.items[id];if not d then return s.itemImages[id],s.itemQuads[id]end
  seen=seen or{};if seen[id]then return nil end;seen[id]=true
  if d.iconBase and d.iconBase~=id then return icon(d.iconBase,seen)end
  local old=s._customOverrides[id];return old and old.image,old and old.quad
 end
 for id in pairs(C.items)do if not s.paperDolls[id]then local image,quad=icon(id);s.itemImages[id]=image or s.itemImages.Bones;s.itemQuads[id]=image and quad or s.itemQuads.Bones end end
end

function C.item(id)return C.items[id]end
function C.monster(id)return C.monsters[id]end
function C.npc(id)return C.npcs[id]end
return C
