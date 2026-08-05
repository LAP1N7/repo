class_name Battle
extends RefCounted

## 전투 코어. 틱 루프 · 전투 해결 · 승패 판정.
##
## 씬 트리를 전혀 모른다. 뷰는 battle_event 를 구독해서 Tween 을 재생하기만 한다.
## 덕분에 헤드리스로 전투 전체를 돌려 검증할 수 있다.
##
## 결정론 보장 (DESIGN 1-1):
##   - 난수 호출 0회
##   - 행동 순서 = Unit.index 오름차순 고정
##   - 모든 동점은 index / Grid.DIRS 순서로 끊음
##   - HP 비율 비교는 정수 연산만 사용
## 같은 배치 + 같은 카드 = 항상 같은 결과.

signal battle_event(e: Dictionary)

const MAX_TICKS: int = 60

## 아무도 피해를 입지 않은 채 이만큼 지나면 정체로 보고 끝낸다.
##
## ── 왜 필요한가 ──────────────────────────────────────────────────────────
## MAX_TICKS(60) 만으로는 늦다. 양쪽이 카이팅에 들어가면 10틱쯤에 이미 승부가
## 정해지는데 화면은 50틱을 더 돌린다. 보는 사람은 그 50틱이 무슨 의미인지
## 알 수 없고, 실제로 전체 결말의 17% 가 타임아웃이었다.
##
## ── 왜 14 인가 ──────────────────────────────────────────────────────────
## 6 / 10 / 14 를 실측했다. 스테이지 2(카이팅 판) 승률 기준:
##   기준선 26.6%  ·  6틱 → 17.2%  ·  10틱 → 24.0%  ·  14틱 → 26.1%
## 6 은 이길 편성까지 잘라 버린다. 14 는 타임아웃을 17% → 2.8% 로 없애고 전투를
## 25틱 → 20틱으로 줄이면서도 정당한 승리를 거의 안 깎는다. 목적은 "느린 빌드를
## 벌주는 것" 이 아니라 "아무 일도 안 일어나는 구간을 없애는 것" 이다.
##
## ── 왜 회복은 안 세는가 ─────────────────────────────────────────────────
## 악사가 매 틱 회복만 하고 있어도 "무언가 일어나는 중" 처럼 보이지만, 적을
## 못 줄이면 판은 그대로다. 정체의 기준은 **피해**여야 한다.
const STALL_LIMIT: int = 14

const RESULT_ONGOING: String = ""
const RESULT_VICTORY: String = "victory"
const RESULT_DEFEAT: String = "defeat"
const RESULT_TIMEOUT: String = "timeout"

var units: Array[Unit] = []
var tick: int = 0

## 마지막으로 피해가 발생한 틱. 정체 판정이 읽는다.
var last_damage_tick: int = 0
var result: String = RESULT_ONGOING

## 헤드리스 검증/리플레이용 전체 이벤트 기록.
var events: Array[Dictionary] = []
var record_events: bool = true

var stage_id: int = 0


# ── 준비 ─────────────────────────────────────────────────────────────────

## party: [{ "type": String, "slot": int(0..5), "cards": Array[String],
##          "special": String (선택) }, ...]
func setup(p_stage_id: int, party: Array) -> void:
	units.clear()
	events.clear()
	tick = 0
	result = RESULT_ONGOING
	stage_id = p_stage_id

	var idx: int = 0

	# 플레이어가 먼저 행동한다. index 가 곧 행동 순서다.
	for member in party:
		var slot: int = int(member["slot"])
		assert(slot >= 0 and slot < Grid.PLAYER_SLOTS.size(), "배치 슬롯은 0~5")
		units.append(Unit.create(
			idx, String(member["type"]), Unit.TEAM_PLAYER,
			Grid.PLAYER_SLOTS[slot], member["cards"],
			String(member.get("special", "")), int(member.get("upgrade", 0)),
			bool(member.get("special_first", false)),
			member.get("card_levels", {})
		))
		idx += 1

	var stage: Dictionary = Stages.get_stage(p_stage_id)
	for e in stage["enemies"]:
		units.append(Unit.create(
			idx, String(e["type"]), Unit.TEAM_ENEMY,
			e["pos"], e["cards"], String(e.get("special", "")), 0,
			bool(e.get("special_first", false))
		))
		idx += 1

	_assert_no_overlap()


func _assert_no_overlap() -> void:
	var seen: Dictionary = {}
	for u in units:
		assert(not seen.has(u.pos), "두 유닛이 같은 칸에 배치됨: %s" % u.pos)
		seen[u.pos] = true


# ── 상태 조회 (규칙 엔진이 쓴다) ────────────────────────────────────────
# 반환 배열은 항상 index 오름차순이다. 규칙 엔진의 동점 처리가 여기에 의존한다.

func living_enemies_of(u: Unit) -> Array:
	var out: Array = []
	for other in units:
		# 잠복 중이면 표적 후보에서 빠진다. 맞지 않는다는 게 이 태세의 값이다.
		if other.alive and other.team != u.team and other.ambush_ticks <= 0:
			out.append(other)
	return out


func living_allies_of(u: Unit) -> Array:
	var out: Array = []
	for other in units:
		if other.alive and other.team == u.team:
			out.append(other)
	return out


func living_count(team: int) -> int:
	var n: int = 0
	for u in units:
		if u.alive and u.team == team:
			n += 1
	return n


func unit_at(p: Vector2i) -> Unit:
	for u in units:
		if u.alive and u.pos == p:
			return u
	return null


## u 가 쏠 수 있는 적만. 사이를 다른 적이 막고 있으면 제외한다.
##
## ── 차폐 설계 ──────────────────────────────────────────────────────────
## 막는 것은 **적 유닛만**이다. 아군은 통과시킨다.
## 아군까지 막으면 내 방패병이 내 궁수의 사선을 가려서, 벽을 세우는 순간
## 후열 화력이 죽는다. 적만 막으면 양방향으로 옳게 작동한다:
##   - 내 방패병은 적 궁수로부터 내 후열을 가린다 (적 입장에서 내 방패병은 적)
##   - 적 방패병은 내 궁수로부터 자기 후열을 가린다
## 즉 "벽을 세운다" 가 공격/수비 양쪽에서 의미를 갖는다.
##
## 이게 없으면 원거리 공격이 몸통을 뚫고 나가서 전열/후열 배치가 장식이 된다.
func shootable_enemies_of(u: Unit) -> Array:
	var enemies := living_enemies_of(u)
	var out: Array = []
	for target in enemies:
		var blockers: Dictionary = {}
		for other in enemies:
			if other != target:
				blockers[other.pos] = true
		if Grid.has_line_of_sight(u.pos, target.pos, blockers):
			out.append(target)
	return out


## u 가 target 을 지금 쏠 수 있는가.
func has_shot(u: Unit, target: Unit) -> bool:
	var blockers: Dictionary = {}
	for other in living_enemies_of(u):
		if other != target:
			blockers[other.pos] = true
	return Grid.has_line_of_sight(u.pos, target.pos, blockers)


## mover 를 제외한 생존 유닛의 점유 칸.
func occupancy(mover: Unit) -> Dictionary:
	var blocked: Dictionary = {}
	for u in units:
		if u.alive and u != mover:
			blocked[u.pos] = true
	return blocked


## 이동 후 도착 좌표를 계산한다. 순수 함수 - 상태를 바꾸지 않는다.
## 규칙 엔진의 실행 가능성 판정과 실제 실행이 같은 값을 써야 하므로 반드시 이걸 공유한다.
## bonus 는 이동 보너스 칸수. 유료 이동 카드가 무료 기본기보다 한 칸 더 가게 해서
## "돌격 ≡ 기본 전진" 같은 완전 중복을 없애는 장치다.
## stop_range 는 "이만큼 가까워지면 그만 간다" 는 거리다. 기본은 사거리다.
##
## 아군에게 갈 때는 반드시 1 을 넘겨야 한다. 사거리로 재면 궁수(사거리 3)가
## 아군에게서 3칸 떨어진 채로 "다 왔다" 고 판단해 한 발짝도 안 움직인다.
## [엄호]·[방패 뒤]·[밀집] 이 통째로 죽어 있던 원인이 이거였다.
func plan_move(mover: Unit, target: Unit, toward: bool, bonus: int = 0,
		stop_range: int = -1) -> Vector2i:
	var path := plan_move_path(mover, target, toward, bonus, stop_range)
	return path[path.size() - 1] if path.size() > 0 else mover.pos


## 밟고 지나가는 칸을 순서대로 돌려준다. 첫 원소는 출발점이다.
##
## 뷰가 도착점만 알면 출발점에서 도착점까지 직선으로 보간해 버린다. 경로가 L자면
## 모서리를 가로질러 다른 유닛을 뚫고 지나가는 것처럼 보인다 - 이동이 2칸이 되면서
## 실제로 그렇게 보였다. 그래서 경로 전체를 넘긴다.
func plan_move_path(mover: Unit, target: Unit, toward: bool, bonus: int = 0,
		stop_range: int = -1) -> Array[Vector2i]:
	var blocked: Dictionary = occupancy(mover)
	var path: Array[Vector2i] = [mover.pos]
	var p: Vector2i = mover.pos
	for _i in mover.move_range + bonus:
		var nxt: Vector2i
		if toward:
			# 사거리 안에 들어오면 더 붙지 않는다. 궁수가 적 코앞까지 걸어가는 걸 막는다.
			var stop_at: int = mover.atk_range if stop_range < 0 else stop_range
			if Grid.manhattan(p, target.pos) <= stop_at:
				break
			nxt = Grid.step_toward(p, target.pos, blocked)
		else:
			nxt = Grid.step_away(p, target.pos, blocked)
		if nxt == p:
			break
		p = nxt
		path.append(p)
	return path


# ── 화력 집중 대상 ───────────────────────────────────────────────────────

## 팀별로 "지금 우리가 붙어 있는 적" 과 "그렇게 정한 유닛" 을 들고 있다.
## [협공] 카드가 읽는다. 팀 index 로 접근한다.
var focus_index: Array[int] = [-1, -1]
var focus_by: Array[int] = [-1, -1]


## 팀별로 직전 틱에 적을 처치했는가. [광전사] 가 읽는다.
## 유닛의 kill_pending 과 같은 2단 구조다.
var team_kill: Array[bool] = [false, false]
var team_kill_pending: Array[bool] = [false, false]

## 팀별로 직전 틱에 아군을 잃었는가. 위와 같은 2단 구조다.
var team_loss: Array[bool] = [false, false]
var team_loss_pending: Array[bool] = [false, false]


func team_killed_last_tick(team: int) -> bool:
	return team_kill[team]


## 직전 틱에 우리 편이 죽었는가. [복수] 가 읽는다.
func team_lost_last_tick(team: int) -> bool:
	return team_loss[team]


## 누가 누구를 때릴 때마다 갱신한다.
func _mark_focus(attacker: Unit, victim: Unit) -> void:
	focus_index[attacker.team] = victim.index
	focus_by[attacker.team] = attacker.index


## unit 에게 [협공] 대상이 되는 적. 없으면 null.
##
## 틱을 넘겨서 유지한다. 매 틱 초기화하면 그 틱에 먼저 행동하는 유닛은 항상
## 후보가 없어서, 행동 순서가 빠른 유닛에게만 이 카드가 죽는다.
##
## 자기가 정한 대상은 제외한다. 안 그러면 혼자서도 조건이 참이 되어
## "같은 적을 계속 때린다" 가 되고, 조율 카드가 아니라 그냥 [교전] 이 된다.
func focus_target_for(unit: Unit) -> Unit:
	var i: int = focus_index[unit.team]
	if i < 0 or i >= units.size():
		return null
	if focus_by[unit.team] == unit.index:
		return null
	var t: Unit = units[i]
	return t if (t.alive and t.is_enemy_of(unit)) else null


# ── 틱 ───────────────────────────────────────────────────────────────────

## 1틱 진행. 전투가 계속되면 true.
func step() -> bool:
	if result != RESULT_ONGOING:
		return false

	tick += 1
	# ── 상시 효과를 이번 틱 값으로 채운다 ────────────────────────────────
	# 진형이 바뀌면 값이 바뀐다. 전투 시작에 한 번 계산하면 대원이 흩어져도
	# 값이 그대로 남아 화면과 실제가 어긋난다.
	for u in units:
		if not u.alive:
			continue
		u.passive_atk_pct = Passives.attack_pct(u, self)
		u.passive_def = Passives.defend_bonus(u, self)
		u.passive_taken_pct = Passives.damage_taken_pct(u, self)
		# [조준경] - 제자리를 지킨 다음 틱에만 사거리가 는다. 무조건 주면
		# 궁수가 판 절반을 덮어서 다른 축이 전부 무의미해진다.
		u.range_bonus = 1 if (Passives.has(u, "scope") and not u.moved_last_tick) else 0
		u.atk_range = u.atk_range_base + u.range_bonus

	_emit({ "type": "tick_begin", "tick": tick })

	for u in units:
		if not u.alive:
			continue

		# ── 잠복 ─────────────────────────────────────────────────────────
		# 멈춰 있는 동안 맞지도 때리지도 않는다. 풀리는 순간 첫 공격이 강해진다.
		# 3틱을 버리고 한 방을 사는 거래라, 그 한 방이 확실히 커야 성립한다.
		if u.ambush_ticks > 0:
			u.ambush_ticks -= 1
			if u.ambush_ticks == 0:
				u.ambush_ready = true
				_emit({ "type": "ambush_end", "unit": u.index })
			else:
				_emit({ "type": "ambush", "unit": u.index })
			continue

		_riposte(u)

		# 방어 태세는 자기 행동 직전에 풀린다 → 정확히 한 바퀴 유지된다.
		u.defending = false
		u.defend_level = 0
		_tick_far_streak(u)
		if not _tick_undying(u):
			# [불굴의 의지] 가 끝나며 쓰러졌다. 이번 틱 행동은 없다.
			continue
		u.last_card_id = ""
		u.last_rule_text = ""

		var choice: Dictionary = Rules.select(u, self)
		if choice.is_empty():
			# 카드도 기본기도 전부 실패. 직업 기본기가 생긴 뒤로는 적이 전멸했거나
			# 완전히 포위됐을 때 정도에서만 나온다.
			_emit({ "type": "idle", "unit": u.index })
			continue

		# 협력 축이 읽는다. 아군이 무엇을 보고 있는지가 남아야 협공·분산이 성립한다.
		var chosen: Unit = choice.get("target", null)
		u.last_target = chosen if (chosen != null and chosen.team != u.team) else null
		u.last_card_id = String(choice["card_id"])
		u.last_rule_text = String(choice["card"]["text"])

		# 머리 위 규칙 라벨이 읽는 이벤트. (DESIGN 1-2, 가성비 1위 기능)
		# innate 가 true 면 산 카드가 아니라 직업 기본기로 떨어졌다는 뜻이다.
		# 화면에서 이게 구분돼야 "내 카드가 왜 안 터지지?" 를 눈으로 알 수 있다.
		_emit({
			"type": "rule",
			"unit": u.index,
			"slot": int(choice["slot"]),
			"card_id": u.last_card_id,
			"text": u.last_rule_text,
			"innate": bool(choice["innate"]),
			"special": bool(choice.get("special", false)),
			"rule_name": String(choice["card"]["name"]),
			# 축별 판단 기록. 성립한 것뿐 아니라 **건너뛴 것과 그 이유**도 들어
			# 있다. 성립한 것만 보여 주면 플레이어는 "왜 2번이 안 걸렸지" 를
			# 답할 수 없고, 자기 교리가 틀린 건지 게임이 이상한 건지 구별하지
			# 못한다. AI 를 설계하는 게임에서 그건 치명적이다.
			"trace": choice.get("trace", {}),
			"target": (chosen.index if chosen != null else -1),
		})

		_execute(u, choice)

	# 피격·처치 플래그를 다음 틱으로 넘긴다. "직전 틱에" 는 여기서 확정된다.
	for u in units:
		u.was_hit = u.hit_pending
		u.hit_pending = false
		u.moved_last_tick = u.moved_this_tick
		u.moved_this_tick = false
		u.killed_last_tick = u.kill_pending
		u.kill_pending = false
	for t in 2:
		team_kill[t] = team_kill_pending[t]
		team_kill_pending[t] = false
		team_loss[t] = team_loss_pending[t]
		team_loss_pending[t] = false

	_emit({ "type": "tick_end", "tick": tick })
	_check_result()
	return result == RESULT_ONGOING


func _execute(u: Unit, choice: Dictionary) -> void:
	var card: Dictionary = choice["card"]
	var target: Unit = choice["target"]
	var act: String = String(card["act"])

	match act:
		"attack":
			# power 는 공격력 대비 백분율. 없으면 100(평타).
			# 기본기는 70 으로 낮춰 유료 공격 카드가 항상 우위에 서게 한다.
			var dmg: int = target.take_damage(
				u.power_damage(int(card.get("power", 100))), u)
			last_damage_tick = tick
			u.damage_dealt += dmg
			# [불굴의 의지] 로 버티는 중이면 갚은 만큼 센다. (_hit 와 같은 규칙)
			if u.undying_ticks > 0:
				u.undying_damage += dmg
			_emit({
				"type": "attack", "unit": u.index, "target": target.index,
				"damage": dmg, "target_hp": target.hp,
			})
			_mark_focus(u, target)
			# 잠복 보너스는 한 번 쓰면 꺼진다.
			u.ambush_ready = false
			_splash(u, target, dmg)
			if not target.alive:
				u.kill_pending = true
				team_kill_pending[u.team] = true
				team_loss_pending[target.team] = true
				_emit({ "type": "death", "unit": target.index })
				_recharge_on_death()

		"heal":
			# 규칙이 heal_amount 를 지정하면 그 값을 쓴다. 무료 기본기를
			# 유료 모듈보다 약하게 두기 위한 장치다.
			var amount: int = target.heal(
				int(card.get("heal_amount", UnitData.BARD_HEAL))
				+ int(card.get("heal_bonus", 0)))
			u.healing_done += amount
			_emit({
				"type": "heal", "unit": u.index, "target": target.index,
				"amount": amount, "target_hp": target.hp,
			})

		"move_to_ally":
			# 아군 쪽으로 붙는다. 경로 계산은 접근과 같고, 목적지만 아군이다.
			var afrom: Vector2i = u.pos
			var apath := plan_move_path(u, target, true, int(card.get("move_bonus", 0)))
			u.pos = apath[apath.size() - 1]
			_emit({ "type": "move", "unit": u.index, "from": afrom, "to": u.pos,
				"path": apath })

		"move_toward", "move_away":
			var from: Vector2i = u.pos
			var path := plan_move_path(u, target, act == "move_toward",
				int(card.get("move_bonus", 0)))
			u.pos = path[path.size() - 1]
			u.moved_this_tick = u.pos != from
			_emit({ "type": "move", "unit": u.index, "from": from, "to": u.pos,
				"path": path })

		"defend":
			u.defending = true
			u.defend_level = int(card.get("defend_bonus", 0))
			_emit({ "type": "defend", "unit": u.index })

		"hold":
			_emit({ "type": "hold", "unit": u.index })

		_:
			_execute_special(u, card, target, act)


# ── 특수 스킬 ────────────────────────────────────────────────────────────
# 전부 결정론적이다. 대상 정렬은 항상 (거리, index) 순으로 끊는다.

## 도약해서 설 칸. 대상의 인접 4칸 중 비어 있는 첫 칸(DIRS 순서).
## 없으면 mover 의 현재 위치를 그대로 돌려준다 = 실행 불가.
func blink_landing(mover: Unit, target: Unit) -> Vector2i:
	var blocked: Dictionary = occupancy(mover)
	for d in Grid.DIRS:
		var p: Vector2i = target.pos + d
		if Grid.in_bounds(p) and not blocked.has(p):
			return p
	return mover.pos


## 상시 효과가 만드는 부가 타격.
##
## ── 왜 본체보다 약한가 ───────────────────────────────────────────────────
## 부가 타격이 본체와 같은 위력이면, 적이 뭉치는 판에서 그냥 피해 3배가 된다.
## 40~60% 로 두면 "뭉친 적에게 강하다" 는 성격은 남기고 배율은 안 터진다.
##
## 대상 선정에 난수를 쓰지 않는다. 후보를 index 순으로 훑어 조건에 맞는 것을
## 고른다 - 같은 배치면 같은 결과여야 하기 때문이다.
func _splash(u: Unit, target: Unit, _main: int) -> void:
	var extra: Array[Unit] = []
	var dist: int = Grid.manhattan(u.pos, target.pos)

	if Passives.has(u, "scatter") and u.atk_range >= 2:
		# 표적에서 1칸 떨어진 다른 적 하나.
		for e in living_enemies_of(u):
			if e.index != target.index and Grid.manhattan(e.pos, target.pos) <= 1:
				extra.append(e)
				break

	if Passives.has(u, "whirl") and u.atk_range <= 1:
		# 적 방향 3칸. 근접이 몰매를 되갚는 자리다.
		var dir: int = 1 if u.team == Unit.TEAM_PLAYER else -1
		for step in [1, 2, 3]:
			var at := u.pos + Vector2i(dir * step, 0)
			var e := unit_at(at)
			if e != null and e.team != u.team and e.index != target.index:
				extra.append(e)

	if Passives.has(u, "bombard") and dist >= 2:
		# 표적을 중심으로 한 십자.
		for d in Grid.DIRS:
			var e2 := unit_at(target.pos + d)
			if e2 != null and e2.team != u.team:
				extra.append(e2)

	if extra.is_empty():
		return

	var pct: int = 0
	for name in ["scatter", "whirl", "bombard"]:
		if Passives.has(u, name):
			pct = maxi(pct, int(Passives.SPLASH[name]))

	for e in extra:
		if not e.alive:
			continue
		var d2: int = e.take_damage(u.power_damage(pct), u)
		u.damage_dealt += d2
		last_damage_tick = tick
		_emit({ "type": "splash", "unit": u.index, "target": e.index,
			"damage": d2, "target_hp": e.hp })
		if not e.alive:
			e.alive = false
			u.kill_pending = true
			team_kill_pending[u.team] = true
			team_loss_pending[e.team] = true
			_emit({ "type": "death", "unit": e.index })
			_recharge_on_death()


## [반격 회전] - 피격 다음 틱, 인접한 적 전원에게 되갚는다.
func _riposte(u: Unit) -> void:
	if not u.was_hit or not Passives.has(u, "riposte"):
		return
	for e in living_enemies_of(u):
		if Grid.manhattan(u.pos, e.pos) > 1:
			continue
		var d: int = e.take_damage(u.power_damage(int(Passives.SPLASH["riposte"])), u)
		u.damage_dealt += d
		last_damage_tick = tick
		_emit({ "type": "splash", "unit": u.index, "target": e.index,
			"damage": d, "target_hp": e.hp })
		if not e.alive:
			e.alive = false
			u.kill_pending = true
			team_kill_pending[u.team] = true
			team_loss_pending[e.team] = true
			_emit({ "type": "death", "unit": e.index })
			_recharge_on_death()


func _hit(attacker: Unit, victim: Unit, percent: int, hits: Array) -> void:
	var dmg: int = victim.take_damage(attacker.power_damage(percent), attacker)
	last_damage_tick = tick
	attacker.damage_dealt += dmg
	_mark_focus(attacker, victim)
	if not victim.alive:
		attacker.kill_pending = true
		team_kill_pending[attacker.team] = true
		team_loss_pending[victim.team] = true
	# [불굴의 의지] 로 버티는 중이면 자기가 넣은 피해를 센다. 이 값이 문턱을
	# 넘어야 부활한다 - "죽기 전에 갚아라" 가 이 궁극기의 조건이다.
	if attacker.undying_ticks > 0:
		attacker.undying_damage += dmg
	hits.append({ "target": victim.index, "damage": dmg, "target_hp": victim.hp })


## [거리두기] 의 산탄 범위. 대상 쪽 인접칸과 그 양옆 대각 2칸, 총 3칸.
##
## 방향을 대상에서 뽑으므로 유닛이 어느 쪽을 보는지 따로 들 필요가 없다.
## 대상이 대각선에 있으면 x/y 중 절댓값이 큰 축을 정면으로 삼고, 같으면 x 를
## 고른다 - 결정론을 위해 무조건 한쪽으로 끊는다.
func _in_shot_cone(u: Unit, target: Unit, e: Unit) -> bool:
	var d: Vector2i = target.pos - u.pos
	var face: Vector2i
	if absi(d.x) >= absi(d.y):
		face = Vector2i(signi(d.x), 0)
	else:
		face = Vector2i(0, signi(d.y))
	if face == Vector2i.ZERO:
		return false
	# 정면 1칸 + 그 양옆. face 가 가로면 세로로, 세로면 가로로 벌린다.
	var side := Vector2i(face.y, face.x)
	for c in [u.pos + face, u.pos + face + side, u.pos + face - side]:
		if e.pos == c:
			return true
	return false


## [최후의 수호] 로 설 자리. 지킬 아군의 인접칸 중 **적에게 가장 가까운** 빈 칸.
##
## "앞" 을 진영 방향이 아니라 적과의 거리로 정의한다. 그래야 적이 위에서 오든
## 옆에서 오든 실제로 막아선다. 없으면 자기 위치를 돌려준다 = 실행 불가.
func guard_landing(u: Unit, ally: Unit) -> Vector2i:
	var blocked: Dictionary = occupancy(u)
	var best: Vector2i = u.pos
	var best_d: int = Grid.UNREACHABLE
	for d in Grid.DIRS:
		var c: Vector2i = ally.pos + d
		if not Grid.in_bounds(c) or blocked.has(c):
			continue
		var far: int = Grid.UNREACHABLE
		for e in living_enemies_of(u):
			far = mini(far, Grid.manhattan(c, e.pos))
		if far < best_d:
			best_d = far
			best = c
	return best


## 밀쳐낼 칸. u 에게서 멀어지는 방향으로 n 칸. 막히면 막히기 직전까지만.
func _push_cell(u: Unit, e: Unit, n: int) -> Vector2i:
	var blocked: Dictionary = occupancy(e)
	var p: Vector2i = e.pos
	for _s in n:
		var nxt := Grid.step_away(p, u.pos, blocked)
		if nxt == p:
			break
		p = nxt
	return p


func _emit_deaths(hits: Array) -> void:
	for h in hits:
		var v: Unit = units[int(h["target"])]
		if not v.alive:
			_emit({ "type": "death", "unit": v.index })
			_recharge_on_death()


## 누가 죽으면 [비영천참] 이 다시 찬다 - **강화한 암살자에 한해서다.**
## 강화 전에는 개전 1회로 끝난다. 이 차이가 암살자의 후반 성장(growth 140)과
## 같은 방향이라, "강화를 어디에 쓸 것인가" 의 답이 하나 생긴다.
func _recharge_on_death() -> void:
	for u in units:
		if not u.alive or not u.special_used or u.upgrade <= 0:
			continue
		if not Specials.TABLE.get(u.special, {}).get("recharge_on_death", false):
			continue
		u.special_used = false


func _execute_special(u: Unit, card: Dictionary, target: Unit, act: String) -> void:
	var power := int(card.get("power", 100))
	var arg := int(card.get("act_arg", 0))
	var hits: Array = []
	var moved_from := u.pos
	var move_path: Array[Vector2i] = []

	match act:
		"point_blank":
			# 적 방향 3칸. 대상 쪽 인접칸과 그 양옆(대각 2칸)이다.
			# 산탄이라 사선 판정을 하지 않는다 - 1칸 거리에서는 어차피 뚫린다.
			for e in living_enemies_of(u):
				if _in_shot_cone(u, target, e):
					_hit(u, e, power, hits)
			# 갈기고 빠진다. 벽에 몰려 물러날 칸이 없으면 그냥 안 물러난다.
			var blocked := occupancy(u)
			var p := u.pos
			move_path.append(p)
			for _s in arg:
				var nxt := Grid.step_away(p, target.pos, blocked)
				if nxt == p:
					break
				p = nxt
				move_path.append(p)
			u.pos = p

		"focus":
			# 전투가 끝날 때까지 유지되는 영구 가산치. 이후 모든 공격에 얹힌다.
			u.focus_bonus = arg
			_emit({
				"type": "special", "unit": u.index, "skill": u.special,
				"name": String(card["name"]), "hits": [], "heals": [],
				"buff": arg, "from": moved_from, "to": u.pos,
			})
			u.special_used = true
			return

		"bless":
			var healed: Array = []
			for a in living_allies_of(u):
				# living_allies_of 가 무타입 Array 라 반환형 추론이 안 된다. 명시한다.
				var amount: int = a.heal(arg)
				u.healing_done += amount
				if amount > 0:
					healed.append({ "target": a.index, "amount": amount, "target_hp": a.hp })
			_emit({
				"type": "special", "unit": u.index, "skill": u.special,
				"name": String(card["name"]), "heals": healed, "hits": [],
				"from": moved_from, "to": u.pos,
			})
			u.special_used = true
			return

		"blink_strike":
			# 도약은 의도적인 순간이동이다. 경로를 남기지 않아야 뷰가 직선으로
			# 슉 이동시키고, 그게 이 스킬의 연출이 된다.
			u.pos = blink_landing(u, target)
			_hit(u, target, power, hits)

		"guard_ally":
			# 지킬 아군 앞으로 파고들어 방어 태세로 선다. 그 자리에 있던 적은
			# 밀려난다 - 전선이 무너지던 한 틱을 통째로 되돌리는 게 이 궁극기다.
			var spot := guard_landing(u, target)
			move_path.append(u.pos)
			move_path.append(spot)
			u.pos = spot
			var pushed: Array = []
			for e in living_enemies_of(u):
				if Grid.manhattan(u.pos, e.pos) <= 1:
					var to := _push_cell(u, e, arg)
					if to != e.pos:
						pushed.append({ "unit": e.index, "from": e.pos, "to": to })
						e.pos = to
			u.defending = true
			_emit({
				"type": "special", "unit": u.index, "skill": u.special,
				"name": String(card["name"]), "hits": [], "heals": [],
				"pushed": pushed, "from": moved_from, "to": u.pos, "path": move_path,
			})
			u.special_used = true
			return

		_:
			push_error("Battle: 알 수 없는 궁극기 행동 '%s'" % act)
			return

	_emit({
		"type": "special", "unit": u.index, "skill": u.special,
		"name": String(card["name"]), "hits": hits, "heals": [],
		"from": moved_from, "to": u.pos, "path": move_path,
	})
	_emit_deaths(hits)
	u.special_used = true


# ── 궁극기 상태 갱신 ─────────────────────────────────────────────────────

## [집중사격] 조건이 읽는 연속 유지 틱 수를 갱신한다.
##
## 조건은 과거를 봐야 하는데 규칙 엔진은 현재 상태밖에 못 본다. 그래서 누적은
## 여기서 한다. 한 틱이라도 거리가 무너지면 0 으로 되돌아간다 - 그래야
## "계속 거리를 지켰다" 가 실제로 지켜진 값이 된다.
func _tick_far_streak(u: Unit) -> void:
	var d: int = Grid.UNREACHABLE
	for e in living_enemies_of(u):
		d = mini(d, Grid.manhattan(u.pos, e.pos))
	if d >= Specials.FOCUS_DISTANCE:
		u.far_streak += 1
	else:
		u.far_streak = 0


## [불굴의 의지] 로 버티는 중인 유닛을 정산한다.
## 이번 틱에 행동할 수 있으면 true, 여기서 쓰러졌으면 false.
func _tick_undying(u: Unit) -> bool:
	if u.undying_ticks <= 0:
		return true

	var spec: Dictionary = Specials.TABLE["unyielding"]

	# 부활 판정이 먼저다. 마지막 틱에 문턱을 넘겼는데 죽으면 억울하다.
	if u.undying_damage >= int(spec["cond_damage"]):
		u.undying_ticks = 0
		u.hp = maxi(1, u.max_hp * int(spec["power"]) / 100)
		_emit({
			"type": "special", "unit": u.index, "skill": "unyielding",
			"name": String(spec["name"]), "hits": [], "heals": [],
			"from": u.pos, "to": u.pos,
		})
		_emit({
			"type": "heal", "unit": u.index, "target": u.index,
			"amount": u.hp, "target_hp": u.hp,
		})
		return true

	u.undying_ticks -= 1
	if u.undying_ticks <= 0:
		u.alive = false
		_emit({ "type": "death", "unit": u.index })
		_recharge_on_death()
		return false
	return true


## 사거리 안의 생존 적을 (거리, index) 오름차순으로. 동점은 index 로 끊는다.
func _enemies_in_range_sorted(u: Unit) -> Array:
	var out: Array = []
	for e in shootable_enemies_of(u):
		if Grid.manhattan(u.pos, e.pos) <= u.atk_range:
			out.append(e)
	out.sort_custom(func(a, b):
		var da := Grid.manhattan(u.pos, a.pos)
		var db := Grid.manhattan(u.pos, b.pos)
		if da != db:
			return da < db
		return a.index < b.index
	)
	return out


func _check_result() -> void:
	var players: int = living_count(Unit.TEAM_PLAYER)
	var enemies: int = living_count(Unit.TEAM_ENEMY)

	if players == 0:
		result = RESULT_DEFEAT
	elif enemies == 0:
		result = RESULT_VICTORY
	elif tick - last_damage_tick >= STALL_LIMIT:
		# 정체. 아무도 피를 못 깎은 채 STALL_LIMIT 틱이 지났다.
		#
		# **패배로 끝낸다.** 무승부가 아니라 패배인 이유는, 이 게임에서 이긴다는
		# 건 적을 없애는 것이고 그걸 못 하는 편성은 실패한 편성이기 때문이다.
		# 물러나며 버티는 것 자체가 전략이 되면 "규칙을 짜서 이긴다" 가 아니라
		# "규칙을 짜서 안 진다" 가 되고, 그건 이 게임이 하려는 것이 아니다.
		result = RESULT_DEFEAT
	elif tick >= MAX_TICKS:
		# 최후의 안전장치. 정체 판정이 먼저 걸리므로 여기까지 오는 일은 드물다.
		result = RESULT_TIMEOUT

	if result != RESULT_ONGOING:
		_emit({ "type": "result", "result": result, "tick": tick })


## 끝까지 돌린다. 반환값은 result.
func run() -> String:
	while step():
		pass
	return result


func is_won() -> bool:
	return result == RESULT_VICTORY


# ── 검증 ─────────────────────────────────────────────────────────────────

## 결정론 확인용 상태 지문. 같은 입력이면 매 틱 같은 문자열이 나와야 한다.
func snapshot() -> String:
	var parts: PackedStringArray = []
	for u in units:
		parts.append("%d:%s:%d,%d:%d:%d:%s" % [
			u.index, u.type_id, u.pos.x, u.pos.y, u.hp, 1 if u.special_used else 0,
			"1" if u.alive else "0",
		])
	return "t%d|%s|%s" % [tick, result, "/".join(parts)]


func _emit(e: Dictionary) -> void:
	if record_events:
		events.append(e)
	battle_event.emit(e)
