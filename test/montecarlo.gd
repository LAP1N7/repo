extends SceneTree

## 몬테카를로 밸런스 시뮬레이션.
##
##   godot --headless --script res://test/montecarlo.gd
##
## ── 무엇에 난수를 뿌리는가 ──────────────────────────────────────────────
## 전투(Battle)는 난수를 한 번도 쓰지 않는다. 같은 편성·같은 카드면 결과가 항상
## 같으므로 "같은 전투를 여러 번 돌리는" 몬테카를로는 의미가 없다.
##
## 그래서 표본을 뿌리는 대상은 전투가 아니라 **설정 공간**이다:
##   편성(5종 중 3명, 중복 허용) × 자리(6칸 중 3칸) × 예산 24 안의 카드 조합
## 이 공간에서 무작위로 뽑아 각각 한 번씩 결정론적으로 돌리고, 결과를 집계한다.
##
## 시드를 고정했으므로 이 스크립트의 출력 자체도 재현 가능하다.
## ────────────────────────────────────────────────────────────────────────

const SAMPLES: int = 3000
const SEED: int = 20260731

var rng: RandomNumberGenerator


func _init() -> void:
	rng = RandomNumberGenerator.new()

	print("=== 몬테카를로 밸런스 시뮬레이션 ===")
	print("표본 %d개 / 스테이지 (시드 %d, 예산 %d)\n" % [SAMPLES, SEED, RunState.START_BUDGET])

	var t0 := Time.get_ticks_msec()
	for stage_id in [1, 2]:
		run_stage(stage_id)
	print("\n총 소요 %.1f초 / 전투 %d회" % [
		(Time.get_ticks_msec() - t0) / 1000.0, SAMPLES * 2])
	quit(0)


# ── 표본 생성 ────────────────────────────────────────────────────────────

## 예산 안에서 무작위로 카드를 산다. 실제 상점과 같은 제약을 받는다.
func sample_cards() -> Array[String]:
	var budget := RunState.START_BUDGET
	var out: Array[String] = []
	var guard := 0
	while out.size() < RunState.PARTY_SIZE * RunState.SLOTS_PER_UNIT and guard < 100:
		guard += 1
		var cid: String = Cards.deck_order()[rng.randi_range(0, Cards.deck_order().size() - 1)]
		var cost := int(Cards.TABLE[cid]["cost"])
		if cost > budget:
			continue
		budget -= cost
		out.append(cid)
		# 예산이 남아도 가끔 그만 산다. 실제 플레이의 손패 크기 분포를 흉내낸다.
		if budget <= 0 or rng.randf() < 0.08:
			break
	return out


func sample_party() -> Array:
	# playable() 를 써야 한다. TABLE.keys() 는 튜토리얼 전용 훈련 표적(dummy)까지
	# 뽑아서 플레이어 편성에 넣는다 — 실제로 표본의 1/7 이 표적이었고, 승률 1.8%
	# 짜리 유닛이 전 통계를 아래로 끌어내리고 있었다.
	var types := UnitData.playable()
	var slots: Array[int] = [0, 1, 2, 3, 4, 5]
	# 자리 3칸을 겹치지 않게 고른다.
	var chosen: Array[int] = []
	for _i in RunState.PARTY_SIZE:
		chosen.append(slots.pop_at(rng.randi_range(0, slots.size() - 1)))

	var hand := sample_cards()
	var party: Array = []
	for i in RunState.PARTY_SIZE:
		party.append({
			"type": String(types[rng.randi_range(0, types.size() - 1)]),
			"slot": chosen[i],
			"cards": [] as Array,
		})
	# 손패를 유닛들에게 무작위로 흩뿌린다.
	for cid in hand:
		var tries := 0
		while tries < 6:
			tries += 1
			var m := rng.randi_range(0, RunState.PARTY_SIZE - 1)
			if (party[m]["cards"] as Array).size() < RunState.SLOTS_PER_UNIT:
				(party[m]["cards"] as Array).append(cid)
				break
	return party


# ── 집계 ─────────────────────────────────────────────────────────────────

func run_stage(stage_id: int) -> void:
	var st := Stages.get_stage(stage_id)
	print("══ 스테이지 %d — %s  (적 전략: %s)" % [
		stage_id, st["name"], st["strategy_text"]])

	rng.seed = SEED + stage_id     # 스테이지마다 같은 표본을 재현

	var wins := 0
	var losses := 0
	var timeouts := 0
	var tick_sum := 0

	# 카드별 { present, present_win, fired }
	var card_stat: Dictionary = {}
	for cid in Cards.deck_order():
		card_stat[cid] = { "present": 0, "win": 0, "fired": 0 }

	# 유닛별 { used, win }
	var unit_stat: Dictionary = {}
	for tid in UnitData.playable():
		unit_stat[tid] = { "used": 0, "win": 0 }

	# 카드 × 유닛. 이게 없으면 유닛 의존적인 카드를 "나쁜 카드" 로 오독한다.
	# 시뮬레이터는 카드를 아무 유닛에나 꽂으므로, 거리 유지처럼 궁수 전용에 가까운
	# 카드는 평균만 보면 항상 최악으로 나온다. 카드가 나쁜 게 아니라 배치가 나쁜 것이다.
	var cu_stat: Dictionary = {}
	for cid in Cards.deck_order():
		var per: Dictionary = {}
		for tid in UnitData.playable():
			per[tid] = { "n": 0, "win": 0 }
		cu_stat[cid] = per

	var rule_events := 0
	var innate_events := 0
	var idle_events := 0
	var bare_units := 0

	for _n in SAMPLES:
		var party := sample_party()
		var b := Battle.new()
		b.setup(stage_id, party)
		var result := b.run()
		var won := result == Battle.RESULT_VICTORY

		match result:
			Battle.RESULT_VICTORY: wins += 1
			Battle.RESULT_DEFEAT: losses += 1
			_: timeouts += 1
		tick_sum += b.tick

		# 이번 표본에 등장한 카드 / 실제로 발동한 카드
		var present: Dictionary = {}
		for m in party:
			if (m["cards"] as Array).is_empty():
				bare_units += 1
			var t: String = m["type"]
			for cid in m["cards"]:
				present[cid] = true
				cu_stat[cid][t]["n"] += 1
				if won:
					cu_stat[cid][t]["win"] += 1
			unit_stat[t]["used"] += 1
			if won:
				unit_stat[t]["win"] += 1

		var fired: Dictionary = {}
		for e in b.events:
			match e["type"]:
				"rule":
					rule_events += 1
					if bool(e.get("innate", false)):
						innate_events += 1
					else:
						fired[e["card_id"]] = true
				"idle":
					idle_events += 1

		for cid in present:
			card_stat[cid]["present"] += 1
			if won:
				card_stat[cid]["win"] += 1
			if fired.has(cid):
				card_stat[cid]["fired"] += 1

	var total := float(SAMPLES)
	print("   승 %5.1f%%   패 %5.1f%%   타임아웃 %5.1f%%   평균 %4.1f틱" % [
		wins / total * 100.0, losses / total * 100.0,
		timeouts / total * 100.0, float(tick_sum) / total])

	var base_wr := wins / total * 100.0

	print("\n   카드                코스트  채용률   채용시승률   기여도   발동률")
	print("   " + "─".repeat(68))
	var rows: Array = []
	for cid in Cards.deck_order():
		var s: Dictionary = card_stat[cid]
		var p: int = s["present"]
		if p == 0:
			continue
		var wr := float(s["win"]) / float(p) * 100.0
		rows.append({
			"cid": cid,
			"cost": int(Cards.TABLE[cid]["cost"]),
			"pick": float(p) / total * 100.0,
			"wr": wr,
			"lift": wr - base_wr,
			"fire": float(s["fired"]) / float(p) * 100.0,
		})
	rows.sort_custom(func(a, b): return a["lift"] > b["lift"])

	for r in rows:
		var flag := ""
		if r["fire"] < 25.0:
			flag = "  ← 거의 안 터짐"
		elif r["lift"] > 6.0:
			flag = "  ← 강함"
		elif r["lift"] < -6.0:
			flag = "  ← 약함"
		# 리터럴 % 는 %% 로 써야 한다. "%p" 는 포맷 지정자로 파싱돼 통째로 실패한다.
		print("   %-16s %4d   %5.1f%%   %6.1f%%   %+6.1f%%p   %5.1f%%%s" % [
			Cards.TABLE[r["cid"]]["name"], r["cost"], r["pick"],
			r["wr"], r["lift"], r["fire"], flag])

	# 유닛에 따라 성능이 갈리는 카드를 골라낸다. 편차가 크면 "나쁜 카드" 가 아니라
	# "쓸 자리가 정해진 카드" 다. 평균만 보고 코스트를 내리면 오히려 헛짚는다.
	print("\n   유닛 의존도 — 유닛 자체 승률을 뺀 순수 시너지")
	print("   " + "─".repeat(68))

	# 유닛별 기본 승률. 이걸 안 빼면 편차가 카드 시너지가 아니라 "궁수가 세다"만
	# 반복해서 보여준다. 실제로 처음엔 그렇게 나왔다.
	var unit_base: Dictionary = {}
	for tid in unit_stat:
		var us: Dictionary = unit_stat[tid]
		unit_base[tid] = 0.0 if int(us["used"]) == 0 \
			else float(us["win"]) / float(us["used"]) * 100.0

	var spread: Array = []
	for cid in Cards.deck_order():
		var best_t := ""
		var worst_t := ""
		var best := -999.0
		var worst := 999.0
		for tid in cu_stat[cid]:
			var e: Dictionary = cu_stat[cid][tid]
			if int(e["n"]) < 60:      # 표본이 적으면 잡음이라 뺀다
				continue
			var lift := float(e["win"]) / float(e["n"]) * 100.0 - float(unit_base[tid])
			if lift > best:
				best = lift; best_t = String(tid)
			if lift < worst:
				worst = lift; worst_t = String(tid)
		if best_t == "" or worst_t == "":
			continue
		spread.append({
			"cid": cid, "gap": best - worst,
			"bt": UnitData.TABLE[best_t]["name"], "bw": best,
			"wt": UnitData.TABLE[worst_t]["name"], "ww": worst,
		})
	spread.sort_custom(func(a, b): return a["gap"] > b["gap"])
	for i in mini(6, spread.size()):
		var r = spread[i]
		print("   %-16s 최적 %-4s %+5.1f%%p   최악 %-4s %+5.1f%%p   편차 %5.1f%%p" % [
			Cards.TABLE[r["cid"]]["name"], r["bt"], r["bw"], r["wt"], r["ww"], r["gap"]])

	print("\n   유닛          채용수   승률")
	print("   " + "─".repeat(34))
	var urows: Array = []
	for tid in unit_stat:
		var s2: Dictionary = unit_stat[tid]
		if s2["used"] == 0:
			continue
		urows.append({
			"name": String(UnitData.TABLE[tid]["name"]),
			"used": int(s2["used"]),
			"wr": float(s2["win"]) / float(s2["used"]) * 100.0,
		})
	urows.sort_custom(func(a, b): return a["wr"] > b["wr"])
	for r in urows:
		print("   %-12s %6d   %5.1f%%" % [r["name"], r["used"], r["wr"]])

	var re := maxf(1.0, float(rule_events))
	print("\n   행동 %d회 중 기본기 폴백 %.1f%%   ·   멍때림 %d회 (%.3f회/전투)" % [
		rule_events, float(innate_events) / re * 100.0,
		idle_events, float(idle_events) / total])
	print("   빈손 유닛 %d명 (표본당 %.2f명)\n" % [bare_units, float(bare_units) / total])
