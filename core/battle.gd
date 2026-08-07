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

## 페이즈 하나가 늘 때마다 늘려 주는 틱 예산.
##
## 60 은 한 덩어리 판을 재던 값이다. 페이즈를 셋으로 쪼개 놓고 예산을 그대로
## 두면 3페이즈는 시작하자마자 시간이 끊긴다. 이건 난이도가 아니라 계량 실수다.
const TICKS_PER_WAVE: int = 22


## 이 전투의 틱 상한. 페이즈 수에 따라 늘어난다.
func max_ticks() -> int:
	return MAX_TICKS + TICKS_PER_WAVE * maxi(0, waves.size() - 1)

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
	wave = 0
	barrage_count = 0
	hazard_cells.clear()

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
		# 보조 지휘 강화는 편성이 확정된 이 순간 한 번만 얹는다.
		units[units.size() - 1].apply_command(member.get("cmd", {}))
		# 야전 정비는 부대 단위 값이다. 누구 것을 읽어도 같다.
		repair_pct = int((member.get("cmd", {}) as Dictionary).get("repair", 0))
		idx += 1

	var stage: Dictionary = Stages.get_stage(p_stage_id)
	waves = Stages.waves(stage)
	hazard = stage.get("hazard", {})
	_spawn_wave(0)

	_assert_no_overlap()


## ── 페이즈 ───────────────────────────────────────────────────────────────
## 한 판이 한 덩어리로 끝나면 "이 판은 어떤 판인가" 가 첫 3초에 다 드러나고,
## 남은 시간은 이미 정해진 결과를 보는 시간이 된다.
##
## 페이즈로 쪼개면 같은 판 안에서 문제가 바뀐다. 1페이즈를 푼 편성이 2페이즈에서
## 통하지 않을 수 있고, 그게 "우선순위를 어떻게 짤 것인가" 를 한 판 안에서 두
## 번 묻는다. 알고리즘은 전투 중에 못 바꾸므로, 두 문제를 **한 알고리즘으로**
## 풀어야 한다 - 그게 이 게임이 물어야 할 질문이다.
##
## 다음 페이즈는 앞 페이즈가 전멸한 **그 틱에** 등장한다. 딜레이를 두면 그
## 사이에 아군이 전진해 진형이 무너진 채로 다음 파가 온다.
var waves: Array = []
var wave: int = 0


func _spawn_wave(n: int) -> void:
	wave = n
	var spawned: Array[int] = []
	for e in waves[n]:
		var idx: int = units.size()
		var u := Unit.create(
			idx, String(e["type"]), Unit.TEAM_ENEMY,
			_free_enemy_cell(e["pos"]), e["cards"],
			String(e.get("special", "")), 0,
			bool(e.get("special_first", false))
		)
		u.apply_traits(e.get("traits", []))
		units.append(u)
		spawned.append(idx)
	if n > 0:
		# 새 파가 오면 정체 시계를 되감는다. 안 그러면 1페이즈에서 카이팅으로
		# 시간을 끈 판이 2페이즈가 뜨자마자 정체 패배로 끝난다.
		last_damage_tick = tick
		_repair()
		# ── 궁극기는 페이즈마다 한 번 ────────────────────────────────────
		# 교전당 1회였다. 그런데 페이즈가 셋인 판에서는 1페이즈에 쓰고 나면
		# 나머지 두 판을 맨손으로 치른다 - 그러면 궁극기를 **아끼는 것**이
		# 늘 정답이 되고, 아끼다 보면 판이 끝난다. 실제로 3페이즈짜리에서
		# 한 번도 안 쓰고 지는 경우가 있었다.
		#
		# 페이즈마다 한 번으로 바꾸면 "지금 쓸까, 다음 파를 위해 남길까" 가
		# 사라지고 "이 페이즈 어디에서 쓸까" 만 남는다. 아끼는 쪽이 늘 옳은
		# 선택지는 선택지가 아니다.
		for u in units:
			if u.team == Unit.TEAM_PLAYER and u.alive:
				u.special_used = false
		_emit({ "type": "wave", "wave": n, "units": spawned, "total": waves.size() })


## ── 페이즈를 넘어가도 HP 는 그대로다 ────────────────────────────────────
##
## 예전에는 페이즈가 바뀔 때마다 최대 HP 의 60% 를 공짜로 돌려줬다. 그러면
## 페이즈가 "한 판 안의 두 번째 문제" 가 아니라 그냥 **따로 노는 두 판**이
## 된다. 앞 파에서 얼마나 아꼈는지가 뒤 파에 아무 영향을 안 주므로, 1페이즈를
## 어떻게 풀든 2페이즈는 늘 같은 조건에서 시작한다.
##
## HP 를 들고 넘어가야 "빨리 끝내는 것" 과 "안 맞고 끝내는 것" 이 값을 갖는다.
## 그게 알고리즘을 짜는 이유가 된다.
##
## 회복이 필요하면 **산다.** 보조 지휘의 [야전 정비] 가 그 자리다
## (data/command.gd). 공짜였던 것을 선택으로 바꾼 것이지 없앤 것이 아니다.
## 공짜로 붙는 최소 응급 처치.
##
## 0 으로 두고 재 봤더니 3~5단계 승률이 1~3% 로 무너졌다. 페이즈가 셋이면 적이
## 여덟인데 대원은 셋이고 회복이 하나도 없으니, 알고리즘을 어떻게 짜든 산술이
## 안 맞는다. 그건 어려운 게 아니라 불가능한 것이다.
##
## 그렇다고 예전처럼 60% 를 돌려주면 페이즈가 **따로 노는 두 판**이 된다.
## 1페이즈를 얼마나 아꼈는지가 2페이즈에 아무 영향을 안 주기 때문이다.
##
## 20% 는 그 사이다. 깎인 것의 대부분은 그대로 남으므로 "빨리 · 안 맞고 끝내기"
## 가 여전히 값을 갖고, 그러면서 여덟을 상대할 산술은 성립한다.
## 더 필요하면 보조 지휘의 [야전 정비] 를 산다.
const BASE_REPAIR_PCT: int = 20

var repair_pct: int = 0


func _repair() -> void:
	var pct: int = BASE_REPAIR_PCT + repair_pct
	if pct <= 0:
		return
	var healed: Array = []
	for u in units:
		if not u.alive or u.team != Unit.TEAM_PLAYER:
			continue
		var amount: int = u.heal(u.max_hp * pct / 100)
		if amount > 0:
			healed.append({ "target": u.index, "amount": amount, "target_hp": u.hp })
	if not healed.is_empty():
		_emit({ "type": "repair", "heals": healed })


## 지정된 칸이 이미 찼으면 적 진영 칸을 순서대로 훑어 빈 칸을 찾는다.
##
## 암살자가 적 진영까지 파고든 상태에서 다음 파가 뜨면 겹친다. 난수를 쓰지
## 않고 ENEMY_SLOTS 의 고정 순서로 밀어내야 같은 배치에서 같은 결과가 나온다.
func _free_enemy_cell(want: Vector2i) -> Vector2i:
	var taken: Dictionary = {}
	for u in units:
		if u.alive:
			taken[u.pos] = true
	if not taken.has(want):
		return want
	for c in Grid.ENEMY_SLOTS:
		if not taken.has(c):
			return c
	# 진영이 통째로 찼다. 격자를 오른쪽 위부터 훑는다.
	for x in range(Grid.W - 1, -1, -1):
		for y in Grid.H:
			var p := Vector2i(x, y)
			if not taken.has(p):
				return p
	return want


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
	# 고정 개체는 어떤 모듈이 붙어도 안 움직인다. 이동력 0 만으로는 부족하다 -
	# 강행군 같은 이동 보너스가 붙으면 한 칸씩 기어간다.
	if mover.immobile:
		return [mover.pos] as Array[Vector2i]

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
## ── 이번 틱의 행동 순서 ──────────────────────────────────────────────────
## 기본은 Unit.index 다. 이 게임은 한 틱 안에서 대원이 **차례로** 행동하고,
## 각자 행동한 결과는 곧바로 판에 반영된다(제자리 갱신). 그래서 순서 자체가
## 규칙의 일부이고, 임의로 흔들면 같은 편성이 판마다 다르게 논다.
##
## 딱 한 가지만 예외로 둔다: **따라다니는 대원은 따라다닐 대상 뒤에 선다.**
##
## 왜 필요한가 - 악사에게 [방패 뒤] 를 꽂고 악사를 방패병보다 앞 칸에 배치하면
## 이런 일이 났다.
##
##   1틱  악사 판단: 방패병 곁이다 -> 제자리
##        방패병 판단: 전진        -> 한 칸 나감
##   2틱  악사 판단: 방패병이 멀다 -> 이제야 따라감
##
## 악사는 항상 **한 틱 전의 방패병**을 보고 있었다. 실제로 3틱이 지나서야
## 처음 움직였다. 따라다니라고 산 모듈이 한 박자씩 늦으면 그건 모듈이 아니라
## 지연이다.
##
## 순서는 위상 정렬로 잡는다. 서로를 따라다니는 고리가 생기면(A→B→A) 그 고리는
## index 순으로 두고 넘어간다 - 답이 없는 관계라 억지로 풀면 오히려 순서가
## 판마다 달라진다.
##
## 결정론은 유지된다. 난수가 없고, 동점은 전부 index 로 끊는다.
func act_order() -> Array:
	var live: Array = []
	for u in units:
		if u.alive:
			live.append(u)

	# 누가 누구를 따라다니는가. 값은 index 다.
	var anchor: Dictionary = {}
	for u in live:
		var a: Unit = Rules.follow_anchor(u, self)
		if a != null and a.alive and a.index != u.index:
			anchor[u.index] = a.index

	if anchor.is_empty():
		return live

	var out: Array = []
	var done: Dictionary = {}
	var busy: Dictionary = {}

	# 재귀 대신 명시적 스택. GDScript 에 지역 재귀 함수가 없다.
	for start in live:
		if done.has(start.index):
			continue
		var stack: Array = [start]
		while not stack.is_empty():
			var u: Unit = stack[stack.size() - 1]
			if done.has(u.index):
				stack.pop_back()
				continue
			var need: int = int(anchor.get(u.index, -1))
			# 아직 안 내보낸 기준이 있고, 그 기준이 지금 스택에 없다면(고리가
			# 아니라면) 그쪽을 먼저 처리한다.
			if need >= 0 and not done.has(need) and not busy.has(need):
				busy[u.index] = true
				stack.append(units[need])
				continue
			busy.erase(u.index)
			done[u.index] = true
			out.append(u)
			stack.pop_back()
	return out


func step() -> bool:
	if result != RESULT_ONGOING:
		return false

	tick += 1

	# 착탄이 먼저다. 예고를 보고 나서 한 틱을 살아남았는지가 여기서 갈린다.
	_resolve_barrage()
	if result != RESULT_ONGOING:
		return false
	_warn_barrage()

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
		# 개체 특성이 만드는 보정. 감독기가 죽으면 그 틱부터 사라진다.
		u.trait_atk_pct = Traits.attack_pct(u, self)

	_emit({ "type": "tick_begin", "tick": tick })

	for u in act_order():
		if not u.alive:
			continue

		# ── 잠복 ─────────────────────────────────────────────────────────
		# 멈춰 있는 동안 맞지도 때리지도 않는다. 풀리는 순간 첫 공격이 강해진다.
		# 3틱을 버리고 한 방을 사는 거래라, 그 한 방이 확실히 커야 성립한다.
		if u.ambush_ticks > 0:
			u.ambush_ticks -= 1
			if u.ambush_ticks == 0:
				u.ambush_ready = true
				u.ambush_done = true
				# 보너스에는 유효 기간이 있다. 풀리고 나서 이 틱 수 안에
				# 때려야 한 방이 세진다.
				# +1 인 이유: 이 틱이 끝날 때 아래 정산에서 한 번 깎인다.
				# 그래서 **실제로 때릴 수 있는 틱이 %d개** 남으려면 하나 더 준다.
				u.ambush_bonus_ticks = Specials.AMBUSH_WINDOW + 1
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

	# ── 도화선 ───────────────────────────────────────────────────────────
	# 붙은 자폭체는 스스로 타들어 간다. 행동이 다 끝난 뒤에 센다 - 이번 틱에
	# 물러나 떨어졌으면 도화선이 꺼져야 하기 때문이다.
	_tick_fuses()

	# 자폭은 틱의 모든 행동이 끝난 뒤에 한꺼번에 처리한다.
	#
	# 죽는 자리마다 터뜨리면 사망 처리 지점이 다섯 군데(평타·범위·반격·불굴·포격)
	# 라 한 곳만 빠뜨려도 조용히 안 터진다. 한 곳에 모으면 빠질 데가 없고,
	# "죽고 나서 터진다" 는 순서도 눈으로 읽힌다.
	_resolve_explosions()

	# 피격·처치 플래그를 다음 틱으로 넘긴다. "직전 틱에" 는 여기서 확정된다.
	for u in units:
		u.was_hit = u.hit_pending
		u.hit_pending = false
		u.moved_last_tick = u.moved_this_tick
		u.moved_this_tick = false
		# 잠복 보너스는 시간이 지나면 식는다.
		if u.ambush_ready:
			u.ambush_bonus_ticks -= 1
			if u.ambush_bonus_ticks <= 0:
				u.ambush_ready = false
		# "적이 다가오는 중인가" 를 다음 틱에 판정할 수 있게 거리를 남긴다.
		var nd: int = Grid.UNREACHABLE
		for e in living_enemies_of(u):
			nd = mini(nd, Grid.manhattan(u.pos, e.pos))
		u.prev_near_dist = nd
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


# ── 궤도 포격 ────────────────────────────────────────────────────────────
#
# ── 왜 넣었나 ────────────────────────────────────────────────────────────
# 판을 바꾸는 가장 강한 손잡이는 적 구성이 아니라 **판 자체**다. 적을 아무리
# 바꿔도 격자가 늘 안전하면 플레이어가 푸는 문제는 "누구를 먼저 치나" 하나로
# 고정된다. 바닥이 위험해지는 순간 "언제 어디에 서 있나" 가 같이 문제가 된다.
#
# ── 왜 한 틱 미리 예고하는가 ─────────────────────────────────────────────
# 예고 없이 떨어지면 그건 난수와 구별되지 않는다. 플레이어는 알고리즘을 짜
# 두고 결과를 보는 입장이라, 예고가 없으면 자기 편성이 나빴는지 운이 나빴는지
# 영영 구분하지 못한다. 한 틱 먼저 칸을 밝히면 화면을 보는 사람이 "저기 서
# 있으면 맞겠다" 를 알 수 있고, 그때부터 이건 규칙이 된다.
#
# ── 왜 양쪽 다 맞는가 ────────────────────────────────────────────────────
# 플레이어만 맞으면 벌칙이고 적만 맞으면 선물이다. 둘 다 맞아야 "적을 저기로
# 끌고 간다" 가 전술이 된다.
#
# 난수는 없다. 패턴은 정해진 순서로 돌고 몇 번째인지는 barrage_count 가 센다.
var hazard: Dictionary = {}
var hazard_cells: Array[Vector2i] = []
var barrage_count: int = 0


## 이번 틱이 예고 틱인가.
func _is_warn_tick() -> bool:
	if hazard.is_empty() or String(hazard.get("kind", "")) != "barrage":
		return false
	var first := int(hazard.get("first", 6))
	var period := maxi(1, int(hazard.get("period", 5)))
	return tick >= first and (tick - first) % period == 0


func _warn_barrage() -> void:
	if not _is_warn_tick():
		return
	var patterns: Array = hazard.get("patterns", [])
	if patterns.is_empty():
		return
	var pat: Dictionary = patterns[barrage_count % patterns.size()]
	barrage_count += 1
	hazard_cells = _pattern_cells(pat)
	_emit({ "type": "barrage_warn", "cells": hazard_cells.duplicate(),
		"name": String(hazard.get("name", "포격")) })


## 열·행 지정을 실제 칸으로 편다. x 오름차순 · y 오름차순 고정이다.
func _pattern_cells(pat: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen: Dictionary = {}
	for x in pat.get("cols", []):
		for y in Grid.H:
			var p := Vector2i(int(x), y)
			if Grid.in_bounds(p) and not seen.has(p):
				seen[p] = true
				out.append(p)
	for y in pat.get("rows", []):
		for x in Grid.W:
			var p2 := Vector2i(x, int(y))
			if Grid.in_bounds(p2) and not seen.has(p2):
				seen[p2] = true
				out.append(p2)
	return out


func _resolve_barrage() -> void:
	if hazard_cells.is_empty():
		return
	var cells := hazard_cells
	hazard_cells = [] as Array[Vector2i]

	var hit_set: Dictionary = {}
	for c in cells:
		hit_set[c] = true
	var dmg := int(hazard.get("damage", 20))
	var hits: Array = []
	# index 순으로 돈다. 같은 배치면 같은 순서로 맞아야 한다.
	for u in units:
		if not u.alive or not hit_set.has(u.pos):
			continue
		# 포격은 유닛이 아니다. take_damage 의 from 을 null 로 둬서 어그로가
		# 엉뚱한 데로 튀지 않게 한다.
		var d: int = u.take_damage(dmg, null)
		last_damage_tick = tick
		hits.append({ "target": u.index, "damage": d, "target_hp": u.hp })
	_emit({ "type": "barrage", "cells": cells, "hits": hits,
		"name": String(hazard.get("name", "포격")) })
	for h in hits:
		var v: Unit = units[int(h["target"])]
		if not v.alive:
			_emit({ "type": "death", "unit": v.index })
			_recharge_on_death()
	_check_result()


## ── 자폭 ─────────────────────────────────────────────────────────────────
## 죽은 자폭 개체를 터뜨린다. 폭발이 또 자폭 개체를 죽이면 연쇄한다.
##
## 연쇄에 상한을 둔다. 자폭체 여럿을 붙여 놓으면 이론상 끝없이 돌 수 있는데,
## 격자가 8x6 이라 실제로는 서너 번이면 끝난다. 상한은 안전장치일 뿐이다.
func _resolve_explosions() -> void:
	for _round in 8:
		var blew := false
		for u in units:
			if u.alive or u.exploded or not Traits.has(u, Traits.VOLATILE):
				continue
			u.exploded = true
			blew = true
			_explode(u)
		if not blew:
			return


## 붙어 있는 자폭체의 도화선을 센다. 0 이 되면 스스로 터진다.
##
## 떨어지면 꺼진다. "물러나서 끊는다" 가 실제로 통해야 선택이 된다.
func _tick_fuses() -> void:
	for u in units:
		if not u.alive or not Traits.has(u, Traits.VOLATILE):
			continue
		var touching := false
		for e in living_enemies_of(u):
			if Grid.manhattan(u.pos, e.pos) <= 1:
				touching = true
				break
		if not touching:
			if u.fuse_ticks >= 0:
				u.fuse_ticks = -1
				_emit({ "type": "fuse", "unit": u.index, "left": -1 })
			continue
		if u.fuse_ticks < 0:
			u.fuse_ticks = Traits.FUSE_TICKS
		else:
			u.fuse_ticks -= 1
		_emit({ "type": "fuse", "unit": u.index, "left": u.fuse_ticks })
		if u.fuse_ticks <= 0:
			# 스스로 터진다. 처치가 아니므로 아무에게도 공적이 안 붙는다.
			u.alive = false
			team_loss_pending[u.team] = true
			_emit({ "type": "death", "unit": u.index })
			_recharge_on_death()


func _explode(src: Unit) -> void:
	var hits: Array = []
	# 자신을 중심으로 한 3x3. 좌표 순서로 돌아 난수가 끼지 않는다.
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var v := unit_at(src.pos + Vector2i(dx, dy))
			if v == null:
				continue
			var dealt: int = v.take_damage(Traits.VOLATILE_DAMAGE, null)
			last_damage_tick = tick
			hits.append({ "target": v.index, "damage": dealt, "target_hp": v.hp })
	_emit({ "type": "explode", "unit": src.index, "at": src.pos, "hits": hits })
	for h in hits:
		var t: Unit = units[int(h["target"])]
		if not t.alive:
			_emit({ "type": "death", "unit": t.index })
			_recharge_on_death()


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
			#
			# **멈추는 거리를 1 로 박는다.** 기본값은 mover.atk_range 인데,
			# 그러면 사거리 2 인 악사가 방패병에게 갈 때 "이미 2칸이니 다 왔다"
			# 로 판단해 한 걸음도 안 걷는다. 판단부(_move_by_ally)는 1칸으로
			# 재고 실행부는 사거리로 재고 있었다 - 규칙은 발동하는데 아무 일도
			# 안 일어나는, 가장 찾기 어려운 종류의 어긋남이었다.
			var afrom: Vector2i = u.pos
			var apath := plan_move_path(u, target, true,
				int(card.get("move_bonus", 0)), 1)
			u.pos = apath[apath.size() - 1]
			u.moved_this_tick = u.pos != afrom
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
		# 다음 페이즈가 남아 있으면 승리가 아니다. 그 자리에서 바로 다음 파가 온다.
		if wave + 1 < waves.size():
			_spawn_wave(wave + 1)
			return
		result = RESULT_VICTORY
	elif tick - last_damage_tick >= STALL_LIMIT:
		# 정체. 아무도 피를 못 깎은 채 STALL_LIMIT 틱이 지났다.
		#
		# **패배로 끝낸다.** 무승부가 아니라 패배인 이유는, 이 게임에서 이긴다는
		# 건 적을 없애는 것이고 그걸 못 하는 편성은 실패한 편성이기 때문이다.
		# 물러나며 버티는 것 자체가 전략이 되면 "규칙을 짜서 이긴다" 가 아니라
		# "규칙을 짜서 안 진다" 가 되고, 그건 이 게임이 하려는 것이 아니다.
		result = RESULT_DEFEAT
	elif tick >= max_ticks():
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
