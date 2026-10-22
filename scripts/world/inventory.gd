extends RefCounted
static var ITEMS:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
var data:Dictionary={"version":1,"items":{}}
static func valid(value:Variant)->bool:
	if not value is Dictionary or value.get("version",1)!=1 or not value.get("items",{}) is Dictionary:return false
	for id in value.get("items",{}):
		var count=value.items[id]
		if not id is String or not (count is int or count is float) or not is_finite(float(count)) or count<0 or count!=int(count):return false
	return true
func load_data(value:Dictionary)->void:
	data={"version":1,"items":{}};data.merge(value.duplicate(true),true)
func count(id:String)->int:return int(data.items.get(id,0))
func add(id:String,amount:int)->void:data.items[id]=count(id)+amount
func to_data()->Dictionary:return data.duplicate(true)
