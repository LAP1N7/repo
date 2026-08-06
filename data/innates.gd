class_name Innates

## 직업별 기본 AI.
##
## ── 왜 규칙 목록이 아니라 표인가 ─────────────────────────────────────────
## 예전에는 기본기도 모듈과 똑같은 모양의 규칙이었고, 규칙 엔진이 슬롯을 전부
## 훑은 뒤 맨 아래에서 평가했다. 그 구조에서는 "모듈이 없으면 대원이 멍청해진다"
## 를 피할 수 없었다 - 기본기가 모듈보다 약해야 모듈을 사는데, 약한 기본기만
## 남으면 아무것도 제대로 못 한다.
##
## 이제 대원은 **모듈이 하나도 없어도 자기 직업의 일을 한다.** 전사는 붙어서
## 때리고, 궁수는 자리를 지키며 쏘고, 악사는 회복한다. 모듈은 그 판단을
## **수정**하는 물건이지, 없으면 안 되는 물건이 아니다.
##
## 플레이어가 설계하는 것은 이제 "무엇을 할까" 가 아니라 "누구를 · 언제 ·
## 어디서 · 누구와" 다. 그게 전술이다. (REFORM.md §1)
##
## ── 기본 AI 에 상한을 둔다 ───────────────────────────────────────────────
## 모듈 없이도 제 역할을 한다는 건 좋은 목표지만, 너무 잘하면 상점에 갈 이유가
## 사라진다. 경제 전체가 "모듈을 산다" 를 축으로 서 있으므로 기본 AI 가
## 유능해지면 그 축이 통째로 무너진다. 목표치는 이렇다.
##
##   모듈 0장으로 1단계 : 이긴다      (60% 이상)
##   모듈 0장으로 3단계 : 진다        (25% 이하)
##   모듈 0장으로 5단계 : 확실히 진다 (5% 이하)
##
## test/probe.gd 가 이걸 잰다. 기본 AI 를 건드릴 때마다 돌린다.

## 기본 판단.
##
##   act          사거리 안에 대상이 있을 때 하는 일. attack | heal
##   power        그 행동의 위력(%)
##   stand        대상이 사거리 밖일 때 어디로 갈 것인가
##                  advance - 대상에게 접근한다 (근접형)
##                  hold    - 움직이지 않는다   (원거리형)
##   flee_within  이 거리 안에 적이 들어오면 한 칸 물러난다. 0 이면 안 물러난다
##
## ── 왜 원거리는 안 움직이는가 ────────────────────────────────────────────
## 이 한 줄이 원거리와 근접의 성격을 기본기 단계에서 갈라 놓는다. 근접은 항상
## 붙으러 가고 원거리는 자리를 지킨다. 그래서 궁수를 앞으로 보내고 싶으면
## POSITION 모듈을 사야 하고, 그 순간 플레이어는 "이 대원을 어떻게 운용할지"
## 를 스스로 정한 것이 된다.
const BASE_AI: Dictionary = {
	# ── 근접 ─────────────────────────────────────────────────────────────
	"warrior":   { "act": "attack", "power": 100, "stand": "advance", "flee_within": 0 },
	"shieldman": { "act": "attack", "power": 100, "stand": "advance", "flee_within": 0 },
	# 암살자는 판단이 같고 **이동력**이 다르다. 그건 UnitData 의 move 가 들고 있다.
	"assassin":  { "act": "attack", "power": 100, "stand": "advance", "flee_within": 0 },
	# 총사는 사거리 2 짜리 근접형이다. 붙되 한 칸 앞에서 쏜다.
	"musketeer": { "act": "attack", "power": 100, "stand": "advance", "flee_within": 0 },

	# ── 원거리 ───────────────────────────────────────────────────────────
	"archer":    { "act": "attack", "power": 100, "stand": "hold", "flee_within": 1 },
	# 악사만 행동이 회복이다. 사거리 3 안의 가장 위독한 아군을 살린다.
	# 예전에는 이게 [구호] 라는 코스트 4짜리 모듈이었는데, 회복은 악사의 **직업**
	# 이지 전술이 아니다. 전술은 "누구를 먼저 살릴까" 쪽이다.
	"bard":      { "act": "heal", "power": 100, "stand": "hold", "flee_within": 1 },

	# ── 기계 개체 ────────────────────────────────────────────────────────────
	# 자동 포탑은 이동력이 0 이라 stand 가 뭐든 안 움직인다. 그래도 hold 를
	# 적어 둔다 - 표를 읽는 사람에게 "이건 안 움직이는 물건" 이 보여야 한다.
	"turret":    { "act": "attack", "power": 100, "stand": "hold", "flee_within": 0 },
	# 신호기는 공격력이 0 이라 위력을 얼마로 두든 피해가 1 로 깔린다.
	# power 를 0 으로 박아 "아무 일도 안 한다" 를 표에서도 못 박는다.
	# 신호기는 걸어온다. 공격력이 0 이라 붙어도 아무 일이 없지만, 안 움직이면
	# **아무와도 상호작용하지 않는 개체**가 되어 판이 정체로 끝난다.
	"beacon":    { "act": "attack", "power": 0, "stand": "advance", "flee_within": 0 },
	"bomber":    { "act": "attack", "power": 100, "stand": "advance", "flee_within": 0 },
	# 감독기는 뒤에 머문다. 붙으면 죽고, 죽으면 나머지가 약해진다.
	"overseer":  { "act": "attack", "power": 100, "stand": "hold", "flee_within": 2 },

	# 훈련용 표적. 아무것도 안 한다.
	"dummy":     { "act": "attack", "power": 0, "stand": "hold", "flee_within": 0 },
}


## 없는 직업이면 가장 무난한 근접형으로 둔다. 새 직업을 추가하다가 표에 넣는
## 걸 잊어도 그 대원이 얼어붙지는 않는다.
static func base_ai(unit_id: String) -> Dictionary:
	return BASE_AI.get(unit_id, {
		"act": "attack", "power": 100, "stand": "advance", "flee_within": 0,
	})


## 편성 화면에 보여 줄 기본 AI 한 줄.
static func describe(unit_id: String) -> String:
	var ai := base_ai(unit_id)
	var what := "회복" if String(ai["act"]) == "heal" else "공격"
	var where := "접근" if String(ai["stand"]) == "advance" else "제자리 유지"
	var flee := ""
	if int(ai["flee_within"]) > 0:
		flee = " · 적이 %d칸 이내면 후퇴" % int(ai["flee_within"])
	return "사거리 안 %s / 밖이면 %s%s" % [what, where, flee]
