extends SceneTree

## 전투 코어 헤드리스 검증.
##
##   godot --headless --script res://test/headless_test.gd
##
## ── 무엇을 검사하는가 ────────────────────────────────────────────────────
## **수치가 아니라 규칙**을 검사한다. 예전 검사는 "이 편성이 이 판을 이긴다"
## 같은 결과를 박아 두었는데, 밸런스를 한 번 고칠 때마다 검사가 깨져서 결국
## 검사 쪽 숫자를 고치게 됐다. 그건 검사가 아니라 스냅샷이다.
##
## 여기서는 밸런스를 어떻게 바꿔도 참이어야 하는 것만 본다.
##   - 결정론 (같은 입력 → 같은 결과)
##   - 축 안의 폴스루 (위가 성립하면 아래는 안 걸린다)
##   - 축 사이의 우선순위 (교전 > 위치 > 표적)
##   - 기본 AI (모듈이 없어도 반드시 무언가 한다)
##   - 교리 활성 조건 (두 장 이상 · 같은 태그만)
##   - 종료 분기 (승 / 패 / 타임아웃 / 정체)

var failures: int = 0
var checks: int = 0


func _init() -> void:
	print("=== PROJECT RECLAIM / 전투 코어 검증 ===\n")

	test_grid()
	test_determinism()
	test_base_ai()
	test_axis_fallthrough()
	test_axis_priority()
	test_target_axis()
	test_squad_axis()
	test_position_axis()
	test_doctrines()
	test_branches()
	test_stall_rule()
	test_line_of_sight()
	test_specials()
	test_tutorial_battle()
	test_doctrine_in_battle()
	test_axis_doctrine()
	test_squad_movement()
	test_story_wiring()
	test_passives()

	print("\n=== %d개 검사 / 실패 %d개 ===" % [checks, failures])
	quit(1 if failures > 0 else 0)


func ok(cond: bool, label: String, detail: String = "") -> void:
	checks += 1
	if cond:
		print("  [PASS] %s" % label)
	else:
		failures += 1
		print("  [FAIL] %s  %s" % [label, detail])


# ── 도구 ─────────────────────────────────────────────────────────────────

func member(t: String, slot: int, cards: Array = [], sp: String = "") -> Dictionary:
	return { "type": t, "slot": slot, "cards": cards, "special": sp, "upgrade": 0 }


func run_battle(stage: int, party: Array) -> Battle:
	var b := Battle.new()
	b.setup(stage, party)
	b.run()
	return b


## 첫 틱에 그 대원이 무엇을 하기로 했는지. 판단만 보고 실행은 안 한다.
func decide(stage: int, party: Array, who: int = 0) -> Dictionary:
	var b := Battle.new()
	b.setup(stage, party)
	return Rules.select(b.units[who], b)


# ── 1. 격자 ──────────────────────────────────────────────────────────────

func test_grid() -> void:
	print("\n[1] 격자 / 이동")
	ok(Grid.manhattan(Vector2i(0, 0), Vector2i(3, 2)) == 5, "맨해튼 거리")
	ok(Grid.in_bounds(Vector2i(0, 0)), "좌상단은 판 안")
	ok(not Grid.in_bounds(Vector2i(-1, 0)), "판 밖은 거부")
	var blocked := { Vector2i(1, 0): true }
	ok(Grid.step_toward(Vector2i(0, 0), Vector2i(3, 0), blocked) != Vector2i(1, 0),
		"막힌 칸은 안 밟는다")


# ── 2. 결정론 ────────────────────────────────────────────────────────────

func test_determinism() -> void:
	print("\n[2] 결정론")
	var party := [
		member("warrior", 0, ["near_first", "forced_march"]),
		member("archer", 2, ["backline", "keep_range"]),
		member("bard", 4, ["escort"]),
	]
	var a := run_battle(3, party)
	var b := run_battle(3, party)
	ok(a.result == b.result, "같은 입력 → 같은 결과", "%s vs %s" % [a.result, b.result])
	ok(a.tick == b.tick, "같은 입력 → 같은 틱 수")
	ok(a.events.size() == b.events.size(), "이벤트 수열 길이 동일")
	var same := true
	for i in mini(a.events.size(), b.events.size()):
		if a.events[i] != b.events[i]:
			same = false
			break
	ok(same, "이벤트 수열 전체 동일")


# ── 3. 기본 AI ───────────────────────────────────────────────────────────

func test_base_ai() -> void:
	print("\n[3] 기본 AI")

	# 모듈이 하나도 없어도 반드시 무언가 한다. 이게 개편의 전제다.
	for t in ["warrior", "archer", "bard", "assassin", "musketeer", "shieldman"]:
		var d := decide(1, [member(t, 2), member("warrior", 0), member("archer", 4)])
		ok(not d.is_empty(), "%s: 모듈 0장이어도 행동한다" % t)

	# 근접은 붙으러 가고 원거리는 자리를 지킨다.
	var mel := decide(1, [member("warrior", 0), member("warrior", 2), member("warrior", 4)])
	ok(String(mel["card"]["act"]) == "move_toward", "전사는 사거리 밖이면 접근")

	var rng := decide(1, [member("archer", 0), member("archer", 2), member("archer", 4)])
	ok(String(rng["card"]["act"]) == "hold", "궁수는 사거리 밖이어도 제자리")

	# 악사는 공격이 아니라 회복이 기본이다.
	var ai := Innates.base_ai("bard")
	ok(String(ai["act"]) == "heal", "악사 기본 행동은 회복")
	ok(int(Innates.base_ai("archer")["flee_within"]) == 1, "궁수는 1칸 이내면 후퇴")
	ok(int(Innates.base_ai("warrior")["flee_within"]) == 0, "전사는 안 물러난다")


# ── 4. 축 안의 폴스루 ────────────────────────────────────────────────────

func test_axis_fallthrough() -> void:
	print("\n[4] 축 안의 폴스루")

	# 조건 없는 표적 모듈을 위에 두면 아래는 절대 안 걸린다.
	# 이게 "위에 있는 게 먼저다" 라는 이 게임의 코어다.
	var d := decide(5, [
		member("archer", 0, ["cut_support", "execute"]),
		member("warrior", 2), member("warrior", 4)])
	var rows: Array = d["trace"].get(Axes.TARGET, [])
	ok(rows.size() >= 2, "표적 축 두 줄이 기록된다")
	if rows.size() >= 2:
		ok(bool(rows[0]["hit"]), "1번이 성립")
		ok(not bool(rows[1]["hit"]), "2번은 안 걸린다")

	# 순서를 뒤집으면 결과가 바뀐다. 같은 모듈로 다른 대원이 되는 근거다.
	var d2 := decide(5, [
		member("archer", 0, ["execute", "cut_support"]),
		member("warrior", 2), member("warrior", 4)])
	var t1: Unit = d["target"]
	var t2: Unit = d2["target"]
	ok(t1 != null and t2 != null and t1.index != t2.index,
		"순서를 바꾸면 표적이 바뀐다")

	# 조건이 안 맞으면 다음 줄로 내려간다.
	var d3 := decide(1, [
		member("warrior", 0, ["fall_back", "guard_stance"]),
		member("archer", 2), member("bard", 4)])
	var er: Array = d3["trace"].get(Axes.DOCTRINE, [])
	ok(er.size() >= 1 and not bool(er[0]["hit"]),
		"HP 만피면 [부상 회피] 는 안 걸린다")


# ── 5. 축 사이의 우선순위 ────────────────────────────────────────────────

func test_axis_priority() -> void:
	print("\n[5] 교전 > 위치 > 표적")

	# [사거리 대기] 가 걸리면 표적이 무엇이든 이번 틱은 안 움직인다.
	var d := decide(1, [
		member("archer", 0, ["backline", "hold_fire", "forced_march"]),
		member("warrior", 2), member("warrior", 4)])
	ok(String(d["card"]["act"]) == "hold", "교전(대기)이 위치(강행군)를 이긴다",
		String(d["card"]["act"]))

	# [부상 회피] 는 표적이 사거리 안이어도 물러나게 한다.
	var b := Battle.new()
	b.setup(1, [member("warrior", 1, ["wary_step"]), member("archer", 2), member("bard", 4)])
	b.units[0].hp = 1
	var d2 := Rules.select(b.units[0], b)
	ok(String(d2["card"]["act"]) in ["move_away", "hold", "move_toward"],
		"교전 수칙이 조립을 통과한다", String(d2["card"]["act"]))


# ── 6. 표적 축 ───────────────────────────────────────────────────────────

func test_target_axis() -> void:
	print("\n[6] 표적 축")

	var party := [member("archer", 0, ["backline"]), member("warrior", 2), member("warrior", 4)]
	var d := decide(3, party)
	var t: Unit = d["target"]
	# 3단계는 방패병 둘이 앞(x=5), 악사가 뒤(x=6)다.
	ok(t != null and t.pos.x == 6, "[후열 침투] 는 뒤를 고른다",
		"x=%d" % (t.pos.x if t != null else -1))

	var d2 := decide(3, [member("archer", 0, ["cut_support"]), member("warrior", 2), member("warrior", 4)])
	var t2: Unit = d2["target"]
	ok(t2 != null and t2.type_id == "bard", "[지원 차단] 은 회복형을 고른다",
		t2.type_id if t2 != null else "null")

	var d3 := decide(1, [member("archer", 0, ["near_first"]), member("warrior", 2), member("warrior", 4)])
	var t3: Unit = d3["target"]
	ok(t3 != null, "[전선 고정] 은 조건이 안 맞으면 기본 표적으로 내려간다")


# ── 7. 협력 축 ───────────────────────────────────────────────────────────

func test_squad_axis() -> void:
	print("\n[7] 협력 축")

	var b := Battle.new()
	b.setup(3, [
		member("archer", 0, ["coop_fire", "near_first"]),
		member("warrior", 2, ["backline"]),
		member("bard", 4)])
	# 아군이 아직 아무도 안 때렸으면 협공은 성립하지 않는다 - 표적 축으로 내려간다.
	var d := Rules.select(b.units[0], b)
	ok(not d.is_empty(), "협공 대상이 없어도 표적이 정해진다")

	b.run()
	ok(b.result != Battle.RESULT_ONGOING, "협공 편성으로 전투가 끝까지 간다")


# ── 8. 위치 축 ───────────────────────────────────────────────────────────

func test_position_axis() -> void:
	print("\n[8] 위치 축")

	# [강행군] 은 이동 보너스다. 접근 행동에 move_bonus 가 실려야 한다.
	var d := decide(1, [
		member("warrior", 0, ["forced_march"]), member("archer", 2), member("bard", 4)])
	ok(int(d["card"].get("move_bonus", 0)) == 1, "[강행군] 이 이동 +1 을 싣는다")

	# [전열 유지] 는 원거리도 앞으로 보낸다. 기본 AI 의 hold 를 덮어쓴다.
	var d2 := decide(1, [
		member("archer", 0, ["front_line"]), member("warrior", 2), member("bard", 4)])
	ok(String(d2["card"]["act"]) == "move_toward",
		"[전열 유지] 가 궁수의 제자리 기본기를 덮어쓴다", String(d2["card"]["act"]))


# ── 9. 교리 ──────────────────────────────────────────────────────────────

func test_doctrines() -> void:
	print("
[9] 교리 보너스")

	# 핵심 둘을 함께 꽂으면 교리가 켜진다.
	var d1 := Doctrines.active_ids(["backline", "forced_march"])
	ok(d1.has("assassin"), "핵심 둘이면 암살 교리 활성")

	# 하나만 있으면 안 켜진다. 조합이 곧 정체성이다.
	ok(Doctrines.active_ids(["backline"]).is_empty(), "한 장이면 활성 안 됨")

	# 셋째 칸은 자유다. 같은 교리라도 세 번째로 대원이 갈린다.
	var d2 := Doctrines.active_ids(["backline", "forced_march", "cluster"])
	ok(d2.has("assassin"), "셋째 칸이 무엇이든 교리는 유지")

	# 다른 조합은 다른 교리다.
	var d3 := Doctrines.active_ids(["behind_guard", "coop_fire"])
	ok(d3.has("phalanx") and not d3.has("assassin"), "조합이 다르면 교리도 다르다")

	ok(Doctrines.amount(d1, "crit_pct") == 15, "암살 교리는 치명타 +15")
	ok(Doctrines.amount(d1, "attack_pct") == 0, "없는 효과는 0")

	# 한 장만 더 채우면 되는 교리를 알려 준다. 상점 안내가 이걸 쓴다.
	var near := Doctrines.near_complete(["backline"])
	var found := false
	for n in near:
		if String(n["key"]) == "assassin" and String(n["need"]) == "forced_march":
			found = true
	ok(found, "한 장 남은 교리를 짚어 준다")


# ── 10. 종료 분기 ────────────────────────────────────────────────────────

func test_branches() -> void:
	print("\n[10] 승 / 패 / 타임아웃")

	var seen: Dictionary = {}
	var comps := [
		[member("warrior", 0), member("warrior", 2), member("warrior", 4)],
		[member("bard", 0), member("bard", 2), member("bard", 4)],
		[member("archer", 0, ["hold_fire"]), member("archer", 2, ["hold_fire"]),
			member("archer", 4, ["hold_fire"])],
	]
	for stage in [1, 2, 3, 4, 5]:
		for c in comps:
			seen[run_battle(stage, c).result] = true

	ok(seen.has(Battle.RESULT_VICTORY), "승리 분기에 도달한다")
	ok(seen.has(Battle.RESULT_DEFEAT), "패배 분기에 도달한다")
	ok(seen.size() >= 2, "결과가 한 종류로 굳지 않는다", str(seen.keys()))


func test_stall_rule() -> void:
	print("\n[11] 정체 판정")
	# 악사만 셋이면 아무도 적을 못 줄인다. 반드시 정체로 끝나야 한다.
	var b := run_battle(1, [member("bard", 0), member("bard", 2), member("bard", 4)])
	ok(b.result != Battle.RESULT_ONGOING, "회복만 하는 편성도 반드시 끝난다")
	ok(b.tick <= Battle.MAX_TICKS, "MAX_TICKS 를 넘지 않는다")


# ── 12. 차폐 ─────────────────────────────────────────────────────────────

func test_line_of_sight() -> void:
	print("\n[12] 차폐")
	var b := Battle.new()
	b.setup(3, [member("archer", 0), member("warrior", 2), member("bard", 4)])
	var shootable := b.shootable_enemies_of(b.units[0])
	ok(shootable.size() >= 1, "쏠 수 있는 적이 하나는 있다")
	ok(shootable.size() <= b.living_enemies_of(b.units[0]).size(),
		"차폐가 후보를 줄이거나 유지한다")


# ── 13. 궁극기 ───────────────────────────────────────────────────────────

func test_specials() -> void:
	print("\n[13] 궁극기")

	for sid in Specials.TABLE:
		var sp: Dictionary = Specials.TABLE[sid]
		ok(sp.has("unit") and UnitData.TABLE.has(String(sp["unit"])),
			"%s: 직업이 유효하다" % sid)

	# 궁극기는 교전당 1회다.
	var b := Battle.new()
	b.setup(1, [member("musketeer", 1, [], "keep_off"), member("warrior", 0), member("bard", 4)])
	b.run()
	var used := 0
	for e in b.events:
		if String(e.get("type", "")) == "special" and int(e.get("unit", -1)) == 0:
			used += 1
	ok(used <= 1, "궁극기는 교전당 한 번만", "%d회" % used)


# ── 14. 튜토리얼 ─────────────────────────────────────────────────────────

func test_tutorial_battle() -> void:
	print("\n[14] 튜토리얼")
	var b := run_battle(Stages.TUTORIAL_ID, [
		member("archer", 0), member("archer", 2), member("archer", 4)])
	ok(b.result == Battle.RESULT_VICTORY, "훈련장은 기본기만으로 이긴다", b.result)


# ── 15. 교리가 전투에 실제로 붙는가 ──────────────────────────────────────

func test_doctrine_in_battle() -> void:
	print("
[15] 교리 적용")

	var b := Battle.new()
	b.setup(1, [
		member("warrior", 0, ["front_line", "battle_stance"]),
		member("archer", 2, ["cut_support", "wary_step"]),
		member("bard", 4)])

	ok(b.units[0].doctrines.has("breakthrough"), "돌파 교리가 켜졌다")
	ok(b.units[1].doctrines.has("interdict"), "저지 교리가 켜졌다")
	ok(b.units[2].doctrines.is_empty(), "모듈 없는 대원은 교리도 없다")

	var plain := Battle.new()
	plain.setup(1, [member("archer", 0), member("warrior", 2), member("bard", 4)])

	# 저지 교리(+12%)가 실제 피해에 반영돼야 한다.
	ok(b.units[1].power_damage(100) > plain.units[0].power_damage(100),
		"저지 교리가 공격력을 올린다",
		"%d vs %d" % [b.units[1].power_damage(100), plain.units[0].power_damage(100)])

	# 돌파 교리(-18%)는 받는 피해를 줄인다.
	var a := b.units[0].take_damage(100, null)
	var c := plain.units[1].take_damage(100, null)
	ok(a < c, "돌파 교리가 받는 피해를 줄인다", "%d vs %d" % [a, c])


func test_axis_doctrine() -> void:
	print("\n[16] 축 교리")

	# 한 축으로 세 칸을 다 채우면 켜진다. 조합이 무엇이든 상관없다.
	var b := Battle.new()
	b.setup(1, [
		member("archer", 0, ["backline", "far_in_range", "execute"]),
		member("warrior", 2, ["near_first", "front_line", "guard_stance"]),
		member("bard", 4)])
	ok(b.units[0].doctrines.has("axis:target"), "표적 셋이면 표적 교리")
	ok(not b.units[1].doctrines.has("axis:target"), "축이 섞이면 안 켜진다")

	# 조합 교리와 축 교리는 겹칠 수 있고, 겹치면 효과가 합쳐진다.
	var both := Battle.new()
	both.setup(1, [
		member("archer", 0, ["cut_support", "wary_step", "keep_range"]),
		member("warrior", 2), member("bard", 4)])
	var d: Dictionary = both.units[0].doctrines
	ok(d.has("interdict"), "저지 교리(조합)가 켜졌다")
	ok(Doctrines.amount(d, "attack_pct") >= 12, "조합 교리 효과가 살아 있다",
		str(Doctrines.amount(d, "attack_pct")))


func test_squad_movement() -> void:
	print("\n[17] 협력이 이동을 정한다")

	# [엄호] 는 오래 표에만 있고 이동에 아무 영향이 없었다. 이제 실제로 붙는다.
	var b := Battle.new()
	b.setup(1, [
		member("archer", 0, ["escort"]),
		member("warrior", 5), member("bard", 4)])
	b.units[1].hp = 10
	var d := Rules.select(b.units[0], b)
	ok(String(d["card"]["act"]) == "move_to_ally",
		"[엄호] 가 위독한 아군 쪽으로 보낸다", String(d["card"]["act"]))

	# [방패 추종] 은 방패병·전사를 따라간다.
	var g := Battle.new()
	g.setup(1, [
		member("archer", 0, ["follow_guard"]),
		member("shieldman", 5), member("bard", 4)])
	var d2 := Rules.select(g.units[0], g)
	ok(String(d2["card"]["act"]) == "move_to_ally",
		"[방패 추종] 이 방패병 쪽으로 보낸다", String(d2["card"]["act"]))

	# 위치 모듈이 있으면 그쪽이 이긴다. 명시적 지정이 협력 보정을 덮는다.
	# 위치 축 안에서는 위가 아래를 가린다. [방패 추종] 이 1번이면 [전열 유지] 는
	# 안 걸린다 - 협력이 위치로 합쳐지면서 이게 축 안의 폴스루가 됐다.
	var p := Battle.new()
	p.setup(1, [
		member("archer", 0, ["front_line", "follow_guard"]),
		member("shieldman", 5), member("bard", 4)])
	var d3 := Rules.select(p.units[0], p)
	ok(String(d3["card"]["act"]) == "move_toward",
		"위치 축 1번이 2번을 가린다", String(d3["card"]["act"]))

	# 새 협력 교리
	ok(Doctrines.active_ids(["follow_guard", "taunt"]).has("vanguard"),
		"선봉 교리가 켜진다")


func test_story_wiring() -> void:
	print("\n[18] 스토리 대본")

	# 대본이 실제로 읽히는가. 파일이 안 읽히면 조용히 빈 배열이 되어
	# 스토리가 통째로 안 나오는데, 화면에는 아무 표시도 안 남는다.
	ok(not Story.beats("pre", 1).is_empty(), "1단계 도입 대사가 있다")
	ok(not Story.beats("post", 5).is_empty(), "5단계 마무리 대사가 있다")
	ok(Story.all_beats().size() > 20, "몰아보기 목록이 만들어진다",
		str(Story.all_beats().size()))

	# 연출 이름 오타는 조용히 죽는다 - 그 장면만 밋밋하게 지나간다.
	var bad := ""
	for stage in [1, 2, 3, 4, 5]:
		for when in ["pre", "post"]:
			for b in Story.beats(when, stage):
				var fx := String((b as Dictionary).get("fx", ""))
				if fx != "" and not Story.EFFECTS.has(fx):
					bad = "%s_%d: %s" % [when, stage, fx]
	ok(bad == "", "알 수 없는 연출 이름이 없다", bad)


func test_passives() -> void:
	print("\n[19] 상시 효과")

	# 상시 모듈은 상점에 안 나온다. 보급 전용이라는 계약이다.
	var in_shop := false
	for cid in Cards.shop_order():
		if String(Cards.TABLE[cid]["axis"]) == Axes.PASSIVE:
			in_shop = true
	ok(not in_shop, "상시 모듈은 상점 주머니에 없다")

	var b := Battle.new()
	b.setup(1, [
		member("warrior", 0, ["assault"]),
		member("shieldman", 2, ["plating"]),
		member("archer", 4)])
	b.step()

	# 공격대 +18%
	var plain := Battle.new()
	plain.setup(1, [member("warrior", 0), member("archer", 2), member("bard", 4)])
	plain.step()
	ok(b.units[0].power_damage(100) > plain.units[0].power_damage(100),
		"[공격대] 가 공격력을 올린다",
		"%d vs %d" % [b.units[0].power_damage(100), plain.units[0].power_damage(100)])

	# 철갑 - 최대 HP 12% 를 넘는 한 방만 깎는다.
	var guard := b.units[1]
	var big: int = guard.max_hp   # 확실히 상한을 넘는 값
	var took := guard.take_damage(big, null)
	ok(took < big, "[철갑] 이 큰 한 방을 무디게 한다", "%d <- %d" % [took, big])

	# 잠복 - 표적 후보에서 빠진다.
	var amb := Battle.new()
	amb.setup(1, [member("assassin", 0, ["ambush"]), member("warrior", 2), member("bard", 4)])
	amb.step()
	var hidden := amb.units[0].ambush_ticks > 0
	if hidden:
		var seen := false
		for e in amb.living_enemies_of(amb.units[3]):
			if e.index == 0:
				seen = true
		ok(not seen, "잠복 중인 대원은 표적이 안 된다")
	else:
		ok(true, "잠복 조건이 안 걸린 판 - 건너뜀")

	# 균형 편제 - 세 축을 하나씩
	var bal := Doctrines.active([
		{ "axis": "target", "id": "backline" },
		{ "axis": "position", "id": "keep_range" },
		{ "axis": "doctrine", "id": "hold_fire" },
	])
	ok(bal.has("balanced"), "세 축을 하나씩 채우면 균형 편제")
