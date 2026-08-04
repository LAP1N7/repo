extends SceneTree

## 규칙 중복 · 지배 관계 감사.
##
##   godot --headless --script res://test/audit.gd
##
## ── 왜 "실효 조건" 을 따로 계산하는가 ───────────────────────────────────
## 규칙 엔진은 폴스루한다. 조건이 참이어도 그 행동이 불가능하면 다음 슬롯으로
## 내려간다. 그래서 카드에 적힌 조건과 실제로 발동하는 조건은 다르다.
##
##   교전: `항상 → 가장 가까운 적 공격`
##   공격은 사거리 안에서만 가능하다 → 실효 조건은 `사거리 안`
##   즉 교전은 사실상 `사거리 안 → 가장 가까운 적 공격` 이다.
##
## 이 정규화를 하지 않으면 눈으로는 다르게 보이는 규칙이 실제로는 완전히 같은
## 규칙이라는 사실이 드러나지 않는다.

var findings: int = 0


func _init() -> void:
	print("=== 규칙 중복 · 지배 감사 ===\n")
	audit_duplicates()
	audit_dominance()
	audit_innate_overlap()
	audit_special_overlap()
	audit_dead_rules()
	print("\n=== 지적 사항 %d건 ===" % findings)
	quit(0)


func note(kind: String, msg: String) -> void:
	findings += 1
	print("  [%s] %s" % [kind, msg])


# ── 실효 조건 ────────────────────────────────────────────────────────────

## 카드에 적힌 조건을, 행동의 실행 가능성까지 반영한 "실제로 발동하는 조건" 으로 바꾼다.
func effective_cond(cond: String, arg: int, act: String) -> String:
	match act:
		"attack":
			# 공격은 사거리 안에서만 가능하다.
			if cond == "always":
				return "enemy_in_range"
			if cond == "enemy_within" and arg >= 99:
				return "enemy_in_range"
		"move_toward":
			# 이미 사거리 안이면 더 붙지 않는다 → 사거리 밖에서만 발동한다.
			if cond == "always":
				return "enemy_out_of_range"
		"heal":
			if cond == "always":
				return "ally_in_range_damaged"
	return "%s%s" % [cond, "" if arg == 0 else ":" + str(arg)]


## 위력과 이동 보너스도 서명에 넣는다. 이걸 빼면 "기본 공격(70%)" 과
## "교전(100%)" 이 같은 규칙으로 잡혀서, 애써 벌려 놓은 차이를 못 본다.
func signature(r: Dictionary) -> String:
	if not r.has("act"):
		note("결손", "규칙 '%s' 에 act 키가 없다 — 데이터가 깨졌다" % r.get("name", "?"))
		return "BROKEN:%s" % r.get("name", "?")
	return "%s|%s|%s|p%d|m%d" % [
		effective_cond(String(r["cond"]), int(r["cond_arg"]), String(r["act"])),
		r["act"], r["target"],
		int(r.get("power", 100)), int(r.get("move_bonus", 0)),
	]


# ── 1. 완전 중복 ─────────────────────────────────────────────────────────

func audit_duplicates() -> void:
	print("[1] 완전 중복 — 실효 조건·행동·대상이 전부 같은 규칙")

	var seen: Dictionary = {}   # signature -> [이름들]
	for cid in Cards.DECK_ORDER:
		var c: Dictionary = Cards.TABLE[cid]
		var sig := signature(c)
		if not seen.has(sig):
			seen[sig] = []
		seen[sig].append("%s(카드 %d코)" % [c["name"], int(c["cost"])])

	for r in Innates.BASE:
		var sig2 := signature(r)
		if not seen.has(sig2):
			seen[sig2] = []
		seen[sig2].append("%s(공통 기본기 · 무료)" % r["name"])

	for tid in Innates.TABLE:
		for r2 in Innates.TABLE[tid]:
			var sig3 := signature(r2)
			if not seen.has(sig3):
				seen[sig3] = []
			seen[sig3].append("%s(%s 기본기 · 무료)" % [
				r2["name"], UnitData.TABLE[tid]["name"]])

	var any := false
	for sig in seen:
		var group: Array = seen[sig]
		if group.size() > 1:
			any = true
			note("중복", "%s\n           → 실효 규칙: %s" % [" ≡ ".join(group), sig])
	if not any:
		print("  없음")


# ── 2. 지배 ──────────────────────────────────────────────────────────────

## a 가 참인 모든 상황에서 b 도 참인가 (a ⊆ b). 같은 행동일 때만 의미가 있다.
func implies(a: String, a_arg: int, b: String, b_arg: int) -> bool:
	if b == "always":
		return true
	if a == b:
		match a:
			# 문턱이 클수록 더 자주 참이다.
			"self_hp_below", "ally_hp_below", "enemy_within":
				return a_arg <= b_arg
			# 문턱이 작을수록 더 자주 참이다.
			"enemies_adjacent_at_least", "tick_below":
				return a_arg >= b_arg
			_:
				return true
	return false


func audit_dominance() -> void:
	print("\n[2] 지배 — 더 싸거나 같은 값에 더 자주 발동하는 카드가 있는가")

	var any := false
	for x in Cards.DECK_ORDER:
		for y in Cards.DECK_ORDER:
			if x == y:
				continue
			var a: Dictionary = Cards.TABLE[x]
			var b: Dictionary = Cards.TABLE[y]
			if a["act"] != b["act"] or a["target"] != b["target"]:
				continue
			if signature(a) == signature(b):
				continue   # 완전 중복은 [1] 에서 이미 잡았다
			# b 가 a 를 지배: b 가 더 자주 발동하고 값이 더 비싸지 않다.
			if implies(String(a["cond"]), int(a["cond_arg"]),
					String(b["cond"]), int(b["cond_arg"])) \
					and int(b["cost"]) <= int(a["cost"]):
				any = true
				note("지배", "%s(%d코) 는 %s(%d코) 에게 밀린다 — 더 자주 발동하는데 더 싸거나 같다" % [
					a["name"], int(a["cost"]), b["name"], int(b["cost"])])
	if not any:
		print("  없음")


# ── 3. 기본기와의 겹침 ───────────────────────────────────────────────────

func audit_innate_overlap() -> void:
	print("\n[3] 기본기와 조건이 같은 카드 — 발동 타이밍이 겹친다")

	var innate_conds: Dictionary = {}
	for tid in Innates.TABLE:
		for r in Innates.TABLE[tid]:
			var key := "%s:%d" % [r["cond"], int(r["cond_arg"])]
			innate_conds[key] = "%s(%s)" % [r["name"], UnitData.TABLE[tid]["name"]]

	var any := false
	for cid in Cards.DECK_ORDER:
		var c: Dictionary = Cards.TABLE[cid]
		var key2 := "%s:%d" % [c["cond"], int(c["cond_arg"])]
		if innate_conds.has(key2):
			any = true
			var same_act := ""
			for tid2 in Innates.TABLE:
				for r2 in Innates.TABLE[tid2]:
					if "%s:%d" % [r2["cond"], int(r2["cond_arg"])] == key2 \
							and r2["act"] == c["act"] and r2["target"] == c["target"]:
						same_act = " · 행동까지 동일"
			note("겹침", "%s(%d코) 와 %s 가 같은 조건에서 발동한다%s" % [
				c["name"], int(c["cost"]), innate_conds[key2], same_act])
	if not any:
		print("  없음")


# ── 4. 특수 스킬 겹침 ────────────────────────────────────────────────────

func audit_special_overlap() -> void:
	print("\n[4] 특수 스킬이 그 직업 기본기와 겹치는가")

	var any := false
	for sid in Specials.ORDER:
		var sp: Dictionary = Specials.TABLE[sid]
		var tid: String = sp["unit"]
		for r in Innates.TABLE.get(tid, []):
			if r["cond"] == sp["cond"] and int(r["cond_arg"]) == int(sp["cond_arg"]):
				any = true
				note("겹침", "%s(특수) 와 %s(기본기) 가 같은 조건이다 — 특수가 항상 선점한다" % [
					sp["name"], r["name"]])
	if not any:
		print("  없음")

	# 직업 기본기가 공통 골격과 "효과" 가 같으면, 조건이 달라도 무의미하다.
	# 기본기 바로 다음이 공통 골격이라 어차피 같은 일이 벌어지기 때문이다.
	# 실제로 암살자의 급습이 이 상태였다 — 조건만 다르고 하는 일은 기본 전진과 동일.
	print("\n[4-b] 직업 기본기가 공통 골격과 효과가 같은가 (조건만 달라도 무의미)")
	var noop := false
	for tid3 in Innates.TABLE:
		for r3 in Innates.TABLE[tid3]:
			for b3 in Innates.BASE:
				if r3["act"] == b3["act"] and r3["target"] == b3["target"] \
						and int(r3.get("power", 100)) == int(b3.get("power", 100)) \
						and int(r3.get("move_bonus", 0)) == int(b3.get("move_bonus", 0)):
					noop = true
					note("무효", "%s(%s 기본기) 는 %s 와 하는 일이 같다 — 효과가 0이다" % [
						r3["name"], UnitData.TABLE[tid3]["name"], b3["name"]])
	if not noop:
		print("  없음")


# ── 5. 실제로 발동하는가 (경험적 검사) ──────────────────────────────────
#
# 위의 1~4는 규칙을 글자로만 비교한다. 그래서 "조건은 다른데 먼저 평가되는 규칙이
# 발동 창을 통째로 덮어버리는" 경우를 못 잡는다.
#
# 예: 암살자의 급습(전투 시작 3틱 → 접근)과 그림자 도약(사거리 밖 → 도약).
# 조건 문자열은 다르지만, 개전 직후엔 항상 사거리 밖이므로 우선발동인 특수가
# 매번 선수를 친다. 글자 비교로는 절대 안 보인다.
#
# 그래서 실제로 돌려 보고 발동 횟수를 센다. 0에 가까우면 죽은 규칙이다.

const TRIALS: int = 120

func audit_dead_rules() -> void:
	print("\n[5] 죽은 규칙 — 실제로 돌려서 발동 횟수를 센다")

	var rng := RandomNumberGenerator.new()
	rng.seed = 424242

	# 규칙 이름 -> 발동 횟수
	var fired: Dictionary = {}
	var expected: Dictionary = {}   # 이름 -> 소유자 설명

	for r in Innates.BASE:
		expected[r["name"]] = "공통 기본기"
	for tid in Innates.TABLE:
		for r2 in Innates.TABLE[tid]:
			expected[r2["name"]] = "%s 기본기" % UnitData.TABLE[tid]["name"]
	for sid in Specials.ORDER:
		# 패시브 궁극기는 규칙 후보로 올라오지 않는다. 규칙 발동 횟수를 세는
		# 이 검사에서는 영원히 0회로 나오므로 "죽은 규칙" 오탐이 된다.
		# [불굴의 의지] 가 실제로 도는지는 headless_test 가 따로 본다.
		if Specials.is_passive(sid):
			continue
		var sp: Dictionary = Specials.TABLE[sid]
		expected[sp["name"]] = "%s 궁극기" % UnitData.TABLE[sp["unit"]]["name"]
	for cid in Cards.DECK_ORDER:
		expected[Cards.TABLE[cid]["name"]] = "카드"
	for k in expected:
		fired[k] = 0

	var types := UnitData.TABLE.keys()
	var battles := 0

	# 모든 유닛 종류가 자기 특수를 낀 채로 골고루 등장하도록 표본을 만든다.
	for t in types:
		for _n in TRIALS:
			var party: Array = []
			var slots: Array[int] = [0, 1, 2, 3, 4, 5]
			for i in 3:
				var slot: int = slots.pop_at(rng.randi_range(0, slots.size() - 1))
				var tid2: String = String(t) if i == 0 \
					else String(types[rng.randi_range(0, types.size() - 1)])
				var cards: Array = []
				for _c in rng.randi_range(0, 3):
					cards.append(Cards.DECK_ORDER[
						rng.randi_range(0, Cards.DECK_ORDER.size() - 1)])
				party.append({
					"type": tid2, "slot": slot, "cards": cards,
					"special": Specials.for_unit(tid2),
				})
			for stage_id in [1, 2]:
				var b := Battle.new()
				b.setup(stage_id, party)
				b.run()
				battles += 1
				for e in b.events:
					if e["type"] != "rule":
						continue
					var nm := String(e.get("rule_name", ""))
					if fired.has(nm):
						fired[nm] += 1

	print("      전투 %d회 표본" % battles)

	var dead: Array = []
	var rare: Array = []
	for nm in fired:
		if int(fired[nm]) == 0:
			dead.append(nm)
		elif int(fired[nm]) < battles / 40:
			rare.append(nm)

	for nm in dead:
		note("죽음", "%s (%s) — %d회 전투에서 단 한 번도 발동하지 않았다" % [
			nm, expected[nm], battles])
	for nm in rare:
		note("희소", "%s (%s) — %d회만 발동 (%.2f회/전투)" % [
			nm, expected[nm], int(fired[nm]), float(fired[nm]) / float(battles)])

	if dead.is_empty() and rare.is_empty():
		print("  없음")

	# 기본기와 특수의 실제 발동 횟수를 항상 찍는다. "죽지는 않았지만 거의 안 뜬다"
	# 는 상태가 눈에 보여야 한다 — 화면에서는 그게 "안 되는 것" 으로 느껴진다.
	print("\n   ── 기본기 · 특수 실제 발동 횟수 (전투 %d회)" % battles)
	for tid3 in Innates.TABLE:
		var uname: String = UnitData.TABLE[tid3]["name"]
		var line := "   %-6s" % uname
		for r3 in Innates.TABLE[tid3]:
			line += "  기본기 %s %d회" % [r3["name"], int(fired[r3["name"]])]
		var sid2 := Specials.for_unit(String(tid3))
		# 패시브는 규칙으로 발동하지 않아 fired 에 아예 키가 없다.
		# 여기서 걸러 주지 않으면 존재하지 않는 키를 읽고 터진다.
		if sid2 != "" and not Specials.is_passive(sid2):
			var spn: String = Specials.TABLE[sid2]["name"]
			line += "   /   궁극기 %s %d회" % [spn, int(fired[spn])]
		elif sid2 != "":
			line += "   /   궁극기 %s (패시브 · 규칙 발동 없음)" % Specials.TABLE[sid2]["name"]
		print(line)
	for r4 in Innates.BASE:
		print("   (공통)  %s %d회" % [r4["name"], int(fired[r4["name"]])])
