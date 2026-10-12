from pathlib import Path
import tempfile,json,threading,urllib.request,urllib.error
from simulation import Simulation
from camps import pack,unpack
import server
root=Path(__file__).resolve().parent.parent
folder=root/'Server'/'graves_http_test_data';folder.mkdir(exist_ok=True)
for file in folder.glob('*'):file.unlink()
db=folder/'qa.sqlite3';server.initialize(db)
for name in ('grave_owner','grave_helper'):server.create_user(db,name,'qa_password_123')
service=server.Service(('127.0.0.1',0),db);s=service.simulation=Simulation(root,data_dir=folder);s.stopped.set();s.thread.join()
threading.Thread(target=service.serve_forever,daemon=True).start();base=f'http://127.0.0.1:{service.server_port}';checks=0

def check(v,msg):
 global checks
 assert v,msg
 checks+=1

def http(path,data=None,token=None,method='POST'):
 req=urllib.request.Request(base+path,data=json.dumps(data).encode()if data is not None else None,method=method,headers={'Content-Type':'application/json',**({'Authorization':'Bearer '+token}if token else{})})
 try:
  with urllib.request.urlopen(req,timeout=30)as response:return response.status,json.load(response)
 except urllib.error.HTTPError as e:return e.code,json.load(e)
try:
 fixture=json.loads(s.eval(r'''
local w=SG_SERVER.world;w.enemies={};w.farmAnimals={};local sk=require('game.skills').new();sk.data.Religion.xp=sk.xpTable[30];sk.data.Religion.level=30;local inv=require('game.inventory').new();inv:add('Copper Axe',1);inv:add('Copper Pickaxe',1);inv:add('Copper Knife',1);local p=require('game.player').new();p.x,p.y=600,600;p.hp=5;p.maxHp=5
return require('game.json').encode({worldId=require('game.regions').doc.worldId,worldFingerprint=require('game.regions').networkFingerprint,regionId=require('game.regions').start,area='overworld',initial=true,seq=1,slot=1,personal=require('game.profile').pack({bagSchemaVersion=2,graveEpoch=0,player=p,skills=sk.data,bags=inv.bagSlots,equipment={weapon='Copper Longsword'},equipmentItems={weapon={name='Copper Longsword',qty=1,qualityGrade='A'}},equipmentSockets={},potionBelt={[1]='Cooked Crab Meat A'},bank=inv.bank,bankSize=25})})
'''))
 accounts=[]
 for name in ('grave_owner','grave_helper'):
  code,user=http('/v1/login',{'name':name,'password':'qa_password_123'});check(code==200,'Login');token=user['token'];state=unpack(fixture['personal']);state['player']['name']=name
  character={'name':name,'race':'Human','save':json.dumps(pack(state))};check(http('/v1/characters/1',{'revision':0,'character':character},token,'PUT')[0]==200,'Initial save');accounts.append({'token':token,'state':state,'seq':0})
 def exchange(account,action=None):
  account['seq']+=1;body=dict(fixture,seq=account['seq'],initial=account['seq']==1,personal=pack(account['state']));body['action']=action
  code,result=http('/v1/multiplayer',body,account['token']);check(code==200,'Exchange '+str(result));
  if result.get('personal'):account['state'].update(unpack(result['personal']))
  return result
 owner,helper=accounts;exchange(owner);exchange(helper)
 owner['state']['player']['hp']=0;exchange(owner);s.call('tick',{'dt':.05,'time':1})
 reply=exchange(owner);check(reply.get('personal')is not None,'Death automatically forces personal state');check(not owner['state']['bags']and not owner['state']['equipment']and not owner['state']['potionBelt'],'All belongings removed');snapshot=unpack(reply['snapshot']);grave=next(iter(snapshot['gravestones'].values()));check(grave['hp']==50 and grave['remaining']>59 and grave['typeLevel']==30,'Religion30 tombstone');check('contents'not in grave,'Public snapshot never exposes escrow');check((owner['state']['player']['x'],owner['state']['player']['y'])!=(600,600),'Town respawn')
 old=unpack(fixture['personal']);owner_epoch=owner['state']['graveEpoch'];owner['state']=old;reply=exchange(owner);check(owner['state']['graveEpoch']==owner_epoch and not owner['state']['bags'],'Stale multiplayer state cannot duplicate items')
 code,data=http('/v1/characters/1',token=owner['token'],method='GET');saved=unpack(json.loads(data['character']['save']));check(not saved['bags']and saved['graveEpoch']==owner_epoch,'Stale durable character overlaid after death')
 check(http('/v1/characters/1',{'revision':data['revision'],'character':{'name':'grave_owner','race':'Human','save':json.dumps(pack(old))}},owner['token'],'PUT')[0]==200,'Stale PUT handled');code,data=http('/v1/characters/1',token=owner['token'],method='GET');check(not unpack(json.loads(data['character']['save']))['bags'],'Stale PUT cannot restore corpse inventory')
 helper['state']['player']['x']=600;helper['state']['player']['y']=600
 helper['state']['skills']['Religion']={'xp':999999999,'level':99}
 r=exchange(helper,{'kind':'grave','op':'recover','target':grave['id']});check(not r['result']['ok'],'Another account cannot recover')
 r=exchange(helper,{'kind':'grave','op':'bless','target':grave['id']});check(r['result']['ok']and r.get('graveCast'),'Server cast begins');s.call('tick',{'dt':.49,'time':1.49});r=exchange(helper);g=next(iter(unpack(r['snapshot'])['gravestones'].values()));check(g['blessingLevel']==0,'Cannot bless before .5 sec');s.call('tick',{'dt':.02,'time':1.51});r=exchange(helper);g=next(iter(unpack(r['snapshot'])['gravestones'].values()));check(g['blessingLevel']==30 and g['remaining']>1800 and g['hp']==50,'Server blessing additive no healing');xp=helper['state']['skills']['Religion']['xp'];r=exchange(helper,{'kind':'grave','op':'bless','target':grave['id']});check(not r['result']['ok'],'Equal blessing rejected');check(helper['state']['skills']['Religion']['xp']==xp,'No repeated XP')
 owner['state']['player']['x']=600;owner['state']['player']['y']=600;r=exchange(owner,{'kind':'grave','op':'recover','target':grave['id']});check(r['result']['ok'],'Owner starts recovery');s.call('tick',{'dt':.5,'time':2.01});r=exchange(owner);check(owner['state']['bags'][1]['slots'][1]['name']=='Copper Axe'and owner['state']['equipmentItems']['weapon']['qualityGrade']=='A'and owner['state']['potionBelt'][1]=='Cooked Crab Meat A','Server recovery metadata contents gear belt');check(not exchange(owner,{'kind':'grave','op':'recover','target':grave['id']})['result']['ok'],'Cannot replay recovery')
 # Restart the actual simulation from its checkpoint; stale database is corrected without a client.
 s.close();service.simulation=None
 code,data=http('/v1/characters/1',token=owner['token'],method='GET');check(unpack(json.loads(data['character']['save']))['bags'][1]['slots'][1]['name']=='Copper Axe','Restart ledger fixes stale database');s=service.simulation=Simulation(root,data_dir=folder);s.stopped.set();s.thread.join();owner['seq']=0;r=exchange(owner);g=next(iter(unpack(r['snapshot'])['gravestones'].values()));check(g['recovered']and g['blessedBy']=='grave_helper','Restart preserves grave history')
 owner['state']['player'].update(x=600,y=600,hp=0);exchange(owner);s.call('tick',{'dt':.05,'time':3});r=exchange(owner);latest=max(unpack(r['snapshot'])['gravestones'].values(),key=lambda v:v['id']);remaining=latest['remaining'];check(not latest.get('broken')and latest['hp']==50,'Second death has independent grave')
 s.close();s=service.simulation=Simulation(root,data_dir=folder);s.stopped.set();s.thread.join();s.call('tick',{'dt':10,'time':10});owner['seq']=0;r=exchange(owner);latest=max(unpack(r['snapshot'])['gravestones'].values(),key=lambda v:v['id']);check(abs(latest['remaining']-(remaining-10))<.001,'Restart timer runs with nobody connected');check(not owner['state']['bags'],'Intact restart preserves empty carried inventory');s.call('tick',{'dt':60,'time':70});r=exchange(owner);latest=max(unpack(r['snapshot'])['gravestones'].values(),key=lambda v:v['id']);drops=unpack(r['snapshot'])['groundItems'];check(latest.get('broken')and len([g for g in drops.values()if g.get('graveLoot')])==6,'Server expiry scatters all six physical objects: '+str(latest)+' drops='+str(drops))
 helper['seq']=0;helper['state']['player'].update(x=600,y=600);helper['state']['bags'][1]['slots']={};r=exchange(helper,{'kind':'pickupAll'});check(r['result']['ok'],'Other player can collect public corpse loot');check(any(v.get('qualityGrade')=='A'for v in helper['state']['bags'][1]['slots'].values()),'Public pickup preserves quality metadata')
 print('PASS',checks,'authenticated grave HTTP/persistence checks')
finally:
 service.shutdown();service.server_close();s.close()
