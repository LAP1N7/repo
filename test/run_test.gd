extends SceneTree

## 상점 / 편성 / 장착 로직 검증 (RunState).
##
##   godot --headless --script res://test/run_test.gd

var failures: int = 0
var checks: int = 0


func _init() -> void:
	print("=== 덱 구성 · 편성 검증 ===\n")
	test_shop()
	test_ban()
	test_escalating_cost()
	test_run_reset()
	test_growth_curve()
	test_speed_bonus()
	test_stage_rewards()
	test_rarity_curve()
	test_reroll_determinism()
	test_roster()
	test_equip()
	test_full_flow()
	test_run_progression()
	test_shadowing()
	test_tutorial()
	test_command()
	test_ban_tokens()
	print("\n=== %d개 검사 / 실패 %d개 ===" % [checks, failures])
	quit(1 if failures > 0 else 0)


func ok(cond: bool, label: String, detail: String = "") -> void:
	checks += 1
	if cond:
		print("  [PASS] %s" % label)
	else:
		failures += 1
		print("  [FAIL] %s  %s" % [label, detail])


## 검사용 런. 시드를 못 박아서 나머지 검사가 매번 같은 제시를 보게 한다.
## 실제 게임은 fixed_seed 가 0 이라 런마다 상점이 달라진다.
func fresh(seed_value: int = 20260731) -> RunState:
	var r := RunState.new()
	r.fixed_seed = seed_value
	r.start_run(1)
	return r


# ── 상점 ─────────────────────────────────────────────────────────────────

func test_shop() -> void:
	print("[1] 상점 · 예산")
	var r := fresh()

	ok(r.budget == RunState.START_BUDGET, "시작 예산 %d" % RunState.START_BUDGET)
	ok(r.offers.size() == RunState.TOTAL_OFFERS,
		"제시 %d칸 (카드 %d + 특수 1)" % [RunState.TOTAL_OFFERS, RunState.SHOP_SIZE])

	var uniq := {}
	for cid in r.offers:
		uniq[cid] = true
	ok(uniq.size() == r.offers.size(), "한 번의 제시 안에 중복 없음", str(r.offers))

	var all_known := true
	for cid in r.offers:
		if cid != "" and not Cards.TABLE.has(cid) and not Specials.TABLE.has(cid):
			all_known = false
	ok(all_known, "제시된 것이 전부 실제 카드 또는 특수")

	# 특수는 같은 풀에서 뽑되 가중치로 희소하게 나와야 한다.
	# 리롤을 여러 번 돌려 등장률이 상식적인 범위인지 본다.
	var slots := 0
	var specials := 0
	for _i in 200:
		r.budget = 99
		r.reroll()
		for cid in r.offers:
			if cid == "":
				continue
			slots += 1
			if RunState.is_special(cid):
				specials += 1
	var rate := float(specials) / maxf(1.0, float(slots)) * 100.0
	print("      특수 등장률 %.1f%% (%d/%d)" % [rate, specials, slots])
	ok(rate > 2.0 and rate < 25.0, "특수 등장률이 희소하되 나오긴 한다", "%.1f%%" % rate)

	# 구매: 예산이 정확히 코스트만큼 줄고, 그 자리는 비고, 손패에 들어간다.
	var target: String = r.offers[0]
	var cost := r.cost_of(target)
	var before := r.budget
	ok(r.buy(0), "구매 성공")
	ok(r.budget == before - cost, "예산이 코스트만큼 차감", "%d → %d (cost %d)" % [before, r.budget, cost])
	ok(r.offers[0] == "", "산 자리는 빈다")
	# 궁극기는 전술과 다른 손패로 간다. 등장률이 스테이지 보정을 받으면서
	# 0번 자리에 궁극기가 뜨는 일이 흔해졌고, hand 만 보던 검사가 그때 터졌다.
	if RunState.is_special(target):
		ok(r.special_hand.size() == 1 and r.special_hand[0] == target, "궁극기 손패에 들어감")
	else:
		ok(r.hand.size() == 1 and r.hand[0] == target, "손패에 들어감")
	ok(not r.buy(0), "빈 자리는 다시 못 산다")

	# 예산 부족
	var poor := fresh()
	poor.budget = 0
	var any_affordable := false
	for i in poor.offers.size():
		if poor.can_buy(i):
			any_affordable = true
	# 코스트 0 카드(사수)가 깔려 있으면 살 수 있다. 그것만 예외.
	var only_free := true
	for i in poor.offers.size():
		if poor.can_buy(i) and poor.cost_of(poor.offers[i]) != 0:
			only_free = false
	ok(only_free, "예산 0이면 코스트 0 카드만 살 수 있다", str(any_affordable))


func test_ban() -> void:
	print("\n[2] 카드 추방")
	var r := fresh()
	# 제외는 정제권을 쓴다. 넉넉히 주고 나머지 동작을 본다 -
	# 정제권이 없을 때의 동작은 [10] 에서 따로 잰다.
	r.refine_tokens = 9
	var victim: String = r.offers[0]

	ok(r.ban(0), "추방 성공")
	ok(r.banned.has(victim), "추방 목록에 등록")
	ok(r.offers[0] == "", "그 자리는 비운다")
	ok(not r.pool().has(victim), "풀에서 제거")

	# 리롤을 여러 번 해도 다시는 안 나와야 한다. 이게 추방의 유일한 의미다.
	var seen := false
	for _i in 30:
		r.budget = 99
		r.reroll()
		if r.offers.has(victim):
			seen = true
	ok(not seen, "리롤 30회에도 추방 카드는 안 나옴", victim)

	# 전부 추방하면 제시가 비어야 하고 리롤도 막혀야 한다 (무한 루프 방지)
	var r2 := fresh()
	r2.refine_tokens = 9
	for cid in Cards.deck_order():
		r2.banned[cid] = true
	for sid in Specials.ORDER:
		r2.banned[sid] = true
	r2.budget = 99
	ok(r2.pool().is_empty(), "전부 추방 시 카드 풀이 빔")
	ok(r2.special_pool().is_empty(), "특수 풀도 빔")
	ok(not r2.can_reroll(), "양쪽 풀이 다 비면 리롤 불가")


func test_escalating_cost() -> void:
	print("
[3-f] 누진 비용 - 한 스테이지에 몇 장이나 살 수 있는가")

	# ── 왜 이 검사가 필요한가 ─────────────────────────────────────────────
	# 슬롯은 3명 x 3칸 = 9칸이다. 실측으로 1스테이지에 평균 8.3장, 최대 11장을
	# 살 수 있었다 - 첫 스테이지에서 이미 슬롯이 다 찬다는 뜻이고, 그러면
	# 2~5스테이지에 자라날 여지가 없다. 리롤이 정액 1이라 원하는 게 나올 때까지
	# 돌려 1코 카드만 골라 담는 것이 가장 큰 원인이었다.

	var buy_all := func(stage: int) -> int:
		var most := 0
		for i in 60:
			var r := RunState.new()
			r.fixed_seed = 9000 + i
			r.start_run(1)
			r.cleared = stage - 1
			r.start(stage)
			var bought := 0
			var guard := 0
			while guard < 200:
				guard += 1
				var pick := -1
				var cheap := 999
				for k in r.offers.size():
					if r.can_buy(k) and r.price_of(r.offers[k]) < cheap:
						cheap = r.price_of(r.offers[k])
						pick = k
				if pick >= 0:
					r.buy(pick)
					bought += 1
				elif not r.reroll():
					break
			most = maxi(most, bought)
		return most

	var s1: int = buy_all.call(1)
	var s5: int = buy_all.call(5)
	print("      최대 구매 - 1스테이지 %d장 / 5스테이지 %d장 (슬롯 9칸)" % [s1, s5])
	ok(s1 <= 6, "1스테이지에 슬롯을 다 못 채운다", "%d장" % s1)
	ok(s5 > s1, "뒤로 갈수록 더 살 수 있다", "%d -> %d" % [s1, s5])

	# 가산금·리롤값이 실제로 오르는가. 상수만 있고 배선이 끊기면 위 검사는
	# 통과할 수도 있다(예산이 원래 빠듯하면). 계산 자체를 직접 본다.
	var r2 := RunState.new()
	r2.fixed_seed = 1
	r2.start_run(1)
	ok(r2.surcharge() == 0, "처음엔 가산금이 없다")
	var base := r2.reroll_cost()
	r2.reroll()
	ok(r2.reroll_cost() > base, "리롤할수록 리롤이 비싸진다",
		"%d -> %d" % [base, r2.reroll_cost()])

	# 스테이지를 넘어가면 리셋된다. 안 그러면 뒤로 갈수록 한 장도 못 산다.
	r2.on_stage_cleared()
	r2.advance()
	ok(r2.surcharge() == 0 and r2.rerolls_this_stage == 0,
		"스테이지가 바뀌면 가산금이 초기화된다")


func test_run_reset() -> void:
	print("
[3-e] 새 런은 정말로 비어 있는가")

	# 튜토리얼을 마치고 [런 시작] 을 누르면 튜토리얼에서 산 카드가 그대로 손패에
	# 남아 있었다. hand.clear() 는 하고 있었지만, 바로 뒤 start() 가 제일 먼저
	# _return_equipped_to_hand() 를 불러 **이전 런의 편성에서 카드를 되돌려 놨다.**
	# 스테이지를 넘어갈 땐 맞는 동작이고 런을 새로 시작할 땐 틀린 동작이다.
	var r := RunState.new()
	r.fixed_seed = 1
	r.start_run(Stages.TUTORIAL_ID)

	# 튜토리얼처럼 사서 꽂아 둔 상태를 만든다.
	r.hand.append("front_line")
	r.hand.append("keep_range")
	ok(r.place("archer", 0), "유닛 배치")
	ok(r.equip(0, "front_line"), "카드 장착 1")
	ok(r.equip(0, "keep_range"), "카드 장착 2")
	ok(r.hand.is_empty(), "손패가 비었다 (전부 꽂힘)")

	# 여기서 새 런을 시작한다.
	r.start_run(1)
	ok(r.hand.is_empty(), "새 런의 손패가 비어 있다", str(r.hand))
	ok(r.special_hand.is_empty(), "새 런의 특수 손패도 비어 있다", str(r.special_hand))
	ok(r.roster.is_empty(), "편성도 비어 있다", str(r.roster.size()))
	ok(r.upgrades.is_empty(), "강화도 초기화된다")

	# 반대로 **스테이지를 넘어갈 때는** 꽂아둔 카드가 손패로 돌아와야 한다.
	# 이걸 같이 검사해야 위 수정이 반대편을 부수지 않았음이 보장된다.
	var r2 := RunState.new()
	r2.fixed_seed = 1
	r2.start_run(1)
	r2.hand.append("front_line")
	r2.place("archer", 0)
	r2.equip(0, "front_line")
	r2.on_stage_cleared()
	r2.advance()
	ok(r2.hand.has("front_line"), "스테이지를 넘어가면 꽂았던 카드가 손패로 돌아온다",
		str(r2.hand))


func test_growth_curve() -> void:
	print("
[3-c] 강화 곡선 — 유닛마다 크는 방향이 다르다")

	# 식이 두 군데 있으면 반드시 갈라진다. 실제로 Unit._scaled 만 성장 계수를 넣고
	# RunState.upgraded_stat 은 안 넣어서, 화면 수치와 전투 수치가 어긋났었다.
	# 지금은 UnitData.scaled 하나뿐이고, 그걸 여기서 못 박는다.
	var r := RunState.new()
	r.start_run(1)
	for tid in UnitData.playable():
		r.upgrades[tid] = 2
	var mismatch := ""
	for tid in UnitData.playable():
		var base_hp: int = int(UnitData.TABLE[tid]["hp"])
		var base_atk: int = int(UnitData.TABLE[tid]["atk"])
		var u := Unit.create(0, String(tid), Unit.TEAM_PLAYER, Vector2i(1, 1), [], "", 2)
		if u.max_hp != r.upgraded_stat(String(tid), "hp", base_hp):
			mismatch = "%s HP %d vs %d" % [tid, u.max_hp, r.upgraded_stat(String(tid), "hp", base_hp)]
		if u.atk != r.upgraded_stat(String(tid), "atk", base_atk):
			mismatch = "%s 공 %d vs %d" % [tid, u.atk, r.upgraded_stat(String(tid), "atk", base_atk)]
	ok(mismatch == "", "전투 스탯과 화면 스탯이 같다", mismatch)

	# 컨셉이 숫자로 나타나는가. 암살자는 공격이, 방패병은 체력이 크게 는다.
	var asn_atk := UnitData.scaled("assassin", "atk", 100, 3) - 100
	var sh_atk := UnitData.scaled("shieldman", "atk", 100, 3) - 100
	ok(asn_atk > sh_atk * 2, "암살자 공격 성장이 방패병보다 훨씬 가파르다",
		"+%d%% vs +%d%%" % [asn_atk, sh_atk])

	var sh_hp := UnitData.scaled("shieldman", "hp", 100, 3) - 100
	var arc_hp := UnitData.scaled("archer", "hp", 100, 3) - 100
	ok(sh_hp > arc_hp, "방패병 체력 성장이 궁수보다 가파르다",
		"+%d%% vs +%d%%" % [sh_hp, arc_hp])

	# 총사는 초·중반 완성형이라 강화를 덜 먹는다.
	ok(UnitData.scaled("musketeer", "atk", 100, 3)
		< UnitData.scaled("archer", "atk", 100, 3),
		"총사는 궁수보다 덜 큰다 — 초·중반 완성형")

	var lv0 := UnitData.scaled("assassin", "atk", 100, 0)
	ok(lv0 == 100, "강화 0단계는 원본 그대로", str(lv0))


func test_speed_bonus() -> void:
	print("
[3-g] 신속 제압 보너스")

	# ── 왜 스테이지마다 기준이 다른가 ─────────────────────────────────────
	# 실측 승리 평균틱이 판마다 3배까지 차이난다(1스테이지 11.2 / 3스테이지 34.3).
	# 방벽과 회복이 낀 판은 원래 오래 걸린다. 하나의 기준으로 재면 그 판은
	# 아무리 잘해도 보너스가 0 이 되고, "빨리 깨는 보상" 이 아니라
	# "짧은 판만 보상" 이 된다.
	var fast_early := RunState.speed_bonus(1, 8)
	var fast_late := RunState.speed_bonus(3, 24)
	ok(fast_early > 0, "1스테이지를 8틱에 깨면 보너스", str(fast_early))
	ok(fast_late > 0, "3스테이지를 24틱에 깨도 보너스 (긴 판이므로)", str(fast_late))

	# 느리면 0. 마이너스는 없다 - 못 깬 것도 아닌데 벌점을 주면 가혹하다.
	ok(RunState.speed_bonus(1, 40) == 0, "기준보다 느리면 0")
	ok(RunState.speed_bonus(1, 999) == 0, "아무리 느려도 마이너스는 없다")

	# 뒤로 갈수록 상한이 크다. 후반강캐가 4~5스테이지를 쓸어담을 때 받는 액수가
	# 초반강캐의 1~2스테이지 이득을 따라잡을 수 있어야 부익부가 안 된다.
	ok(RunState.speed_bonus(5, 1) > RunState.speed_bonus(1, 1),
		"후반 스테이지의 상한이 더 크다",
		"%d vs %d" % [RunState.speed_bonus(1, 1), RunState.speed_bonus(5, 1)])

	# ── 실제로 예산에 들어가는가 ─────────────────────────────────────────
	# 계산만 맞고 배선이 끊기면 화면에는 "신속 제압 +5" 가 뜨는데 예산은 그대로다.
	var r := RunState.new()
	r.fixed_seed = 1
	r.start_run(1)
	var before := r.bonus_budget
	r.on_stage_cleared(8)
	ok(r.last_speed_bonus > 0, "보너스가 기록된다", str(r.last_speed_bonus))
	ok(r.bonus_budget == before + r.last_speed_bonus,
		"보너스가 누적 예산에 들어간다",
		"%d -> %d" % [before, r.bonus_budget])

	# 다음 스테이지 예산에 실제로 반영되는가.
	var expect := RunState.stage_budget(2) + r.last_speed_bonus
	r.advance()
	ok(r.budget == expect, "다음 스테이지 예산에 얹힌다",
		"%d (기대 %d)" % [r.budget, expect])


func test_stage_rewards() -> void:
	print("
[3-d] 스테이지 보상")

	# 보상 예산은 뒤로 갈수록 커져야 한다. 상점의 고가치 카드가 뒤로 갈수록
	# 열리므로(TIER_COPIES), 살 돈이 같이 늘지 않으면 보이기만 하고 못 산다.
	ok(RunState.reward_budget(5) > RunState.reward_budget(1),
		"보상 예산이 스테이지에 따라 는다",
		"%d → %d" % [RunState.reward_budget(1), RunState.reward_budget(5)])
	ok(RunState.reward_tokens(5) >= RunState.reward_tokens(1), "정제권도 줄지 않는다")

	# ── 경제 보상이 다음 스테이지까지 살아남는가 ──────────────────────────
	# start() 가 budget 을 재계산하기 때문에, 예전엔 보상으로 받은 예산이
	# 다음 스테이지 진입 순간 통째로 사라졌다. 경제 보상을 골라도 아무 일도
	# 안 났다는 뜻이고, 화면 어디에도 그 사실이 드러나지 않았다.
	var r2 := RunState.new()
	r2.fixed_seed = 1
	r2.start_run(1)
	r2.on_stage_cleared()
	r2.bonus_budget += 8
	r2.advance()
	var expect := RunState.stage_budget(2) + 8
	ok(r2.budget == expect, "보상 예산이 다음 스테이지로 이월된다",
		"%d (기대 %d)" % [r2.budget, expect])

	# 런을 새로 시작하면 초기화된다.
	r2.start_run(1)
	ok(r2.bonus_budget == 0 and r2.budget == RunState.START_BUDGET,
		"새 런에서는 보상 예산이 초기화된다", str(r2.budget))


func test_rarity_curve() -> void:
	print("
[3-b] 희귀도 곡선 — 고가치는 후반에 열린다")

	# 고가치 카드(3티어)는 1스테이지에 거의 안 뜨고 5스테이지에 흔해야 한다.
	# 이게 런의 파워 곡선이다.
	var early: int = Cards.copies("cut_support", 1)
	var late: int = Cards.copies("cut_support", 5)
	ok(late > early, "구호(3티어)는 뒤로 갈수록 흔해진다", "%d → %d" % [early, late])

	# 기본 도구는 반대다. 처음부터 흔해야 빌드의 바닥이 깔린다.
	ok(Cards.copies("near_first", 1) >= Cards.copies("cut_support", 5),
		"1티어는 처음부터 흔하다",
		"%d vs %d" % [Cards.copies("near_first", 1), Cards.copies("cut_support", 5)])

	# ── 선언한 확률이 실제 동작과 같은가 ──────────────────────────────
	# 지금까지 반복된 버그가 전부 이 어긋남이었다. CARD_WEIGHT 는 테이블에
	# 적힌 weight 를 안 읽었고, 희귀 보상 풀은 사라진 키를 읽었고, 강화 식은
	# 두 곳에 갈라져 있었다. 전부 "데이터는 맞는데 배선이 끊긴" 경우다.
	#
	# 그래서 숫자를 하드코딩해 비교하지 않는다. **선언한 상수를 그대로 읽어서**
	# 실측치와 맞춰 본다. 상수를 고치면 검사도 따라 움직이고, 배선이 끊기면
	# 상수만 바뀌고 실측은 안 따라와서 바로 잡힌다.
	var slot_rate := func(stage: int) -> float:
		var sp := 0
		var slots := 0
		for i in 300:
			var rr := RunState.new()
			rr.fixed_seed = 2000 + i
			rr.start_run(1)
			rr.stage_id = stage
			for _round in 3:
				rr.offers.clear()
				rr._fill_offers()
				for cid in rr.offers:
					if cid == "":
						continue
					slots += 1
					if RunState.is_special(cid):
						sp += 1
		return float(sp) / float(slots) * 100.0

	var drift := ""
	for stage in [1, 3, 5]:
		var want: float = float(RunState.special_chance(stage))
		var got: float = slot_rate.call(stage)
		print("      스테이지 %d — 선언 %.0f%% / 실측 %.1f%%" % [stage, want, got])
		# 표본 오차를 고려해 ±2.5%p 까지 본다.
		if absf(got - want) > 2.5:
			drift = "스테이지 %d: 선언 %.0f%% vs 실측 %.1f%%" % [stage, want, got]
	ok(drift == "", "궁극기 등장 확률이 선언한 값대로 동작한다", drift)

	# 곡선 자체도 확인한다. 초반엔 드물고 후반엔 흔해야 한다.
	ok(RunState.special_chance(5) > RunState.special_chance(1) * 3,
		"5스테이지는 1스테이지보다 훨씬 흔하다",
		"%d%% → %d%%" % [RunState.special_chance(1), RunState.special_chance(5)])

	# 실제 주머니에서도 그런가. 데이터만 맞고 배선이 끊겨 있으면 이 검사가
	# 통과해도 게임은 안 바뀐다 — CARD_WEIGHT 상수가 정확히 그런 상태였다.
	for sid in [1, 5]:
		var r := RunState.new()
		r.fixed_seed = 20260731
		r.start_run(1)
		r.stage_id = sid
		var bag := r._make_bag()
		var rare := 0
		for cid in bag:
			if Cards.TABLE.has(cid) and int(Cards.TABLE[cid].get("tier", 1)) == 3:
				rare += 1
		print("      스테이지 %d — 주머니 %d장 중 3티어 %d장" % [sid, bag.size(), rare])
		if sid == 1:
			ok(rare * 8 < bag.size(), "1스테이지 주머니에 고가치가 희소하다", str(rare))
		else:
			ok(rare * 10 > bag.size(), "5스테이지 주머니에는 고가치가 늘어난다", str(rare))


func test_reroll_determinism() -> void:
	print("
[3] 상점 시드 — 런 안에서는 재현, 런끼리는 달라야 한다")

	# ── 재현성의 의미가 바뀌었다 ──────────────────────────────────────────
	# 예전엔 스테이지별 고정 시드라 **모든 런의 상점이 완전히 같았다.** 영상을
	# 다시 찍기엔 편했지만 로그라이트로서는 치명적이다 — 매번 같은 카드가 같은
	# 순서로 뜨면 덱 빌딩이라는 선택 자체가 없다.
	#
	# 지금은 런 시작마다 시드를 새로 뽑는다. 확인할 것이 둘로 나뉜다:
	#   ① 같은 시드면 조작 순서까지 똑같이 재현된다 (디버깅·영상용)
	#   ② 시드를 안 주면 런마다 달라진다 (게임으로서 성립)

	var seq := func(r: RunState) -> Array[String]:
		var acc: Array[String] = []
		for cid in r.offers:
			acc.append(cid)
		for _i in 4:
			r.reroll()
			for cid in r.offers:
				acc.append(cid)
		return acc

	var a: Array[String] = seq.call(fresh())
	var b: Array[String] = seq.call(fresh())
	ok(a == b, "같은 시드 → 같은 제시", "%d vs %d" % [a.size(), b.size()])
	ok(a != seq.call(fresh(11111)), "다른 시드 → 다른 제시")

	# 시드를 안 주면(실제 게임) 런마다 달라야 한다.
	# 우연히 전부 같을 확률은 사실상 0 이다.
	var wild: Array = []
	for _i in 3:
		var r := RunState.new()
		r.start_run(1)
		wild.append(seq.call(r))
	ok(wild[0] != wild[1] or wild[1] != wild[2],
		"시드를 안 주면 런마다 상점이 달라진다")

	# 스테이지가 다르면 제시도 달라야 한다 (시드가 실제로 쓰이는지)
	var r1 := RunState.new(); r1.start_run(1)
	var r2 := RunState.new(); r2.start_run(2)
	ok(r1.offers != r2.offers, "스테이지마다 다른 제시",
		"%s / %s" % [str(r1.offers), str(r2.offers)])

	# 리롤은 예산을 쓴다
	var r3 := fresh()
	var before := r3.budget
	r3.reroll()
	ok(r3.budget == before - RunState.REROLL_COST, "리롤 비용 차감")


# ── 편성 ─────────────────────────────────────────────────────────────────

func test_roster() -> void:
	print("\n[4] 편성 · 자리 지정")
	var r := fresh()

	ok(r.place("warrior", 4), "배치 성공")
	ok(not r.place("archer", 4), "같은 칸에 두 명 배치 불가")
	ok(r.place("archer", 0), "다른 칸은 가능")
	ok(r.place("bard", 2), "세 번째 배치")
	ok(r.party_full(), "3명이면 정원")
	ok(not r.place("assassin", 5), "정원 초과 배치 불가")
	ok(not r.place("dragon", 5), "없는 유닛 타입 거부")

	# 자리를 무르면 꽂아둔 카드는 손패로 돌아와야 한다. 카드가 증발하면 안 된다.
	r.hand.append("front_line")
	r.equip(0, "front_line")
	ok(r.hand.is_empty(), "장착하면 손패에서 빠짐")
	ok(r.remove_member(0), "배치 무르기")
	ok(r.hand.has("front_line"), "무른 유닛의 카드가 손패로 복귀")
	ok(r.roster.size() == 2, "인원 감소")


func test_equip() -> void:
	print("\n[5] 규칙 장착 · 우선순위")
	var r := fresh()
	r.place("archer", 0)
	r.hand = ["front_line", "run_down", "fall_back", "far_in_range"] as Array[String]

	ok(r.equip(0, "front_line"), "1번 슬롯")
	ok(r.equip(0, "run_down"), "2번 슬롯")
	ok(r.equip(0, "fall_back"), "3번 슬롯")
	ok(not r.equip(0, "far_in_range"), "슬롯 3칸 초과 거부")
	ok(r.hand == ["far_in_range"], "쓴 카드만 손패에서 빠짐", str(r.hand))
	ok(not r.equip(0, "cut_support"), "손패에 없는 카드는 못 꽂음")

	# 순서 바꾸기 = 전략 바꾸기
	ok(r.move_slot(0, 0, 1), "1↔2 교체")
	ok(r.unit_cards[0][0] == "run_down" and r.unit_cards[0][1] == "front_line",
		"순서가 실제로 바뀜", str(r.unit_cards[0]))
	ok(not r.move_slot(0, 0, -1), "맨 위에서 더 못 올림")
	ok(not r.move_slot(0, 2, 1), "맨 아래에서 더 못 내림")

	ok(r.unequip(0, 0), "빼기")
	ok(r.hand.has("run_down"), "뺀 카드는 손패로")
	ok((r.unit_cards[0] as Array).size() == 2, "슬롯 감소")


# ── 전체 흐름 ────────────────────────────────────────────────────────────

func test_full_flow() -> void:
	print("\n[6] 상점 → 편성 → 전투까지 실제로 이어지는가")
	var r := fresh()

	ok(not r.ready_to_fight(), "인원 미달이면 출전 불가")
	ok(r.blocking_reason() != "", "막힌 이유를 알려준다", r.blocking_reason())

	# 예산을 다 써서 카드를 모은다. 살 수 있는 건 다 사고, 모자라면 리롤.
	var guard := 0
	while r.hand.size() < 9 and guard < 60:
		guard += 1
		var bought := false
		for i in r.offers.size():
			if r.can_buy(i):
				r.buy(i)
				bought = true
				break
		if not bought:
			if not r.reroll():
				break
	print("      예산 %d 로 손패 %d장 확보 (리롤 포함 %d회 조작)" % [
		RunState.START_BUDGET, r.hand.size(), guard])
	ok(r.hand.size() >= 2, "예산 %d 로 최소 2장은 모인다" % RunState.START_BUDGET,
		str(r.hand.size()))

	r.place("warrior", 4)
	r.place("archer", 0)
	r.place("archer", 2)
	# 직업 기본기가 생긴 뒤로는 빈손 유닛도 제 몫을 하므로 막지 않는다.
	ok(r.ready_to_fight(), "3명만 채우면 출전 가능", r.blocking_reason())
	ok(r.bare_units().size() == 3, "빈손 유닛은 경고로만 알린다", str(r.bare_units()))

	# 손패가 모자라면 세 번째 대원이 못 받는다. 넉넉히 채워 두고 검사한다.
	for extra in ["near_first", "keep_range", "guard_stance"]:
		r.hand.append(extra)
	for i in 3:
		for cid in r.hand.duplicate():
			if (r.unit_cards[i] as Array).size() >= 1:
				break
			r.equip(i, cid)
	ok(r.bare_units().is_empty(), "카드를 꽂으면 경고가 사라진다", str(r.bare_units()))

	# to_party() 가 Battle.setup() 이 먹는 형식인지 — 여기서 어긋나면 전투가 안 뜬다.
	var party := r.to_party()
	ok(party.size() == 3, "파티 3명")
	var b := Battle.new()
	b.setup(r.stage_id, party)
	# 스테이지마다 적 수가 다르다. 상수로 박으면 밸런스를 고칠 때마다 깨진다.
	# 1페이즈 인원만 센다. 뒷 페이즈는 아직 등장 전이다.
	var want: int = 3 + (Stages.waves(Stages.get_stage(1))[0] as Array).size()
	ok(b.units.size() == want, "전투에 %d명 등장 (아군3 + 적%d)" % [want, want - 3],
		str(b.units.size()))
	var result := b.run()
	ok(result != Battle.RESULT_ONGOING, "전투가 끝까지 간다", result)
	print("      결과: %s (tick %d)" % [result, b.tick])

	# 예산 초과 구매는 절대 불가능해야 한다. 사기 카드 통제의 근거.
	ok(r.budget >= 0, "예산이 음수로 내려가지 않음", str(r.budget))


# ── 런 진행 (로그라이트) ─────────────────────────────────────────────────

func test_run_progression() -> void:
	print("
[7] 런 진행 — 스테이지를 넘어가도 남는 것 / 사라지는 것")
	var r := fresh()

	ok(r.stage_id == 1, "1스테이지에서 시작")
	ok(r.cleared == 0, "클리어 0")
	ok(r.budget == RunState.START_BUDGET, "시작 예산 %d" % RunState.START_BUDGET)

	# 덱을 좀 만들고 편성한다
	r.hand = ["front_line", "forced_march", "far_in_range", "fall_back"] as Array[String]
	r.special_hand = ["unyielding"] as Array[String]
	r.place("warrior", 4)
	r.place("archer", 0)
	r.place("archer", 2)
	r.equip(0, "front_line")
	r.equip_special(0, "unyielding")

	var deck_before := r.hand.size()
	r.on_stage_cleared()
	r.apply_upgrade("warrior")
	r.refine_tokens += 2

	ok(r.advance(), "다음 스테이지로 진행")
	ok(r.stage_id == 2, "스테이지 2", str(r.stage_id))

	# ── 남아야 하는 것
	ok(r.hand.size() == deck_before + 1,
		"덱이 유지된다 (편성 해제로 꽂았던 카드도 복귀)", str(r.hand.size()))
	ok(r.special_hand.has("unyielding"), "특수도 손패로 복귀해 유지된다", str(r.special_hand))
	ok(r.upgrade_level("warrior") == 1, "유닛 강화가 유지된다")
	ok(r.refine_tokens == 2, "정제권이 유지된다")
	ok(r.cleared == 1, "클리어 수가 누적된다")

	# ── 사라져야 하는 것
	ok(r.roster.is_empty(), "편성은 초기화된다 (매 스테이지 새로 짠다)")

	# ── 예산은 클리어할수록 는다
	var expected := RunState.stage_budget(2)
	ok(r.budget == expected, "예산이 클리어 보상만큼 는다", "%d (기대 %d)" % [r.budget, expected])

	# 강화가 실제 전투 스탯에 반영되는가 — 여기가 끊기면 강화가 장식이 된다
	var base_hp: int = UnitData.TABLE["warrior"]["hp"]
	var up_hp := r.upgraded_stat("warrior", "hp", base_hp)
	ok(up_hp > base_hp, "강화가 스탯을 올린다", "%d → %d" % [base_hp, up_hp])

	r.place("warrior", 4)
	r.place("archer", 0)
	r.place("archer", 2)
	var b := Battle.new()
	b.setup(r.stage_id, r.to_party())
	ok(b.units[0].max_hp == up_hp,
		"전투 유닛이 강화된 HP 로 생성된다", "%d vs %d" % [b.units[0].max_hp, up_hp])
	ok(b.units[0].upgrade == 1, "유닛이 강화 단계를 안다")

	# 강화 상한
	for _i in 20:
		r.apply_upgrade("warrior")
	ok(r.upgrade_level("warrior") == RunState.MAX_UPGRADE,
		"강화 상한 %d 를 넘지 않는다" % RunState.MAX_UPGRADE, str(r.upgrade_level("warrior")))
	ok(not r.can_upgrade("warrior"), "만렙이면 더 못 올린다")

	# 정제
	var n_before := r.hand.size()
	var tok := r.refine_tokens
	ok(r.refine(r.hand[0]), "정제로 카드를 버린다")
	ok(r.hand.size() == n_before - 1, "덱에서 실제로 사라진다")
	ok(r.refine_tokens == tok - 1, "정제권을 1장 쓴다")
	r.refine_tokens = 0
	ok(not r.refine(r.hand[0]), "정제권이 없으면 못 버린다")

	# 마지막 스테이지에서는 더 못 간다
	var last := RunState.new()
	last.start_run(Stages.TABLE[Stages.TABLE.size() - 1]["id"])
	ok(not last.has_next_stage(), "마지막 스테이지에는 다음이 없다")
	ok(not last.advance(), "마지막에서 advance 는 실패한다")

	# 런 전체 리셋
	r.start_run(1)
	ok(r.upgrade_level("warrior") == 0 and r.cleared == 0 and r.hand.is_empty(),
		"start_run 은 런 상태를 전부 비운다")


# ── 가려진 슬롯 ──────────────────────────────────────────────────────────

func test_shadowing() -> void:
	print("
[8] 가려진 슬롯 — 위 카드에 막혀 절대 발동 못 하는 카드 찾기")

	# 실제로 플레이 중에 나온 사례.
	# 저격의 조건은 `적이 사거리 안` 이라 적이 들어오는 순간 항상 참이 된다.
	# 그래서 아래의 거리 유지는 단 한 번도 발동하지 못하고, 궁수는 물러나지 않는다.
	# 궁수(사거리 3) 기준. 전사(사거리 1)면 2칸 이내가 사거리 밖이라 안 가려진다.
	var bad := ["backline", "far_in_range"]
	var dead := Shadow.shadowed_slots(bad, 3)
	ok(dead.has(1), "같은 축이면 위가 아래를 가린다", str(dead))
	var w := Shadow.warnings(bad, 3)
	ok(w.size() == 1 and w[0].contains("원거리 추적") and w[0].contains("후열 침투"),
		"경고 문장이 가린 카드와 가려진 카드를 모두 지목한다",
		"" if w.is_empty() else w[0])

	# 순서를 뒤집으면 문제가 사라진다 — 이게 이 게임의 핵심 조작이다.
	ok(Shadow.shadowed_slots(["backline", "keep_range"], 3).is_empty(),
		"축이 다르면 서로 안 가린다")

	# `항상` 조건 공격은 그 아래 전부를 가린다.
	var always_first := ["backline", "far_in_range", "execute"]
	var dead2 := Shadow.shadowed_slots(always_first, 3)
	ok(dead2.has(1) and dead2.has(2), "조건 없는 표적 모듈은 아래 표적을 전부 가린다", str(dead2))

	# ── 축이 다르면 안 가린다 ────────────────────────────────────────────
	# 축을 도입하기 전에는 슬롯 하나가 아래를 전부 가렸다. 지금은 축마다 따로
	# 읽으므로, 표적 하나와 위치 하나는 서로 자리를 다투지 않는다.
	ok(Shadow.shadowed_slots(["near_first", "keep_range"], 3).is_empty(),
		"축이 다르면 위가 아래를 안 가린다")

	# 같은 축에 조건 없는 것이 둘이면 아래는 죽는다. 위치 축도 예외가 아니다.
	#
	# 예전 주석은 "이동 카드는 실행 불가 시 양보하므로 가림이 아니다" 였는데,
	# 그건 축이 없던 시절의 규칙이다. 지금은 축이 **조건**으로 하나를 고르고,
	# 실행 실패는 그 축 안에서 처리된다 - 아래 칸으로 내려가지 않는다.
	ok(not Shadow.shadowed_slots(["keep_range", "front_line"], 3).is_empty(),
		"같은 축에 조건 없는 것이 둘이면 아래가 죽는다")

	# 조건 문턱 비교 — 넓은 조건이 좁은 조건을 가린다
	# 같은 교전 축이고 위가 더 넓은 조건이면 아래는 절대 안 걸린다.
	#
	# 짝을 바꿨다. [부상 후퇴]·[경계 후퇴] 문턱을 50 -> 30 으로 내리고
	# [광전] 을 40 -> 45 로 올리면서 넓고 좁은 쪽이 뒤바뀌었다. 이제
	# 광전(45)이 부상 후퇴(30)를 가린다.
	ok(not Shadow.shadowed_slots(["berserk", "fall_back"], 1).is_empty(),
		"넓은 HP 조건이 좁은 HP 조건을 가린다 (같은 축)")
	ok(Shadow.shadowed_slots(["fall_back", "berserk"], 1).is_empty(),
		"좁은 조건이 위에 있으면 아래는 안 가린다")
	ok(Shadow.implies("self_hp_below", 25, "self_hp_below", 50),
		"HP<25% 는 HP<50% 에 포함된다")
	ok(not Shadow.implies("self_hp_below", 50, "self_hp_below", 25),
		"반대는 성립하지 않는다")

	# 빈 슬롯·미지의 카드에 죽지 않는다
	ok(Shadow.shadowed_slots([], 3).is_empty(), "빈 목록도 처리한다")
	ok(Shadow.shadowed_slots(["front_line", "없는카드"], 3).size() >= 0, "없는 카드에 죽지 않는다")

	# 같은 카드 조합도 유닛에 따라 가림 여부가 달라야 한다 — 이게 사거리를 받는 이유다.
	ok(Shadow.shadowed_slots(["far_in_range", "keep_range"], 1).is_empty(),
		"전사(사거리 1)에게는 저격이 거리 유지를 가리지 않는다")


# ── 튜토리얼 ─────────────────────────────────────────────────────────────

func test_tutorial() -> void:
	print("\n[9] 튜토리얼 — 대본 · 고정 상점")

	var t := Tutorial.new()
	ok(t.load_script(), "대본 JSON 을 읽는다")
	ok(t.steps.size() > 0, "대사가 있다", str(t.steps.size()))
	ok(t.speaker_name != "", "화자 이름이 있다", t.speaker_name)

	# 각 대사가 필요한 필드를 갖췄는가 — 하나라도 빠지면 그 지점에서 진행이 멈춘다.
	var bad := ""
	var screens := {}
	for s in t.steps:
		for key in ["id", "screen", "text", "advance"]:
			if not s.has(key):
				bad = "%s 에 '%s' 없음" % [s.get("id", "?"), key]
		screens[String(s.get("screen", "?"))] = true
		var adv := String(s.get("advance", ""))
		if adv != "click" and not adv.begins_with("action:"):
			bad = "%s: 알 수 없는 advance '%s'" % [s.get("id", "?"), adv]
		# 게이트를 걸었으면 어디를 눌러야 하는지 알려줘야 한다. 아니면 갇힌다.
		if bool(s.get("gate", false)) and String(s.get("anchor", "")) == "":
			bad = "%s: gate 인데 anchor 가 없다 (진행 불가)" % s.get("id", "?")
	ok(bad == "", "모든 대사가 필수 항목을 갖췄다", bad)

	# id 중복은 나중에 특정 대사를 짚을 때 문제가 된다.
	var ids := {}
	var dup := ""
	for s in t.steps:
		var i := String(s["id"])
		if ids.has(i):
			dup = i
		ids[i] = true
	ok(dup == "", "대사 id 가 유일하다", dup)

	print("      화면별 대사: %s" % str(screens.keys()))

	# 진행: 클릭으로 넘어가는 대사는 advance() 로, 행동 대기는 notify_action 으로
	t.start()
	ok(t.active and t.index == 0, "시작하면 첫 대사")
	var guard := 0
	while t.active and guard < 200:
		guard += 1
		var s := t.current()
		var adv := String(s.get("advance", "click"))
		if adv == "click":
			t.advance()
		else:
			t.notify_action(adv.substr(7))
	ok(not t.active, "끝까지 진행된다", "%d 단계" % guard)
	ok(guard == t.steps.size(), "모든 대사를 정확히 한 번씩 지난다",
		"%d / %d" % [guard, t.steps.size()])

	# 엉뚱한 행동에는 반응하지 않아야 한다
	t.start()
	while t.advances_on_click():
		t.advance()
	var before := t.index
	t.notify_action("전혀_다른_행동")
	ok(t.index == before, "기다리는 행동이 아니면 진행하지 않는다")

	# 고정 상점 — 대본이 지목한 카드가 실제로 깔리는가
	var r := RunState.new()
	r.start_run(1)
	r.fixed_offers = ["front_line", "keep_range", "execute"] as Array[String]
	r.offers.clear()
	r._fill_offers()
	ok(r.offers.size() == 3 and r.offers[0] == "front_line", "고정 상점이 그대로 깔린다", str(r.offers))
	r.budget = 99
	r.reroll()
	ok(r.offers[0] == "front_line", "리롤해도 고정 목록이 유지된다", str(r.offers))
	r.start_run(1)
	ok(r.fixed_offers.is_empty(), "새 런에서는 고정이 풀린다")


## ── 보조 지휘 ────────────────────────────────────────────────────────────
## 여기서 걸리길 바라는 것: 예산이 새는 것과, 실험용 장치가 축을 넘는 것.
##
## 축을 넘어가면 안 된다. 표적 모듈을 위치 모듈로 바꿀 수 있으면 축을 나눈
## 의미 자체가 사라진다. 무작위가 끼는 유일한 자리라 특히 확인해 둔다.
func test_command() -> void:
	print("\n[보조 지휘]")
	var r := fresh()
	r.budget = 30

	ok(r.command_level("atk") == 0, "처음에는 전부 0단계")
	ok(r.command_amount("atk") == 0, "0단계는 효과도 0")

	ok(r.command_buy("atk") == "", "예산이 있으면 산다")
	ok(r.command_level("atk") == 1, "단계가 오른다")
	ok(r.budget == 30 - Command.COST_CURVE[0], "코스트만큼 빠진다", str(r.budget))
	ok(r.command_amount("atk") == 5, "1단계 화력 +5%", str(r.command_amount("atk")))

	# 값이 오르지 않으면 "하나를 끝까지" 와 "여럿을 얕게" 가 같은 값이 된다.
	var before := r.budget
	r.command_buy("atk")
	ok(before - r.budget == Command.COST_CURVE[1], "두 번째가 더 비싸다")
	r.command_buy("atk")
	ok(r.command_level("atk") == Command.MAX_LEVEL, "3단계가 최대")
	ok(r.command_buy("atk") != "", "최대면 더 못 산다")
	ok(r.command_level("atk") == Command.MAX_LEVEL, "실패해도 단계가 안 오른다")

	var poor := fresh()
	poor.budget = 0
	var kept := poor.budget
	ok(poor.command_buy("hp") != "", "예산이 없으면 못 산다")
	ok(poor.budget == kept and poor.command_level("hp") == 0, "실패하면 아무것도 안 변한다")

	# 재검색 할인은 최소 1 아래로 못 내려간다 - 공짜 재검색은 상점을 무의미하게 만든다.
	var cheap := fresh()
	cheap.budget = 99
	cheap.command_levels["reroll"] = Command.MAX_LEVEL
	ok(cheap.reroll_cost() >= 1, "재검색은 공짜가 되지 않는다", str(cheap.reroll_cost()))

	# 축 강화는 그 축 모듈을 낀 대원만 받는다.
	var plain := Unit.create(0, "warrior", Unit.TEAM_PLAYER, Vector2i(0, 0),
		["front_line"])
	var base_atk := plain.atk
	plain.apply_command({"axis_target": 8})
	ok(plain.atk == base_atk, "위치 모듈만 낀 대원은 표적 강화를 못 받는다", str(plain.atk))

	var tgt := Unit.create(0, "warrior", Unit.TEAM_PLAYER, Vector2i(0, 0),
		["near_first"])
	tgt.apply_command({"axis_target": 8})
	ok(tgt.atk > base_atk, "표적 모듈을 낀 대원은 받는다", str(tgt.atk))

	# ── 실험용 장치 ──────────────────────────────────────────────────────
	var sw := fresh()
	sw.budget = 20
	sw.hand = ["near_first"] as Array[String]
	ok(sw.command_swap("backline") != "", "없는 모듈은 못 바꾼다")
	ok(sw.command_swap("near_first") == "", "보유 모듈은 바뀐다")
	ok(sw.hand.size() == 1, "장수는 그대로")
	ok(sw.hand[0] != "near_first", "다른 모듈이 됐다", str(sw.hand))
	ok(String(Cards.TABLE[sw.hand[0]]["axis"]) == "target",
		"같은 축 안에서만 바뀐다", str(sw.hand))
	ok(sw.budget == 20 - Command.SWAP_COST, "코스트가 빠진다", str(sw.budget))

	# 같은 시드면 같은 결과여야 리플레이가 성립한다.
	var a := fresh()
	a.budget = 20
	a.hand = ["near_first"] as Array[String]
	a.command_swap("near_first")
	var b := fresh()
	b.budget = 20
	b.hand = ["near_first"] as Array[String]
	b.command_swap("near_first")
	ok(a.hand[0] == b.hand[0], "같은 시드면 같은 모듈이 나온다", str(a.hand))


## ── 제외는 정제권을 쓴다 ─────────────────────────────────────────────────
## 예전에는 공짜였다. 마음에 안 드는 것을 계속 지우면 주머니가 내가 원하는
## 카드로만 남고, 상점이 "무엇이 나왔는가" 가 아니라 "무엇을 남길 것인가" 가
## 된다. 매 런이 같은 덱으로 수렴한다.
##
## 손패를 버리는 것(정제)과 같은 자원을 쓴다. 따로 두면 저울질이 사라진다 -
## 각각 자기 것만 쓰면 되니까.
func test_ban_tokens() -> void:
	print("
[10] 제외 · 정제권")
	var r := fresh()
	r.refine_tokens = 2

	ok(r.ban(0), "정제권이 있으면 제외된다")
	ok(r.refine_tokens == 1, "정제권을 1장 쓴다", str(r.refine_tokens))

	# 같은 자원이므로 손패 정제와 서로 깎아먹는다. 그게 요점이다.
	r.hand = ["near_first"] as Array[String]
	ok(r.refine("near_first"), "남은 1장으로 손패를 버릴 수 있다")
	ok(r.refine_tokens == 0, "이제 0장", str(r.refine_tokens))

	var idx := -1
	for i in r.offers.size():
		if r.offers[i] != "":
			idx = i
			break
	ok(idx >= 0, "제외할 자리가 있다")
	var pool_before := r.pool().size()
	ok(not r.ban(idx), "정제권이 없으면 제외되지 않는다")
	ok(r.offers[idx] != "", "자리가 그대로 남는다")
	ok(r.pool().size() == pool_before, "주머니도 그대로다")
