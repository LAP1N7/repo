extends SceneTree

## 전투를 틱 단위로 읽을 수 있게 찍는다.
##
##   godot --headless --script res://test/trace.gd
##
## "왜 이 유닛이 이때 이걸 했는가" 를 눈으로 따라가기 위한 도구다.
##
## ── 반드시 실시간으로 찍어야 한다 ──────────────────────────────────────
## 처음엔 step() 이 끝난 뒤 events 배열을 훑어 출력했는데, 그러면 HP·좌표를
## "틱이 다 끝난 뒤" 상태로 읽게 되어 전부 틀린 값이 나온다. 실제로 전사 3명이
## 각각 18씩 때린 틱에서 HP 가 세 줄 모두 최종값으로 찍혔다.
## Battle 은 battle_event 시그널을 실시간으로 쏘므로 거기에 붙는다.

var b: Battle
var names: Dictionary = {}


func _init() -> void:
	print("=== 전투 트레이스 ===
")
	trace_case("후반형 — 암살자2 + 방패병 vs 스테이지 1",
		[{ "type": "assassin", "slot": 0, "cards": ["near_first", "finisher"] },
		 { "type": "assassin", "slot": 2, "cards": ["near_first", "finisher"] },
		 { "type": "shieldman", "slot": 4, "cards": ["guard_stance", "near_first"] }],
		1, 30)
	quit(0)


func trace_case(title: String, party: Array, stage_id: int, max_ticks: int) -> void:
	print("─".repeat(74))
	print(title)
	print("─".repeat(74))

	b = Battle.new()
	b.setup(stage_id, party)
	b.battle_event.connect(_on_event)

	names.clear()
	for u in b.units:
		names[u.index] = "%s%s#%d" % [
			"" if u.team == Unit.TEAM_PLAYER else "적 ", u.display_name, u.index]

	print("  시작 배치:")
	for u in b.units:
		print("    %-11s (%d,%d)  HP %-4d 사거리 %d  이동 %d" % [
			names[u.index], u.pos.x, u.pos.y, u.hp, u.atk_range, u.move_range])
	print("")

	for _i in max_ticks:
		if not b.step():
			print("  ▸ 종료: %s (%d틱)\n" % [b.result, b.tick])
			return
	print("  … (%d틱까지만 표시)\n" % max_ticks)


## 이벤트가 발생한 그 순간에 호출된다. 여기서 읽는 HP·좌표는 전부 정확하다.
func _on_event(e: Dictionary) -> void:
	match e["type"]:
		"tick_begin":
			print("  [틱 %d]" % e["tick"])

		"rule":
			var tag := "기본기"
			if bool(e.get("special", false)):
				tag = "특수"
			elif not bool(e.get("innate", false)):
				tag = "슬롯%d" % (int(e["slot"]) + 1)
			print("    %-11s │ %s (%s)" % [names[e["unit"]], e.get("rule_name", ""), tag])
			print("    %-11s │   조건·행동: %s" % ["", e["text"]])

		"attack":
			print("    %-11s │   → %s 에게 %d 피해   HP %d" % [
				"", names[e["target"]], e["damage"], e["target_hp"]])

		"move":
			# 이동 직후의 실제 거리. 적이 아직 움직이기 전이므로 이 값이 맞다.
			print("    %-11s │   → 이동 (%d,%d)→(%d,%d)   가장 가까운 적까지 %d칸" % [
				"", e["from"].x, e["from"].y, e["to"].x, e["to"].y,
				_nearest_dist(int(e["unit"]))])

		"heal":
			print("    %-11s │   → %s 회복 %d   HP %d" % [
				"", names[e["target"]], e["amount"], e["target_hp"]])

		"special":
			print("    %-11s │   → 특수 [%s] · %d명 타격" % [
				"", e["name"], (e["hits"] as Array).size()])

		"defend":
			print("    %-11s │   → 방어 태세" % "")

		"hold":
			print("    %-11s │   → 제자리" % "")

		"idle":
			print("    %-11s │ (어떤 규칙도 발동하지 않음)" % names[e["unit"]])

		"death":
			print("    %-11s │   ☠ %s 사망" % ["", names[e["unit"]]])


func _nearest_dist(index: int) -> int:
	var u: Unit = b.units[index]
	var best := 99
	for e in b.living_enemies_of(u):
		best = mini(best, Grid.manhattan(u.pos, e.pos))
	return best
