"""Real exported-world ingestion and two-account zone replication; isolated DB."""
from pathlib import Path
import json,zlib,sqlite3,threading,urllib.request,urllib.error,gc,time
from contextlib import closing
from simulation import Simulation
from camps import Camps,pack,unpack
import server
root=Path(__file__).resolve().parent.parent
folder=root/'Server/level_zone_http_test_data';folder.mkdir(exist_ok=True);db=folder/'test.sqlite3';world=folder/'zones.sgworld'
# Start from the native editor-exported world package, never an authored source file.
fixture=root/'Server/Fixtures/level-zone-editor.sgworld'
raw=fixture.read_bytes();document=json.loads(zlib.decompress(raw[19:]));doc=unpack(document['files']['current'])
def values(v):return v.values()if isinstance(v,dict)else v
record=next(m for m in values(doc['maps'])if m['id']==doc['startMap']);d=record['data'];mask=set(values(d['landCells']));cols,rows=d['cols'],d['rows'];points=[]
def intersects(a,b):return a[0]<b[2]and a[2]>b[0]and a[1]<b[3]and a[3]>b[1]
blocked=[]
for z in values(d.get('townZones',[])):blocked.append((z['x']-80,z['y']-80,z['x']+z['w']+80,z['y']+z['h']+80))
for p in values(d.get('paths',[])):blocked.append((p['x']-80,p['y']-80,p['x']+96,p['y']+96))
for o in values(d.get('objects',[])):blocked.append((o['x']-130,o['y']-130,o['x']+130,o['y']+130))
for y in range(600,rows*16-600,700):
 for x in range(600,cols*16-600,700):
  rect=(x-300,y-300,x+300,y+300)
  if len(points)<2 and not any(intersects(rect,b)for b in blocked)and all(yy*cols+xx in mask for yy in range(int(rect[1]/16),int(rect[3]/16)+1)for xx in range(int(rect[0]/16),int(rect[2]/16)+1)):
   points.append((x,y))
assert len(points)==2,'Need two safe authored fixture zones'
d['mapInfo']={'levelMin':1,'levelMax':20,'connections':{}};d['levelZones']=[];d['spawnZones']=[]
for i,(x,y)in enumerate(points):
 d['levelZones'].append({'name':f'QA Zone {i+1}','x':x-300,'y':y-300,'w':600,'h':600,'level':2 if i==0 else 18,'density':.7,'resourceMode':'auto'if i==0 else'custom','resources':{'iron':True},'enemies':True})
 d['spawnZones'].append({'x':x-200,'y':y-200,'w':400,'h':400,'enemy':'wolf','level':1,'count':5})
d['spawnZones'].append({'x':0,'y':0,'w':16,'h':16,'enemy':'nagaQueen','level':12,'count':1})
document['files']['current']=pack(doc);world.write_bytes(b'STONEGROVE_WORLD_1\n'+zlib.compress(json.dumps(document).encode()))
db.unlink(missing_ok=True);server.initialize(db)
for name in ('zone_a','zone_b'):server.create_user(db,name,'fixture_password_only')
service=server.Service(('127.0.0.1',0),db);service.simulation=Simulation(root,world=world);service.camps=Camps(service)
threading.Thread(target=service.serve_forever,daemon=True).start();url=f'http://127.0.0.1:{service.server_port}'
def http(path,data,token=None,method='POST'):
 req=urllib.request.Request(url+path,data=json.dumps(data).encode(),method=method,headers={'Content-Type':'application/json',**({'Authorization':'Bearer '+token}if token else{})})
 try:
  with urllib.request.urlopen(req,timeout=30)as response:return response.status,json.load(response)
 except urllib.error.HTTPError as e:return e.code,json.load(e)
def values(v):return v.values()if isinstance(v,dict)else v
try:
 body=json.loads(service.simulation.eval(r"""
local w=SG_SERVER.world;local z=w.map.authored.levelZones[2];local p=require('game.player').new();p.x,p.y=z.x+z.w/2,z.y+z.h/2;p.hp=495;p.maxHp=495
local sk=require('game.skills').new();sk.data.Health.level=99;sk.data.Health.xp=sk.xpTable[99];local inv=require('game.inventory').new();local R=require('game.regions')
for _,e in ipairs(w.enemies)do e.attackTimer=1000 end
return require('game.json').encode({worldId=R.doc.worldId,worldFingerprint=R.networkFingerprint,regionId=R.start,slot=1,seq=1,initial=true,area='overworld',personal=require('game.profile').pack({player=p,skills=sk.data,bags=inv.bagSlots,equipment={},bank={},bankSize=25})})
"""))
 accounts=[];identities=[]
 for name in ('zone_a','zone_b'):
  code,login=http('/v1/login',{'name':name,'password':'fixture_password_only'});assert code==200;token=login['token'];state=unpack(body['personal']);state['player']['name']=name;clean=dict(state,bags={},skills={});record={'name':name,'race':'Human','save':json.dumps(pack(clean))}
  code,result=http('/v1/characters/1',{'revision':0,'character':record},token,'PUT');assert code==200,result;record['save']=json.dumps(pack(state))
  with closing(sqlite3.connect(db))as c:
   user=c.execute('SELECT id FROM users WHERE name=?',(name,)).fetchone()[0];c.execute('UPDATE characters SET data=? WHERE user=? AND slot=1',(json.dumps(record),user));c.commit()
  payload=dict(body,personal=pack(state));code,result=http('/v1/multiplayer',payload,token);assert code==200,result;snap=unpack(result['snapshot'])
  nodes=[n for n in values(snap['nodes'])if n.get('levelZone')==2];assert nodes and all(n['kind']=='iron'and 15<=n['resourceLevel']<=20 for n in nodes),'Wrong replicated zone resources'
  wolves=[e for e in values(snap['enemies'])if e.get('editorSpawnZone')==2];assert len(wolves)==5 and all(1<=e['level']<=20 for e in wolves),'Wrong inherited monster levels'
  identities.append((sorted((n['netId'],n['kind'])for n in nodes),sorted((e['netId'],e['level'])for e in wolves)));accounts.append((token,payload))
 assert identities[0]==identities[1],'Clients disagree on nodes or enemy levels'
 node_id=identities[0][0][0][0]
 service.simulation.eval('local w=SG_SERVER.world;for _,n in ipairs(w.nodes)do if n.netId=='+json.dumps(node_id)+" then n.depleted=true;n.hp=0;n.respawnTimer=123;n.prospectCycle=2 end end;return 'ready'")
 checkpoint=service.simulation.call('export',{});service.simulation.call('restore',checkpoint)
 for token,payload in accounts:
  code,result=http('/v1/multiplayer',dict(payload,seq=2,initial=True,levelZones=[],nodes=[{'kind':'coal','hp':999}]),token);assert code==200,result
  restored=next(n for n in values(unpack(result['snapshot'])['nodes'])if n['netId']==node_id);assert restored['kind']=='iron'and restored['depleted']and restored['prospectCycle']==2 and 120<restored['respawnTimer']<=123,'Checkpoint or forged resource data changed authoritative node'
 # Two real authenticated characters occupy one random cave. Clear the authoritative room,
 # then ensure it remains until both exit, closes safely, and refills on the next night.
 token0,payload0=accounts[0];code,result=http('/v1/multiplayer',dict(payload0,seq=3,initial=True),token0);assert code==200,result
 entrance=next(e for e in values(unpack(result['snapshot'])['caveEntrances'])if not e.get('authored')and not e.get('questSpawnKey'))
 for token,payload in accounts:
  code,result=http('/v1/multiplayer',dict(payload,seq=4,initial=True,area='cave',caveId=entrance['id']),token);assert code==200,result
 service.simulation.eval("local w=SG_SERVER.world.caveInstances["+str(entrance['id'])+"];assert(w);for _,e in ipairs(w.enemies)do e.dead=true;e.hp=0 end;require('game.caves').cleared(w);return 'cleared'")
 token,payload=accounts[0];code,result=http('/v1/multiplayer',dict(payload,seq=5,initial=True),token);assert code==200,result
 assert any(e['id']==entrance['id']and e.get('closing')for e in values(unpack(result['snapshot'])['caveEntrances'])),'Cave removed with a player inside'
 token,payload=accounts[1];code,result=http('/v1/multiplayer',dict(payload,seq=5,initial=True),token);assert code==200,result
 time.sleep(.3)
 token,payload=accounts[0];code,result=http('/v1/multiplayer',dict(payload,seq=6,initial=True),token);assert code==200,result
 assert not any(e['id']==entrance['id']for e in values(unpack(result['snapshot'])['caveEntrances'])),'Cleared empty cave remains'
 service.simulation.eval("local w=SG_SERVER.world;w._nightState=false;w:setNightState(true);assert(#w.caveEntrances==3);for _,e in ipairs(w.caveEntrances)do assert(e.id~="+str(entrance['id'])+")end;return 'night refill passed'")
 assert service.simulation.error is None
 print('PASS two-account cleared-cave closure, occupied-cave safeguard, last-player exit and nighttime replenishment')
 print('PASS exported .sgworld dedicated startup; two authenticated accounts share exact zone-generated iron IDs and inherited wolf levels; depletion/prospecting timers survive checkpoint restore; client zone/resource forgery ignored')
finally:
 service.shutdown();service.server_close();service.simulation.close();gc.collect();db.unlink();world.unlink();folder.rmdir()
