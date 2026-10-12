-- Run the original game rules without a window, audio device, or save writes.
local clock=0
local function read(path)local f=io.open(SG_ROOT..'/'..path,'rb');if not f then return end;local d=f:read('*a');f:close();return d end
local function image(path,height)
 if type(path)=='number'then return {getDimensions=function()return path,height end,getWidth=function()return path end,getHeight=function()return height end,setFilter=function()end,mapPixel=function()end}end
 if type(path)=='table'then return path end
 local dims=SG_IMPORTED and SG_IMPORTED[path];local d=not dims and assert(read(path),'Missing asset '..path)
 local function u32(i)local a,b,c,e=d:byte(i,i+3);return ((a*256+b)*256+c)*256+e end
 local w,h=dims and dims[1]or u32(17),dims and dims[2]or u32(21)
 return {getDimensions=function()return w,h end,getWidth=function()return w end,getHeight=function()return h end,setFilter=function()end,setWrap=function()end,getPixel=function()return 0,0,0,0 end,mapPixel=function()end}
end
love={graphics={newImage=image,newQuad=function(...)return {...}end},image={newImageData=image},
 math={random=math.random,newRandomGenerator=function(seed)return {random=function(_,a,b)seed=(seed*48271)%2147483647;local n=seed/2147483647;if not a then return n end;if not b then b=a;a=1 end;return a+math.floor(n*(b-a+1))end}end},timer={getTime=function()return clock end},filesystem={
 load=function(path)if path=='character_save.lua'then return end;return loadfile(SG_ROOT..'/'..path)end,
 getInfo=function(path)return read(path)and{type='file'}or nil end,read=read,write=function()error('Server cannot write game saves')end}}
package.preload['game.audio']=function()return setmetatable({play=function(cue,x,y)if SG_AUDIO then SG_AUDIO('play',cue,x,y)end end,hurt=function(kind,x,y)if SG_AUDIO then SG_AUDIO('hurt',kind,x,y)end end},{__index=function()return function()end end})end
package.preload['utf8']=function()return {char=function(n)if n<128 then return string.char(n)elseif n<2048 then return string.char(192+math.floor(n/64),128+n%64)elseif n<65536 then return string.char(224+math.floor(n/4096),128+math.floor(n/64)%64,128+n%64)else return string.char(240+math.floor(n/262144),128+math.floor(n/4096)%64,128+math.floor(n/64)%64,128+n%64)end end}end
assert(SG_PACKAGE_RAW,'Server world must come from the GitHub downloader')
if SG_PACKAGE_RAW then
 local doc=require('game.json').decode(SG_PACKAGE_RAW);SG_IMPORTED=doc.importedDimensions
 local files={};for name,data in pairs(doc.files)do files[name]=require('game.profile').unpack(data);package.loaded[name]=files[name]end
 local load=love.filesystem.load;love.filesystem.load=function(path)local name=path:match('^([%w_]+)%.lua$');if files[name]then return function()return files[name]end end;return load(path)end
 local info=love.filesystem.getInfo;love.filesystem.getInfo=function(path)if SG_IMPORTED[path]then return{type='file'}end;return info(path)end
end
local worldDocument=package.loaded.current
assert(type(worldDocument)=='table'and worldDocument.format=='StonegroveWorld'and type(worldDocument.worldId)=='string'and worldDocument.worldId~=''and type(worldDocument.maps)=='table'and #worldDocument.maps>0,'Invalid GitHub world document; bundled generation is disabled')
local mapIds={};for _,map in ipairs(worldDocument.maps)do assert(type(map.id)=='string'and not mapIds[map.id]and type(map.data)=='table','Invalid GitHub map');mapIds[map.id]=true;local d=map.data;assert(d.format=='StonegroveMap'and type(d.landCells)=='table','Invalid GitHub map format; bundled generation is disabled');assert(type(d.cols)=='number'and d.cols>=1 and d.cols<=4096 and d.cols%1==0 and type(d.rows)=='number'and d.rows>=1 and d.rows<=4096 and d.rows%1==0,'Invalid GitHub map size');for _,cell in ipairs(d.landCells)do assert(type(cell)=='number'and cell%1==0 and cell>=0 and cell<d.cols*d.rows,'Invalid GitHub terrain cell')end;local valid,why=require('game.level_zones').validate(d);assert(valid,why)end
assert(mapIds[worldDocument.startMap],'GitHub world has no valid starting map')
package.preload['game.world_jobs']=function()return {install=function()end}end
if SG_PACKAGE_RAW and not package.loaded.content_data then package.loaded.content_data=require('game.content_schema').empty()end
local valid,why=require('game.content_schema').validate(require('content_data'));assert(valid,why)
local sprites=require('game.sprites').load()
local function ids(module,key)local out={};for _,row in ipairs(require(module)[key]or{})do out[row.id]=true end;return out end
local monsters={};for _,k in ipairs({'rat','wolf','boar','slime','goblin','nagalian','nagaQueen','skeleton','ghost','gigaRat','slimeBoss','cow','chicken'})do monsters[k]=true end;for id in pairs(ids('monster_data','entries'))do monsters['custom:'..id]=true end
local zones={};local current=require('current');for _,map in ipairs(current.maps or{})do for _,z in ipairs((map.data or{}).spawnZones or{})do if z.placementId then zones[z.placementId]=true end end end
local valid,why=require('game.content_schema').references(require('content_data'),sprites.itemInfo,ids('npc_data','entries'),monsters,ids('quest_data','quests'),zones,require('game.crafting').new():allRecipes());assert(valid,why)
local colors=read('Server/particle_colors.json');if colors then sprites.objectColors=require('game.json').decode(colors)end
for _,record in ipairs(worldDocument.maps)do local ok,why=require('game.mountains').validate(record.data);assert(ok,why)end
local Regions=require('game.regions');Regions.boot(worldDocument,{})
assert(Regions.doc and Regions.data(),'GitHub world failed to initialize; bundled generation is disabled')
local w=Regions.initial(sprites)
SG_SERVER={sprites=sprites,world=w}
function SG_CLOCK(t)clock=t end
