"""Real two-account HTTP boss replication and damage, isolated SQLite fixture."""
from pathlib import Path
import json,sqlite3,threading,urllib.request,urllib.error,gc,time
from contextlib import closing
from simulation import Simulation
from camps import Camps,pack,unpack
import server
root=Path(__file__).resolve().parent.parent
folder=root/'Server/healing_http_test_data';folder.mkdir(exist_ok=True);db=folder/'test.sqlite3';db.unlink(missing_ok=True)
server.initialize(db)
for name in ('heal_a','heal_b'):server.create_user(db,name,'fixture_password_only')
service=server.Service(('127.0.0.1',0),db);service.simulation=Simulation(root);service.camps=Camps(service)
threading.Thread(target=service.serve_forever,daemon=True).start();url=f'http://127.0.0.1:{service.server_port}'
def http(path,data,token=None,method='POST'):
 req=urllib.request.Request(url+path,data=json.dumps(data).encode(),method=method,headers={'Content-Type':'application/json',**({'Authorization':'Bearer '+token}if token else{})})
 try:
  with urllib.request.urlopen(req,timeout=30)as r:return r.status,json.load(r)
 except urllib.error.HTTPError as e:return e.code,json.load(e)
def values(v):return v.values()if isinstance(v,dict)else v
try:
 fixture=json.loads(service.simulation.eval(r"""
local w=SG_SERVER.world;w.enemies={};w.sheep={};w.guards={};w.mercs={};w.nodes={}
local p=require('game.player').new();p.x,p.y=1000,1000;p.hp=200;p.maxHp=495;p.stamina=100;p.maxStamina=100
local sk=require('game.skills').new();for _,key in ipairs({'Magic','Health'})do sk.data[key].level=99;sk.data[key].xp=sk.xpTable[99]end
local inv=require('game.inventory').new();inv.bagSlots[1].slots[4]={name='Green Slime Tube',qty=10,blessed=true}
local R=require('game.regions');return require('game.json').encode({worldId=R.doc.worldId,worldFingerprint=R.networkFingerprint,regionId=R.start,slot=1,seq=1,initial=true,area='overworld',personal=require('game.profile').pack({player=p,skills=sk.data,bags=inv.bagSlots,equipment={offhand='Spellbook'},spellPages={'Healing Spell Page','Healing Spell Page'},bank={},bankSize=25})})
"""))
 accounts=[]
 for name in ('heal_a','heal_b'):
  code,login=http('/v1/login',{'name':name,'password':'fixture_password_only'});assert code==200
  token=login['token'];state=unpack(fixture['personal']);state['player']['name']=name
  if name=='heal_b':state['player']['x']=1100;state['player']['hp']=100
  clean=dict(state,bags={},skills={});record={'name':name,'race':'Human','save':json.dumps(pack(clean))}
  code,result=http('/v1/characters/1',{'revision':0,'character':record},token,'PUT');assert code==200,result
  record['save']=json.dumps(pack(state))
  with closing(sqlite3.connect(db))as c:
   uid=c.execute('SELECT id FROM users WHERE name=?',(name,)).fetchone()[0];c.execute('UPDATE characters SET data=? WHERE user=? AND slot=1',(json.dumps(record),uid));c.commit()
  body=dict(fixture,personal=pack(state));code,result=http('/v1/multiplayer',body,token);assert code==200,result
  accounts.append({'token':token,'body':body,'state':state,'id':uid,'seq':1})
 a,b=accounts
 def exchange(account,action=None):
  account['seq']+=1;body=dict(account['body'],seq=account['seq'],initial=False,personal=pack(account['state']))
  if action:body['action']=action
  code,result=http('/v1/multiplayer',body,account['token']);assert code==200,result
  account['lastBody']=body
  if result.get('personal'):
   account['state'].update(unpack(result['personal']))
  else:account['state']['player']['hp']+=result['delta']['hp'];account['state']['player']['stamina']+=result['delta']['stamina']
  return result
 result=exchange(a,{'kind':'spell','slot':1,'healPlayerId':b['id']});assert result['result']['ok'],result
 assert not a['state']['player'].get('healingPulse'),'Caster received ally pulse'
 assert a['state']['bags'][1]['slots'][4]['qty']==9,'Rune not consumed exactly once'
 service.simulation.call('tick',{'dt':.1,'time':time.monotonic()-service.simulation.started})
 result=exchange(b);assert result['delta']['hp']>0,result
 assert a['state']['player']['hp']==200,'Ally heal affected caster'
 peer=next(p for p in exchange(a)['players']if p['id']==b['id']);assert peer['hp']>100 and peer['maxHp']==495,'Health missing from peer replication'
 # Invalid recipient never falls back to healing the caster and never consumes a rune.
 old=a['state']['bags'][1]['slots'][4]['qty'];result=exchange(a,{'kind':'spell','slot':2,'healPlayerId':999999});assert not result['result']['ok'];assert a['state']['bags'][1]['slots'][4]['qty']==old
 a['state']['player']['x']=500;result=exchange(a,{'kind':'spell','slot':2,'healPlayerId':b['id']});assert not result['result']['ok']and result['result']['reason']=='range',result;assert a['state']['bags'][1]['slots'][4]['qty']==old
 # No target keeps the original self heal.
 result=exchange(a,{'kind':'spell','slot':2});assert result['result']['ok'],result
 service.simulation.call('tick',{'dt':.1,'time':time.monotonic()-service.simulation.started});result=exchange(a);assert result['delta']['hp']>0,'Self heal regression'
 # Leaving removes the authoritative recipient.
 code,_=http('/v1/presence/leave',{'slot':1},b['token']);assert code==200
 result=exchange(a,{'kind':'spell','slot':1,'healPlayerId':b['id']});assert not result['result']['ok'],'Disconnected recipient accepted'
 assert service.simulation.error is None
 print('PASS real two-account healing HTTP: ally receives pulse, caster unchanged, exact rune cost, replicated health, invalid/range/disconnected target rejection, self-heal fallback')
finally:
 service.shutdown();service.server_close();service.simulation.close();gc.collect();db.unlink();folder.rmdir()
