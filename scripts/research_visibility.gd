extends RefCounted
## Public research receives projections of discovered entries, never the catalog.
static func known(book) -> Array:
	var rows:Array=[]
	for entry in book.entries():rows.append({"spell_id":entry["spell_id"],"name":entry["name"]})
	return rows
static func observed(state:Dictionary) -> String:
	if state.get("phase")=="FAILED" or float(state.get("stability",100))<30:return "형상이 흔들리고 거친 균열이 번집니다."
	if float(state.get("mana_amount",0))<=0:return "아직 뚜렷한 마나 구조가 없습니다."
	if float(state.get("flow_strength",0))>.4:return "마나의 흐름이 한 방향으로 수렴하고 있습니다."
	if float(state.get("cohesion",0))>30:return "작은 영역 안으로 마나가 조밀하게 모입니다."
	if float(state.get("form_integrity",0))>20:return "마나가 일정한 윤곽을 유지하려 합니다."
	return "모인 마나가 아직 자유롭게 움직입니다."
