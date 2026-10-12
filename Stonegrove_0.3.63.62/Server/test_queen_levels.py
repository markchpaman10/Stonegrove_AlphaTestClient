from pathlib import Path
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent)
try:
 print(s.eval(r'''
local original=SG_SERVER.world;local N=require('game.naga_queen');local M=require('EditorShared.model');local data=M.copy(original.map.authored);local x,y
for yy=160,original.map.height-160,160 do for xx=160,original.map.width-160,160 do if not x and N.allowed(original,xx,yy)and not original:enemyBlocked(xx,yy)then x,y=xx,yy end end end
assert(x,'No safe Queen placement');data.spawnZones={{enemy='nagaQueen',x=x-32,y=y-32,w=64,h=64,level=55,count=1,useZoneLevel=false}};data.objects=data.objects or{}
local w=require('game.world').new(SG_SERVER.sprites,data);local queen
for _,e in ipairs(w.enemies)do if e.kind=='nagaQueen'then assert(not queen,'Only editor population');queen=e end end
assert(queen and queen.editorSpawnZone and queen.level==55,'Editor chosen Queen level');assert(queen.stats.melee==55 and queen.maxHp==1375,'Queen stats scale with chosen level')
data.spawnZones={};w=require('game.world').new(SG_SERVER.sprites,data);for _,e in ipairs(w.enemies)do assert(e.kind~='nagaQueen','Removing editor zone removes Queen')end
return 'PASS actual world generation: Queen level 55 and scaled stats; no Queen without an authored spawn zone'
'''))
finally:s.close()
