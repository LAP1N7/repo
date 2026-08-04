class_name Stages

## 스테이지 5개. 로그라이트 런은 1 → 5 를 차례로 넘어간다.
##
## 적 전략은 시작 전 화면에 그대로 공개한다. 숨기면 시행착오 게임이 되고,
## 공개하면 추리 게임이 된다. (DESIGN 2.4)
##
## pos 는 Grid.ENEMY_SLOTS 안의 좌표여야 한다 (x 는 5 또는 6, y 는 1~3).
## cards 는 우선순위 순서이며 슬롯 수(유닛당 3장)를 넘기면 뒤가 잘린다.
## special 은 선택이며, 그 유닛의 직업 전용 스킬만 붙는다.
##
## ── 난이도 곡선 ────────────────────────────────────────────────────────
## 1  붙어서 때리는 벽    - 물러나며 쏘는 법을 배운다
## 2  물러서는 사수       - 쫓아가 끊는 법을 배운다
## 3  버티는 방벽 + 회복  - 화력 집중과 후열 처리를 배운다
## 4  급습하는 암살자     - 전열로 막고 반격하는 법을 배운다
## 5  종합               - 특수 스킬을 낀 혼성 편성

const TABLE: Array[Dictionary] = [
	{
		"id": 1,
		"name": "돌진하는 벽",
		"strategy_text": "접근 → 교전",
		"hint": "궁수가 붙잡히면 진다. 물러나면서 쏘게 만들어라.",
		# 튜토리얼이라 `돌격`(이동 +1)을 주지 않는다. 그걸 주면 적이 틱당 2칸을
		# 좁히는데 궁수는 1칸만 물러나므로 카이팅이 원리적으로 불가능해진다.
		# 접근은 공통 기본기(사거리 밖 → 접근, 1칸)가 알아서 한다.
		# ── 왜 셋이 아니라 둘인가 ─────────────────────────────────────────
		# 전사 셋은 HP 375 · 화력 54 로 전 스테이지 중 두 번째로 두껍다. 그런데
		# 이걸 만나는 플레이어는 강화 0, 카드 5장, 궁극기 없음이다.
		# 런 시뮬레이션 실측 승률이 **16.9%** 였다 - 3~4스테이지가 71~75% 인데
		# 첫 판이 제일 어려웠다. 난이도 곡선이 뒤집혀 있었다.
		#
		# 로그라이트 클리어율은 스테이지 승률의 **곱**이다. 첫 판에서 다섯 중 넷이
		# 떨어지면 뒤의 밸런스는 아무도 못 본다.
		"enemies": [
			{ "type": "warrior", "pos": Vector2i(5, 1), "cards": ["engage"] },
			{ "type": "warrior", "pos": Vector2i(5, 3), "cards": ["engage"] },
		],
	},
	{
		"id": 2,
		"name": "물러서는 사수들",
		"strategy_text": "거리 유지 → 저격 / 구호",
		"hint": "적이 물러선다. 같이 물러나면 아무 일도 안 일어난다 - 쫓아가 끊어라.",
		# ── 악사를 뺐다 ──────────────────────────────────────────────────
		# 사수 둘(HP 202)에 매 틱 20씩 회복하는 악사가 붙으니 실효 HP 가 폭증했다.
		# 게다가 사거리 3 짜리 사수를 총사(2)·암살자(1)로는 따라잡을 수가 없다.
		# 런 시뮬 승률 23.8% 로 1스테이지를 고치자마자 여기가 새 벽이 됐다.
		# 회복이 낀 지구전은 3스테이지(방벽 + 악사)의 몫이다. 여긴 카이팅만 가르친다.
		# ── 왜 하나만 카드 순서가 반대인가 ────────────────────────────────
		# 유닛 개편으로 궁수가 사거리 3·공 24 가 되면서 양쪽이 완전한 대칭이 됐다.
		# 그 상태에서 적 전원에게 [거리 유지] 를 1번에 주면 아무도 방아쇠를 안
		# 당기고 물러나기만 해서, 먼저 쏘는 플레이어가 6틱 무피해 완승을 한다.
		# 반대로 적을 넷으로 늘렸더니 이번엔 플레이어가 4틱에 전멸했다.
		#
		# 답은 수가 아니라 구성이었다. 가운데 하나만 [저격] 을 1번에 올려 두면
		# 물러나는 둘이 시간을 벌고 그 하나가 계속 쏜다 - 스테이지 이름 그대로
		# "물러서는 사수들" 이 되고, 플레이어는 쫓아가서 끊는 법을 배우게 된다.
		"enemies": [
			# 카이팅 사수에게 [총력전] 을 준다. 플레이어만 교착을 끊을 수단을 갖고
			# 적은 영원히 물러나기만 하면, 타임아웃이 플레이어 탓이 아닌데도
			# 플레이어가 카드 한 장을 거기에 써야 한다.
			{ "type": "archer", "pos": Vector2i(5, 1), "cards": ["keep_distance", "all_in", "snipe"] },
			# 둘 다 사거리 3 이면 총사(2)·암살자(1)·전사(1)로는 구조적으로 못 잡는다.
			# 궁수를 안 뽑은 편성은 이 판에서 아무것도 할 수 없고, 실측 승률이
			# 46% 에 머물렀다. 한 명을 사거리 2 짜리 총사로 바꿔 **붙어서 잡을
			# 표적**을 하나 준다. 스테이지 이름은 흐려지지만, 뒤로 물러나는 적을
			# 어떻게 붙잡을 것인가라는 과제는 그대로 남는다.
			{ "type": "musketeer", "pos": Vector2i(5, 3), "cards": ["engage", "finisher", "all_in"] },
		],
	},
	{
		"id": 3,
		"name": "무너지지 않는 방벽",
		"strategy_text": "방어 태세 → 교전 / 뒤에서 구호",
		"hint": "방패병은 시간을 끌 뿐이다. 화력을 뒤의 악사에게 돌려라.",
		"enemies": [
			{ "type": "shieldman", "pos": Vector2i(5, 1),
			  "cards": ["guard_stance", "engage", "charge"] },
			{ "type": "shieldman", "pos": Vector2i(5, 3),
			  "cards": ["guard_stance", "engage", "charge"] },
			{ "type": "bard", "pos": Vector2i(6, 2),
			  "cards": ["mend", "keep_distance", "engage"], "special": "cantabile" },
		],
	},
	{
		"id": 4,
		"name": "그림자 급습",
		"strategy_text": "후열로 파고들어 마무리",
		"hint": "후열이 먼저 죽는다. 전열로 막고 반격으로 갚아라.",
		"enemies": [
			{ "type": "assassin", "pos": Vector2i(5, 1),
			  "cards": ["pursue", "finisher", "engage"], "special": "shadow_rend" },
			{ "type": "assassin", "pos": Vector2i(5, 3),
			  "cards": ["pursue", "finisher", "engage"] },
			# 총사는 사거리 2 라 [거리 유지](2칸 이내 → 후퇴)를 꽂으면 쏠 수 있는
			# 거리 전부에서 물러나 한 발도 못 쏜다. 붙어서 갈기는 카드를 준다.
			{ "type": "musketeer", "pos": Vector2i(6, 2),
			  "cards": ["engage", "finisher", "charge"] },
		],
	},
	{
		"id": 5,
		"name": "정예 혼성대",
		"strategy_text": "벽으로 막고 · 쏘고 · 살린다",
		"hint": "정답 하나로는 안 뚫린다. 세 명이 각자 다른 일을 해야 한다.",
		"enemies": [
			{ "type": "shieldman", "pos": Vector2i(5, 2),
			  "cards": ["guard_stance", "engage", "charge"], "special": "last_guard" },
			{ "type": "archer", "pos": Vector2i(6, 1),
			  "cards": ["keep_distance", "finisher", "engage"], "special": "focus_fire" },
			{ "type": "bard", "pos": Vector2i(6, 3),
			  "cards": ["mend", "keep_distance", "engage"], "special": "cantabile" },
		],
	},
]


## 튜토리얼 전용 스테이지. TABLE 에 넣지 않는다 -
## 상점의 스테이지 선택기와 밸런싱 통계에 섞이면 안 되기 때문이다.
const TUTORIAL_ID: int = 0

const TUTORIAL: Dictionary = {
	"id": TUTORIAL_ID,
	"name": "훈련장",
	"strategy_text": "접근 → 교전",
	"hint": "표적이 다가온다. 물러나면서 쏘게 만들어라.",
	# ── 이 배치는 네 가지를 순서대로 보여주려고 짠 것이다 ──────────────────
	#
	# 튜토리얼 캐릭터는 궁수다. 총사가 아니다 - 총사는 사거리 2 라 `거리 유지`
	# 문턱(2칸)과 값이 같아서, 쏠 수 있는 거리 전부에서 물러난다. 그 카드로
	# 순서를 가르쳐야 하는 튜토리얼에서는 쓸 수가 없다.
	# 궁수는 사거리 3 이라 "3칸에서 쏘고 2칸이면 물러난다" 는 밴드가 생긴다.
	#
	# 표적 둘의 역할을 나눴다:
	#   앞표적 - [사수] 로 제자리를 지킨다. 사거리 밖이면 안 움직이므로
	#            궁수가 접근(기본기) → 사격(교전) 을 안전하게 보여줄 수 있다
	#   뒷표적 - [돌격] 으로 틱당 2칸씩 좁힌다. 이동이 같으면 궁수가 판을 빙빙
	#            돌기만 하고 영영 구석에 안 몰려서, 폴스루(물러날 곳이 없으면
	#            교전)를 못 보여준다
	#
	# 표적은 약하다. 배우는 게 목적이지 이기는 게 어려우면 안 된다.
	"enemies": [
		{ "type": "dummy", "pos": Vector2i(5, 2), "cards": ["hold_ground", "engage"] },
		{ "type": "dummy", "pos": Vector2i(6, 3), "cards": ["charge", "engage"] },
	],
}


static func get_stage(stage_id: int) -> Dictionary:
	if stage_id == TUTORIAL_ID:
		return TUTORIAL
	for s in TABLE:
		if int(s["id"]) == stage_id:
			return s
	push_error("Stages: 없는 스테이지 %d" % stage_id)
	return {}


static func count() -> int:
	return TABLE.size()


static func is_last(stage_id: int) -> bool:
	return int(TABLE[TABLE.size() - 1]["id"]) == stage_id


## 다음 스테이지 번호. 마지막이면 -1.
static func next_id(stage_id: int) -> int:
	var found := false
	for s in TABLE:
		if found:
			return int(s["id"])
		if int(s["id"]) == stage_id:
			found = true
	return -1
