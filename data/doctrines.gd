class_name Doctrines

## 교리 보너스.
##
## 한 축에 장착한 모듈이 **전부 같은 태그**면 그 축의 교리가 활성화된다.
##
## ── 왜 필요한가 ──────────────────────────────────────────────────────────
## 축만 나누면 플레이어는 항상 **안전한 조합**을 짠다. 표적을
## `후열 → 처형 → 근접` 처럼 성격이 다른 것으로 섞어 두면 어떤 상황에서도
## 하나는 걸리기 때문이다. 그게 나쁜 건 아니지만, 그 결과 모든 대원의 목록이
## 비슷해지고 "이 대원은 이런 성격" 이 사라진다.
##
## 교리 보너스는 "한쪽으로 몰면 강하지만 그 상황이 없으면 아무것도 못 한다" 는
## **대가 있는 선택**을 만든다. 전부 후방 태그로 채운 궁수는 적 후열이 있을 때
## 치명적이지만, 적이 전열 셋뿐인 판에서는 목록이 통째로 헛돈다.
##
## ── 두 가지 규칙을 반드시 지킨다 ─────────────────────────────────────────
## 1. **두 칸 이상**이어야 성립한다. 한 칸짜리로 보너스를 주면 "어차피 한 장이니
##    공짜" 가 되어 선택이 아니게 된다.
## 2. **다른 태그가 하나라도 섞이면 무효다.** 그 엄격함이 대가를 만든다.
##    섞어도 절반쯤 준다면 아무도 몰아 넣지 않는다.

const MIN_MODULES: int = 2

## 태그 -> 교리.
##
## effect 는 core/unit.gd 가 읽는 이름이다. 여기 없는 이름을 쓰면 조용히
## 아무 일도 안 일어나므로, 추가할 때는 unit.gd 의 doctrine_* 도 같이 본다.
const TABLE: Dictionary = {
	# ── TARGET ───────────────────────────────────────────────────────────
	"rear": {
		"axis": "target",
		"name": "후방 교리",
		"effect": "crit_pct",
		"value": 10,
		"text": "치명타 확률 +10%",
	},
	"execute": {
		"axis": "target",
		"name": "처형 교리",
		"effect": "kill_refund",
		"value": 1,
		"text": "적을 처치하면 그 틱에 한 번 더 행동",
	},

	# ── ENGAGE ───────────────────────────────────────────────────────────
	"patience": {
		"axis": "engage",
		"name": "인내 교리",
		"effect": "damage_taken_pct",
		"value": -15,
		"text": "받는 피해 -15%",
	},
	"charge": {
		"axis": "engage",
		"name": "맹진 교리",
		"effect": "attack_pct",
		"value": 15,
		"text": "공격력 +15%",
	},

	# ── POSITION ─────────────────────────────────────────────────────────
	"formation": {
		"axis": "position",
		"name": "진형 교리",
		"effect": "defend_per_ally",
		"value": 1,
		"text": "인접한 아군 1명당 방어 +1",
	},
	"skirmish": {
		"axis": "position",
		"name": "유격 교리",
		"effect": "moved_attack_pct",
		"value": 10,
		"text": "이동한 다음 틱의 공격 +10%",
	},

	# ── SQUAD ────────────────────────────────────────────────────────────
	"focus": {
		"axis": "squad",
		"name": "집중 교리",
		"effect": "same_target_pct",
		"value": 8,
		"text": "같은 표적을 노린 아군 1명당 +8%",
	},
	"spread": {
		"axis": "squad",
		"name": "분산 교리",
		"effect": "evade_pct",
		"value": 10,
		"text": "아군과 다른 적을 노릴 때 회피 +10%",
	},
}


## 장착 모듈 목록에서 활성 교리를 찾는다.
##
## modules 는 { axis: [모듈 규칙, ...] } 형태다. 축 하나가 통째로 같은 태그이고
## 두 개 이상일 때만 성립한다.
##
## 반환: { 태그: 교리 } - 축마다 최대 하나이므로 최대 넷.
static func active(by_axis: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for axis in by_axis:
		var mods: Array = by_axis[axis]
		if mods.size() < MIN_MODULES:
			continue
		var tag := String((mods[0] as Dictionary).get("tag", ""))
		if tag == "":
			continue
		var uniform := true
		for m in mods:
			if String((m as Dictionary).get("tag", "")) != tag:
				uniform = false
				break
		if not uniform or not TABLE.has(tag):
			continue
		out[tag] = TABLE[tag]
	return out


## 활성 교리에서 특정 효과의 합을 낸다. 없으면 0.
##
## 합이다. 같은 효과를 주는 교리가 둘 이상 켜지는 구성이 나올 수 있고,
## 그때 하나만 세면 플레이어가 짠 것과 화면에 뜬 것이 어긋난다.
static func amount(actives: Dictionary, effect: String) -> int:
	var n := 0
	for tag in actives:
		var d: Dictionary = actives[tag]
		if String(d.get("effect", "")) == effect:
			n += int(d.get("value", 0))
	return n
