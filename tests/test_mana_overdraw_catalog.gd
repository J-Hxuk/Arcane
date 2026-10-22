extends "res://tests/preview_world_phase1.gd"
# Historical interpreter/UI fixture. Production acceptance is test_formal_phase1..9.
const H=preload("res://tests/test_chant.gd")
const DIR:="res://.task002_artifacts/mana_overdraw/"
func run() -> void:
	var path:=DIR+"catalog.json";A.write(path,F.fixture("WATER",1787453028))
	game=Scene.instantiate();game.formal_rules=false;game.save_path=path;root.add_child(game);game.set_process(false)
	var original:Dictionary=game._character_document();var disk:=FileAccess.get_file_as_bytes(path);var count:=0
	for option in D.OPTIONS:
		game._start_developer_test(option,"LAB");game.magic_talent=50
		game.laboratory_panel.arena.set_process(false);game.laboratory_panel.arena.controller=null
		for example in D.examples(game.chant_profile,option,game.research.simulation_context()):
			game._laboratory_recover();game.player_mana=example["cost"]-5
			A.enter_keys(game,example["inputs"].map(func(input):return input["key"]))
			game._cast_spell();count+=1
			var record:Dictionary=game.journal.records()[-1]["result"]
			check(game.player_mana==0 and is_equal_approx(game.mana_debt,5) and record.get("manifestation",{}).get("spell_id")==example["spell_id"],"Automatic shortage payment manifests the existing spell "+example["spell_id"])
			check(record["manifestation"]["mental_spent"]==5 and record["energy_spent"]==example["cost"],"The shared transaction records exact mana/mental spending for "+example["spell_id"])
	game._start_developer_test("WATER","LAB");game.laboratory_panel.arena.controller=null;game.player_mana=10
	A.enter_keys(game,["Q","E"]);game._cast_spell();count+=1
	check(game.player_mana==0 and game.mana_debt==5 and game.journal.records()[-1]["result"]["manifestation"]["spell_id"]=="MANA_BOLT","Legacy pure mana bolt uses the same automatic payment transaction")
	check(count==22,"All 22 currently implemented combat spells are covered; the remaining 60 M2-M5 designs are not executable content")
	check(game._end_developer_test() and H.equal(game._character_document(),original) and FileAccess.get_file_as_bytes(path)==disk,"All catalog tests restore the original character and leave the isolated disk save untouched")
	game.free()
	var source:=DIR+"user_save_before.json"
	if FileAccess.file_exists(source):
		var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source));var fixture:=DIR+"current_user_copy.json";A.write(fixture,data)
		game=Scene.instantiate();game.formal_rules=false;game.save_path=fixture;root.add_child(game);game.set_process(false)
		var evidence_model=preload("res://scripts/character_research.gd").new();evidence_model.load_data(data.research);evidence_model.detach_evidence(data.laboratory.records);data.research=evidence_model.to_data()
		check(game.save_writable,"Current v4 player copy loads with the new resource accounting")
		for field in ["research","chant","laboratory","spell_discoveries","magic","body"]:
			check(H.equal(game._character_document()[field],data[field]),"Current player copy preserves "+field)
		game.free()
	else:print("SKIP: optional current-user copy compatibility checks (no fixture supplied)")
	print("MANA OVERDRAW CATALOG: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
