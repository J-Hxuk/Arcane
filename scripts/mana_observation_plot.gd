extends Control
## Small per-axis sparklines of actual snapshots. No predicted/fictional state.
const Observation = preload("res://scripts/mana_observation.gd")
var frames: Array = []
var selected_index := -1
func set_frames(value: Array) -> void:
	frames=value.duplicate(true); queue_redraw()
func _draw() -> void:
	var font := get_theme_default_font()
	var cell := Vector2(size.x/4.0,size.y/2.0)
	for index in Observation.FIELDS.size():
		var field: String=Observation.FIELDS[index]
		var origin := Vector2((index%4)*cell.x,(index/4)*cell.y)
		draw_string(font,origin+Vector2(3,11),Observation.LABELS[field],HORIZONTAL_ALIGNMENT_LEFT,cell.x-6,10,Color("c0d0dd"))
		var values: Array=[]
		if not frames.is_empty() and frames[0].before.has(field): values.append(float(frames[0].before[field]))
		for frame in frames:
			if frame.after.has(field): values.append(float(frame.after[field]))
		if values.is_empty(): continue
		var low: float=values.min(); var high: float=values.max()
		var points := PackedVector2Array()
		for i in values.size():
			var ratio: float=(values[i]-low)/(high-low) if high-low>0.00000001 else .5
			points.append(origin+Vector2(4+(cell.x-12)*i/maxi(1,values.size()-1),cell.y-5-ratio*15))
		if points.size()>1: draw_polyline(points,Color("69cbe6"),1.5,true)
		for point in points: draw_circle(point,2,Color("d3f3ff"))
		if selected_index>=0 and selected_index<points.size():
			draw_circle(points[selected_index],3,Color("ffcc80"))
			if selected_index>0: draw_circle(points[selected_index-1],3,Color("9ee9ae"))
