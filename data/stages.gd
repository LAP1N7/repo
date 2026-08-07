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
		#
		# 2페이즈에서 자폭 개체를 처음 보여 준다. 붙어서 잡으면 폭발을 그대로
		# 맞는다 - "죽이는 것" 과 "어디서 죽이는 것" 이 다르다는 걸 여기서 배운다.
		# 아직 아프지는 않다. 배우는 판이지 벌주는 판이 아니다.
		"waves": [
			# ── 기조: 닥돌 ───────────────────────────────────────────────
			# 자폭체가 **먼저** 온다. 첫 판부터 피를 깎고 시작하게 만드는 것이
			# 목적이다 - 페이즈 사이에 HP 가 안 돌아오므로(core/battle.gd),
			# 1페이즈를 얼마나 아꼈는지가 2페이즈에 그대로 남는다.
			#
			# 그 한 줄이 이 게임의 첫 교훈이다. "이겼다" 가 아니라 "얼마나
			# 아끼고 이겼다" 를 처음부터 묻는다.
			[
				{ "type": "bomber", "pos": Vector2i(5, 1), "cards": [],
				  "traits": ["volatile"] },
				{ "type": "bomber", "pos": Vector2i(5, 3), "cards": [],
				  "traits": ["volatile"] },
			],
			[
				{ "type": "stalker", "pos": Vector2i(5, 2),
				  "cards": ["frail_hunt", "forced_march"], "traits": ["volatile"] },
				{ "type": "warrior", "pos": Vector2i(6, 1), "cards": [] },
				{ "type": "warrior", "pos": Vector2i(6, 3), "cards": [] },
			],
		],
	},
	{
		"id": 2,
		"name": "물러서는 포대",
		"strategy_text": "거리 유지 → 사거리 대기",
		"hint": "포탑은 쫓아오지 않습니다. 물러나기만 하면 영영 못 부숩니다.",
		# ── 인내 교리를 죽인다 ────────────────────────────────────────────
		# 사수들은 [거리 유지] + [사거리 대기] 라 플레이어까지 기다리면 양쪽이
		# 서로를 바라보다 정체 패배로 끝난다.
		#
		# 자동 포탑이 그 압박을 한 단계 올린다. 사거리 3 에 이동 0 이라
		# **거리를 두는 쪽이 손해**다. 물러나면 영영 못 부수고, 붙으러 가는
		# 동안 계속 맞는다. 카이팅 하나로 버티던 편성이 여기서 처음 막힌다.
		# ── 새 개체는 한 페이즈에 하나씩 ─────────────────────────────────
		# 1페이즈는 예전 그대로 순수한 카이팅 판이다. 여기에 포탑까지 세우면
		# 새 기믹을 배우기도 전에 물량으로 진다 - 실측으로 승률이 27% 였다.
		# 2페이즈에서 포탑 둘로 "물러나면 손해" 를 확실히 못 박는다.
		"waves": [
			# 1페이즈는 순수한 카이팅 판이다. 이 시점의 플레이어는 전술이
			# 모자라므로 새 개체를 여기서 섞으면 배우기 전에 물량으로 진다.
			[
				{ "type": "archer", "pos": Vector2i(5, 1),
				  "cards": ["far_in_range", "keep_range", "hold_fire"] },
				{ "type": "archer", "pos": Vector2i(5, 3),
				  "cards": ["near_first", "run_down"] },
			],
			# 2페이즈에서 고정 포대를 소개한다. 방패병이 앞을 막는 동안 포탑
			# 둘이 뒤에서 쏜다 - **붙어야 하는데 붙는 길이 막혀 있다.**
			[
				{ "type": "shieldman", "pos": Vector2i(5, 2),
				  "cards": ["near_first", "guard_stance", "front_line"] },
				{ "type": "turret", "pos": Vector2i(6, 1), "cards": [],
				  "traits": ["immobile"] },
				{ "type": "turret", "pos": Vector2i(6, 3), "cards": [],
				  "traits": ["immobile"] },
			],
		],
	},
	{
		"id": 3,
		"name": "무너지지 않는 방벽",
		"strategy_text": "방어 태세 → 뒤에서 회복",
		"hint": "신호기부터 때리게 됩니다. 표적 모듈로 그 판단을 덮으십시오.",
		# ── 근접 우선과 "표적 모듈 없음" 을 같이 죽인다 ────────────────────
		# 방패병 둘이 피해를 나누고 악사가 뒤에서 회복한다. 가장 가까운 적만
		# 때리면 실효 HP 를 영영 못 깎는다.
		#
		# 유인 신호기가 여기에 한 겹을 더 얹는다. 기본 표적 판단은 위협도를
		# 보므로(core/rules.gd), 표적 모듈이 하나도 없는 대원은 신호기부터
		# 친다. 신호기는 아무것도 안 하는 물건이라 그 시간이 통째로 버려진다.
		#
		# **표적 모듈을 안 산 대가를 판이 직접 청구한다.** HP 를 60 으로 낮게
		# 둔 것은 의도다 - 못 부수는 벽이 아니라 한 박자를 뺏는 장치여야 한다.
		"waves": [
			# ── 유인 신호기가 표적 판단을 시험한다 ───────────────────────
			# 기본 표적 판단은 위협도를 본다(core/rules.gd). 표적 모듈이 없는
			# 대원은 아무것도 안 하는 신호기부터 친다. 그 사이 자폭체가 붙는다.
			[
				{ "type": "bomber", "pos": Vector2i(5, 1), "cards": [],
				  "traits": ["volatile"] },
				{ "type": "bomber", "pos": Vector2i(5, 3), "cards": [],
				  "traits": ["volatile"] },
				{ "type": "beacon", "pos": Vector2i(6, 2), "cards": [],
				  "traits": ["beacon"] },
				{ "type": "archer", "pos": Vector2i(6, 1),
				  "cards": ["execute", "keep_range"] },
			],
			# 2페이즈는 진짜 방벽이다. 신호기가 표적을 흐리는 동안 악사가
			# 뒤에서 살린다 - 후열을 못 끊으면 영영 안 끝난다.
			[
				{ "type": "beacon", "pos": Vector2i(5, 2), "cards": [],
				  "traits": ["beacon"] },
				{ "type": "bard", "pos": Vector2i(6, 2),
				  "cards": ["behind_guard"], "special": "cantabile" },
				{ "type": "musketeer", "pos": Vector2i(6, 1),
				  "cards": ["execute", "front_line"] },
				# ── 잠복을 처음 만난다 ───────────────────────────────────
				# 3틱간 사라졌다가 후열로 튀어나온다. 그동안 표적으로 잡히지도
				# 않으므로, 앞의 넷을 정리하고 나면 판 위에 아무도 없는데
				# 전투가 안 끝나는 순간이 생긴다. [잠복 사냥] 이 그 답이다.
				{ "type": "assassin", "pos": Vector2i(5, 3),
				  "cards": ["ambush", "backline", "forced_march"] },
			],
		],
	},
	{
		"id": 4,
		"name": "그림자 급습",
		"strategy_text": "후열로 파고들어 처형",
		"hint": "포격이 가운데를 씁니다. 붙을 거면 빨리, 아니면 아예 물러나십시오.",
		# ── 유격 교리를 죽이고, 바닥을 위험하게 만든다 ─────────────────────
		# 암살자들이 곧장 뒤를 판다. 흩어 놓으면 각개격파당하므로 진형을
		# 유지하는 쪽이 답이다.
		#
		# 여기서 궤도 포격이 처음 떨어진다. 가운데 두 열(x=3,4)이 주기적으로
		# 위험해지므로 "붙는다" 는 선택에 값이 붙는다. 빨리 건너가거나 아예
		# 안 건너가거나 - 어중간하게 가운데 서 있는 편성만 손해를 본다.
		#
		# 3페이즈는 감독기다. 살려 두면 나머지가 25% 세진다. 후열을 못 끊는
		# 편성이 여기서 확실히 갈린다.
		"hazard": {
			"kind": "barrage",
			"name": "궤도 포격",
			"first": 8,
			"period": 7,
			"damage": 11,
			# 순서대로 돈다. 난수 없음.
			"patterns": [
				{ "cols": [3, 4] },
				{ "rows": [2] },
				{ "cols": [2, 5] },
			],
		},
		"waves": [
			# 감독기가 처음부터 서 있다. 살려 두면 암살자가 25% 세진다 -
			# "먼저 끊어야 할 적" 이 판 위에 명시적으로 존재한다.
			[
				{ "type": "overseer", "pos": Vector2i(6, 2), "cards": [],
				  "traits": ["overseer"] },
				{ "type": "assassin", "pos": Vector2i(5, 1),
				  "cards": ["backline", "forced_march", "berserk"],
				  "special": "shadow_rend" },
				# 하나는 숨어서 들어온다. 앞에서 배운 것을 여기서는 감독기와
				# 같이 처리해야 한다 - 끊을 것이 둘이고 하나는 안 보인다.
				{ "type": "assassin", "pos": Vector2i(5, 3),
				  "cards": ["ambush", "backline", "forced_march"] },
			],
			# 2페이즈는 같은 문제에 신호기가 얹힌다. 감독기를 끊어야 하는데
			# 표적 판단은 신호기로 끌린다.
			[
				{ "type": "overseer", "pos": Vector2i(6, 2), "cards": [],
				  "traits": ["overseer"] },
				{ "type": "assassin", "pos": Vector2i(5, 1),
				  "cards": ["backline", "forced_march"] },
				{ "type": "archer", "pos": Vector2i(6, 3),
				  "cards": ["execute", "keep_range"] },
				# 전사 하나를 뺐다. 감독기가 전원을 25% 세게 만드는 판에서
				# 다섯은 산술이 안 맞았다 - 실측 승률 11%.
				{ "type": "beacon", "pos": Vector2i(6, 1), "cards": [],
				  "traits": ["beacon"] },
			],
		],
	},
	{
		"id": 5,
		"name": "정예 혼성대",
		"strategy_text": "벽으로 막고 · 쏘고 · 살린다",
		"hint": "세 페이즈가 각각 다른 답을 요구합니다. 하나로는 안 됩니다.",
		# ── 단일 교리를 전부 죽인다 ───────────────────────────────────────
		# 알고리즘은 전투 중에 못 바꾼다. 그러므로 페이즈마다 답이 다르면
		# **하나의 알고리즘으로 세 문제를 다 풀어야 한다.** 이게 이 게임이
		# 마지막에 물어야 할 질문이다.
		#
		#   1페이즈  유인 + 벽    - 표적 판단을 안 짜면 여기서 시간을 다 쓴다
		#   2페이즈  고정 포대 + 감독기 - 붙어야 하는데 붙는 동안 계속 맞는다
		#   3페이즈  정예 3인     - 벽·화력·회복이 동시에 선다
		#
		# 포격이 4단계보다 잦고 세다. 세 페이즈를 오래 끄는 편성은 바닥에서
		# 진다 - 마지막 판은 빨리 끝내는 것 자체가 요구 사항이다.
		"hazard": {
			"kind": "barrage",
			"name": "궤도 포격",
			"first": 7,
			"period": 6,
			"damage": 12,
			"patterns": [
				{ "cols": [3, 4] },
				{ "rows": [1, 3] },
				{ "cols": [2, 5] },
				{ "rows": [2] },
			],
		},
		"waves": [
			# ── 1페이즈 · 표적 ───────────────────────────────────────────
			# 신호기 둘이 표적 판단을 통째로 흔든다. 그 사이 추격 자폭체가
			# 가장 약한 대원 하나만 물고 들어온다. 표적을 못 짜면 여기서
			# 후열이 먼저 사라진다.
			[
				{ "type": "beacon", "pos": Vector2i(5, 1), "cards": [],
				  "traits": ["beacon"] },
				{ "type": "beacon", "pos": Vector2i(5, 3), "cards": [],
				  "traits": ["beacon"] },
				{ "type": "stalker", "pos": Vector2i(6, 2),
				  "cards": ["frail_hunt", "forced_march"], "traits": ["volatile"] },
				{ "type": "shieldman", "pos": Vector2i(6, 1),
				  "cards": ["near_first", "guard_stance", "front_line"] },
			],
			# ── 2페이즈 · 자리 ───────────────────────────────────────────
			# 고정 포대 둘 + 감독기. 붙어야 하는데 붙는 동안 계속 맞고,
			# 감독기를 살려 두면 그 피해가 25% 더 커진다.
			[
				{ "type": "turret", "pos": Vector2i(6, 1), "cards": [],
				  "traits": ["immobile"] },
				{ "type": "turret", "pos": Vector2i(6, 3), "cards": [],
				  "traits": ["immobile"] },
				{ "type": "overseer", "pos": Vector2i(6, 2), "cards": [],
				  "traits": ["overseer"] },
				{ "type": "bomber", "pos": Vector2i(5, 1), "cards": ["forced_march"],
				  "traits": ["volatile"] },
			],
			# ── 3페이즈 · 정예 ───────────────────────────────────────────
			# 벽이 막고, 궁수가 화력을 모으고, 악사가 살린다. 게다가 악사는
			# 광신이라 아군이 죽을수록 세진다 - 오래 끌수록 불리하다.
			[
				{ "type": "shieldman", "pos": Vector2i(5, 2),
				  "cards": ["near_first", "guard_stance", "front_line"],
				  "special": "last_guard" },
				{ "type": "archer", "pos": Vector2i(6, 1),
				  "cards": ["execute", "coop_fire", "keep_range"],
				  "special": "focus_fire" },
				{ "type": "bard", "pos": Vector2i(6, 3),
				  "cards": ["behind_guard"], "special": "cantabile",
				  "traits": ["zealot"] },
			],
		],
	},
]


## ── 검사 전용 배치 ───────────────────────────────────────────────────────
## 규칙 엔진 검사가 쓰는 고정 판. TABLE 에 넣지 않으므로 상점·밸런싱·런에는
## 절대 안 나온다.
##
## ── 왜 따로 두는가 ───────────────────────────────────────────────────────
## 예전에는 검사가 "3단계는 방패병 둘이 앞, 악사가 뒤" 를 그대로 믿었다.
## 그래서 스테이지 표를 재미있게 고칠 때마다 규칙 엔진 검사가 무더기로 터졌고,
## 엔진이 멀쩡한데도 매번 검사를 고치게 됐다.
##
## 검사가 재려는 것은 **표적 선택기가 옳게 도는가** 지 3단계의 구성이 아니다.
## 그러니 절대 안 바뀌는 판을 하나 두고 거기서 재야 한다.
const TEST_ID: int = -1

const TEST: Dictionary = {
	"id": TEST_ID,
	"name": "검사장",
	"strategy_text": "-",
	"hint": "-",
	# 앞(x=5)에 벽 둘, 뒤(x=6)에 회복형 하나. 표적 선택기 전부를 가른다.
	"enemies": [
		{ "type": "shieldman", "pos": Vector2i(5, 1), "cards": [] },
		{ "type": "shieldman", "pos": Vector2i(5, 3), "cards": [] },
		{ "type": "bard", "pos": Vector2i(6, 2), "cards": [] },
	],
}


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


## 페이즈 목록. 한 덩어리 판(튜토리얼)이면 한 파짜리 목록으로 감싸 돌려준다.
##
## 호출부가 "페이즈가 있는 판" 과 "없는 판" 을 구분하지 않게 하려는 것이다.
## 구분하기 시작하면 전투 코어에 if 가 두 갈래로 갈리고, 그 갈래마다 정체
## 판정과 틱 예산을 따로 관리해야 한다.
static func waves(stage: Dictionary) -> Array:
	if stage.has("waves"):
		return stage["waves"]
	return [stage.get("enemies", [])]


## 이 스테이지의 페이즈 수. 편성 화면이 미리 알려 준다.
static func wave_count(stage_id: int) -> int:
	return waves(get_stage(stage_id)).size()


## 이 판에 걸린 지형 기믹. 없으면 빈 사전.
static func hazard(stage_id: int) -> Dictionary:
	return get_stage(stage_id).get("hazard", {})


## 이 판에 등장하는 개체 특성 전부. 편성 전에 그대로 공개한다.
##
## 숨기면 시행착오 게임이 되고 공개하면 추리 게임이 된다(DESIGN 2.4). 그
## 원칙은 적 알고리즘만이 아니라 특성에도 똑같이 적용된다.
static func trait_list(stage_id: int) -> Array[String]:
	var out: Array[String] = []
	for w in waves(get_stage(stage_id)):
		for e in w:
			for t in (e as Dictionary).get("traits", []):
				if not out.has(String(t)):
					out.append(String(t))
	return out


## ── 이 판에 무엇이 나오는가 ─────────────────────────────────────────────
## "적 알고리즘을 공개한다" 는 원칙(DESIGN 2.4)의 마지막 조각이다.
##
## 전략과 페이즈 수와 특성은 이미 공개하고 있었는데, 정작 **어떤 개체가 몇이나
## 나오는지**만 안 알려 줬다. 그래서 표적 축의 대응 모듈들이 도박이 됐다.
## [지원 차단](회복하는 적을 친다)은 적 악사가 있는 판에서만 값을 하고, 실측으로
## 5판 통틀어 8회밖에 안 걸렸다. 살 이유가 없었던 게 아니라 **살 이유를 알
## 방법이 없었다.**
##
## 무엇이 오는지 알면 대응 모듈을 고르는 것이 곧 전략이 된다. 그게 이 게임이
## 스테이지마다 새 답을 요구하는 방식이다.
static func enemy_summary(stage_id: int) -> String:
	var count: Dictionary = {}
	var order: Array[String] = []
	for w in waves(get_stage(stage_id)):
		for e in w:
			var t := String((e as Dictionary)["type"])
			if not count.has(t):
				count[t] = 0
				order.append(t)
			count[t] = int(count[t]) + 1
	var parts: Array[String] = []
	for t in order:
		var nm := String(UnitData.TABLE.get(t, {}).get("name", t))
		parts.append("%s %d" % [nm, int(count[t])])
	return " · ".join(parts)


static func get_stage(stage_id: int) -> Dictionary:
	if stage_id == TUTORIAL_ID:
		return TUTORIAL
	if stage_id == TEST_ID:
		return TEST
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
