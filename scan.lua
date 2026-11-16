-- @crafting-center {"version":"1.0.1","suite":"crafting-center","id":"scan","title":"Diagnostics","args":[],"description":"Read connected blocks, fluids, inventories and methods.","category":"Console Scripts"}
-- CC:Tweaked read-only, on-computer diagnostics. Run: scan
-- Discovers capabilities; NEVER invokes transfers, redstone or casting.
local ROOT=fs.getDir(shell.getRunningProgram())
local devices={}
local selected,offset=1,0
local mode="list"
local notice=""
local detailSlot,detailValue,detailError
local function call(name,method,...)
  local ok,a,b=pcall(peripheral.call,name,method,...)
  if not ok then return nil,tostring(a) end
  return a,nil,b
end
local function collect()
  devices={}
  local names=peripheral.getNames(); table.sort(names)
  for _,name in ipairs(names) do
    local d={name=name,methods={},types={}}
    local ok,methods=pcall(peripheral.getMethods,name)
    if ok and methods then
      table.sort(methods); d.methodList=methods
      for _,method in ipairs(methods) do d.methods[method]=true end
    else d.error="Disconnected during scan"; d.methodList={} end
    local types={pcall(peripheral.getType,name)}
    if types[1] then for i=2,#types do d.types[#d.types+1]=types[i] end end
    if d.methods.getSize then
      local w,err,h=call(name,"getSize")
      d.monitor=err and {error=err} or {width=w,height=h}
    end
    if d.methods.tanks then d.fluids,d.fluidError=call(name,"tanks") end
    if d.methods.list then d.items,d.itemError=call(name,"list") end
    if d.methods.size then d.slots,d.sizeError=call(name,"size") end
    devices[#devices+1]=d
  end
  selected=math.max(1,math.min(selected,#devices))
  offset=0; detailSlot,detailValue,detailError=nil,nil,nil
end
local function capability(d)
  local inv=d.methods.list and "I" or "-"
  local fluid=d.methods.tanks and "F" or "-"
  return inv..fluid.." "..(d.methods.pushItems and "i>" or "--").." "..(d.methods.pushFluid and "f>" or "--")
end
local function detailLines(d,width)
  local lines={}
  local function add(value)
    value=tostring(value or "")
    for line in (value.."\n"):gmatch("([^\n]*)\n") do
      if line=="" then lines[#lines+1]="" end
      for pos=1,#line,width do lines[#lines+1]=line:sub(pos,pos+width-1) end
    end
  end
  local function dump(value) add(textutils.serialize(value)) end
  add(d.name); add("Types: "..table.concat(d.types,", "))
  if d.error then add("ERROR: "..d.error) end
  add("ITEMS: read="..tostring(d.methods.list==true).." push="..tostring(d.methods.pushItems==true).." pull="..tostring(d.methods.pullItems==true))
  add("FLUID: read="..tostring(d.methods.tanks==true).." push="..tostring(d.methods.pushFluid==true).." pull="..tostring(d.methods.pullFluid==true))
  add("Capabilities do not guarantee a valid cast or transfer route.")
  if d.monitor then add("MONITOR (current text scale)"); dump(d.monitor) end
  if d.methods.tanks then
    add("--- FLUID TANKS ---")
    if d.fluidError then add("ERROR: "..d.fluidError)
    elseif type(d.fluids)=="table" then
      local count=0
      for tank,fluid in pairs(d.fluids) do
        count=count+1; add("Tank "..tostring(tank)); dump(fluid)
      end
      if count==0 then add("Empty / no exposed tanks") end
    else add("No tank data returned") end
  end
  if d.methods.list then
    add("--- INVENTORY ---")
    if d.slots then add("Slots: "..d.slots) end
    if d.sizeError then add("Size error: "..d.sizeError) end
    if d.itemError then add("ERROR: "..d.itemError)
    elseif type(d.items)=="table" then
      local slots={}; for slot in pairs(d.items) do slots[#slots+1]=slot end
      table.sort(slots)
      for _,slot in ipairs(slots) do add("Slot "..slot); dump(d.items[slot]) end
      if #slots==0 then add("Empty inventory") end
    else add("No inventory data returned") end
  end
  if detailSlot then
    add("--- ITEM DETAIL: SLOT "..detailSlot.." ---")
    if detailError then add("ERROR: "..detailError)
    elseif detailValue then dump(detailValue)
    else add("Empty slot / no detail") end
  end
  add("--- ALL EXPOSED METHODS ---")
  for _,method in ipairs(d.methodList) do add(method) end
  return lines
end
local function export()
  local path=fs.combine(ROOT,"discovery.txt")
  local f,err=fs.open(path,"w")
  if not f then notice="Save failed: "..tostring(err); return end
  f.write(textutils.serialize(devices)); f.close()
  notice="Saved discovery.txt (optional local copy)"
end
local function itemDetail()
  local d=devices[selected]
  if not d or not d.methods.getItemDetail then notice="No getItemDetail method on this block"; return end
  term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1,1)
  print("Item slot number (Enter cancels):")
  local input=read(); if input=="" then return end
  local slot=tonumber(input)
  if not slot or slot<1 or slot%1~=0 or (d.slots and slot>d.slots) then notice="Invalid slot"; return end
  detailSlot=slot; detailValue,detailError=call(d.name,"getItemDetail",slot)
  offset=0; notice="Item detail added below inventory"
end
local function render()
  local w,h=term.getSize()
  term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear()
  local function line(y,label,bg)
    term.setCursorPos(1,y); term.setBackgroundColor(bg or colors.black)
    label=tostring(label):sub(1,w); term.write(label..string.rep(" ",w-#label))
  end
  if w<20 or h<8 then line(1,"Need terminal 20x8"); return 1 end
  line(1,"GEAR DIAGNOSTICS | READ ONLY",colors.blue)
  local capacity=h-6
  if mode=="list" then
    local page=math.floor((selected-1)/capacity)
    line(2,"Devices: "..#devices.." | I=items F=fluids")
    line(3,"i>=pushItems f>=pushFluid (not tested)")
    if #devices==0 then line(4,"No peripherals. Enable wired modems.") end
    for row=1,capacity do
      local index=page*capacity+row
      local d=devices[index]
      if d then line(row+3,(index==selected and ">" or " ")..index.." "..capability(d).." "..d.name,index==selected and colors.blue or colors.black) end
    end
    line(h-2,"Arrows select | Enter inspect | R refresh")
    line(h-1,"Q quit | S save optional report")
  else
    local d=devices[selected]
    if not d then mode="list"; return render() end
    local lines=detailLines(d,w)
    offset=math.max(0,math.min(offset,math.max(0,#lines-capacity)))
    line(2,"Device "..selected.."/"..#devices.." | Lines "..(offset+1).."-"..math.min(offset+capacity,#lines).."/"..#lines)
    line(3,"Name: "..d.name)
    for row=1,capacity do line(row+3,lines[offset+row] or "") end
    line(h-2,"Up/Down scroll | PgUp/PgDn page | B back")
    line(h-1,"D item detail | R refresh | S save | Q quit")
  end
  line(h,notice,colors.gray)
  return capacity
end
collect()
while true do
  local capacity=render()
  local event,key=os.pullEvent()
  if event=="key" then
    notice=""
    if key==keys.q then break
    elseif key==keys.r then collect(); notice="Scan refreshed"
    elseif key==keys.s then export()
    elseif mode=="list" then
      if key==keys.up then selected=math.max(1,selected-1)
      elseif key==keys.down then selected=math.min(math.max(1,#devices),selected+1)
      elseif key==keys.pageUp then selected=math.max(1,selected-capacity)
      elseif key==keys.pageDown then selected=math.min(math.max(1,#devices),selected+capacity)
      elseif key==keys.enter and devices[selected] then mode="detail"; offset=0 end
    else
      if key==keys.up then offset=math.max(0,offset-1)
      elseif key==keys.down then offset=offset+1
      elseif key==keys.pageUp then offset=math.max(0,offset-capacity)
      elseif key==keys.pageDown then offset=offset+capacity
      elseif key==keys.b or key==keys.backspace then mode="list"; detailSlot,detailValue,detailError=nil,nil,nil
      elseif key==keys.d then itemDetail() end
    end
  elseif event=="mouse_scroll" then
    if mode=="detail" then offset=math.max(0,offset+key)
    else selected=math.max(1,math.min(math.max(1,#devices),selected+key)) end
  end
end
term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1,1)
print("Diagnostics closed.")
