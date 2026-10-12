"""Authenticated two-account camp API integration tests; isolated QA database."""
from pathlib import Path
import json,sys,time,threading,sqlite3,urllib.request,urllib.error,hashlib
from contextlib import closing
from simulation import Simulation
from camps import Camps,pack,unpack
import server

root=Path(__file__).resolve().parent.parent
folder=root/'Server'/'activity_http_test_data';folder.mkdir(exist_ok=True)
db=folder/'test.sqlite3';db.unlink(missing_ok=True);server.initialize(db)
for name in ('camp_owner','camp_guest'):server.create_user(db,name,'qa_password_123')
service=server.Service(('127.0.0.1',0),db);service.simulation=Simulation(root);service.camps=Camps(service)
threading.Thread(target=service.serve_forever,daemon=True).start();base=f'http://127.0.0.1:{service.server_port}'
def http(path,data=None,token=None,method='POST'):
    req=urllib.request.Request(base+path,data=json.dumps(data).encode()if data is not None else None,method=method,headers={'Content-Type':'application/json',**({'Authorization':'Bearer '+token}if token else{})})
    try:
        with urllib.request.urlopen(req,timeout=30)as r:return r.status,json.load(r)
    except urllib.error.HTTPError as e:return e.code,json.load(e)
try:
    s=service.simulation
    fixture=json.loads(s.eval(r'''
local F=require('game.fieldcraft');local P=require('game.profile');local w=SG_SERVER.world;local sk=require('game.skills').new();local inv=require('game.inventory').new();inv.bagSlots[1].size=128
sk.data.Fieldcraft.xp=sk.xpTable[99];sk.data.Fieldcraft.level=99
local p=require('game.player').new();p.hp=10;p.maxHp=10
local a={player=p,inv=inv,skills=sk};local found=false
for y=240,w.map.height-240,160 do for x=240,w.map.width-240,160 do if not found then p.x,p.y=x,y+40;if F.valid(w,a,'Lean-to',x,y)then found=true end end end end
assert(found,'No valid wilderness footprint')
inv:add('Cover Tent',2);inv:add('Angled Timber',3);inv:add('Horizontal Timber',3);inv:add('Vertical Timber',3);inv:add('Bones',2);inv:add('Pine Logs',3);inv:add('Stone Gravel',4);inv:add('Iron Bar',20);inv:add('Oak Wood Parts',20);inv:add('Cut Emerald',3);inv:add('Raw Chicken',1)
return require('game.json').encode({worldId=require('game.regions').doc.worldId,worldFingerprint=require('game.regions').networkFingerprint,regionId=require('game.regions').start,area='overworld',initial=true,seq=1,slot=1,personal=P.pack({player=p,skills=sk.data,bags=inv.bagSlots,equipment={},bank={},bankSize=25})})
'''))
    accounts=[]
    for name in ('camp_owner','camp_guest'):
        status,user=http('/v1/login',{'name':name,'password':'qa_password_123'});assert status==200
        token=user['token'];state=unpack(fixture['personal']);state['player']['name']=name
        if name=='camp_guest':state['player']['x']+=200
        clean=dict(state,bags={},skills={});record={'name':name,'race':'Human','save':json.dumps(pack(clean))}
        status,saved=http('/v1/characters/1',{'revision':0,'character':record},token,'PUT');assert status==200
        with closing(sqlite3.connect(db))as c:
            uid=c.execute('SELECT id FROM users WHERE name=?',(name,)).fetchone()[0]
            record['save']=json.dumps(pack(state));c.execute('UPDATE characters SET data=? WHERE user=? AND slot=1',(json.dumps(record),uid))
            ledger={'config':{'layout':{},'built':{},'recovery':{},'regions':{}},'xp':{'Fieldcraft':state['skills']['Fieldcraft']['xp'],'Survival':0,'Foraging':0}}
            c.execute("INSERT OR REPLACE INTO fieldcraft(user,slot,data,active,seen,owner)VALUES(?,1,?,'',0,'')",(uid,json.dumps(ledger)));c.commit()
        body=dict(fixture,personal=pack(state));status,result=http('/v1/multiplayer',body,token);assert status==200,result
        accounts.append({'token':token,'revision':1,'seq':1,'state':state,'body':body})
    owner,guest=accounts;position=dict(owner['state']['player']);position['y']-=40;request=0
    def camp(a,command):
        global request
        request+=1;body={'slot':1,'request':str(request),'revision':a['revision'],'command':command}
        status,result=http('/v1/camp',body,a['token'])
        if status==200 and result.get('state'):
            a['revision']=result['revision'];state=unpack(result['state']);a['state']['bags']=state['bags'];a['state']['skills']=state['skills'];a['state']['bank']=state['bank']
        return status,result,body
    # A forged save cannot mint protected items or new skill XP.
    forged=unpack(pack(owner['state']));first=next(v for v in forged['bags'][1]['slots'].values()if v['name']=='Cover Tent');first['qty']+=1
    status,rejected=http('/v1/characters/1',{'revision':owner['revision'],'character':{'name':'camp_owner','race':'Human','save':json.dumps(pack(forged))}},owner['token'],'PUT');assert status==400,rejected
    slot=next(i for i,v in owner['state']['bags'][1]['slots'].items()if v['name']=='Angled Timber')
    status,result,_=camp(owner,{'op':'drop','bag':1,'slot':slot});assert status==200,result
    owner['seq']+=1;status,result=http('/v1/multiplayer',dict(owner['body'],seq=owner['seq'],initial=False,personal=pack(owner['state'])),owner['token']);assert status==200,result
    ground=next(v for v in unpack(result['snapshot'])['groundItems'].values()if v['name']=='Angled Timber')
    status,result,_=camp(owner,{'op':'pickup','target':ground['netId']});assert status==200,result
    status,result,_=camp(guest,{'op':'admin','action':'give','item':'Cover Tent','amount':1,'serverAdmin':True});assert status==403,'Client forged admin authorization'
    with closing(sqlite3.connect(db))as c:c.execute("UPDATE users SET role='admin' WHERE name='camp_owner'");c.commit()
    status,result,_=camp(owner,{'op':'admin','action':'level','skill':'Mining','amount':42});assert status==200,result
    assert unpack(result['state'])['skills']['Mining']['level']==42
    status,result,_=camp(owner,{'op':'admin','action':'give','item':'Angled Timber','amount':1});assert status==200,result
    status,result,_=camp(owner,{'op':'admin','action':'heal'});assert status==200,result
    status,result,_=camp(owner,{'op':'recover'});assert status==409 and result['error']=='No items to recover from lost camps.'
    status,result,request_body=camp(owner,{'op':'deploy','tent':'Cover Tent','x':position['x'],'y':position['y']});assert status==200,result
    assert unpack(result['camp'])['tent']=='Cover Tent'
    status,replay=http('/v1/camp',request_body,owner['token']);assert status==200 and replay['revision']==result['revision'],'Replay changed inventory'
    # Reported production XP near the owned camp contributes once, despite retries.
    before_fc=owner['state']['skills']['Fieldcraft']['xp'];owner['state']['skills']['Woodworking']['xp']+=10
    owner['seq']+=1;body=dict(owner['body'],seq=owner['seq'],initial=False,personal=pack(owner['state']))
    status,activity=http('/v1/multiplayer',body,owner['token']);assert status==200,activity
    after_fc=activity['skillTotals']['Fieldcraft'];assert abs(after_fc-before_fc-1.1)<.001,(before_fc,after_fc)
    status,same=http('/v1/multiplayer',body,owner['token']);assert status==200 and same['skillTotals']['Fieldcraft']==after_fc,'Replay duplicated camp activity'
    owner['seq']+=1;body['seq']=owner['seq'];status,same=http('/v1/multiplayer',body,owner['token']);assert status==200 and same['skillTotals']['Fieldcraft']==after_fc,'Unchanged skill XP duplicated activity'
    # An authoritative server action also contributes once; its client echo does not.
    s.eval("for _,a in ipairs(SG_SERVER.world.onlineActors or{})do if a.player.name=='camp_owner'then a.skills:addXP('Woodworking',10)end end;return 'ready'")
    owner['state']['skills']['Woodworking']['xp']+=11;owner['seq']+=1;body['seq']=owner['seq'];body['personal']=pack(owner['state']);status,same=http('/v1/multiplayer',body,owner['token']);assert status==200,same
    assert abs(same['skillTotals']['Fieldcraft']-after_fc-1.21)<.001,'Server gain double counted on client echo'
    status,result,_=camp(guest,{'op':'withdraw','slot':1});assert status==409,'Guest accessed storage'
    guest['seq']+=1;body=dict(guest['body'],seq=guest['seq'],initial=False);status,result=http('/v1/multiplayer',body,guest['token']);assert status==200
    assert len(unpack(result['snapshot'])['playerCamps'])==1,'Camp not replicated to second account'
    # Deposit a real persisted bag slot, then packing must fail.
    bag=owner['state']['bags'][1];slot=next(i for i,v in bag['slots'].items()if v['name']=='Bones')
    with closing(sqlite3.connect(db))as c:
        c.execute("CREATE TRIGGER qa_fail_update BEFORE UPDATE ON characters BEGIN SELECT RAISE(ABORT,'QA forced character write failure'); END");c.commit()
    status,failed,failed_body=camp(owner,{'op':'deposit','bag':1,'slot':slot});assert status==500,'Fault injection did not reject the write'
    with closing(sqlite3.connect(db))as c:c.execute('DROP TRIGGER qa_fail_update');c.commit()
    status,result=http('/v1/camp',failed_body,owner['token']);assert status==200,result
    owner['revision']=result['revision'];state=unpack(result['state']);owner['state']['bags']=state['bags'];owner['state']['skills']=state['skills'];owner['state']['bank']=state['bank']
    stale_status,_=http('/v1/camp',request_body,owner['token']);assert stale_status==409,'Stale replay overwrote a newer inventory'
    status,result,_=camp(owner,{'op':'pack'});assert status==409 and result['error']=='Empty all camp storage before packing up your camp.'
    status,result,_=camp(owner,{'op':'withdraw','slot':1});assert status==200,result
    status,result,_=camp(owner,{'op':'pack'});assert status==200,result
    # Build is timed and cannot consume materials immediately.
    status,result,_=camp(owner,{'op':'deploy','tent':'Cover Tent','x':position['x'],'y':position['y']});assert status==200,result
    build={'op':'build','structure':'fire','slot':1}
    status,result,_=camp(owner,build);assert status==409
    status,result,_=camp(owner,{'op':'begin','next':build});assert status==200 and result['duration']==2
    status,result,_=camp(owner,build);assert status==409,'Early construction accepted'
    time.sleep(2.1);status,result,_=camp(owner,build);assert status==200,result
    assert unpack(result['state'])['fieldcraft']['built']['fire']
    bank_build={'op':'build','structure':'bank','slot':2}
    status,result,_=camp(owner,{'op':'begin','next':bank_build});assert status==200
    time.sleep(2.1);status,result,_=camp(owner,bank_build);assert status==200,result
    def move(a,x,y):
        a['state']['player']['x']=x;a['state']['player']['y']=y;a['seq']+=1
        status,result=http('/v1/multiplayer',dict(a['body'],seq=a['seq'],initial=False,personal=pack(a['state'])),a['token']);assert status==200,result
    move(owner,position['x']+28,position['y']+20)
    bone=next(i for i,v in owner['state']['bags'][1]['slots'].items()if v['name']=='Bones')
    status,result,_=camp(owner,{'op':'bankDeposit','bag':1,'slot':bone});assert status==200,result
    bank=unpack(result['state'])['bank'];bank_slot=next(i for i,v in bank.items()if v['name']=='Bones')
    status,result,_=camp(owner,{'op':'bankWithdraw','slot':bank_slot,'amount':1});assert status==200,result
    assert not unpack(result['state'])['bank'],'Camp bank created a duplicate inventory'
    # A second account can cook at the owner's unlocked camp fire.
    move(guest,position['x']-28,position['y']+20)
    recipes=json.loads(s.eval("local out={};for i,r in ipairs(require('game.crafting').new():getRecipes('campfire'))do if r.output=='Raw Chicken'then out.index=i end end;return require('game.json').encode(out)"))
    cook={'op':'craft','station':'campfire','index':recipes['index']}
    status,result,_=camp(guest,{'op':'begin','next':cook});assert status==200
    time.sleep(.6);status,result,_=camp(guest,cook);assert status==200,result
    # Storage recovery on authenticated logout retains layout but destroys Tent.
    bag=owner['state']['bags'][1];slot=next(i for i,v in bag['slots'].items()if v['name']=='Bones')
    status,result,_=camp(owner,{'op':'deposit','bag':1,'slot':slot});assert status==200,result
    status,result=http('/v1/logout',{},owner['token']);assert status==200
    status,user=http('/v1/login',{'name':'camp_owner','password':'qa_password_123'});owner['token']=user['token']
    status,data=http('/v1/characters/1',None,owner['token'],'GET');assert status==200
    recovered=unpack(json.loads(data['character']['save']));assert len(recovered['fieldcraft']['recovery'])==1
    assert recovered['fieldcraft']['layout'][1]=='fire'
    tents=sum(v.get('qty',1)for bag in recovered['bags'].values()for v in bag['slots'].values()if v['name']=='Cover Tent');assert tents==1,'Logout returned the deployed Tent'
    owner['revision']=data['revision'];owner['state']=recovered;owner['seq']+=1
    status,result=http('/v1/multiplayer',dict(owner['body'],seq=owner['seq'],initial=True,personal=pack(recovered)),owner['token']);assert status==200,result
    status,result,_=camp(owner,{'op':'recover'});assert status==200,result
    move(guest,position['x']+200,position['y']+40)
    status,result,_=camp(owner,{'op':'deploy','tent':'Cover Tent','x':position['x'],'y':position['y']});assert status==200,result
    assert len(unpack(result['camp'])['structures'])==2,'Paid layout not rebuilt after Tent loss'
    bone=next(i for i,v in owner['state']['bags'][1]['slots'].items()if v['name']=='Bones')
    status,result,_=camp(owner,{'op':'deposit','bag':1,'slot':bone});assert status==200,result
    status,new_login=http('/v1/login',{'name':'camp_owner','password':'qa_password_123'});assert status==200
    old_token=owner['token'];owner['token']=new_login['token'];owner['seq']=1
    status,result=http('/v1/multiplayer',dict(owner['body'],seq=1,initial=True,personal=pack(owner['state'])),owner['token']);assert status==200
    assert len(unpack(result['snapshot'])['playerCamps'])==1,'Brief reconnect destroyed camp'
    status,_=http('/v1/logout',{},old_token);assert status==200
    status,check=http('/v1/characters/1',None,owner['token'],'GET');assert status==200
    assert unpack(json.loads(check['character']['save']))['fieldcraft'].get('active'),'Old session destroyed reconnected camp'
    # Exercise the real cleanup thread with an expired server-side heartbeat.
    with closing(sqlite3.connect(db))as c:c.execute('UPDATE fieldcraft SET seen=? WHERE user=1',(time.time()-service.camps.grace-1,));c.commit()
    time.sleep(5.5)
    status,check=http('/v1/characters/1',None,owner['token'],'GET');assert status==200
    cfg=unpack(json.loads(check['character']['save']))['fieldcraft'];assert not cfg.get('active')and len(cfg['recovery'])==1,'Disconnect cleanup lost storage or retained camp'
    guest['seq']+=1;status,result=http('/v1/multiplayer',dict(guest['body'],seq=guest['seq'],initial=True,personal=pack(guest['state'])),guest['token']);assert status==200
    assert not unpack(result['snapshot'])['playerCamps'],'Expired camp remained visible'
    # Authenticated admin teleport persists a safe destination and rejoins its region.
    status,record=http('/v1/characters/1',None,owner['token'],'GET');assert status==200
    owner['revision']=record['revision'];owner['state']=unpack(json.loads(record['character']['save']))
    towns=json.loads(s.eval("return require('game.json').encode(require('game.admin_rules').towns())"));town=towns[-1]
    status,result,_=camp(owner,{'op':'admin','action':'teleport','region':town['region'],'index':town['index']});assert status==200,result
    destination=result['destination'];assert destination['region']==town['region']
    status,record=http('/v1/characters/1',None,owner['token'],'GET');assert status==200
    persisted=unpack(json.loads(record['character']['save']));assert persisted['regionId']==destination['region']and persisted['player']['x']==destination['x'],'Admin teleport not persisted'
    owner['seq']+=1;status,result=http('/v1/multiplayer',dict(owner['body'],regionId=destination['region'],seq=owner['seq'],initial=True,personal=pack(persisted)),owner['token']);assert status==200,result
    assert service.simulation.error is None
    print('PASS owned-camp production XP, multiplayer replay/echo deduplication and authenticated HTTP: admin role enforcement, level/item grants, safe persisted town teleport, two accounts, camp replication, owner-only storage, exact packing guard, replay idempotence, stale replay rejection, injected database-failure rollback, timed construction, real bank transfers, cooperative station crafting, logout Tent loss, durable recovery, paid-layout redeployment, reconnect ownership and expired-session cleanup')
finally:
    service.shutdown();service.server_close();__import__('gc').collect();db.unlink();folder.rmdir()
