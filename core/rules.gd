class_name Rules
extends RefCounted

## 판단 파이프라인.
##
## 매 틱 대원 하나가 네 축을 **순서대로 통과해 행동 하나를 조립한다.**
##
##   1) SQUAD    아군을 어떻게 참조할지 정한다 (협공 / 분산 / 엄호 / 집결)
##   2) TARGET   누구를 노릴지 고른다
##   3) ENGAGE   지금 싸울지 정한다 (교전 / 회피 / 대기 / 추격 / 방어)
##   4) POSITION 사거리 밖일 때 어디로 갈지 정한다
##   5) 조립     사거리 안이고 태세가 교전이면 공격(회복), 아니면 이동
##
## ── 왜 목록이 아니라 파이프라인인가 ──────────────────────────────────────
## 예전에는 모듈 한 장이 조건과 행동을 다 들고 있었고, 엔진은 목록을 위에서부터
## 훑어 처음 맞는 하나를 실행했다. 그래서 모듈을 장착하는 행위가 "이 대원에게
## 동작 하나를 준다" 가 됐다. 그건 전술이 아니라 매크로 편집이다.
##
## 축을 넷으로 갈라도 대원은 한 틱에 행동 하나만 한다. 표적·위치·교전이 각자
## 답을 내놓으면 셋 중 무엇을 실행할지가 정해져야 한다. 그래서 목록이 아니라
## 조립 라인이다.
##
## ── 축 안에서는 폴스루가 그대로다 ────────────────────────────────────────
## 한 축의 모듈은 위에서부터 읽어 **처음 성립하는 하나**가 이긴다. 조건이 없는
## 모듈 아래는 죽은 칸이다. 플레이어가 이미 배운 규칙("위에 있는 게 먼저다")을
## 버리지 않는다. 달라지는 건 그 목록이 넷으로 갈렸다는 것뿐이다.
##
## ── 축끼리 충돌하면 ──────────────────────────────────────────────────────
##     교전  >  위치  >  표적
## "싸울 것인가" 가 "어디 설 것인가" 를 이기고, 그게 "누구를 칠 것인가" 를
## 이긴다. [교전: 회피] 가 걸리면 [표적: 후열 우선] 이 무엇을 고르든 물러난다.
## 이 한 줄이 없으면 두 축이 충돌할 때마다 임의 판정이 된다.
##
## 표적을 교전보다 **먼저 계산**하는 것은 순서가 아니라 의존성 때문이다.
## [마무리 신호](표적 HP < 30%) 같은 교전 조건이 표적을 알아야 판정된다.
## 우선순위는 조립 단계에서 지켜진다.


## 표적을 참조하는 교전 조건을 위해 파이프라인이 채워 두는 값.
##
## eval_condition 에 인자를 하나 더 다는 대신 여기 둔다. 조건 평가기는
## 검사와 화면 양쪽에서 불리는데, 시그니처를 바꾸면 그 호출부가 전부 깨진다.
static var _ctx_target: Unit = null

## 위협도만 바꾸는 수칙. 행동을 정하지 않으므로 **아래 칸을 가리지 않는다.**
##
## core/shadow.gd 의 같은 목록과 짝이다. 한쪽만 고치면 화면 경고와 실제 동작이
## 어긋난다.
const THREAT_ONLY: Array[String] = ["taunt", "aggressive", "stealth"]

## [광전] 이 붙는 위력 배수. 물러나지 않는 대신 받는 값이다.
## 1.3 은 기본기(70)를 91 로, 평타(100)를 130 으로 올린다 - 한 방이 눈에 띄게
## 커지되 궁극기(150~200)를 넘지는 않는 선이다.
const BERSERK_POWER: float = 1.3


## 발동할 규칙을 고른다.
##
## 반환은 예전 그대로다: { "card_id", "card", "target", "slot", "innate",
## "special", "trace" }. card 는 이제 표에서 꺼낸 것이 아니라 **조립된** 것이다.
## 전투 실행부(battle.gd)는 그 차이를 몰라도 된다.
static func select(unit: Unit, state) -> Dictionary:
	# 궁극기를 슬롯보다 먼저 볼지는 플레이어가 정한다.
	if unit.special_first:
		var early := _try_special(unit, state)
		if not early.is_empty():
			return early

	var trace: Dictionary = {}

	# 1) TARGET - 누구를 쫓는가
	var picked := _pick_target(unit, state, trace)
	var target: Unit = picked.get("target", null)
	# 표적 **모듈**이 골랐는가, 아니면 기본 판단으로 떨어졌는가.
	# 조립 단계에서 "쫓을지" 를 이 값으로 정한다. (_move_by_stand 참조)
	# ── 표적 모듈을 **가지고 있으면** 능동적으로 움직인다 ────────────────
	# picked.has("rule") 만 보면, 조건이 안 걸린 틱에는 원거리가 제자리에
	# 굳는다. [원거리 추적] 은 사거리 안에 적이 있어야 대상을 고르므로, 적이
	# 멀리 있는 동안에는 아무것도 안 걸리고 궁수는 한 걸음도 안 움직였다.
	# 실측으로 30틱 중 이동 0틱이었다.
	#
	# 표적 모듈을 샀다는 것은 "이 대원은 적을 찾아간다" 는 선언이다. 그 선언은
	# 조건이 걸린 틱에만 참일 수 없다.
	var designated := picked.has("rule") or _has_axis(unit, Axes.TARGET)

	# 표적이 정해졌으니 이제 조건 평가기가 그걸 볼 수 있다.
	#
	# 예전에는 이 줄이 위치 축 **뒤에** 있었다. 그래서 [추격 기동](표적 HP<30%)
	# 처럼 표적을 봐야 하는 위치 조건이 항상 null 을 읽어 **한 번도 발동하지
	# 못했다.** 실측 발동 0회. 주석에는 "표적을 먼저 계산한다" 고 적혀 있었는데
	# 정작 코드는 안 그랬다.
	_ctx_target = target

	# 2) POSITION - 어디에 서는가
	var pos := _axis(unit, Axes.POSITION, state, trace)
	var stand := String(pos.get("value", ""))

	# 3) DOCTRINE - 언제 무엇을 하는가
	var doc := _pick_doctrine(unit, state, trace)
	_ctx_target = null
	var stance := String(doc.get("value", ""))
	# 위협도 보정은 매 틱 다시 계산한다. 조건이 풀리면 꺼져야 하기 때문이다.
	unit.threat_mod = _threat_mod(String(doc.get("threat", "")))

	# 궁극기가 "전술 뒤" 면 축을 다 읽은 다음, 기본 판단보다는 먼저 본다.
	if not unit.special_first:
		var late := _try_special(unit, state)
		if not late.is_empty():
			late["trace"] = trace
			return late

	var built := _assemble(unit, state, target, stance, stand, designated)
	if built.is_empty():
		return {}

	built["trace"] = trace
	# slot 은 이제 "어느 축이 이번 행동을 정했는가" 다. 화면이 이걸로 줄을 밝힌다.
	built["slot"] = int(built.get("slot", -1))
	built["innate"] = bool(built.get("innate", true))
	built["special"] = false
	return built


# ── 축 하나를 읽는다 ─────────────────────────────────────────────────────

## 그 축의 모듈을 위에서부터 읽어 처음 성립하는 것을 고른다.
##
## trace 에 축별로 [{ slot, name, hit, why }] 를 남긴다. **건너뛴 항목과 그
## 이유를 같이 남기는 게 핵심이다.** 성립한 것만 보여 주면 플레이어는
## "왜 2번이 안 걸렸지" 를 답할 수 없고, 그러면 자기 교리가 틀린 건지 게임이
## 이상한 건지 구별하지 못한다.
static func _axis(unit: Unit, axis: String, state, trace: Dictionary) -> Dictionary:
	var rows: Array = []
	var out: Dictionary = {}
	var key := String(Axes.PAYLOAD[axis])

	for slot in unit.card_rules.size():
		var rule: Dictionary = unit.card_rules[slot]
		if rule.is_empty() or String(rule.get("axis", "")) != axis:
			continue
		var name := String(rule.get("name", ""))
		if not out.is_empty():
			rows.append({ "slot": slot, "name": name, "hit": false, "why": "위가 성립" })
			continue
		if not eval_condition(unit, String(rule["cond"]), int(rule["cond_arg"]), state):
			rows.append({ "slot": slot, "name": name, "hit": false, "why": "조건 불성립" })
			continue
		rows.append({ "slot": slot, "name": name, "hit": true, "why": "" })
		out = { "value": String(rule.get(key, "")), "rule": rule, "slot": slot }

	trace[axis] = rows
	return out


## 교전 수칙을 읽는다. 다른 축과 달리 결과가 **둘**이다 - 행동과 위협도.
##
## ── 왜 이 축만 다른가 ────────────────────────────────────────────────────
## [전투태세]·[도발]·[은신] 은 행동을 정하지 않는다. 위협도만 바꾼다. 그런데
## 다른 축과 똑같이 "처음 성립한 것이 이긴다" 로 처리하면, 조건이 `항상` 인
## [전투태세] 하나가 아래 칸을 전부 죽인다.
##
## 실제로 방패병에게 [1 전투태세, 2 방어 태세] 를 꽂으면 방어 태세가 영영
## 발동하지 않았고, 화면은 "가려서 발동하지 않는다" 고 경고까지 띄웠다. 둘은
## 애초에 다투는 판단이 아니다 - 하나는 "누가 나를 치게 할까" 고 다른 하나는
## "맞을 때 어떻게 버틸까" 다.
##
## 그래서 위협 수칙은 행동 자리를 차지하지 않는다. 값만 챙기고 아래를 계속
## 읽는다. 위협 수칙끼리는 여전히 위가 이긴다 - 그건 진짜로 다투는 판단이다.
static func _pick_doctrine(unit: Unit, state, trace: Dictionary) -> Dictionary:
	var rows: Array = []
	var out: Dictionary = {}
	var threat: String = ""

	for slot in unit.card_rules.size():
		var rule: Dictionary = unit.card_rules[slot]
		if rule.is_empty() or String(rule.get("axis", "")) != Axes.DOCTRINE:
			continue
		var name := String(rule.get("name", ""))
		var value := String(rule.get("stance", ""))

		if not eval_condition(unit, String(rule["cond"]), int(rule["cond_arg"]), state):
			rows.append({ "slot": slot, "name": name, "hit": false, "why": "조건 불성립" })
			continue

		if THREAT_ONLY.has(value):
			if threat == "":
				threat = value
				rows.append({ "slot": slot, "name": name, "hit": true, "why": "위협도" })
			else:
				rows.append({ "slot": slot, "name": name, "hit": false,
					"why": "위 위협 수칙이 성립" })
			continue

		if not out.is_empty():
			rows.append({ "slot": slot, "name": name, "hit": false, "why": "위가 성립" })
			continue
		rows.append({ "slot": slot, "name": name, "hit": true, "why": "" })
		out = { "value": value, "rule": rule, "slot": slot }

	trace[Axes.DOCTRINE] = rows
	out["threat"] = threat
	return out


## 그 축의 모듈을 하나라도 꽂았는가. 조건이 걸렸는지는 안 본다.
static func _has_axis(unit: Unit, axis: String) -> bool:
	for r in unit.card_rules:
		if String((r as Dictionary).get("axis", "")) == axis:
			return true
	return false


# ── 2) 표적 ──────────────────────────────────────────────────────────────

## 표적 축을 읽어 대상을 고른다. 아무것도 안 걸리면 가장 가까운 적.
##
## 협력 축이 여기에 개입한다. [협공] 은 아군이 이미 노리는 적을 그대로 쓰고,
## [분산] 은 그 적을 후보에서 뺀다. 표적 축보다 **먼저** 걸리는 이유는,
## 협력이 "부대 차원의 결정" 이고 표적은 "개인의 취향" 이기 때문이다.
static func _pick_target(unit: Unit, state, trace: Dictionary) -> Dictionary:
	var rows: Array = []
	var won: Dictionary = {}

	for slot in unit.card_rules.size():
		var rule: Dictionary = unit.card_rules[slot]
		if rule.is_empty() or String(rule.get("axis", "")) != Axes.TARGET:
			continue
		var name := String(rule.get("name", ""))
		if not won.is_empty():
			rows.append({ "slot": slot, "name": name, "hit": false, "why": "위가 성립" })
			continue
		if not eval_condition(unit, String(rule["cond"]), int(rule["cond_arg"]), state):
			rows.append({ "slot": slot, "name": name, "hit": false, "why": "조건 불성립" })
			continue
		var t := resolve_target(unit, String(rule.get("pick", "nearest_enemy")), state, "attack")
		if t == null:
			rows.append({ "slot": slot, "name": name, "hit": false, "why": "대상 없음" })
			continue
		rows.append({ "slot": slot, "name": name, "hit": true, "why": "" })
		if won.is_empty():
			won = { "target": t, "rule": rule, "slot": slot }

	trace[Axes.TARGET] = rows
	if not won.is_empty():
		return won
	# 기본값. 악사는 아군을 살리는 게 기본이므로 표적도 아군 쪽이다.
	var ai := Innates.base_ai(unit.type_id)
	if String(ai["act"]) == "heal":
		return { "target": resolve_target(unit, "lowest_hp_ally", state, "heal") }
	# 표적 모듈이 없으면 **위협도가 가장 높은 적**을 친다. 예전 기본값은 "가장
	# 가까운 적" 이었는데 그러면 도발도 은신도 아무 의미가 없다. 위협 관리가
	# 성립하려면 기본 판단이 위협을 보고 있어야 한다.
	return { "target": resolve_target(unit, "highest_threat_enemy", state, "attack") }


## 아군이 이번 판에 노리고 있는 적. 없으면 null.
## 아군이 지금 붙어 있는 적. 없으면 null.
##
## Battle 이 이미 팀별로 들고 있는 값을 그대로 쓴다. 자기가 정한 대상은
## 제외되므로 혼자서 조건이 참이 되는 일이 없다 - 협력 축이 성립하는 근거다.
static func _ally_focus(unit: Unit, state) -> Unit:
	return state.focus_target_for(unit)


# ── 5) 조립 ──────────────────────────────────────────────────────────────

## 표적·태세·자리를 받아 이번 틱에 실제로 할 행동 하나를 만든다.
##
## 여기가 `교전 > 위치 > 표적` 우선순위가 실제로 지켜지는 곳이다.
static func _assemble(unit: Unit, state, target: Unit, stance: String,
		stand: String, designated: bool = false) -> Dictionary:
	var ai := Innates.base_ai(unit.type_id)
	var act_kind := String(ai["act"])
	var power := int(ai["power"])
	# 강행군은 자리가 아니라 **이동력 보정**이다. 다른 자리 판단과 같이 걸린다.
	var bonus := 1 if stand == "march" else 0

	# ── 교전이 위치와 표적을 이긴다 ──────────────────────────────────────
	var near_d: int = _nearest_distance(unit, state)
	match stance:
		"wait":
			return _rule(unit, "대기", "hold", unit, 0, 0)
		"defend":
			return _rule(unit, "방어", "defend", unit, 0, 0)
		"ambush":
			# ── 잠복 ─────────────────────────────────────────────────────
			#   3틱간 멈춘다. 그동안 맞지도 때리지도 움직이지도 않는다.
			#   풀린 뒤 3틱 안에 때리면 그 한 방이 세진다.
			#
			# 전투당 한 번이다. 조건이 참인 동안 계속 숨었다 나왔다 하면 그
			# 대원은 판이 끝날 때까지 아무 일도 안 한다.
			if not unit.ambush_done:
				unit.ambush_ticks = Specials.AMBUSH_TICKS
				return _rule(unit, "잠복", "hold", unit, 0, 0)
		"avoid_near":
			if near_d <= 1:
				return _retreat(unit, state, bonus)
		"avoid_mid":
			if near_d <= 2:
				return _retreat(unit, state, bonus)
		"avoid_boost":
			return _retreat(unit, state, bonus + 1)

		# ── 붙어서 끝낸다 ────────────────────────────────────────────────
		# 능력치를 안 준다. 하는 일은 둘이다 - 물러나는 판단을 이 틱에만 끄고,
		# 한 칸 더 간다.
		#
		# "안 물러난다" 만으로는 실측에서 -4 였다. 원거리 대원이 카이팅을
		# 잃기만 하고 얻는 게 없었기 때문이다. 이 축이 값을 하려면 **끝내는
		# 속도**로 갚아야 한다 - 한 칸을 더 가는 것은 능력치가 아니라 판단의
		# 결과라 강화가 아니다.
		"close_in":
			if target != null and Grid.manhattan(unit.pos, target.pos) > unit.atk_range:
				return _approach(unit, state, target, bonus + 1, "압박")


	# 표적이 없어도 자리는 지킨다.
	#
	# 예전에는 여기서 빈 손으로 돌아갔는데, 그러면 전투 로그에 "행동 없음" 만
	# 남고 그 대원이 왜 멈췄는지 아무 데도 안 적힌다. 실제로 아군이 전부
	# 만피인 악사가 통째로 사라진 것처럼 보였다.
	if target == null:
		# ── 표적이 없어도 진형은 유지한다 ────────────────────────────────
		# 여기서 곧장 제자리로 돌아가고 있었다. 그런데 자리 모듈 중 상당수는
		# **적이 아니라 아군을 기준으로** 선다. [방패 뒤]·[방패 추종]·[밀집]
		# 은 표적이 있든 없든 할 일이 있다.
		#
		# 악사가 대표적인 피해자였다. 기본 행동이 회복이라 아군이 전부 만피인
		# 동안에는 표적이 없고, 그래서 [방패 뒤] 를 꽂아도 방패병이 앞으로
		# 나가는 걸 그냥 지켜보고 있었다. 누가 다칠 때까지는 진형이 아예
		# 작동하지 않은 것이다.
		var formed := _move_by_ally(unit, state, stand, bonus)
		if not formed.is_empty():
			return formed
		return _rule(unit, "대상 없음", "hold", unit, 0, 0)

	# ── 사거리 안이면 일한다 ─────────────────────────────────────────────
	# ── 회복형에게 표적 모듈을 꽂으면 그 적을 친다 ───────────────────────
	# 악사의 기본 행동은 회복이라, 표적 축이 **적**을 골라 오면 예전에는 갈 곳이
	# 없어서 그냥 제자리였다. [근접 추적] 을 꽂아도 판이 끝날 때까지 한 걸음도
	# 안 움직였다 - 산 모듈이 아무 일도 안 하는 것이고, 그건 버그다.
	#
	# 표적 모듈을 꽂는 것은 "이 대원에게 노릴 대상을 지정한다" 는 명시적인
	# 선택이다. 그 선택이 회복형에게만 무시될 이유가 없다. 악사도 사거리 2에
	# 공격력이 있다 - 약하지만 없는 것이 아니다.
	if act_kind == "heal" and target.team != unit.team:
		act_kind = "attack"
		power = 100

	# ── [광전] 은 값을 치른 만큼 받아야 한다 ─────────────────────────────
	# 원래는 "물러나지 않는다" 뿐이었다. 그런데 물러나지 않는 것은 **손해**다 -
	# 맞을 자리에 계속 서 있겠다는 뜻이니까. 손해만 주는 모듈은 아무도 안 산다.
	#
	# 실측으로 5판 × 3명에서 발동 14회, 행동 변화 15회. 표의 51개 중 꼴찌였고
	# 사실상 죽어 있었다.
	#
	# 물러나는 대신 세게 친다. 그래야 "빠질까, 붙어서 끝낼까" 가 선택이 된다.
	if stance == "engage":
		power = int(round(float(power) * BERSERK_POWER))

	var dist: int = Grid.manhattan(unit.pos, target.pos)
	if dist <= unit.atk_range:
		if act_kind == "heal":
			if target.team == unit.team and target.missing_hp() > 0:
				return _rule(unit, "회복", "heal", target, power, 0)
			# 살릴 사람이 없으면 자리를 지킨다. 악사는 밀고 들어가는 직업이 아니다.
			return _rule(unit, "대기", "hold", unit, 0, 0)
		elif state.has_shot(unit, target):
			# 원거리는 적이 코앞이면 한 칸 물러나며 쏠 자리를 만든다.
			# 이게 기본 AI 의 flee_within 이다. 태세가 추격이면 안 물러난다.
			var flee := int(ai["flee_within"])
			# [광전]·[압박]은 물러나지 않는다. 추격 자세도 마찬가지다.
			if stance == "engage" or stance == "close_in" or stand == "chase":
				flee = 0
			if flee > 0 and dist <= flee:
				var near := resolve_target(unit, "nearest_enemy", state, "")
				if near != null and state.plan_move(unit, near, false, bonus) != unit.pos:
					return _rule(unit, "간격 확보", "move_away", near, 0, bonus)
			return _rule(unit, "공격", "attack", target, power, 0)

	# ── 사거리 밖이면 위치 축이 어디로 갈지 정한다 ───────────────────────
	return _move_by_stand(unit, state, target, stand, bonus, designated)


## 아군을 기준으로 서는 자리들. 표적이 있든 없든 판단이 같으므로 따로 뗀다.
## 아무 할 일이 없으면 빈 사전을 돌려준다.
static func _move_by_ally(unit: Unit, state, stand: String, bonus: int) -> Dictionary:
	# ── 협력이 위치 모듈보다 먼저 걸린다 ─────────────────────────────────
	# 부대 차원의 결정이 개인의 자리 취향을 이긴다. [방패 추종] 을 넣어 놓고
	# 혼자 딴 데 서면 그건 협력이 아니다.
	if stand in ["follow_guard", "follow_lead", "protect_support", "protect_ranged",
			"escort", "rally"]:
		var mate := _coop_anchor(unit, state, stand)
		if mate != null and Grid.manhattan(unit.pos, mate.pos) > 1:
			# 아군에게 갈 때는 1칸 옆까지 간다. 사거리로 재면 궁수가 3칸 밖에서
			# "다 왔다" 고 판단해 협력 모듈이 아무 일도 안 한다.
			if state.plan_move(unit, mate, true, bonus, 1) != unit.pos:
				return _rule(unit, "동행", "move_to_ally", mate, 0, bonus)
		return {}

	if stand == "behind_guard":
		var guard := _guard_ally(unit, state)
		if guard == null:
			return {}
		if _is_ahead_of(unit, guard) 				and state.plan_move(unit, guard, true, bonus, 1) != unit.pos:
			return _rule(unit, "방패 뒤", "move_to_ally", guard, 0, bonus)
		if Grid.manhattan(unit.pos, guard.pos) > 1 				and state.plan_move(unit, guard, true, bonus, 1) != unit.pos:
			return _rule(unit, "방패 뒤 따라감", "move_to_ally", guard, 0, bonus)
		return {}

	if stand == "cluster":
		var near := _nearest_ally(unit, state)
		if near != null and Grid.manhattan(unit.pos, near.pos) > 1 				and state.plan_move(unit, near, true, bonus, 1) != unit.pos:
			return _rule(unit, "밀집", "move_to_ally", near, 0, bonus)
		return {}

	return {}


static func _move_by_stand(unit: Unit, state, target: Unit,
		stand: String, bonus: int, designated: bool = false) -> Dictionary:
	var ai := Innates.base_ai(unit.type_id)

	# 위치 모듈이 있으면 그쪽이 이긴다 - 플레이어가 명시적으로 자리를 지정한
	# 것이므로, 협력이 그걸 덮으면 지정이 무의미해진다.
	if stand in ["follow_guard", "follow_lead", "protect_support", "protect_ranged",
			"escort", "rally"]:
		var coop := _move_by_ally(unit, state, stand, bonus)
		if not coop.is_empty():
			return coop

	match stand:
		"keep_range":
			# 최대 사거리를 유지한다. 너무 가까우면 물러나고 멀면 붙는다.
			var d: int = Grid.manhattan(unit.pos, target.pos)
			if d < unit.atk_range and state.plan_move(unit, target, false, bonus) != unit.pos:
				return _rule(unit, "간격 유지", "move_away", target, 0, bonus)
			return _approach(unit, state, target, bonus, "거리 좁힘")

		"behind_guard":
			# 방패병·전사보다 앞에 서 있으면 그 뒤로 돌아간다.
			var guard := _guard_ally(unit, state)
			if guard != null:
				if _is_ahead_of(unit, guard):
					if state.plan_move(unit, guard, true, bonus, 1) != unit.pos:
						return _rule(unit, "방패 뒤", "move_to_ally", guard, 0, bonus)
				# ── 뒤에 있다. 이제는 붙박이가 아니라 따라간다 ────────────────
				# 예전에는 여기서 무조건 제자리였다. 그러면 방패병이 전진하는 동안
				# 원거리 대원이 뒤에 남아 사거리 밖에서 아무것도 안 하고, 판이
				# 끝날 때까지 한 발도 못 쏘는 일이 실제로 났다. "뒤에 선다" 가
				# "일을 안 한다" 가 되면 그건 모듈이 아니라 벌칙이다.
				#
				# 그래서 **앞지르지 않는 선에서** 표적 쪽으로 붙는다. 한 칸 갔을 때
				# 방패병보다 앞이 되면 안 간다 - 그 한 줄이 이 모듈의 전부다.
				var step: Vector2i = state.plan_move(unit, target, true, bonus)
				if step != unit.pos and not _cell_ahead_of(unit, step, guard):
					return _rule(unit, "방패 뒤 전진", "move_toward", target, 0, bonus)
				# 앞지르게 된다. 대신 방패병 옆으로 붙어 간격이 벌어지는 걸 막는다.
				if Grid.manhattan(unit.pos, guard.pos) > 1 						and state.plan_move(unit, guard, true, bonus, 1) != unit.pos:
					return _rule(unit, "방패 뒤 따라감", "move_to_ally", guard, 0, bonus)
				return _rule(unit, "방패 뒤 유지", "hold", unit, 0, 0)
			return _approach(unit, state, target, bonus, "전진")

		"cluster":
			# 아군과 떨어져 있으면 붙는다.
			var mate := _nearest_ally(unit, state)
			if mate != null and Grid.manhattan(unit.pos, mate.pos) > 1:
				if state.plan_move(unit, mate, true, bonus, 1) != unit.pos:
					return _rule(unit, "밀집", "move_to_ally", mate, 0, bonus)
			return _approach(unit, state, target, bonus, "전진")

		"frontline", "flank", "march":
			return _approach(unit, state, target, bonus, "전진")

	# ── 표적 모듈을 꽂았으면 쫓는다 ──────────────────────────────────────
	# 표적 카드 열세 장이 전부 "**쫓는다**" 라고 적혀 있는데 실제로는 안 쫓았다.
	# 원거리는 기본 판단이 제자리라, 표적만 꽂은 궁수·악사가 대상을 정해 놓고
	# 판이 끝날 때까지 한 걸음도 안 움직였다. 카드가 자기 문장과 모순이었다.
	#
	# 표적을 지정하는 것은 "저 녀석이다" 라는 명시적인 선택이다. 그 선택에
	# 다리를 안 달아 주면 산 모듈이 아무 일도 안 하는 것이고, 그건 어떤 설계
	# 원칙으로도 못 덮는다.
	#
	# ── 그래도 위치 축은 안 죽는다 ───────────────────────────────────────
	# 쫓는다는 것은 **사거리 안까지만** 간다는 뜻이다(plan_move 가 atk_range 에서
	# 멈춘다). 궁수는 3칸, 총사는 2칸에서 선다 - 근접으로 걸어 들어가지 않는다.
	# 어디에 · 어떻게 설지는 여전히 위치 축의 몫이다:
	#   거리 유지  최대 사거리를 지킨다      방패 뒤  아군 뒤에 선다
	#   밀집       뭉친다                    강행군   한 칸 더 간다
	#
	# 모듈이 하나도 없으면 예전 그대로 원거리는 제자리다. "모듈을 사야 대원이
	# 자기 뜻대로 움직인다" 는 경제의 근거는 그대로 남는다.
	if String(ai["stand"]) == "advance" or stand == "chase" or designated:
		return _approach(unit, state, target, bonus, "전진")
	return _rule(unit, "제자리", "hold", target, 0, 0)


static func _approach(unit: Unit, state, target: Unit, bonus: int, name: String) -> Dictionary:
	if state.plan_move(unit, target, true, bonus) == unit.pos:
		return _rule(unit, "정체", "hold", target, 0, 0)
	return _rule(unit, name, "move_toward", target, 0, bonus)


## 조립된 규칙 하나. 표에서 꺼낸 모듈과 같은 모양이라 실행부가 구분하지 않는다.
static func _rule(unit: Unit, name: String, act: String, target: Unit,
		power: int, move_bonus: int) -> Dictionary:
	var card := { "name": name, "act": act, "text": name, "cond": "always",
		"cond_arg": 0, "target": "", "move_bonus": move_bonus }
	if power > 0:
		card["power"] = power
	return { "card": card, "target": target, "card_id": "", "slot": -1,
		"innate": true, "special": false }


## ── 이 대원이 누구를 기준으로 서는가 ────────────────────────────────────
## 행동 순서를 정하는 데 쓴다. 따라다니는 쪽은 따라다닐 대상이 움직인 **뒤에**
## 판단해야 한다. (core/battle.gd 의 act_order 주석 참조)
##
## 실제 판단과 같은 함수를 쓰되, 카드가 걸릴지 말지는 여기서 안 따진다.
## 순서만 정하는 일이라 대충 잡아도 손해가 없고, 정확히 맞추려면 판단을 두 번
## 하게 된다.
const FOLLOW_STANDS: Array[String] = [
	"follow_guard", "follow_lead", "protect_support", "protect_ranged",
	"escort", "rally", "behind_guard",
]


static func follow_anchor(unit: Unit, state) -> Unit:
	# 장착한 위치 모듈 중 따라다니는 것이 있는가.
	for cid in unit.cards:
		var c: Dictionary = Cards.TABLE.get(cid, {})
		if String(c.get("axis", "")) != Axes.POSITION:
			continue
		var st := String(c.get("stand", ""))
		if not FOLLOW_STANDS.has(st):
			continue
		var mate: Unit = _guard_ally(unit, state) if st == "behind_guard" \
			else _coop_anchor(unit, state, st)
		if mate != null and mate.alive:
			return mate
	return null


## 협력 축이 기준으로 삼는 아군. 없으면 null.
##
## 표적이 "누구를 치는가" 라면 이쪽은 "누구 옆에 있는가" 다. 같은 표적 모듈을
## 쓰는 두 대원도 이 기준이 다르면 완전히 다르게 논다.
static func _coop_anchor(unit: Unit, state, coop: String) -> Unit:
	match coop:
		"escort":
			# HP 가 가장 낮은 아군. 지금 가장 위험한 쪽이다.
			return resolve_target(unit, "lowest_hp_other_ally", state, "")
		"follow_guard":
			return _guard_ally(unit, state)
		"protect_support":
			for a in state.living_allies_of(unit):
				if a.index != unit.index and String(Innates.base_ai(a.type_id)["act"]) == "heal":
					return a
			return null

		# 사거리가 긴 아군 곁. 회복형만 지키던 [지원 엄호] 로는 궁수·총사가
		# 홀로 남는 판을 못 막는다. 뒤에 서는 것은 악사만이 아니다.
		"protect_ranged":
			var far_ally: Unit = null
			for a in state.living_allies_of(unit):
				if a.index == unit.index or a.atk_range < 2:
					continue
				if far_ally == null or a.atk_range > far_ally.atk_range:
					far_ally = a
			return far_ally
		"rally":
			# 아군 무리의 한가운데. 아군까지 거리 합이 가장 작은 아군을 기준으로
			# 삼는다. 칸을 직접 고르지 않는 이유는 이동이 아군 기준으로만
			# 계획되기 때문이다(plan_move 는 유닛을 받는다).
			var center: Unit = null
			var best_sum: int = 1 << 30
			for a in state.living_allies_of(unit):
				if a.index == unit.index:
					continue
				var sum := 0
				for b in state.living_allies_of(unit):
					sum += Grid.manhattan(a.pos, b.pos)
				if sum < best_sum:
					best_sum = sum
					center = a
			return center

		"follow_lead":
			# 적진 쪽으로 가장 나가 있는 아군. 진영마다 "앞" 이 반대다.
			var best: Unit = null
			for a in state.living_allies_of(unit):
				if a.index == unit.index:
					continue
				if best == null or _is_ahead_of(a, best):
					best = a
			return best
	return null


## 태세가 붙이는 위협도 보정.
static func _threat_mod(stance: String) -> int:
	match stance:
		"taunt":
			return Threat.TAUNT
		"aggressive":
			return Threat.AGGRESSIVE
		"stealth":
			return Threat.STEALTH
	return 0


## 물러난다. 갈 곳이 없으면 버틴다 - 실패했다고 공격으로 넘어가면 지시가 뒤집힌다.
static func _retreat(unit: Unit, state, bonus: int) -> Dictionary:
	var away := resolve_target(unit, "nearest_enemy", state, "")
	if away != null and state.plan_move(unit, away, false, bonus) != unit.pos:
		return _rule(unit, "후퇴", "move_away", away, 0, bonus)
	return _rule(unit, "퇴로 없음", "hold", unit, 0, 0)


static func _guard_ally(unit: Unit, state) -> Unit:
	for a in state.living_allies_of(unit):
		if a.index != unit.index and (a.type_id == "shieldman" or a.type_id == "warrior"):
			return a
	return null


static func _nearest_ally(unit: Unit, state) -> Unit:
	var best: Unit = null
	var best_d: int = Grid.UNREACHABLE
	for a in state.living_allies_of(unit):
		if a.index == unit.index:
			continue
		var d: int = Grid.manhattan(unit.pos, a.pos)
		if d < best_d:
			best_d = d
			best = a
	return best


## 적진 쪽으로 더 나가 있는가. 진영마다 "앞" 의 방향이 반대다.
## 그 **칸**이 other 보다 앞인가. 실제로 밟기 전에 물어보려고 좌표를 받는다.
static func _cell_ahead_of(unit: Unit, cell: Vector2i, other: Unit) -> bool:
	if unit.team == Unit.TEAM_PLAYER:
		return cell.x > other.pos.x
	return cell.x < other.pos.x


static func _is_ahead_of(unit: Unit, other: Unit) -> bool:
	if unit.team == Unit.TEAM_PLAYER:
		return unit.pos.x > other.pos.x
	return unit.pos.x < other.pos.x


static func _try_special(unit: Unit, state) -> Dictionary:
	if not unit.special_ready():
		return {}
	var rule: Dictionary = Specials.TABLE[unit.special]
	if not eval_condition(unit, String(rule["cond"]), int(rule["cond_arg"]), state):
		return {}
	var target := resolve_target(unit, String(rule["target"]), state, String(rule["act"]))
	if not is_viable(unit, rule, target, state):
		return {}
	return { "card": rule, "target": target, "card_id": unit.special,
		"slot": -2, "innate": false, "special": true, "trace": {} }


# ── 조건 ─────────────────────────────────────────────────────────────────

static func eval_condition(unit: Unit, cond: String, arg: int, state) -> bool:
	match cond:
		"always":
			return true

		"enemy_in_range":
			return _nearest_distance(unit, state) <= unit.atk_range

		"enemy_out_of_range":
			var d: int = _nearest_distance(unit, state)
			return d != Grid.UNREACHABLE and d > unit.atk_range

		# ── 적이 사거리 밖이고, 다가오는 중 ──────────────────────────────
		# [사거리 대기] 가 쓴다. 그냥 "사거리 밖" 으로 두면 **영원히 기다린다.**
		# 상대가 고정 포탑이거나 같이 거리를 두는 편성이면 양쪽 다 안 움직이고,
		# 정체 판정이 걸려 기다린 쪽이 진다. 기다림은 상대가 오고 있을 때만
		# 뜻이 있으므로, 안 오면 놓아 준다.
		#
		# 첫 틱은 이전 거리를 모른다. 그때는 기다리는 쪽으로 둔다 - 개전 직후
		# 진형을 갖추는 것이 이 모듈의 본래 용도다.
		"enemy_out_of_range_closing":
			var od: int = _nearest_distance(unit, state)
			if od == Grid.UNREACHABLE or od <= unit.atk_range:
				return false
			return unit.prev_near_dist < 0 or od < unit.prev_near_dist

		"enemy_within":
			return _nearest_distance(unit, state) <= arg

		"self_hp_below":
			return unit.hp_percent_below(arg)

		"was_hit_last_tick":
			return unit.was_hit

		"enemies_adjacent_at_least":
			var n: int = 0
			for e in state.living_enemies_of(unit):
				if Grid.manhattan(unit.pos, e.pos) <= 1:
					n += 1
			return n >= arg

		"ally_hp_below":
			for a in state.living_allies_of(unit):
				if a.hp_percent_below(arg):
					return true
			return false

		"other_ally_hp_below":
			# 자기 자신은 뺀다. [최후의 수호] 는 남을 지키러 가는 궁극기라
			# 자기가 다쳤다고 발동하면 제자리에서 방어만 하는 잉여 행동이 된다.
			for a in state.living_allies_of(unit):
				if a.index != unit.index and a.hp_percent_below(arg):
					return true
			return false

		"ally_engaged":
			# 아군이 붙어 있는 적이 있는가. [협공] 이 읽는다.
			# 내가 정한 대상은 제외한다 - 안 그러면 혼자서도 참이 되어
			# "같은 적을 계속 때린다" 가 되고, 조율 카드가 아니라 그냥 교전이 된다.
			return state.focus_target_for(unit) != null

		"killed_last_tick":
			return unit.killed_last_tick

		"team_killed_last_tick":
			# [광전사] 가 읽는다. 본인 처치로 좁히면 거의 안 터진다 -
			# 한 유닛이 직접 막타를 치는 일 자체가 드물기 때문이다. (cards.gd 주석)
			return state.team_killed_last_tick(unit.team)

		"kept_distance_for":
			# [집중사격] 전용. "적과 2칸 이상을 arg 틱 연속 유지" 를 뜻한다.
			# 거리 판정 자체는 Battle 이 매 틱 far_streak 에 누적해 둔다 -
			# 조건은 과거를 봐야 하는데 규칙은 현재밖에 못 보기 때문이다.
			return unit.far_streak >= arg

		"tick_above":
			# 장기전 전용. 이 게임에서 세 번째로 흔한 결말이 타임아웃(16.7%)인데,
			# 그 원인은 양쪽이 서로 카이팅하며 영영 안 붙는 것이다. 그런데 시간
			# 조건이 `tick_below`(개전) 하나뿐이라 **후반에 태세를 바꾸는 수단이
			# 어휘에 아예 없었다.** 이게 그 자리다.
			return state.tick > arg

		"ally_died_last_tick":
			# 아군을 잃었을 때. team_killed_last_tick(우리가 죽였다)의 거울이다.
			# 유리할 때와 불리할 때가 같은 규칙으로 돌아가면 전투에 국면이 없다.
			return state.team_lost_last_tick(unit.team)

		"tick_below":
			# 개전 직후에만 발동하는 규칙용. state.tick 은 1부터 센다.
			return state.tick < arg

		"enemy_special_ready":
			# 적 중에 궁극기가 준비된 자가 있는가. [선제 차단] 이 이걸 본다.
			for e in state.living_enemies_of(unit):
				if e.special_ready():
					return true
			return false

		"target_hp_below":
			# 지금 노리고 있는 표적의 HP. 파이프라인이 _ctx_target 을 채워 준다.
			# 표적이 아직 안 정해진 경로에서 불리면 성립하지 않는다.
			return _ctx_target != null and _ctx_target.hp_percent_below(arg)

		# ── 여기서부터: 판을 읽는 조건들 ─────────────────────────────────
		# 교전 축이 약한 이유는 하는 일이 전부 "멈춘다/물러난다/막는다" 여서
		# 딜을 안 넣기 때문이다(TODO.md 측정 참조). 그렇다고 교전에 능력치
		# 보상을 붙이면 그건 전술이 아니라 강화가 된다.
		#
		# 대신 **볼 수 있는 것**을 늘린다. 지금 이 축이 읽는 것은 자기 HP·
		# 거리·틱뿐이라, "판이 어떻게 돌아가는가" 를 조건으로 쓸 수가 없다.
		# 조건이 늘면 같은 행동(추격·집중·방어)도 언제 하느냐가 달라진다.

		"target_hp_above":
			# 표적이 아직 멀쩡한가. target_hp_below 의 거울이다.
			return _ctx_target != null and not _ctx_target.hp_percent_below(arg)

		"enemies_left_at_most":
			# 적이 몇 남았는가. 마지막 하나를 다 같이 끝내는 판단이 여기서 나온다.
			return state.living_enemies_of(unit).size() <= arg

		"allies_left_at_most":
			# 우리가 몇 남았는가. 자기 자신을 포함해서 센다 - "혼자 남았다" 가
			# 1 로 읽혀야 대본을 쓸 때 헷갈리지 않는다.
			return state.living_allies_of(unit).size() <= arg

		"in_home_zone":
			# 제 진영 안에 있는가. 좌표를 직접 조건으로 쓰는 유일한 자리다.
			#
			# 진영은 x 로 가른다 - 아군은 x<=2, 적은 x>=5 에서 시작한다.
			# 격자 한가운데(x 3~4)는 어느 쪽 진영도 아니다.
			if unit.team == Unit.TEAM_PLAYER:
				return unit.pos.x <= 2
			return unit.pos.x >= 5

		"never":
			# 패시브 궁극기의 자리 표시. 규칙 엔진은 이걸 절대 고르지 않는다.
			return false

	push_error("Rules: 알 수 없는 조건 '%s'" % cond)
	return false


# ── 대상 선택 ────────────────────────────────────────────────────────────
# 모든 동점은 unit.index 오름차순으로 끊는다. state 의 리스트가 이미 index 순이므로
# 엄격한 부등호(<, >)만 쓰면 자동으로 먼저 나온 쪽이 이긴다.

## act 를 받는 이유: 공격 계열은 차폐를 통과한 적만 후보로 삼아야 한다.
## 그러지 않으면 "가장 가까운 적" 이 벽 뒤에 있을 때 조준했다가 실행 불가로
## 폴스루해 버려서, 쏠 수 있는 적이 있는데도 궁수가 아무것도 안 한다.
static func resolve_target(unit: Unit, target_kind: String, state, act: String = "") -> Unit:
	# point_blank 는 1칸이라 사선이 막힐 수가 없지만, 대상 후보를 공격 계열과
	# 똑같이 걸러 두어야 "때릴 수 없는 적" 을 조준하고 폴스루하는 일이 없다.
	var shooting := act == "attack" or act == "point_blank"
	var enemies: Array = state.shootable_enemies_of(unit) if shooting 		else state.living_enemies_of(unit)

	match target_kind:
		"self":
			return unit

		"nearest_enemy":
			var best: Unit = null
			var best_d: int = Grid.UNREACHABLE
			for e in enemies:
				var d: int = Grid.manhattan(unit.pos, e.pos)
				if d < best_d:
					best_d = d
					best = e
			return best

		"farthest_enemy":
			var best: Unit = null
			var best_d: int = -1
			for e in enemies:
				var d: int = Grid.manhattan(unit.pos, e.pos)
				if d > best_d:
					best_d = d
					best = e
			return best

		"locked_backline_enemy":
			# 교전 시작 시점의 가장 깊은 적을 **끝까지** 쫓는다.
			#
			# 매 틱 다시 고르면 뒤엣놈이 앞으로 나오는 순간 표적이 바뀌어,
			# "후열을 끊으러 간다" 가 "그때그때 제일 뒤를 본다" 가 된다.
			# 한 번 정한 목표를 밀고 들어가는 것이 이 모듈의 성격이다.
			if unit.locked_target != null and unit.locked_target.alive 					and unit.locked_target.team != unit.team:
				return unit.locked_target
			var lb := resolve_target(unit, "backline_enemy", state, act)
			unit.locked_target = lb
			return lb

		"backline_enemy":
			# 제 진영 **깊숙이** 있는 적. "가장 먼 적" 과 다르다.
			#
			# farthest_enemy 는 맨해튼 거리로 고르는데, (1,2)에서 방패병(5,1)·
			# 방패병(5,3)·악사(6,2)가 전부 거리 5로 동점이 된다. index 로 끊기면
			# 전열 방패병이 뽑혀서, 후열을 찢으라는 궁극기가 앞줄을 친다.
			# 실제로 [비영천참] 이 그 상태였다.
			#
			# 깊이는 x 로 잰다. 플레이어는 왼쪽(x 작음), 적은 오른쪽(x 큼)에서
			# 시작하므로 상대 진영 기준으로 안쪽일수록 x 가 크다.
			# 동점이면 HP 가 낮은 쪽 - 후열에서 제일 무른 표적이 목표다.
			var deep: Unit = null
			for e in enemies:
				if deep == null:
					deep = e
					continue
				if unit.team == Unit.TEAM_PLAYER:
					if e.pos.x > deep.pos.x or (e.pos.x == deep.pos.x and e.hp < deep.hp):
						deep = e
				else:
					if e.pos.x < deep.pos.x or (e.pos.x == deep.pos.x and e.hp < deep.hp):
						deep = e
			return deep

		# 지금 남은 HP 가 아니라 **원래 그릇이 작은** 적. 깎였는지와 무관하므로
		# 전투 내내 같은 대상을 고른다 - 추격 자폭체가 이걸로 한 명만 문다.
		# ── 개전 시 가장 가까운 적을 끝까지 ──────────────────────────────
		# [후열 침투] 의 반대다. 한 번 문 것을 놓지 않는 것이 요점이라, 매 틱
		# 다시 고르는 [근접 추적] 과는 완전히 다른 물건이다. 전열이 흩어지든
		# 새 적이 붙든 처음 정한 하나를 끝낸다.
		"locked_frontline_enemy":
			if unit.locked_target != null and unit.locked_target.alive 					and unit.locked_target.team != unit.team:
				return unit.locked_target
			var fb: Unit = null
			var fb_d: int = Grid.UNREACHABLE
			for e in enemies:
				var d3: int = Grid.manhattan(unit.pos, e.pos)
				if d3 < fb_d:
					fb_d = d3
					fb = e
			unit.locked_target = fb
			return fb

		# ── 잠복한 적 ────────────────────────────────────────────────────
		# 숨은 적은 living_enemies_of 에서 아예 빠지므로 다른 어떤 모듈로도
		# 고를 수 없다. 이 모듈만 그 목록을 따로 본다 - 잠복에 대한 답이
		# 판 위에 하나는 있어야 한다.
		"ambushing_enemy":
			var hidden: Unit = null
			for e in state.units:
				if e.alive and e.team != unit.team and e.ambush_ticks > 0:
					if hidden == null or Grid.manhattan(unit.pos, e.pos) 							< Grid.manhattan(unit.pos, hidden.pos):
						hidden = e
			return hidden

		"lowest_max_hp_enemy":
			var frail: Unit = null
			for e in enemies:
				if frail == null or e.max_hp < frail.max_hp:
					frail = e
			return frail

		"lowest_hp_enemy":
			var best: Unit = null
			for e in enemies:
				if best == null or e.hp < best.hp:
					best = e
			return best

		"lowest_hp_ally":
			# 피가 깎인 아군만 후보. 자기 자신도 포함한다.
			var best: Unit = null
			for a in state.living_allies_of(unit):
				if a.missing_hp() <= 0:
					continue
				if best == null or a.hp < best.hp:
					best = a
			return best

		"focused_enemy":
			# 아군이 지금 붙어 있는 적. 사선이 막혔으면 후보에서 빠진다.
			var fe: Unit = state.focus_target_for(unit)
			if fe == null:
				return null
			return fe if (not shooting or state.has_shot(unit, fe)) else null

		"lowest_hp_other_ally":
			# 자기 자신 제외. [최후의 수호] 가 지키러 갈 대상이다.
			var guard: Unit = null
			for a in state.living_allies_of(unit):
				if a.index == unit.index or a.missing_hp() <= 0:
					continue
				if guard == null or a.hp < guard.hp:
					guard = a
			return guard

		"last_attacker":
			# index 로 들고 있으므로 여기서 되짚는다. (순환 참조 방지 - unit.gd 주석 참조)
			var i: int = unit.last_attacker_index
			if i < 0 or i >= state.units.size():
				return null
			var la: Unit = state.units[i]
			if not la.alive:
				return null
			# 반격도 사선이 막히면 못 때린다.
			return la if (not shooting or state.has_shot(unit, la)) else null

		"all_enemies":
			# 광역기는 개별 대상이 없다. 생존 적이 하나라도 있으면 성립한다.
			return enemies[0] if enemies.size() > 0 else null

		"special_ready_enemy":
			# 궁극기가 곧 터질 적. [예봉 차단] 이 이걸로 선제를 잡는다.
			# 여럿이면 index 순 - 먼저 행동하는 쪽이 더 급하다.
			for e in enemies:
				if e.special_ready():
					return e
			return null

		"highest_threat_enemy":
			# 위협도가 가장 높은 적. 도발·은신이 실제로 작동하는 자리다.
			#
			# 지금 쫓던 상대가 있으면 **크게 넘어서야** 갈아탄다. 1이라도 높으면
			# 바로 옮기면, 둘의 위협이 엎치락뒤치락하는 동안 적이 매 틱 표적을
			# 바꾸며 제자리에서 떤다. 화면에는 아무 일도 안 일어난다.
			var ht: Unit = null
			var hs: int = -9999
			for e in enemies:
				var sc := Threat.score(unit, e)
				if sc > hs:
					hs = sc
					ht = e
			var cur: Unit = unit.last_target
			if cur != null and cur.alive and cur.team != unit.team and ht != null 					and cur.index != ht.index:
				var cs := Threat.score(unit, cur)
				# 새 후보가 마진을 못 넘으면 하던 대로 간다.
				if hs * 100 < cs * Threat.SWITCH_MARGIN:
					return cur
			return ht

		"farthest_in_range_enemy":
			# 사거리 안에서 가장 먼 적. 사거리 밖까지 세는 [저격] 과 달리
			# **지금 쏠 수 있는 것 중** 가장 먼 것이라 카이팅과 맞물린다.
			var fr: Unit = null
			var fd: int = -1
			for e in enemies:
				var d: int = Grid.manhattan(unit.pos, e.pos)
				if d <= unit.atk_range and d > fd:
					fd = d
					fr = e
			return fr

		"ranged_enemy":
			for e in enemies:
				if e.atk_range >= 2:
					return e
			return null

		"melee_enemy":
			for e in enemies:
				if e.atk_range <= 1:
					return e
			return null

		"lowest_hp_abs_enemy":
			# 남은 HP 절대값. 비율(처형)과 다르다 - 두꺼운 적은 비율이 낮아도
			# 남은 양이 많아서 못 끊는다.
			var la: Unit = null
			for e in enemies:
				if la == null or e.hp < la.hp:
					la = e
			return la

		"toughest_enemy":
			var tg: Unit = null
			for e in enemies:
				if tg == null or e.max_hp > tg.max_hp:
					tg = e
			return tg

		"unfocused_enemy":
			# 아군이 쫓지 않는 적. 아군이 아무도 안 붙었으면 성립하지 않는다.
			var shared: Unit = state.focus_target_for(unit)
			if shared == null:
				return null
			for e in enemies:
				if e.index != shared.index:
					return e
			return null

		"far_from_allies_enemy":
			# 아군 무리에서 가장 떨어진 적. 기동대가 이걸로 각개격파한다.
			var best: Unit = null
			var bd: int = -1
			for e in enemies:
				var sum := 0
				for a in state.living_allies_of(unit):
					sum += Grid.manhattan(a.pos, e.pos)
				if sum > bd:
					bd = sum
					best = e
			return best

		"healer_enemy":
			# 회복하는 적 우선. 방벽 뒤의 악사를 끊는 표적 교리다.
			var h: Unit = null
			for e in enemies:
				if String(Innates.base_ai(e.type_id)["act"]) == "heal":
					h = e
					break
			return h

		"unguarded_enemy":
			# 방어 태세인 적을 건너뛴다. 전부 방어 중이면 아무도 안 고른다 -
			# 그게 이 모듈의 대가다. 아래 칸으로 폴스루한다.
			var u: Unit = null
			var ud: int = Grid.UNREACHABLE
			for e in enemies:
				if e.defend_level > 0:
					continue
				var d: int = Grid.manhattan(unit.pos, e.pos)
				if d < ud:
					ud = d
					u = e
			return u

		"strongest_enemy":
			var sbest: Unit = null
			for e in enemies:
				if sbest == null or e.atk > sbest.atk:
					sbest = e
			return sbest

	push_error("Rules: 알 수 없는 대상 '%s'" % target_kind)
	return null


# ── 실행 가능성 ──────────────────────────────────────────────────────────

static func is_viable(unit: Unit, card: Dictionary, target: Unit, state) -> bool:
	var act: String = String(card["act"])
	match act:
		"attack":
			return target != null and Grid.manhattan(unit.pos, target.pos) <= unit.atk_range 				and state.has_shot(unit, target)

		"heal":
			return target != null and Grid.manhattan(unit.pos, target.pos) <= unit.atk_range

		"move_toward":
			if target == null:
				return false
			# 이미 사거리 안이면 더 붙을 이유가 없다 → 다음 슬롯에 양보한다.
			if Grid.manhattan(unit.pos, target.pos) <= unit.atk_range:
				return false
			return state.plan_move(unit, target, true, int(card.get("move_bonus", 0))) != unit.pos

		"move_away":
			if target == null:
				return false
			return state.plan_move(unit, target, false, int(card.get("move_bonus", 0))) != unit.pos

		"move_to_ally":
			# 아군 쪽으로 붙는다. 이미 옆에 있으면 더 갈 이유가 없다 → 다음 슬롯.
			#
			# move_toward 를 재사용할 수 없다. 그쪽은 "사거리 안이면 실행 불가" 인데,
			# 사거리는 적을 때리는 거리라 아군에게 적용하면 사거리 3짜리 궁수가
			# 3칸 밖 아군을 호위한다고 판단한다. 호위는 인접이 기준이다.
			if target == null or target.index == unit.index:
				return false
			if Grid.manhattan(unit.pos, target.pos) <= 1:
				return false
			# 계획과 판정이 같은 값을 써야 한다. 여기만 사거리로 재면 "갈 수 있다" 고
			# 판정해 놓고 실제로는 안 움직이는 유령 행동이 나온다.
			return state.plan_move(unit, target, true, int(card.get("move_bonus", 0)), 1) != unit.pos

		"defend", "hold":
			return true

		# ── 궁극기 ───────────────────────────────────────────────────────
		"point_blank":
			# 붙은 적이 있어야 한다. 후퇴할 칸이 없어도 발동한다 -
			# 벽에 몰린 채로도 한 방은 갈긴다는 게 이 궁극기의 값어치다.
			return target != null and Grid.manhattan(unit.pos, target.pos) <= 1

		"focus":
			# 이미 걸려 있으면 발동하지 않는다. 1회제라 사실상 걸릴 일이 없지만,
			# 조건이 참인 채로 두 번 후보에 오르는 경로를 원천 차단한다.
			return unit.focus_bonus == 0

		"guard_ally":
			# 그 아군을 지킬 자리에 실제로 설 수 있어야 한다.
			return target != null and state.guard_landing(unit, target) != unit.pos

		"unyielding":
			# 패시브. 규칙 후보로 올라오면 안 된다. special_ready() 가 이미 막지만
			# 여기서도 지켜서, 나중에 호출 경로가 하나 늘어도 조용히 새지 않게 한다.
			return false

		"bless":
			# 회복할 아군이 하나라도 있어야 한다. 만피뿐이면 낭비다.
			for a in state.living_allies_of(unit):
				if a.missing_hp() > 0:
					return true
			return false

		"blink_strike":
			# 도약해 설 빈 칸이 있어야 한다.
			return target != null and state.blink_landing(unit, target) != unit.pos

	push_error("Rules: 알 수 없는 행동 '%s'" % act)
	return false


# ── 내부 ─────────────────────────────────────────────────────────────────

static func _nearest_distance(unit: Unit, state) -> int:
	var best: int = Grid.UNREACHABLE
	for e in state.living_enemies_of(unit):
		var d: int = Grid.manhattan(unit.pos, e.pos)
		if d < best:
			best = d
	return best
