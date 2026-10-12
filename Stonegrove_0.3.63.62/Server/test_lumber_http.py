from pathlib import Path
import json,threading,urllib.request,urllib.error,sqlite3
from contextlib import closing
from simulation import Simulation
from camps import pack,unpack
import server
root=Path(__file__).resolve().parent.parent;folder=root/'Server/lumber_http_test_data';folder.mkdir(exist_ok=True)
for p in folder.glob('*'):p.unlink()
db=folder/'qa.sqlite3';server.initialize(db)
for name in ('storage_owner','storage_other'):server.create_user(db,name,'qa_password_123')
service=server.Service(('127.0.0.1',0),db);s=service.simulation=Simulation(root,data_dir=folder);s.stopped.set();s.thread.join();threading.Thread(target=service.serve_forever,daemon=True).start();base=f'http://127.0.0.1:{service.server_port}';checks=0
def ck(v,msg='check'):
 global checks
 assert v,msg;checks+=1
def http(path,data=None,token=None,method='POST'):
 req=urllib.request.Request(base+path,data=json.dumps(data).encode()if data is not None else None,method=method,headers={'Content-Type':'application/json',**({'Authorization':'Bearer '+token}if token else{})})
 try:
  with urllib.request.urlopen(req,timeout=30)as r:return r.status,json.load(r)
 except urllib.error.HTTPError as e:return e.code,json.load(e)
try:
 fixture=json.loads(s.eval("local w=SG_SERVER.world;w.enemies={};w.farmAnimals={};local x,y=500,500;local found=false;for yy=500,900,20 do for xx=500,900,20 do if w.map:isLand(xx+16,yy+16)and not w:playerBlocked(xx+16,yy+16,7)then x,y=xx,yy;found=true;break end end;if found then break end end;assert(found);local inv=require('game.inventory').new();inv.bagSlots[1].slots={[1]={name='Pine Crate',qty=1,qualityGrade='A',contents={}},[2]={name='Carved Feather',qty=12,qualityGrade='B',blessed=true}};local p=require('game.player').new();p.x,p.y=x,y;return require('game.json').encode({worldId=require('game.regions').doc.worldId,regionId=require('game.regions').start,area='overworld',slot=1,initial=true,seq=1,personal=require('game.profile').pack({bagSchemaVersion=2,player=p,skills=require('game.skills').new().data,bags=inv.bagSlots,equipment={},equipmentItems={},potionBelt={},bank=inv.bank,bankSize=25})})"))
 accounts=[]
 for name in ('storage_owner','storage_other'):
  code,user=http('/v1/login',{'name':name,'password':'qa_password_123'});ck(code==200,'login');token=user['token'];state=unpack(fixture['personal']);state['player']['name']=name;character={'name':name,'race':'Human','save':json.dumps(pack(state))};ck(http('/v1/characters/1',{'revision':0,'character':character},token,'PUT')[0]==200,'create');code,response=http('/v1/multiplayer',fixture,token);ck(code==200,str(response));accounts.append({'token':token})
 owner,other=accounts;request=0
 def camp(account,cmd):
  global request
  code,data=http('/v1/characters/1',token=account['token'],method='GET');ck(code==200,'read');request+=1;body={'slot':1,'revision':data['revision'],'request':'storage-'+str(request),'command':cmd};code,result=http('/v1/camp',body,account['token']);return code,result,body
 code,result,_=camp(owner,{'op':'containerStore','bag':1,'slot':1,'sourceBag':1,'sourceSlot':2});ck(code==200,str(result));state=unpack(result['state']);ck(state['bags'][1]['slots'][1]['contents'][1]['qty']==12,'contents')
 code,result,body=camp(owner,{'op':'containerPlace','bag':1,'slot':1});ck(code==200,str(result));ck(http('/v1/camp',body,owner['token'])[0]==200,'idempotent replay');ck(s.eval('return #SG_SERVER.world.placedContainers')=='1','duplicate placement')
 code,_,_=camp(other,{'op':'containerRetrieve','id':1});ck(code==409,'ownership')
 with closing(sqlite3.connect(db))as c:c.execute("CREATE TRIGGER qa_fail BEFORE UPDATE ON characters BEGIN SELECT RAISE(ABORT,'QA failure'); END");c.commit()
 code,_,body=camp(owner,{'op':'containerWithdraw','id':1,'contentSlot':1});ck(code==500,'fault injection')
 ck(s.eval('return SG_SERVER.world.placedContainers[1].object.contents[1].qty')=='12','world rollback')
 with closing(sqlite3.connect(db))as c:c.execute('DROP TRIGGER qa_fail');c.commit()
 code,result=http('/v1/camp',body,owner['token']);ck(code==200,str(result));ck(unpack(result['state'])['bags'][1]['slots'][1]['qty']==12,'withdraw conserved')
 code,result,_=camp(owner,{'op':'containerStore','id':1,'sourceBag':1,'sourceSlot':1});ck(code==200,str(result))
 s.checkpoint();size=(folder/'shared_world.json').stat().st_size;s.close();s=service.simulation=Simulation(root,data_dir=folder);s.stopped.set();s.thread.join()
 ck(s.eval('return SG_SERVER.world.placedContainers[1].object.contents[1].qty')=='12','restart contents');ck(s.eval('return SG_SERVER.world.placedContainers[1].object.contents[1].qualityGrade')=='B','restart grade')
 code,data=http('/v1/characters/1',token=owner['token'],method='GET');req=dict(fixture,personal=pack(unpack(json.loads(data['character']['save']))));ck(http('/v1/multiplayer',req,owner['token'])[0]==200,'reconnect')
 code,result,_=camp(owner,{'op':'containerRetrieve','id':1});ck(code==200,str(result));ck(unpack(result['state'])['bags'][1]['slots'][1]['contents'][1]['qty']==12,'retrieval conserved');ck(s.eval('return #SG_SERVER.world.placedContainers')=='0','retrieval removed world copy')
 code,data=http('/v1/characters/1',token=owner['token'],method='GET');saved=unpack(json.loads(data['character']['save']));saved['skills']['Woodworking']['xp']=int(s.eval("return require('game.skills').new().xpTable[99]"));saved['bags'][1]['slots']={1:{'name':'Pine Logs','qty':2,'qualityGrade':'A'}};data['character']['save']=json.dumps(pack(saved));ck(http('/v1/characters/1',{'revision':data['revision'],'character':data['character']},owner['token'],'PUT')[0]==200,'craft fixture save')
 px,py=saved['player']['x'],saved['player']['y'];s.eval("SG_SERVER.world.enemies={};SG_SERVER.world.authoredObjects={{id='steelSawmill',x="+str(px)+",y="+str(py)+"}};math.random=function(a,b)if not a then return .5 end;return b or a end;return 'ready'")
 index=int(s.eval("for i,r in ipairs(require('game.crafting').new():getRecipes('woodcraft'))do if r.output=='Pine Planks'then return i end end"));cmd={'op':'craft','station':'woodcraft','index':index};code,result,_=camp(owner,{'op':'begin','next':cmd});ck(code==200 and result['duration']>=2,'sawing begin');code,_,_=camp(owner,cmd);ck(code==409,'reject early completion');s.call('tick',{'dt':result['duration']+.1,'time':3});code,result,_=camp(owner,cmd);ck(code==200,str(result));slots=unpack(result['state'])['bags'][1]['slots'];ck(sum(it.get('qty',1)for it in slots.values()if it['name']=='Pine Logs')==1,'one log per cycle');ck(sum(it.get('qty',1)for it in slots.values()if it['name']=='Pine Planks')==1,'plank output');ck(sum(it.get('qty',1)for it in slots.values()if it['name']=='Sawdust')==1,'sawdust output')
 print('PASS',checks,'authenticated container ownership/replay/DB rollback/restart/metadata/retrieval and timed sawmill checks; save bytes',size)
finally:service.shutdown();service.server_close();s.close()
