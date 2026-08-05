class_name Cards

## 규칙 카드 18장. (조건 → 행동) 한 쌍이 카드 한 장이다. (DESIGN 2.3)
##
## cond / cond_arg / act / target 은 core/rules.gd 가 match 로 분기하는 어휘다.
## 여기에 없는 값을 쓰면 규칙 엔진이 push_error 를 낸다.
##
## name / text 는 사람이 읽는 문자열이고, text 는 전투 중 유닛 머리 위 라벨에
## 그대로 표시된다. (DESIGN 1-2) 문장이 그대로 카드 한 장으로 읽혀야 하므로
## 표현을 임의로 바꾸지 말 것.
##
## cost 는 상점에서 이 카드를 사는 값이다. 밸런싱 노브가 이 숫자 하나뿐이라
## 사기 카드가 나와도 값을 올리면 통제된다. 0 = 거의 무해한 유틸, 4 = 판을 뒤집는 카드.
##
## ── 코스트는 실측으로 조정한다 ─────────────────────────────────────────
## 감으로 매기면 반드시 틀린다. 몬테카를로의 **기여도**(그 카드를 넣은 빌드의
## 승률 − 전체 승률)를 보고 값을 맞춘다. 아래 다섯 장은 그렇게 내렸다.
##
##   구호 +8.3%p / 마무리 +7.3%p  → 4코 유지. 제값을 한다
##   교전 +3.3%p                → 2코 유지. 코스트 효율 1위지만 **의도된 것**이다.
##                                 모든 유닛의 기본 공격 수단이라 이게 비싸면
##                                 초반에 아무도 못 싸운다
##   반격 -1.5 / 광전사 -1.0 / 암살 -7.1 / 후퇴 -6.5  → 내렸다
##
## tier 는 **얼마나 자주 상점에 뜨는가** 다. 값이 아니라 빈도라서 cost 와는 다른 축이다.
##
##   1  기본 도구      항상 흔하다. 이게 깔려야 빌드의 바닥이 생긴다
##   2  조건부·역할     스테이지가 오를수록 늘어난다
##   3  고가치         초반엔 거의 안 뜨고 후반에 열린다
##
## 배정은 감이 아니라 몬테카를로 실측 기여도(채용 시 승률 − 전체 승률)를 따랐다.
##   구호 +8.3%p · 마무리 +7.3%p · 협공 +3.7%p  → 3티어
## 교전(+3.3%p)은 세지만 1티어로 뒀다. 모든 유닛의 기본 공격 수단이라 이게 안 뜨면
## 게임이 시작을 못 한다 - 세다고 희귀하게 만들면 재미가 아니라 고통이 된다.

const TABLE: Dictionary = {
	# ── TARGET · 표적 ────────────────────────────────────────
	"near_first": {
		"axis": "target",
		"tag": "none",
		"tier": 1,
		"cost": 1,
		"name": "근접 우선",
		"cond": "always",
		"cond_arg": 0,
		"pick": "nearest_enemy",
		"text": "가장 가까운 적을 노린다",
	},
	"backline": {
		"axis": "target",
		"tag": "rear",
		"tier": 2,
		"cost": 3,
		"name": "후열 침투",
		"cond": "always",
		"cond_arg": 0,
		"pick": "backline_enemy",
		"text": "가장 깊은 적을 노린다",
	},
	"snipe": {
		"axis": "target",
		"tag": "rear",
		"tier": 2,
		"cost": 3,
		"name": "저격",
		"cond": "always",
		"cond_arg": 0,
		"pick": "farthest_enemy",
		"text": "가장 먼 적을 노린다",
	},
	"cut_support": {
		"axis": "target",
		"tag": "rear",
		"tier": 3,
		"cost": 4,
		"name": "지원 차단",
		"cond": "always",
		"cond_arg": 0,
		"pick": "healer_enemy",
		"text": "회복하는 적을 먼저 노린다",
	},
	"execute": {
		"axis": "target",
		"tag": "execute",
		"tier": 2,
		"cost": 3,
		"name": "처형",
		"cond": "always",
		"cond_arg": 0,
		"pick": "lowest_hp_enemy",
		"text": "HP 비율이 가장 낮은 적을 노린다",
	},
	"ignore_guard": {
		"axis": "target",
		"tag": "execute",
		"tier": 2,
		"cost": 3,
		"name": "방패 무시",
		"cond": "always",
		"cond_arg": 0,
		"pick": "unguarded_enemy",
		"text": "방어 태세인 적을 건너뛴다",
	},
	"firepower": {
		"axis": "target",
		"tag": "execute",
		"tier": 3,
		"cost": 4,
		"name": "화력 우선",
		"cond": "always",
		"cond_arg": 0,
		"pick": "strongest_enemy",
		"text": "공격력이 가장 높은 적을 노린다",
	},

	# ── ENGAGE · 교전 ────────────────────────────────────────
	"hold_fire": {
		"axis": "engage",
		"tag": "patience",
		"tier": 1,
		"cost": 2,
		"name": "사거리 대기",
		"cond": "enemy_out_of_range",
		"cond_arg": 0,
		"stance": "wait",
		"text": "적이 사거리 밖 → 제자리를 지킨다",
	},
	"fall_back": {
		"axis": "engage",
		"tag": "patience",
		"tier": 1,
		"cost": 2,
		"name": "부상 회피",
		"cond": "self_hp_below",
		"cond_arg": 50,
		"stance": "avoid",
		"text": "자신 HP < 50% → 물러난다",
	},
	"delay_open": {
		"axis": "engage",
		"tag": "patience",
		"tier": 2,
		"cost": 3,
		"name": "개전 지연",
		"cond": "tick_below",
		"cond_arg": 4,
		"stance": "wait",
		"text": "4픸까지 → 진형을 갖추고 기다린다",
	},
	"pursue": {
		"axis": "engage",
		"tag": "charge",
		"tier": 2,
		"cost": 3,
		"name": "끝까지 추격",
		"cond": "enemy_out_of_range",
		"cond_arg": 0,
		"stance": "pursue",
		"text": "적이 사거리 밖 → 끝까지 쪽는다",
	},
	"berserk": {
		"axis": "engage",
		"tag": "charge",
		"tier": 2,
		"cost": 3,
		"name": "광전",
		"cond": "self_hp_below",
		"cond_arg": 40,
		"stance": "engage",
		"text": "자신 HP < 40% → 물러나지 않는다",
	},
	"guard_stance": {
		"axis": "engage",
		"tag": "none",
		"tier": 1,
		"cost": 2,
		"name": "방어 우선",
		"cond": "enemies_adjacent_at_least",
		"cond_arg": 2,
		"stance": "defend",
		"text": "인접한 적 2명 이상 → 방어한다",
	},
	"preempt": {
		"axis": "engage",
		"tag": "charge",
		"tier": 3,
		"cost": 5,
		"name": "선제 차단",
		"cond": "enemy_special_ready",
		"cond_arg": 0,
		"stance": "engage",
		"text": "적이 궁극기 직전 → 물러나지 않는다",
	},
	"finish_call": {
		"axis": "engage",
		"tag": "charge",
		"tier": 2,
		"cost": 3,
		"name": "마무리 신호",
		"cond": "target_hp_below",
		"cond_arg": 30,
		"stance": "engage",
		"text": "표적 HP < 30% → 물러나지 않는다",
	},

	# ── POSITION · 위치 ────────────────────────────────────
	"keep_range": {
		"axis": "position",
		"tag": "skirmish",
		"tier": 2,
		"cost": 3,
		"name": "거리 유지",
		"cond": "always",
		"cond_arg": 0,
		"stand": "keep_range",
		"text": "최대 사거리를 유지한다",
	},
	"flank": {
		"axis": "position",
		"tag": "skirmish",
		"tier": 2,
		"cost": 3,
		"name": "측면 기동",
		"cond": "always",
		"cond_arg": 0,
		"stand": "flank",
		"text": "가장자리로 우회한다",
	},
	"forced_march": {
		"axis": "position",
		"tag": "skirmish",
		"tier": 3,
		"cost": 4,
		"name": "강행군",
		"cond": "always",
		"cond_arg": 0,
		"stand": "march",
		"text": "이동 거리 +1",
	},
	"front_line": {
		"axis": "position",
		"tag": "formation",
		"tier": 1,
		"cost": 2,
		"name": "전열 유지",
		"cond": "always",
		"cond_arg": 0,
		"stand": "frontline",
		"text": "아군 중 가장 앞에 선다",
	},
	"behind_guard": {
		"axis": "position",
		"tag": "formation",
		"tier": 2,
		"cost": 3,
		"name": "방패 뒤",
		"cond": "always",
		"cond_arg": 0,
		"stand": "behind_guard",
		"text": "방패병·전사보다 뒤에 선다",
	},
	"cluster": {
		"axis": "position",
		"tag": "formation",
		"tier": 1,
		"cost": 2,
		"name": "밀집",
		"cond": "always",
		"cond_arg": 0,
		"stand": "cluster",
		"text": "아군과 1칸 이내를 유지한다",
	},

	# ── SQUAD · 협력 ──────────────────────────────────────────
	"solo": {
		"axis": "squad",
		"tag": "none",
		"tier": 1,
		"cost": 1,
		"name": "단독 행동",
		"cond": "always",
		"cond_arg": 0,
		"coop": "solo",
		"text": "아군을 참조하지 않는다",
	},
	"focus_fire": {
		"axis": "squad",
		"tag": "focus",
		"tier": 2,
		"cost": 4,
		"name": "협공",
		"cond": "ally_engaged",
		"cond_arg": 0,
		"coop": "focus",
		"text": "아군이 노리는 적을 같이 노린다",
	},
	"rally": {
		"axis": "squad",
		"tag": "focus",
		"tier": 2,
		"cost": 3,
		"name": "집결",
		"cond": "always",
		"cond_arg": 0,
		"coop": "rally",
		"text": "아군이 모일 때까지 기다린다",
	},
	"spread_out": {
		"axis": "squad",
		"tag": "spread",
		"tier": 2,
		"cost": 3,
		"name": "분산",
		"cond": "ally_engaged",
		"cond_arg": 0,
		"coop": "spread",
		"text": "아군이 노리지 않는 적을 노린다",
	},
	"escort": {
		"axis": "squad",
		"tag": "spread",
		"tier": 2,
		"cost": 3,
		"name": "엄호",
		"cond": "always",
		"cond_arg": 0,
		"coop": "escort",
		"text": "HP가 가장 낮은 아군 곁에 선다",
	},

}

const DECK_ORDER: Array[String] = [
	"engage",
	"finisher",
	"snipe",
	"charge",
	"retreat",
	"resolve",
	"keep_distance",
	"counter",
	"guard_stance",
	"mend",
	"hold_ground",
	"pursue",
	"all_in",
	"revenge",
	"escort",
	"crossfire",
	"berserk",
	"assassinate",
]

## 스테이지별 티어 등장 장수. 인덱스는 스테이지 1~5.
##
## 초반엔 기본 도구가 대부분이고, 뒤로 갈수록 고가치가 열린다.
## 이게 런의 파워 곡선이다 - 1스테이지에서 마무리·구호가 쏟아지면 뒤에 남는 게 없다.
const TIER_COPIES: Dictionary = {
	1: [6, 6, 5, 5, 4],
	2: [3, 4, 5, 5, 5],
	3: [1, 1, 2, 3, 4],
}


# ── 합성 ─────────────────────────────────────────────────────────────────

## 카드는 3단계까지 오른다.
const MAX_LEVEL: int = 3

## 한 단계 올리는 데 필요한 같은 카드 장수. 그중 (이 값 - 1)장이 소모되고
## 한 장은 남는다. 전부 소모하면 "합성했더니 쓸 카드가 없다" 가 된다.
##
## ── 왜 2장인가 (3장이 아니라) ───────────────────────────────────────────
## 런 시뮬레이션으로 둘 다 돌렸다.
##   2장 - 런당 4.6회 합성. 너무 흔해서 "선택" 이 아니라 루틴이 된다
##   3장 - 런당 0.9회 합성. 너무 드물어서 빌드의 축이 못 된다
## 그런데 2장이 흔했던 진짜 이유는 장수가 아니라 **합성이 공짜였다는 것**이다.
## 2장만 모이면 무조건 하는 게 이득이니 저울질할 게 없었다.
## 장수는 2로 두고 예산을 받는다. 그러면 "한 장 더 사기 vs 있는 걸 키우기" 가
## 매 상점마다 새로 생긴다.
const MERGE_COPIES: int = 2

## 합성에 드는 예산. 올릴 단계가 높을수록 비싸다.
##   1 -> 2단계 : MERGE_COST
##   2 -> 3단계 : MERGE_COST * 2
## 3단계까지 가면 카드 3장 + 예산 9 다. 진짜 투자여야 한다.
const MERGE_COST: int = 3


## card_id 를 지금 단계에서 한 칸 올리는 데 드는 예산.
static func merge_cost(level: int) -> int:
	return MERGE_COST * maxi(1, level)

## ── 왜 합성이 필요한가 ──────────────────────────────────────────────────
## 중복 카드는 지금까지 **쓰레기였다.** 같은 유닛의 아래 슬롯에 같은 카드를 꽂으면
## 위에 가려서 영영 안 터지고, 다른 유닛에 나눠 꽂는 것 외에는 쓸 데가 없다.
## 그런데 실측상 손패는 5스테이지에 26장까지 쌓인다 - 카드 종류가 24종이니
## 상당수가 죽은 중복이다.
##
## 합성은 그 죽은 중복을 **깊이**로 바꾼다. 넓게 모으는 대신 하나를 갈고닦는
## 선택지가 생기고, 손패도 저절로 줄어든다. "덱을 완성한다" 는 감각이 여기서 나온다.
##
## ── 왜 레벨이 카드 종류 단위인가 ────────────────────────────────────────
## 장(張) 단위로 레벨을 붙이면 손패가 (id, level) 쌍의 목록이 되어 상점·편성·전투가
## 전부 바뀐다. 종류 단위면 `{교전: 2}` 사전 하나로 끝나고, "이 런에서 교전을
## 2단계까지 갈고닦았다" 는 문장이 오히려 더 읽힌다.

## 레벨이 무엇을 올리는가. 행동 계열마다 다르다.
##   공격  위력 +20%p
##   이동  한 칸 더
##   회복  회복량 +8
##   방어  피해 감소가 더 세짐
## `사수`(제자리 유지)만 올릴 수치가 없어 합성 대상이 아니다.
const LEVEL_POWER: int = 20
const LEVEL_MOVE: int = 1
const LEVEL_HEAL: int = 8


static func can_merge(card_id: String) -> bool:
	if not TABLE.has(card_id):
		return false
	return String(TABLE[card_id]["act"]) != "hold"


## 레벨이 반영된 규칙. 전투와 화면이 반드시 이걸 봐야 한다.
static func leveled(card_id: String, level: int) -> Dictionary:
	var base: Dictionary = TABLE[card_id]
	if level <= 1 or not can_merge(card_id):
		return base

	var up: int = level - 1
	var c := base.duplicate()
	c["name"] = "%s%s" % [base["name"], "+".repeat(up)]
	match String(base["act"]):
		"attack":
			c["power"] = int(base.get("power", 100)) + LEVEL_POWER * up
			c["text"] = "%s  (위력 %d%%)" % [_strip_power(base["text"]), c["power"]]
		"move_toward", "move_away", "move_to_ally":
			c["move_bonus"] = int(base.get("move_bonus", 0)) + LEVEL_MOVE * up
			c["text"] = "%s  (%d칸 더)" % [base["text"], c["move_bonus"]]
		"heal":
			c["heal_bonus"] = LEVEL_HEAL * up
			c["text"] = "%s  (회복 +%d)" % [base["text"], c["heal_bonus"]]
		"defend":
			c["defend_bonus"] = up
			c["text"] = "%s  (경감 강화 %d단계)" % [base["text"], up]
	return c


## 카드 문장 끝의 "(위력 nn%)" 를 떼어낸다. 레벨을 올릴 때마다 붙어서 늘어나는 걸 막는다.
static func _strip_power(text: String) -> String:
	# 카드 원문은 공백 하나('… 공격 (위력 100%)')를 쓰고 합성문은 둘을 쓴다.
	# 하나짜리로 찾아야 둘 다 걸린다. 실제로 두 칸으로 찾다가 표기가 겹쳐 나왔다.
	var at := text.find(" (위력")
	return text.substr(0, at) if at > 0 else text


static func get_card(card_id: String) -> Dictionary:
	return TABLE[card_id]


## 이 카드가 그 스테이지 뽑기 주머니에 들어가는 장수.
static func copies(card_id: String, stage: int) -> int:
	var t: int = int(TABLE[card_id].get("tier", 1))
	var i: int = clampi(stage, 1, 5) - 1
	return int((TIER_COPIES[t] as Array)[i])
