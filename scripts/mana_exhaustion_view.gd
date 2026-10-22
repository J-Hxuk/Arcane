extends CanvasLayer
## One screen copy, one nine-sample draw, no mip chain or multi-pass blur.
const Rules=preload("res://scripts/mana_overdraw.gd")
var overlay:ColorRect
var material_effect:ShaderMaterial
var displayed_blur:=0.0
var displayed_ratio:=0.0
var entry_warning:=0.0
var positive_seconds:=1.0
var _armed:=true
var entry_count:=0
func _ready() -> void:
	layer=24
	overlay=ColorRect.new(); overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	material_effect=ShaderMaterial.new(); material_effect.shader=preload("res://data/shaders/mana_exhaustion.gdshader")
	overlay.material=material_effect; add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for pair in [["blur_radius_px","blur_radius_px"],["blur_minimum_radius_px","blur_minimum_radius_px"],["edge_extra_radius_px","edge_extra_radius_px"],["vignette_maximum","edge_vignette_maximum"],["entry_tint_multiplier","entry_tint_multiplier"]]:
		material_effect.set_shader_parameter(pair[0],Rules.CONFIG[pair[1]])
	overlay.hide()
func advance(debt:float,maximum:float,delta:float,active:=true) -> void:
	if not active:
		reset(); return
	var p:=Rules.ratio(debt,maximum)
	var target:=Rules.blur(debt,maximum)
	if p>0:
		positive_seconds=0
		if _armed:
			entry_count+=1; _armed=false
			entry_warning=Rules.CONFIG["entry_edge_warning"]
			displayed_blur=maxf(displayed_blur,minf(target,Rules.CONFIG["blur_start"]))
	else:
		positive_seconds+=maxf(0,delta)
		if positive_seconds>=float(Rules.CONFIG["warning_rearm_seconds"]):_armed=true
	var seconds:float=Rules.CONFIG["visual_rise_seconds"] if target>displayed_blur else Rules.CONFIG["visual_recovery_seconds"]
	var weight:=1.0-exp(-maxf(0,delta)/maxf(0.001,seconds))
	displayed_blur=lerpf(displayed_blur,target,weight)
	displayed_ratio=lerpf(displayed_ratio,p,weight)
	if delta>0:entry_warning=maxf(0,entry_warning-delta*float(Rules.CONFIG["entry_edge_warning"])/float(Rules.CONFIG["entry_warning_seconds"]))
	if p==0 and positive_seconds>=float(Rules.CONFIG["visual_recovery_seconds"]):
		displayed_blur=0;displayed_ratio=0;entry_warning=0
	material_effect.set_shader_parameter("strength",displayed_blur)
	material_effect.set_shader_parameter("ratio",displayed_ratio)
	material_effect.set_shader_parameter("edge_warning",entry_warning)
	overlay.visible=displayed_blur>0.0001 or entry_warning>0
func reset() -> void:
	displayed_blur=0;displayed_ratio=0;entry_warning=0;positive_seconds=1;_armed=true
	if overlay!=null:overlay.hide()
