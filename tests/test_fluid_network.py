from pathlib import Path
import sys
from lupa.lua52 import LuaRuntime
R=Path(__file__).resolve().parents[1]
l=LuaRuntime(unpack_returned_tuples=True)
for name in ['fluid_network','fluid_client','fluid_service','fluid_monitor','network_setup']:l.globals()[name+'Source']=(R/(name+'.lua')).read_text()
l.execute(r'''
 now=100;files={};calls=0;pushes={};balances={a=100000,b=1000};limit=1000000;inject=false;epoch=100000
 os={clock=function() return now end,epoch=function() return epoch end,getComputerID=function() return 20 end,queueEvent=function() end}
 local function serialize(v)
  if type(v)=='table' then local a={};for k,x in pairs(v) do a[#a+1]='['..serialize(k)..']='..serialize(x) end;return '{'..table.concat(a,',')..'}'
  elseif type(v)=='string' then return string.format('%q',v) else return tostring(v) end
 end
 textutils={serialize=serialize,unserialize=function(s) local f=load('return '..s);return f and f() end}
 fs={combine=function(a,b) return a..'/'..b end,getDir=function() return 'root' end,exists=function(p) return files[p]~=nil end,
 delete=function(p) files[p]=nil end,move=function(a,b) assert(files[a] and not files[b]);files[b]=files[a];files[a]=nil end,
 open=function(p,mode)
  if mode=='r' then if not files[p] then return nil end;return {readAll=function() return files[p] end,close=function() end} end
  local data='';return {write=function(s) data=data..s end,close=function() files[p]=data end}
 end}
 peripheral={call=function(name,method,...)
  if method=='tanks' then return {{name='productivemetalworks:molten_iron',amount=balances[name] or 0}} end
  if method=='pushFluid' then
   local target,amount,fluid=...;calls=calls+1
   if inject then error('injected disconnect') end
   local moved=math.min(amount,limit,balances[name]);balances[name]=balances[name]-moved
   pushes[#pushes+1]={target=target,amount=moved,fluid=fluid};return moved
  end
  if method=='isWireless' then return false end
  error(method)
 end,hasType=function() return true end}
 config={role='fluid',modem='left',monitors={'fluid_monitor'},sources={'a','b'},destinations={'gear_table'},outputs={Ingot='ingot_buffer',Block='block_buffer'},clients={10},keepMb=0}
 Network=assert(load(fluid_networkSource))();factory=assert(load(fluid_serviceSource))();service=factory('root',config)
 local function request(id,method,args,sender) return service.handle(sender or 10,{version=1,id='10:100000:'..id,method=method,args=args}) end
 assert(not pcall(request,1,'stock',{},11))
 assert(#request(1,'stock')==1 and request(1,'stock')[1].amount==101000)
 assert(not service.readyForLocal())
 request(2,'reserve',{demand={['productivemetalworks:molten_iron']=100500}})
 assert(service.readyForLocal() and service.reserved('productivemetalworks:molten_iron')==100500)
 local ok,err=pcall(service.transfer,20,'monitor:20:1:1',{target='block_buffer',fluid='productivemetalworks:molten_iron',amount=810},true)
 assert(not ok and tostring(err):find('Not Enough Fluid',1,true) and calls==0)
 request(3,'reserve',{demand={['productivemetalworks:molten_iron']=0}})
 now=116;assert(not service.readyForLocal());now=100
 local result=request(4,'pour',{target='gear_table',fluid='productivemetalworks:molten_iron',amount=90})
 assert(result.moved==90 and calls==1)
 local before=calls;assert(request(4,'pour',{target='gear_table',fluid='productivemetalworks:molten_iron',amount=90}).moved==90 and calls==before)
 assert(not pcall(request,4,'pour',{target='gear_table',fluid='productivemetalworks:molten_iron',amount=91}))
 assert(not pcall(request,5,'pour',{target='block_buffer',fluid='productivemetalworks:molten_iron',amount=90}))
 -- Receipts survive service restart; no physical replay after a lost reply.
 service=factory('root',config)
 assert(request(4,'pour',{target='gear_table',fluid='productivemetalworks:molten_iron',amount=90}).moved==90 and calls==before)
 request(6,'reserve',{demand={}})
 -- A partial transfer reports the measured amount and is replay-safe.
 limit=20;result=request(7,'pour',{target='gear_table',fluid='productivemetalworks:molten_iron',amount=90})
 assert(result.moved==40 and result.error:find('Partial',1,true));before=calls
 assert(request(7,'pour',{target='gear_table',fluid='productivemetalworks:molten_iron',amount=90}).moved==40 and calls==before)
 -- Unknown physical result locks further transfers across restart until inspected.
 limit=1000000;inject=true
 assert(not pcall(request,8,'pour',{target='gear_table',fluid='productivemetalworks:molten_iron',amount=90}))
 assert(#service.uncertain()==1 and service.fault)
 service=factory('root',config);inject=false
 assert(#service.uncertain()==1 and not pcall(request,9,'pour',{target='gear_table',fluid='productivemetalworks:molten_iron',amount=90}))
 service.acknowledge();assert(#service.uncertain()==0)
 assert(not pcall(request,8,'pour',{target='gear_table',fluid='productivemetalworks:molten_iron',amount=90}))
 assert(request(10,'pour',{target='gear_table',fluid='productivemetalworks:molten_iron',amount=90}).moved==90)
 -- Old receipts evicted from the bounded cache are rejected, never re-executed.
 for i=11,80 do assert(request(i,'pour',{target='gear_table',fluid='productivemetalworks:molten_iron',amount=1}).moved==1) end
 before=calls;assert(not pcall(request,4,'pour',{target='gear_table',fluid='productivemetalworks:molten_iron',amount=90}) and calls==before)
 -- Reject shared destinations and corrupt pending journal before touching fluids.
 local bad={sources={'a'},destinations={'gear_table'},outputs={Block='gear_table'},clients={10}}
 assert(not pcall(factory,'bad',bad))
 files['broken/fluid_transfers.txt.pending']='garbage';assert(not pcall(factory,'broken',config))
 assert(Network.volume('Block','productivemetalworks:molten_iron')==810)
 assert(Network.volume('Block','productivemetalworks:molten_diamond')==900)
 assert(Network.volume('Block','productivemetalworks:molten_glass')==1000)
 assert(Network.volume('Block','productivemetalworks:molten_amethyst')==400)
 assert(Network.volume('Ingot','productivemetalworks:molten_diamond')==nil)
 assert(Network.volume('Block','minecraft:water')==nil)
''')
print('PASS service: exact IDs, aggregate stock, queue reservations/fresh heartbeats, role-specific outputs, measured partials, restart-safe receipts, uncertain transfer locks, old-request replay rejection, corrupt journals and volumes')
# Client loop: real matching logic with simulated Rednet replies and timeout.
l.execute(r'''
 events={};sent={};nextTimer=0;timers={};timeout=false;server=service
 os.startTimer=function(delay) nextTimer=nextTimer+1;timers[nextTimer]=delay;return nextTimer end
 os.cancelTimer=function() end
 os.pullEvent=function() local e=table.remove(events,1);assert(e,'No event');return table.unpack(e) end
 rednet={open=function() end,send=function(peer,msg,protocol)
  assert(peer==20);sent[#sent+1]=msg
  if timeout then events[#events+1]={'timer',nextTimer+1};return true end
  local ok,result=pcall(server.handle,10,msg)
  events[#events+1]={'rednet_message',999,{version=1,id=msg.id,ok=true,result='wrong sender'},protocol}
  events[#events+1]={'rednet_message',peer,{version=1,id='other',ok=true,result='wrong id'},protocol}
  events[#events+1]={'rednet_message',peer,{version=1,id=msg.id,ok=ok,result=ok and result,error=not ok and tostring(result)},protocol}
  return true
 end}
 os.getComputerID=function() return 10 end
 client=assert(load(fluid_clientSource))()(Network,{modem='left',serverId=20,monitors={'gear_monitor'}})
 client.checkAssignments({Sword={peripheral='gear_table'}})
 assert(not pcall(client.checkAssignments,{Sword={peripheral='block_buffer'}}))
 assert(type(client.call(Network.source,'tanks'))=='table')
 client.reserve({['productivemetalworks:molten_iron']=90})
 epoch=200000 -- Existing session ID is fixed; next client starts a fresh epoch.
 client=assert(load(fluid_clientSource))()(Network,{modem='left',serverId=20,monitors={'gear_monitor'}})
 before=calls;assert(client.call(Network.source,'pushFluid','gear_table',90,'productivemetalworks:molten_iron')==90 and calls==before+1)
 timeout=true;local beforeSent=#sent
 local ok,err=pcall(client.call,Network.source,'pushFluid','gear_table',90,'productivemetalworks:molten_iron')
 assert(not ok and tostring(err):find('no automatic resend',1,true) and #sent==beforeSent+1)
 timeout=false
 local conflict=assert(load(fluid_clientSource))()(Network,{modem='left',serverId=20,monitors={'fluid_monitor'}})
 assert(not pcall(conflict.checkAssignments,{}))
''')
print('PASS client: pinned server/request matching, separate monitors/stations, stock/reservation/pour RPC and timeout without duplicate resend')

monitor=(R/'fluid_monitor.lua').read_text()
l.globals().appSource=monitor[:monitor.rindex('connect();render()')]+"\nreturn {S=S,Q=Q,service=service,connect=connect,render=render,enqueue=enqueue,worker=queueWorker,stockWorker=stockWorker}"
l.execute(r"""
 os.getComputerID=function() return 20 end
 os.pullEvent=function() return coroutine.yield('event') end
 sleep=function() coroutine.yield('sleep') end
 shell={getRunningProgram=function() return 'root/fluid_monitor.lua' end}
 colors={};for i,name in ipairs({'white','orange','magenta','lightBlue','yellow','lime','pink','gray','lightGray','cyan','purple','blue','brown','green','red','black'}) do colors[name]=2^(i-1) end
 colors.toBlit=function(color) for i=0,15 do if color==2^i then return string.format('%x',i) end end;error('color') end
 local writes=0;local row,x=0,0
 local mon={setTextScale=function() end,setPaletteColor=function() end,getSize=function() return 60,49 end,
 setCursorPos=function(a,b) assert(a>=1 and a<=60 and b>=1 and b<=49);x=a;row=b end,
 blit=function(text,fg,bg) assert(#text==#fg and #fg==#bg and x+#text-1<=60);writes=writes+1 end}
 peripheral.wrap=function() return mon end
 dofile=function(path)
  if path:find('fluid_network.lua',1,true) then return assert(load(fluid_networkSource))() end
  if path:find('fluid_service.lua',1,true) then return assert(load(fluid_serviceSource))() end
  error(path)
 end
 files['root/fluid_network.txt']=textutils.serialize(config)
 App=assert(load(appSource))();App.connect();App.S.fluid='productivemetalworks:molten_iron';App.S.stock={{name=App.S.fluid,amount=10000}}
 for _,screen in ipairs({'welcome','main','resources','automatic','material','review','queue','utilities','acknowledge'}) do App.S.screen=screen;App.render() end
 App.S.screen='main';App.render();local beforeWrites=writes;App.render();assert(writes==beforeWrites)
 App.service.handle(10,{version=1,id='hold',method='reserve',args={demand={}}})
 App.enqueue(App.S.fluid,'Ingot',2,false);assert(#App.Q.jobs==1 and App.Q.jobs[1].remaining==180)
 limit=50
 local worker=coroutine.create(App.worker);local ok,e=coroutine.resume(worker);assert(ok,e)
 assert(App.Q.paused and App.Q.jobs[1].remaining==80 and App.Q.jobs[1].request==nil)
 App.Q.paused=false;ok,e=coroutine.resume(worker);assert(ok,e);assert(#App.Q.jobs==0)
 -- Restart after physical success but before queue checkpoint uses the saved receipt.
 local requestId='monitor:20:2:1'
 limit=1000000
 local result=App.service.transfer(20,requestId,{target='ingot_buffer',fluid=App.S.fluid,amount=180},true);assert(result.moved==180)
 files['root/fluid_jobs.txt']=textutils.serialize({nextId=3,paused=false,jobs={{id=2,fluid=App.S.fluid,shape='Ingot',quantity=2,remaining=180,total=180,target='ingot_buffer',request={id=requestId,amount=180}}}})
 local before=calls
 App=assert(load(appSource))();App.service.handle(10,{version=1,id='hold',method='reserve',args={demand={}}})
 worker=coroutine.create(App.worker);ok,e=coroutine.resume(worker);assert(ok,e);assert(#App.Q.jobs==0 and calls==before)
 -- Automatic blocks wait for Gear heartbeat and preserve its demand.
 files['root/fluid_auto.txt']=textutils.serialize({['productivemetalworks:molten_iron']=true})
 App=assert(load(appSource))()
 local poll=coroutine.create(App.stockWorker);ok,e=coroutine.resume(poll);assert(ok,e);assert(#App.Q.jobs==0)
 App.service.handle(10,{version=1,id='hold',method='reserve',args={demand={['productivemetalworks:molten_iron']=900000}}})
 poll=coroutine.create(App.stockWorker);ok,e=coroutine.resume(poll);assert(ok,e);assert(#App.Q.jobs==0)
 App.service.handle(10,{version=1,id='hold',method='reserve',args={demand={}}})
 poll=coroutine.create(App.stockWorker);ok,e=coroutine.resume(poll);assert(ok,e)
 assert(#App.Q.jobs==1 and App.Q.jobs[1].automatic and App.Q.jobs[1].remaining==64*810)
""")
print('PASS monitor: every screen renders within bounds, unchanged frames skip writes, partial buffer deliveries resume remaining mB, restart does not re-pour, and automatic 64-block batches protect Gear demand/heartbeats')

l.execute(r"""
 -- Console-style setup saves a per-computer role without touching other state.
 local nc={role='gear',modem='left',monitors={'gear_monitor'},serverId=20,clients={},sources={},destinations={}}
 files['root/fluid_network.txt']=textutils.serialize(nc)
 os.getComputerID=function() return 10 end
 keys={q=1,b=2,backspace=3,up=4,down=5,pageUp=6,pageDown=7,enter=8,r=9}
 local input={};for i=1,11 do input[#input+1]={'key',keys.down} end
 input[#input+1]={'key',keys.enter};input[#input+1]={'key',keys.q}
 os.pullEvent=function() local event=table.remove(input,1);assert(event,'Console loop did not exit');return table.unpack(event) end
 term={getSize=function() return 60,22 end,setCursorPos=function(x,y) assert(x>=1 and x<=60 and y>=1 and y<=22) end,
 setBackgroundColor=function() end,setTextColor=function() end,clear=function() end,write=function(s) assert(#s<=60) end}
 assert(load(network_setupSource))()
 local saved=textutils.unserialize(files['root/fluid_network.txt']);assert(saved.role=='gear' and saved.serverId==20 and saved.monitors[1]=='gear_monitor')
 assert(not files['root/fluid_network.txt.pending'])
 -- Interrupted settings updates load the pending draft instead of falling back to auto discovery.
 files['root/fluid_network.txt.pending']=textutils.serialize({role='fluid',monitors={},clients={},sources={},destinations={}})
 assert(Network.load('root').role=='fluid');files['root/fluid_network.txt.pending']='broken'
 assert(not pcall(Network.load,'root'));files['root/fluid_network.txt.pending']=nil
""")
print('PASS Network Setup: paged console navigation/save, preserved assignments, pending configuration recovery and corrupt-config rejection')
for p in R.glob('*.lua'):
 ok,err=l.eval('function(s) local f,e=load(s);return f~=nil,e end')(p.read_text());assert ok,(p.name,err)
print('PASS all scripts compile in Lua 5.2')
