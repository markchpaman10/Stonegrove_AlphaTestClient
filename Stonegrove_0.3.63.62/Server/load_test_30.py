"""Isolated real-HTTP load test; never opens production accounts or saves."""
import gzip
import http.client as http_client
import argparse, collections, concurrent.futures, copy, ctypes, json, math, os
import platform, sqlite3, subprocess, sys, threading, time, urllib.request, urllib.error
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'Server'))
from camps import pack,unpack

def percentile(values,p):
    values=sorted(values)
    return values[min(len(values)-1,int((len(values)-1)*p))] if values else None

def metrics():
    if os.name!='nt':
        import resource
        usage=resource.getrusage(resource.RUSAGE_SELF)
        fields={}
        status=Path('/proc/self/status')
        if status.exists():fields=dict(line.split(':',1)for line in status.read_text().splitlines()if ':'in line)
        rss=int(fields.get('VmRSS',str(usage.ru_maxrss)).split()[0])*1024
        anonymous=int(fields.get('RssAnon',str(rss//1024)).split()[0])*1024
        return {'at':time.time(),'cpu_seconds':usage.ru_utime+usage.ru_stime,'rss_bytes':rss,'private_bytes':anonymous}
    from ctypes import wintypes as W
    class MEMORY(ctypes.Structure):
        _fields_=[('cb',W.DWORD),('faults',W.DWORD)]+[(n,ctypes.c_size_t)for n in ('peak','rss','peakPaged','paged','peakNonpaged','nonpaged','pagefile','peakPagefile','private')]
    k=ctypes.WinDLL('kernel32',use_last_error=True);p=ctypes.WinDLL('psapi',use_last_error=True)
    k.GetCurrentProcess.restype=W.HANDLE;handle=k.GetCurrentProcess()
    files=[W.FILETIME()for _ in range(4)]
    k.GetProcessTimes.argtypes=[W.HANDLE]+[ctypes.POINTER(W.FILETIME)]*4
    assert k.GetProcessTimes(handle,*[ctypes.byref(v)for v in files])
    cpu=sum(((v.dwHighDateTime<<32)+v.dwLowDateTime)/1e7 for v in files[2:])
    mem=MEMORY();mem.cb=ctypes.sizeof(mem)
    p.GetProcessMemoryInfo.argtypes=[W.HANDLE,ctypes.c_void_p,W.DWORD]
    assert p.GetProcessMemoryInfo(handle,ctypes.byref(mem),mem.cb)
    return {'at':time.time(),'cpu_seconds':cpu,'rss_bytes':mem.rss,'private_bytes':mem.private,'peak_rss_bytes':mem.peak}

def child(folder):
    import server
    from simulation import Simulation
    from camps import Camps
    from world_source import resolve_world
    world_source=resolve_world(ROOT,folder,link=os.environ.get('WORLD_LINK'))
    server.initialize(folder/'accounts.sqlite3')
    # Login hashing remains production code; account creation is outside measured load.
    for i in range(30):server.create_user(folder/'accounts.sqlite3',f'load_{i:02}','isolated_test_password')
    service=server.Service(('127.0.0.1',0),folder/'accounts.sqlite3');service.camps=Camps(service)
    sim=service.simulation=Simulation(ROOT,world=world_source,data_dir=folder)
    calls=collections.defaultdict(list);lock=threading.Lock();original=sim.call
    def measured(method,args):
        start=time.perf_counter()
        try:return original(method,args)
        finally:
            with lock:calls[method].append({'at':time.time(),'ms':(time.perf_counter()-start)*1000})
    sim.call=measured
    handler=server.Handler.run_request
    def measured_handler(self):
        start=time.perf_counter()
        try:return handler(self)
        finally:
            with lock:calls['http_handler'].append({'at':time.time(),'ms':(time.perf_counter()-start)*1000})
    server.Handler.run_request=measured_handler
    fixture=json.loads(sim.eval(r'''
local I=require('game.inventory');local sk=require('game.skills').new();for _,v in pairs(sk.data)do v.level=30;v.xp=sk.xpTable[30]end
local inv=I.new();inv:applyStrengthBagBonus(30);inv:add('Copper Axe',1);inv:add('Copper Pickaxe',1);inv:add('Copper Knife',1)
local p=require('game.player').new();local w=SG_SERVER.world;p.x,p.y=w.playerRef and w.playerRef.x or 600,w.playerRef and w.playerRef.y or 600
local targets={};for _,e in ipairs(w.enemies)do if not e.dead and not e.townAnimal and (e.level or 1)<=10 then targets[#targets+1]={x=e.x,y=e.y,kind='combat'};if #targets>=10 then break end end end
for _,e in ipairs(w.nodes)do if e.kind=='tree'and not e.depleted then targets[#targets+1]={x=e.x,y=e.y,kind='gather'};if #targets>=20 then break end end end
return require('game.json').encode({targets=targets,worldId=require('game.regions').doc.worldId,worldFingerprint=require('game.regions').networkFingerprint,regionId=require('game.regions').start,area='overworld',slot=1,personal=require('game.profile').pack({bagSchemaVersion=2,graveEpoch=0,player=p,skills=sk.data,bags=inv.bagSlots,equipment={weapon='Copper Longsword'},equipmentItems={weapon={name='Copper Longsword',qty=1}},equipmentSockets={},potionBelt={},bank=inv.bank,bankSize=25})})
'''))
    (folder/'ready.json').write_text(json.dumps({'port':service.server_port,'fixture':fixture}),encoding='utf-8')
    threading.Thread(target=service.serve_forever,daemon=True).start()
    samples=[]
    try:
        while not (folder/'stop').exists():
            samples.append(metrics());time.sleep(1)
            with lock:data={'samples':samples,'calls':dict(calls),'simulation_error':sim.error}
            temporary=folder/'metrics.tmp';temporary.write_text(json.dumps(data),encoding='utf-8');
            try:temporary.replace(folder/'metrics.json')
            except PermissionError:pass # Windows reader temporarily holds the telemetry file; retry next sample.
    finally:
        service.shutdown();sim.close();service.server_close()
        with lock:data={'samples':samples,'calls':dict(calls),'simulation_error':sim.error}
        (folder/'metrics.json').write_text(json.dumps(data),encoding='utf-8')

def run(folder,seconds):
    folder.mkdir(parents=True,exist_ok=False)
    log=open(folder/'server.log','w',encoding='utf-8')
    process=subprocess.Popen([sys.executable,__file__,'--child',str(folder)],stdout=log,stderr=log)
    (folder/'processes.json').write_text(json.dumps({'parent':os.getpid(),'child':process.pid}))
    records=[];phases=[];error_examples=[];guard=threading.Lock()
    try:
        deadline=time.monotonic()+120
        while not (folder/'ready.json').exists():
            if process.poll() is not None:raise RuntimeError((folder/'server.log').read_text())
            if time.monotonic()>deadline:raise TimeoutError('Server start')
            time.sleep(.25)
        normal_opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
        ready=json.loads((folder/'ready.json').read_text());fixture=ready['fixture'];fixture['snapshotVersion']=2;base=f"http://127.0.0.1:{ready['port']}"
        def http(path,body,token=None,method='POST',source=None):
            encoded=json.dumps(body,separators=(',',':')).encode()if body is not None else None
            req=urllib.request.Request(base+path,data=encoded,method=method,headers={'Accept-Encoding':'gzip','Content-Type':'application/json',**({'Authorization':'Bearer '+token}if token else{})})
            start=time.perf_counter()
            try:
                if source:
                    class SourceHandler(urllib.request.HTTPHandler):
                        def http_open(self,request):return self.do_open(lambda host,**kw:http_client.HTTPConnection(host,source_address=(source,0),**kw),request)
                    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),SourceHandler())
                else:opener=normal_opener
                with opener.open(req,timeout=20)as response:raw=response.read();status=response.status;encoding=response.headers.get('Content-Encoding','')
            except urllib.error.HTTPError as e:raw=e.read();status=e.code;encoding=e.headers.get('Content-Encoding','')
            decoded=gzip.decompress(raw)if encoding=='gzip'else raw
            return status,json.loads(decoded),len(encoded or b''),len(raw),(time.perf_counter()-start)*1000
        accounts=[]
        for i in range(30):
            while True:
                status,result,*_=http('/v1/login',{'name':f'load_{i:02}','password':'isolated_test_password'},source=f'127.0.0.{i+1}')
                if status!=429:break
                time.sleep(5)
            assert status==200,result
            print(f'Authenticated client {i+1}/30',flush=True)
            state=unpack(fixture['personal']);state['player']['name']=f'Load{i:02}'
            targets=fixture['targets'];target=targets[i%len(targets)]if targets else None
            if target:state['player'].update(x=target['x']+18,y=target['y'])
            token=result['token']
            status,result,*_=http('/v1/characters/1',{'revision':0,'character':{'name':f'Load{i:02}','race':'Human','save':json.dumps(pack(state))}},token,'PUT');assert status==200,result
            accounts.append({'token':token,'state':state,'seq':0,'entities':{},'kind':target['kind']if target else 'walk','action_next':0})
        print('READY 30 separate authenticated accounts, real simulation and persistent camp ledger',flush=True)
        def bot(i,phase,end):
            a=accounts[i];next_request=time.monotonic()+i*.2/30;last=time.monotonic()
            while time.monotonic()<end:
                time.sleep(max(0,next_request-time.monotonic()));now=time.monotonic();dt=min(.3,now-last);last=now
                action=None;p=a['state']['player']
                if phase=='mixed' and a['seq']>0:
                    kind=a['kind'];group='enemies'if kind=='combat'else'nodes'
                    candidates=[e for e in a['entities'].get(group,{}).values()if not e.get('dead')and not e.get('inactive')and not e.get('depleted')and (group!='nodes'or e.get('kind')=='tree')]
                    if candidates:
                        target=min(candidates,key=lambda e:(e['x']-p['x'])**2+(e['y']-p['y'])**2)
                        dx,dy=target['x']-p['x'],target['y']-p['y'];distance=math.hypot(dx,dy)
                        if distance>20:
                            step=min(distance-20,70*dt);p['x']+=dx/distance*step;p['y']+=dy/distance*step
                        elif now>=a['action_next']:
                            action={'kind':'attack'if group=='enemies'else'gather','collection':group,'target':target['netId']};a['action_next']=now+1
                a['seq']+=1;body={k:v for k,v in fixture.items()if k not in ('targets','personal')};state=a['state'];fields=('x','y','hp','maxHp','stamina','maxStamina','race','headDir','bodyDir','frame','moving','equipped','burst','warriorYell','poisonImmuneTimer','slimeCoated','toolSwing','activity','activityTimer')
                personal={k:state[k]for k in ('graveEpoch','potionBelt','mercs','quests','bags','activeBag','skills','equipment','equipmentItems','equipmentSockets','spellPages')if k in state};personal['player']={k:state['player'][k]for k in fields if k in state['player']};personal.update(knownOre={},knownPositions={});body.update(seq=a['seq'],initial=a['seq']==1,personal=pack(personal),action=action)
                started=time.time()
                try:
                    status,result,up,down,latency=http('/v1/multiplayer',body,a['token'])
                    error=None
                    if status==200:
                        assert result.get('seq')==a['seq'],'Wrong sequence'
                        if result.get('personal'):a['state'].update(unpack(result['personal']));p=a['state']['player']
                        else:
                            delta=result.get('delta')or{};p['hp']=max(0,min(p['maxHp'],p['hp']+delta.get('hp',0)));p['stamina']=max(0,min(p['maxStamina'],p['stamina']+delta.get('stamina',0)))
                            if delta.get('teleport'):p.update(delta['teleport'])
                            for name,xp in delta.get('xp',{}).items():a['state']['skills'][name]['xp']+=xp
                        p.update(result.get('status')or{})
                        snap=unpack(result['snapshot'])
                        for group in ('nodes','enemies'):
                            values=snap.get(group,{})
                            for e in values.values()if isinstance(values,dict)else values:
                                previous=a['entities'].setdefault(group,{}).get(e['netId'],{});previous.update(e);a['entities'][group][e['netId']]=previous
                        for group,removed in (snap.get('removed')or{}).items():
                            for key in removed.values()if isinstance(removed,dict)else removed:a['entities'].setdefault(group,{}).pop(key,None)
                        peers=len(result.get('players')or[])
                    else:error=str(result)[:300];peers=0
                    record={'phase':phase,'client':i,'at':started,'status':status,'ms':latency,'up':up,'down':down,'peers':peers,'action':action and action['kind'],'action_ok':(result.get('result')or{}).get('ok'),'reason':(result.get('result')or{}).get('reason')}
                except Exception as e:
                    error=repr(e);record={'phase':phase,'client':i,'at':started,'status':0,'ms':(time.time()-started)*1000,'up':0,'down':0,'peers':0}
                with guard:
                    records.append(record)
                    if error and len(error_examples)<20:error_examples.append(error)
                next_request=max(now+.2,time.monotonic())
        for name,duration in [('connected',seconds),('mixed',seconds*2)]:
            start=time.time();end=time.monotonic()+duration;print(f'PHASE {name}: 30 clients at up to 5 exchanges/second each, {duration}s',flush=True)
            with concurrent.futures.ThreadPoolExecutor(max_workers=30)as pool:
                futures=[pool.submit(bot,i,name,end)for i in range(30)]
                for f in futures:f.result()
            phases.append({'name':name,'start':start,'end':time.time(),'duration':duration})
            selected=[r for r in records if r['phase']==name]
            print(f"DONE {name}: {len(selected)} exchanges, {sum(r['status']!=200 for r in selected)} errors, p95 {percentile([r['ms']for r in selected],.95):.1f}ms",flush=True)
        (folder/'stop').touch();process.wait(timeout=40)
        telemetry=json.loads((folder/'metrics.json').read_text())
        summaries=[]
        for phase in phases:
            rows=[r for r in records if r['phase']==phase['name']];samples=[s for s in telemetry['samples']if phase['start']<=s['at']<=phase['end']]
            ticks=[v['ms']for v in telemetry['calls'].get('tick',[])if phase['start']<=v['at']<=phase['end']]
            elapsed=phase['end']-phase['start'];cpu=(samples[-1]['cpu_seconds']-samples[0]['cpu_seconds'])/(samples[-1]['at']-samples[0]['at'])*100 if len(samples)>1 else None
            summaries.append({**phase,'requests':len(rows),'requests_per_second':len(rows)/elapsed,'errors':sum(r['status']!=200 for r in rows),'p50_ms':percentile([r['ms']for r in rows],.5),'p95_ms':percentile([r['ms']for r in rows],.95),'p99_ms':percentile([r['ms']for r in rows],.99),'max_ms':max(r['ms']for r in rows),'cpu_percent_one_core':cpu,'peak_rss_mb':max(s['rss_bytes']for s in samples)/1048576,'peak_private_mb':max(s['private_bytes']for s in samples)/1048576,'rss_start_mb':samples[0]['rss_bytes']/1048576,'rss_end_mb':samples[-1]['rss_bytes']/1048576,'download_mbps':sum(r['down']for r in rows)*8/elapsed/1e6,'upload_mbps':sum(r['up']for r in rows)*8/elapsed/1e6,'ticks':len(ticks),'ticks_per_second':len(ticks)/elapsed,'tick_p95_ms':percentile(ticks,.95),'ticks_over_50ms':sum(v>50 for v in ticks),'clients_seen':len(set(r['client']for r in rows)),'peer_29_responses':sum(r['peers']==29 for r in rows),'actions':dict(collections.Counter(r.get('action')for r in rows if r.get('action'))),'successful_actions':sum(r.get('action_ok')is True for r in rows),'action_reasons':dict(collections.Counter(str(r.get('reason'))for r in rows if r.get('action')))})
        result={'host':platform.platform(),'logical_processors':os.cpu_count(),'version':json.loads((ROOT/'client_package.json').read_text(encoding='utf-8'))['version'],'roles':dict(collections.Counter(a['kind']for a in accounts)),'phases':summaries,'simulation_error':telemetry['simulation_error'],'error_examples':error_examples,'limitations':['Localhost HTTP, no TLS/WAN latency.','Synthetic movement/attack/gather clients, no graphical clients.','Server and load generator share the host, but process CPU and memory are measured separately.','Short capacity sample, not a multi-hour soak or Render hardware benchmark.','All clients in the same overworld region; no cave, camp, spell or crafting workload.','Payload bytes exclude HTTP/TLS headers.']}
        (folder/'result.json').write_text(json.dumps(result,indent=2),encoding='utf-8');(folder/'requests.json').write_text(json.dumps(records),encoding='utf-8')
        print(json.dumps(result,indent=2),flush=True)
    finally:
        (folder/'stop').touch()
        if process.poll()is None:
            try:process.wait(timeout=40)
            except subprocess.TimeoutExpired:process.terminate()
        log.close()

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--child');p.add_argument('--seconds',type=int,default=90);p.add_argument('--output');p.add_argument('--world-link',default=os.environ.get('WORLD_LINK'));args=p.parse_args()
    if args.world_link:os.environ['WORLD_LINK']=args.world_link
    if not args.child and not args.world_link:p.error('Supply --world-link or WORLD_LINK; benchmark worlds also come only from GitHub')
    if args.child:child(Path(args.child))
    else:run(Path(args.output or Path(__file__).resolve().parent/('load30-'+time.strftime('%Y%m%d-%H%M%S'))).resolve(),args.seconds)
