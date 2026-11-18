from pathlib import Path
import sys,json,posixpath,hashlib
sys.path.insert(0,r'C:\Users\kale2\Documents\Codex\2026-11-16\we-x20\work\lua_check')
from lupa.lua52 import LuaRuntime
r=Path(__file__).resolve().parents[1];source=(r/'update.lua').read_text()
files=[p.name for p in r.glob('*.lua')]
for scenario in ['normal','unchanged','download','hash','syntax','write','space','self']:
 l=LuaRuntime(unpack_returned_tuples=True);g=l.globals();data={'app/'+n:(r/n).read_text() for n in files};old='-- @crafting-center {"version":"0"}\nreturn true\n'
 if scenario!='unchanged':data['app/gear_preview.lua']=old
 if scenario=='self':data['app/update.lua']=old
 data['app/backups/gear_ui.lua.bak']='old script';data['app/backups/gear_ui.lua.legacy1.bak']='old legacy';data['app/backups/cast_installations.txt.bak']='STATE';data['app/cast_installations.txt']='STATE';data['app/queue.txt']='QUEUE';before=data.copy();logs=[];reboot=[];written=[];failed=[False]
 def norm(p):return posixpath.normpath(p)
 def openfile(p,mode):
  p=norm(p)
  if mode=='r':return l.table_from({'readAll':lambda:data[p],'close':lambda:None})
  data[p]='';written.append(p)
  def write(s):
   if scenario=='write' and p=='app/gear_preview.lua' and not failed[0]:failed[0]=True;raise RuntimeError('injected write failure')
   data[p]+=s
  return l.table_from({'write':write,'close':lambda:None})
 g.fs=l.table_from({'combine':lambda a,b:norm(a+'/'+b),'getDir':lambda p:'app','exists':lambda p:norm(p) in data or norm(p)=='app/backups','isDir':lambda p:norm(p)=='app/backups','list':lambda p:l.table_from([x.rsplit('/',1)[-1] for x in data if x.startswith(norm(p)+'/')]),'delete':lambda p:data.pop(norm(p),None),'open':openfile,'getFreeSpace':lambda p:0 if scenario=='space' else 1000000})
 g.shell=l.table_from({'getRunningProgram':lambda:'app/update.lua'})
 g.textutils=l.table_from({'unserializeJSON':lambda s:l.table_from(json.loads(s),recursive=True),'serialize':lambda t:'receipt'})
 g.print=lambda *a:logs.append(str(a));g.printError=g.print;g.sleep=lambda t:None;g.os.reboot=lambda:reboot.append(True);g.os.epoch=lambda _:0
 requests=[]
 def get(url,headers):
  requests.append(url)
  if '/commits/' in url:body=json.dumps({'sha':'a'*40})
  elif '/git/trees/' in url:
   entries=[]
   for n in files:
    content=(r/n).read_text()
    if scenario=='syntax' and n=='gear_preview.lua':content=content.splitlines()[0]+'\nthis is invalid []'
    raw=content.encode();entries.append({'path':n,'type':'blob','sha':hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()})
   body=json.dumps({'tree':entries})
  else:
   name=url.rsplit('/',1)[-1]
   if scenario=='download' and name=='gear_preview.lua':return None,'failed',None
   body=(r/name).read_text()
   if scenario in ['syntax','hash'] and name=='gear_preview.lua':body=body.splitlines()[0]+'\nthis is invalid []'
  return l.table_from({'readAll':lambda:body,'close':lambda:None,'getResponseCode':lambda:200})
 g.http=l.table_from({'get':get});l.execute(source)
 assert data['app/backups/cast_installations.txt.bak']=='STATE' and data['app/cast_installations.txt']=='STATE' and data['app/queue.txt']=='QUEUE'
 assert not any(p.endswith('.lua.bak') or '.legacy1.bak' in p for p in data)
 if scenario in ['download','hash','syntax','write','space']:assert data['app/gear_preview.lua']==old,(scenario,logs)
 else:assert data['app/gear_preview.lua']==(old if scenario=='self' else (r/'gear_preview.lua').read_text()),logs
 if scenario=='unchanged':assert not [p for p in written if p.endswith('.lua')]
 assert not any(p.endswith('.download') for p in data)
 raw=[u.rsplit('/',1)[-1] for u in requests if 'raw.githubusercontent' in u]
 if scenario=='unchanged':assert raw==[],raw
 if scenario=='normal':assert raw==['gear_preview.lua'],raw
 if scenario=='self':assert raw==['update.lua'],raw
 assert bool(reboot)==(scenario=='self')
 print('PASS updater',scenario)

