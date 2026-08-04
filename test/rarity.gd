extends SceneTree

## 상점에 궁극기가 실제로 얼마나 뜨는가.
##
## 주머니 안의 **장수 비율**과 화면에 실제로 **뜨는 비율**은 다르다.
## _fill_offers 는 한 종류를 뽑으면 그 종류의 사본을 전부 걷어내는데,
## 전술 카드는 한 번에 6장씩 빠지고 궁극기는 2장씩 빠진다. 뒤쪽 슬롯일수록
## 주머니에서 궁극기의 비중이 올라간다 — 명목 가중치보다 자주 뜬다는 뜻이다.

func _init() -> void:
	print("=== 상점 궁극기 등장률 ===\n")
	print("  스테이지  주머니비율   슬롯비율   장당평균   1장이상 뜬 상점")
	print("  " + "-".repeat(62))
	for sid in [1, 2, 3, 4, 5]:
		var bag_ratio := 0.0
		var slots := 0
		var sp_slots := 0
		var shops := 0
		var shops_with := 0

		for seed_i in 400:
			var r := RunState.new()
			r.fixed_seed = 1000 + seed_i
			r.start_run(1)
			r.stage_id = sid
			if seed_i == 0:
				var bag := r._make_bag()
				var n := 0
				for cid in bag:
					if RunState.is_special(cid):
						n += 1
				bag_ratio = float(n) / float(bag.size()) * 100.0
			# 상점 한 번 + 리롤 두 번 = 실제 플레이에 가까운 노출량
			for _round in 3:
				r.offers.clear()
				r._fill_offers()
				shops += 1
				var here := 0
				for cid in r.offers:
					if cid == "":
						continue
					slots += 1
					if RunState.is_special(cid):
						sp_slots += 1
						here += 1
				if here > 0:
					shops_with += 1

		print("     %d      %5.1f%%     %5.1f%%     %4.2f장      %5.1f%%" % [
			sid, bag_ratio, float(sp_slots) / float(slots) * 100.0,
			float(sp_slots) / float(shops), float(shops_with) / float(shops) * 100.0])
	quit(0)
