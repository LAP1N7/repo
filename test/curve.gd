extends SceneTree

## 파워 곡선이 실제로 교차하는가.
##
## "초반강캐를 후반까지 키울까 / 후반강캐를 초반에 버티며 키울까" 가 성립하려면
## 두 조건이 다 필요하다.
##   ① 초반: 초반형이 후반형보다 확실히 세다
##   ② 후반(강화 후): 후반형이 초반형을 **역전한다**
## 역전이 없으면 후반형을 고를 이유가 없고, 그냥 함정 선택지다.

const CARDS := ["near_first", "finisher", "fall_back"]

func _init() -> void:
	print("=== 유닛별 파워 곡선 ===\n")
	print("  유닛      1스테이지 0강    5스테이지 3강    역전폭")
	print("  " + "-".repeat(58))

	var rows: Array = []
	for tid in UnitData.playable():
		var early := win_rate(String(tid), 1, 0)
		var late := win_rate(String(tid), 5, 3)
		rows.append({ "id": tid, "early": early, "late": late })

	rows.sort_custom(func(a, b): return a["late"] - a["early"] > b["late"] - b["early"])
	for r in rows:
		print("  %-8s   %5.1f%%           %5.1f%%          %+6.1f%%p" % [
			UnitData.TABLE[r["id"]]["name"], r["early"] * 100.0,
			r["late"] * 100.0, (r["late"] - r["early"]) * 100.0])
	quit(0)


## 그 유닛 3명으로 스테이지를 돌려 승률을 낸다.
## 전투는 결정론이라 배치를 바꿔가며 표본을 만든다.
func win_rate(tid: String, stage: int, upgrade: int) -> float:
	var wins := 0
	var n := 0
	var slots := [[0, 1, 2], [1, 2, 3], [2, 3, 4], [3, 4, 5], [0, 2, 4], [1, 3, 5]]
	for combo in slots:
		var party: Array = []
		for sl in combo:
			party.append({ "type": tid, "slot": sl, "cards": CARDS, "upgrade": upgrade })
		var b := Battle.new()
		b.setup(stage, party)
		b.run()
		n += 1
		if b.is_won():
			wins += 1
	return float(wins) / float(n)
