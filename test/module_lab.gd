extends SceneTree

## 모듈이 실제로 일을 하는가.
##
##   godot --headless --path . --script res://test/module_lab.gd
##
## ── 왜 필요한가 ──────────────────────────────────────────────────────────
## 표에 적힌 설명은 그 모듈이 **무엇을 하려는지**만 말한다. 실제로 발동하는지,
## 발동해서 행동이 달라지는지는 말하지 않는다.
##
## 두 가지가 조용히 죽는다.
##   1) 조건이 사실상 안 걸린다 - 발동 0회
##   2) 발동은 하는데 안 꽂았을 때와 **같은 행동**을 한다 - 발동 N회, 변화 0회
##
## 2번이 더 나쁘다. 화면에는 모듈 이름이 뜨니까 일하는 것처럼 보인다.
## 그래서 여기서는 발동 횟수와 **행동 변화 횟수**를 따로 센다.
##
## 난수는 없다. 같은 편성·같은 판이면 같은 결과가 나오므로, 한 모듈을 뺀
## 편성과 넣은 편성을 나란히 돌려 틱마다 행동을 비교하면 된다.

const STAGES: Array[int] = [1, 2, 3, 4, 5]

## 축마다 대표 대원을 정한다. 아무 대원에게나 꽂으면 직업 기본기와 엇갈려
## 모듈 탓인지 직업 탓인지 구별이 안 된다.
const CARRIERS: Dictionary = {
	"target": ["archer", "musketeer", "assassin"],
	"position": ["archer", "bard", "warrior"],
	"doctrine": ["warrior", "archer", "bard"],
	"passive": ["warrior", "archer", "bard"],
}

const SLOTS: Array[int] = [0, 2, 4]


func _init() -> void:
	print("\n=== 모듈 실효성 측정 ===\n")
	print("  발동  : 그 모듈이 이번 틱의 행동을 정한 횟수")
	print("  변화  : 그 모듈이 없었을 때와 **다른 행동**을 한 횟수")
	print("  판    : 측정에 쓴 전투 수\n")

	var base := _winrate("")
	var rows: Array = []
	for cid in Cards.shop_order():
		var r := _measure(String(cid))
		r["win"] = _winrate(String(cid))
		r["delta"] = int(r["win"]) - base
		rows.append(r)

	rows.sort_custom(func(a, b): return int(a["delta"]) < int(b["delta"]))

	print("  기준(모듈 없음) 승리 %d / %d판
" % [base, COMPS.size() * STAGES.size()])
	print("%-14s %-9s %-12s %6s %6s %5s %6s" % ["id", "축", "이름", "발동", "변화",
		"승", "증감"])
	print("  " + "-".repeat(70))
	for r in rows:
		var mark := "   "
		if int(r["fire"]) == 0:
			mark = "!! "
		elif int(r["change"]) == 0:
			mark = " ! "
		elif int(r["delta"]) < 0:
			mark = " - "
		elif int(r["delta"]) == 0:
			mark = " . "
		print("%s%-12s %-9s %-12s %6d %6d %5d %+6d" % [mark, r["id"], r["axis"],
			r["name"], r["fire"], r["change"], r["win"], r["delta"]])

	print("
  !! 발동 자체가 없다   ! 행동이 안 바뀐다   - 꽂으면 오히려 진다   . 꽂으나 마나")
	quit(0)


## ── 이 모듈이 이기게 해 주는가 ──────────────────────────────────────────
## 발동과 변화는 "일을 하는가" 만 말한다. 일을 열심히 하고도 지게 만드는
## 모듈이 있다 - 판단을 멈추는 것들이 특히 그렇다.
const COMPS: Array = [
	["warrior", "archer", "bard"],
	["shieldman", "musketeer", "bard"],
	["warrior", "assassin", "archer"],
	["shieldman", "archer", "archer"],
]


func _winrate(cid: String) -> int:
	var wins := 0
	for comp in COMPS:
		for stage in STAGES:
			var party: Array = []
			for i in 3:
				party.append({
					"type": String(comp[i]), "slot": SLOTS[i],
					"cards": [] if cid == "" else [cid],
					"special": "", "special_first": false, "card_levels": {},
					"upgrade": 2, "cmd": {},
				})
			var b := Battle.new()
			b.setup(stage, party)
			b.run()
			if b.result == Battle.RESULT_VICTORY:
				wins += 1
	return wins


## 한 모듈을 넣은 편성과 뺀 편성을 나란히 돌려 비교한다.
func _measure(cid: String) -> Dictionary:
	var c: Dictionary = Cards.TABLE[cid]
	var axis := String(c.get("axis", ""))
	var carriers: Array = CARRIERS.get(axis, ["archer", "bard", "warrior"])

	var fire := 0
	var change := 0
	_card_name = String(c.get("name", cid))
	for stage in STAGES:
		var with_b := _run(stage, carriers, cid)
		var without := _run(stage, carriers, "")
		fire += int(with_b["fire"])
		# 틱·유닛별 행동을 나란히 놓고 다른 것만 센다.
		var a: Dictionary = with_b["acts"]
		var b: Dictionary = without["acts"]
		for k in a:
			if String(a[k]) != String(b.get(k, "")):
				change += 1
	return { "id": cid, "axis": axis, "name": String(c.get("name", cid)),
		"fire": fire, "change": change }


## 편성 셋 전원에게 같은 모듈을 1번 칸에 꽂고 한 판 돌린다.
##
## 셋 다에게 꽂는 이유: 하나에게만 꽂으면 그 대원이 일찍 죽는 판에서 표본이
## 통째로 사라진다. 셋이면 적어도 하나는 끝까지 산다.
## 지금 재고 있는 모듈의 표시 이름. trace 는 id 가 아니라 이름만 남긴다.
var _card_name: String = ""


func _run(stage: int, carriers: Array, cid: String) -> Dictionary:
	var party: Array = []
	for i in 3:
		var cards: Array = [] if cid == "" else [cid]
		party.append({
			"type": String(carriers[i]), "slot": SLOTS[i], "cards": cards,
			"special": "", "special_first": false, "card_levels": {},
			"upgrade": 2, "cmd": {},
		})
	var b := Battle.new()
	b.setup(stage, party)
	b.run()

	var fire := 0
	var acts: Dictionary = {}
	var tick := 0
	for e in b.events:
		var et := String(e.get("type", ""))
		if et == "tick_begin":
			tick = int(e.get("tick", 0))
			continue
		if et == "rule":
			# card_id 는 축을 도입한 뒤로 항상 빈 문자열이다 - 조립부(_rule)가
			# 새로 만든 카드를 돌려주기 때문이다. 어느 모듈이 걸렸는지는
			# trace 에만 남는다. 축별로 hit 인 줄을 찾는다.
			if cid != "":
				var tr: Dictionary = e.get("trace", {})
				for ax in tr:
					for row in tr[ax]:
						if bool(row.get("hit", false)) 								and String(row.get("name", "")) == _card_name:
							fire += 1
			continue
		# 행동 이벤트만 지문으로 남긴다. 어디로 갔는지·누구를 쳤는지까지 담아야
		# "움직이긴 했는데 다른 칸으로 갔다" 가 변화로 잡힌다.
		if et in ["move", "attack", "heal", "defend", "idle", "special"]:
			var key := "%d/%s" % [tick, str(e.get("unit", -1))]
			acts[key] = "%s:%s:%s" % [et, str(e.get("to", "")), str(e.get("target", ""))]
	return { "fire": fire, "acts": acts }
