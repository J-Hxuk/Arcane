extends RefCounted
## Recognition scaffold only: production installs no real signature definitions.
var patterns:Array=[]
var active:=false
var remaining:=0.0
var _current:Array=[]
var settings:Dictionary=preload("res://scripts/chant_config.gd").DATA.signature_scaffold
func register_fixture(sequence:Array,general_rows:Array)->bool:
	if sequence.size() not in [7,8]:return false
	var prefix:Array=sequence.slice(0,3)
	for row in general_rows:
		var remaining_actions:Array=row.actions.duplicate()
		var fits:=true
		for action in prefix:
			if action not in remaining_actions:fits=false;break
			remaining_actions.erase(action)
		if fits:return false
	for pattern in patterns:
		if pattern.slice(0,3)==prefix:return false
	patterns.append(sequence.duplicate());return true
func observe(actions:Array,focus:bool)->String:
	end()
	if not focus:return "focus_required"
	for pattern in patterns:
		if actions==pattern:return "complete"
		if actions.size()>=3 and actions.size()<pattern.size() and actions==pattern.slice(0,actions.size()):
			active=true;remaining=float(settings.prepare_seconds);_current=actions.duplicate();return "prepared"
	return "unrecognized"
func advance(delta:float)->void:
	remaining=maxf(0,remaining-delta)
	if remaining<=0:end()
func enemy_multiplier()->float:return float(settings.enemy_multiplier) if active else 1.0
func end()->void:active=false;remaining=0;_current.clear()
