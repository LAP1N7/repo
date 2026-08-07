extends SceneTree

## 튜토리얼 대본이 지금 데이터와 맞는지.
##
## ── 왜 필요한가 ──────────────────────────────────────────────────────────
## 대본은 자리를 지목한다 - "0번 카드를 사라", "2번을 제외하라". 그 자리에
## 무엇이 놓이는지는 view/game.gd 의 fixed_offers 가 정하고, 그 이름이 실제로
## 존재하는지는 data/cards.gd 가 정한다. 셋이 따로 놀 수 있는 구조다.
##
## 실제로 따로 놀았다. fixed_offers 에 engage / keep_distance / pursue /
## hold_ground 가 적혀 있었는데 축을 도입하면서 표를 갈아엎을 때 이 줄이 안
## 따라왔다. 튜토리얼 상점이 통째로 비었고, 아무도 몰랐다.

const OFFERS: Array[String] = [
	"near_first", "keep_range", "guard_stance", "execute", "front_line",
]

var fails := 0


func _init() -> void:
	print("\n=== 튜토리얼 대본 검사 ===\n")

	# 1) 고정 제시가 전부 실재하는 모듈인가
	for cid in OFFERS:
		_ok(Cards.TABLE.has(cid), "고정 제시 [%s] 가 모듈 표에 있다" % cid)

	# 2) 예산 12 로 0번과 1번을 살 수 있는가. 대본이 그 둘을 사라고 시킨다.
	var need: int = int(Cards.TABLE[OFFERS[0]]["cost"]) + int(Cards.TABLE[OFFERS[1]]["cost"])
	_ok(need <= 12, "0번+1번 값이 예산 12 안이다 (%d)" % need)

	# 3) 대본이 [제외] 를 시킨다면 정제권이 있어야 한다. 시키는 대로 해도
	#    안 되는 튜토리얼은 튜토리얼이 아니다.
	var game_src := FileAccess.get_file_as_string("res://view/game.gd")
	_ok(game_src.contains("run.refine_tokens = 1"),
		"튜토리얼이 정제권을 한 장 준다")

	# 4) 대본 자체
	# 실제 게임과 같은 경로로 읽는다. 파일을 직접 파싱하면 story.json 에서
	# 대사를 끌어오는 단계를 건너뛰어, 대사가 비어도 통과해 버린다.
	var tut := Tutorial.new()
	_ok(tut.load_script(), "대본을 읽을 수 있다")
	var steps: Array = tut.steps
	_ok(steps.size() > 0, "대사가 있다")

	var seen: Dictionary = {}
	var ticks: Array = []
	for s in steps:
		var st: Dictionary = s
		var id := String(st.get("id", ""))
		_ok(id != "" and not seen.has(id), "id 가 비지 않고 안 겹친다: %s" % id)
		seen[id] = true
		# 대사는 story.json 에서 온다. Tutorial.load_script() 가 채워 넣으므로
		# 여기서는 **채워진 뒤의 상태**를 본다 - 둘 중 어느 파일이 비어도 잡힌다.
		_ok(String(st.get("text", "")) != "", "%s 에 대사가 있다" % id)
		var scr := String(st.get("screen", "any"))
		_ok(scr in ["tutorial", "shop", "command", "loadout", "battle", "any"],
			"%s 의 screen 이 유효하다 (%s)" % [id, scr])
		var adv := String(st.get("advance", "click"))
		_ok(adv == "click" or adv.begins_with("action:"),
			"%s 의 advance 가 유효하다 (%s)" % [id, adv])
		# 게이트는 앵커가 있어야 의미가 있다. 앵커 없이 막으면 아무것도 못 누른다.
		if bool(st.get("gate", false)):
			_ok(String(st.get("anchor", "")) != "",
				"%s 가 막고 있으면 가리킬 곳도 있다" % id)
		if st.has("at_tick"):
			ticks.append(int(st["at_tick"]))

	# 4) 틱 정지 지점이 오름차순인가. 뒤엉키면 그 대사는 영영 안 뜬다.
	var sorted_ticks := ticks.duplicate()
	sorted_ticks.sort()
	_ok(ticks == sorted_ticks, "틱 정지 지점이 오름차순이다 %s" % [ticks])

	# 5) 훈련장이 그 틱까지 실제로 굴러가는가
	var party: Array = [{
		"type": "archer", "slot": 0, "cards": ["near_first", "keep_range"],
		"special": "", "special_first": false, "card_levels": {},
		"upgrade": 1, "cmd": {},
	}]
	var b := Battle.new()
	b.setup(Stages.TUTORIAL_ID, party)
	var last: int = int(ticks[ticks.size() - 1]) if not ticks.is_empty() else 0
	var reached := 0
	for _i in last:
		if b.result != Battle.RESULT_ONGOING:
			break
		b.step()
		reached = b.tick
	_ok(reached >= last, "훈련장이 마지막 해설 틱(%d)까지 간다 - 실제 %d" % [last, reached])

	print("\n=== %d개 검사 / 실패 %d개 ===" % [_n, fails])
	quit(1 if fails > 0 else 0)


var _n := 0

func _ok(cond: bool, msg: String) -> void:
	_n += 1
	if not cond:
		fails += 1
		print("  [FAIL] %s" % msg)
