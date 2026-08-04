extends SceneTree

## 한 스테이지에서 카드를 몇 장이나 살 수 있는가.
##
## 슬롯은 3명 × 3칸 = 9칸이다. 1스테이지에 9칸을 거의 채울 수 있으면
## 2~5스테이지에 자라날 여지가 없다.

func _init() -> void:
	print("=== 스테이지별 구매 가능 장수 ===\n")
	print("  스테이지  예산   평균장수  최대장수  슬롯9칸중")
	print("  " + "-".repeat(54))
	for sid in [1, 2, 3, 4, 5]:
		var total := 0
		var best := 0
		var n := 200
		var budget := 0
		for i in n:
			var r := RunState.new()
			r.fixed_seed = 5000 + i
			r.start_run(1)
			# 스테이지별 예산·상점 구성으로 맞춘다.
			r.cleared = sid - 1
			r.start(sid)
			budget = r.budget
			var bought := _greedy(r)
			total += bought
			best = maxi(best, bought)
		var avg := float(total) / float(n)
		print("     %d      %3d    %5.1f장   %3d장     %4.0f%%" % [
			sid, budget, avg, best, avg / 9.0 * 100.0])

	print("
=== 런 전체 누적 (손패는 스테이지를 넘어 쌓인다) ===
")
	print("  스테이지  이번에 산 장수   누적 손패   슬롯 9칸 대비")
	print("  " + "-".repeat(54))
	var runs := 200
	var acc: Array[float] = [0, 0, 0, 0, 0]
	var got: Array[float] = [0, 0, 0, 0, 0]
	for i in runs:
		var r := RunState.new()
		r.fixed_seed = 7000 + i
		r.start_run(1)
		for sid in [1, 2, 3, 4, 5]:
			if sid > 1:
				r.cleared = sid - 1
				r.start(sid)
			var before := r.hand.size() + r.special_hand.size()
			_greedy(r)
			var after := r.hand.size() + r.special_hand.size()
			got[sid - 1] += float(after - before)
			acc[sid - 1] += float(after)
	for sid in [1, 2, 3, 4, 5]:
		var a: float = acc[sid - 1] / float(runs)
		print("     %d          %4.1f장        %4.1f장       %4.0f%%" % [
			sid, got[sid - 1] / float(runs), a, a / 9.0 * 100.0])

	quit(0)


## 싼 것부터 최대한 사고, 못 사면 리롤한다. 플레이어가 할 수 있는 최선에 가깝다.
func _greedy(r: RunState) -> int:
	var bought := 0
	var guard := 0
	while guard < 200:
		guard += 1
		var best_i := -1
		var best_cost := 99
		for i in r.offers.size():
			if r.can_buy(i) and r.cost_of(r.offers[i]) < best_cost:
				best_cost = r.cost_of(r.offers[i])
				best_i = i
		if best_i >= 0:
			r.buy(best_i)
			bought += 1
			continue
		if not r.reroll():
			break
	return bought
