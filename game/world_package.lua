local W={names={'current','item_data','npc_data','monster_data','quest_data','event_data'}}
local J=require('game.json');local P=require('game.profile')
function W.export(root)
 local data={format='StonegroveWorldPackage',version=1,files={},assets={}};local model=require('game.data_model')
 for _,name in ipairs(W.names)do data.files[name]=P.pack((assert(model.read(root..'/'..name..'.lua'))))end
 local items=P.unpack(data.files.item_data);for _,row in ipairs(items.entries or{})do local path=row.paperSprite or row.paperPath or row.spritePath;if path and path~=''then assert(path:match('^assets/imported/[%w_%-%.]+%.png$'),'Invalid imported sprite path');local f=assert(io.open(root..'/'..path,'rb'));local bytes=f:read('*a');f:close();data.assets[path]=love.data.encode('string','base64',bytes)end end
 return 'STONEGROVE_WORLD_1\n'..love.data.compress('string','zlib',J.encode(data))
end
function W.decode(bytes)
 assert(bytes:sub(1,19)=='STONEGROVE_WORLD_1\n','Not a Stonegrove world package');assert(#bytes<=16000000,'World package too large');local plain=love.data.decompress('string','zlib',bytes:sub(20));assert(#plain<=64000000,'World package too large');local data=J.decode(plain);assert(data.format=='StonegroveWorldPackage'and data.version==1,'Unsupported world package');local out={files={},assets={}}
 for _,name in ipairs(W.names)do out.files[name]=P.unpack((assert(data.files[name],'Missing '..name)))end
 for _,kind in ipairs({'item','npc','monster','quest'})do local rows=kind=='quest' and out.files.quest_data.quests or out.files[kind..'_data'].entries;assert(type(rows)=='table','Invalid '..kind..' definitions');local seen={};for _,row in ipairs(rows)do assert(type(row)=='table'and type(row.id)=='string'and row.id~=''and not seen[row.id],'Invalid or duplicate '..kind..' ID');seen[row.id]=true;if kind=='npc'or(kind=='monster'and row.baseSprite=='humanoid')then assert(({Human=true,Elf=true,Dwarf=true,Ghost=true})[row.race],'Invalid race')end;if row.spritePath and row.spritePath~=''then assert(row.spritePath:match('^assets/imported/[%w_%-]+%.png$'),'Unsafe sprite path')end end end;local valid,why=require('game.event_schema').validate(out.files.event_data);assert(valid,why);local doc=out.files.current;assert(doc.format=='StonegroveWorld'and type(doc.maps)=='table'and #doc.maps>0 and type(doc.worldId)=='string','Invalid world');local ids={};for _,m in ipairs(doc.maps)do assert(type(m.id)=='string'and not ids[m.id]and type(m.data)=='table','Invalid map');ids[m.id]=true;assert(type(m.data.cols)=='number'and m.data.cols>0 and m.data.cols<=4096 and type(m.data.rows)=='number'and m.data.rows>0 and m.data.rows<=4096,'Invalid map size');local ok,why=require('game.level_zones').validate(m.data);assert(ok,why)end;assert(ids[doc.startMap],'Missing start map')
 for path,encoded in pairs(data.assets or{})do assert(path:match('^assets/imported/[%w_%-%.]+%.png$')and not path:find('%.%.'),'Unsafe asset path');local png=love.data.decode('string','base64',encoded);assert(#png<8000000 and png:sub(1,8)=='\137PNG\r\n\26\n','Invalid PNG');out.assets[path]=png end
 return out
end
function W.activate(bytes)
 local data=W.decode(bytes);for path,png in pairs(data.assets)do love.filesystem.createDirectory('assets/imported');assert(love.filesystem.write(path,png))end
 assert(love.filesystem.write('active_world.sgworld',bytes));W.current=data;for name,d in pairs(data.files)do if name~='current'then package.loaded[name]=d end end
 local c=require('game.custom_content');local function index(d)local a={};for _,r in ipairs(d.entries or{})do a[r.id]=r end;return a end;c.items=index(data.files.item_data);c.npcs=index(data.files.npc_data);c.monsters=index(data.files.monster_data)
end
function W.restore()local bytes=love.filesystem.read('active_world.sgworld');if bytes then local ok,err=pcall(W.activate,bytes);return ok,err end;return true end
function W.github(link,callback)
 local fileOwner,fileRepo,fileBranch,filePath=link:match('^https://github%.com/([%w_.%-]+)/([%w_.%-]+)/blob/([^/]+)/(.+)$')
 if fileOwner then callback('https://raw.githubusercontent.com/'..fileOwner..'/'..fileRepo..'/'..fileBranch..'/'..filePath:gsub('%?.*$',''));return end
 link=link:gsub('%.git$','');local owner,repo=link:match('^https://github%.com/([%w_.%-]+)/([%w_.%-]+)/?$');if owner then require('game.network').request('https://api.github.com/repos/'..owner..'/'..repo,'GET',nil,nil,function(r)if r.status~=200 or not r.data.default_branch then callback(nil,'Cannot find public GitHub repository');return end;callback('https://raw.githubusercontent.com/'..owner..'/'..repo..'/'..r.data.default_branch:gsub('[^%w_.~-]',function(c)return string.format('%%%02X',c:byte())end)..'/latest.sgworld')end)
 elseif link:match('^https://raw%.githubusercontent%.com/')or link:match('^https://github%.com/.+/releases/.+/download/')or link:match('^https://github%.com/.+/releases/download/')then callback(link)else callback(nil,'Paste a public GitHub repository, raw file or release download link')end
end
return W
