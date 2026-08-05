extends SceneTree

## 편성 저울 - 특정 조합이 사기인지 재는 도구.
##
## runsim 은 런 전체(상점·보상·강화 포함)를 보므로 "이 조합이 세다" 는 체감을
## 확인하기엔 변수가 너무 많다. 여기서는 그 변수를 전부 고정하고 **편성만** 바꿔
## 단계별 승률을 낸다. 슬롯 배치 4가지를 돌려 자리 운을 지운다.
##
## 조건을 바꿔 가며 재는 것이 요령이다. 강화·모듈을 채워 넣으면 후반 조건이,
## 0으로 두면 초반 조건이 된다 - 사기 조합은 대개 한쪽에서만 사기다.
## (악사 2명 조합은 풀강에서 90%, 강화 0에서 55% 였다. 문제는 1~2단계의
##  100%/100% 였고, 원인은 무료 기본기 레가토가 유료 모듈 구호와 회복량이
##  같았던 것이다. data/innates.gd 참조.)

const SLOTS := [[0, 2, 4], [1, 3, 5], [0, 3, 4], [1, 2, 5]]
const CARDS: Array = []

const BUILDS := {
	"딜1 + 악사2": ["archer", "bard", "bard"],
	"딜2 + 악사1": ["archer", "archer", "bard"],
	"딜3":         ["archer", "archer", "archer"],
	"딜1 탱1 악사1": ["archer", "shieldman", "bard"],
	"총사1 + 악사2": ["musketeer", "bard", "bard"],
	"전사1 + 악사2": ["warrior", "bard", "bard"],
}

func _init() -> void:
	print("  편성             1단계  2단계  3단계  4단계  5단계   평균")
	print("  " + "-".repeat(62))
	for name in BUILDS:
		var line := "  %-16s" % name
		var sum := 0.0
		for sid in [1, 2, 3, 4, 5]:
			var r := _rate(BUILDS[name], sid)
			sum += r
			line += " %4.0f%% " % (r * 100.0)
		print(line + "  %4.0f%%" % (sum / 5.0 * 100.0))
	quit(0)

func _rate(types: Array, sid: int) -> float:
	var wins := 0
	for combo in SLOTS:
		var party: Array = []
		for i in types.size():
			party.append({
				"type": types[i], "slot": combo[i], "cards": CARDS,
				"special": "", "upgrade": 0,
			})
		var b := Battle.new()
		b.setup(sid, party)
		b.run()
		if b.is_won():
			wins += 1
	return float(wins) / float(SLOTS.size())
