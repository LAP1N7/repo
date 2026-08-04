extends SceneTree

## 편성 탐색 / 밸런싱 도구.
##
##   godot --headless --script res://test/explore.gd
##
## 후보 편성을 스테이지에 돌려보고 결과를 표로 뽑는다. 밸런싱(D7)에 계속 쓴다.

func _init() -> void:
	print("=== 편성 탐색 ===\n")

	var candidates := {
		"궁수3 / 교전만": [
			{ "type": "archer", "slot": 3, "cards": ["engage"] },
			{ "type": "archer", "slot": 4, "cards": ["engage"] },
			{ "type": "archer", "slot": 5, "cards": ["engage"] },
		],
		"궁수3 / 교전+추격": [
			{ "type": "archer", "slot": 3, "cards": ["engage", "pursue"] },
			{ "type": "archer", "slot": 4, "cards": ["engage", "pursue"] },
			{ "type": "archer", "slot": 5, "cards": ["engage", "pursue"] },
		],
		"궁수3 / 거리유지+교전": [
			{ "type": "archer", "slot": 3, "cards": ["keep_distance", "engage"] },
			{ "type": "archer", "slot": 4, "cards": ["keep_distance", "engage"] },
			{ "type": "archer", "slot": 5, "cards": ["keep_distance", "engage"] },
		],
		"방패 앞 + 궁수2 뒤": [
			{ "type": "shieldman", "slot": 4, "cards": ["engage", "charge"] },
			{ "type": "archer",    "slot": 0, "cards": ["engage", "pursue"] },
			{ "type": "archer",    "slot": 2, "cards": ["engage", "pursue"] },
		],
		"방패 앞 + 궁수2 카이팅": [
			{ "type": "shieldman", "slot": 4, "cards": ["engage", "charge"] },
			{ "type": "archer",    "slot": 0, "cards": ["keep_distance", "engage"] },
			{ "type": "archer",    "slot": 2, "cards": ["keep_distance", "engage"] },
		],
		"전사 앞 + 궁수2 뒤": [
			{ "type": "warrior", "slot": 4, "cards": ["engage", "charge"] },
			{ "type": "archer",  "slot": 0, "cards": ["engage", "pursue"] },
			{ "type": "archer",  "slot": 2, "cards": ["engage", "pursue"] },
		],
		"암살자 + 궁수2": [
			{ "type": "assassin", "slot": 4, "cards": ["engage", "pursue"] },
			{ "type": "archer",   "slot": 0, "cards": ["engage", "pursue"] },
			{ "type": "archer",   "slot": 2, "cards": ["engage", "pursue"] },
		],
		"암살자 + 방패 + 악사": [
			{ "type": "shieldman", "slot": 4, "cards": ["guard_stance", "engage", "charge"] },
			{ "type": "assassin",  "slot": 3, "cards": ["engage", "pursue"] },
			{ "type": "bard",    "slot": 1, "cards": ["mend", "engage", "keep_distance"] },
		],
		"암살자2 + 악사": [
			{ "type": "assassin", "slot": 3, "cards": ["engage", "pursue"] },
			{ "type": "assassin", "slot": 5, "cards": ["engage", "pursue"] },
			{ "type": "bard",   "slot": 1, "cards": ["mend", "engage", "keep_distance"] },
		],
	}

	for stage_id in [1, 2]:
		var st := Stages.get_stage(stage_id)
		print("── 스테이지 %d: %s (%s)" % [stage_id, st["name"], st["strategy_text"]])
		for label in candidates:
			var b := Battle.new()
			b.setup(stage_id, candidates[label])
			b.run()
			print("   %-22s %-8s tick %2d   아군 %d / 적 %d" % [
				label, b.result, b.tick,
				b.living_count(Unit.TEAM_PLAYER), b.living_count(Unit.TEAM_ENEMY),
			])
		print("")

	diagnose_kiting()
	quit(0)


## 후퇴 카드가 실제로 물러날 공간이 있는지 확인한다.
func diagnose_kiting() -> void:
	print("── 카이팅 여유 진단")
	print("   아군 배치 열 x = %d, %d" % [Grid.PLAYER_SLOTS[0].x, Grid.PLAYER_SLOTS[3].x])
	print("   적  배치 열 x = %d, %d" % [Grid.ENEMY_SLOTS[3].x, Grid.ENEMY_SLOTS[0].x])
	print("   → 아군 뒤쪽 여유 칸: %d열" % Grid.PLAYER_SLOTS[0].x)

	var party := [{ "type": "archer", "slot": 3, "cards": ["keep_distance", "engage"] }]
	var b := Battle.new()
	b.setup(1, party)
	var path: Array[String] = []
	for _i in 12:
		if not b.step():
			break
		path.append("%d,%d" % [b.units[0].pos.x, b.units[0].pos.y])
	print("   궁수 단독 카이팅 경로: %s" % " → ".join(path))
