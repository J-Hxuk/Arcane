extends RefCounted
## Permanent awakenings and replaceable equipment have separate authority.
const ORDER=["WOOD","FIRE","EARTH","METAL","WATER"]
static func upgrade(source:Dictionary)->Dictionary:
	var data:=source.duplicate(true)
	if data.has("attribute_loadout_version"):return data
	var awakened:Array=[]
	var main=data.get("main_attribute")
	var auxiliary=data.get("auxiliary_attributes",[])
	if not auxiliary is Array:return data
	var legacy=data.get("legacy_committed_attributes",data.get("researched_base_elements",[]))
	if not legacy is Array or auxiliary.size()>1 or (main==null and not auxiliary.is_empty()):return data
	var commitments:Array=legacy+([] if main==null else [main])+auxiliary
	var seen:Array=[]
	for element in commitments:
		if element not in ORDER or element in seen:return data
		seen.append(element)
	if seen.size()>3:return data
	if data.has("main_attribute") and data.has("researched_base_elements"):
		if not data.researched_base_elements is Array or data.researched_base_elements.size()!=seen.size():return data
		for element in data.researched_base_elements:
			if element not in seen:return data
	var history=data.get("inactive_attribute_history",{})
	if not history is Dictionary:return data
	var roles=history.get("original_roles",{})
	if not roles is Dictionary or not roles.get("auxiliary_attributes",[]) is Array:return data
	for element in [main]+auxiliary+[roles.get("main_attribute")]+roles.get("auxiliary_attributes",[]):
		if element in ORDER and element not in awakened:awakened.append(element)
	var sorted:Array=[]
	for element in ORDER:
		if element in awakened:sorted.append(element)
	var bindings=data.get("binding_studies",[])
	var old_bindings=history.get("binding_studies",[])
	if not bindings is Array or not old_bindings is Array:return data
	bindings=bindings.duplicate()
	for pair in old_bindings:
		if pair not in bindings:bindings.append(pair)
	var observations=data.get("fusion_observations",{})
	if not observations is Dictionary or not history.get("fusion_observations",{}) is Dictionary:return data
	observations=observations.duplicate(true)
	for pair in history.get("fusion_observations",{}):
		if not observations.has(pair):observations[pair]=history.fusion_observations[pair].duplicate(true)
	data["awakening_migration"]={"main_attribute":main,"auxiliary_attributes":auxiliary.duplicate(),"legacy_committed_attributes":data.get("legacy_committed_attributes",[]).duplicate()}
	var active=main if main in sorted else (sorted[0] if not sorted.is_empty() else null)
	var aux=auxiliary[0] if not auxiliary.is_empty() and auxiliary[0] in sorted and auxiliary[0]!=active else null
	data.merge({"attribute_loadout_version":1,"awakened_attributes":sorted,"active_main_attribute":active,"active_auxiliary_attribute":aux,"selected_attribute_slot":"main","main_attribute":active,"auxiliary_attributes":[] if aux==null else [aux],"binding_studies":bindings,"fusion_observations":observations},true)
	return data
static func valid(data:Dictionary)->bool:
	if data.get("attribute_loadout_version")!=1:return false
	var awakened=data.get("awakened_attributes")
	if not awakened is Array or awakened.size()>5:return false
	var seen:Array=[]
	for element in awakened:
		if element not in ORDER or element in seen:return false
		seen.append(element)
	var main=data.get("active_main_attribute");var aux=data.get("active_auxiliary_attribute")
	if data.get("selected_attribute_slot") not in ["main","auxiliary"]:return false
	if awakened.is_empty():
		if main!=null or aux!=null:return false
	elif main not in awakened:return false
	if aux!=null and (aux not in awakened or aux==main):return false
	if data.get("main_attribute")!=main or data.get("auxiliary_attributes")!=([] if aux==null else [aux]):return false
	return true
static func owns_pair(elements:Array,awakened:Array)->bool:
	return elements.size()==2 and elements[0]!=elements[1] and elements[0] in ORDER and elements[1] in ORDER and elements[0] in awakened and elements[1] in awakened
static func valid_context(context:Dictionary)->bool:
	var awakened=context.get("awakened_attributes",[])
	if not awakened is Array or awakened.size()>5:return false
	var seen:Array=[]
	for element in awakened:
		if element not in ORDER or element in seen:return false
		seen.append(element)
	var main=context.get("active_main_attribute");var aux=context.get("active_auxiliary_attribute")
	if main==null:return awakened.is_empty() and aux==null
	return main in awakened and (aux==null or (aux in awakened and aux!=main))
static func candidates(awakened:Array,main:Variant,aux:Variant,slot:String)->Array:
	var values:Array=[null] if slot=="auxiliary" else []
	for element in ORDER:
		if element in awakened and element!=(aux if slot=="main" else main):values.append(element)
	return values
