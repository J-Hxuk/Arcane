extends RefCounted
var remaining:=0.0
var heavy:=false
var direction:=Vector2.ZERO
var last_damage:=0.0
var hits:=0
var shake_remaining:=0.0
var shake_peak:=0.0
var elapsed:=0.0
static var CONFIG:Dictionary=preload("res://scripts/hit_screen_view.gd").CONFIG
func receive(amount:float,strong:bool,heading:Vector2)->void:
	last_damage=amount;heavy=strong;direction=heading.normalized();remaining=.32 if strong else .20;hits+=1
	shake_remaining=maxf(shake_remaining,float(CONFIG.heavy_seconds if strong else CONFIG.normal_seconds))
	shake_peak=maxf(shake_peak,float(CONFIG.heavy_shake_px if strong else CONFIG.normal_shake_px))
func advance(delta:float)->void:
	remaining=maxf(0,remaining-delta);shake_remaining=maxf(0,shake_remaining-delta);elapsed+=maxf(0,delta)
	if shake_remaining==0:shake_peak=0
func camera_offset(scale:float,world_to_screen_scale:=Vector2.ONE)->Vector2:
	# Configuration is in visible pixels; Camera2D.offset is in world units.
	# Include viewport texture scaling when the camera is displayed inside UI.
	var screen_offset:=Vector2(sin(elapsed*float(CONFIG.shake_hz)*TAU),cos(elapsed*float(CONFIG.shake_hz)*TAU*.79))*.7071*shake_peak*scale*minf(1,shake_remaining/float(CONFIG.heavy_seconds))
	return screen_offset/world_to_screen_scale.abs().max(Vector2(.001,.001))
func offset()->Vector2:
	return direction*sin(remaining*65)*(4.0 if heavy else 2.0) if remaining>0 else Vector2.ZERO
