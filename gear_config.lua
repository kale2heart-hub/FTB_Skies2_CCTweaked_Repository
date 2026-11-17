-- @crafting-center {"version":"1.2.0","suite":"crafting-center","id":"gear_config","title":"Gear Config","launchable":false,"description":"Shared machine and recipe configuration; not a runnable tool."}
-- Explicit wired peripheral names: run scan.lua to discover these.
return {
  autoDiscoverMolten = true, -- Other menus use real molten-fluid stock; new metals use 90 mB ingots.
  liveCasting = true, -- Enables Other casts and verified standalone tool-part routes.
  liveChestParts = true, -- Binding/Grip/Lining/Cord/Fletching/Coating deliver finished parts or material bundles.
  liveToolPartCasting = true, -- Tool Rod/Tip use real stock, even with demoMode=true.
  liveIronCasting = true, -- Enables the configured live ingot routes.
  liveIngotMaterials = {
    ["productivemetalworks:molten_iron"] = {
      label="Iron", amount=90,
      outputs={"minecraft:iron_ingot","ftbmaterials:iron_ingot"},
    },
    ["productivemetalworks:molten_constantan"] = {
      label="Constantan", amount=90, outputs={"ftbmaterials:constantan_ingot"},
    },
    -- Entries override auto-discovered recipes (amount, name, optional outputs).
    -- Set enabled=false on an entry to prevent ingot casting for that fluid.
    -- Known gem/non-metal fluids appear in menus but cannot use the ingot cast.
    -- outputs is OPTIONAL. Omit it to deliver and record the station's actual
    -- new output without looking up an item ID. Fluid, amount and correct
    -- ingot-cast compatibility still need to be known.
    -- ["ACTUAL:molten_metal"] = {label="Metal", amount=90},
  },
  demoMode = true, -- Sample stock/recipes. Set false to use real storage.
  monitors = { inDisplay = "", outDisplay = "", devDisplay = "" },
  textScale = 0.5,
  bottomMargin = 9, -- Blank text rows below every screen; restart after changing.
  partsChest = "sophisticatedstorage:chest_0", -- Leather, wool, parts/materials.
  castingTable = "productivemetalworks:casting_2",
  manualCastingTable = "productivemetalworks:casting_1",
  castingBasin = "productivemetalworks:casting_0",
  -- station_setup.lua writes gear_stations.txt, which overrides these defaults.
  castStations = {
    Block={peripheral="productivemetalworks:casting_0",part="Material"},
    ["Ingot"]={peripheral="productivemetalworks:casting_2",part="Material"},
    ["Nugget"]={peripheral="productivemetalworks:casting_3",part="Material"},
    ["Gem"]={peripheral="productivemetalworks:casting_4",part="Material"},
    ["Gear"]={peripheral="productivemetalworks:casting_5",part="Material"},
    ["Rod"]={peripheral="productivemetalworks:casting_6",part="Material"},
    ["Plate"]={peripheral="productivemetalworks:casting_7",part="Material"},
    ["Sword"]={peripheral="productivemetalworks:casting_8",part="Main"},
    ["Katana"]={peripheral="productivemetalworks:casting_9",part="Main"},
    ["Machete"]={peripheral="productivemetalworks:casting_10",part="Main"},
    ["Spear"]={peripheral="productivemetalworks:casting_11",part="Main"},
    ["Trident"]={peripheral="productivemetalworks:casting_12",part="Main"},
    ["Knife"]={peripheral="productivemetalworks:casting_13",part="Main"},
    ["Dagger"]={peripheral="productivemetalworks:casting_14",part="Main"},
    ["Pickaxe"]={peripheral="productivemetalworks:casting_15",part="Main"},
    ["Shovel"]={peripheral="productivemetalworks:casting_16",part="Main"},
    ["Axe"]={peripheral="productivemetalworks:casting_17",part="Main"},
    ["Paxel"]={peripheral="productivemetalworks:casting_18",part="Main"},
    ["Hammer"]={peripheral="productivemetalworks:casting_19",part="Main"},
    ["Excavator"]={peripheral="productivemetalworks:casting_20",part="Main"},
    ["Hoe"]={peripheral="productivemetalworks:casting_21",part="Main"},
    ["Mattock"]={peripheral="productivemetalworks:casting_22",part="Main"},
    ["Prospector Hammer"]={peripheral="productivemetalworks:casting_23",part="Main"},
    ["Saw"]={peripheral="productivemetalworks:casting_24",part="Main"},
    ["Sickle"]={peripheral="productivemetalworks:casting_25",part="Main"},
    ["Shears"]={peripheral="productivemetalworks:casting_26",part="Main"},
    ["Fishing Rod"]={peripheral="productivemetalworks:casting_27",part="Main"},
    ["Bow"]={peripheral="productivemetalworks:casting_28",part="Main"},
    ["Crossbow"]={peripheral="productivemetalworks:casting_29",part="Main"},
    ["Slingshot"]={peripheral="productivemetalworks:casting_30",part="Main"},
    ["Arrow"]={peripheral="productivemetalworks:casting_31",part="Main"},
    ["Ring"]={peripheral="productivemetalworks:casting_32",part="Main"},
    ["Bracelet"]={peripheral="productivemetalworks:casting_33",part="Main"},
    ["Necklace"]={peripheral="productivemetalworks:casting_34",part="Main"},
    ["Helmet"]={peripheral="productivemetalworks:casting_35",part="Main"},
    ["Chestplate"]={peripheral="productivemetalworks:casting_36",part="Main"},
    ["Leggings"]={peripheral="productivemetalworks:casting_37",part="Main"},
    ["Boots"]={peripheral="productivemetalworks:casting_38",part="Main"},
    ["Shield"]={peripheral="productivemetalworks:casting_39",part="Main"},
    ["Tool Rod"]={peripheral="productivemetalworks:casting_40",part="Tool Rod"},
    ["Tip"]={peripheral="productivemetalworks:casting_41",part="Tip"},
  },
  -- Optional exact material overrides, indexed by shape then fluid ID:
  -- castMaterialOverrides={Block={["ACTUAL:fluid"]={label="Material",amount=810}}},
  castChest = "sophisticatedstorage:chest_1", -- Cast storage; production adapter pending.
  outputChest = "sophisticatedstorage:chest_2",
  fluidStores = {"functionalstorage:storage_controller_0"},
  pollSeconds = 3,

  -- Exact recipe rules, added after inspecting the modpack.
  -- A rule is scoped to ONE equipment item and ONE part.
  -- fluid rule: {id="sword_iron_main", item="Sword", part="Main",
  --   label="Iron", source="fluid", name="ACTUAL:fluid_id", amount=180}
  -- chest rule: {id="sword_grip", item="Sword", part="Grip",
  --   label="Leather grip", source="chest", name="ACTUAL:item_id",
  --   nbt="EXACT_NBT_HASH_IF_PRESENT", amount=1}
  -- NBT is matched exactly; omitting it matches only stacks without NBT.
  -- For raw materials, amount is the required raw count. For finished
  -- parts it is the number of parts. Add separate rules for each route.
  rules = {},

  -- Populate confirmed recipes here; otherwise the item remains a UI draft.
  -- Example shape ONLY (check your pack before enabling):
  -- recipes = { Sword = {verified=true, parts={
  --   {name="Main", required=true, source="fluid"},
  --   {name="Tool Rod", required=true, source="fluid"},
  --   {name="Grip", required=false, source="chest"},
  -- }} },
  recipes = {},
}



