extends SceneTree

## 런 단위 몬테카를로. 스테이지 1→5 를 통째로 시뮬레이션한다.
##
## ── 왜 단일 전투 시뮬로는 부족한가 ──────────────────────────────────────
## 기존 montecarlo.gd 는 "무작위 카드 3장을 든 유닛이 이 스테이지를 이기는가" 만
## 본다. 그래서 **누적되는 것을 전부 못 본다** — 강화, 합성, 손패, 보상 선택.
##
## 실제로 그 한계가 결론을 왜곡했다:
##   · [복수](아군 사망 시 발동)는 기여도 -4.1%p 로 나온다. 발동했다는 사실
##     자체가 이미 지고 있다는 뜻이라, 단일 전투 승률로는 영원히 마이너스다.
##   · [호위]·[협공] 같은 조율 카드는 **다른 카드와 같이 있어야** 값을 하는데
##     무작위 3장에서는 짝이 맞을 확률이 낮다.
##   · 합성은 아예 측정 대상이 아니었다. 무작위 빌드는 합성을 안 하니까.
##
## 여기서는 정책을 정해 놓고 런을 끝까지 돌린다. 비교 대상은 승률이 아니라
## **어디까지 갔는가** 다.

const RUNS: int = 120

## 조건이 얼마나 좁은가. 작을수록 좁고, 좁은 것이 위로 간다.
##
## 이게 이 게임의 기본기다. `항상` 을 1번에 두면 아래가 전부 죽으므로, 어떤
## 빌드든 "좁은 조건 → 넓은 조건" 순서가 출발점이다. 시뮬레이터도 그렇게 둬야
## 카드의 값을 재는 것이지 배치 실수를 재는 게 아니게 된다.
const COND_RANK: Dictionary = {
	"team_killed_last_tick": 0, "ally_died_last_tick": 0, "killed_last_tick": 0,
	"was_hit_last_tick": 1, "kept_distance_for": 1,
	"other_ally_hp_below": 2, "ally_hp_below": 2, "self_hp_below": 2,
	"enemies_adjacent_at_least": 3, "enemy_within": 3,
	"tick_below": 4, "tick_above": 4, "ally_engaged": 4,
	"enemy_in_range": 5, "enemy_out_of_range": 5,
	"always": 6,
}

const PARTIES: Dictionary = {
	"초반형 (총사2 전사)":   ["musketeer", "musketeer", "warrior"],
	# 암살자 둘은 1스테이지에 거의 전멸한다 - 급습 기본기가 방패병보다 앞서 나가
	# 집중포화를 맞는다. 그건 편성 실수지 후반형의 성립 여부가 아니다.
	# "후반을 노리는 현실적인 편성" 은 암살자 하나에 앞을 세워 주는 쪽이다.
	"후반형 (암살자 방패 악사)": ["assassin", "shieldman", "bard"],
	"혼성 (궁수 전사 악사)": ["archer", "warrior", "bard"],
}


func _init() -> void:
	print("=== 런 단위 시뮬레이션 (스테이지 1→5, %d런) ===\n" % RUNS)

	print("  편성                   상점정책  보상정책   클리어율  평균도달  평균합성")
	print("  " + "-".repeat(76))
	for pname in PARTIES:
		for shop in ["넓게", "깊게"]:
			for rew in ["강화", "희귀"]:
				var r := _many(PARTIES[pname], shop, rew)
				print("  %-22s %-8s %-8s  %5.1f%%   %4.2f     %4.2f" % [
					pname, shop, rew, r["clear"] * 100.0, r["reach"], r["merges"]])
		print("")

	# ── 스테이지별 승률 ───────────────────────────────────────────────────
	# 클리어율은 스테이지 승률의 **곱**이다. 5판을 다 이겨야 하므로 판당 50%면
	# 0.5^5 = 3% 밖에 안 된다. 어느 판이 벽인지는 이걸 봐야 안다.
	print("
  스테이지별 승률 (도달한 런 기준)")
	print("  " + "-".repeat(52))
	var win: Array[int] = [0, 0, 0, 0, 0]
	var seen: Array[int] = [0, 0, 0, 0, 0]
	for pname in PARTIES:
		for i in RUNS:
			_track(PARTIES[pname], "넓게", "강화", 40000 + i, win, seen)
	for k in 5:
		var rate: float = 0.0 if seen[k] == 0 else float(win[k]) / float(seen[k]) * 100.0
		print("     %d스테이지   도달 %4d런   승 %5.1f%%" % [k + 1, seen[k], rate])
	quit(0)


## 스테이지마다 도달·승리를 센다.
func _track(types: Array, shop: String, rew: String, seed_v: int,
		win: Array[int], seen: Array[int]) -> void:
	var run := RunState.new()
	run.fixed_seed = seed_v
	run.start_run(1)
	var stage := 1
	while stage <= 5:
		if stage > 1:
			run.start(stage)
		_shop(run, shop)
		_equip(run, types)
		var b := Battle.new()
		b.setup(stage, run.to_party())
		b.run()
		seen[stage - 1] += 1
		if not b.is_won():
			return
		win[stage - 1] += 1
		run.on_stage_cleared(b.tick)
		_reward(run, types, rew)
		stage += 1


func _many(types: Array, shop: String, rew: String) -> Dictionary:
	var cleared := 0
	var reach := 0.0
	var merges := 0.0
	for i in RUNS:
		var out := _one(types, shop, rew, 30000 + i)
		if out["stage"] > 5:
			cleared += 1
		reach += float(mini(int(out["stage"]), 5))
		merges += float(out["merges"])
	return {
		"clear": float(cleared) / float(RUNS),
		"reach": reach / float(RUNS),
		"merges": merges / float(RUNS),
	}


## 런 하나. 반환 stage 는 "죽은 스테이지"이고 6이면 전부 깼다는 뜻이다.
func _one(types: Array, shop: String, rew: String, seed_v: int) -> Dictionary:
	var run := RunState.new()
	run.fixed_seed = seed_v
	run.start_run(1)

	var merges := 0
	var stage := 1
	while stage <= 5:
		if stage > 1:
			run.start(stage)
		merges += _shop(run, shop)
		_equip(run, types)

		var b := Battle.new()
		b.setup(stage, run.to_party())
		b.run()
		if not b.is_won():
			break

		run.on_stage_cleared(b.tick)
		_reward(run, types, rew)
		stage += 1
	return { "stage": stage, "merges": merges }


## 상점. "넓게" 는 살 수 있는 만큼 사고, "깊게" 는 합성을 우선한다.
func _shop(run: RunState, policy: String) -> int:
	var merged := 0
	var guard := 0
	while guard < 60:
		guard += 1

		# 깊게: 합칠 수 있으면 먼저 합친다. 이제 예산을 쓰므로 카드를 덜 사게 된다.
		if policy == "깊게":
			var did := false
			for cid in run.hand.duplicate():
				if run.can_merge(String(cid)):
					run.merge(String(cid))
					merged += 1
					did = true
					break
			if did:
				continue

		# 무엇을 사는가.
		#   넓게 - 제일 싼 것부터. 장수를 최대로 늘린다.
		#   깊게 - 티어가 높은 것부터. 좋은 카드를 적게 갖는다.
		# 싼 것만 담는 정책은 실제 플레이보다 약하다. 두 정책을 갈라 놓아야
		# "많이 vs 좋게" 라는 실제 선택지를 재는 것이 된다.
		var pick := -1
		var best := -999
		for k in run.offers.size():
			if not run.can_buy(k):
				continue
			var cid := String(run.offers[k])
			var score := 0
			if policy == "깊게":
				score = (9 if RunState.is_special(cid)
					else int(Cards.TABLE[cid].get("tier", 1))) * 10 - run.price_of(cid)
			else:
				score = -run.price_of(cid)
			if score > best:
				best = score
				pick = k
		if pick >= 0:
			run.buy(pick)
			continue

		# 깊게는 리롤로 같은 카드를 더 노린다. 넓게는 예산을 카드에만 쓴다.
		if policy == "깊게" and run.can_reroll() and run.reroll_cost() <= 3:
			run.reroll()
			continue
		break
	return merged


## 편성. 유닛을 세우고 카드를 나눠 꽂는다.
##
## ── 조건 순서만으로 나누면 안 된다 ──────────────────────────────────────
## 처음엔 조건이 좁은 순으로 정렬해 앞 유닛부터 돌렸다. 그랬더니 암살자(공 32)가
## [후퇴]·[구호]를 들고 방패병이 [교전]을 들었다. 암살자가 전투 내내 회복만 하니
## 후반형 편성의 1스테이지 승률이 **0%** 로 나왔다.
##
## 그건 게임이 아니라 하네스가 진 것이다. 실제 플레이어는 공격 카드를 딜러에게
## 주고 회복을 서포터에게 준다. 그래서 두 단계로 나눈다:
##   1. 카드-유닛 궁합으로 배분한다
##   2. 유닛 안에서 조건이 좁은 순으로 정렬해 꽂는다
func _equip(run: RunState, types: Array) -> void:
	for i in types.size():
		run.place(String(types[i]), i * 2)

	for m in run.roster.size():
		for sid in run.special_hand.duplicate():
			if run.can_equip_special(m, String(sid)):
				run.equip_special(m, String(sid))
				break

	# 유닛별로 담을 목록을 먼저 만든다.
	var plan: Array = []
	for _m in run.roster.size():
		plan.append([] as Array[String])

	# 공격 카드를 먼저 한 장씩 돌린다. 공격 수단 없는 유닛이 생기면 안 된다.
	var pool := run.hand.duplicate()
	for m in run.roster.size():
		for cid in pool:
			if String(Cards.TABLE[cid]["act"]) == "attack":
				(plan[m] as Array).append(String(cid))
				pool.erase(cid)
				break

	# 나머지는 궁합이 좋은 유닛에게 준다.
	for cid in pool.duplicate():
		var best_m := -1
		var best_fit := -999
		for m in run.roster.size():
			if (plan[m] as Array).size() >= RunState.SLOTS_PER_UNIT:
				continue
			var fit := _fit(String(cid), String(run.roster[m]["type"]))
			if fit > best_fit:
				best_fit = fit
				best_m = m
		if best_m < 0:
			break
		(plan[best_m] as Array).append(String(cid))
		pool.erase(cid)

	# 유닛 안에서 조건이 좁은 순으로 꽂는다. 이 순서가 곧 전술이다.
	for m in run.roster.size():
		var lst: Array = plan[m]
		lst.sort_custom(func(a, b): return _rank(String(a)) < _rank(String(b)))
		for cid in lst:
			run.equip(m, String(cid))


## 이 카드가 이 유닛에게 얼마나 맞는가.
func _fit(cid: String, tid: String) -> int:
	var c: Dictionary = Cards.TABLE[cid]
	var act := String(c["act"])
	var atk: int = int(UnitData.TABLE[tid]["atk"])
	var rng: int = int(UnitData.TABLE[tid]["range"])
	match act:
		"attack":
			return atk
		"heal":
			# 공격력이 낮을수록 회복에 시간을 쓰는 게 이득이다.
			return 40 - atk
		"move_away":
			# 물러나며 쏘는 건 사거리가 길어야 성립한다. 사거리 1이면 자해다.
			return 20 if rng >= 3 else -20
		"move_toward", "move_to_ally":
			return 15 if rng <= 1 else 0
		"defend":
			return int(UnitData.TABLE[tid]["hp"]) / 20
		"hold":
			return 10 if rng >= 2 else -10
	return 0


func _rank(cid: String) -> int:
	if not Cards.TABLE.has(cid):
		return 9
	return int(COND_RANK.get(String(Cards.TABLE[cid]["cond"]), 5))


## 보상. 화면 로직을 그대로 흉내낸다.
func _reward(run: RunState, types: Array, policy: String) -> void:
	if policy == "강화":
		# 성장 계수가 제일 가파른 유닛에 몰아준다.
		var best := ""
		var best_g := -1
		for t in types:
			if not run.can_upgrade(String(t)):
				continue
			var g: int = maxi(UnitData.growth(String(t), "hp"),
				UnitData.growth(String(t), "atk"))
			if g > best_g:
				best_g = g
				best = String(t)
		if best != "":
			var lv: int = 1 if run.cleared < 3 else 2
			for _i in lv:
				run.apply_upgrade(best)
			return

	# 희귀 보상 — 3티어 카드나 궁극기를 하나 받는다.
	var pool: Array[String] = []
	for cid in Cards.DECK_ORDER:
		if int(Cards.TABLE[cid].get("tier", 1)) >= 3:
			pool.append(cid)
	for sid in Specials.ORDER:
		pool.append(sid)
	var idx: int = (run.cleared * 7 + run.stage_id * 3) % pool.size()
	run.grant_card(pool[idx])
