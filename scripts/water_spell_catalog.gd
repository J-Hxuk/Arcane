extends RefCounted
## Official water identities. Recipes are multisets, never special-effect switches.
static var DATA:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/water15_spells.json"))
static func row(id:String)->Dictionary:
	for item in DATA.spells:
		if item.id==id:return item
	return {}
static func definition(id:String):
	var item:=row(id)
	if item.is_empty():return null
	# Keep the three already balanced formal spells and their physical roles.
	var spell=preload("res://scripts/m1_spell_catalog.gd").find(id).duplicate() if int(id.right(3))<=63 else preload("res://scripts/spell_definition.gd").new()
	spell.spell_id=id;spell.catalog_id=id;spell.display_name=item.name;spell.english_name=item.name
	spell.attribute=&"WATER";spell.requires_elements=PackedStringArray(["WATER"])
	spell.effect=StringName(item.effect);spell.damage=item.damage;spell.mana_cost=item.mana_cost
	spell.visual_style=StringName(id);spell.projectile_color=Color("63dcf5");spell.combat_rank=item.tier
	spell.formula_effect={"water15":true,"version":DATA.version,"source_id":id,"axis":item.axis,"armor_ignore":0.0,"strength":0.0}
	if int(id.right(3))<=63:return spell
	spell.projectile_radius=6;spell.projectile_speed=480;spell.lifetime=1
	match id:
		"OH-064":spell.projectile_speed=600;spell.lifetime=480.0/600;spell.formula_effect.armor_ignore=.10
		"OH-065":spell.radius=220;spell.knockback=75;spell.duration=.5
		"OH-066":spell.radius=85;spell.duration=3;spell.placement_distance=0
		"OH-067":spell.radius=75;spell.duration=5;spell.placement_distance=75
		"OH-068":spell.radius=115;spell.duration=2;spell.placement_distance=230;spell.knockback=-90;spell.status_effect=&"slow"
		"OH-069":spell.lifetime=490.0/480;spell.duration=.6
		"OH-070":spell.damage=80;spell.projectile_speed=520;spell.lifetime=550.0/520;spell.projectile_radius=5;spell.formula_effect.armor_ignore=.20
		"OH-071":spell.radius=155;spell.placement_distance=260;spell.knockback=-210;spell.duration=1;spell.status_effect=&"slow"
		"OH-072":spell.radius=42;spell.placement_distance=310;spell.duration=1.3;spell.status_effect=&"root"
		"OH-073":spell.radius=190;spell.placement_distance=250;spell.duration=6;spell.damage_per_second=13;spell.status_effect=&"slow"
		"OH-074":spell.projectile_speed=650;spell.lifetime=600.0/650;spell.formula_effect.armor_ignore=.30
		"OH-075":spell.lifetime=470.0/480
	return spell
