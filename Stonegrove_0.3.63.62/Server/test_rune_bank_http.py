from pathlib import Path
import tempfile,json,threading,urllib.request,urllib.error
from simulation import Simulation
from camps import pack,unpack
import server
root=Path(__file__).resolve().parent.parent
folder=root/'Server'/'rune_bank_http_test_data';folder.mkdir(exist_ok=True)
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
local w=SG_SERVER.world;w.enemies={};w.farmAnimals={};local sk=require('game.skills').new();sk.data.Religion.xp=sk.xpTable[30];sk.data.Religion.level=30;local inv=require('game.inventory').new();inv:add('Copper Axe',1);inv:add('Copper Pickaxe',1);inv:add('Copper Knife',1);inv.bagSlots[1].slots[4]={name='Charred Wood',qty=6,qualityGrade='A',blessed=true};inv.bagSlots[1].slots[5]={name='Charred Wood',qty=6,qualityGrade='A',blessed=true};assert(inv:depositAll('Charred Wood'));assert(inv:withdrawBankSlotAmount(9,1));assert(inv.bank[9].qty==11);local p=require('game.player').new();p.x,p.y=600,600;p.hp=5;p.maxHp=5
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
 owner['state']['player']['hp']=0;exchange(owner);s.call('tick',{'dt':.05,'time':1});r=exchange(owner);check(not owner['state']['bags'],'Death removes bags')
 check(http('/v1/presence/leave',{},owner['token'])[0]==200,'Logout')
 s.close();s=service.simulation=Simulation(root,data_dir=folder);s.stopped.set();s.thread.join();owner['seq']=0
 code,data=http('/v1/characters/1',token=owner['token'],method='GET');check(code==200,'Relog character');owner['state']=unpack(json.loads(data['character']['save']));check(not owner['state']['bags'],'No automatic starter on relog');check(owner['state']['bank'][9]['qty']==11 and owner['state']['bank'][9]['qualityGrade']=='A' and owner['state']['bank'][9]['blessed'],'Graded bank remainder survives server restart');exchange(owner)
 keeper=json.loads(s.eval("local keeper=assert(require('game.bag_keeper').vendors(SG_SERVER.world)[1],'No trader bag keeper');return require('game.json').encode(keeper)"))
 owner['state']['player'].update(x=keeper['x'],y=keeper['y']);exchange(owner);request=0
 def claim(account):
  global request
  code,data=http('/v1/characters/1',token=account['token'],method='GET');check(code==200,'Read revision');request+=1;body={'slot':1,'revision':data['revision'],'request':'bag-'+str(request),'command':{'op':'starterBag','x':keeper['x'],'y':keeper['y']}}
  code,result=http('/v1/camp',body,account['token']);return code,result,body
 code,result,_=claim(owner);check(code==409 and 'grave'in result['error'],'Protected old bag blocks free bag after restart')
 s.call('tick',{'dt':61,'time':62});exchange(owner);code,result,_=claim(owner);check(code==409 and 'ground'in result['error'],'Broken grave bag on ground blocks')
 ground=json.loads(s.eval("for _,g in ipairs(SG_SERVER.world.groundItems)do if g.bagOwner then return require('game.json').encode(g)end end;error('Missing owned bag drop')"));check(ground['name']=='Medium Leather Bag','Starter corpse bag')
 helper['seq']=0;helper['state']['bags'][1]['slots']={};helper['state']['player'].update(x=ground['x'],y=ground['y']);reply=exchange(helper,{'kind':'pickup','collection':'groundItems','target':ground['netId']});check(reply['result']['ok'],'Other player picks up public bag')
 code,result,body=claim(owner);check(code==200,result);saved=unpack(result['state']);bag=saved['bags'][1];check(bag['name']=='Medium Leather Bag'and bag['qualityGrade']=='D'and bag['size']==5 and not bag['slots'],'Eligible starter equipped');owner['state'].update(bags=saved['bags'],bank=saved['bank'],bankSize=saved['bankSize'],skills=saved['skills'],fieldcraft=saved['fieldcraft'])
 code,replay=http('/v1/camp',body,owner['token']);check(code==200 and replay['revision']==result['revision'],'Same request replay is idempotent');code,result,_=claim(owner);check(code==409,'Second claim blocked')
 code,data=http('/v1/characters/1',token=owner['token'],method='GET');stored=unpack(json.loads(data['character']['save']));check(stored['bags'][1]['name']=='Medium Leather Bag'and len(stored['bank'])==9 and stored['bank'][9]['qty']==11 and stored['bank'][9]['qualityGrade']=='A' and stored['bank'][7]['name']=='Copper Longsword','Bag and original bank persist')
 check(http('/v1/presence/leave',{},owner['token'])[0]==200,'Logout with recovery bag');s.close();s=service.simulation=Simulation(root,data_dir=folder);s.stopped.set();s.thread.join();owner['seq']=0;owner['state']=stored;exchange(owner);code,result,_=claim(owner);check(code==409,'No duplicate after another server restart/relog')
 print('PASS',checks,'authenticated graded bank save/restart and bag recovery regressions')
finally:
 service.shutdown();service.server_close();s.close()
