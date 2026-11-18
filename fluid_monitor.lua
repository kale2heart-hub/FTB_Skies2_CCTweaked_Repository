-- @crafting-center {"version":"1.5.0","suite":"crafting-center","id":"fluid_monitor","title":"Liquid Resource Monitor","category":"Applications","description":"Fluid stock, managed whole-block basins and shared Gear fluid service.","locks":["fluid-service"],"dependencies":["pipe_casting.lua","basin_casting.lua","basin_casting_data.lua","fluid_network.lua","fluid_service.lua"]}
local VERSION="1.5.0"
local ROOT=fs.getDir(shell.getRunningProgram())
local N=dofile(fs.combine(ROOT,"fluid_network.lua"))
local c=N.load(ROOT)
assert(c.role=="fluid","Assign this computer to Fluid Monitor in Fluid Network Setup first")
N.open(c)
local service=dofile(fs.combine(ROOT,"fluid_service.lua"))(ROOT,c)
local blockRules=dofile(fs.combine(ROOT,"basin_casting_data.lua"))
local basins=dofile(fs.combine(ROOT,"basin_casting.lua"))(c,service)
local pipe=dofile(fs.combine(ROOT,"pipe_casting.lua"))(c,service)
local S={screen="welcome",page=1,quantity=1,shape="Block",message="",stock={},gearStock={},lastTouch=os.clock()}
local displays,W,H={},math.huge,math.huge
local palette={[colors.black]=0x101820,[colors.blue]=0x25394D,[colors.gray]=0x334155,[colors.lightGray]=0xAAB8C5,[colors.cyan]=0x176B80,[colors.green]=0x265F4B,[colors.red]=0x8B3545,[colors.white]=0xF0F5FA}
local function loadState(name,default)
 local path=fs.combine(ROOT,name)
 local function read(p)
  if not fs.exists(p) then return nil end
  local f=assert(fs.open(p,"r"));local value=textutils.unserialize(f.readAll());f.close()
  if type(value)~="table" then return nil end
  if name=="fluid_jobs.txt" and (type(value.jobs)~="table" or type(value.nextId)~="number") then return nil end
  return value
 end
 if fs.exists(path..".pending") then
  local pending=read(path..".pending")
  if pending then return pending end
  local primary=read(path)
  assert(primary,"Unreadable "..name.." and pending save; inspect before continuing")
  local archive=path..".rejected-"..os.epoch("utc");local suffix=0
  while fs.exists(archive..".txt") do suffix=suffix+1;archive=path..".rejected-"..os.epoch("utc").."-"..suffix end
  fs.move(path..".pending",archive..".txt")
  printError("Recovered "..name.." from last complete save; incomplete pending file retained for inspection")
  return primary
 end
 if not fs.exists(path) then return default end
 return assert(read(path),"Unreadable "..name.."; inspect before continuing")
end
local function saveState(name,value)
 local path=fs.combine(ROOT,name)
 local content=textutils.serialize(value) -- Validate before opening/truncating the pending file.
 local f=assert(fs.open(path..".pending","w"));f.write(content);f.close()
 local check=assert(fs.open(path..".pending","r"));local decoded=textutils.unserialize(check.readAll());check.close();assert(type(decoded)=="table","State save failed")
 if fs.exists(path) then fs.delete(path) end
 fs.move(path..".pending",path)
end
local Q=loadState("fluid_jobs.txt",{jobs={},nextId=1,paused=false})
assert(type(Q.jobs)=="table" and type(Q.nextId)=="number","Invalid fluid_jobs.txt")
for _,job in ipairs(Q.jobs) do
 if job.mode~="basin_blocks" then Q.paused=true;Q.reason="Legacy buffer job: cancel it and queue whole blocks after assigning basins" end
end
local auto=loadState("fluid_auto.txt",{})
local function saveQueue() saveState("fluid_jobs.txt",Q) end
local function connect()
 displays={};W,H=math.huge,math.huge
 for _,name in ipairs(c.monitors) do
  assert(peripheral.hasType(name,"monitor"),"Assigned fluid monitor disconnected: "..name)
  local m=peripheral.wrap(name);m.setTextScale(.5)
  for color,hex in pairs(palette) do m.setPaletteColor(color,hex) end
  local w,h=m.getSize();displays[#displays+1]={name=name,mon=m,w=w,h=h,cache={}}
  W=math.min(W,w);H=math.min(H,h-9)
 end
 assert(#displays>0 and W>=30 and H>=30,"Assign fluid monitors with at least 30x39 text cells")
end
local function center(s,w) s=tostring(s):sub(1,w);local left=math.floor((w-#s)/2);return string.rep(" ",left)..s..string.rep(" ",w-#s-left) end
local function format(n) return n>=1000 and string.format("%.2f B",n/1000) or tostring(n).." mB" end
local function selectedStock() for _,row in ipairs(S.stock) do if row.name==S.fluid then return row.amount end end;return 0 end
local function volume() return S.fluid and blockRules[S.fluid] and blockRules[S.fluid].amount end
local function navigate(screen) S.screen=screen;S.page=1;S.message="" end
local function enqueue(fluid,shape,quantity,automatic)
 assert(shape=="Block","Liquid Resource Monitor casts whole blocks only")
 local rule=assert(blockRules[fluid],"No verified whole-block basin recipe for this fluid")
 assert(#(c.basins or {})>0,"Assign managed basins in Network Setup")
 assert(c.blockOutputChest and c.blockOutputChest~="","Assign the block output chest in Network Setup")
 assert(type(quantity)=="number" and quantity>=1 and quantity<=64 and quantity==math.floor(quantity),"Quantity must be 1 to 64 whole blocks")
 local outputs={};for i,id in ipairs(rule.outputs) do outputs[i]=id end
 Q.jobs[#Q.jobs+1]={mode="basin_blocks",id=Q.nextId,fluid=fluid,shape="Block",quantity=quantity,completed=0,
  amount=rule.amount,outputs=outputs,units={},remaining=rule.amount*quantity,total=rule.amount*quantity,automatic=automatic or false}
 Q.nextId=Q.nextId+1;saveQueue();os.queueEvent("fluid_queue_changed")
end
local function cancelJob(index)
 assert(not S.busy,"Wait for the current basin operation")
 local job=Q.jobs[index];if not job then return end
 if job.pipe then
  job.pipe.cancelled=true;saveQueue();S.message="Waiting feed cancelled; Pipez tank and active basins will finish/recover";os.queueEvent("fluid_queue_changed");return
 end
 for basin,unit in pairs(job.units or {}) do
  if unit.phase=="partial" and (unit.moved or 0)==0 then job.units[basin]=nil end
 end
 local active=basins.active(job)
 if active>0 then
  job.quantity=(job.completed or 0)+active;job.remaining=active*job.amount
  S.message="Waiting blocks cancelled; active basins will finish and collect"
 else
  table.remove(Q.jobs,index)
  if job.id==Q.failedJobId or not Q.failedJobId and index==1 then Q.paused=false;Q.reason=nil;Q.failedJobId=nil end
  S.message="Job cancelled"
 end
 saveQueue();os.queueEvent("fluid_queue_changed")
end
local function resolveBasins(mode)
 assert(not S.busy,"Wait for current basin operation")
 service.acknowledge()
 local job=Q.jobs[1]
 for _,candidate in ipairs(Q.jobs) do if candidate.id==Q.failedJobId then job=candidate;break end end
 if job and job.pipe then pipe.resolve(job,saveQueue,mode)
 elseif job and job.mode=="basin_blocks" then basins.resolve(job,saveQueue,mode) end
 Q.paused=false;Q.reason=nil;saveQueue();os.queueEvent("fluid_queue_changed")
 navigate("utilities")
end
local function saveMinimum()
 local latest=N.load(ROOT)
 if S.minimumInherited then latest.gearMinimums[S.fluid]=nil else latest.gearMinimums[S.fluid]=S.minimum end
 N.save(ROOT,latest);c.gearMinimums=latest.gearMinimums
 os.queueEvent("fluid_refresh");navigate("gearStock");S.message="Gear minimum saved"
end
local function render()
 for _,d in ipairs(displays) do
  local breath=(1-math.cos(os.clock()*math.pi/3))/2
  local shade=S.screen=="welcome" and math.floor(9+7*breath) or 16
  local hex=S.screen=="welcome" and (shade*65536+math.floor(14+10*breath)*256+math.floor(18+14*breath)) or palette[colors.black]
  if d.background~=hex then d.mon.setPaletteColor(colors.black,hex);d.background=hex end
  local rows={};local buttons={};local ox=math.floor((d.w-W)/2);local oy=math.max(0,d.h-9-H)
  for y=1,d.h do rows[y]={text=string.rep(" ",d.w),fg=string.rep(colors.toBlit(colors.white),d.w),bg=string.rep(colors.toBlit(colors.black),d.w)} end
  local function text(x,y,width,label,bg,fg,align)
   if y<1 or y>d.h then return end
   width=math.max(0,math.min(width,d.w-x+1));if width==0 then return end
   label=align and center(label,width) or (tostring(label)..string.rep(" ",width)):sub(1,width)
   local r=rows[y]
   r.text=r.text:sub(1,x-1)..label..r.text:sub(x+width)
   r.fg=r.fg:sub(1,x-1)..string.rep(colors.toBlit(fg or colors.white),width)..r.fg:sub(x+width)
   r.bg=r.bg:sub(1,x-1)..string.rep(colors.toBlit(bg or colors.black),width)..r.bg:sub(x+width)
  end
  local function line(y,label,bg,fg) text(ox+1,oy+y,W,label,bg,fg,true) end
  local function button(x,y,width,label,action,bg)
   if not action and (label=="Previous" or label=="Next") then return end
   text(ox+x,oy+y,width,label,bg or (action and colors.blue or colors.gray),action and colors.white or colors.lightGray,true)
   text(ox+x,oy+y+1,width,"",bg or (action and colors.blue or colors.gray))
   if action then buttons[#buttons+1]={x=ox+x,y=oy+y,w=width,h=2,action=action} end
  end
  local half=math.floor((W-2)/2);local right=W-half+1
  if S.screen=="welcome" then
   text(1,math.floor(d.h/2)-1,d.w,"Welcome to the Fluid Center",colors.black,colors.white,true)
   text(1,math.floor(d.h/2)+1,d.w,"Right click to begin",colors.black,colors.lightGray,true)
   buttons[1]={x=1,y=1,w=d.w,h=d.h,action=function() navigate("main") end}
  else
   local problem=Q.paused or service.fault or S.stockError or S.gearError or S.refillError
   local frame=problem and colors.red or colors.blue
   line(1,"LIQUID RESOURCE MONITOR",frame)
   line(2,"Computer "..os.getComputerID().." | "..S.screen,nil,colors.lightGray)
   text(ox+1,d.h,W,"",frame)
   text(ox+W-#VERSION-1,d.h,#VERSION+1,"v"..VERSION,frame,colors.gray)
   if S.screen~="main" then
    button(1,3,half,"<< Back",function() navigate(S.screen=="review" and "material" or S.screen=="material" and "resources" or S.screen=="gearMinimum" and "gearStock" or "main") end,colors.gray)
    button(right,3,half,"Home",function() navigate("main") end)
   end
   if S.screen=="main" then
    local width=math.floor(W*2/3);local x=math.floor((W-width)/2)+1
    line(5,"Select Option")
    button(x,7,width,"Resources",function() navigate("resources") end,colors.cyan)
    button(x,10,width,"Queue ("..#Q.jobs..")",function() navigate("queue") end)
    button(x,13,width,"Automatic Casting",function() navigate("automatic") end)
    button(x,16,width,"Gear Stock / Minimums",function() navigate("gearStock") end)
    button(x,H-2,width,"Utilities",function() navigate("utilities") end,colors.gray)
   elseif S.screen=="resources" or S.screen=="automatic" or S.screen=="gearStock" then
    local listing=S.screen=="gearStock" and S.gearStock or S.stock
    local size=math.max(1,math.floor((H-14)/3));local pages=math.max(1,math.ceil(#listing/size));S.page=math.max(1,math.min(S.page,pages))
    line(6,S.screen=="gearStock" and "Gear-only stock / minimums" or S.screen=="automatic" and "Toggle automatic 64-block batches" or "Select a fluid",colors.blue)
    if #listing==0 then line(9,S.screen=="gearStock" and (service.hasGearStore() and "Gear stock unavailable or no molten fluids found" or "Assign Gear-only storage in Network Setup") or S.stockError and "Storage unavailable" or "No fluids in assigned storage",nil,colors.lightGray) end
    for i=1,size do
     local fluid=listing[(S.page-1)*size+i]
     if fluid then
      local label=N.label(fluid.name).." ("..format(fluid.amount)..")"
      if S.screen=="gearStock" then label=N.label(fluid.name)..": "..format(fluid.amount).." / Min "..format(fluid.minimum) end
      if S.screen=="automatic" then label=(auto[fluid.name] and "[ON] " or "[OFF] ")..label end
      button(1,8+(i-1)*3,W,label,function()
       if S.screen=="gearStock" then
        S.fluid=fluid.name;S.minimum=fluid.minimum;S.minimumInherited=(c.gearMinimums or {})[fluid.name]==nil;navigate("gearMinimum")
       elseif S.screen=="automatic" then assert(blockRules[fluid.name],"No verified whole-block recipe for this fluid");auto[fluid.name]=not auto[fluid.name];saveState("fluid_auto.txt",auto)
       else S.fluid=fluid.name;S.quantity=1;navigate("material") end
      end,S.screen=="gearStock" and ((fluid.deficit or 0)>0 and colors.red or colors.green) or auto[fluid.name] and S.screen=="automatic" and colors.green or colors.blue)
     end
    end
    if pages>1 then line(H-6,"Page: "..S.page.." / "..pages,nil,colors.lightGray) end
    button(1,H-4,half,"Previous",S.page>1 and function() S.page=S.page-1 end or nil)
    button(right,H-4,half,"Next",S.page<pages and function() S.page=S.page+1 end or nil)
    if S.screen=="gearStock" then line(H-1,S.refillError or service.refillStatus or "Gear minimums are maintained automatically",nil,colors.lightGray) end
   elseif S.screen=="gearMinimum" then
    line(6,N.label(S.fluid),colors.blue)
    local amount=0;for _,row in ipairs(S.gearStock) do if row.name==S.fluid then amount=row.amount end end
    line(9,"Gear stock: "..format(amount),nil,colors.lightGray)
    line(11,"Default minimum: "..format(c.gearMinimumDefault),nil,colors.lightGray)
    line(13,"Queued Gear demand: "..format(service.reserved(S.fluid)),nil,colors.lightGray)
    button(1,15,half,"Use default",function() S.minimum=c.gearMinimumDefault;S.minimumInherited=true end,colors.gray)
    button(right,15,half,"Minimum 0",function() S.minimum=0;S.minimumInherited=false end,colors.gray)
    line(18,"Minimum: "..format(S.minimum)..(S.minimumInherited and " (default)" or ""),colors.cyan)
    local deltas={-10000,-1000,1000,10000};local labels={"-10 B","-1 B","+1 B","+10 B"};local unit=math.floor(W/4)
    for i,delta in ipairs(deltas) do
     button(1+(i-1)*unit,H-9,i==4 and W-3*unit or unit,labels[i],function() S.minimum=math.max(0,math.min(1000000000,S.minimum+delta));S.minimumInherited=false end)
    end
    button(1,H-3,W,"Save minimum",saveMinimum,colors.cyan)
   elseif S.screen=="material" or S.screen=="review" then
    line(6,N.label(S.fluid),colors.blue)
    line(9,"Available: "..format(selectedStock()),nil,colors.lightGray)
    line(11,"Gear reserved: "..format(service.reserved(S.fluid)),nil,colors.lightGray)
    line(13,"Casting: Whole Blocks",colors.cyan)
    line(20,"Managed basins: "..#(c.basins or {}),nil,colors.lightGray)
    local amount=volume()
    line(16,amount and ("Need "..format(amount*S.quantity).." for "..S.quantity.." "..S.shape) or "No verified casting recipe for this fluid",nil,colors.lightGray)
    if S.screen=="review" then line(18,c.castingFluidTank and "Casting Fluid Tank > Pipez > basins > output" or "Cast, cool and collect into the block output chest",nil,colors.lightGray) end
    local labels={"Min","-16","-1","Qty:"..S.quantity,"+1","+16","Max"}
    local delta={false,-16,-1,false,1,16,false};local unit=math.floor(W/7)
    for i,label in ipairs(labels) do
     local index=i
     button(1+(i-1)*unit,H-7,i==7 and W-6*unit or unit,label,i~=4 and function()
      S.quantity=index==1 and 1 or index==7 and 64 or math.max(1,math.min(64,S.quantity+delta[index]))
     end or nil,i==4 and colors.cyan or colors.blue)
    end
    button(1,H-3,half,"Reset",function() S.quantity=1 end,colors.cyan)
    button(right,H-3,half,S.screen=="review" and "Add to Queue" or "Review",amount and function()
     if S.screen=="review" then enqueue(S.fluid,S.shape,S.quantity,false);S.quantity=1;S.message="Whole blocks added to queue"
     else navigate("review") end
    end or nil,colors.cyan)
   elseif S.screen=="queue" then
    line(6,"Items in Queue: "..#Q.jobs,colors.blue)
    local size=math.max(1,math.floor((H-17)/3));local pages=math.max(1,math.ceil(#Q.jobs/size));S.page=math.max(1,math.min(S.page,pages))
    for i=1,size do
     local index=(S.page-1)*size+i;local job=Q.jobs[index]
     if job then
      local count=job.mode=="basin_blocks" and (job.quantity-(job.completed or 0)).." blocks" or format(job.remaining)
      button(1,8+(i-1)*3,W,(basins.active(job)>0 and "Cancel waiting: " or "Cancel: ")..N.label(job.fluid).." ("..count..")",function() cancelJob(index) end,colors.gray)
     end
    end
    if #Q.jobs==0 then line(10,"Queue idle",nil,colors.lightGray) end
    button(1,H-8,half,"Previous",S.page>1 and function() S.page=S.page-1 end or nil)
    button(right,H-8,half,"Next",S.page<pages and function() S.page=S.page+1 end or nil)
    button(1,H-4,W,"Resume Queue",Q.paused and function() Q.paused=false;Q.reason=nil;saveQueue();os.queueEvent("fluid_queue_changed") end or nil,colors.cyan)
    line(H-1,Q.reason or service.last,nil,Q.paused and colors.red or colors.lightGray)
   elseif S.screen=="utilities" then
    line(6,"Fluid Service / Error Report",colors.blue)
    local problems=service.uncertain();line(9,"Uncertain transfers: "..#problems,nil,colors.lightGray)
    if problems[1] then
     line(11,"Inspect: "..problems[1].target,nil,colors.red)
     line(13,N.label(problems[1].fluid).." requested "..format(problems[1].amount),nil,colors.lightGray)
    end
    line(15,"Gear holds protected | Managed basins: "..#(c.basins or {}),nil,colors.lightGray)
    line(17,S.refillError or service.refillStatus or (service.hasGearStore() and "Gear-only storage enabled" or "Shared storage mode"),nil,colors.lightGray)
    button(1,H-7,W,"Inspect Complete / Acknowledge",(#problems>0 or service.fault or Q.paused) and function() navigate("acknowledge") end or nil,colors.gray)
    button(1,H-3,W,"Refresh Storage",function() os.queueEvent("fluid_refresh") end)
   elseif S.screen=="acknowledge" then
    line(7,"Inspect affected basins and the output chest first",nil,colors.red)
    line(10,"Retry empty = cast again. Delivered = count existing output.",nil,colors.lightGray)
    line(13,"This clears the service lock; no transfer is repeated.",nil,colors.lightGray)
    button(1,H-9,W,"Recheck inspected basin contents",function() resolveBasins(nil) end,colors.gray)
    button(1,H-6,W,"Retry inspected empty basins",function() resolveBasins("retry") end,colors.cyan)
    button(1,H-3,W,"Confirm empty basins already delivered",function() resolveBasins(true) end,colors.cyan)
   end
   if S.message~="" then line(H,S.message,nil,colors.lightGray) end
   if S.screen~="main" then
    local top=d.h-7;text(ox+1,top,W,string.rep("-",W),nil,colors.gray)
    text(ox+1,top+1,W,"Queue: "..#Q.jobs.." | Basins: "..(function() local n=0;for _,job in ipairs(Q.jobs) do n=n+basins.active(job) end;return n end)().."/"..#(c.basins or {}).." | "..(S.busy and "Managing basins" or Q.paused and "Error - Queue paused" or "Ready"),nil,Q.paused and colors.red or colors.lightGray,true)
    local cast=c.castingFluidTank and pipe.progress or basins.progress
    local progress=service.progress
    if cast and (cast.phase~="completed" or os.clock()-cast.at<=4) then
     local fill=math.floor(W*math.max(0,math.min(1,cast.moved)))
     text(ox+1,top+3,fill,"",cast.phase=="completed" and colors.green or colors.cyan)
     text(ox+1+fill,top+3,W-fill,"",colors.gray)
     text(ox+1,top+4,W,cast.phase.." | "..cast.completed.." / "..cast.quantity.." blocks",nil,colors.lightGray,true)
    elseif progress and os.clock()-progress.at<=4 then
     text(ox+1,top+3,W,"Fluid delivered: "..format(progress.moved),nil,colors.lightGray,true)
    else text(ox+1,top+3,W,service.last,nil,colors.lightGray,true) end
   end
  end
  d.buttons=buttons
  for y,row in ipairs(rows) do
   local key=row.text..row.fg..row.bg
   if d.cache[y]~=key then d.mon.setCursorPos(1,y);d.mon.blit(row.text,row.fg,row.bg);d.cache[y]=key end
  end
 end
end
local function networkLoop()
 while true do
  local sender,message=rednet.receive(N.protocol)
  if type(message)=="table" and message.version==1 and type(message.id)=="string" and #message.id<=160 then
   local ok,result=pcall(service.handle,sender,message)
   rednet.send(sender,{version=1,id=message.id,ok=ok,result=ok and result or nil,error=not ok and tostring(result) or nil},N.protocol)
   os.queueEvent("fluid_status")
  end
 end
end
local function queueWorker()
 while true do
  if Q.paused or #Q.jobs==0 then os.pullEvent("fluid_queue_changed") else
   S.busy=true;os.queueEvent("fluid_status")
   local function token(prefix)
    Q.nextPour=(Q.nextPour or 0)+1
    return (prefix or "basin")..":"..os.getComputerID()..":"..Q.nextPour..":1"
   end
   local ok,err=pcall(function()
    if c.castingFluidTank then
     -- Finish already-recorded direct casts before the shared pipe starts feeding.
     local draining=false;local done={}
     for _,job in ipairs(Q.jobs) do
      if not job.pipe and basins.active(job)>0 then
       for name,unit in pairs(job.units) do if unit.phase=="partial" and (unit.moved or 0)==0 then job.units[name]=nil;saveQueue() end end
       if basins.active(job)>0 then
        draining=true;basins.failedJobId=job.id
        if basins.tick(job,saveQueue,{allocate=false,nextRequest=token}) then done[job]=true end
       end
      end
     end
     for i=#Q.jobs,1,-1 do if done[Q.jobs[i]] then table.remove(Q.jobs,i);saveQueue() end end
     if not draining and Q.jobs[1] then
      basins.failedJobId=Q.jobs[1].id
      if pipe.step(Q.jobs[1],saveQueue,token) then table.remove(Q.jobs,1);saveQueue() end
     end
    else
     for _,job in ipairs(Q.jobs) do assert(not job.pipe,"Restore the Casting Fluid Tank assignment to resume this Pipez job") end
     basins.stepQueue(Q.jobs,saveQueue,token)
    end
   end)
   if not ok then Q.paused=true;Q.reason=tostring(err);Q.failedJobId=basins.failedJobId;saveQueue()
   elseif Q.failedJobId then Q.failedJobId=nil;saveQueue() end
   S.busy=false;os.queueEvent("fluid_status");sleep(.2)
  end
 end
end
local function stockWorker()
 while true do
  local refilled,refillError=pcall(service.refill)
  S.refillError=not refilled and tostring(refillError) or nil
  local gearOk,gearRows=pcall(service.gearStatus)
  S.gearStock=gearOk and gearRows or {};S.gearError=not gearOk and tostring(gearRows) or nil
  table.sort(S.gearStock,function(a,b) return N.label(a.name)<N.label(b.name) end)
  local ok,stock=pcall(service.stock)
  S.stock=ok and stock or {};S.stockError=not ok and tostring(stock) or nil
  table.sort(S.stock,function(a,b) return N.label(a.name)<N.label(b.name) end)
  local ready,reason=service.readyForLocal()
  if not ready then service.last=reason end
  if ready and not Q.paused and not service.fault and #service.uncertain()==0 and #(c.basins or {})>0 and c.blockOutputChest then
   local waiting=0;local reserved={}
   for _,job in ipairs(Q.jobs) do
    if job.mode=="basin_blocks" then
     waiting=waiting+basins.waiting(job)
     reserved[job.fluid]=(reserved[job.fluid] or 0)+basins.pendingFluid(job)
    end
   end
   -- Keep one wave of unassigned work available, with bounded admission and fair material rotation.
   for attempt=1,math.ceil(#c.basins/64)+1 do
    if waiting>=#c.basins or #S.stock==0 then break end
    local found=false
    for offset=1,#S.stock do
     local index=((S.autoCursor or 0)+offset-1)%#S.stock+1
     local fluid=S.stock[index];local rule=blockRules[fluid.name]
     if rule and auto[fluid.name] and service.blockAvailable(fluid.name,fluid.amount)-(reserved[fluid.name] or 0)>=rule.amount*64 then
      enqueue(fluid.name,"Block",64,true)
      reserved[fluid.name]=(reserved[fluid.name] or 0)+rule.amount*64
      waiting=waiting+64;S.autoCursor=index;found=true;break
     end
    end
    if not found then break end
   end
  end
  os.queueEvent("fluid_status")
  local timer=os.startTimer(3)
  while true do local event,id=os.pullEvent();if event=="fluid_refresh" or event=="timer" and id==timer then break end end
 end
end
local function uiLoop()
 local timer=os.startTimer(.5)
 while true do
  local event,name,x,y=os.pullEvent()
  if event=="rednet_message" and N.replyDiscovery(c,name,x,y) then
    -- Discovery does not grant fluid access.
  elseif event=="monitor_touch" then
   for _,d in ipairs(displays) do if d.name==name then
    S.lastTouch=os.clock()
    for _,button in ipairs(d.buttons or {}) do if x>=button.x and x<button.x+button.w and y>=button.y and y<button.y+button.h then
     local ok,err=pcall(button.action);if not ok then S.message=tostring(err) end;break
    end end
   end end
   render()
  elseif event=="fluid_status" then render()
  elseif event=="timer" and name==timer then
   local pending=#Q.jobs>0 or S.busy
   if not pending and os.clock()-S.lastTouch>=30 then S.screen="welcome" elseif pending and os.clock()-S.lastTouch>=60 then S.screen="queue" end
   render();timer=os.startTimer(.5)
  elseif event=="monitor_resize" or event=="peripheral" or event=="peripheral_detach" then connect();render() end
 end
end
connect();render()
print("Liquid Resource Monitor v"..VERSION.." | Computer "..os.getComputerID())
print("Only assigned monitors, fluid sources and managed block basins are controlled.")
parallel.waitForAny(uiLoop,networkLoop,queueWorker,stockWorker)
