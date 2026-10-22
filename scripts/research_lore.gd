extends RefCounted
static var DATA:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/research_lore.json"))
static func personality(name:String)->String:
	for row in DATA.values():
		if name.contains(row.name):return row.personality
	return "결정의 결이 빛나며 마나의 형상이 세상에 남습니다."
static func color_for_name(name:String)->Color:
	for row in DATA.values():
		if name.contains(row.name):return Color(row.color)
	return Color("b6ecff")
static func page(element:String,index:int,known:Array)->String:
	var row:Dictionary=DATA[element];var text:String=row.pages[clampi(index,0,1)]
	if index==1:
		for entry in known:
			if str(entry.spell_id) in [str(row.spell),str(preload("res://scripts/m1_spell_catalog.gd").find(row.spell).spell_id)]:text+="\n\n[대조 확인] "+str(row.name);break
	return text
static func mentor(element:String,research)->String:
	var row:Dictionary=DATA[element];var branch:="seeking"
	if research.researched_base_elements.has(element):branch="awakened"
	elif research.ritual_eligibility(element)=="available":branch="ready"
	elif research.stable_count(element)>0:branch="stable"
	return str(row.mentor[branch])+"\n\n[구술 전승] "+str(row.mentor.oral)
