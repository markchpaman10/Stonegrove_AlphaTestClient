from pathlib import Path
import sys,tempfile,threading,urllib.request,urllib.error,json,sqlite3,time
root=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(root/'Server'))
import server
from simulation import Simulation
from camps import Camps
from contextlib import nullcontext
qa=root/'Server'/'character_delete_test_data'/str(time.time_ns());qa.mkdir(parents=True,exist_ok=True)
with nullcontext(str(qa.resolve()))as temp:
 db=Path(temp)/'qa.sqlite3';server.initialize(db)
 for name in ('owner_test','other_test'):server.create_user(db,name,'qa_password_123')
 service=server.Service(('127.0.0.1',0),db);service.simulation=Simulation(root,data_dir=Path(temp));service.camps=Camps(service)
 threading.Thread(target=service.serve_forever,daemon=True).start();base=f'http://127.0.0.1:{service.server_port}'
 def http(path,method='GET',data=None,token=None):
  req=urllib.request.Request(base+path,data=json.dumps(data).encode()if data is not None else None,method=method,headers={'Content-Type':'application/json',**({'Authorization':'Bearer '+token}if token else{})})
  try:
   with urllib.request.urlopen(req,timeout=30)as response:return response.status,json.load(response)
  except urllib.error.HTTPError as e:return e.code,json.load(e)
 try:
  owner=http('/v1/login','POST',{'name':'owner_test','password':'qa_password_123'})[1];other=http('/v1/login','POST',{'name':'other_test','password':'qa_password_123'})[1];token=owner['token'];uid=owner['id'];record={'name':'Delete Me','race':'Human','save':'{"entries":[]}'}
  for slot in (1,2,3):assert http('/v1/characters/'+str(slot),'PUT',{'revision':0,'character':record},token)[0]==200
  assert http('/v1/characters/1','DELETE',{'revision':1,'name':'Delete Me'})[0]==401
  assert http('/v1/characters/1','DELETE',{'revision':1,'name':'Delete Me'},other['token'])[0]==404
  assert http('/v1/characters/1','DELETE',{'revision':0,'name':'Delete Me'},token)[0]==409
  assert http('/v1/characters/1','DELETE',{'revision':1,'name':'Different'},token)[0]==409
  assert http('/v1/characters/4','DELETE',{},token)[0]==404
  with service.presence.lock:service.presence.players[uid]={'slot':1,'seen':service.presence.clock(),'owner':'QA','record':{}}
  assert http('/v1/characters/1','DELETE',{'revision':1,'name':'Delete Me'},token)[0]==409
  with service.presence.lock:service.presence.players.clear()
  fixture=json.loads(service.simulation.eval(r"local p=require('game.player').new();local sk=require('game.skills').new();local inv=require('game.inventory').new();return require('game.json').encode({worldId=require('game.regions').doc.worldId,worldFingerprint=require('game.regions').networkFingerprint,regionId=require('game.regions').start,area='overworld',initial=true,seq=1,slot=1,personal=require('game.profile').pack({player=p,skills=sk.data,bags=inv.bagSlots,equipment={},bank={},bankSize=25})})"))
  fixture.update(id=uid,owner='native-qa',name='Delete Me',race='Human');service.simulation.call('exchange',fixture)
  assert http('/v1/characters/1','DELETE',{'revision':1,'name':'Delete Me'},token)[0]==409
  service.simulation.call('leave',{'id':uid,'owner':'native-qa'})
  with sqlite3.connect(db)as c:
   c.execute("INSERT INTO fieldcraft VALUES(?,1,'{}','',0,'')",(uid,));c.execute("INSERT INTO camp_requests VALUES(?,1,'old','{}')",(uid,));c.commit()
  status,deleted=http('/v1/characters/1','DELETE',{'revision':1,'name':'Delete Me'},token);assert status==200,(status,deleted)
  empty=http('/v1/characters/1',token=token)[1];assert empty=={'revision':2,'character':None}
  rows=http('/v1/characters',token=token)[1]['slots'];assert rows[0]['name']==''and rows[0]['revision']==2 and rows[1]['name']=='Delete Me'and rows[2]['name']=='Delete Me'
  assert (uid,1)not in service.character_meta and service.presence.character_name(uid,1)is None
  assert http('/v1/characters/1','PUT',{'revision':1,'character':record},token)[0]==409
  assert http('/v1/characters/1','DELETE',{'revision':1,'name':'Delete Me'},token)[0]==404
  assert http('/v1/multiplayer','POST',{'slot':1,'seq':1},token)[0]==409
  with sqlite3.connect(db)as c:
   assert c.execute('SELECT count(*)FROM fieldcraft WHERE user=? AND slot=1',(uid,)).fetchone()[0]==0
   assert c.execute('SELECT count(*)FROM camp_requests WHERE user=? AND slot=1',(uid,)).fetchone()[0]==0
  assert http('/v1/characters/1','PUT',{'revision':2,'character':dict(record,name='Replacement')},token)[1]['revision']==3
  assert http('/v1/characters/1','DELETE',{'revision':1,'name':'Delete Me'},token)[0]==409
  assert http('/v1/characters/1','GET',token=token)[1]['character']['name']=='Replacement'
  # Concurrent stale-save vs deletion cannot resurrect the old character.
  barrier=threading.Barrier(2);results=[]
  def operation(method):barrier.wait();results.append((method,http('/v1/characters/1',method,{'revision':3,'name':'Replacement','character':dict(record,name='Replacement')},token)[0]))
  threads=[threading.Thread(target=operation,args=(method,))for method in ('DELETE','PUT')]
  for t in threads:t.start()
  for t in threads:t.join()
  assert sorted(status for method,status in results)==[200,409],results
  service.shutdown();service.server_close();service=server.Service(('127.0.0.1',0),db);threading.Thread(target=service.serve_forever,daemon=True).start();base=f'http://127.0.0.1:{service.server_port}'
  assert http('/v1/characters/2','GET',token=token)[1]['character']['name']=='Delete Me'
  assert http('/v1/characters/1','PUT',{'revision':1,'character':record},token)[0]==409
  print('PASS authenticated character delete, cancel guards, ownership, revision/name validation, active-session refusal, camp/cache cleanup, slot reuse, stale-save prevention, concurrent save/delete and restart durability')
 finally:service.shutdown();service.server_close()

