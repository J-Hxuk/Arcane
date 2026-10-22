extends RefCounted
## B + positional O + adjacent T. Never calls legacy _apply or reads affinity.
static func state(actions:Array,element:String,config:Dictionary)->Dictionary:
	var sum_weights:=0.0
	for i in actions.size():sum_weights+=pow(float(config.r),i)
	var sums:Dictionary={};var reference:Dictionary={};var components:Dictionary=config.elements.get(element,{})
	if element.contains("+"):
		var parts:=element.split("+");components={}
		for field in config.operations.ACCUMULATE.keys()+["compression_risk","interaction"]:
			components[field]=(float(config.elements[parts[0]].get(field,1 if field!="compression_risk" else 0))+float(config.elements[parts[1]].get(field,1 if field!="compression_risk" else 0)))*.5
	for i in actions.size():
		var vector:Dictionary=config.operations.get(actions[i],{})
		var weight:float=pow(float(config.r),i)/maxf(.001,sum_weights)
		for field in vector:
			var v:float=vector[field]*float(components.get(field,1.0))
			reference[field]=float(reference.get(field,0))+v
			sums[field]=float(sums.get(field,0))+v*(1+float(config.kappa)*(weight-1.0/actions.size()))
		if i>0:
			var interaction:Dictionary=config.transitions.get(str(actions[i-1])+">"+str(actions[i]),{})
			for field in interaction:sums[field]=float(sums.get(field,0))+float(config.lambda)*float(components.get("interaction",1))*interaction[field]
	var compression_count:int=actions.count("COMPRESS")
	var advanced_used:=false
	for action in actions:
		if action in ["EXPAND","SPLIT","CYCLE","ANCHOR","DISSIPATE"]:advanced_used=true
	sums["stability"]=float(sums.get("stability",0))-float(components.get("compression_risk",0))*compression_count*compression_count*float(config.thresholds.compression_penalty_scale)
	var stability:=clampf(float(config.thresholds.initial_stability)+float(sums.get("stability",0)),0,100)
	sums["reference"]=reference
	return {"grammar_version":8,"collapse_threshold":float(config.thresholds.collapse_below),"unstable_threshold":float(config.thresholds.unstable_below),"mana_amount":clampf(sums.get("mana_amount",0),0,60),"cohesion":clampf(sums.get("cohesion",0),0,100),"stability":stability,"form_integrity":clampf(sums.get("form_integrity",0),0,100),"flow_strength":clampf(sums.get("flow_strength",0),0,1.5),"flow_vector":[1,0] if "DIRECT" in actions else [0,0],"energy_loss":maxf(0,sums.get("energy_loss",0)),"persistence":maxf(0,sums.get("persistence",0)),"spread":maxf(0,sums.get("spread",0)),"base_attributes":[element] if not element.is_empty() else [],"resonance":{element:clampf(actions.size()*15,0,100)} if not element.is_empty() else {},"phase":"FAILED" if stability<float(config.thresholds.collapse_below) else "MANIPULATING","coupling":actions.count("RESONATE"),"cycles":actions.count("CYCLE"),"branches":1+actions.count("SPLIT"),"anchoring":minf(1,actions.count("ANCHOR")),"binding_window":false,"binding_quality":70 if "BIND" in actions else 0,"advanced_used":advanced_used,"variation_vector":sums}
static func projection(state:Dictionary,config:Dictionary)->Dictionary:
	var t:Dictionary=config.tuning
	var f:float=clampf((state.cohesion-state.form_integrity*float(t.form_density_ratio))/float(t.focus_denominator),-1,1)
	var m:float=clampf(state.flow_strength-state.persistence*float(t.motion_persistence),-1,1)
	var reference:Dictionary=state.variation_vector.get("reference",{})
	var ref_focus:float=float(reference.get("cohesion",0))-float(reference.get("form_integrity",0))*float(t.form_density_ratio)
	var ref_motion:float=float(reference.get("flow_strength",0))-float(reference.get("persistence",0))*float(t.motion_persistence)
	# The same continuous projection for every identity: amplify order response,
	# without selecting a preset or changing the B + O + adjacent-T calculation.
	var order_state:Dictionary=state.variation_vector if t.get("order_residual_mode","clipped_legacy")=="raw" else state
	var df:float=(order_state.get("cohesion",0)-order_state.get("form_integrity",0)*float(t.form_density_ratio)-ref_focus)/float(t.order_focus_scale)
	var dm:float=(order_state.get("flow_strength",0)-order_state.get("persistence",0)*float(t.motion_persistence)-ref_motion)/float(t.order_motion_scale)
	f=tanh(f+float(t.order_gain)*tanh(df))
	m=tanh(m+float(t.order_gain)*tanh(dm))
	return {"focus":f,"motion":m,"order_focus_input":df,"order_motion_input":dm}
static func tune(source,state:Dictionary,config:Dictionary):
	var result=source.duplicate()
	var t:Dictionary=config.tuning
	var projected:=projection(state,config)
	var f:float=projected.focus;var m:float=projected.motion
	result.damage*=1+float(t.damage_focus)*f
	result.projectile_speed*=1+float(t.speed_motion)*m
	result.lifetime*=maxf(.4,1+float(t.range_focus)*f+float(t.range_motion)*m)/(1+float(t.speed_motion)*m)
	result.radius*=1+float(t.radius_focus)*f
	result.knockback*=1+float(t.knockback_motion)*m
	result.duration*=maxf(.4,1+float(t.duration_focus)*f+float(t.duration_motion)*m)
	result.damage_per_second*=1+float(t.damage_focus)*f
	result.mana_cost*=1+float(t.cost_focus)*f+float(t.cost_motion)*absf(m)+state.energy_loss*float(t.cost_loss)
	result.variation_visual=true
	result.projectile_radius=maxf(4,source.projectile_radius if source.projectile_radius>0 else float(t.base_projectile_radius))*clampf(1-float(t.core_focus)*f-float(t.core_motion)*m,.45,1.8)
	result.visual_glow=clampf(1+.3*f,.6,1.4)
	result.visual_density=clampf(1+.5*f-.25*m,.4,1.8)
	result.visual_trail=clampf(1+.5*m,.5,1.5)
	if result.effect==&"barrier":
		# An obstacle has no useful projectile speed. Its area and lifetime share
		# one budget, so motion projection cannot buy a free improvement in both.
		result.duration=source.duration*pow(source.radius/maxf(1,result.radius),float(t.get("barrier_area_tradeoff",2.0)))
	return result
