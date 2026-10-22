extends CanvasLayer
static var CONFIG:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/hit_feedback.json"))
var intensity:=0.0
var shake_scale:=1.0
var edge:Control
var settings:AcceptDialog
var settings_button:Button
var slider:HSlider
func _ready()->void:
	layer=25
	edge=Control.new();edge.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(edge);edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);edge.draw.connect(_draw_edge)
	var controls:=CanvasLayer.new();controls.layer=28;add_child(controls)
	var button:=Button.new();settings_button=button;button.text="화면 설정";button.position=Vector2(1040,6);button.focus_mode=Control.FOCUS_NONE;controls.add_child(button)
	settings=AcceptDialog.new();settings.title="화면 흔들림";add_child(settings)
	var column:=VBoxContainer.new();settings.add_child(column)
	var label:=Label.new();label.text="카메라 흔들림 강도 · 왼쪽 끝: 끄기";column.add_child(label)
	slider=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=.1;slider.value=1;slider.custom_minimum_size=Vector2(360,30);column.add_child(slider)
	slider.value_changed.connect(func(value):shake_scale=value)
	button.pressed.connect(func():get_parent()._reset_combat_input();settings.popup_centered())
func advance(hp:float,maximum:float,delta:float,active:=true)->void:
	var target:=clampf(1-hp/maxf(1,maximum)/float(CONFIG.low_hp_threshold),0,1) if active else 0.0
	intensity=lerpf(intensity,target,1-exp(-maxf(0,delta)/float(CONFIG.rise_seconds if target>intensity else CONFIG.recovery_seconds)))
	if intensity<.0001:intensity=0
	edge.queue_redraw()
func _draw_edge()->void:
	if intensity<=0:return
	var screen:=edge.size
	for i in 12:
		var width:float=float(CONFIG.edge_width_px)/12
		var alpha:float=float(CONFIG.low_hp_max_alpha)*intensity*pow(1-float(i)/12,2)
		var color:=Color(.8,.015,.025,alpha)
		for rect in [Rect2(i*width,0,width,screen.y),Rect2(screen.x-(i+1)*width,0,width,screen.y),Rect2(0,i*width,screen.x,width),Rect2(0,screen.y-(i+1)*width,screen.x,width)]:edge.draw_rect(rect,color)
