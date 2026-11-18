-- @crafting-center {"version":"1.0.0","suite":"crafting-center","id":"fluid_network","title":"Fluid Network Settings","launchable":false,"description":"Explicit per-computer wired network assignments."}
local T={protocol="crafting_center.fluids.v1",source="@fluid_service"}
function T.load(root)
 local path=fs.combine(root,"fluid_network.txt")
 if fs.exists(path..".pending") then path=path..".pending" end
 if not fs.exists(path) then return {role="standalone",monitors={},sources={},destinations={},clients={}} end
 local f=assert(fs.open(path,"r"));local c=textutils.unserialize(f.readAll());f.close()
 assert(type(c)=="table" and (c.role=="gear" or c.role=="fluid" or c.role=="standalone"),"Invalid fluid_network.txt; use Network Setup")
 for _,k in ipairs({"monitors","sources","destinations","clients"}) do c[k]=c[k] or {};assert(type(c[k])=="table","Invalid network "..k) end
 return c
end
function T.save(root,c)
 local path=fs.combine(root,"fluid_network.txt")
 local f=assert(fs.open(path..".pending","w"));f.write(textutils.serialize(c));f.close()
 if fs.exists(path) then fs.delete(path) end
 fs.move(path..".pending",path)
end
function T.open(c)
 assert(type(c.modem)=="string" and c.modem~="","Select the local wired modem in Network Setup")
 assert(peripheral.hasType(c.modem,"modem"),"Configured wired modem is disconnected")
 assert(peripheral.call(c.modem,"isWireless")==false,"Use a wired modem for the shared fluid network")
 rednet.open(c.modem)
end
function T.label(name)
 return name:gsub("^.*:",""):gsub("^molten_",""):gsub("_"," "):gsub("(%a)([%w]*)",function(a,b) return a:upper()..b end)
end
function T.volume(shape,fluid)
 if type(fluid)~="string" or not fluid:find(":molten_",1,true) then return nil end
 local name=fluid:gsub("^.*:",""):gsub("^molten_","")
 local gems={diamond=true,emerald=true,lapis=true,lapis_lazuli=true,redstone=true,quartz=true,slime=true}
 local extra={fluxite=true,glass=true,obsidian=true}
 if shape=="Block" then
  if extra[name] then return 1000 end
  if gems[name] then return 900 end
  if name=="amethyst" or name=="glowstone" then return 400 end
  return 810
 end
 if not gems[name] and not extra[name] and name~="amethyst" and name~="glowstone" and name~="blaze" then return 90 end
end
return T
