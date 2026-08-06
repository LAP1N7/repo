class_name RunState
extends RefCounted

## 전투 밖의 모든 상태: 예산 · 상점 · 손패 · 편성 · 배치.
##
## 뷰를 전혀 모른다. 헤드리스로 전부 검증할 수 있다.
##
## ── 난수에 대해 ────────────────────────────────────────────────────────
## 상점 리롤에만 난수를 쓰고, 그 시드는 스테이지마다 고정한다. 따라서
##   같은 스테이지에서 같은 순서로 조작하면 항상 같은 카드가 제시된다.
## 전투(Battle)는 여전히 난수를 단 한 번도 쓰지 않는다. 즉 손패와 배치가 같으면
## 전투 결과도 항상 같다. 영상 재촬영이 가능한 이유가 이것이다. (DESIGN 1-1)
## ──────────────────────────────────────────────────────────────────────

## ── 스테이지별 예산 ────────────────────────────────────────────────────
## 그 스테이지를 시작할 때 쥐는 돈. 보상으로 받은 누적분(bonus_budget)이 여기 얹힌다.
##
## ── 왜 표로 바꿨는가 ───────────────────────────────────────────────────
## 예전엔 `시작 16 + 깬 수 × 5` 였다. 그러면 곡선이 16 → 21 → 26 → 31 → 36 이고
## 증가율이 +31% → +24% → +19% → +16% 로 **갈수록 밋밋해진다.** 시작이 제일 크고
## 이후 이득의 비중이 계속 줄어드니 "쌓아 올린다" 는 감각이 나올 수가 없다.
##
## 지금은 시작을 조이고 뒤를 키운다. 10 → 17 → 26 → 37 → 50 이고 증가율은
## +70% → +53% → +42% → +35% 다. 1스테이지는 두세 장으로 버티고, 5스테이지에는
## 고티어 카드(4코)·합성(3~6)·궁극기(6~7코)를 감당할 수 있게 된다.
##
## 후반에 돈이 늘어도 슬롯은 9칸 그대로다. 그래서 남는 예산은 장수가 아니라
## **질**로 간다 - 그게 합성과 고티어 카드가 후반에 열리는 이유와 맞물린다.
const STAGE_BUDGET: Array[int] = [10, 17, 26, 37, 50]

## 1스테이지 시작 예산. 표의 첫 칸이다.
const START_BUDGET: int = 10


static func stage_budget(stage: int) -> int:
	return STAGE_BUDGET[clampi(stage, 1, 5) - 1]


## 스테이지를 깼을 때 [보급] 보상으로 고를 수 있는 금액.
## 뒤로 갈수록 커진다 - 상점의 고가치 카드도 뒤로 갈수록 열리므로,
## 살 수 있는 돈이 같이 늘어야 보이기만 하고 못 사는 일이 없다.
const REWARD_BUDGET: Array[int] = [5, 7, 10, 14, 18]
const REWARD_TOKENS: Array[int] = [1, 1, 1, 2, 2]


static func reward_budget(cleared_stage: int) -> int:
	return REWARD_BUDGET[clampi(cleared_stage, 1, 5) - 1]


static func reward_tokens(cleared_stage: int) -> int:
	return REWARD_TOKENS[clampi(cleared_stage, 1, 5) - 1]


## ── 신속 제압 보너스 ────────────────────────────────────────────────────
## 빨리 끝낼수록 예산을 더 준다. 이게 "초반강캐 vs 후반강캐" 를 스탯이 아니라
## **경제**로 만든다.
##
##   초반강캐 - 1~2스테이지를 빨리 깨고 그 예산으로 빌드를 앞당긴다
##   후반강캐 - 초반엔 억지로 버티며 조금만 받고, 4~5스테이지를 쓸어담는다
##
## ── 왜 기준 틱이 스테이지마다 다른가 ───────────────────────────────────
## 실측 승리 평균틱: 1스테이지 11.2 · 2스테이지 11.3 · 3스테이지 34.3 ·
## 4스테이지 10.4 · 5스테이지 32.9. 3·5스테이지는 방벽과 회복이 낀 지구전이라
## 원래 오래 걸린다. 하나의 기준으로 재면 그 두 판은 아무리 잘해도 보너스가
## 영영 0 이 되고, 그러면 "빨리 깨는 보상" 이 아니라 "짧은 판만 보상" 이다.
##
## ── 부익부를 막는 장치 ─────────────────────────────────────────────────
## 그냥 두면 빨리 깬다 → 예산이 는다 → 더 빨리 깬다 로 눈덩이가 된다. 게다가
## 초반 예산은 복리로 불어나므로 같은 금액이라도 1스테이지가 훨씬 값지다.
## 그래서 **상한을 뒤로 갈수록 키운다.**
const SPEED_BASE_TICKS: Array[int] = [16, 16, 40, 15, 38]
const SPEED_CAP: Array[int] = [3, 4, 5, 6, 8]


static func speed_bonus(cleared_stage: int, ticks: int) -> int:
	var i: int = clampi(cleared_stage, 1, 5) - 1
	# 2틱 아낄 때마다 1. 기준보다 느리면 0 이고 마이너스는 없다.
	return clampi((SPEED_BASE_TICKS[i] - ticks) / 2, 0, SPEED_CAP[i])

## 유닛 강화 1단계당 스탯 상승률(%). 정수 연산만 쓴다 - 결정론 때문이다.
const UPGRADE_STEP_PCT: int = 15
const MAX_UPGRADE: int = 5
const SHOP_SIZE: int = 5
const TOTAL_OFFERS: int = SHOP_SIZE

## 특수 스킬은 일반 카드와 같은 풀에서 뽑는다. 다만 뽑기 주머니에 규칙 카드는
## 이 배수만큼, 특수는 1장만 넣어 등장률을 낮춘다.
## 1 이면 특수가 6/20 = 30% 로 흔해져 "특수" 느낌이 사라진다.
## 상점 한 칸이 궁극기일 확률(%). 인덱스는 스테이지 1~5.
##
## ── 왜 주머니에 안 넣는가 ───────────────────────────────────────────────
## 예전엔 궁극기도 전술 카드와 같은 뽑기 주머니에 사본으로 넣었다. 그러면
## **1장 미만으로 넣을 수가 없다.** 6종에 최소 1장씩만 넣어도 11장이고, 카드
## 66장 옆에 서면 14% 다. 실측으로 1스테이지 상점의 59.3% 가 궁극기를 물었다.
##
## 사본 수를 늘려 비율을 희석하는 우회도 해 봤지만(카드 3배), 그건 확률을
## 직접 정하는 대신 분모를 부풀리는 짓이라 값이 무엇을 뜻하는지 읽히지 않는다.
## 슬롯마다 따로 굴리면 원하는 확률을 그대로 적을 수 있다.
##
## 슬롯 5칸이므로 상점 하나에 하나라도 뜰 확률은 1-(1-p)^5 이다.
##   5% → 23%   ·   8% → 34%   ·   12% → 47%   ·   16% → 58%   ·   22% → 71%
const SPECIAL_CHANCE_PCT: Array[int] = [5, 8, 12, 16, 22]


static func special_chance(stage: int) -> int:
	return SPECIAL_CHANCE_PCT[clampi(stage, 1, 5) - 1]

## TODO(로드맵): "캐릭터 n강 이상일 때만 특수가 상점에 등장" 같은 해금 조건.
## 스테이지 1~5 를 넘어가며 강화하는 구조가 들어오면 여기에 게이트를 건다.
## 리롤 기본값. 실제 값은 이번 스테이지에 리롤한 횟수만큼 오른다.
##
## ── 왜 누진인가 ─────────────────────────────────────────────────────────
## 정액 1 이면 예산이 남는 한 무한히 돌려서 1코 카드만 골라 담을 수 있다.
## 실측으로 1스테이지에 평균 8.3장, 최대 11장을 샀다 — 슬롯이 9칸인데 첫
## 스테이지에서 이미 다 채워진다. 리롤이 "안 맞으면 다시" 가 아니라
## "원하는 게 나올 때까지" 가 되면 상점이 선택지가 아니라 자판기가 된다.
const REROLL_COST: int = 1

## 이번 스테이지에서 카드를 한 장 더 살 때마다 붙는 가산금.
##
## ── 왜 장수를 막지 않고 값을 올리는가 ──────────────────────────────────
## "스테이지당 4장까지" 같은 상한은 이해하기 쉽지만, 4장을 채우는 순간 남은
## 예산이 죽은 돈이 되어 "아껴서 좋은 걸 산다" 는 선택이 사라진다.
## 값이 오르면 예산은 끝까지 살아 있고, **한 장 더 사는 것과 좋은 걸 사는 것**
## 사이의 저울질이 매번 새로 생긴다.
##
## 예산이 스테이지마다 늘어나므로 살 수 있는 장수도 자연히 늘어난다.
## 상한을 스테이지별로 따로 적어 줄 필요가 없다.
const BUY_SURCHARGE: int = 1
const PARTY_SIZE: int = 3
const SLOTS_PER_UNIT: int = 3

## 0 이 아니면 이 값으로 런 시드를 고정한다.
##
## ── 왜 기본을 무작위로 바꿨는가 ────────────────────────────────────────
## 예전엔 스테이지별 고정 시드였다. 영상을 다시 찍어도 같은 카드가 나오게 하려고
## 그렇게 뒀는데, 그러면 **모든 런의 상점이 완전히 똑같다.** 로그라이트에서
## 매번 같은 카드가 같은 순서로 뜨면 덱 빌딩이라는 게 성립하지 않는다.
##
## 지금은 런 시작마다 시드를 새로 뽑고, 그 시드에서 스테이지별 시드를 파생한다.
## 한 런 안에서는 여전히 완전히 결정론적이라 재현과 디버깅에는 지장이 없고,
## 재현이 꼭 필요한 곳(테스트·몬테카를로)만 이 값을 채우면 된다.
var fixed_seed: int = 0

## 이번 런의 시드. start_run 에서 정해지고 런 내내 유지된다.
var run_seed: int = 0

var stage_id: int = 1
var budget: int = START_BUDGET
var rng: RandomNumberGenerator

## ── 런(run) 상태 - 스테이지를 넘어가도 유지된다 ─────────────────────────
## 이게 로그라이트의 전부다. 예전에는 스테이지를 바꿀 때마다 start() 로 전부
## 리셋했기 때문에 "쌓아 올린다" 는 감각이 없었다.

## 유닛 종류별 강화 단계. type_id -> 0..MAX_UPGRADE
var upgrades: Dictionary = {}

## 카드 종류별 합성 단계. card_id -> 1..Cards.MAX_LEVEL (없으면 1)
##
## 장 단위가 아니라 **종류 단위**다. 이유는 Cards 쪽 주석 참조.
var card_levels: Dictionary = {}

## 덱 정제권. 보상으로 얻고, 손패에서 카드를 영구히 버릴 때 1장 쓴다.
## 정제를 상시 무료로 열어두면 누구나 덱을 최적화해서 빌드 다양성이 죽는다.
## 자원으로 묶어야 "지금 정제할까, 강화 받을까" 라는 진짜 선택이 생긴다.
var refine_tokens: int = 0

## 보상으로 받은 누적 예산.
##
## 스테이지 예산은 start() 에서 stage_budget(stage) 로 **다시 계산**된다. 그래서 보상 화면에서 budget 에 직접 더해 봐야 다음 스테이지에
## 진입하는 순간 통째로 지워졌다 - 경제 보상을 골라도 아무 일도 안 났다는 뜻이다.
## 여기에 쌓아 두고 재계산 식에 함께 넣는다.
var bonus_budget: int = 0

## 방금 깬 스테이지에서 받은 신속 제압 보너스. 보상 화면이 읽어서 보여 준다.
var last_speed_bonus: int = 0

## 지금까지 깬 스테이지 수.
var cleared: int = 0

## 보상 화면이 제시한 선택지. 새로고침되지 않게 런 상태에 들고 있는다.
var pending_rewards: Array = []

## 구매한 카드. 같은 카드를 두 번 사면 두 개가 들어간다.
var hand: Array[String] = []

## 구매한 특수 스킬. 카드와 섞지 않는다 - 꽂는 슬롯이 다르기 때문이다.
var special_hand: Array[String] = []

## 이번 런에서 추방한 카드. 리롤해도 다시 나오지 않는다.
var banned: Dictionary = {}

## 상점에 깔린 카드. 산 자리는 "" 로 비워 둔다.
var offers: Array[String] = []

## 튜토리얼처럼 제시 카드를 정해 놓고 싶을 때 쓴다.
## 비어 있지 않으면 리롤해도 이 목록이 그대로 다시 깔린다.
## 대본이 "[교전] 을 사" 라고 지목하는데 무작위로 안 나오면 말이 안 되기 때문이다.
var fixed_offers: Array[String] = []

## 편성. 유닛 타입과 자리(0~5)만 담고, 규칙은 unit_cards 가 따로 들고 있다.
## [{ "type": String, "slot": int }, ...]
var roster: Array = []

## roster 인덱스별 규칙 슬롯. 손패에서 꺼내 꽂은 카드 id 들.
var unit_cards: Array = []

## roster 인덱스별 특수 슬롯 1칸. 빈 문자열이면 없음.
var unit_special: Array = []

## 특수를 전술 슬롯보다 먼저 볼지. roster 인덱스별.
var unit_special_first: Array = []


## 런을 처음부터 시작한다. 강화·정제권까지 전부 날아간다.
func start_run(p_stage_id: int = 1) -> void:
	# 시드는 런 단위다. 스테이지를 넘어가도 같은 시드에서 파생되므로 한 런은
	# 통째로 재현 가능하고, 다음 런은 완전히 다른 상점이 된다.
	run_seed = fixed_seed if fixed_seed != 0 else int(randi())
	upgrades.clear()
	card_levels.clear()
	fixed_offers.clear()
	refine_tokens = 0
	bonus_budget = 0
	cleared = 0
	pending_rewards.clear()

	# ── 편성을 손패보다 **먼저** 비워야 한다 ──────────────────────────────
	# 바로 아래 start() 가 제일 먼저 _return_equipped_to_hand() 를 부른다.
	# 스테이지를 넘어갈 때 꽂아둔 카드를 잃지 않으려고 있는 장치인데, 런을
	# 새로 시작할 때는 그게 **이전 런의 카드를 새 손패에 부어 넣는다.**
	#
	# 튜토리얼을 마치고 [런 시작] 을 누르면 튜토리얼에서 산 [교전]·[거리 유지]가
	# 그대로 손패에 남아 있던 게 이것이다. hand.clear() 는 분명히 했는데,
	# 그 직후 start() 가 튜토리얼 편성에서 두 장을 되돌려 놨다.
	command_levels.clear()
	roster.clear()
	unit_cards.clear()
	unit_special.clear()
	unit_special_first.clear()

	hand.clear()
	special_hand.clear()
	# 추방은 런 전체에 걸린다. 스테이지 단위 start() 에서 지우면 다음 스테이지에
	# 되살아나서 "이 런에서 다시 안 나온다" 는 약속이 거짓말이 된다.
	banned.clear()
	start(p_stage_id)


## 한 스테이지 준비. 예산·손패·편성을 초기화하지만 런 상태(강화·정제권)는 남긴다.
func start(p_stage_id: int) -> void:
	# 편성을 풀기 전에 꽂아둔 것들을 손패로 되돌린다.
	# 이걸 빼먹으면 스테이지를 넘어갈 때마다 장착했던 카드가 증발한다 -
	# 덱을 쌓아 올리는 로그라이트 구조 자체가 무너진다.
	_return_equipped_to_hand()

	stage_id = p_stage_id
	budget = stage_budget(p_stage_id) + bonus_budget
	# banned 는 여기서 지우지 않는다 - start_run 에서만 푼다.
	roster.clear()
	unit_cards.clear()
	unit_special.clear()
	unit_special_first.clear()

	# 가산금은 스테이지마다 리셋된다. 안 그러면 뒤로 갈수록 한 장도 못 산다.
	buys_this_stage = 0
	rerolls_this_stage = 0

	rng = RandomNumberGenerator.new()
	# 런 시드에서 스테이지 시드를 파생한다. 곱하는 수는 서로소인 소수면 무엇이든
	# 되고, 스테이지끼리 제시가 겹치지 않게만 하면 된다.
	rng.seed = run_seed + p_stage_id * 7919

	offers.clear()
	_fill_offers()


## 유닛에 꽂혀 있던 카드와 특수를 전부 손패로 회수한다.
func _return_equipped_to_hand() -> void:
	for slots in unit_cards:
		for cid in slots:
			hand.append(cid)
	for sid in unit_special:
		if String(sid) != "":
			special_hand.append(String(sid))


# ── 상점 ─────────────────────────────────────────────────────────────────

## 추방되지 않은 카드 종류.
func pool() -> Array[String]:
	var out: Array[String] = []
	for cid in Cards.shop_order():
		if not banned.has(cid):
			out.append(cid)
	return out


## 추방되지 않은 특수 스킬 종류.
func special_pool() -> Array[String]:
	var out: Array[String] = []
	for sid in Specials.ORDER:
		if not banned.has(sid):
			out.append(sid)
	return out


## 전술 카드 뽑기 주머니. 궁극기는 여기 없다 - 슬롯마다 따로 굴린다.
##
## 예전엔 모든 카드를 CARD_WEIGHT(3)장씩 똑같이 넣었다. 카드마다 적어둔 weight 는
## 한 번도 읽히지 않았고, 그래서 마무리·구호 같은 고가치 카드가 교전과 똑같은
## 확률로 1스테이지부터 쏟아졌다. 지금은 티어와 스테이지가 장수를 정한다.
func _make_bag() -> Array[String]:
	var bag: Array[String] = []
	for cid in pool():
		for _w in Cards.copies(cid, stage_id):
			bag.append(cid)
	return bag


## 이번 슬롯에 넣을 궁극기 하나. 못 고르면 "".
## taken 에 이미 든 종류는 건너뛴다 - 한 상점에 같은 궁극기가 둘 뜨면 안 된다.
func _roll_special(taken: Dictionary) -> String:
	# 고밸류 회선이 확률을 올린다.
	if rng.randi_range(1, 100) > special_chance(stage_id) + command_amount("rarity"):
		return ""
	# weight 는 궁극기끼리의 상대 빈도다. 비영천참(1)이 나머지(2)보다 귀하다.
	var pick_bag: Array[String] = []
	for sid in special_pool():
		if taken.has(sid):
			continue
		for _w in int(Specials.TABLE[sid]["weight"]):
			pick_bag.append(sid)
	if pick_bag.is_empty():
		return ""
	return pick_bag[rng.randi_range(0, pick_bag.size() - 1)]


func _fill_offers() -> void:
	offers.clear()
	if not fixed_offers.is_empty():
		for cid in fixed_offers:
			offers.append(cid)
		return
	var bag := _make_bag()

	# 한 번의 제시 안에서는 같은 종류가 겹치지 않게 뽑는다.
	var taken: Dictionary = {}
	for _i in SHOP_SIZE:
		# 궁극기 판정을 먼저 한다. 카드 주머니와 무관한 독립 확률이라
		# 카드가 몇 종 남았든 궁극기 등장률이 흔들리지 않는다.
		var sp := _roll_special(taken)
		if sp != "":
			taken[sp] = true
			offers.append(sp)
			continue

		if bag.is_empty():
			offers.append("")
			continue
		var k := rng.randi_range(0, bag.size() - 1)
		var pick: String = bag[k]
		# 뽑힌 종류를 주머니에서 전부 걷어낸다 (가중치 사본까지).
		var left: Array[String] = []
		for x in bag:
			if x != pick:
				left.append(x)
		bag = left
		taken[pick] = true
		offers.append(pick)


## 제시 목록에 있는 id 가 특수 스킬인가.
static func is_special(id: String) -> bool:
	return id != "" and Specials.TABLE.has(id)


## 이번 스테이지에서 이미 산 장수 / 돌린 횟수. start() 에서 초기화된다.
var buys_this_stage: int = 0
var rerolls_this_stage: int = 0


## 지금 한 장 더 살 때 붙는 가산금.
func surcharge() -> int:
	# 두 장마다 +1. 장당 +1 로 뒀더니 1스테이지에 4장밖에 못 사서 유닛 셋이
	# 카드 1~2장으로 싸웠고, 런 시뮬레이션 평균 도달이 1.0~1.5스테이지였다.
	# 카드가 없으면 순서를 짤 것도 없으므로 게임 자체가 성립하지 않는다.
	return buys_this_stage / 2 * BUY_SURCHARGE


## 지금 리롤에 드는 값.
func reroll_cost() -> int:
	return maxi(1, REROLL_COST + rerolls_this_stage - command_amount("reroll"))


## 카드 자체의 값. 가산금은 포함하지 않는다 — 카드에 적히는 숫자다.
func cost_of(id: String) -> int:
	if id == "":
		return 0
	if Specials.TABLE.has(id):
		return int(Specials.TABLE[id]["cost"])
	if Cards.TABLE.has(id):
		return int(Cards.TABLE[id]["cost"])
	return 0


## 실제로 지불할 값. 카드값 + 이번 스테이지 가산금.
func price_of(id: String) -> int:
	return cost_of(id) + surcharge() if id != "" else 0


func can_buy(index: int) -> bool:
	if index < 0 or index >= offers.size():
		return false
	var cid: String = offers[index]
	return cid != "" and price_of(cid) <= budget


## 상점의 index 번 카드를 산다. 그 자리는 비고, 예산이 깎이고, 손패에 들어간다.
func buy(index: int) -> bool:
	if not can_buy(index):
		return false
	var cid: String = offers[index]
	budget -= price_of(cid)
	buys_this_stage += 1
	if is_special(cid):
		special_hand.append(cid)
	else:
		hand.append(cid)
	offers[index] = ""
	return true


## 이번 런에서 그 카드를 영구 추방한다. 리롤해도 다시 나오지 않는다.
## 값은 들지 않는다 - 손해는 "그 카드를 앞으로 못 쓴다" 는 것 자체다.
func ban(index: int) -> bool:
	if index < 0 or index >= offers.size():
		return false
	var cid: String = offers[index]
	if cid == "":
		return false
	banned[cid] = true
	# 같은 카드가 다른 자리에도 깔려 있으면 함께 치운다.
	for i in offers.size():
		if offers[i] == cid:
			offers[i] = ""
	return true


func can_reroll() -> bool:
	if budget < reroll_cost():
		return false
	return not pool().is_empty() or not special_pool().is_empty()


func reroll() -> bool:
	if not can_reroll():
		return false
	budget -= reroll_cost()
	rerolls_this_stage += 1
	_fill_offers()
	return true


# ── 편성 / 배치 ──────────────────────────────────────────────────────────

## 이번 전투에 세워야 하는 인원.
##
## 튜토리얼만 1명이다. 대본이 궁수 한 명만 배치시키는데 본편과 같은 3명을
## 요구하면 [전투 시작] 이 영영 비활성이라 튜토리얼이 그 자리에서 막힌다.
## 실제로 막혔다. 그렇다고 대본을 3명으로 늘리면 배우는 양이 세 배가 되고,
## 첫 화면에서 가르쳐야 할 것(카드 순서)이 편성 노동에 묻힌다.
func required_party() -> int:
	return 1 if stage_id == Stages.TUTORIAL_ID else PARTY_SIZE


func party_full() -> bool:
	return roster.size() >= required_party()


func slot_taken(slot: int) -> bool:
	for m in roster:
		if int(m["slot"]) == slot:
			return true
	return false


## 유닛을 자리에 배치한다. 이미 찬 자리거나 인원이 다 찼으면 실패.
func place(type_id: String, slot: int) -> bool:
	if party_full() or slot_taken(slot):
		return false
	if not UnitData.TABLE.has(type_id):
		return false
	if slot < 0 or slot >= Grid.PLAYER_SLOTS.size():
		return false
	roster.append({ "type": type_id, "slot": slot })
	unit_cards.append([] as Array)
	unit_special.append("")
	unit_special_first.append(false)
	return true


func remove_member(index: int) -> bool:
	if index < 0 or index >= roster.size():
		return false
	# 꽂아둔 것은 전부 손패로 되돌린다. 배치를 무르면서 잃으면 안 된다.
	for cid in unit_cards[index]:
		hand.append(cid)
	if String(unit_special[index]) != "":
		special_hand.append(unit_special[index])
	roster.remove_at(index)
	unit_cards.remove_at(index)
	unit_special.remove_at(index)
	unit_special_first.remove_at(index)
	return true


# ── 규칙 장착 ────────────────────────────────────────────────────────────

## 손패에서 카드 하나를 꺼내 유닛 슬롯에 꽂는다. 손패에서는 사라진다.
func equip(member: int, card_id: String) -> bool:
	if member < 0 or member >= unit_cards.size():
		return false
	var slots: Array = unit_cards[member]
	if slots.size() >= SLOTS_PER_UNIT:
		return false
	var at := hand.find(card_id)
	if at < 0:
		return false
	hand.remove_at(at)
	slots.append(card_id)
	return true


## 꽂은 카드를 빼서 손패로 되돌린다.
func unequip(member: int, slot: int) -> bool:
	if member < 0 or member >= unit_cards.size():
		return false
	var slots: Array = unit_cards[member]
	if slot < 0 or slot >= slots.size():
		return false
	hand.append(slots[slot])
	slots.remove_at(slot)
	return true


## 우선순위 변경. 이 순서가 곧 전략이다.
func move_slot(member: int, slot: int, delta: int) -> bool:
	if member < 0 or member >= unit_cards.size():
		return false
	var slots: Array = unit_cards[member]
	var to := slot + delta
	if slot < 0 or slot >= slots.size() or to < 0 or to >= slots.size():
		return false
	var tmp = slots[slot]
	slots[slot] = slots[to]
	slots[to] = tmp
	return true


# ── 특수 슬롯 ────────────────────────────────────────────────────────────

## 그 유닛이 이 특수 스킬을 쓸 수 있는가. 직업이 맞아야 한다.
func can_equip_special(member: int, sid: String) -> bool:
	if member < 0 or member >= roster.size():
		return false
	if not special_hand.has(sid):
		return false
	return Specials.usable_by(sid, String(roster[member]["type"]))


## 특수 슬롯은 1칸뿐이라, 이미 꽂혀 있으면 기존 것을 손패로 되돌리고 교체한다.
func equip_special(member: int, sid: String) -> bool:
	if not can_equip_special(member, sid):
		return false
	if String(unit_special[member]) != "":
		special_hand.append(unit_special[member])
	special_hand.remove_at(special_hand.find(sid))
	unit_special[member] = sid
	return true


## 특수를 전술보다 먼저 볼지 뒤집는다. 이 순서 자체가 전략의 일부다.
func toggle_special_first(member: int) -> bool:
	if member < 0 or member >= unit_special_first.size():
		return false
	unit_special_first[member] = not bool(unit_special_first[member])
	return true


func unequip_special(member: int) -> bool:
	if member < 0 or member >= unit_special.size():
		return false
	if String(unit_special[member]) == "":
		return false
	special_hand.append(unit_special[member])
	unit_special[member] = ""
	return true


# ── 전투 넘기기 ──────────────────────────────────────────────────────────

## 인원만 채우면 출전할 수 있다.
##
## 예전에는 규칙이 없는 유닛을 막았다. 그때는 카드가 하나도 없으면 유닛이 정말로
## 아무것도 안 하고 서 있었기 때문이다. 지금은 직업 기본기가 폴백으로 깔려 있어서
## 빈손이어도 제 몫을 한다. 그러니 막을 이유가 없고, 오히려 "기본기만으로 어디까지
## 되나" 를 시험해 보는 것도 유효한 플레이다.
func ready_to_fight() -> bool:
	return roster.size() >= required_party()


func blocking_reason() -> String:
	if roster.size() < required_party():
		return UiText.t("state.need_units", "대원을 %d명 배치해야 합니다. (현재 %d명)") % [required_party(), roster.size()]
	return ""


## 경고는 아니지만 알려는 줘야 하는 것. 빈손 유닛이 있으면 이름을 돌려준다.
func bare_units() -> Array[String]:
	var out: Array[String] = []
	for i in unit_cards.size():
		if (unit_cards[i] as Array).is_empty():
			out.append(String(UnitData.TABLE[roster[i]["type"]]["name"]))
	return out


# ── 강화 ─────────────────────────────────────────────────────────────────

func upgrade_level(type_id: String) -> int:
	return int(upgrades.get(type_id, 0))


func can_upgrade(type_id: String) -> bool:
	return upgrade_level(type_id) < MAX_UPGRADE


func apply_upgrade(type_id: String) -> bool:
	if not can_upgrade(type_id):
		return false
	upgrades[type_id] = upgrade_level(type_id) + 1
	return true


## 강화가 반영된 스탯. 식은 UnitData.scaled 한 곳에만 있다 - 여긴 강화 단계만 얹는다.
func upgraded_stat(type_id: String, key: String, base: int) -> int:
	return UnitData.scaled(type_id, key, base, upgrade_level(type_id))


# ── 합성 ─────────────────────────────────────────────────────────────────

func card_level(card_id: String) -> int:
	return int(card_levels.get(card_id, 1))


## 손패에 그 카드가 몇 장 있는가.
func copies_of(card_id: String) -> int:
	var n := 0
	for c in hand:
		if String(c) == card_id:
			n += 1
	return n


## 같은 카드 2장을 합쳐 한 단계 올릴 수 있는가.
##
## 2장을 넣고 1장이 남는다. 남기지 않고 전부 소모하면 "합성했더니 쓸 카드가
## 없어졌다" 가 되어 아무도 안 쓴다. 손패는 한 장 줄고 성능은 올라간다.
## 이 카드를 한 단계 올리는 데 드는 예산.
func merge_price(card_id: String) -> int:
	return Cards.merge_cost(card_level(card_id))


func can_merge(card_id: String) -> bool:
	if not Cards.can_merge(card_id):
		return false
	if budget < merge_price(card_id):
		return false
	if card_level(card_id) >= Cards.MAX_LEVEL:
		return false
	return copies_of(card_id) >= Cards.MERGE_COPIES


func merge(card_id: String) -> bool:
	if not can_merge(card_id):
		return false
	budget -= merge_price(card_id)
	for _i in Cards.MERGE_COPIES - 1:
		hand.remove_at(hand.find(card_id))
	card_levels[card_id] = card_level(card_id) + 1
	return true


## 합성이 막힌 이유. 화면에 그대로 띄운다.
## 보상으로 카드를 받는다. 이미 가진 카드면 그 자리에서 합성한다.
##
## ── 왜 자동 합성인가 ────────────────────────────────────────────────────
## 런 시뮬레이션에서 **강화 보상이 희귀 보상을 2~5배로 이겼다**(클리어율 11.7%
## vs 5.0%). 이유는 단순하다 - 슬롯 9칸이 이미 차 있으면 카드 한 장은 꽂을 데가
## 없어 그냥 죽은 보상이고, 강화는 언제 받아도 스탯이 오른다.
##
## 받은 카드가 이미 있으면 합성으로 넘겨 주면 그 문제가 사라진다. 슬롯이 차
## 있어도 값을 하고, "덱을 완성한다" 는 감각과도 맞물린다.
func grant_card(card_id: String) -> String:
	if is_special(card_id):
		special_hand.append(card_id)
		return UiText.t("state.got_module", "확보")
	hand.append(card_id)
	if can_merge(card_id):
		merge(card_id)
		return UiText.t("state.merged", "이미 보유 중이므로 %d등급으로 통합") % card_level(card_id)
	return UiText.t("state.got_module", "확보")


func merge_blocker(card_id: String) -> String:
	if not Cards.can_merge(card_id):
		return UiText.t("state.merge_no_stat", "이 모듈은 상승시킬 수치가 없습니다")
	if card_level(card_id) >= Cards.MAX_LEVEL:
		return UiText.t("state.merge_maxed", "이미 최고 등급입니다")
	if budget < merge_price(card_id):
		return UiText.t("state.merge_poor", "예산 %d 이 필요합니다 (현재 %d)") % [merge_price(card_id), budget]
	if copies_of(card_id) < Cards.MERGE_COPIES:
		return UiText.t("state.merge_need", "동일 모듈 %d개가 필요합니다 (현재 %d개)") % [
			Cards.MERGE_COPIES, copies_of(card_id)]
	return ""


# ── 정제 ─────────────────────────────────────────────────────────────────

## 손패에서 카드 한 장을 영구히 버린다. 정제권 1장을 쓴다.
func refine(card_id: String) -> bool:
	if refine_tokens <= 0:
		return false
	var at := hand.find(card_id)
	if at >= 0:
		hand.remove_at(at)
		refine_tokens -= 1
		return true
	var at2 := special_hand.find(card_id)
	if at2 >= 0:
		special_hand.remove_at(at2)
		refine_tokens -= 1
		return true
	return false


# ── 스테이지 클리어 ──────────────────────────────────────────────────────

## ticks 는 그 전투가 걸린 틱 수. 신속 제압 보너스에 쓴다.
## 0 이면 보너스 없음 - 테스트나 개발용 경로에서 그냥 부를 수 있게 둔다.
func on_stage_cleared(ticks: int = 0) -> void:
	cleared += 1
	# 보급 확충 - 단계를 깰 때마다 붙는다.
	bonus_budget += command_amount("income")
	# 예산 운용 - 남긴 예산에 이자가 붙는다. 안 쓰고 모으는 선택에 값을 준다.
	if command_level("interest") > 0:
		bonus_budget += budget / 8
	last_speed_bonus = 0
	if ticks > 0:
		last_speed_bonus = speed_bonus(stage_id, ticks)
		bonus_budget += last_speed_bonus


func has_next_stage() -> bool:
	return Stages.next_id(stage_id) != -1


## 다음 스테이지로. 덱(손패)과 강화는 유지되고 편성만 다시 짠다.
func advance() -> bool:
	var nxt := Stages.next_id(stage_id)
	if nxt == -1:
		return false
	start(nxt)
	return true


## Battle.setup() 이 먹는 형식으로 변환한다.
func to_party() -> Array:
	var out: Array = []
	for i in roster.size():
		out.append({
			"special": String(unit_special[i]),
			"special_first": bool(unit_special_first[i]),
			"type": roster[i]["type"],
			"slot": int(roster[i]["slot"]),
			"cards": (unit_cards[i] as Array).duplicate(),
			"card_levels": card_levels.duplicate(),
			"upgrade": upgrade_level(String(roster[i]["type"])),
			# 보조 지휘 강화. 전투가 이 값으로 능력치를 얹는다.
			"cmd": {
				"atk": command_amount("atk"),
				"def": command_amount("def"),
				"hp": command_amount("hp"),
				"axis_target": command_amount("axis_target"),
				"axis_position": command_amount("axis_position"),
				"axis_doctrine": command_amount("axis_doctrine"),
				"repair": command_amount("repair"),
			},
		})
	return out


## 보조 지휘 강화 단계. id -> level(0~3)
##
## 런 내내 유지된다. 스테이지를 넘어도 안 풀린다 - 이건 부대를 키우는 것이지
## 이번 교전을 푸는 것이 아니다. (data/command.gd 참조)
var command_levels: Dictionary = {}


func command_level(id: String) -> int:
	return int(command_levels.get(id, 0))


## 그 항목의 현재 효과값.
func command_amount(id: String) -> int:
	return Command.amount(id, command_level(id))


## 한 단계 올린다. 예산이 모자라거나 최대면 실패하고 이유를 돌려준다.
func command_buy(id: String) -> String:
	if not Command.TABLE.has(id):
		return UiText.t("cmd.unknown", "없는 항목입니다")
	var lv := command_level(id)
	var price := Command.price(lv)
	if price < 0:
		return UiText.t("cmd.maxed", "이미 최고 단계입니다")
	if budget < price:
		return UiText.t("cmd.poor", "예산 %d 이 필요합니다 (현재 %d)") % [price, budget]
	budget -= price
	command_levels[id] = lv + 1
	return ""


## 보유 모듈 하나를 같은 축의 다른 모듈로 바꾼다.
##
## 축을 넘어가면 안 된다. 표적을 위치로 바꿀 수 있으면 축의 의미가 사라진다.
## 축 안에서만 도니까 "표적 교리를 다듬는다" 가 된다.
func command_swap(cid: String) -> String:
	if not hand.has(cid):
		return UiText.t("cmd.not_owned", "보유하지 않은 모듈입니다")
	if budget < Command.SWAP_COST:
		return UiText.t("cmd.poor", "예산 %d 이 필요합니다 (현재 %d)") % [
			Command.SWAP_COST, budget]
	var axis := String(Cards.TABLE.get(cid, {}).get("axis", ""))
	var pool: Array[String] = []
	for other in Cards.shop_order():
		if other != cid and String(Cards.TABLE[other]["axis"]) == axis \
				and not banned.has(other):
			pool.append(other)
	if pool.is_empty():
		return UiText.t("cmd.no_swap", "바꿀 대상이 없습니다")
	budget -= Command.SWAP_COST
	hand.erase(cid)
	# 무작위지만 **런 시드**를 쓴다. 같은 런을 다시 돌리면 같은 결과가 나온다.
	hand.append(pool[rng.randi_range(0, pool.size() - 1)])
	return ""


func spent() -> int:
	return START_BUDGET - budget
