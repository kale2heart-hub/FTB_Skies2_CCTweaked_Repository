-- @crafting-center {"version":"1.0.0","suite":"crafting-center","id":"gear_chest_data","title":"Silent Gear Chest Part Data","launchable":false,"description":"Finished-part IDs and material rules from FTB Skies 2 1.25.3."}
-- Source: installed FTB Skies 2 1.25.3 material definitions and compound-part recipes.
-- Only exact item/tag ingredients with an explicit compatible part property are included.
return {packVersion="1.25.3",parts={
 ["Binding"]={finished="silentgear:binding",amount=1,extras={},materials={
  {item="silentgear:fine_silk",materialId="silentgear:fine_silk"},
  {item="silentgear:flax_string",materialId="silentgear:flax"},
  {item="silentgear:fluffy_string",materialId="silentgear:fluffy_string"},
  {item="silentgear:sinew_fiber",materialId="silentgear:sinew"},
  {item="minecraft:string",materialId="silentgear:string"},
  {item="minecraft:vine",materialId="silentgear:vine"},
 }},
 ["Grip"]={finished="silentgear:grip",amount=1,extras={},materials={
  {item="silentgear:fine_silk_cloth",materialId="silentgear:fine_silk_cloth"},
  {tag="c:leathers",materialId="silentgear:leather"},
  {item="minecraft:phantom_membrane",materialId="silentgear:phantom_membrane"},
  {tag="minecraft:wool",materialId="silentgear:wool"},
 }},
 ["Lining"]={finished="silentgear:lining",amount=1,extras={},materials={
  {item="silentgear:fine_silk_cloth",materialId="silentgear:fine_silk_cloth"},
  {tag="c:leathers",materialId="silentgear:leather"},
  {item="minecraft:phantom_membrane",materialId="silentgear:phantom_membrane"},
  {item="minecraft:slime_block",materialId="silentgear:slime"},
  {tag="minecraft:wool",materialId="silentgear:wool"},
 }},
 ["Cord"]={finished="silentgear:cord",amount=3,extras={},materials={
  {item="silentgear:fine_silk",materialId="silentgear:fine_silk"},
  {item="silentgear:flax_string",materialId="silentgear:flax"},
  {item="silentgear:fluffy_string",materialId="silentgear:fluffy_string"},
  {item="silentgear:sinew_fiber",materialId="silentgear:sinew"},
  {item="minecraft:string",materialId="silentgear:string"},
  {item="minecraft:vine",materialId="silentgear:vine"},
 }},
 ["Fletching"]={finished="silentgear:fletching",amount=1,extras={},materials={
  {tag="c:feathers",materialId="silentgear:feather"},
  {tag="minecraft:leaves",materialId="silentgear:leaves"},
  {tag="c:paper",materialId="silentgear:paper"},
 }},
 ["Coating"]={finished="silentgear:coating",amount=1,extras={{name="minecraft:glass_bottle",amount=1}},materials={
  {tag="c:ingots/blaze_gold",materialId="silentgear:blaze_gold"},
  {tag="c:ingots/gold",materialId="silentgear:gold"},
  {tag="c:ingots/netherite",materialId="silentgear:netherite"},
  {tag="c:gems/prismarine",materialId="silentgear:prismarine"},
  {tag="c:ingots/uru_metal",materialId="sgearmetalworks:uru_metal"},
 }},
}}
