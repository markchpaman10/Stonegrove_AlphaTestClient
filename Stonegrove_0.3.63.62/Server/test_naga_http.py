"""Real two-account HTTP boss replication and damage, isolated SQLite fixture."""
from pathlib import Path
import json,sqlite3,threading,urllib.request,urllib.error,gc,time
from contextlib import closing
from simulation import Simulation
from camps import Camps,pack,unpack
import server
root=Path(__file__).resolve().parent.parent
folder=root/'Server/naga_http_test_data';folder.mkdir(exist_ok=True);db=folder/'test.sqlite3';db.unlink(missing_ok=True)
server.initialize(db)
for name in ('naga_a','naga_b'):server.create_user(db,name,'fixture_password_only')
service=server.Service(('127.0.0.1',0),db);service.simulation=Simulation(root);service.camps=Camps(service)
threading.Thread(target=service.serve_forever,daemon=True).start();url=f'http://127.0.0.1:{service.server_port}'
def http(path,data,token=None,method='POST'):
 req=urllib.request.Request(url+path,data=json.dumps(data).encode(),method=method,headers={'Content-Type':'application/json',**({'Authorization':'Bearer '+token}if token else{})})
 try:
  with urllib.request.urlopen(req,timeout=30)as r:return r.status,json.load(r)
 except urllib.error.HTTPError as e:return e.code,json.load(e)
def values(v):return v.values()if isinstance(v,dict)else v
try:
 fixture=json.loads(service.simulation.eval(r'''
local w=SG_SERVER.world;local q;for _,e in ipairs(w.enemies)do if e.kind=='nagaQueen'then q=e end end;assert(not q,'No procedural Queen');local N=require('game.naga_queen');local x,y;for yy=160,w.map.height-160,160 do for xx=160,w.map.width-160,160 do if not x and N.allowed(w,xx,yy)and not w:enemyBlocked(xx,yy)then x,y=xx,yy end end end;assert(x);local authored=require('game.rune_inventory').copy(w.map.authored);authored.spawnZones={{enemy='nagaQueen',x=x-32,y=y-32,w=64,h=64,count=1,level=12}};local placed=require('game.world').new(SG_SERVER.sprites,authored);for _,e in ipairs(placed.enemies)do if e.kind=='nagaQueen'then q=e end end;assert(q,'Editor Queen placed');q.editorSpawnZone=1;w.enemies={q};w.groundItems={};w.sheep={};w.guards={};w.mercs={};q.nagaPhase='rest';q.nagaTimer=100;SG_SERVER.nagaQA=q
local p=require('game.player').new();p.x,p.y=q.x-30,q.y;p.hp=200;p.maxHp=495;local sk=require('game.skills').new();sk.data.Health.level=99;sk.data.Health.xp=sk.xpTable[99]
local inv=require('game.inventory').new();local R=require('game.regions');return require('game.json').encode({worldId=R.doc.worldId,worldFingerprint=R.networkFingerprint,regionId=R.start,slot=1,seq=1,initial=true,area='overworld',personal=require('game.profile').pack({player=p,skills=sk.data,bags=inv.bagSlots,equipment={},bank={},bankSize=25})})
'''))
 accounts=[]
 for name in ('naga_a','naga_b'):
  code,login=http('/v1/login',{'name':name,'password':'fixture_password_only'});assert code==200
  token=login['token'];state=unpack(fixture['personal']);state['player']['name']=name
  if name=='naga_b':state['player']['x']-=10
  clean=dict(state,bags={},skills={});record={'name':name,'race':'Human','save':json.dumps(pack(clean))}
  code,result=http('/v1/characters/1',{'revision':0,'character':record},token,'PUT');assert code==200,result
  record['save']=json.dumps(pack(state))
  with closing(sqlite3.connect(db))as c:
   uid=c.execute('SELECT id FROM users WHERE name=?',(name,)).fetchone()[0];c.execute('UPDATE characters SET data=? WHERE user=? AND slot=1',(json.dumps(record),uid));c.commit()
  body=dict(fixture,personal=pack(state));code,result=http('/v1/multiplayer',body,token);assert code==200,result
  queen=next(e for e in values(unpack(result['snapshot'])['enemies'])if e['kind']=='nagaQueen');assert queen['level']==12 and queen['nagaPhase']=='rest'
  accounts.append((token,body,queen['netId']))
 assert accounts[0][2]==accounts[1][2],'Different replicated boss identity'
 service.simulation.eval(r'''
local w=SG_SERVER.world;local q=SG_SERVER.nagaQA;q.nagaPhase='windup';q.nagaAttack='tail';q.nagaTimer=.01;q.nagaAimX=q.x;q.nagaAimY=q.y
w.nodes={{kind='tree',x=q.x+4,y=q.y,hp=6,maxHp=6,shake=0,depleted=false,respawnTimer=0},{kind='oak',x=q.x+8,y=q.y,hp=9,maxHp=9,shake=0,depleted=false,respawnTimer=0}};require('game.node_index').invalidate(w)
return 'ready'
''')
 service.simulation.call('tick',{'dt':.1,'time':time.monotonic()-service.simulation.started})
 for token,body,boss_id in accounts:
  code,result=http('/v1/multiplayer',dict(body,seq=2,initial=True,nagaPhase='rest'),token);assert code==200,result
  snapshot=unpack(result['snapshot']);queen=next(e for e in values(snapshot['enemies'])if e['kind']=='nagaQueen');assert queen['netId']==boss_id and queen['nagaPhase']=='recover'and queen['nagaAttack']=='tail'
  assert result['delta']['hp']<0,'Boss damage missing for participant'
  nodes=list(values(snapshot['nodes']));assert all(n['depleted']for n in nodes),'Tree changes not replicated'
  loot=list(values(snapshot['groundItems']));baseline_hides=sum(q['name']=='Raw Cave Snake Hide'for q in loot);baseline_bones=sum(q['name']=='Bones'for q in loot);assert any(n['name']=='Pine Logs'for n in loot)and any(n['name']=='Oak Logs'for n in loot)

 service.simulation.eval(r"""
local w=SG_SERVER.world;local q=SG_SERVER.nagaQA;q.nagaPhase='rest';q.nagaTimer=100;q.nagaAttack='magic';q.nagaAimX=q.x+150;q.nagaAimY=q.y-35
require('game.naga_queen').strike(w,q,w.playerRef);local bolt=w.bossShots[#w.bossShots];bolt.time=5;bolt.vx=20;bolt.vy=0
local rng=math.random;math.random=function(a,b)if a==1 and b==4 then return 4 end;return rng(a,b)end;require('game.naga_queen').onDeath(w,q);math.random=rng
return 'ready'
""")
 for token,body,boss_id in accounts:
  code,result=http('/v1/multiplayer',dict(body,seq=3,initial=True),token);assert code==200,result
  snapshot=unpack(result['snapshot']);shots=list(values(snapshot['bossShots']));assert any(q.get('spellName')=='Water Bolt'and q.get('row')==2 for q in shots),'Water Bolt not replicated'
  loot=list(values(snapshot['groundItems']));assert sum(q['name']=='Raw Cave Snake Hide'for q in loot)-baseline_hides==5 and sum(q['name']=='Bones'for q in loot)-baseline_bones==10,'Boss loot not replicated: '+str([(q['name'],q.get('qty',1))for q in loot])
 assert service.simulation.error is None
 print('PASS real two-account /v1/multiplayer: same boss identity/level/phase, cooperative encounter damage, replicated pine/oak stumps and logs; client boss phase ignored; real Water Bolt and exact boss loot replicated')
finally:
 service.shutdown();service.server_close();service.simulation.close();gc.collect();db.unlink();folder.rmdir()

