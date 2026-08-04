class_name Rules
extends RefCounted

## 규칙 엔진. 매 틱 유닛의 슬롯을 1 → 2 → 3 순으로 읽어 실행할 규칙 하나를 고른다.
##
## ── 폴스루(fall-through) 결정 ─────────────────────────────────────────────
## DESIGN 2.3 은 "처음 조건이 맞는 규칙 하나"라고만 썼지만, 그대로 구현하면
## 스테이지 1의 적 전략 `돌격 → 교전` 이 성립하지 않는다. 돌격의 조건은 `항상`
## 이므로 슬롯 1에서 무조건 참이 되고, 슬롯 2의 교전은 영원히 실행되지 않는다.
## 적이 플레이어에게 붙기만 하고 때리지는 않는다.
##
## 그래서 발동 조건을 두 단계로 나눴다:
##   1. 조건이 참인가          (eval_condition)
##   2. 그 행동이 실제로 가능한가 (is_viable - 대상이 존재하고 사거리/이동이 성립)
## 둘 다 만족해야 발동하고, 하나라도 실패하면 다음 슬롯으로 내려간다.
##
## FFXII 갬빗도 대상이 없는 갬빗은 건너뛴다. 이 규칙이 있어야
## `돌격 → 교전` = "사거리 밖이면 붙고, 닿으면 때린다" 라는 자연스러운 문장이 된다.
## ─────────────────────────────────────────────────────────────────────────


## 발동할 규칙을 고른다.
##
## 평가 순서: 꽂은 카드 1 → 2 → 3, 그 다음 직업 기본기, 마지막으로 공통 골격.
## 기본기가 맨 아래에 있으므로 산 카드가 항상 우선한다. 그리고 공통 골격에
## "사거리 밖 → 접근" 이 있으므로 사실상 빈손으로도 유닛은 반드시 무언가 한다.
##
## 반환: { "card_id", "card", "target", "slot", "innate", "special" }.
## 전부 실패하면 빈 Dictionary.
static func select(unit: Unit, state) -> Dictionary:
	# 특수를 규칙 슬롯보다 먼저 볼지는 플레이어가 정한다.
	# 무조건 최우선으로 두면 특수가 준비된 동안 슬롯 1~3 이 통째로 무시되어
	# "우선순위가 곧 전략" 이라는 명제가 깨진다. (unit.gd 의 special_first 주석 참조)
	if unit.special_first:
		var early := _try_special(unit, state)
		if not early.is_empty():
			return early

	for slot in unit.card_rules.size():
		var card_id: String = unit.cards[slot]
		# 반드시 card_rules 를 본다. Cards.TABLE 을 직접 읽으면 합성 단계가
		# 통째로 무시된다. (unit.gd 의 card_rules 주석 참조)
		var hit := _try_rule(unit, unit.card_rules[slot], state)
		if not hit.is_empty():
			hit["card_id"] = card_id
			hit["slot"] = slot
			hit["innate"] = false
			hit["special"] = false
			return hit

	# 특수가 "전술 뒤" 면 카드가 전부 어긋난 뒤, 기본기보다는 먼저 본다.
	if not unit.special_first:
		var late := _try_special(unit, state)
		if not late.is_empty():
			return late

	for rule in unit.innate:
		var hit2 := _try_rule(unit, rule, state)
		if not hit2.is_empty():
			hit2["card_id"] = ""
			hit2["slot"] = -1
			hit2["innate"] = true
			hit2["special"] = false
			return hit2

	return {}


static func _try_special(unit: Unit, state) -> Dictionary:
	if not unit.special_ready():
		return {}
	var hit := _try_rule(unit, Specials.TABLE[unit.special], state)
	if hit.is_empty():
		return {}
	hit["card_id"] = unit.special
	hit["slot"] = -2
	hit["innate"] = false
	hit["special"] = true
	return hit


## 규칙 하나가 지금 발동 가능한지 본다. 되면 { "card", "target" }, 아니면 {}.
static func _try_rule(unit: Unit, rule: Dictionary, state) -> Dictionary:
	if not eval_condition(unit, rule["cond"], int(rule["cond_arg"]), state):
		return {}
	var target: Unit = resolve_target(unit, String(rule["target"]), state, String(rule["act"]))
	if not is_viable(unit, rule, target, state):
		return {}
	return { "card": rule, "target": target }


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
