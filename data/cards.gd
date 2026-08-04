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
	"engage": {
		"tier": 1,
		"cost": 2,
		"name": "교전",
		"cond": "always",
		"cond_arg": 0,
		"act": "attack",
		"target": "nearest_enemy",
		# 평타 100%. 기본 공격(70%)보다 확실히 세야 살 이유가 생긴다.
		"power": 100,
		"text": "항상 → 가장 가까운 적 공격 (위력 100%)",
	},
	"finisher": {
		"tier": 3,
		"cost": 4,
		"name": "마무리",
		"cond": "always",
		"cond_arg": 0,
		"act": "attack",
		"target": "lowest_hp_enemy",
		"text": "항상 → HP 가장 낮은 적 공격",
	},
	"snipe": {
		"tier": 2,
		"cost": 2,
		"name": "저격",
		"cond": "enemy_in_range",
		"cond_arg": 0,
		"act": "attack",
		"target": "farthest_enemy",
		"text": "적이 사거리 안 → 가장 먼 적 공격",
	},
	"charge": {
		"tier": 1,
		"cost": 2,
		"name": "돌격",
		"cond": "always",
		"cond_arg": 0,
		"act": "move_toward",
		"target": "nearest_enemy",
		# 기본 전진보다 한 칸 더 간다. 이게 없으면 `돌격 ≡ 추격 ≡ 기본 전진` 이 되어
		# 세 규칙이 완전히 같은 카드가 된다.
		"move_bonus": 1,
		"text": "항상 → 적에게 접근 (한 칸 더)",
	},
	"retreat": {
		"tier": 1,
		"cost": 1,   # 2→1 기여도 -6.5%p. 물러나는 틱은 못 쏘는 틱이라 구조적으로 손해다
		"name": "후퇴",
		"cond": "self_hp_below",
		"cond_arg": 50,
		"act": "move_away",
		"target": "nearest_enemy",
		"text": "내 HP < 50% → 적 반대로 1칸",
	},
	"resolve": {
		"tier": 1,
		"cost": 1,
		"name": "결사",
		"cond": "self_hp_below",
		"cond_arg": 25,
		"act": "attack",
		"target": "lowest_hp_enemy",
		"text": "내 HP < 25% → HP 가장 낮은 적 공격",
	},
	"keep_distance": {
		"tier": 2,
		"cost": 2,
		"name": "거리 유지",
		"cond": "enemy_within",
		"cond_arg": 2,
		"act": "move_away",
		"target": "nearest_enemy",
		# 이동 보너스를 한 번 줬다가 뺐다. 궁수가 틱당 2칸씩 물러나니 기동이 과했고,
		# 애초에 보너스를 준 이유(적이 돌격으로 2칸씩 좁힘)는 튜토리얼 스테이지에서
		# 돌격을 제거하면서 사라졌다. 카이팅은 "때릴 틱을 생존과 맞바꾸는" 거래여야지
		# 공짜 기동이 되면 안 된다.
		"text": "적이 2칸 이내 → 적 반대로 1칸",
	},
	"counter": {
		"tier": 2,
		"cost": 2,   # 3→2 기여도 -1.5%p. 발동률은 86% 로 높은데 값을 못 한다
		"name": "반격",
		"cond": "was_hit_last_tick",
		"cond_arg": 0,
		"act": "attack",
		"target": "last_attacker",
		"text": "직전 틱에 피격 → 때린 적 공격",
	},
	"guard_stance": {
		"tier": 2,
		"cost": 2,   # 3→2 발동률 편차가 3.7~75% 로 판을 심하게 탄다
		"name": "방어 태세",
		"cond": "enemies_adjacent_at_least",
		"cond_arg": 2,
		"act": "defend",
		"target": "self",
		"text": "주변 적 2명 이상 → 방어",
	},
	"mend": {
		"tier": 3,
		"cost": 4,
		"name": "구호",
		"cond": "ally_hp_below",
		"cond_arg": 50,
		"act": "heal",
		"target": "lowest_hp_ally",
		"text": "아군 HP < 50% → 가장 HP 낮은 아군 회복",
	},
	"hold_ground": {
		"tier": 1,
		"cost": 1,
		"name": "사수",
		"cond": "enemy_out_of_range",
		"cond_arg": 0,
		"act": "hold",
		"target": "self",
		"text": "적이 사거리 밖 → 제자리 유지",
	},
	# ── 조율 카드 ─────────────────────────────────────────────────────────
	# 여기부터 네 장은 다른 축에 있다. 위의 카드들이 전부 "**언제** 싸울까" 를
	# 바꾼다면, 이 넷은 "**누구를** 향할까" 를 바꾼다.
	#
	# 슬롯이 3칸뿐이라 카드의 값은 "기본기보다 얼마나 센가" 가 아니라 "이 한 장이
	# 빌드를 만드는가" 로 정해진다. 조건만 바꾸는 카드는 아무리 세도 그 유닛이
	# 하던 일을 조금 더 잘할 뿐이고, 대상을 바꾸는 카드는 그 유닛의 역할 자체를
	# 바꾼다. 실제로 개편 전 13장이 쓰는 대상은 `가장 가까운 적` 에 6장이 몰려
	# 있었고, **아군을 향해 움직이는 카드가 한 장도 없었다.**
	"escort": {
		"tier": 2,
		"cost": 2,
		"name": "호위",
		"cond": "other_ally_hp_below",
		"cond_arg": 60,
		"act": "move_to_ally",
		"target": "lowest_hp_other_ally",
		# 이 게임 최초로 **아군을 향해** 움직이는 카드다. 이 한 장이면 전사든
		# 방패병이든 "제일 앞에서 때리는 놈" 에서 "제일 약한 아군 옆에 붙는 놈" 이
		# 된다. 슬롯 하나를 공격에서 빼는 대신 진형이 생긴다.
		"text": "다른 아군 HP < 60% → 그 아군 곁으로 이동",
	},
	"crossfire": {
		"tier": 3,
		"cost": 3,
		"name": "협공",
		"cond": "ally_engaged",
		"cond_arg": 0,
		"act": "attack",
		"target": "focused_enemy",
		"power": 100,
		# 화력 분산이 이 게임에서 지는 가장 흔한 이유다. 셋이 각자 다른 적을 때리면
		# 아무도 안 죽고 적은 셋 다 살아서 반격한다. 이 카드는 "먼저 친 아군이
		# 대상을 정하고 나머지가 얹는다" 를 규칙으로 만든다.
		#
		# 슬롯 순서가 그대로 역할이 된다 - 협공을 1번에 두면 추종자, 아래 두면
		# 자기 판단이 먼저인 선봉이 된다.
		"text": "아군이 교전 중 → 그 적을 같이 공격",
	},
	"berserk": {
		"tier": 2,
		"cost": 2,   # 3→2 발동률 22%/4.6%. 터질 땐 세지만 기댓값이 3코에 못 미친다
		"name": "광전사",
		"cond": "team_killed_last_tick",
		"cond_arg": 0,
		"act": "attack",
		"target": "lowest_hp_enemy",
		"power": 140,
		# 처음엔 `처치 직후 → 다음 적에게 두 칸 접근` 이었는데 감사가 [돌격] 에게
		# 지배당한다고 잡았다. 맞는 지적이다 - 행동도 대상도 돌격과 같고 조건만
		# 빡빡한데 값은 더 비쌌다. 이동 보너스 1칸 차이로는 카드가 안 된다.
		#
		# 한 틱에 한 행동뿐인 엔진에서 "접근하거나 공격" 중 살릴 쪽은 공격이다.
		# 접근은 이미 돌격·추격·암살 세 장이 하고 있고, 처치 직후에만 켜지는
		# 강타는 어느 카드도 안 하기 때문이다. 죽이면 피 냄새를 맡고 제일 약한
		# 놈에게 달려드는, 굴러가기 시작하면 멈추지 않는 카드가 된다.
		#
		# 조건은 **팀 단위**다. 본인 처치로 잡았더니 1680회 전투에서 39번밖에
		# 안 터졌다(0.02회/전투) - 한 유닛이 직접 막타를 치는 일 자체가 드물다.
		# 팀 단위로 열면 "누가 하나 눕히면 전원이 달려든다" 가 되어, 협공과 함께
		# 화력 집중 빌드의 두 번째 장이 된다.
		"text": "직전 틱에 아군이 적 처치 → HP 가장 낮은 적 강타 (위력 140%)",
	},
	"assassinate": {
		"tier": 2,
		"cost": 2,   # 3→2 기여도 최하위권. 역할 카드라 값을 낮춰 시험 비용을 줄인다
		"name": "암살",
		"cond": "tick_below",
		"cond_arg": 6,
		"act": "move_toward",
		# farthest_enemy 가 아니라 backline_enemy 다. 맨해튼 거리로 고르면
		# 대각선에 있는 전열이 후열과 동점이 되어 앞줄로 간다. (rules.gd 주석)
		"target": "backline_enemy",
		"move_bonus": 1,
		# 전열을 지나쳐 후열로 간다. 그 사이 맞는 건 이 카드의 값이지 결함이 아니다.
		#
		# ── 조건이 `항상` 이면 안 된다 ────────────────────────────────────
		# 처음엔 `항상` 이었다. 가장 먼 적은 정의상 거의 사거리 밖이라
		# `move_toward` 가 매 틱 실행 가능했고, 발동률 98.4% 에 기여도 -7.4%p -
		# 이 카드를 꽂은 유닛이 전투 내내 걷기만 하고 한 번도 공격하지 않았다.
		# 역할 카드가 아니라 함정 카드였다.
		#
		# 개전 6틱으로 끊으면 "파고드는 국면" 과 "싸우는 국면" 이 나뉜다.
		# 그 안에 후열에 닿고, 그 뒤로는 아래 슬롯의 공격 카드가 이어받는다.
		# [암살] 1번 + [교전] 2번이 "후열까지 파고들고, 그 다음 친다" 는 한 문장이
		# 되고, 순서를 뒤집으면 그냥 앞의 적을 때리는 유닛이 된다.
		"text": "개전 6틱 안 → 가장 먼 적(후열)에게 파고든다 (한 칸 더)",
	},
	# ── 국면 카드 ─────────────────────────────────────────────────────────
	# 조율 카드가 "누구를 향할까" 를 바꿨다면, 이 둘은 "**언제부터 다르게 싸울까**"
	# 를 바꾼다. 전투에 국면이 생긴다.
	#
	# 어휘 분포를 세어 보고 넣었다. 조건 12종 중 시간 조건은 `개전 n틱 안` 하나뿐이라
	# **후반에 태세를 바꾸는 수단이 아예 없었고**, 아군의 죽음에 반응하는 조건은
	# 0개였다. 그 사이 타임아웃이 전체 결말의 16.7% 로 세 번째로 흔했다.
	"all_in": {
		"tier": 2,
		# 1코다. 20틱 전에는 아무 일도 안 하는 카드라 값이 싸야 슬롯을 걸 만하다.
		# (돌격 2코보다 싸야 감사의 지배 판정도 통과한다 - 돌격은 `항상` 이라
		#  더 자주 발동하므로, 같은 값이면 이 카드가 존재할 이유가 없다)
		"cost": 1,
		"name": "총력전",
		"cond": "tick_above",
		# 20 으로 잡았다가 발동률 2.3% 로 죽은 카드가 됐다. 평균 전투가 24.7틱이라
		# 20틱은 사실상 "끝나기 직전" 이었다. 12 면 중반부터 태세가 바뀐다.
		"cond_arg": 12,
		"act": "move_toward",
		"target": "nearest_enemy",
		"move_bonus": 1,
		# [거리 유지] 위에 [총력전] 을 두면 "초반엔 물러나며 쏘고, 20틱부터는
		# 붙는다" 가 된다. 카이팅 교착을 플레이어가 직접 끊는 유일한 수단이다.
		"text": "12틱 이후 → 적에게 접근 (한 칸 더)",
	},
	"revenge": {
		"tier": 2,
		"cost": 2,
		"name": "복수",
		# 처음엔 `직전 틱에 아군 사망` 이었는데 1680회 전투에서 39번(0.02회/전투)
		# 밖에 안 터졌다. 아군이 죽는 순간은 드물고, 죽고 나면 대개 곧 진다.
		# 조건을 `아군 HP 35% 미만` 으로 넓혀 **잃기 전에** 반응하게 한다.
		# 그래야 만회 카드가 아니라 위기 카드가 된다.
		"cond": "other_ally_hp_below",
		"cond_arg": 35,
		"act": "attack",
		"target": "lowest_hp_enemy",
		# [광전사](우리가 죽였을 때)의 거울이다. 유리할 때와 불리할 때가 같은
		# 규칙으로 돌아가면 전투에 국면이 없다.
		"power": 130,
		"text": "다른 아군 HP < 35% → HP 가장 낮은 적 강타 (위력 130%)",
	},
	"pursue": {
		"tier": 1,
		"cost": 1,
		"name": "추격",
		"cond": "enemy_out_of_range",
		"cond_arg": 0,
		"act": "move_toward",
		# 기본 전진은 "가장 가까운 적" 으로 간다. 추격은 "HP 가장 낮은 적" 을 쫓아가
		# 마무리한다. 대상이 달라야 기본기와 다른 카드가 된다.
		"target": "lowest_hp_enemy",
		"text": "적이 사거리 밖 → HP 가장 낮은 적을 쫓는다",
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
