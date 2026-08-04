extends SceneTree

## 전투 코어 헤드리스 검증.
##
##   godot --headless --script res://test/headless_test.gd
##
## 승/패/타임아웃 세 종료 분기를 모두 태우고, 결정론을 스냅샷 수열로 확인한다.

var failures: int = 0
var checks: int = 0


func _init() -> void:
	print("=== GAMBIT GRID / 전투 코어 검증 ===\n")

	test_data_tables()
	test_grid()
	test_determinism()
	test_branch_defeat()
	test_branch_victory()
	test_branch_timeout()
	test_rule_priority()
	test_fallthrough()
	test_innate()
	test_counter_target()
	test_specials()
	test_line_of_sight()
	test_card_merge()
	test_stall_rule()
	test_coordination_cards()
	test_passive_ultimate()
	test_tutorial_battle()

	print("\n=== %d개 검사 / 실패 %d개 ===" % [checks, failures])
	quit(1 if failures > 0 else 0)


func ok(cond: bool, label: String, detail: String = "") -> void:
	checks += 1
	if cond:
		print("  [PASS] %s" % label)
	else:
		failures += 1
		print("  [FAIL] %s  %s" % [label, detail])


# ── 1. 데이터 테이블 ─────────────────────────────────────────────────────

const VALID_CONDS := [
	"always", "enemy_in_range", "enemy_out_of_range", "enemy_within",
	"self_hp_below", "was_hit_last_tick", "enemies_adjacent_at_least",
	"ally_hp_below", "tick_below",
	"other_ally_hp_below", "kept_distance_for", "never",
	"ally_engaged", "killed_last_tick", "team_killed_last_tick",
	"tick_above", "ally_died_last_tick",
]
const VALID_ACTS := [
	"attack", "heal", "move_toward", "move_away", "defend", "hold",
	"move_to_ally",
]
## 궁극기 전용 행동. 전술 카드에는 쓰지 않는다.
const VALID_SPECIAL_ACTS := [
	"point_blank", "focus", "blink_strike", "unyielding", "guard_ally", "bless",
]
const VALID_TARGETS := [
	"self", "nearest_enemy", "farthest_enemy", "lowest_hp_enemy",
	"lowest_hp_ally", "lowest_hp_other_ally", "last_attacker", "all_enemies",
	"backline_enemy",
	"focused_enemy",
]


func test_data_tables() -> void:
	print("[1] 데이터 테이블")

	ok(UnitData.TABLE.size() == 7, "유닛 7종 (플레이 6 + 훈련 표적 1)",
		str(UnitData.TABLE.size()))
	ok(UnitData.playable().size() == 6, "편성 가능한 유닛은 6종",
		str(UnitData.playable().size()))
	ok(not UnitData.playable().has("dummy"), "훈련 표적은 편성 목록에 없다")
	# 12장(각성 폐지) → 13장 → 회피를 빼고 조율 카드 4장을 넣어 16장.
	ok(Cards.TABLE.size() == 18, "카드 18장", str(Cards.TABLE.size()))
	ok(Cards.DECK_ORDER.size() == 18, "DECK_ORDER 18개")
	ok(not Cards.TABLE.has("evade"),
		"회피 폐지 — 조건은 반격과, 행동은 거리 유지와 같아 겹쳤다")
	ok(Stages.count() == 5, "스테이지 5개")

	# 위임 산출물의 최대 함정: Lua 스타일 { key = v } 는 StringName 키를 만든다.
	# Godot 이 둘을 같게 취급해서 우연히 동작하고, 그래서 눈으로는 안 걸린다.
	var all_string_keys := true
	var bad_key := ""
	for tbl in [UnitData.TABLE, Cards.TABLE]:
		for k in tbl.keys():
			if typeof(k) != TYPE_STRING:
				all_string_keys = false
				bad_key = str(k)
			for k2 in (tbl[k] as Dictionary).keys():
				if typeof(k2) != TYPE_STRING:
					all_string_keys = false
					bad_key = "%s.%s" % [k, k2]
	ok(all_string_keys, "모든 키가 String (StringName 아님)", bad_key)

	# 필수 키 존재 검사. 어휘 검사만 있으면 키가 통째로 빠졌을 때
	# Dictionary 접근이 null 을 돌려주면서 조용히 넘어간다 — 실제로 그렇게 당했다.
	const REQUIRED := ["cost", "name", "cond", "cond_arg", "act", "target", "text"]
	var missing := ""
	for cid in Cards.DECK_ORDER:
		if not Cards.TABLE.has(cid):
			missing = "카드 %s 자체가 없음" % cid
			continue
		for key in REQUIRED:
			if not (Cards.TABLE[cid] as Dictionary).has(key):
				missing = "%s 에 '%s' 없음" % [cid, key]
	for r in Innates.BASE:
		for key2 in ["name", "cond", "cond_arg", "act", "target", "text"]:
			if not r.has(key2):
				missing = "공통 기본기 '%s' 에 '%s' 없음" % [r.get("name", "?"), key2]
	for tid2 in Innates.TABLE:
		for r2 in Innates.TABLE[tid2]:
			for key3 in ["name", "cond", "cond_arg", "act", "target", "text"]:
				if not r2.has(key3):
					missing = "%s 기본기에 '%s' 없음" % [tid2, key3]
	ok(missing == "", "카드·기본기에 필수 키가 전부 있다", missing)

	# 카드의 어휘가 규칙 엔진이 아는 값인지. 오타 하나가 push_error 로 새는 걸 막는다.
	var vocab_ok := true
	var vocab_bad := ""
	for cid in Cards.DECK_ORDER:
		ok(Cards.TABLE.has(cid), "DECK_ORDER '%s' 가 TABLE 에 존재" % cid)
		var c: Dictionary = Cards.TABLE[cid]
		if not VALID_CONDS.has(c["cond"]):
			vocab_ok = false; vocab_bad = "%s.cond=%s" % [cid, c["cond"]]
		if not VALID_ACTS.has(c["act"]):
			vocab_ok = false; vocab_bad = "%s.act=%s" % [cid, c["act"]]
		if not VALID_TARGETS.has(c["target"]):
			vocab_ok = false; vocab_bad = "%s.target=%s" % [cid, c["target"]]
		if typeof(c["cond_arg"]) != TYPE_INT:
			vocab_ok = false; vocab_bad = "%s.cond_arg 가 int 아님" % cid
	ok(vocab_ok, "카드 어휘가 규칙 엔진과 일치", vocab_bad)

	# 라벨 문자열은 영상에 그대로 뜬다. 비어 있거나 화살표가 없으면 안 된다.
	var text_ok := true
	var text_bad := ""
	for cid in Cards.DECK_ORDER:
		var t: String = Cards.TABLE[cid]["text"]
		if t.is_empty() or not t.contains("→"):
			text_ok = false; text_bad = "%s: '%s'" % [cid, t]
	ok(text_ok, "모든 카드 라벨에 '→' 포함", text_bad)

	# 스테이지의 적 배치가 적 진영 안에 있고 서로 겹치지 않는지.
	for s in Stages.TABLE:
		var seen := {}
		var placement_ok := true
		for e in s["enemies"]:
			var p: Vector2i = e["pos"]
			if not Grid.ENEMY_SLOTS.has(p) or seen.has(p):
				placement_ok = false
			seen[p] = true
			if not UnitData.TABLE.has(e["type"]):
				placement_ok = false
			for c in e["cards"]:
				if not Cards.TABLE.has(c):
					placement_ok = false
		ok(placement_ok, "스테이지 %d 배치 유효" % s["id"])


# ── 2. 격자 ──────────────────────────────────────────────────────────────

func test_grid() -> void:
	print("\n[2] 격자 / 이동")

	ok(Grid.manhattan(Vector2i(0, 0), Vector2i(3, 2)) == 5, "맨해튼 거리")
	ok(Grid.in_bounds(Vector2i(7, 5)), "경계 내부")
	ok(not Grid.in_bounds(Vector2i(8, 0)), "경계 외부 x")
	ok(not Grid.in_bounds(Vector2i(0, 6)), "경계 외부 y")

	# 빈 격자에서 오른쪽으로 한 칸
	ok(Grid.step_toward(Vector2i(0, 2), Vector2i(5, 2), {}) == Vector2i(1, 2),
		"직선 접근")

	# 정면이 막히면 우회한다. DIRS 순서상 아래(0,1)를 먼저 시도한다.
	var blocked := { Vector2i(1, 2): true }
	var detour := Grid.step_toward(Vector2i(0, 2), Vector2i(5, 2), blocked)
	ok(detour != Vector2i(0, 2) and detour != Vector2i(1, 2),
		"막힌 정면 우회", str(detour))

	# 후퇴
	ok(Grid.step_away(Vector2i(3, 2), Vector2i(5, 2), {}) == Vector2i(2, 2),
		"이탈")
	# 벽에 몰리면 제자리
	ok(Grid.step_away(Vector2i(0, 0), Vector2i(1, 0), {}) == Vector2i(0, 1),
		"모서리에서 수직 이탈")

	# 완전 포위 → 제자리
	var caged := {
		Vector2i(1, 2): true, Vector2i(3, 2): true,
		Vector2i(2, 1): true, Vector2i(2, 3): true,
	}
	ok(Grid.step_toward(Vector2i(2, 2), Vector2i(7, 2), caged) == Vector2i(2, 2),
		"포위 시 제자리")


# ── 3. 결정론 ────────────────────────────────────────────────────────────

func make_battle(stage_id: int, party: Array) -> Battle:
	var b := Battle.new()
	b.setup(stage_id, party)
	return b


func trace(stage_id: int, party: Array) -> Array[String]:
	var b := make_battle(stage_id, party)
	var out: Array[String] = [b.snapshot()]
	while b.step():
		out.append(b.snapshot())
	out.append(b.snapshot())
	return out


func test_determinism() -> void:
	print("\n[3] 결정론")

	var party := [
		{ "type": "warrior", "slot": 3, "cards": ["charge", "engage"] },
		{ "type": "archer",  "slot": 1, "cards": ["keep_distance", "engage"] },
		{ "type": "bard",  "slot": 2, "cards": ["mend", "engage"] },
	]

	var a := trace(1, party)
	var b := trace(1, party)
	var c := trace(1, party)

	ok(a.size() > 1, "전투가 최소 1틱 진행됨", str(a.size()))
	ok(a == b and b == c, "3회 실행 스냅샷 수열 완전 일치",
		"len %d/%d/%d" % [a.size(), b.size(), c.size()])

	# 스테이지 2도 동일하게
	var d := trace(2, party)
	var e := trace(2, party)
	ok(d == e, "스테이지 2 재현성")

	# 배치를 한 칸만 바꾸면 결과 수열이 달라져야 한다 (= 상태가 실제로 반영된다)
	var party2 := party.duplicate(true)
	party2[1]["slot"] = 4
	var f := trace(1, party2)
	ok(f != a, "배치가 바뀌면 전개가 달라짐")


# ── 4~6. 종료 분기 ───────────────────────────────────────────────────────

func report(b: Battle, label: String) -> void:
	var p := b.living_count(Unit.TEAM_PLAYER)
	var e := b.living_count(Unit.TEAM_ENEMY)
	print("      %s → %s (tick %d, 아군 %d / 적 %d)" % [label, b.result, b.tick, p, e])


func test_branch_defeat() -> void:
	print("
[4] 종료 분기: 패배")
	# 패배 분기를 실제로 밟는 편성이어야 한다. 예전엔 스테이지 2 에 궁수 3명을
	# 세워 놓고 "화력 교환에서 밀려 전멸" 을 기대했는데, 유닛 개편으로 궁수가
	# 적과 대칭이 되면서 그 편성이 오히려 이겨 버렸다. 분기가 통째로 안 밟혔다.
	#
	# 지금은 확실히 지는 편성을 쓴다: 악사(공 9, HP 72) 셋을 최종 스테이지에.
	# 딜이 없어서 적을 못 줄이고, 서로 회복만 하다 갈린다.
	var party := [
		{ "type": "bard", "slot": 3, "cards": ["engage"] },
		{ "type": "bard", "slot": 4, "cards": ["engage"] },
		{ "type": "bard", "slot": 5, "cards": ["engage"] },
	]
	var b := make_battle(5, party)
	b.run()
	report(b, "악사 3명 / 교전만 (스테이지 5)")
	ok(b.result == Battle.RESULT_DEFEAT, "전멸 시 패배", b.result)
	ok(b.living_count(Unit.TEAM_PLAYER) == 0, "아군 생존 0")


func test_branch_victory() -> void:
	print("\n[5] 종료 분기: 승리")
	var party := [
		{ "type": "shieldman", "slot": 4, "cards": ["engage", "charge"] },
		{ "type": "archer",    "slot": 0, "cards": ["engage", "pursue"] },
		{ "type": "archer",    "slot": 2, "cards": ["engage", "pursue"] },
	]
	var b := make_battle(1, party)
	b.run()
	report(b, "방패 앞 + 궁수2 뒤")
	ok(b.result == Battle.RESULT_VICTORY, "적 전멸 시 승리", b.result)
	ok(b.living_count(Unit.TEAM_ENEMY) == 0, "적 생존 0")


func test_branch_timeout() -> void:
	print("
[6] 종료 분기: 교착")

	# ── 규칙을 검사하지 시나리오를 검사하지 않는다 ───────────────────────
	# 예전엔 "카이팅 편성으로 스테이지 2 를 돌리면 교착이 난다" 로 검사했다.
	# 그런데 스테이지 밸런스를 손댈 때마다 그 편성이 이기거나 지면서 검사가
	# 깨졌다 - 두 번 겪었다. 밸런스를 고칠 때 규칙 검사가 깨지면, 규칙이 아니라
	# 그 판의 수치를 검사하고 있었다는 뜻이다.
	#
	# 확인할 명제는 하나다: **피해 없이 STALL_LIMIT 틱이 지나면 패배로 끝난다.**
	# 그건 어느 스테이지에서든 같아야 하므로 판정을 직접 부른다.
	var b := make_battle(3, [
		{ "type": "shieldman", "slot": 0, "cards": ["guard_stance"] },
	])
	b.step()
	ok(b.result == Battle.RESULT_ONGOING, "아직은 진행 중", b.result)

	b.last_damage_tick = b.tick - Battle.STALL_LIMIT
	b._check_result()
	ok(b.result == Battle.RESULT_DEFEAT, "정체가 이어지면 패배", b.result)
	ok(b.tick < Battle.MAX_TICKS, "60틱을 다 기다리지 않는다",
		"%d틱 (상한 %d)" % [b.tick, Battle.MAX_TICKS])
	ok(b.living_count(Unit.TEAM_PLAYER) > 0 and b.living_count(Unit.TEAM_ENEMY) > 0,
		"양쪽이 살아 있는 채로 끝난다 (진짜 교착)")

	# 피해가 계속 나면 정체로 끊기지 않는다. 반대편도 같이 봐야 규칙이
	# "느린 빌드를 벌주는 것" 으로 변질되지 않았음이 보장된다.
	var b2 := make_battle(1, [
		{ "type": "warrior", "slot": 0, "cards": ["engage", "charge"] },
		{ "type": "warrior", "slot": 2, "cards": ["engage", "charge"] },
		{ "type": "warrior", "slot": 4, "cards": ["engage", "charge"] },
	])
	b2.run()
	report(b2, "전사3 / 교전 (스테이지 1)")
	ok(b2.result != Battle.RESULT_TIMEOUT, "치고받는 판은 제때 끝난다", b2.result)



# ── 7. 우선순위 = 전략 ───────────────────────────────────────────────────

func first_rule_of(b: Battle, unit_index: int) -> String:
	for e in b.events:
		if e["type"] == "rule" and e["unit"] == unit_index:
			return e["card_id"]
	return ""


func test_rule_priority() -> void:
	print("\n[7] 슬롯 순서가 행동을 바꾼다")

	# 같은 카드 2장, 순서만 반대. 궁수는 사거리 3이라 시작 시 적이 사거리 밖이다.
	var forward := [{ "type": "archer", "slot": 1, "cards": ["charge", "hold_ground"] }]
	var reverse := [{ "type": "archer", "slot": 1, "cards": ["hold_ground", "charge"] }]

	var bf := make_battle(1, forward)
	bf.step()
	var br := make_battle(1, reverse)
	br.step()

	ok(first_rule_of(bf, 0) == "charge", "[돌격, 사수] → 돌격", first_rule_of(bf, 0))
	ok(first_rule_of(br, 0) == "hold_ground", "[사수, 돌격] → 사수", first_rule_of(br, 0))

	# ── 영상 10~22초 구간이 그대로 성립하는지 ──────────────────────────────
	# 기획서의 핵심 장면: 궁수의 1번 규칙을 `교전` 에서 `거리 유지` 로 한 장만 바꾸면
	# DEFEAT 가 VICTORY 로 뒤집힌다. 스테이지 2에서 정확히 재현된다.
	#
	# 교전을 1번에 두면 사거리에 들어온 순간부터 제자리에서 쏘다가 붙잡혀 죽고,
	# 거리 유지를 1번에 두면 물러나며 쏜다. 접근 자체는 직업 기본기가 알아서 한다.
	var glued := [
		{ "type": "archer", "slot": 3, "cards": ["engage", "pursue"] },
		{ "type": "archer", "slot": 4, "cards": ["engage", "pursue"] },
		{ "type": "archer", "slot": 5, "cards": ["engage", "pursue"] },
	]
	var kiting := [
		{ "type": "archer", "slot": 3, "cards": ["keep_distance", "engage"] },
		{ "type": "archer", "slot": 4, "cards": ["keep_distance", "engage"] },
		{ "type": "archer", "slot": 5, "cards": ["keep_distance", "engage"] },
	]
	# 스테이지 2 는 악사를 빼면서 카이팅으로도 이길 수 있게 됐다. 순서 대조는
	# 회복이 낀 지구전(3스테이지)에서 더 선명하다 - 물러나기만 하면 적이 계속
	# 회복해서 영영 못 줄인다.
	var b1 := make_battle(3, glued)
	b1.run()
	report(b1, "궁수 1번 = 교전 (스테이지 3)")
	var b2 := make_battle(3, kiting)
	b2.run()
	report(b2, "궁수 1번 = 거리 유지 (스테이지 3)")

	# ── 이 대조는 유닛 개편으로 방향이 뒤집혔다 ───────────────────────────
	# 예전 수치에서는 스테이지 2 의 적이 화력에서 앞서서 "물러나며 쏴야 이긴다"
	# 였다. 지금은 궁수가 사거리 3·공 24 로 적과 완전한 대칭이 됐고, 그러면
	# **먼저 쏘는 쪽이 이긴다**. 그래서 [거리 유지] 를 1번에 두면 양쪽이 같이
	# 물러나며 아무도 방아쇠를 안 당겨 60틱 교착으로 끝난다.
	#
	# 가르치는 명제 자체는 그대로다: 같은 카드 두 장의 **순서만** 바꿨는데
	# 승리와 교착으로 갈린다. 방향이 바뀌었을 뿐이라 테스트도 측정값에 맞춘다.
	ok(b1.result == Battle.RESULT_VICTORY, "교전을 1번에 두면 이긴다", b1.result)
	# 정체 규칙이 들어오면서 교착이 타임아웃이 아니라 패배가 됐다. 가르치는
	# 명제는 오히려 더 선명해졌다 - 같은 카드 두 장의 **순서만** 바꿨는데
	# 한쪽은 이기고 한쪽은 진다.
	ok(b2.result == Battle.RESULT_DEFEAT, "거리 유지로 바꾸면 진다", b2.result)
	ok(b1.result != b2.result,
		"카드 한 장 교체로 승패가 뒤집힘", "%s → %s" % [b1.result, b2.result])


# ── 8. 폴스루 ────────────────────────────────────────────────────────────

func test_fallthrough() -> void:
	print("\n[8] 폴스루 (실행 불가능한 규칙은 다음 슬롯에 양보)")

	# 전사 [돌격, 교전]. 사거리 밖이면 돌격, 붙으면 교전이어야 한다.
	var party := [{ "type": "warrior", "slot": 3, "cards": ["charge", "engage"] }]
	var b := make_battle(1, party)

	var saw_charge := false
	var saw_engage := false
	for _i in 20:
		if not b.step():
			break
	for e in b.events:
		if e["type"] == "rule" and e["unit"] == 0:
			if e["card_id"] == "charge":
				saw_charge = true
			elif e["card_id"] == "engage":
				saw_engage = true

	ok(saw_charge, "사거리 밖에서는 돌격(슬롯1)이 발동")
	ok(saw_engage, "사거리 안에서는 교전(슬롯2)으로 폴스루")

	# 폴스루가 없으면 돌격(조건=항상)이 영원히 이겨서 교전이 절대 안 뜬다.
	# 즉 이 검사가 스테이지 1의 적 전략이 성립하는지를 그대로 확인한다.
	var attacks := 0
	for e in b.events:
		if e["type"] == "attack" and e["unit"] == 0:
			attacks += 1
	ok(attacks > 0, "돌격+교전 조합이 실제로 공격까지 도달", str(attacks))


# ── 9. 직업 기본기 ───────────────────────────────────────────────────────

func test_innate() -> void:
	print("\n[9] 직업 기본기 (카드가 없어도 유닛은 움직인다)")

	# 기본기 목록 자체가 규칙 엔진 어휘를 지키는지 — 오타 하나가 push_error 로 샌다.
	var vocab_ok := true
	var bad := ""
	for tid in UnitData.TABLE.keys():
		for r in Innates.for_unit(String(tid)):
			for key in ["name", "cond", "cond_arg", "act", "target", "text"]:
				if not r.has(key):
					vocab_ok = false; bad = "%s: %s 없음" % [tid, key]
			if not VALID_CONDS.has(r.get("cond", "")):
				vocab_ok = false; bad = "%s.cond=%s" % [tid, r.get("cond", "")]
			if not VALID_ACTS.has(r.get("act", "")):
				vocab_ok = false; bad = "%s.act=%s" % [tid, r.get("act", "")]
			if not VALID_TARGETS.has(r.get("target", "")):
				vocab_ok = false; bad = "%s.target=%s" % [tid, r.get("target", "")]
	ok(vocab_ok, "5종 전부 기본기 어휘가 엔진과 일치", bad)

	for tid in UnitData.TABLE.keys():
		ok(Innates.for_unit(String(tid)).size() >= Innates.BASE.size(),
			"%s 가 공통 골격을 갖는다" % UnitData.TABLE[tid]["name"])

	# 카드 0장으로 전투가 성립하는가 — 이게 이번 변경의 핵심.
	var bare := [
		{ "type": "warrior", "slot": 4, "cards": [] },
		{ "type": "archer",  "slot": 0, "cards": [] },
		{ "type": "archer",  "slot": 2, "cards": [] },
	]
	var b := make_battle(1, bare)
	b.run()
	report(b, "카드 0장 (기본기만)")
	ok(b.result != Battle.RESULT_ONGOING, "빈손으로도 전투가 끝까지 간다", b.result)

	var idle := 0
	var acted := 0
	for e in b.events:
		if e["type"] == "idle":
			idle += 1
		elif e["type"] == "rule":
			acted += 1
	ok(acted > 0, "빈손 유닛이 실제로 행동한다", "행동 %d회" % acted)
	print("      행동 %d회 / 멍때림 %d회" % [acted, idle])

	# 예전 버그: 카드가 없으면 전원 idle 이었다. 이제 idle 이 압도적이면 회귀다.
	ok(acted > idle, "행동이 멍때림보다 많다", "%d vs %d" % [acted, idle])

	var used_innate := false
	for e in b.events:
		if e["type"] == "rule" and bool(e.get("innate", false)):
			used_innate = true
	ok(used_innate, "기본기 발동이 이벤트로 표시된다")

	# 산 카드가 기본기보다 항상 우선해야 한다. 이 순서가 뒤집히면 게임이 죽는다.
	#
	# 사수는 `적이 사거리 밖` 일 때만 발동하므로 뒷자리(slot 0 = x1)에 세운다.
	# 앞자리(slot 3 = x2)면 시작부터 적이 궁수 사거리 3 안에 있어 조건이 거짓이 된다.
	# 이때 기본기가 "제자리 유지" 를 덮고 전진하는지를 보는 것이 이 검사의 핵심이다.
	var carded := [{ "type": "archer", "slot": 0, "cards": ["hold_ground"] }]
	var b2 := make_battle(1, carded)
	b2.step()
	var first := ""
	var was_innate := true
	for e in b2.events:
		if e["type"] == "rule" and e["unit"] == 0:
			first = String(e["card_id"])
			was_innate = bool(e.get("innate", false))
			break
	ok(first == "hold_ground" and not was_innate,
		"꽂은 카드가 기본기를 이긴다", "%s (innate=%s)" % [first, was_innate])

	# 암살자의 tick_below 기본기 — 개전 직후에만 발동해야 한다.
	var assassin := [{ "type": "assassin", "slot": 3, "cards": [] }]
	var b3 := make_battle(1, assassin)
	var early := false
	var late := false
	for _i in 8:
		if not b3.step():
			break
	for e in b3.events:
		if e["type"] == "rule" and e["unit"] == 0 and String(e.get("rule_name", "")) == "암살자의 급습":
			if e.has("tick"):
				pass
	# 급습은 3틱 안에만 나와야 하므로, 발동 횟수가 3을 넘으면 조건이 샌 것이다.
	var rush := 0
	for e in b3.events:
		if e["type"] == "rule" and String(e.get("rule_name", "")) == "암살자의 급습":
			rush += 1
	ok(rush <= 3, "급습(tick_below 4)은 3틱까지만 발동", "%d회" % rush)
	ok(rush > 0, "급습이 실제로 발동한다", "%d회" % rush)


# ── 10. 반격 대상 되짚기 ─────────────────────────────────────────────────

func test_counter_target() -> void:
	print("\n[10] 반격 — 때린 적을 되짚는다")

	# Unit 이 서로를 직접 참조하면 RefCounted 순환이 생겨 전투가 끝나도 해제되지
	# 않는다(실측 확인). 그래서 index 로 들고 여기서 되짚는다.
	# 이 검사는 그 되짚기가 실제로 맞는 대상을 찾는지 지킨다.
	var party := [
		{ "type": "shieldman", "slot": 4, "cards": ["counter", "engage"] },
		{ "type": "archer",    "slot": 0, "cards": ["engage"] },
		{ "type": "archer",    "slot": 2, "cards": ["engage"] },
	]
	var b := make_battle(1, party)
	for _i in 20:
		if not b.step():
			break

	# 이벤트를 순서대로 훑으며 "그 시점에 나를 마지막으로 때린 적" 을 재구성한다.
	# 전투가 끝난 뒤의 last_attacker_index 와 비교하면 안 된다 — 틱마다 바뀌기 때문이다.
	var countered := 0
	var checked := 0
	var bad := ""
	var last_hitter := -1

	for i in b.events.size():
		var e: Dictionary = b.events[i]
		if e["type"] == "attack" and int(e["target"]) == 0:
			last_hitter = int(e["unit"])
			continue
		if e["type"] != "rule" or int(e["unit"]) != 0 or String(e["card_id"]) != "counter":
			continue
		countered += 1
		var expected := last_hitter
		for j in range(i + 1, mini(i + 4, b.events.size())):
			var a: Dictionary = b.events[j]
			if a["type"] == "attack" and int(a["unit"]) == 0:
				checked += 1
				if expected >= 0 and int(a["target"]) != expected:
					bad = "기대 %d, 실제 %d" % [expected, int(a["target"])]
				break

	ok(countered > 0, "반격이 실제로 발동한다", "%d회" % countered)
	ok(checked > 0, "반격 뒤 공격 이벤트를 확인했다", "%d건" % checked)
	ok(bad == "", "반격 대상이 나를 때린 적과 일치", bad)
	ok(b.units[0].last_attacker_index >= 0,
		"피격 시 공격자 index 가 기록된다", str(b.units[0].last_attacker_index))


# ── 11. 특수 스킬 ────────────────────────────────────────────────────────

func test_specials() -> void:
	print("
[11] 궁극기 — 우선발동 · 전투당 1회 · 직업 전용")

	# 어휘 검사. 오타 하나가 push_error 로 새는 걸 막는다.
	var vocab_ok := true
	var bad := ""
	for sid in Specials.ORDER:
		var sp: Dictionary = Specials.TABLE[sid]
		for key in ["name", "unit", "cost", "weight", "cond", "cond_arg",
				"act", "act_arg", "power", "target", "text"]:
			if not sp.has(key):
				vocab_ok = false; bad = "%s: %s 없음" % [sid, key]
		if not VALID_CONDS.has(sp.get("cond", "")):
			vocab_ok = false; bad = "%s.cond=%s" % [sid, sp.get("cond", "")]
		if not VALID_SPECIAL_ACTS.has(sp.get("act", "")):
			vocab_ok = false; bad = "%s.act=%s" % [sid, sp.get("act", "")]
		if not UnitData.TABLE.has(sp.get("unit", "")):
			vocab_ok = false; bad = "%s.unit=%s" % [sid, sp.get("unit", "")]
		if int(sp.get("weight", 0)) < 1:
			vocab_ok = false; bad = "%s 등장 가중치가 1 미만" % sid
	ok(vocab_ok, "궁극기 어휘가 엔진과 일치", bad)

	# 6종 전부 자기 특수를 하나씩 갖는가
	# 훈련 표적은 특수가 필요 없다. 플레이 가능한 유닛만 센다.
	var covered := 0
	for tid in UnitData.playable():
		if Specials.for_unit(tid) != "":
			covered += 1
	ok(covered == UnitData.playable().size(),
		"편성 가능한 %d종 전부 궁극기를 갖는다" % UnitData.playable().size(), str(covered))

	# 직업 전용 — 안 맞는 조합은 장착 자체가 거부돼야 한다
	ok(Specials.usable_by("keep_off", "musketeer"), "총사는 거리두기 가능")
	ok(not Specials.usable_by("keep_off", "warrior"), "전사는 거리두기 불가")

	# 패시브는 규칙 후보로 올라오면 안 된다. 올라오면 전사가 매 틱 "아무것도
	# 아닌 것" 을 고르고 실제 행동을 못 한다.
	ok(Specials.is_passive("unyielding"), "불굴의 의지는 패시브")
	ok(not Specials.is_passive("keep_off"), "거리두기는 패시브가 아니다")

	# 총사의 후퇴사격이 실제로 터지는가. 적 3명이 붙는 스테이지 1로 검증한다.
	# 특수를 전술보다 먼저 보게 설정한다. 기본값은 "전술 먼저" 라서
	# 슬롯 1의 교전이 항상 선수를 치고 특수가 발동하지 못한다.
	var party := [
		{ "type": "musketeer", "slot": 4, "cards": ["engage"],
		  "special": "keep_off", "special_first": true },
		{ "type": "archer", "slot": 0, "cards": ["engage"] },
		{ "type": "archer", "slot": 2, "cards": ["engage"] },
	]
	var b := make_battle(1, party)
	b.run()
	report(b, "총사(후퇴사격) + 궁수2")

	var fired := 0
	var multi := 0
	var moved := 0
	var first_tick := -1
	var ticks: Array[int] = []
	var tick_now := 0
	for e in b.events:
		if e["type"] == "tick_begin":
			tick_now = int(e["tick"])
		elif e["type"] == "special" and int(e["unit"]) == 0:
			fired += 1
			ticks.append(tick_now)
			if first_tick < 0:
				first_tick = tick_now
			if (e["hits"] as Array).size() >= 2:
				multi += 1
			if e["from"] != e["to"]:
				moved += 1

	ok(fired > 0, "거리두기가 발동한다", "%d회" % fired)
	ok(moved > 0, "타격 후 실제로 물러난다", "이동 %d회" % moved)
	print("      발동 틱: %s (다중타격 %d회)" % [str(ticks), multi])

	# 전투당 1회 — 이게 궁극기와 전술을 가르는 유일한 규칙이다.
	# 두 번 터지면 위력 135%% 짜리 광역기가 매 틱 나가는 것과 다름없어진다.
	ok(fired == 1, "궁극기는 전투당 딱 한 번만 발동한다", "%d회" % fired)

	# 우선발동 — 특수가 터진 틱에는 그 유닛의 규칙 카드가 같이 발동하면 안 된다
	var double_act := false
	var acted_this_tick := false
	for e in b.events:
		if e["type"] == "tick_begin":
			acted_this_tick = false
		elif e["type"] == "rule" and int(e["unit"]) == 0:
			if acted_this_tick:
				double_act = true
			acted_this_tick = true
	ok(not double_act, "한 틱에 규칙은 하나만 발동한다")

	# 특수는 rule 이벤트에도 special=true 로 표시돼야 한다 (화면 구분용)
	var flagged := false
	for e in b.events:
		if e["type"] == "rule" and bool(e.get("special", false)):
			flagged = true
	ok(flagged, "특수 발동이 이벤트에 표시된다")

	# 결정론 — 특수가 끼어도 재현돼야 한다. 여기가 깨지면 영상 재촬영이 불가능하다.
	var t1 := trace(1, party)
	var t2 := trace(1, party)
	ok(t1 == t2, "특수 스킬이 있어도 결정론 유지", "%d vs %d" % [t1.size(), t2.size()])

	# ── 우선순위 토글이 실제로 작동하는가 ──────────────────────────────
	# 이게 이 게임의 명제다. "특수 무조건 최우선" 이면 슬롯 1~3 이 무시되어
	# 우선순위가 곧 전략이라는 전제가 깨진다. 실제로 관통사격을 낀 궁수가
	# 거리 유지를 영영 발동 못 하는 문제가 났었다.
	var later := [
		{ "type": "musketeer", "slot": 4, "cards": ["engage"],
		  "special": "keep_off", "special_first": false },
		{ "type": "archer", "slot": 0, "cards": ["engage"] },
		{ "type": "archer", "slot": 2, "cards": ["engage"] },
	]
	var b4 := make_battle(1, later)
	b4.run()
	var late_fired := 0
	for e in b4.events:
		if e["type"] == "rule" and int(e["unit"]) == 0 and bool(e.get("special", false)):
			late_fired += 1
	ok(late_fired == 0,
		"'전술 먼저' 면 슬롯1 교전이 선수를 쳐 특수가 발동하지 않는다", "%d회" % late_fired)
	ok(fired > 0 and late_fired < fired,
		"우선순위 토글이 실제로 발동 여부를 바꾼다", "먼저 %d회 / 나중 %d회" % [fired, late_fired])

	# 슬롯이 비어 있으면 '전술 먼저' 라도 특수가 발동한다 — 막힌 게 아니라 양보한 것
	var empty_slots := [
		{ "type": "musketeer", "slot": 4, "cards": [],
		  "special": "keep_off", "special_first": false },
		{ "type": "archer", "slot": 0, "cards": ["engage"] },
		{ "type": "archer", "slot": 2, "cards": ["engage"] },
	]
	var b5 := make_battle(1, empty_slots)
	b5.run()
	var yield_fired := 0
	for e in b5.events:
		if e["type"] == "rule" and int(e["unit"]) == 0 and bool(e.get("special", false)):
			yield_fired += 1
	ok(yield_fired > 0, "슬롯이 비면 '전술 먼저' 라도 특수가 발동한다", "%d회" % yield_fired)

	# 직업이 안 맞는 특수는 조용히 버려져야 한다
	var wrong := [{ "type": "warrior", "slot": 4, "cards": ["engage"],
		"special": "keep_off" }]
	var b2 := make_battle(1, wrong)
	ok(b2.units[0].special == "", "직업이 안 맞으면 장착되지 않는다", b2.units[0].special)


# ── 12. 차폐 (LOS) ───────────────────────────────────────────────────────

func test_line_of_sight() -> void:
	print("
[12] 차폐 — 원거리 공격이 몸통을 뚫지 못한다")

	# 사이에 낀 칸 계산. 양 끝은 빼야 한다.
	var cells := Grid.line_cells(Vector2i(0, 0), Vector2i(3, 0))
	ok(cells == [Vector2i(1, 0), Vector2i(2, 0)], "직선 사이 칸", str(cells))
	ok(Grid.line_cells(Vector2i(2, 2), Vector2i(3, 2)).is_empty(), "인접이면 사이 칸 없음")
	ok(Grid.line_cells(Vector2i(1, 1), Vector2i(1, 1)).is_empty(), "같은 칸이면 빈 배열")

	ok(Grid.has_line_of_sight(Vector2i(0, 2), Vector2i(4, 2), {}), "빈 격자면 뚫림")
	ok(not Grid.has_line_of_sight(Vector2i(0, 2), Vector2i(4, 2), { Vector2i(2, 2): true }),
		"사이에 유닛이 있으면 막힘")
	ok(Grid.has_line_of_sight(Vector2i(0, 2), Vector2i(1, 2), { Vector2i(1, 2): true }),
		"인접은 대상 자신이 막지 않는다")

	# 실전: 적 방패병이 자기 뒤의 악사를 가려야 한다.
	var party := [
		{ "type": "archer", "slot": 1, "cards": ["engage"] },
		{ "type": "archer", "slot": 0, "cards": ["engage"] },
		{ "type": "archer", "slot": 2, "cards": ["engage"] },
	]
	var b := make_battle(3, party)   # 방패병 2 + 악사(뒤)
	b.run()
	report(b, "궁수3 vs 방벽(스테이지 3)")

	# 궁수가 벽 뒤 악사를 먼저 노리지 않고 앞의 방패병부터 치는지
	var first_target := -1
	for e in b.events:
		if e["type"] == "attack" and int(e["unit"]) <= 2:
			first_target = int(e["target"])
			break
	ok(first_target >= 0, "궁수가 공격은 한다", str(first_target))
	if first_target >= 0:
		ok(b.units[first_target].type_id == "shieldman",
			"벽에 가려 뒤의 악사 대신 방패병을 친다", b.units[first_target].type_id)

	# 차폐가 실제로 대상 후보를 줄이는가
	var b2 := make_battle(3, party)
	var shooter: Unit = b2.units[0]
	var all_enemies: int = b2.living_enemies_of(shooter).size()
	var shootable: int = b2.shootable_enemies_of(shooter).size()
	ok(shootable <= all_enemies, "쏠 수 있는 적은 전체 이하", "%d / %d" % [shootable, all_enemies])
	print("      시작 시점: 적 %d명 중 %d명만 사선이 열림" % [all_enemies, shootable])

	# 관통사격은 차폐를 뚫는다 — 그게 이 스킬의 값어치다
	var pierce_party := [
		{ "type": "archer", "slot": 1, "cards": [],
		  "special": "focus_fire", "special_first": true },
		{ "type": "archer", "slot": 0, "cards": ["engage"] },
		{ "type": "archer", "slot": 2, "cards": ["engage"] },
	]
	var b3 := make_battle(3, pierce_party)
	b3.run()
	var pierced := 0
	var multi := 0
	for e in b3.events:
		if e["type"] == "special" and int(e["unit"]) == 0:
			pierced += 1
			if (e["hits"] as Array).size() >= 2:
				multi += 1
	ok(pierced > 0, "관통사격이 발동한다", "%d회" % pierced)
	print("      관통사격 %d회 (그중 2명 이상 관통 %d회)" % [pierced, multi])

	# 결정론은 차폐가 끼어도 유지돼야 한다
	var t1 := trace(3, party)
	var t2 := trace(3, party)
	ok(t1 == t2, "차폐가 있어도 결정론 유지")


# ── 13. 튜토리얼 전투 ────────────────────────────────────────────────────

func test_card_merge() -> void:
	print("
[12-c] 카드 합성")

	# ── 화면만 바뀌고 전투는 그대로인 것이 최악이다 ──────────────────────
	# 규칙 엔진이 Cards.TABLE 을 직접 읽으면 합성 단계가 통째로 무시된다.
	# 카드에는 "교전++ 위력 140%" 라고 떠 있는데 실제로는 100% 로 때리게 된다.
	# 오류도 안 나고 화면도 멀쩡하다. 그래서 **실제 피해량**으로 검사한다.
	var dmg := func(level: int) -> int:
		var u := Unit.create(0, "warrior", Unit.TEAM_PLAYER, Vector2i(1, 1),
			["engage"], "", 0, false, { "engage": level })
		return u.power_damage(int(u.card_rules[0].get("power", 100)))

	var d1: int = dmg.call(1)
	var d3: int = dmg.call(3)
	print("      교전 피해 - 1단계 %d / 3단계 %d" % [d1, d3])
	ok(d3 > d1, "합성하면 실제 피해가 늘어난다", "%d -> %d" % [d1, d3])

	# 이름과 문장도 따라와야 한다. 안 그러면 뭐가 올랐는지 화면에서 못 읽는다.
	var lv3: Dictionary = Cards.leveled("engage", 3)
	ok(String(lv3["name"]).begins_with("교전") and String(lv3["name"]) != "교전",
		"이름에 단계가 드러난다", String(lv3["name"]))
	ok(String(lv3["text"]).contains("140"), "문장에 실제 위력이 적힌다", String(lv3["text"]))

	# 위력 표기가 단계마다 덧붙어 늘어나면 안 된다.
	ok(String(lv3["text"]).count("위력") == 1, "위력 표기가 중복되지 않는다",
		String(lv3["text"]))

	# 이동 카드는 칸 수가, 회복 카드는 회복량이 오른다.
	ok(int(Cards.leveled("charge", 3)["move_bonus"])
		> int(Cards.TABLE["charge"].get("move_bonus", 0)), "이동 카드는 칸 수가 는다")
	ok(int(Cards.leveled("mend", 2).get("heal_bonus", 0)) > 0, "회복 카드는 회복량이 는다")

	# 올릴 수치가 없는 카드는 합성 대상이 아니다.
	ok(not Cards.can_merge("hold_ground"), "사수는 합성할 수 없다")

	# ── 합성 규칙 ────────────────────────────────────────────────────────
	var r := RunState.new()
	r.fixed_seed = 1
	r.start_run(1)
	ok(not r.can_merge("engage"), "1장으로는 합성 못 한다")
	for _i in Cards.MERGE_COPIES:
		r.hand.append("engage")
	ok(r.can_merge("engage"), "%d장이면 합성할 수 있다" % Cards.MERGE_COPIES)

	# ── 합성은 예산을 쓴다 ───────────────────────────────────────────────
	# 공짜였을 때는 2장만 모이면 무조건 하는 게 이득이라 저울질이 없었다.
	# 런 시뮬레이션에서 런당 4.6회씩 터져 "선택" 이 아니라 루틴이 됐다.
	var price := r.merge_price("engage")
	ok(price > 0, "합성에 예산이 든다", str(price))
	r.budget = price - 1
	ok(not r.can_merge("engage"), "예산이 모자라면 합성할 수 없다")
	r.budget = 99

	var before := r.budget
	ok(r.merge("engage"), "합성 성공")
	ok(r.budget == before - price, "예산이 정확히 깎인다",
		"%d -> %d (값 %d)" % [before, r.budget, price])

	# 단계가 오를수록 비싸진다. 3단계까지 가는 것이 진짜 투자여야 한다.
	ok(r.merge_price("engage") > price, "다음 단계는 더 비싸다",
		"%d -> %d" % [price, r.merge_price("engage")])
	ok(r.card_level("engage") == 2, "단계가 올랐다", str(r.card_level("engage")))
	# 2장을 넣고 1장이 남는다. 전부 소모하면 "합성했더니 쓸 카드가 없다" 가 된다.
	ok(r.copies_of("engage") == 1, "합성 후 한 장이 남는다", str(r.copies_of("engage")))

	# 최고 단계를 넘길 수 없다.
	r.card_levels["engage"] = Cards.MAX_LEVEL
	for _i in Cards.MERGE_COPIES:
		r.hand.append("engage")
	ok(not r.can_merge("engage"), "최고 단계에서는 더 못 올린다")

	# 새 런에서는 초기화된다.
	r.start_run(1)
	ok(r.card_levels.is_empty(), "새 런에서 합성 단계가 초기화된다")


func test_stall_rule() -> void:
	print("
[12-b] 정체 자동 종료")

	# 아무도 피해를 못 입힌 채 STALL_LIMIT 틱이 지나면 패배로 끝난다.
	# 이게 없으면 양쪽이 카이팅에 들어간 뒤 60틱까지 아무 일도 안 일어난다.

	# 악사 셋. 딜이 거의 없어서 적을 못 줄인다 -> 정체가 나야 한다.
	var stall := [
		{ "type": "bard", "slot": 0, "cards": ["keep_distance"] },
		{ "type": "bard", "slot": 2, "cards": ["keep_distance"] },
		{ "type": "bard", "slot": 4, "cards": ["keep_distance"] },
	]
	# ── 규칙 자체를 직접 검사한다 ────────────────────────────────────────
	# 처음엔 "회복만 하는 편성" 으로 정체를 만들려 했는데, 스테이지 밸런스를 손댈
	# 때마다 그 편성이 조금씩 피해를 내서 정체가 안 났다. 시나리오로 규칙을
	# 검사하면 규칙이 아니라 그 판의 밸런스를 검사하게 된다.
	var b := make_battle(1, [
		{ "type": "shieldman", "slot": 0, "cards": ["guard_stance"] },
	])
	b.step()
	# 마지막 피해 시각을 과거로 밀고 판정만 다시 돌린다.
	#
	# step() 을 한 번 더 부르면 안 된다. 그 사이 유닛이 서로 붙어 실제로 피해가
	# 나면서 시계가 다시 초기화된다 - 실제로 그렇게 돼서 검사가 통과를 못 했다.
	# 규칙을 검사하려면 규칙만 불러야 한다.
	b.last_damage_tick = b.tick - Battle.STALL_LIMIT
	b._check_result()
	ok(b.result == Battle.RESULT_DEFEAT, "정체가 이어지면 패배로 끝난다", b.result)
	ok(b.tick < Battle.MAX_TICKS, "60틱을 기다리지 않는다", "%d틱" % b.tick)

	# 피해가 계속 나는 판은 정체로 끊기면 안 된다. 이걸 같이 봐야 규칙이
	# "느린 빌드를 벌주는 것" 으로 변질되지 않았음이 보장된다.
	var fighting := [
		{ "type": "warrior", "slot": 0, "cards": ["engage", "charge"] },
		{ "type": "warrior", "slot": 2, "cards": ["engage", "charge"] },
		{ "type": "warrior", "slot": 4, "cards": ["engage", "charge"] },
	]
	var b2 := make_battle(1, fighting)
	b2.run()
	report(b2, "전사3 / 교전 (스테이지 1)")
	ok(b2.result != Battle.RESULT_TIMEOUT, "치고받는 판은 제때 끝난다", b2.result)

	# 마지막 피해 틱이 실제로 갱신되는가. 이게 안 되면 모든 전투가 14틱에 끝난다.
	ok(b2.last_damage_tick > 0, "피해가 나면 정체 시계가 초기화된다",
		str(b2.last_damage_tick))


func test_coordination_cards() -> void:
	print("
[13] 조율 카드 — 대상을 바꾸는 네 장")

	# 이 넷은 "언제 싸울까" 가 아니라 "누구를 향할까" 를 바꾼다. 조건만 바꾸는
	# 카드와 달리 실제로 대상이 달라졌는지를 봐야 검증이 된다.

	# ── 협공: 아군이 붙은 적을 같이 친다 ─────────────────────────────────
	# 화력 분산이 이 게임에서 지는 가장 흔한 이유다. 셋이 각자 다른 적을 때리면
	# 아무도 안 죽는다. 협공을 낀 쪽이 실제로 한 대상에 모이는지 센다.
	var spread := [
		{ "type": "archer", "slot": 3, "cards": ["engage"] },
		{ "type": "archer", "slot": 4, "cards": ["engage"] },
		{ "type": "archer", "slot": 5, "cards": ["engage"] },
	]
	var focused := [
		{ "type": "archer", "slot": 3, "cards": ["engage"] },
		{ "type": "archer", "slot": 4, "cards": ["crossfire", "engage"] },
		{ "type": "archer", "slot": 5, "cards": ["crossfire", "engage"] },
	]
	var b1 := make_battle(3, spread)
	b1.run()
	var b2 := make_battle(3, focused)
	b2.run()
	report(b1, "궁수3 / 교전만 (스테이지 3)")
	report(b2, "궁수3 / 협공 포함 (스테이지 3)")

	var fired := 0
	for e in b2.events:
		if e["type"] == "rule" and String(e.get("card_id", "")) == "crossfire":
			fired += 1
	ok(fired > 0, "협공이 발동한다", "%d회" % fired)
	ok(b2.tick <= b1.tick, "협공 쪽이 더 빨리 끝난다 — 화력이 모인다",
		"협공 %d틱 / 분산 %d틱" % [b2.tick, b1.tick])

	# 혼자서는 발동하면 안 된다. 자기가 정한 대상까지 인정하면 그냥 교전이다.
	var solo := [{ "type": "archer", "slot": 4, "cards": ["crossfire", "engage"] }]
	var b3 := make_battle(1, solo)
	b3.run()
	var solo_fired := 0
	for e in b3.events:
		if e["type"] == "rule" and String(e.get("card_id", "")) == "crossfire":
			solo_fired += 1
	ok(solo_fired == 0, "혼자면 협공이 발동하지 않는다", "%d회" % solo_fired)

	# ── 호위: 아군을 향해 움직인다 ───────────────────────────────────────
	# 이 게임 최초로 적이 아닌 쪽으로 가는 카드다. 실제로 거리가 좁혀지는지 본다.
	var esc := [
		{ "type": "archer", "slot": 0, "cards": ["engage"] },
		{ "type": "shieldman", "slot": 5, "cards": ["escort", "engage"] },
	]
	var b4 := make_battle(2, esc)
	b4.run()
	report(b4, "궁수 + 방패병(호위) (스테이지 2)")
	var escorted := 0
	for e in b4.events:
		if e["type"] == "rule" and String(e.get("card_id", "")) == "escort":
			escorted += 1
	ok(escorted > 0, "호위가 발동한다 — 아군 쪽으로 움직인다", "%d회" % escorted)

	# ── 암살: 후열로 파고든다 ────────────────────────────────────────────
	# [암살] 1번 + [교전] 2번 = "후열까지 가고, 닿으면 친다" 라는 한 문장.
	var asn := [{ "type": "assassin", "slot": 4, "cards": ["assassinate", "engage"] }]
	var b5 := make_battle(3, asn)
	b5.run()
	report(b5, "암살자(암살→교전) (스테이지 3)")
	var deep := 0
	for e in b5.events:
		if e["type"] == "rule" and String(e.get("card_id", "")) == "assassinate":
			deep += 1
	ok(deep > 0, "암살이 발동한다", "%d회" % deep)

	# ── 광전사: 처치 직후 다음 적으로 ────────────────────────────────────
	# 조건이 두 겹으로 좁다. 처치해야 하고, **그 다음 적이 사거리 밖이어야** 한다
	# (사거리 안이면 move_toward 가 실행 불가라 다음 슬롯으로 넘어간다).
	# 그래서 적이 뭉쳐 있는 스테이지 1 에서는 한 번도 안 터진다 — 죽은 게 아니라
	# 조건이 안 맞는 것이다. 적이 흩어져 있는 판까지 훑어서 확인한다.
	var brk := [
		{ "type": "assassin", "slot": 3, "cards": ["berserk", "engage"] },
		{ "type": "assassin", "slot": 4, "cards": ["berserk", "engage"] },
		{ "type": "archer", "slot": 5, "cards": ["engage"] },
	]
	var rage := 0
	var rage_where := ""
	var flag_seen := false
	for sid in [1, 2, 3, 4, 5]:
		var b6 := make_battle(sid, brk)
		b6.run()
		for e in b6.events:
			if e["type"] == "rule" and String(e.get("card_id", "")) == "berserk":
				rage += 1
				if rage_where == "":
					rage_where = "스테이지 %d" % sid
		for u in b6.units:
			if u.killed_last_tick or u.kill_pending:
				flag_seen = true
	ok(flag_seen, "처치 플래그가 실제로 선다")
	ok(rage > 0, "광전사가 발동한다 — 처치 직후 다음 적으로",
		"%d회 (최초 %s)" % [rage, rage_where])


func test_passive_ultimate() -> void:
	print("
[13] 패시브 궁극기 — 불굴의 의지")

	# 감사(죽은 규칙 검사)는 규칙 발동 횟수만 세므로 패시브를 볼 수 없다.
	# 실제로 도는지는 여기서 본다. 안 그러면 아무도 안 보는 코드가 된다.

	# 규칙 후보로 올라오면 안 된다. 올라오면 전사가 매 틱 "아무것도 아닌 것" 을
	# 고르고 실제 행동을 못 한다.
	var w := Unit.create(0, "warrior", Unit.TEAM_PLAYER, Vector2i(1, 1),
		["engage"], "unyielding")
	ok(w.special == "unyielding", "패시브도 장착은 된다")
	ok(not w.special_ready(), "패시브는 규칙 후보로 올라오지 않는다")

	# 치명타를 맞으면 죽는 대신 버티기에 들어간다.
	var killer := Unit.create(1, "assassin", Unit.TEAM_ENEMY, Vector2i(2, 1), [])
	w.take_damage(9999, killer)
	ok(w.alive, "HP 0 에서도 살아 있다")
	ok(w.hp == 0, "HP 는 0 이다", str(w.hp))
	ok(w.undying_ticks > 0, "버티기 틱이 찼다", str(w.undying_ticks))
	ok(w.special_used, "궁극기를 소모했다")

	# 두 번은 안 된다. 안 그러면 영원히 안 죽는다.
	var before := w.undying_ticks
	w.take_damage(9999, killer)
	ok(w.alive and w.undying_ticks == before, "버티는 중 재발동은 없다",
		"%d → %d" % [before, w.undying_ticks])

	# 실전에서 실제로 발동하는가. 확실히 죽는 판에 세운다.
	var party := [{ "type": "warrior", "slot": 4, "cards": ["engage"],
		"special": "unyielding" }]
	var b := make_battle(5, party)
	b.run()
	report(b, "전사 1명(불굴의 의지) / 스테이지 5")
	var held := false
	for u in b.units:
		if u.type_id == "warrior" and u.special_used:
			held = true
	ok(held, "실전에서 불굴의 의지가 발동한다")


func test_tutorial_battle() -> void:
	print("\n[13] 튜토리얼 전투 — 반드시 이기고 대사 틱과 맞아야 한다")

	# 대본이 지시하는 그대로의 편성. 여기가 어긋나면 대사가 헛돈다.
	var party := [{
		"type": "archer", "slot": 0,
		"cards": ["engage", "keep_distance"],
	}]
	var b := make_battle(Stages.TUTORIAL_ID, party)
	b.run()
	report(b, "튜토리얼 (총사 [교전, 거리 유지])")

	ok(b.result == Battle.RESULT_VICTORY,
		"튜토리얼은 반드시 승리로 끝난다", b.result)
	ok(b.living_count(Unit.TEAM_PLAYER) == 1, "총사가 살아남는다")

	# 대본이 틱 1~8 을 설명한다. 전투가 그보다 짧으면 뒤쪽 대사가 안 뜨고,
	# 너무 길면 설명 없는 틱이 줄줄이 흘러간다.
	var script_ticks := 0
	var t := Tutorial.new()
	if t.load_script():
		for s in t.steps:
			if s.has("at_tick"):
				script_ticks = maxi(script_ticks, int(s["at_tick"]))
	ok(b.tick == script_ticks,
		"전투 길이와 대사 틱 수가 일치한다", "전투 %d틱 / 대사 %d틱" % [b.tick, script_ticks])

	# 가르치려는 것이 실제로 화면에 나오는지
	var saw_innate_move := false
	var saw_engage := false
	var saw_counterattack := false
	var deaths := 0
	for e in b.events:
		if e["type"] == "rule" and int(e["unit"]) == 0:
			if bool(e.get("innate", false)) and String(e.get("rule_name", "")) == "기본 전진":
				saw_innate_move = true
			if String(e["card_id"]) == "engage":
				saw_engage = true
		elif e["type"] == "attack" and int(e["target"]) == 0:
			saw_counterattack = true
		elif e["type"] == "death":
			deaths += 1
	ok(saw_innate_move, "기본기 접근이 시연된다")
	ok(saw_engage, "교전이 시연된다")
	ok(saw_counterattack, "표적의 반격도 한 번은 맞는다 (붙으면 맞는다는 걸 보여줌)")
	ok(deaths == 2, "표적 둘을 전부 부순다", "%d개" % deaths)

	# 반대 순서면 한 발도 못 쏜다 — 대본이 주장하는 내용이 사실인지 확인한다.
	var reversed_party := [{
		"type": "musketeer", "slot": 0,
		"cards": ["keep_distance", "engage"],
	}]
	var b2 := make_battle(Stages.TUTORIAL_ID, reversed_party)
	b2.run()
	var shots := 0
	for e in b2.events:
		if e["type"] == "attack" and int(e["unit"]) == 0:
			shots += 1
	report(b2, "순서를 뒤집으면 (총사 [거리 유지, 교전])")
	ok(shots == 0,
		"거리 유지를 1번에 두면 한 발도 못 쏜다 — 대본의 주장이 사실이다", "%d발" % shots)
	ok(b2.result != Battle.RESULT_VICTORY, "그래서 못 이긴다", b2.result)
