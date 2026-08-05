class_name Stages

## 스테이지 5개. 로그라이트 런은 1 → 5 를 차례로 넘어간다.
##
## 적 알고리즘은 시작 전 화면에 그대로 공개한다. 숨기면 시행착오 게임이 되고,
## 공개하면 추리 게임이 된다. (DESIGN 2.4)
##
## pos 는 Grid.ENEMY_SLOTS 안의 좌표여야 한다 (x 는 5 또는 6, y 는 1~3).
## cards 는 우선순위 순서다. 축이 다른 모듈은 서로 경쟁하지 않으므로 같은 축의
## 모듈만 위아래로 다툰다.
##
## ── 이 표가 이 게임에서 가장 중요하다 ────────────────────────────────────
## 모듈이 재미있는 게 아니라 **적이 모듈을 요구해야 한다.** 후열 우선 모듈이
## 있는데 게임 내내 후열이 없으면 그건 쓰레기 모듈이고, 매 판 후열이 있으면
## 후열 모듈만 쓰는 정답 게임이 된다.
##
## 그래서 각 판은 특정 교리를 **요구**할 뿐 아니라 다른 교리를 **명시적으로
## 무력화**해야 한다. 요구만 있고 무력화가 없으면 만능 조합 하나로 다 통과한다.
##
##   단계  적 구성                요구하는 답            무력화되는 교리
##   1     전사 2                 (없음 - 기본기로 이긴다)
##   2     사수 3 · 물러남        추격 / 강행군          인내 (대기하면 아무 일도 안 남)
##   3     방패 2 + 악사 1        후열 침투 / 지원 차단  근접 우선 (방패만 때리다 정체)
##   4     암살자 2 + 총사 1      엄호 / 방패 뒤         유격 (후열이 먼저 죽는다)
##   5     혼성 + 궁극기 2        하나로는 안 됨         단일 교리 전부
##
## 측정 기준은 REFORM.md §9-2 에 있다. 어떤 단일 교리도 전체 1위를 못 하고,
## 단계마다 1위 교리가 달라야 한다. 못 채우면 모듈이 아니라 이 표를 고친다.

const TABLE: Array[Dictionary] = [
	{
		"id": 1,
		"name": "돌진하는 벽",
		"strategy_text": "접근 → 교전",
		"hint": "붙으면 진다. 물러나면서 쏘게 만드십시오.",
		# 첫 판은 기본 AI 만으로 이겨야 한다. 모듈을 아직 한 장도 안 샀기 때문이다.
		# 적도 모듈이 없다 - 순수하게 편성과 자리만 겨룬다.
		"enemies": [
			{ "type": "warrior", "pos": Vector2i(5, 1), "cards": [] },
			{ "type": "warrior", "pos": Vector2i(5, 3), "cards": [] },
		],
	},
	{
		"id": 2,
		"name": "물러서는 사수들",
		"strategy_text": "거리 유지 → 사거리 대기",
		"hint": "적이 물러섭니다. 같이 기다리면 아무 일도 일어나지 않습니다.",
		# ── 인내 교리를 죽인다 ────────────────────────────────────────────
		# 셋 다 [거리 유지] + [사거리 대기] 다. 플레이어까지 대기하면 양쪽이
		# 서로를 바라보다 정체 패배(14틱 무피해)로 끝난다. 쫓아가야만 이긴다.
		#
		# 가운데 하나만 [끝까지 추격] 을 준다. 셋 다 물러나기만 하면 적이
		# 한 발도 못 쏘고 플레이어가 무피해로 이긴다 - 실제로 그랬다.
		"enemies": [
			{ "type": "archer", "pos": Vector2i(5, 1),
			  "cards": ["far_in_range", "keep_range", "hold_fire"] },
			{ "type": "archer", "pos": Vector2i(6, 2),
			  "cards": ["near_first", "run_down"] },
			{ "type": "musketeer", "pos": Vector2i(5, 3),
			  "cards": ["near_first", "keep_range", "hold_fire"] },
		],
	},
	{
		"id": 3,
		"name": "무너지지 않는 방벽",
		"strategy_text": "방어 태세 → 뒤에서 회복",
		"hint": "방패는 시간을 끌 뿐입니다. 화력을 뒤로 돌리십시오.",
		# ── 근접 우선을 죽인다 ────────────────────────────────────────────
		# 방패병 둘이 [방어 우선] 로 피해를 나누고, 뒤의 악사가 기본 AI 로 매 틱
		# 회복한다. 가장 가까운 적만 때리면 방패의 실효 HP 를 영영 못 깎아
		# 정체 패배한다. 후열(악사)을 끊어야만 판이 진행된다.
		"enemies": [
			{ "type": "shieldman", "pos": Vector2i(5, 1),
			  "cards": ["near_first", "guard_stance", "front_line"] },
			{ "type": "shieldman", "pos": Vector2i(5, 3),
			  "cards": ["near_first", "guard_stance", "front_line"] },
			{ "type": "bard", "pos": Vector2i(6, 2),
			  "cards": ["behind_guard"], "special": "cantabile" },
		],
	},
	{
		"id": 4,
		"name": "그림자 급습",
		"strategy_text": "후열로 파고들어 처형",
		"hint": "후열이 먼저 죽습니다. 붙여 놓거나 뒤에 세우십시오.",
		# ── 유격 교리를 죽인다 ────────────────────────────────────────────
		# 암살자 둘이 [후열 침투] + [강행군] 으로 곧장 뒤를 판다. 거리 유지나
		# 측면 기동으로 흩어 놓으면 각개격파당한다. 밀집·방패 뒤·엄호처럼
		# 진형을 유지하는 쪽이 답이다.
		"enemies": [
			{ "type": "assassin", "pos": Vector2i(5, 1),
			  "cards": ["backline", "forced_march", "berserk"],
			  "special": "shadow_rend" },
			{ "type": "assassin", "pos": Vector2i(5, 3),
			  "cards": ["backline", "forced_march"] },
			{ "type": "musketeer", "pos": Vector2i(6, 2),
			  "cards": ["execute", "front_line"] },
		],
	},
	{
		"id": 5,
		"name": "정예 혼성대",
		"strategy_text": "벽으로 막고 · 쏘고 · 살린다",
		"hint": "하나로는 안 뚫립니다. 셋이 각자 다른 일을 해야 합니다.",
		# ── 단일 교리를 전부 죽인다 ───────────────────────────────────────
		# 방패가 앞을 막고(근접 우선 무효), 궁수가 [협공] 으로 화력을 모으고
		# (분산 무효), 악사가 뒤에서 살린다(처형 무효 - 깎아 놓으면 회복된다).
		# 표적 교리 하나로는 어느 쪽도 못 뚫는다.
		"enemies": [
			{ "type": "shieldman", "pos": Vector2i(5, 2),
			  "cards": ["near_first", "guard_stance", "front_line"],
			  "special": "last_guard" },
			{ "type": "archer", "pos": Vector2i(6, 1),
			  "cards": ["execute", "coop_fire", "keep_range"],
			  "special": "focus_fire" },
			{ "type": "bard", "pos": Vector2i(6, 3),
			  "cards": ["behind_guard"], "special": "cantabile" },
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
		{ "type": "dummy", "pos": Vector2i(5, 2), "cards": ["front_line"] },
		{ "type": "dummy", "pos": Vector2i(6, 3), "cards": ["forced_march"] },
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
