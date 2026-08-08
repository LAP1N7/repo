extends SceneTree

## 스테이지 난이도 측정기.
##
##   godot --headless --script res://test/stagelab.gd
##
## ── 왜 runsim 으로는 부족한가 ────────────────────────────────────────────
## runsim 은 상점 정책까지 포함한 런 전체를 돌린다. 그래서 앞 스테이지에서
## 대부분 죽으면 뒤 스테이지 표본이 한 자릿수로 줄어 아무것도 못 잰다. 실제로
## 5단계 표본이 9런까지 떨어졌다.
##
## 여기서는 **모든 스테이지를 같은 조건으로** 잰다. 편성 4종 x 모듈 조합 12종을
## 고정 강화 단계로 돌려, 스테이지 하나가 얼마나 많은 빌드를 통과시키는지 본다.
##
## 지는 방식도 같이 센다. 전멸 패배와 정체 패배는 고칠 것이 완전히 다르다.
##   전멸 - 적이 너무 세다. 수치를 내린다.
##   정체 - 아무도 안 다가온다. **구성을 고쳐야 한다.** 수치로는 절대 안 낫는다.

const COMPS: Dictionary = {
	"총사2전사": [["musketeer", 0], ["musketeer", 2], ["warrior", 4]],
	"궁전악": [["archer", 0], ["warrior", 2], ["bard", 4]],
	"암방악": [["assassin", 0], ["shieldman", 2], ["bard", 4]],
	"딜3": [["archer", 0], ["musketeer", 2], ["assassin", 4]],
}

## ── 4판부터는 네 명이다 ─────────────────────────────────────────────────
## 편성 표는 셋짜리인데 실제 게임은 4판부터 넷을 세운다. 셋으로 재면 4·5판을
## 있지도 않은 난이도로 재게 된다 - 실제로 4판이 1% 로 찍혔다.
## 편성마다 네 번째 자리를 하나씩 정해 둔다.
const FOURTH: Dictionary = {
	"총사2전사": ["shieldman", 1],
	"궁전악": ["shieldman", 1],
	"암방악": ["musketeer", 3],
	"딜3": ["shieldman", 1],
}

## 플레이어가 실제로 짤 법한 알고리즘들. 축을 골고루 섞는다.
const KITS: Array = [
	[],
	["near_first"],
	["execute"],
	["backline"],
	["near_first", "front_line"],
	["execute", "front_line"],
	["backline", "forced_march"],
	["far_in_range", "keep_range"],
	["near_first", "behind_guard"],
	["execute", "cluster"],
	["near_first", "front_line", "battle_stance"],
	["cut_support", "forced_march", "guard_stance"],
	# 실수하는 빌드도 하나 넣는다. 원거리만으로 기다리면 어떻게 되는지가
	# 표에 안 보이면, 그 함정이 얼마나 깊은지 알 수 없다.
	["near_first", "hold_fire"],
]


func _init() -> void:
	print("=== 스테이지 난이도 (편성 %d x 모듈 %d x 강화 1/3/5) ===\n"
		% [COMPS.size(), KITS.size()])
	print("  단계   승률   전멸패  정체패  시간초과   평균틱")
	print("  ---------------------------------------------------")
	for stage in [1, 2, 3, 4, 5]:
		var win := 0
		var wipe := 0
		var stall := 0
		var slow := 0
		var ticks := 0
		var n := 0
		for cn in COMPS:
			for kit in KITS:
				# 강화 1/3/5 로 훑는다. 0~2 로 재면 후반 스테이지를 실제보다
				# 훨씬 어렵게 본다 - 4단계에 도달한 편성이 무강화일 리가 없다.
				for up in [1, 3, 5]:
					var comp: Array = (COMPS[cn] as Array).duplicate()
					if stage >= RunState.PARTY_LATE_FROM_STAGE:
						comp.append(FOURTH[cn])
					var b := _play(stage, comp, kit, up)
					n += 1
					ticks += b.tick
					match _how(b):
						"승": win += 1
						"전멸": wipe += 1
						"정체": stall += 1
						_: slow += 1
		print("  %4d  %4d%%  %5d%%  %5d%%  %6d%%  %7.1f" % [
			stage, win * 100 / n, wipe * 100 / n, stall * 100 / n,
			slow * 100 / n, float(ticks) / float(n)])
	quit(0)


func _play(stage: int, comp: Array, kit: Array, upgrade: int) -> Battle:
	var party: Array = []
	for c in comp:
		party.append({ "type": c[0], "slot": c[1], "cards": kit,
			"special": "", "upgrade": upgrade })
	var b := Battle.new()
	b.record_events = false
	b.setup(stage, party)
	b.run()
	return b


## 어떻게 끝났는가. 아군이 남았는데 졌으면 정체다.
func _how(b: Battle) -> String:
	if b.result == Battle.RESULT_VICTORY:
		return "승"
	if b.result == Battle.RESULT_TIMEOUT:
		return "시간"
	return "정체" if b.living_count(Unit.TEAM_PLAYER) > 0 else "전멸"
