from pathlib import Path
from lupa.lua52 import LuaRuntime
R=Path(__file__).resolve().parents[1]
l=LuaRuntime(unpack_returned_tuples=True)
for name in ['pipe_casting','fluid_service','fluid_network','basin_casting','basin_casting_data']:
 l.globals()[name+'Source']=(R/(name+'.lua')).read_text()
l.execute(r'''
 now=100;files={};calls={};seq=0;returned=0;collected={};canReturn=true;fillLimit=1000000;bankLimit=1000000;outputBlocked=false
 local iron='productivemetalworks:molten_iron';local gold='productivemetalworks:molten_gold'
 store={[iron]=100000,[gold]=100000};h={tank={amount=0},b1={amount=0},b2={amount=0}}
 os={clock=function() return now end,epoch=function() return now*1000 end,getComputerID=function() return 20 end,queueEvent=function() end}
 sleep=function(t) now=now+t end
 parallel={waitForAll=function(...) for _,f in ipairs({...}) do f() end end}
 local function serialize(root)
  local seen={};local function encode(v)
   if type(v)=='table' then assert(not seen[v],'repeated table');seen[v]=true;local a={};for k,x in pairs(v) do a[#a+1]='['..encode(k)..']='..encode(x) end;return '{'..table.concat(a,',')..'}'
   elseif type(v)=='string' then return string.format('%q',v) else return tostring(v) end
  end;return encode(root)
 end
 textutils={serialize=serialize,unserialize=function(s) local f=load('return '..s);return f and f() end}
 fs={combine=function(a,b) return a..'/'..b end,exists=function(p) return files[p]~=nil end,
 delete=function(p) files[p]=nil end,move=function(a,b) assert(files[a]~=nil and files[b]==nil);files[b]=files[a];files[a]=nil end,
 open=function(p,mode)
  if mode=='r' then return files[p]~=nil and {readAll=function() return files[p] end,close=function() end} or nil end
  local content='';return {write=function(s) content=content..s end,close=function() files[p]=content end}
 end}
 local function mature(b)
  if b.ready and now>=b.ready then b.amount=0;b.ready=nil;b.item={name=b.name==gold and 'minecraft:gold_block' or 'minecraft:iron_block',count=1} end
 end
 local function add(name,amount,fluid)
  local b=assert(h[name]);assert(b.amount==0 or b.name==fluid);local moved=math.min(amount,fillLimit,name=='tank' and bankLimit-b.amount or 810-b.amount)
  b.amount=b.amount+moved;b.name=fluid;if name~='tank' and b.amount==810 then b.ready=now+3 end;return moved
 end
 peripheral={getMethods=function(name) return name=='store' and {'tanks','pushFluid','pullFluid'} or {'tanks','pushFluid','list','pushItems'} end,
 call=function(name,method,...)
  if name=='store' then
   if method=='tanks' then local rows={};for fluid,amount in pairs(store) do if amount>0 then rows[#rows+1]={name=fluid,amount=amount} end end;return rows end
   if method=='pushFluid' then local target,amount,fluid=...;assert(store[fluid]>=amount);local moved=add(target,amount,fluid);store[fluid]=store[fluid]-moved;calls[#calls+1]={target=target,moved=moved,fluid=fluid};return moved end
   if method=='pullFluid' then local origin,amount,fluid=...;local b=assert(h[origin]);mature(b);local moved=canReturn and not b.ready and b.name==fluid and math.min(amount,b.amount) or 0;b.amount=b.amount-moved;store[fluid]=(store[fluid] or 0)+moved;returned=returned+moved;return moved end
  end
  local b=assert(h[name],name);mature(b)
  if method=='tanks' then return b.amount>0 and {{name=b.name,amount=b.amount}} or {} end
  if method=='list' then return b.item and {[1]=b.item} or nil end
  if method=='pushItems' then assert(b.item);if outputBlocked then return 0 end;collected[b.item.name]=(collected[b.item.name] or 0)+1;b.item=nil;return 1 end
  error(method)
 end}
 cfg={sources={'store'},basins={'b1','b2'},castingFluidTank='tank',blockOutputChest='out',clients={10}}
 factory=assert(load(fluid_serviceSource))();service=factory('root',cfg)
 service.handle(10,{version=1,id='hold',method='reserve',args={demand={}}})
 worker=assert(load(pipe_castingSource))()(cfg,service)
 function job(id,fluid,count) return {id=id,mode='basin_blocks',fluid=fluid,amount=810,quantity=count,completed=0,remaining=count*810,outputs={fluid==gold and 'minecraft:gold_block' or 'minecraft:iron_block'},units={}} end
 function token(prefix) seq=seq+1;return (prefix or 'basin')..':20:'..seq..':1' end
 checkpoint=''
 function save() checkpoint=textutils.serialize(current) end
 function tick(dt) now=now+(dt or 0);service.handle(10,{version=1,id='hold',method='reserve',args={demand={}}});return worker.step(current,save,token) end
 function pipes()
  for _,name in ipairs({'b1','b2'}) do
   local b=h[name];mature(b)
   if h.tank.amount>0 and not b.item and not b.ready then
    local amount=math.min(h.tank.amount,810-b.amount);local moved=add(name,amount,h.tank.name);h.tank.amount=h.tank.amount-moved
   end
  end
 end
 current=job(1,iron,2);assert(not tick());assert(h.tank.amount==1620 and #calls==1 and calls[1].target=='tank')
 local before=#calls;local restored=textutils.unserialize(checkpoint);current=restored
 worker=assert(load(pipe_castingSource))()(cfg,service);assert(not tick() and #calls==before)
 pipes();assert(h.tank.amount==0 and h.b1.amount==810 and h.b2.amount==810)
 assert(not tick());tick(3.1);assert(collected['minecraft:iron_block']==2);assert(tick(.1))
 assert(#calls==1) -- no routine direct pours into basins
 current=job(2,gold,1);tick();pipes();tick();tick(3.1);assert(tick(.1));assert(collected['minecraft:gold_block']==1)
 -- Drawer capacity may accept a partial batch. Continue same material after it empties.
 current=job(3,iron,2);bankLimit=810;tick();assert(h.tank.amount==810);pipes();tick();assert(h.tank.amount==810)
 pipes();tick();tick(3.1);tick(.1);tick(3.1);assert(tick(.1));assert(collected['minecraft:iron_block']==4);bankLimit=1000000
''')
print('PASS Pipez batches: one tank feed, no normal basin pours, parallel block collection, restart without duplicate feed, clean material changes and partial-capacity tank feeding')
l.execute(r'''
 local iron='productivemetalworks:molten_iron'
 -- A 10-second partial basin is drained into main storage before any direct top-up.
 current=job(4,iron,1);tick();h.b1={amount=100,name=iron};h.tank.amount=h.tank.amount-100;tick()
 local before=returned;tick(9.9);assert(returned==before)
 tick(.2);assert(returned==before+100 and current.pipe.returned==100 and h.b1.amount==0)
 -- Cancel stops further feeding but preserves observed material and recovery accounting.
 current.pipe.cancelled=true
 -- Clear this fixture's residual tank by returning it to main; maintain the measured ledger.
 local drained=service.returnFluid(token('return'),'tank',iron,h.tank.amount);current.pipe.returned=current.pipe.returned+drained.moved
 assert(tick(.1))
 -- If a partial cannot be drained, add only the measured missing volume.
 current=job(5,iron,1);tick();h.b1={amount=100,name=iron};h.tank.amount=h.tank.amount-100;tick()
 canReturn=false;local beforeCalls=#calls;tick(10.1)
 assert(#calls==beforeCalls+1 and calls[#calls].target=='b1' and calls[#calls].moved==710 and current.pipe.topped==710)
 tick(3.1);tick(3.1);assert(collected['minecraft:iron_block']==5)
 -- Do not switch material merely because the tank is empty: previous basins still matter.
 assert(current.pipe.fed==810 and h.tank.amount==710)
 canReturn=true
 -- Returning the unused remainder balances the recovery top-up and avoids an extra block.
 local result=service.returnFluid(token('return'),'tank',iron,h.tank.amount);current.pipe.returned=current.pipe.returned+result.moved
 assert(tick(.1))
 -- A new material rejects an occupied tank or any leftover basin contents.
 current=job(6,'productivemetalworks:molten_gold',1);h.tank={amount=10,name=iron}
 assert(not pcall(tick));h.tank={amount=0};h.b2={amount=10,name=iron};assert(not pcall(tick));h.b2={amount=0}
 -- Corrupt routing cannot loop forever with missing fluid.
 current=job(7,iron,1);tick();h.tank.amount=0;tick();local ok,e=pcall(tick,10.1);assert(not ok and tostring(e):find('not found',1,true))
''')
print('PASS stalled-basin recovery: ten-second threshold, main-storage return first, exact top-up fallback, measured ledger balance, cancellation drain, material barrier and missing-fluid timeout')
l.execute(r'''
 local iron='productivemetalworks:molten_iron'
 local function fresh(id)
  h={tank={amount=0},b1={amount=0},b2={amount=0}};canReturn=true;outputBlocked=false;bankLimit=1000000;fillLimit=1000000
  current=job(id,iron,1);worker=assert(load(pipe_castingSource))()(cfg,service)
 end
 fresh(8);tick();h.b1={amount=100,name=iron};h.tank.amount=h.tank.amount-100;tick();now=now+10.1
 current.units.b1.returnRequest={id=token('return'),amount=100};save();local snapshot=checkpoint
 local result=service.returnFluid(current.units.b1.returnRequest.id,'b1',iron,100);assert(result.moved==100)
 local before=returned;current=textutils.unserialize(snapshot);service=factory('root',cfg);worker=assert(load(pipe_castingSource))()(cfg,service)
 tick();assert(returned==before and current.pipe.returned==100)
 fresh(9);tick();h.b1={amount=100,name=iron};h.tank.amount=h.tank.amount-100;tick();canReturn=false
 current.units.b1.topup={id=token(),amount=710};save();snapshot=checkpoint
 service.transfer(20,current.units.b1.topup.id,{target='b1',fluid=iron,amount=710},true)
 local count=#calls;current=textutils.unserialize(snapshot);worker=assert(load(pipe_castingSource))()(cfg,service)
 tick();assert(#calls==count and current.pipe.topped==710)
 fresh(10);tick()
 for i=1,3 do h.b1={amount=100,name=iron};h.tank.amount=h.tank.amount-100;tick();tick(10.1) end
 h.b1={amount=100,name=iron};h.tank.amount=h.tank.amount-100;tick();local ok,e=pcall(tick,10.1)
 assert(not ok and tostring(e):find('Recovery limit',1,true))
 fresh(11);tick();tick();ok,e=pcall(tick,30.1);assert(not ok and tostring(e):find('not emptying',1,true))
 fresh(12);tick();pipes();tick();outputBlocked=true;tick(3.1);count=#calls
 ok,e=pcall(tick,5.1);assert(not ok and tostring(e):find('Cannot extract',1,true) and #calls==count)
 outputBlocked=false;tick();assert(tick(.1) and #calls==count)
''')
print('PASS Pipez recovery safety: return/top-up replay after lost checkpoints, three-recovery bound, stalled tank timeout and blocked-output Resume without another feed')

monitor=(R/'fluid_monitor.lua').read_text()
l.globals().monitorSource=monitor[:monitor.rindex('connect();render()')]+"\nreturn {Q=Q,S=S,service=service,enqueue=enqueue,worker=queueWorker}"
l.execute(r'''
 h={tank={amount=0},b1={amount=0},b2={amount=0}};canReturn=true;outputBlocked=false
 colors={};for i,name in ipairs({'white','orange','magenta','lightBlue','yellow','lime','pink','gray','lightGray','cyan','purple','blue','brown','green','red','black'}) do colors[name]=2^(i-1) end
 fs.getDir=function() return 'apptest' end;shell={getRunningProgram=function() return 'apptest/fluid_monitor.lua' end}
 printError=function() end
 local call=peripheral.call;peripheral.call=function(name,method,...) if method=='isWireless' then return false end;return call(name,method,...) end
 peripheral.hasType=function() return true end;rednet={open=function() end}
 dofile=function(path)
  for _,name in ipairs({'fluid_network','fluid_service','basin_casting','basin_casting_data','pipe_casting'}) do if path:find(name..'.lua',1,true) then return assert(load(_G[name..'Source']))() end end
  error(path)
 end
 local config={role='fluid',modem='left',monitors={'monitor'},sources={'store'},basins={'b1','b2'},castingFluidTank='tank',blockOutputChest='out',clients={10}}
 files['apptest/fluid_network.txt']=textutils.serialize(config)
 local app=assert(load(monitorSource))()
 local function heartbeat() app.service.handle(10,{version=1,id='hold',method='reserve',args={demand={},layout={monitors={'gear_monitor'},destinations={'gear_station'},inventories={}}}}) end
 heartbeat()
 local iron='productivemetalworks:molten_iron';local gold='productivemetalworks:molten_gold'
 app.enqueue(iron,'Block',1,false);app.enqueue(gold,'Block',1,false)
 os.pullEvent=function() return coroutine.yield('event') end
 sleep=function(t) now=now+t;coroutine.yield('sleep') end
 local co=coroutine.create(app.worker);local first=#calls;local i0=collected['minecraft:iron_block'] or 0;local g0=collected['minecraft:gold_block'] or 0
 local ok,e=coroutine.resume(co);assert(ok,e);assert(#app.Q.jobs==2 and app.Q.jobs[1].pipe and not app.Q.jobs[2].pipe)
 for i=1,50 do now=now+.5;heartbeat();pipes();ok,e=coroutine.resume(co);assert(ok,e);assert(not app.Q.paused,app.Q.reason);if #app.Q.jobs==0 then break end end
 assert(#app.Q.jobs==0 and collected['minecraft:iron_block']==i0+1 and collected['minecraft:gold_block']==g0+1)
 assert(#calls==first+2 and calls[first+1].target=='tank' and calls[first+2].target=='tank' and calls[first+1].fluid==iron and calls[first+2].fluid==gold)
''')
print('PASS actual monitor worker: Pipez mode runs queued iron then gold, feeds only the Casting Fluid Tank, waits for collection/material clearance and persists progress')

l.execute(r'''
 local iron='productivemetalworks:molten_iron'
 h={tank={amount=0},b1={amount=0},b2={amount=0}};store[iron]=100000000;bankLimit=55300000;fillLimit=1000000000
 cfg.castingFluidTankCapacity=55300000
 current=job(20,iron,68271);worker=assert(load(pipe_castingSource))()(cfg,service)
 local before=#calls;tick()
 assert(#calls==before+1 and calls[#calls].target=='tank' and calls[#calls].moved==55299510 and h.tank.amount==55299510)
 -- Empty inventories intentionally return nil throughout this fixture, including recovery reads.
 local call=peripheral.call
 peripheral.call=function(name,method,...) if name=='b1' and method=='list' then return 17 end;return call(name,method,...) end
 local ok,e=pcall(tick);assert(not ok and tostring(e):find('Invalid item inventory from basin b1',1,true))
 peripheral.call=call
''')
print('PASS large tank feed: 55,299,510 mB in one batch, nil empty inventories/recovery paths handled, malformed non-table inventory gives a named error')
for p in R.glob('*.lua'):
 ok,e=l.eval('function(s) local f,e=load(s);return f~=nil,e end')(p.read_text());assert ok,(p.name,e)
print('PASS Lua 5.2 syntax')
