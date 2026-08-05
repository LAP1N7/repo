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

	# 1) SQUAD - 아군 참조 방식
	var squad := _axis(unit, Axes.SQUAD, state, trace)
	var coop := String(squad.get("value", "solo"))

	# 2) TARGET - 누구를
	var picked := _pick_target(unit, state, trace, coop)
	var target: Unit = picked.get("target", null)

	# 3) ENGAGE - 지금 싸우는가
	_ctx_target = target
	var eng := _axis(unit, Axes.ENGAGE, state, trace)
	_ctx_target = null
	var stance := String(eng.get("value", "engage"))

	# 4) POSITION - 어디에
	var pos := _axis(unit, Axes.POSITION, state, trace)
	var stand := String(pos.get("value", ""))

	# 궁극기가 "전술 뒤" 면 축을 다 읽은 다음, 기본 판단보다는 먼저 본다.
	if not unit.special_first:
		var late := _try_special(unit, state)
		if not late.is_empty():
			late["trace"] = trace
			return late

	var built := _assemble(unit, state, target, stance, stand, coop)
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


# ── 2) 표적 ──────────────────────────────────────────────────────────────

## 표적 축을 읽어 대상을 고른다. 아무것도 안 걸리면 가장 가까운 적.
##
## 협력 축이 여기에 개입한다. [협공] 은 아군이 이미 노리는 적을 그대로 쓰고,
## [분산] 은 그 적을 후보에서 뺀다. 표적 축보다 **먼저** 걸리는 이유는,
## 협력이 "부대 차원의 결정" 이고 표적은 "개인의 취향" 이기 때문이다.
static func _pick_target(unit: Unit, state, trace: Dictionary, coop: String) -> Dictionary:
	var rows: Array = []

	# 협공: 아군이 노리는 적이 있으면 그쪽으로 확정한다.
	if coop == "focus":
		var shared := _ally_focus(unit, state)
		if shared != null:
			rows.append({ "slot": -1, "name": "협공", "hit": true, "why": "" })
			trace[Axes.TARGET] = rows
			return { "target": shared }

	var banned: Unit = _ally_focus(unit, state) if coop == "spread" else null

	for slot in unit.card_rules.size():
		var rule: Dictionary = unit.card_rules[slot]
		if rule.is_empty() or String(rule.get("axis", "")) != Axes.TARGET:
			continue
		var name := String(rule.get("name", ""))
		if not eval_condition(unit, String(rule["cond"]), int(rule["cond_arg"]), state):
			rows.append({ "slot": slot, "name": name, "hit": false, "why": "조건 불성립" })
			continue
		var t := resolve_target(unit, String(rule.get("pick", "nearest_enemy")), state, "attack")
		if t == null or (banned != null and t.index == banned.index):
			rows.append({ "slot": slot, "name": name, "hit": false, "why": "대상 없음" })
			continue
		rows.append({ "slot": slot, "name": name, "hit": true, "why": "" })
		trace[Axes.TARGET] = rows
		return { "target": t, "rule": rule, "slot": slot }

	trace[Axes.TARGET] = rows
	# 기본값. 악사는 아군을 살리는 게 기본이므로 표적도 아군 쪽이다.
	var ai := Innates.base_ai(unit.type_id)
	if String(ai["act"]) == "heal":
		return { "target": resolve_target(unit, "lowest_hp_ally", state, "heal") }
	return { "target": resolve_target(unit, "nearest_enemy", state, "attack") }


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
		stand: String, coop: String) -> Dictionary:
	var ai := Innates.base_ai(unit.type_id)
	var act_kind := String(ai["act"])
	var power := int(ai["power"])
	# 강행군은 자리가 아니라 **이동력 보정**이다. 다른 자리 판단과 같이 걸린다.
	var bonus := 1 if stand == "march" else 0

	# ── 교전이 위치와 표적을 이긴다 ──────────────────────────────────────
	match stance:
		"wait":
			return _rule(unit, "대기", "hold", target, 0, 0)
		"defend":
			return _rule(unit, "방어", "defend", unit, 0, 0)
		"avoid":
			var away := resolve_target(unit, "nearest_enemy", state, "")
			if away != null and state.plan_move(unit, away, false, bonus) != unit.pos:
				return _rule(unit, "회피", "move_away", away, 0, bonus)
			# 물러날 칸이 없으면 버틴다. 회피가 실패했다고 공격으로 넘어가면
			# "물러나라" 는 지시가 조용히 뒤집힌다.
			return _rule(unit, "회피 불가", "hold", target, 0, 0)

	if target == null:
		return {}

	# ── 사거리 안이면 일한다 ─────────────────────────────────────────────
	var dist: int = Grid.manhattan(unit.pos, target.pos)
	if dist <= unit.atk_range:
		if act_kind == "heal":
			if target.team == unit.team and target.missing_hp() > 0:
				return _rule(unit, "회복", "heal", target, power, 0)
		elif state.has_shot(unit, target):
			# 원거리는 적이 코앞이면 한 칸 물러나며 쏠 자리를 만든다.
			# 이게 기본 AI 의 flee_within 이다. 태세가 추격이면 안 물러난다.
			var flee := int(ai["flee_within"])
			if flee > 0 and dist <= flee and stance != "pursue":
				var near := resolve_target(unit, "nearest_enemy", state, "")
				if near != null and state.plan_move(unit, near, false, bonus) != unit.pos:
					return _rule(unit, "간격 확보", "move_away", near, 0, bonus)
			return _rule(unit, "공격", "attack", target, power, 0)

	# ── 사거리 밖이면 위치 축이 어디로 갈지 정한다 ───────────────────────
	return _move_by_stand(unit, state, target, stance, stand, bonus)


static func _move_by_stand(unit: Unit, state, target: Unit, stance: String,
		stand: String, bonus: int) -> Dictionary:
	var ai := Innates.base_ai(unit.type_id)

	match stand:
		"keep_range":
			# 최대 사거리를 유지한다. 너무 가까우면 물러나고 멀면 붙는다.
			var d: int = Grid.manhattan(unit.pos, target.pos)
			if d < unit.atk_range and state.plan_move(unit, target, false, bonus) != unit.pos:
				return _rule(unit, "간격 유지", "move_away", target, 0, bonus)
			return _approach(unit, state, target, bonus, "거리 좁힘")

		"behind_guard":
			# 방패병·전사보다 앞에 서 있으면 물러난다. 없으면 그냥 붙는다.
			var guard := _guard_ally(unit, state)
			if guard != null and _is_ahead_of(unit, guard):
				if state.plan_move(unit, guard, true, bonus) != unit.pos:
					return _rule(unit, "방패 뒤", "move_to_ally", guard, 0, bonus)
			return _approach(unit, state, target, bonus, "전진")

		"cluster":
			# 아군과 떨어져 있으면 붙는다.
			var mate := _nearest_ally(unit, state)
			if mate != null and Grid.manhattan(unit.pos, mate.pos) > 1:
				if state.plan_move(unit, mate, true, bonus) != unit.pos:
					return _rule(unit, "밀집", "move_to_ally", mate, 0, bonus)
			return _approach(unit, state, target, bonus, "전진")

		"frontline", "flank", "march":
			return _approach(unit, state, target, bonus, "전진")

	# 위치 모듈이 없다. 직업 기본 AI 가 정한다.
	if String(ai["stand"]) == "advance" or stance == "pursue":
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
			return state.plan_move(unit, target, true, int(card.get("move_bonus", 0))) != unit.pos

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
