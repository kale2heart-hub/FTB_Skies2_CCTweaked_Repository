from pathlib import Path
import sys
from lupa.lua52 import LuaRuntime
R=Path(__file__).resolve().parents[1]
l=LuaRuntime(unpack_returned_tuples=True)
for name in ['fluid_network','fluid_client','fluid_service','fluid_monitor','network_setup','basin_casting','basin_casting_data']:l.globals()[name+'Source']=(R/(name+'.lua')).read_text()
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
 peripheral={getNames=function() return {} end,call=function(name,method,...)
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
 config={role='fluid',modem='left',monitors={'fluid_monitor'},sources={'a','b'},destinations={'gear_table'},basins={'ingot_buffer','block_buffer'},clients={10},keepMb=0}
 function findAction(rows,prefix) for _,row in ipairs(rows) do local label=row.label:gsub('^%[%d+ DISCONNECTED%] ','');if label:sub(1,#prefix)==prefix then return row.action end end;error('Missing action '..prefix) end
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
 local bad={sources={'a'},destinations={'gear_table'},basins={'gear_table'},clients={10}}
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
l.globals().appSource=monitor[:monitor.rindex('connect();render()')]+"\nreturn {S=S,Q=Q,service=service,connect=connect,render=render,enqueue=enqueue,worker=queueWorker,stockWorker=stockWorker,cancel=cancelJob,saveMinimum=saveMinimum}"
l.execute(r"""
 os.getComputerID=function() return 20 end
 os.epoch=function() return now*1000 end
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
  for _,name in ipairs({'fluid_network','fluid_service','basin_casting','basin_casting_data'}) do if path:find(name..'.lua',1,true) then return assert(load(_G[name..'Source']))() end end
  error(path)
 end
 config.basins={'basin1','basin2'};config.outputs=nil;config.blockOutputChest='block_chest'
 files['root/fluid_network.txt']=textutils.serialize(config)
 B={basin1={fluid=0},basin2={fluid=0}};blocksOut=0;blocked=false;extractError=false;neverCool=false
 local originalCall=peripheral.call
 peripheral.call=function(name,method,...)
  if B[name] then
   local b=B[name]
   if b.ready and now>=b.ready and not neverCool then b.fluid=0;b.item={name='minecraft:iron_block',count=1};b.ready=nil end
   if method=='list' then return b.item and {[1]=b.item} or {} end
   if method=='tanks' then return b.fluid>0 and {{name=b.name or 'productivemetalworks:molten_iron',amount=b.fluid}} or {} end
   if method=='pushItems' then
    assert(select(1,...)=='block_chest')
    if extractError then error('uncertain extraction') end
    if blocked then return 0 end
    assert(b.item);b.item=nil;blocksOut=blocksOut+1;return 1
   end
  end
  if method=='pushFluid' then
   local target,amount,fluid=...
   local moved=originalCall(name,method,...)
   if B[target] then local b=B[target];b.fluid=b.fluid+moved;b.name=fluid;if b.fluid==810 then b.ready=now+3 end end
   return moved
  end
  return originalCall(name,method,...)
 end
 App=assert(load(appSource))();App.connect();App.S.fluid='productivemetalworks:molten_iron';App.S.minimum=10000;App.S.stock={{name=App.S.fluid,amount=10000}}
 for _,screen in ipairs({'welcome','main','resources','automatic','material','review','queue','utilities','acknowledge','gearStock','gearMinimum'}) do App.S.screen=screen;App.render() end
 App.S.screen='main';App.render();local beforeWrites=writes;App.render();assert(writes==beforeWrites)
 App.service.handle(10,{version=1,id='hold',method='reserve',args={demand={},layout={monitors={'gear_monitor'},destinations={'gear_table'},inventories={}}}})
 assert(not pcall(App.enqueue,App.S.fluid,'Ingot',1,false))
 App.enqueue(App.S.fluid,'Block',4,false);assert(#App.Q.jobs==1 and App.Q.jobs[1].remaining==4*810)
 local worker=coroutine.create(App.worker)
 local function step(n)
  for i=1,n do now=now+.25;local ok,e=coroutine.resume(worker);assert(ok,e);if #App.Q.jobs==0 or App.Q.paused then break end end
 end
 step(1);assert(App.Q.jobs[1].units.basin1 and App.Q.jobs[1].units.basin2)
 step(1);assert(B.basin1.fluid==810 and B.basin2.fluid==810 and blocksOut==0)
 step(60);assert(#App.Q.jobs==0 and blocksOut==4 and not App.Q.paused)
 -- Cancel before a pour removes unstarted basin allocations without consuming fluid.
 App.enqueue(App.S.fluid,'Block',3,false);step(1);local untouched=calls;App.cancel(1);assert(#App.Q.jobs==0 and calls==untouched)
 -- A full output chest pauses extraction, then Resume does not pour another block.
 App.enqueue(App.S.fluid,'Block',1,false);blocked=true;step(30)
 assert(App.Q.paused and App.Q.jobs[1].units.basin1.phase=='waiting_output' and B.basin1.item)
 local before=calls;App.Q.paused=false;blocked=false;step(2);assert(#App.Q.jobs==0 and blocksOut==5 and calls==before)
 -- Restart during cooling reuses the persistent basin unit without another pour.
 App.enqueue(App.S.fluid,'Block',1,false);step(2);assert(B.basin1.fluid==810)
 before=calls;now=now+4;App=assert(load(appSource))();App.service.handle(10,{version=1,id='hold',method='reserve',args={demand={},layout={monitors={'gear_monitor'},destinations={'gear_table'},inventories={}}}})
 worker=coroutine.create(App.worker);step(2);assert(#App.Q.jobs==0 and blocksOut==6 and calls==before)
 -- Cancelling waiting quantity preserves active basin casts and their output.
 App.S.fluid='productivemetalworks:molten_iron'
 App.enqueue(App.S.fluid,'Block',6,false);step(2)
 local job=App.Q.jobs[1];assert(job.units.basin1 and job.units.basin2)
 App.cancel(1);assert(job.quantity==2 and job.remaining==2*810)
 step(40);assert(#App.Q.jobs==0 and blocksOut==8)
 -- Automatic batches remain blocked by stale/missing Gear heartbeats and demand.
 balances.a=200000
 files['root/fluid_auto.txt']=textutils.serialize({['productivemetalworks:molten_iron']=true})
 App=assert(load(appSource))()
 local poll=coroutine.create(App.stockWorker);local ok,e=coroutine.resume(poll);assert(ok,e);assert(#App.Q.jobs==0)
 App.service.handle(10,{version=1,id='hold',method='reserve',args={demand={['productivemetalworks:molten_iron']=900000},layout={monitors={'gear_monitor'},destinations={'gear_table'},inventories={}}}})
 poll=coroutine.create(App.stockWorker);ok,e=coroutine.resume(poll);assert(ok,e);assert(#App.Q.jobs==0)
 App.service.handle(10,{version=1,id='hold',method='reserve',args={demand={},layout={monitors={'gear_monitor'},destinations={'gear_table'},inventories={}}}})
 poll=coroutine.create(App.stockWorker);ok,e=coroutine.resume(poll);assert(ok,e)
 assert(#App.Q.jobs==1 and App.Q.jobs[1].automatic and App.Q.jobs[1].mode=='basin_blocks' and App.Q.jobs[1].remaining==64*810)
""")
print('PASS managed basins: block-only UI, two overlapping cooling cycles, exact block output collection, blocked-output Resume without re-pour, restart during cooling, cancellation protection and automatic Gear-reserved batches')

l.execute(r"""
 local manager=assert(load(basin_castingSource))()(config,App.service)
 local function fresh(id)
  B.basin1={fluid=0};B.basin2={fluid=0};balances.b=100000;neverCool=false;extractError=false;blocked=false;limit=1000000
  App.service.handle(10,{version=1,id='hold',method='reserve',args={demand={},layout={monitors={'gear_monitor'},destinations={'gear_table'},inventories={}}}})
  return {id=id,mode='basin_blocks',fluid='productivemetalworks:molten_iron',shape='Block',quantity=1,amount=810,outputs={'minecraft:iron_block'},completed=0,remaining=810,units={}}
 end
 local job=fresh(100);local snapshot
 local function save() snapshot=textutils.serialize(job) end
 manager.tick(job,save);limit=100
 local ok,e=pcall(manager.tick,job,save);assert(not ok and tostring(e):find('Partial',1,true) and B.basin1.fluid==200)
 limit=1000000;local before=calls;manager.tick(job,save);assert(calls==before+1 and B.basin1.fluid==810 and pushes[#pushes].amount==610)
 now=now+3.1;assert(manager.tick(job,save) and job.completed==1)
 job=fresh(101);manager.tick(job,save);manager.tick(job,save)
 B.basin1.fluid=0;B.basin1.ready=nil;B.basin1.item={name='minecraft:gold_block',count=1};before=calls
 ok,e=pcall(manager.tick,job,save);assert(not ok and tostring(e):find('Wrong block at basin1',1,true) and calls==before)
 job=fresh(102);neverCool=true;manager.tick(job,save);manager.tick(job,save);before=calls;now=now+16
 ok,e=pcall(manager.tick,job,save);assert(not ok and tostring(e):find('15 seconds',1,true) and calls==before)
 job=fresh(103);manager.tick(job,save);manager.tick(job,save);now=now+3.1;extractError=true
 ok,e=pcall(manager.tick,job,save);assert(not ok and job.units.basin1.phase=='delivery_started')
 extractError=false;before=calls;ok,e=pcall(manager.tick,job,save);assert(not ok and tostring(e):find('Uncertain item extraction',1,true) and calls==before)
 manager.resolve(job,save,nil);assert(job.units.basin1.phase=='waiting_output');assert(manager.tick(job,save))
 -- Physical extraction succeeded, but a simulated checkpoint failure retains the extraction intent.
 job=fresh(104);manager.tick(job,save);manager.tick(job,save);now=now+3.1
 local function failAfterExtraction() if job.completed==1 then error('disk checkpoint failed') end;snapshot=textutils.serialize(job) end
 ok,e=pcall(manager.tick,job,failAfterExtraction);assert(not ok)
 job=textutils.unserialize(snapshot);before=calls;local outBefore=blocksOut
 ok,e=pcall(manager.tick,job,save);assert(not ok and tostring(e):find('Uncertain item extraction',1,true))
 manager.resolve(job,save,true);assert(job.completed==1 and calls==before and blocksOut==outBefore)
 -- Repeated rejected pours are bounded, even if Resume is requested repeatedly.
 job=fresh(105);limit=0;manager.tick(job,save)
 for i=1,8 do assert(not pcall(manager.tick,job,save)) end
 before=calls;ok,e=pcall(manager.tick,job,save)
 assert(not ok and tostring(e):find('Pour limit reached',1,true) and calls==before)
 limit=1000000
""")
print('PASS basin recovery: exact partial remainder, wrong block stops, cooling timeout without top-ups, uncertain extraction revalidation, explicit delivered reconciliation and eight-attempt pour bound')
l.execute(r"""
 -- Console-style setup saves a per-computer role without touching other state.
 local nc={role='gear',modem='left',monitors={'gear_monitor'},serverId=20,clients={},sources={},destinations={}}
 files['root/fluid_network.txt']=textutils.serialize(nc)
 os.getComputerID=function() return 10 end
 keys={q=1,b=2,backspace=3,up=4,down=5,pageUp=6,pageDown=7,enter=8,r=9}
 local input={};for i=1,6 do input[#input+1]={'key',keys.down} end
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

setup=(R/'network_setup.lua').read_text()
l.globals().sourcePicker=setup[:setup.rindex('while true do')]+"\nreturn {choose=choose,entries=entries}"
l.execute(r"""
 local names={'functionalstorage:storage_controller_0','functionalstorage:chest_0','productivemetalworks:casting_0','othermod:tank_0','back'}
 peripheral.getNames=function() return names end
 peripheral.getMethods=function(name) if name=='functionalstorage:chest_0' then return {'list','pushItems'} elseif name=='productivemetalworks:casting_0' then return {'list','tanks','pushFluid','pushItems'} end;return {'tanks','pushFluid'} end
 peripheral.getType=function(name) if name=='back' then return 'fluid_storage','functionalstorage:fluid_drawer' end;return 'fluid_storage' end
 local picker=assert(load(sourcePicker))()
 picker.choose('sources','fluid',true)
 local labels={};for _,entry in ipairs(picker.entries()) do labels[entry.label]=true end
 assert(labels['[ ] functionalstorage:storage_controller_0'] and labels['[ ] back'])
 assert(not labels['[ ] productivemetalworks:casting_0'] and not labels['[ ] othermod:tank_0'] and not labels['[ ] functionalstorage:chest_0'])
 assert(labels['Clear source selections'])
 picker.choose('destinations','fluid',true)
 labels={};for _,entry in ipairs(picker.entries()) do labels[entry.label]=true end
 assert(labels['[ ] productivemetalworks:casting_0'] and not labels['[ ] othermod:tank_0'])
""")
print('PASS source picker: only Functional Storage fluid-capable devices, local-side type recognition, clear old selections and unchanged casting destination choices')

l.execute(r"""
 -- Basins and block output are assigned independently, with Gear stations excluded.
 files['root/fluid_network.txt']=textutils.serialize({role='fluid',modem='left',monitors={'fluid_monitor'},clients={10},sources={'functionalstorage:storage_controller_0'},destinations={'productivemetalworks:casting_0'},basins={}})
 os.getComputerID=function() return 20 end
 peripheral.getNames=function() return {'productivemetalworks:casting_0','productivemetalworks:casting_42','sophisticatedstorage:chest_9','functionalstorage:storage_controller_0'} end
 peripheral.getMethods=function(name)
  if name:find('casting_',1,true) then return {'list','tanks','pushItems','pushFluid'} end
  if name:find('chest_',1,true) then return {'list','size','pushItems'} end
  return {'tanks','pushFluid'}
 end
 peripheral.hasType=function() return false end
 local picker=assert(load(sourcePicker))();picker.choose('basins','basin',true)
 local rows=picker.entries();assert(#rows==3);findAction(rows,'[ ] productivemetalworks:casting_42')()
 picker.choose('blockOutputChest','inventory',false);rows=picker.entries();assert(#rows==1 and rows[1].label=='[ ] sophisticatedstorage:chest_9');rows[1].action()
 rows=picker.entries();findAction(rows,'SAVE')()
 local saved=textutils.unserialize(files['root/fluid_network.txt']);assert(saved.basins[1]=='productivemetalworks:casting_42' and saved.blockOutputChest=='sophisticatedstorage:chest_9' and saved.outputs==nil)
""")
print('PASS Fluid setup: local basins and inventory-only output can be assigned without duplicating Gear stations')

setup=(R/'network_setup.lua').read_text()
l.globals().orderedPicker=setup[:setup.rindex('while true do')]+"\nreturn {choose=choose,entries=entries}"
l.execute(r"""
 local order={103,10,1,100,2,9,0,101,5,3,8,4,7,6}
 peripheral.getNames=function() local names={};for _,n in ipairs(order) do names[#names+1]='productivemetalworks:casting_'..n end;return names end
 local picker=assert(load(orderedPicker))();picker.choose('destinations','fluid',true)
 local rows=picker.entries();local expected={0,1,2,3,4,5,6,7,8,9,10,100,101,103}
 for i,n in ipairs(expected) do assert(tonumber(rows[i].label:match('_(%d+)$'))==n,rows[i].label) end
""")
print('PASS numeric casting order: 0 through 10, then 100/101/103')

l.execute(r"""
 local cfg=textutils.unserialize(files['root/fluid_network.txt'])
 cfg.role='fluid';cfg.destinations={'productivemetalworks:casting_42'};cfg.basins={}
 files['root/fluid_network.txt']=textutils.serialize(cfg)
 local picker=assert(load(orderedPicker))();local rows=picker.entries()
 assert(not pcall(findAction,rows,'Fluid: Computer ID') and not pcall(findAction,rows,'Additional Gear'))
 findAction(rows,'Apply managed basin range')();findAction(rows,'SAVE')()
 local saved=Network.load('root');assert(#saved.destinations==0 and #saved.basins==63 and saved.basins[1]=='productivemetalworks:casting_43' and saved.basins[63]=='productivemetalworks:casting_105')
 assert(saved.blockOutputChest=='sophisticatedstorage:chest_9')
 files['root/fluid_network.txt']=textutils.serialize({role='gear',modem='left',monitors={'gear_monitor'},serverId=20})
 os.getComputerID=function() return 10 end
 picker=assert(load(orderedPicker))();rows=picker.entries()
 assert(not pcall(findAction,rows,'Gear: Computer ID') and not pcall(findAction,rows,'Main fluid storage') and not pcall(findAction,rows,'Managed block'))
 findAction(rows,'Reserve Gear casting_0')();findAction(rows,'SAVE')()
 saved=Network.load('root');assert(#saved.destinations==43 and saved.destinations[1]=='productivemetalworks:casting_0' and saved.destinations[43]=='productivemetalworks:casting_42')
 os.getComputerID=function() return 20 end
""")
print('PASS role-specific menus: Gear defines 0-42; Fluid defines 43-105; partner fields/local resources are not duplicated')
l.execute(r"""
 -- Dedicated Gear storage is a distinct pool: only refills flow main -> Gear.
 local iron='productivemetalworks:molten_iron';local diamond='productivemetalworks:molten_diamond'
 local pools={main_store={[iron]=30000,[diamond]=9000},gear_store={[iron]=2000,[diamond]=1000},gear_table={},block_basin={}}
 local moves={};local rejectGear=false;local fillLimit=1000000
 sleep=function(t) now=now+t end
 peripheral.call=function(name,method,...)
  if method=='tanks' then local result={};for fluid,amount in pairs(assert(pools[name],name)) do result[#result+1]={name=fluid,amount=amount} end;return result end
  if method=='pushFluid' then
   local target,amount,fluid=...;assert(pools[name] and pools[target])
   local moved=target=='gear_store' and rejectGear and 0 or math.min(amount,fillLimit,pools[name][fluid] or 0)
   pools[name][fluid]=(pools[name][fluid] or 0)-moved;pools[target][fluid]=(pools[target][fluid] or 0)+moved
   moves[#moves+1]={source=name,target=target,fluid=fluid,moved=moved};return moved
  end
  error(method)
 end
 local cfg={sources={'main_store'},gearSources={'gear_store'},destinations={'gear_table'},basins={'block_basin'},clients={10},gearMinimumDefault=10000,gearMinimums={}}
 local svc=factory('dedicated',cfg)
 svc.handle(10,{version=1,id='hold',method='reserve',args={demand={}}})
 assert(svc.refill()==17000 and pools.gear_store[iron]==10000 and pools.gear_store[diamond]==10000)
 assert(pools.main_store[iron]==22000 and pools.main_store[diamond]==0)
 local rows=svc.handle(10,{version=1,id='stock',method='stock'})
 for _,row in ipairs(rows) do assert(row.amount==10000) end
 local main=pools.main_store[iron]
 svc.handle(10,{version=1,id='10:999999:1',method='pour',args={target='gear_table',fluid=iron,amount=90}})
 assert(pools.main_store[iron]==main and pools.gear_store[iron]==9910 and pools.gear_table[iron]==90)
 assert(svc.refill()==90 and pools.gear_store[iron]==10000)
 svc.transfer(20,'monitor:20:1:1',{target='block_basin',fluid=iron,amount=810},true)
 assert(moves[#moves].source=='main_store' and pools.gear_store[iron]==10000 and pools.block_basin[iron]==810)
 pools.gear_store[iron]=0;main=pools.main_store[iron]
 local ok,e=pcall(svc.handle,10,{version=1,id='10:999999:2',method='pour',args={target='gear_table',fluid=iron,amount=90}})
 assert(not ok and tostring(e):find('Not Enough Fluid',1,true) and pools.main_store[iron]==main)
 pools.main_store[iron]=10500;rejectGear=true
 ok,e=pcall(svc.transfer,20,'monitor:20:2:1',{target='block_basin',fluid=iron,amount=810},true)
 assert(not ok and pools.main_store[iron]==10500 and pools.gear_store[iron]==0 and svc.refillStatus:find('blocked',1,true))
 rejectGear=false;cfg.gearMinimums[iron]=5000;cfg.gearMinimums[diamond]=0
 svc.refill();assert(pools.gear_store[iron]==5000 and pools.main_store[iron]==5500 and svc.minimum(diamond)==0)
 svc.handle(10,{version=1,id='hold',method='reserve',args={demand={[iron]=8000}}})
 svc.refill();assert(pools.gear_store[iron]==8000 and pools.main_store[iron]==2500)
 svc.handle(10,{version=1,id='hold',method='reserve',args={demand={}}})
 pools.gear_store[iron]=0;pools.main_store[iron]=30000;fillLimit=2000
 assert(svc.refill()==2000 and pools.gear_store[iron]==2000)
 assert(svc.refill()==2000 and pools.gear_store[iron]==4000)
 assert(svc.refill()==1000 and pools.gear_store[iron]==5000)
 local count=#moves;svc=factory('dedicated',cfg);assert(svc.refill()==0 and #moves==count)
 pools.gear_store[iron]=4900;assert(svc.refill()==100 and pools.gear_store[iron]==5000)
 local bad={sources={'main_store'},gearSources={'main_store'},destinations={},basins={}}
 assert(not pcall(factory,'overlapping-pools',bad))
""")
print('PASS dedicated Gear stock: 10,000 mB defaults, refill-before-block priority, exclusive source routing, no main fallback, blocked refill protection, per-fluid/zero overrides, larger queued demand, measured partial refills and restart-safe refill IDs')

l.execute(r"""
 -- The on-monitor minimum editor persists just the target and retains device assignments.
 files['root/fluid_network.txt']=textutils.serialize({role='fluid',modem='left',monitors={'fluid_monitor'},sources={'main_store'},gearSources={'gear_store'},destinations={'gear_table'},basins={'block_basin'},clients={10},gearMinimumDefault=10000,gearMinimums={},blockOutputChest='block_chest'})
 local previous=peripheral.call
 peripheral.call=function(name,method,...) if method=='isWireless' then return false end;return previous(name,method,...) end
 peripheral.hasType=function() return true end
 App=assert(load(appSource))();App.connect();App.S.fluid='productivemetalworks:molten_iron';App.S.minimum=12000;App.S.minimumInherited=false
 App.saveMinimum()
 local saved=Network.load('root')
 assert(saved.gearSources[1]=='gear_store' and saved.sources[1]=='main_store' and saved.gearMinimums[App.S.fluid]==12000)
 assert(App.service.minimum(App.S.fluid)==12000)
 App.S.gearStock=App.service.gearStatus();App.S.screen='gearStock';App.render()
 App.S.screen='gearMinimum';App.render()
 App.S.minimumInherited=true;App.saveMinimum();assert(Network.load('root').gearMinimums[App.S.fluid]==nil and App.service.minimum(App.S.fluid)==10000)
 -- Source selector prevents assigning the same controller to both pools.
 local main='functionalstorage:storage_controller_0';local gear='functionalstorage:storage_controller_1'
 files['root/fluid_network.txt']=textutils.serialize({role='fluid',modem='left',monitors={'fluid_monitor'},sources={main},gearSources={},destinations={'productivemetalworks:casting_0'},basins={},clients={10}})
 peripheral.getNames=function() return {main,gear} end
 peripheral.getMethods=function() return {'tanks','pushFluid'} end
 local picker=assert(load(orderedPicker))();picker.choose('gearSources','fluid',true)
 local rows=picker.entries();assert(#rows==2 and rows[2].label=='[ ] '..gear);rows[2].action()
 -- Returning to a main-menu instance with the selection represented in saved settings.
 local cfg=Network.load('root');cfg.gearSources={gear};Network.save('root',cfg)
 picker=assert(load(orderedPicker))();rows=picker.entries();findAction(rows,'SAVE')()
 saved=Network.load('root');assert(saved.gearMinimumDefault==10000 and saved.gearSources[1]==gear)
 cfg.gearSources={main};Network.save('root',cfg);picker=assert(load(orderedPicker))();rows=picker.entries()
 local ok,e=pcall(findAction(rows,'SAVE'));assert(not ok and tostring(e):find('conflicts',1,true))
""")
print('PASS Gear target editor persistence/default reset, live service targets, rendered Gear stock pages, disjoint Functional Storage selectors and minimum defaults')

l.execute(r"""
 -- Production exchange mode ignores duplicated/obsolete remote station settings.
 local cfg={assignmentExchange=true,sources={'fluid_supply'},gearSources={},destinations={'obsolete','fluid_basin'},basins={'fluid_basin'},monitors={'fluid_display'},blockOutputChest='fluid_output',clients={10}}
 local stock=1000;local poured=0
 peripheral.call=function(name,method,...)
  if method=='tanks' then assert(name=='fluid_supply');return {{name='productivemetalworks:molten_iron',amount=stock}} end
  if method=='pushFluid' then local target,amount,fluid=...;assert(name=='fluid_supply' and target=='gear_station');stock=stock-amount;poured=poured+amount;return amount end
  if method=='isWireless' then return false end
  error(method)
 end
 local svc=factory('ownership',cfg)
 local layout={monitors={'gear_display'},destinations={'gear_station','productivemetalworks:casting_42'},inventories={'gear_parts','gear_casts','gear_output'}}
 local function rpc(method,args,id,sender) return svc.handle(sender or 10,{version=1,id=id or 'layout',method=method,args=args}) end
 assert(not svc.readyForLocal())
 assert(not pcall(rpc,'pour',{target='obsolete',fluid='productivemetalworks:molten_iron',amount=90},'10:500000:1'))
 rpc('register',{layout=layout});rpc('reserve',{demand={},layout=layout});assert(svc.readyForLocal())
 for _,conflict in ipairs({'fluid_display','fluid_supply','fluid_basin','fluid_output'}) do
  local bad={monitors={},destinations={'gear_station'},inventories={conflict}}
  local ok,e=pcall(rpc,'register',{layout=bad});assert(not ok and tostring(e):find(conflict,1,true))
 end
 cfg.clients[2]=11
 local ok,e=pcall(rpc,'register',{layout=layout},'other',11);assert(not ok and tostring(e):find('Gear computer 10',1,true))
 cfg.clients[2]=nil
 rpc('pour',{target='gear_station',fluid='productivemetalworks:molten_iron',amount=90},'10:500000:2');assert(poured==90)
 svc=factory('ownership',cfg)
 assert(not pcall(rpc,'pour',{target='gear_station',fluid='productivemetalworks:molten_iron',amount=90},'10:500000:3'))
 rpc('reserve',{demand={},layout=layout});assert(svc.readyForLocal())
 rpc('pour',{target='gear_station',fluid='productivemetalworks:molten_iron',amount=90},'10:500000:4');assert(poured==180)
 -- A live client repeats the layout with heartbeats and flags an ownership conflict.
 local pending={};local timer=0
 os.startTimer=function() timer=timer+1;return timer end;os.cancelTimer=function() end
 os.getComputerID=function() return 10 end;os.pullEvent=function() return table.unpack(table.remove(pending,1)) end
 rednet={open=function() end,send=function(peer,message,protocol)
  local success,result=pcall(svc.handle,10,message)
  pending[#pending+1]={'rednet_message',20,{version=1,id=message.id,ok=success,result=success and result,error=not success and tostring(result)},protocol};return true
 end}
 local client=assert(load(fluid_clientSource))()(Network,{modem='left',serverId=20,monitors={'gear_display'},destinations={'productivemetalworks:casting_42'}})
 client.checkAssignments({Sword={peripheral='gear_station'}},{'gear_parts'})
 client.reserve({});svc=factory('ownership',cfg);client.reserve({});assert(svc.registrations[10].destinations['productivemetalworks:casting_42'])
 cfg.monitors={'gear_display'}
 assert(not pcall(client.reserve,{}) and client.assignmentError:find('gear_display',1,true))
 cfg.monitors={'fluid_display'};client.reserve({});assert(client.assignmentError==nil)
""")
print('PASS Rednet ownership exchange: no copied Gear list, monitor/storage/basin/chest and other-peer overlap rejection, unannounced pours denied, heartbeat re-registration after server restart, client conflict quarantine and recovery')

setup=(R/'network_setup.lua').read_text()
l.globals().monitorPicker=setup[:setup.rindex('while true do')]+"\nreturn {choose=choose,entries=entries,draw=draw,save=save}"
l.execute(r"""
 os.getComputerID=function() return 10 end
 files['root/fluid_network.txt']=textutils.serialize({role='gear',modem='left',serverId=20,monitors={'monitor_2','monitor_10'}})
 local connected={monitor_2=true,monitor_3=true}
 peripheral.getNames=function() return {'monitor_2','monitor_3'} end
 peripheral.getMethods=function() return {} end
 peripheral.hasType=function(name,kind) return kind=='monitor' and connected[name]==true end
 local fg;local sawRed=false
 term.setTextColor=function(color) fg=color end
 term.write=function(text) if text:find('[DISCONNECTED]',1,true) then assert(fg==colors.red);sawRed=true end end
 local picker=assert(load(monitorPicker))();picker.choose('monitors','monitor',true)
 local rows=picker.entries();assert(#rows==3 and rows[3].label=='[x] monitor_10 [DISCONNECTED]' and rows[3].fg==colors.red)
 picker.draw();assert(sawRed)
 rows[3].action();picker.choose('monitors','monitor',true);rows=picker.entries();assert(#rows==2)
 -- A selected device disappearing while the picker is open changes its status immediately.
 connected.monitor_2=false;rows=picker.entries();assert(rows[1].label:find('[DISCONNECTED]',1,true) and rows[1].fg==colors.red);picker.draw()
 connected.monitor_2=true;rows=picker.entries();assert(not rows[1].label:find('[DISCONNECTED]',1,true) and rows[1].fg==nil)
 rows[2].action();picker.save()
 local saved=Network.load('root');assert(#saved.monitors==2 and saved.monitors[1]=='monitor_2' and saved.monitors[2]=='monitor_3')
""")
print('PASS missing monitors: retained/red/deselectable, natural order, refreshed choices and live disconnect/reconnect styling')

setup=(R/'network_setup.lua').read_text()
l.globals().devicePicker=setup[:setup.rindex('while true do')]+"\nreturn {choose=choose,entries=entries,draw=draw,config=c,main=function() view='main' end}"
l.execute(r"""
 os.getComputerID=function() return 20 end
 local main0='functionalstorage:storage_controller_0';local main1='functionalstorage:storage_controller_1';local gear='functionalstorage:storage_controller_2'
 local basin43='productivemetalworks:casting_43';local basin44='productivemetalworks:casting_44';local chest='sophisticatedstorage:chest_9'
 files['root/fluid_network.txt']=textutils.serialize({role='fluid',modem='left',monitors={'monitor_1'},sources={main0,main1},gearSources={gear},basins={basin43,basin44},blockOutputChest=chest,clients={10}})
 local online={monitor_1=true,[main1]=true,[basin44]=true}
 peripheral.getNames=function() local names={};for name in pairs(online) do names[#names+1]=name end;return names end
 peripheral.hasType=function(name,kind) return online[name]==true and (kind=='monitor' and name=='monitor_1' or kind=='modem' and name=='right') end
 peripheral.getMethods=function(name)
  assert(online[name],'Disconnected')
  if name:find('functionalstorage:',1,true) then return {'tanks','pushFluid'} end
  if name:find('casting_',1,true) then return {'list','tanks','pushFluid','pushItems'} end
  if name==chest then return {'list','size','pushItems'} end
  return {}
 end
 local picker=assert(load(devicePicker))()
 local function categories()
  picker.main();local result={};for _,row in ipairs(picker.entries()) do if row.deviceKey then result[row.deviceKey]=row end end;return result
 end
 local cats=categories()
 for _,key in ipairs({'modem','sources','gearSources','basins','blockOutputChest'}) do assert(cats[key].fg==colors.red and cats[key].label:find('[1 DISCONNECTED]',1,true),key) end
 assert(cats.monitors.fg==nil)
 local function missing(key,name,multiple)
  picker.choose(key,key=='modem' and 'modem' or 'fluid',multiple)
  for _,row in ipairs(picker.entries()) do
   if row.label:find(name,1,true) then assert(row.fg==colors.red and row.label:find('[DISCONNECTED]',1,true));return row end
  end
  error('Missing disconnected entry '..name)
 end
 missing('sources',main0,true).action();assert(#picker.config.sources==1 and picker.config.sources[1]==main1 and categories().sources.fg==nil)
 missing('gearSources',gear,true).action();assert(#picker.config.gearSources==0 and categories().gearSources.fg==nil)
 missing('modem','left',false).action();assert(picker.config.modem==nil and categories().modem.fg==nil)
 missing('blockOutputChest',chest,false).action();assert(picker.config.blockOutputChest==nil and categories().blockOutputChest.fg==nil)
 picker.choose('basins','basin',true);online[basin43]=true
 local rows=picker.entries();for _,row in ipairs(rows) do if row.label:find(basin43,1,true) then assert(row.fg==nil and not row.label:find('[DISCONNECTED]',1,true)) end end
 assert(categories().basins.fg==nil)
 online[basin44]=nil;missing('basins',basin44,true).action();assert(#picker.config.basins==1 and picker.config.basins[1]==basin43)
 online.right=true
 files['root/fluid_network.txt']=textutils.serialize({role='gear',modem='right',monitors={'monitor_1'},serverId=20,destinations={'productivemetalworks:casting_2',basin43}})
 os.getComputerID=function() return 10 end
 picker=assert(load(devicePicker))();cats=categories();assert(cats.destinations.fg==colors.red)
 missing('destinations','productivemetalworks:casting_2',true).action()
 assert(#picker.config.destinations==1 and categories().destinations.fg==nil)
""")
print('PASS every device category: red disconnected counts, retained missing modem/stores/basins/stations/chest, multi/single deselection, immediate reconnect updates and warnings clear after removal')

l.execute(r"""
 -- Real Setup event flow: refresh, role responses, selection and Save without read().
 os.getComputerID=function() return 10 end;os.getComputerLabel=function() return 'Gear Center' end
 files['root/fluid_network.txt']=textutils.serialize({role='gear',modem='left',monitors={'monitor_1'},serverId=99})
 local computers={computer_10={id=10,label='Self'},computer_20={id=20,label='Fluid Center'},computer_30={id=30,label='Other Gear'}}
 peripheral.getNames=function() return {'computer_30','computer_20','computer_10','left','monitor_1'} end
 peripheral.getMethods=function(name) return computers[name] and {'getID','getLabel','isOn'} or {} end
 peripheral.hasType=function(name,kind) return name=='left' and kind=='modem' or name=='monitor_1' and kind=='monitor' end
 peripheral.call=function(name,method)
  if method=='isWireless' then return false end
  local computer=assert(computers[name]);if method=='getID' then return computer.id elseif method=='getLabel' then return computer.label elseif method=='isOn' then return true end;error(method)
 end
 local nonces={};local packets={};local timer=0
 rednet={open=function() end,broadcast=function(message,protocol) assert(protocol==Network.discoveryProtocol);nonces[#nonces+1]=message.nonce;return true end,
 send=function(id,message,protocol) packets[#packets+1]={id=id,message=message,protocol=protocol};return true end}
 os.startTimer=function() timer=timer+1;return timer end;os.cancelTimer=function() end
 read=function() error('Numeric ID entry must not be used') end
 local events={}
 local function key(k) events[#events+1]={'key',k} end
 for i=1,3 do key(keys.down) end;key(keys.enter);key(keys.r)
 events[#events+1]=function() return {'rednet_message',20,{kind='hello',version=1,id=20,role='fluid',label='STALE',nonce=nonces[1]},Network.discoveryProtocol} end
 events[#events+1]=function() return {'rednet_message',20,{kind='hello',version=1,id=21,role='fluid',label='WRONG ID',nonce=nonces[2]},Network.discoveryProtocol} end
 events[#events+1]=function() return {'rednet_message',20,{kind='hello',version=1,id=20,role='fluid',label='Fluid Center',nonce=nonces[2]},Network.discoveryProtocol} end
 events[#events+1]=function() return {'rednet_message',30,{kind='hello',version=1,id=30,role='gear',label='Other Gear',nonce=nonces[2]},Network.discoveryProtocol} end
 events[#events+1]=function() return {'timer',timer} end
 key(keys.down);key(keys.down);key(keys.enter) -- Wrong-role entry stays in picker.
 key(keys.up);key(keys.enter) -- Matching fluid computer 20.
 for i=1,6 do key(keys.down) end;key(keys.enter);key(keys.q)
 os.pullEvent=function() local event=table.remove(events,1);assert(event,'Setup did not exit');if type(event)=='function' then return table.unpack(event()) else return table.unpack(event) end end
 assert(load(network_setupSource))()
 local saved=Network.load('root');assert(saved.serverId==20 and #nonces==2 and saved.serverId~=10)
 assert(Network.replyDiscovery(saved,33,{kind='probe',nonce='test'},Network.discoveryProtocol))
 assert(packets[#packets].message.role=='gear' and packets[#packets].message.id==10 and packets[#packets].message.label=='Gear Center')
 assert(not Network.replyDiscovery(saved,10,{kind='probe',nonce='test'},Network.discoveryProtocol))
""")
print('PASS computer picker: native labels/IDs, self exclusion, role discovery/ranking, wrong-role rejection, stale/incorrect replies ignored, refresh and persisted selection without numeric input')

setup=(R/'network_setup.lua').read_text()
l.globals().peerPicker=setup[:setup.rindex('while true do')]+"\nreturn {scan=scanPeers,entries=entries,config=c}"
l.execute(r"""
 files['root/fluid_network.txt']=textutils.serialize({role='gear',modem='left',monitors={'monitor_1'},serverId=99})
 local picker=assert(load(peerPicker))();picker.scan('serverId')
 local missing
 for _,row in ipairs(picker.entries()) do if row.label:find('#99',1,true) then missing=row end end
 assert(missing and missing.fg==colors.red and missing.label:find('[OFFLINE]',1,true));missing.action();assert(picker.config.serverId==nil)
 files['root/fluid_network.txt']=textutils.serialize({role='fluid',modem='left',monitors={'monitor_1'},serverId=77,clients={}})
 os.getComputerID=function() return 20 end
 picker=assert(load(peerPicker))();picker.scan('client')
 for _,row in ipairs(picker.entries()) do assert(not row.label:find('#77',1,true)) end
 findAction(picker.entries(),'[ ] #10')();assert(picker.config.clients[1]==10)
""")
print('PASS offline computer retained/red/removable, cold native selection, partner roles independent and no numeric input needed')
for p in R.glob('*.lua'):
 ok,err=l.eval('function(s) local f,e=load(s);return f~=nil,e end')(p.read_text());assert ok,(p.name,err)
print('PASS all scripts compile in Lua 5.2')
