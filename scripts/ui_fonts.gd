extends RefCounted
static var UI:FontVariation=create("res://assets/fonts/NotoSansKR.ttf",500)
static var BOOK:FontVariation=create("res://assets/fonts/NotoSerifKR.ttf",450)
static func create(path:String,weight:float)->FontVariation:
	var base:FontFile=load(path);base.allow_system_fallback=false
	var font=FontVariation.new();font.base_font=base;font.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):weight};return font
