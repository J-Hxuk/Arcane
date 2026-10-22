extends RefCounted
## Normal mana is nonnegative. Debt is internal and never a spendable second pool.
static var CONFIG: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/mana_overdraw.json"))
static func limit(maximum:float) -> float:
	return maxf(0,maximum)*float(CONFIG["maximum_mana_fraction"])
static func ratio(debt:float,maximum:float) -> float:
	var capacity:=limit(maximum)
	return clampf(debt/capacity,0,1) if capacity>0 else 0.0
static func speed(debt:float,maximum:float) -> float:
	return 1.0-float(CONFIG["maximum_speed_reduction"])*ratio(debt,maximum)
static func blur(debt:float,maximum:float) -> float:
	var p:=ratio(debt,maximum)
	return 0.0 if p==0 else lerpf(CONFIG["blur_start"],CONFIG["blur_maximum"],p)
static func quote(current:float,maximum:float,cost:float,debt:=0.0) -> Dictionary:
	if not is_finite(current) or not is_finite(maximum) or not is_finite(cost) or not is_finite(debt) or maximum<=0 or current<0 or debt<0 or cost<0:
		return {"allowed":false}
	var shortage:=maxf(0,cost-current)
	var next_debt:=debt+shortage
	if next_debt>limit(maximum)+0.000001:return {"allowed":false}
	return {"allowed":true,"next_mana":maxf(0,current-cost),"next_debt":minf(next_debt,limit(maximum)),"mental_spent":shortage}
static func recover(current:float,debt:float,maximum:float,amount:float) -> Vector2:
	var paid:=minf(maxf(0,amount),debt)
	return Vector2(minf(maximum,maxf(0,current)+maxf(0,amount)-paid),maxf(0,debt-paid))
