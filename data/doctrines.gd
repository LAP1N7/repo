class_name Doctrines

## 교리 — 축을 가로지르는 조합에 붙는 이름.
##
## ── 왜 축 안의 태그가 아니라 조합인가 ────────────────────────────────────
## 처음에는 "같은 축에 같은 태그 두 장" 을 교리로 봤다. 그건 잘 돌아가긴 했지만
## 플레이어 머릿속에 **부대의 그림이 안 떠올랐다.** [후방 교리] 는 "표적을
## 뒤쪽으로 몰았다" 이상을 말해 주지 않는다.
##
## 실제로 원하는 건 이거다.
##
##     후열 침투 + 강행군 + 단독 행동  →  "아, 이건 암살조구나"
##     방패 뒤   + 협공   + 밀집       →  "아, 이건 방진이구나"
##
## 축 하나만 봐서는 절대 이런 그림이 안 나온다. **어디를 노리고(표적), 어디에
## 서고(위치), 누구와 움직이는지(협력)** 가 같이 있어야 부대의 성격이 된다.
## 그래서 교리는 축을 가로지르는 조합에 붙는다.
##
## 이러면 교리 이름 자체가 **플레이어가 짠 전술의 요약**이 된다. 모듈을 모으는
## 게임이 아니라 교리를 완성하는 게임이 된다.
##
## ── 왜 두 장인가 (세 장이 아니라) ────────────────────────────────────────
## 대원 슬롯은 셋뿐이다(RunState.SLOTS_PER_UNIT). 교리를 세 장으로 잡으면 슬롯
## 셋을 정확히 그 조합으로 채워야 하는데, 상점이 무작위라 그 셋이 다 나올
## 확률이 너무 낮다. 실측 전에도 명백하다 - 26종 중 특정 3종이다.
##
## ── 왜 두 장이 서로 다른 축이어야 하는가 ────────────────────────────────
## 같은 축 모듈 둘을 핵심으로 잡으면 위아래로 겹쳐서 **아래 것이 절대 발동하지
## 않는다.** 교리는 켜지는데 그 절반이 죽은 칸인 셈이라, 플레이어는 조합을
## 맞췄는데 대원이 안 바뀌는 경험을 한다. 실제로 방진·저지·매복 셋이 그렇게
## 짜여 있었고 test/audit.gd 가 잡아냈다.
##
## 축이 다르면 이 문제가 원천적으로 없고, 동시에 "어디를 노리고 어디에 서는가"
## 라는 그림도 자동으로 만들어진다.
##
## 두 장이면 **정체성은 둘이 만들고 남은 한 칸은 자유**가 된다. 같은 암살
## 교리라도 세 번째 칸에 무엇을 넣느냐로 대원이 갈린다. 완성의 만족과 조정의
## 여지를 둘 다 남기는 지점이 여기였다.
##
## ── 왜 조합마다 대가가 있는가 ────────────────────────────────────────────
## 교리 조합은 대부분 **한쪽으로 치우친 선택**이다. 암살 교리는 뒤로 파고드니
## 앞이 비고, 방진 교리는 뭉치니 광역에 약하다. 보너스는 그 치우침을 감수한
## 값이지 공짜가 아니다. 그래서 보너스도 그 성격을 밀어 주는 쪽으로만 준다 -
## 암살 교리에 방어를 주면 치우침이 사라진다.

## 교리 하나를 켜는 데 필요한 모듈 수.
const CORE_SIZE: int = 2

## 이름 붙은 교리들.
##
## core 는 반드시 함께 장착해야 하는 모듈 id 다. 순서는 상관없다.
## effect 는 core/unit.gd 가 읽는 이름이다. 없는 이름을 쓰면 조용히 아무 일도
## 안 일어나므로, 추가할 때는 unit.gd 쪽도 같이 본다.
const TABLE: Dictionary = {
	# 뒤를 찢고 들어간다. 혼자 깊이 들어가므로 앞이 빈다.
	"assassin": {
		"name": "암살 교리",
		"core": ["backline", "forced_march"],
		"effect": "crit_pct",
		"value": 15,
		"text": "치명타 확률 +15%",
		"flavor": "후열을 끊는 것이 전투를 끝내는 가장 빠른 길이다.",
	},
	# 방패 뒤에서 화력을 모은다. 한 자리에 모이므로 흩어지면 무너진다.
	"phalanx": {
		"name": "방진 교리",
		"core": ["behind_guard", "coop_fire"],
		"effect": "defend_per_ally",
		"value": 2,
		"text": "인접한 아군 1명당 방어 +2",
		"flavor": "대열을 지키는 동안 누구도 혼자 죽지 않는다.",
	},
	# 흩어져 갉는다. 개별 화력이 낮으므로 오래 버텨야 한다.
	"skirmish": {
		"name": "유격 교리",
		"core": ["keep_range", "spread_out"],
		"effect": "evade_pct",
		"value": 15,
		"text": "회피 +15%",
		"flavor": "닿지 않는 거리에서 계속 깎는다.",
	},
	# 한 놈씩 확실히 끊는다. 표적이 바뀌면 이점이 사라진다.
	"annihilate": {
		"name": "섬멸 교리",
		"core": ["execute", "coop_fire"],
		"effect": "same_target_pct",
		"value": 12,
		"text": "같은 표적을 노린 아군 1명당 +12%",
		"flavor": "반쯤 죽인 적 둘보다 확실히 죽인 적 하나가 낫다.",
	},
	# 측면으로 돌아 적의 회복원을 끊는다. 우회하는 동안 정면이 비어 있다.
	"interdict": {
		"name": "저지 교리",
		"core": ["cut_support", "flank"],
		"effect": "attack_pct",
		"value": 12,
		"text": "공격력 +12%",
		"flavor": "살리는 자를 먼저 지운다.",
	},
	# 정면으로 밀고 들어간다. 가장 단순하고 가장 먼저 맞는다.
	"breakthrough": {
		"name": "돌파 교리",
		"core": ["front_line", "pursue"],
		"effect": "damage_taken_pct",
		"value": -18,
		"text": "받는 피해 -18%",
		"flavor": "먼저 닿는 자가 판을 연다.",
	},
	# 아군을 지키며 움직인다. 자기 화력을 포기한 대가다.
	"escort": {
		"name": "호위 교리",
		"core": ["escort", "guard_stance"],
		"effect": "defend_per_ally",
		"value": 3,
		"text": "인접한 아군 1명당 방어 +3",
		"flavor": "지켜야 할 것이 있는 쪽이 더 오래 선다.",
	},
	# 진형을 갖추고 기다렸다 친다. 먼저 움직이지 않으므로 정체에 약하다.
	"ambush": {
		"name": "매복 교리",
		"core": ["delay_open", "cluster"],
		"effect": "moved_attack_pct",
		"value": 20,
		"text": "이동한 다음 틱의 공격 +20%",
		"flavor": "진형을 갖추고 기다린 쪽이 먼저 친다.",
	},
}


## 장착 모듈 id 목록에서 활성 교리를 찾는다.
##
## 반환: { 교리키: 교리 }. 슬롯이 셋이므로 보통 하나, 많아야 둘이다.
static func active_ids(ids: Array) -> Dictionary:
	var have: Dictionary = {}
	for cid in ids:
		have[String(cid)] = true

	var out: Dictionary = {}
	for key in TABLE:
		var d: Dictionary = TABLE[key]
		var all := true
		for need in d["core"]:
			if not have.has(String(need)):
				all = false
				break
		if all:
			out[key] = d
	return out


## 장착 규칙 목록(카드 사전 배열)에서 활성 교리를 찾는다.
##
## Unit 은 id 가 아니라 규칙 사전을 들고 다니므로 이쪽이 실제로 쓰인다.
static func active(rules: Array) -> Dictionary:
	var ids: Array = []
	for r in rules:
		var cid := String((r as Dictionary).get("id", ""))
		if cid != "":
			ids.append(cid)
	return active_ids(ids)


## 활성 교리에서 특정 효과의 합을 낸다. 없으면 0.
##
## 합이다. 교리가 둘 켜지는 구성이 나올 수 있고, 그때 하나만 세면 플레이어가
## 짠 것과 화면에 뜬 것이 어긋난다.
static func amount(actives: Dictionary, effect: String) -> int:
	var n := 0
	for key in actives:
		var d: Dictionary = actives[key]
		if String(d.get("effect", "")) == effect:
			n += int(d.get("value", 0))
	return n


## 아직 완성 못 한 교리 중 **한 장만 더** 채우면 되는 것들.
##
## 상점에서 "이 모듈을 사면 암살 교리가 완성됩니다" 를 띄우기 위한 것이다.
## 교리를 완성하는 게임이라면 완성까지 얼마 남았는지가 보여야 한다.
static func near_complete(ids: Array) -> Array:
	var have: Dictionary = {}
	for cid in ids:
		have[String(cid)] = true

	var out: Array = []
	for key in TABLE:
		var d: Dictionary = TABLE[key]
		var missing: Array = []
		for need in d["core"]:
			if not have.has(String(need)):
				missing.append(String(need))
		if missing.size() == 1:
			out.append({ "key": key, "doctrine": d, "need": missing[0] })
	return out
