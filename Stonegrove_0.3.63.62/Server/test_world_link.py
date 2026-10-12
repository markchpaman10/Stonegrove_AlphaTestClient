"""GitHub-only startup tests. Network responses and accounts are isolated QA fixtures."""
from pathlib import Path
import io,json,sys,zlib,urllib.error,urllib.request,uuid
from unittest.mock import patch
ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'Server'))
import world_source as W
from simulation import Simulation
raw=(ROOT/'Server/Fixtures/level-zone-editor.sgworld').read_bytes()
# A different marker proves disk/bundled data cannot win.
doc=W.decode_world(raw)
for e in doc['files']['current']['entries']:
 if e['key']=='worldId':e['value']='github_only_remote_qa'
raw=b'STONEGROVE_WORLD_1\n'+zlib.compress(json.dumps(doc).encode())
checks=0
def ck(v,message='check'):
 global checks
 assert v,message;checks+=1
def fail(fn,text=None):
 try:fn()
 except (ValueError,RuntimeError)as exc:
  if text:ck(text.lower()in str(exc).lower(),str(exc))
  else:ck(True)
  return
 raise AssertionError('Expected failure')
class Response(io.BytesIO):
 def __init__(self,data,headers=None):super().__init__(data);self.headers=headers or{}
class Opener:
 def __init__(self,data=raw,error=None,headers=None):self.data=data;self.error=error;self.headers=headers;self.calls=[]
 def open(self,req,timeout):
  self.calls.append(req.full_url)
  if self.error:raise self.error
  if req.full_url.startswith('https://api.github.com/'):return Response(json.dumps({'default_branch':'main'}).encode())
  return Response(self.data,self.headers)
url='https://raw.githubusercontent.com/test/worlds/main/world.sgworld';link='https://github.com/test/worlds/blob/main/world.sgworld'
for value in (link,'worldLink = "'+link+'"',"worldLink='"+link+"';"):ck(W.github_url(value)==url)
for value in ('http://github.com/a/b','C:/world.sgworld','https://localhost/file','https://github.com@localhost/a/b','https://github.com/a/b/tree/main'):fail(lambda:W.github_url(value))
opener=Opener();source=W.download_world(link,opener=opener);ck(isinstance(source,W.GitHubWorld));ck(source.raw==raw and source.world_id=='github_only_remote_qa');ck(opener.calls==[url])
for bad in (b'<html>404</html>',raw[:-4],raw+b'extra',b'STONEGROVE_WORLD_1\n'+zlib.compress(json.dumps({'format':'StonegroveWorldPackage','version':1,'files':{}}).encode())):fail(lambda:W.download_world(link,opener=Opener(bad)))
fail(lambda:W.download_world(link,opener=Opener(error=urllib.error.URLError('offline'))),'download')
fail(lambda:W.download_world(link,opener=Opener(headers={'Content-Length':'16000001'})))
repo=Opener();W.download_world('https://github.com/test/worlds',opener=repo);ck(repo.calls==['https://api.github.com/repos/test/worlds','https://raw.githubusercontent.com/test/worlds/main/world.sgworld'])
folder=ROOT/'Server'/('github_only53_test_data_'+uuid.uuid4().hex[:8]);folder.mkdir();fake=folder/'fake_root';(fake/'Server').mkdir(parents=True);data=folder/'data';(data/'world-cache').mkdir(parents=True)
(fake/'Server/world.sgworld').write_bytes(b'local world must never be read');(fake/'current.lua').write_text("error('bundled world must never be read')");(data/'world-cache/world.sgworld').write_bytes(b'stale cache must never be read')
silent=lambda *a,**kw:None;calls=[]
def downloader(value):calls.append(value);return W.download_world(value,opener=Opener())
fail(lambda:W.resolve_world(fake,data,log=silent,downloader=downloader),'required');ck(calls==[])
fail(lambda:W.resolve_world(fake,data,interactive=True,read=lambda _:'',log=silent,downloader=downloader),'required')
fail(lambda:W.resolve_world(fake,data,world=fake/'Server/world.sgworld',log=silent,downloader=downloader),'HTTPS')
source=W.resolve_world(fake,data,link=link,log=silent,downloader=downloader);ck(calls==[url]);ck(json.loads((data/'world-link.json').read_text())=={'worldLink':url});ck(json.loads((data/'world-source.json').read_text())['sha256']==source.sha256)
second=W.resolve_world(fake,data,log=silent,downloader=downloader);ck(calls==[url,url]and second.raw==raw);ck((data/'world-cache/world.sgworld').read_bytes()==b'stale cache must never be read')
config=(data/'world-link.json').read_bytes();fail(lambda:W.resolve_world(fake,data,link=link,log=silent,downloader=lambda _:(_ for _ in()).throw(ValueError('network failed'))));ck((data/'world-link.json').read_bytes()==config)
fail(lambda:W.resolve_world(fake,data,link=link,log=silent,downloader=lambda _:fake/'Server/world.sgworld'),'download')
fail(lambda:Simulation(ROOT),'GitHub');fail(lambda:Simulation(ROOT,world=fake/'Server/world.sgworld'),'GitHub')
# Use downloaded bytes directly even if every local world/cache path is replaced afterward.
(fake/'Server/world.sgworld').unlink();(data/'world-cache/world.sgworld').unlink()
sim=Simulation(ROOT,world=source,data_dir=folder/'simulation');sim.stopped.set();sim.thread.join()
try:ck(sim.eval("return require('game.regions').doc.worldId")=='github_only_remote_qa');ck(sim.error is None)
finally:sim.close()
badDoc=json.loads(zlib.decompress(raw[19:]));badDoc['files']['current']={'entries':[{'key':'format','value':'NotAWorld'}]};badRaw=b'STONEGROVE_WORLD_1\n'+zlib.compress(json.dumps(badDoc).encode());badSource=W.download_world(url,opener=Opener(badRaw));fail(lambda:Simulation(ROOT,world=badSource),'bundled generation is disabled')
badDoc=json.loads(zlib.decompress(raw[19:]));current=badDoc['files']['current'];maps=next(e['value'] for e in current['entries'] if e['key']=='maps');first=maps['array'][0];mapData=next(e['value'] for e in first['entries'] if e['key']=='data')
for entry in mapData['entries']:
 if entry['key']=='format':entry['value']='NotAMap'
badRaw=b'STONEGROVE_WORLD_1\n'+zlib.compress(json.dumps(badDoc).encode());badSource=W.download_world(url,opener=Opener(badRaw));fail(lambda:Simulation(ROOT,world=badSource),'bundled generation is disabled')
handler=W.GithubRedirect();req=urllib.request.Request(url)
for target in ('http://github.com/file','https://127.0.0.1/file','https://githubusercontent.com.attacker.test/file'):fail(lambda:handler.redirect_request(req,None,302,'',{},target))
ck(handler.redirect_request(req,None,302,'',{},'https://release-assets.githubusercontent.com/asset').full_url.endswith('/asset'))
import server
served=[]
def serve(service):
 ck(service.simulation is not None,'Simulation must validate before serving');ck(service.simulation.eval("return require('game.regions').doc.worldId")=='github_only_remote_qa');served.append(service.world_source.sha256)
with patch.dict('os.environ',{'WORLD_LINK':''},clear=False),patch.object(sys.stdin,'isatty',return_value=False),patch.object(server.Service,'serve_forever',serve):
 with patch.object(sys,'argv',['server.py','--data',str(folder/'startup'),'--port','0','--world-link',link]),patch.object(W.urllib.request,'build_opener',return_value=Opener()):server.main()
 with patch.object(sys,'argv',['server.py','--data',str(folder/'startup'),'--port','0']),patch.object(W.urllib.request,'build_opener',return_value=Opener()):server.main()
 ck(len(served)==2)
 with patch.object(sys,'argv',['server.py','--data',str(folder/'startup'),'--port','0']),patch.object(W.urllib.request,'build_opener',return_value=Opener(error=urllib.error.URLError('offline'))):fail(server.main,'download')
 ck(len(served)==2,'Failed download must not start serving')
 with patch.object(sys,'argv',['server.py','--data',str(folder/'empty-startup'),'--port','0']):fail(server.main,'required')
 with patch.object(sys,'argv',['server.py','--data',str(folder/'empty-startup'),'--port','0','--world',str(ROOT/'Server/Fixtures/level-zone-editor.sgworld')]):fail(server.main,'HTTPS')
 ck(len(served)==2)
print('PASS',checks,'GitHub-only URL/assignment/repository, fresh download, local/cache rejection, no bundled fallback, in-memory simulation, startup validation and failure checks')
