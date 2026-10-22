extends RefCounted
const PERSPECTIVES={"WOOD":"생장과 유지","FIRE":"열과 전개","EARTH":"구조와 침전","METAL":"정밀한 집중","WATER":"흐름과 변화"}
const LESSONS=["마나는 조작을 통해 모이고 형태를 얻습니다. 같은 입력을 눌렀다 놓으면 한 번의 조작입니다.","축적은 재료를, 압축은 밀도를, 안정화는 균형을 바꿉니다. 하나씩 비교해 보세요.","같은 조작도 뒤에 둘수록 결과에 미치는 영향이 커질 수 있습니다. 입력 전후를 비교하세요.","나무는 유지, 불은 전개, 땅은 구조, 금은 정밀함, 물은 흐름에 서로 다른 성향을 보입니다.","흔들림이 커지면 정상 발현과 불안정한 발현, 불발과 붕괴를 구분해 관찰하세요."]
static func evaluate(state:Dictionary,element:String,resolution:Dictionary={})->Dictionary:
	var fields={"mana_amount":state.get("mana_amount",0),"cohesion":state.get("cohesion",0),"stability":state.get("stability",60),"form_integrity":state.get("form_integrity",0),"flow_strength":state.get("flow_strength",0),"energy_loss":state.get("energy_loss",0)}
	var text:String
	var branch:="observation"
	if resolution.get("state")=="ready":
		branch="ready_unstable" if resolution.get("risk")=="unstable" else "ready"
		text="발현할 구조는 갖추었으나 흔들림도 크구나. 위험을 감수할지, 균형을 다듬을지는 그대의 몫이다." if branch=="ready_unstable" else "이 구조는 이미 발현할 수 있구나. 원한다면 순서를 바꾸어 성질의 차이를 더 살펴보아라."
	elif fields.stability<40:text="윤곽이 무너지려 하는구나. 힘을 더하기 전에 흔들림을 가라앉혀 보렴."
	elif fields.mana_amount<=0:text="먼저 관측할 마나가 필요하구나. 변화 하나를 만들고 전후를 비교해 보렴."
	elif fields.cohesion>55 and element in ["FIRE","WATER","WOOD"]:text="지나치게 조밀하게 붙잡고 있구나. 이 성향에서는 밀도의 대가로 손실과 흔들림을 살펴야 한단다."
	elif fields.flow_strength<.3 and fields.mana_amount>=15:text="힘은 모였지만 흐름이 머물러 있구나. 힘을 더하기보다 움직임의 성질을 살펴보렴."
	elif fields.form_integrity<20:text="흐름은 보이지만 윤곽은 아직 희미하구나. 무엇을 유지하고 싶은지 생각해 보렴."
	elif fields.energy_loss>3:text="윤곽 밖으로 빛이 새고 있구나. 같은 재료로 손실을 줄이는 순서를 비교해 보렴."
	else:text="윤곽이 유지되는구나. 같은 조작의 순서를 바꾸어 무엇이 강해지고 약해지는지 비교해 보렴."
	return {"text":"[%s의 관점] %s"%[PERSPECTIVES.get(element,"마나 관측"),text],"consulted":fields,"element":element,"branch":branch,"resolution":resolution.duplicate(true)}
