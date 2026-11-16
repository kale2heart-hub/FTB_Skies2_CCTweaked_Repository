-- @crafting-center {"version":"1.0.0","suite":"crafting-center","id":"casting_test","title":"Casting Test","description":"Commission the manual casting table.","dependencies":["gear_config.lua"],"actions":[{"id":"test_inspect","title":"Casting Test: Inspect","args":["inspect"],"description":"Read-only inspection of the manual test table."},{"id":"test_collect","title":"Casting Test: Collect","args":["collect"],"description":"Move one existing test ingot into the output chest.","locks":["casting-state"]},{"id":"test_iron","title":"Casting Test: Iron","args":["iron"],"description":"REAL test: cast one iron ingot using 90 mB on the manual table.","locks":["casting-state"]}]}
-- One-shot commissioning test. Separate from the UI and request queue.
-- casting_test          : inspect only
-- casting_test collect  : move ONE existing iron/steel ingot to output
-- casting_test iron     : inject EXACTLY 90 mB iron, wait, deliver ONE ingot
local ROOT=fs.getDir(shell.getRunningProgram())
local configPath=fs.combine(ROOT,"gear_config.lua")
local C=fs.exists(configPath) and dofile(configPath) or {}
local TABLE=C.manualCastingTable or C.castingTable or "productivemetalworks:casting_1"
local SOURCE=(C.fluidStores or {})[1] or "functionalstorage:storage_controller_0"
local OUTPUT=C.outputChest~="" and C.outputChest or nil
OUTPUT=OUTPUT or "sophisticatedstorage:chest_2"
local IRON="productivemetalworks:molten_iron"
local CAST_WAIT=3 -- Minimum cooling time after a successful fluid transfer.
local DELIVERY_WAIT=10 -- Retry only extraction, never fluid insertion.
local STATE=fs.combine(ROOT,"casting_test_state.txt")
local args={...}
local mode=args[1] or "inspect"
local function invoke(name,method,...)
  local ok,result=pcall(peripheral.call,name,method,...)
  if not ok then error(name.."."..method..": "..tostring(result),0) end
  return result
end
local function requireMethod(name,method)
  local methods=peripheral.getMethods(name) or {}
  for _,m in ipairs(methods) do if m==method then return end end
  error("Missing "..method.." on "..name,0)
end
local function fluidAmount(name,fluid)
  local amount=0
  for _,tank in pairs(invoke(name,"tanks")) do
    if tank.name==fluid then amount=amount+(tank.amount or 0) end
  end
  return amount
end
local function totalFluid(name)
  local amount=0
  for _,tank in pairs(invoke(name,"tanks")) do amount=amount+(tank.amount or 0) end
  return amount
end
local function loadState()
  if not fs.exists(STATE) then return nil end
  local f=assert(fs.open(STATE,"r")); local value=textutils.unserialize(f.readAll()); f.close()
  if type(value)~="table" then error("Unreadable test state; inspect before starting another cast.",0) end
  return value
end
local function saveState(state)
  local f=assert(fs.open(STATE,"w")); f.write(textutils.serialize(state)); f.close()
end
local function ironItem(item)
  return item and (item.name=="minecraft:iron_ingot" or item.name=="ftbmaterials:iron_ingot")
end
local function collect(ironOnly)
  local deadline=os.clock()+DELIVERY_WAIT
  local expected
  local waiting=false
  repeat
    local item=invoke(TABLE,"list")[1]
    if not item then error("No output in table slot 1. Inspect before retrying.",0) end
    if not ironItem(item) and (ironOnly or item.name~="ftbmaterials:steel_ingot") then
      error("Unexpected output left in table: "..item.name..". Inspect it with scan.",0)
    end
    if expected and (item.name~=expected.name or item.nbt~=expected.nbt) then
      error("Output changed during delivery. Stopped for inspection.",0)
    end
    if not expected then
      expected={name=item.name,nbt=item.nbt}
      print("Moving 1 x "..item.name.." to "..OUTPUT)
    end
    local moved=invoke(TABLE,"pushItems",OUTPUT,1,1)
    if moved==1 then print("Items moved: 1"); return item.name end
    if moved~=0 then error("Unexpected transfer result: "..tostring(moved)..". Inspect before retrying.",0) end
    if not waiting then
      print("Not extractable yet or output blocked; waiting...")
      waiting=true
    end
    sleep(0.5)
  until os.clock()>=deadline
  error("Delivery still blocked after "..DELIVERY_WAIT.." seconds. Check casting/output chest; no more fluid sent.",0)
end
local function main()
  if mode~="inspect" and mode~="collect" and mode~="iron" then
    print("Usage: casting_test [inspect|collect|iron]"); return
  end
  requireMethod(TABLE,"list"); requireMethod(TABLE,"tanks")
  requireMethod(SOURCE,"tanks")
  print("Table: "..TABLE); print("Fluid store: "..SOURCE); print("Output: "..OUTPUT)
  print("Iron available: "..fluidAmount(SOURCE,IRON).." mB")
  print("Table fluid: "..totalFluid(TABLE).." mB")
  local items=invoke(TABLE,"list")
  for slot,item in pairs(items) do print("Slot "..slot..": "..item.count.." x "..item.name) end
  local state=loadState()
  if state then print("Last test: "..tostring(state.status)) end
  if mode=="inspect" then print("Inspection only; nothing moved."); return end
  requireMethod(TABLE,"pushItems"); requireMethod(OUTPUT,"list")
  if mode=="collect" then
    if state and state.status~="done" and not ironItem(items[1]) then
      error("Pending iron test: unexpected item. Inspect before collecting.",0)
    end
    local item=collect(state and state.status~="done")
    if state and state.status~="done" then state.status="done"; state.output=item; saveState(state) end
    print("Collection test complete."); return
  end
  if state and state.status~="done" then
    error("Previous iron test needs inspection. No new fluid sent. Use scan/casting_test inspect.",0)
  end
  requireMethod(SOURCE,"pushFluid")
  requireMethod(OUTPUT,"size")
  if next(items) then error("Table output is occupied. Collect the existing ingot first.",0) end
  if totalFluid(TABLE)>0 then error("Table contains fluid; inspect before adding more.",0) end
  if fluidAmount(SOURCE,IRON)<90 then error("Need 90 mB molten iron.",0) end
  local occupied=invoke(OUTPUT,"list")
  local empty=false
  for slot=1,invoke(OUTPUT,"size") do if not occupied[slot] then empty=true; break end end
  if not empty then error("Leave one empty output-chest slot for this test.",0) end
  -- Cast is NOT exposed by list(). Leave the known ingot cast installed.
  -- Isolate the table from other fluid feeds/output extractors for this test.
  state={status="fluid_transfer_started",table=TABLE,source=SOURCE,outputChest=OUTPUT,fluid=IRON,requested=90}
  saveState(state) -- Write BEFORE the irreversible transfer; never auto-retry.
  local moved=invoke(SOURCE,"pushFluid",TABLE,90,IRON)
  state.moved=moved; state.status="waiting_for_output"; saveState(state)
  print("Fluid moved: "..tostring(moved).." / 90 mB")
  if moved~=90 then
    state.status="partial_or_failed_transfer"; saveState(state)
    error("Stopped without retry. Inspect fluid/output before continuing.",0)
  end
  print("Cooling: waiting at least "..CAST_WAIT.." seconds...")
  sleep(CAST_WAIT)
  local deadline=os.clock()+60
  while os.clock()<deadline do
    local result=invoke(TABLE,"list")[1]
    if result then
      if not ironItem(result) then
        state.status="unexpected_output"; state.actual=result.name; saveState(state)
        error("Unexpected output "..result.name.."; left in table for inspection.",0)
      end
      state.status="delivery_started"; saveState(state)
      state.output=collect(true); state.status="done"; saveState(state)
      print("SUCCESS: one iron ingot delivered."); return
    end
    sleep(0.5)
  end
  state.status="timeout"; saveState(state)
  error("No output after 60 seconds. No retry. Inspect the table/cast/fluid.",0)
end
local ok,err=pcall(main)
if not ok then printError(err); print("Stopped. Fluid is never automatically retried.") end

