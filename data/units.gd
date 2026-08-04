class_name UnitData

## 유닛 원본 스탯과 캐릭터 컨셉.
##
## ── growth 가 왜 따로 있는가 ───────────────────────────────────────────────
## 파워 곡선은 스탯만으로 못 그린다. "초반에 세고 후반에 밀린다" 는 시작 스탯이
## 아니라 **강화가 붙는 속도**의 문제다. growth 는 RunState.UPGRADE_STEP_PCT 에
## 곱해지는 백분율이고, 100 이 표준이다.
##
## ── 왜 HP 와 공격을 나눴는가 ──────────────────────────────────────────────
## 하나로 두면 방패병에게 공격력 강화를, 궁수에게 체력 강화를 똑같이 먹이게 된다.
## 그러면 강화가 "무조건 좋은 것" 이라 고를 이유가 없다. 축을 나누면 강화 한 번이
## 곧 "이 대원을 어느 방향으로 키울까" 가 되고, 캐릭터 컨셉과도 맞아떨어진다.
##
##   유닛     HP   공격   방향
##   총사     85   70    초·중반에 이미 완성형. 강화를 먹여도 덜 큰다
##   궁수     90  125    유리대포가 더 유리대포가 된다
##   암살자   90  175    시작은 물몸, 강화가 쌓일수록 손을 못 쓴다
##   전사    115   95    맞아 주는 쪽으로 굳는다
##   방패병  130   80    벽이 더 두꺼워진다. 공격 강화는 거의 의미 없다
##   악사    100  100    평탄
##
## ── art 는 왜 데이터에 있는가 ──────────────────────────────────────────────
## 스프라이트를 그릴 때 참조할 컨셉이다. ASSETS.md 와 여기가 어긋나면 다시
## 그리게 되므로 원본을 한 곳에만 둔다.
const TABLE: Dictionary = {
	"warrior": {
		"name": "전사",
		"hp": 125,
		"atk": 18,
		"range": 1,
		"move": 1,
		"slots": 3,
		"growth_hp": 115,
		"growth_atk": 95,
		"curve": "균형",
		"curve_text": "전 구간 중간. 무너지지 않는 대신 폭발하지도 않는다.",
		"role": "벽, 어그로",
		"art": "남캐 · 도끼 버서커. 몰릴수록 세진다",
		"color": Color(0.85, 0.35, 0.30),
	},
	"archer": {
		# 유리대포. 사거리 3 은 이 게임에서 가장 긴 사거리고, 그 대가로 HP 가
		# 제일 낮다. 총사가 사거리 2 로 내려오면서 "제일 멀리서 쏘는 유닛" 자리를
		# 궁수가 독점한다.
		"name": "궁수",
		"hp": 65,
		"atk": 24,
		"range": 3,
		"move": 1,
		"slots": 3,
		"growth_hp": 90,
		"growth_atk": 125,
		"curve": "기복",
		"curve_text": "초반에 반짝, 중반에 밀리다, 강화가 쌓이면 다시 올라온다.",
		"role": "장거리 딜, 카이팅",
		"art": "여캐 · 기계식 활. 정밀 사격형",
		"color": Color(0.35, 0.75, 0.45),
	},
	"bard": {
		# 구 "사제". 컨셉을 악사로 바꿨다 - 기술 이름이 전부 악상 기호라
		# 회복 타이밍(레가토=매 틱 조금씩 / 칸타빌레=한 번에 크게)이 이름만으로 읽힌다.
		"name": "악사",
		"hp": 72,
		"atk": 9,
		"range": 2,
		"move": 1,
		"slots": 3,
		"growth_hp": 100,
		"growth_atk": 100,
		"curve": "균형",
		"curve_text": "혼자서는 못 이긴다. 다른 둘을 오래 살린다.",
		"role": "지속 회복, 유지력",
		"art": "성별 미상 · 여러 악기를 다룬다",
		"color": Color(0.95, 0.85, 0.45),
	},
	"assassin": {
		"name": "암살자",
		"hp": 58,
		"atk": 32,
		"range": 1,
		"move": 2,
		"slots": 3,
		"growth_hp": 90,
		"growth_atk": 175,
		"curve": "후반",
		"curve_text": "초반엔 짐이다. 강화를 몰아주면 판을 혼자 끝낸다.",
		"role": "후열 급습, 유리대포",
		"art": "남캐 · 쌍단검",
		"color": Color(0.65, 0.35, 0.80),
	},
	"musketeer": {
		# 인파이팅 원딜. 사거리 2 는 의도된 값이다 - 원거리인데 붙어야 하는
		# 어정쩡한 거리가 이 캐릭터의 정체성이고, 궁극기 [거리두기] 가 그 어정쩡함을
		# 무기로 바꾼다.
		#
		# 부작용을 하나 알고 간다: `거리 유지`(적 2칸 이내 → 후퇴)는 총사에게
		# 사문화된다. 쏠 수 있는 거리 전부에서 물러나기 때문이다. 이건 버그가 아니라
		# "총사는 거리를 안 두는 원딜" 이라는 차별화다. 카이팅 카드는 궁수의 것이다.
		"name": "총사",
		"hp": 100,
		"atk": 20,
		"range": 2,
		"move": 1,
		"slots": 3,
		"growth_hp": 85,
		"growth_atk": 70,
		"curve": "초반",
		"curve_text": "처음부터 완성형. 대신 강화를 먹여도 덜 큰다.",
		"role": "근접 견제, 인파이팅 원딜",
		"art": "여캐 · 산탄총",
		"color": Color(0.90, 0.62, 0.30),
	},
	"dummy": {
		"name": "표적",
		# 튜토리얼 궁수(공 24)가 정확히 3발에 부순다. 리듬을 위해 딱 맞춘 값이다.
		"hp": 70,
		"atk": 6,
		"range": 1,
		"move": 1,
		"slots": 3,
		"growth_hp": 100,
		"growth_atk": 100,
		"curve": "균형",
		"curve_text": "훈련용.",
		"role": "훈련용 표적",
		"art": "짚 인형 · 나무 받침",
		"color": Color(0.55, 0.52, 0.48),
		# 튜토리얼 전용. 플레이어 편성 목록에는 뜨지 않는다.
		"enemy_only": true,
	},
	"shieldman": {
		"name": "방패병",
		"hp": 190,
		"atk": 9,
		"range": 1,
		"move": 1,
		"slots": 3,
		"growth_hp": 130,
		"growth_atk": 80,
		"curve": "균형",
		"curve_text": "벽으로 시작해 더 두꺼운 벽이 된다.",
		"role": "초벽, 방어 태세 전문",
		"art": "방패에 싸여 얼굴이 보이지 않는다",
		"color": Color(0.40, 0.60, 0.85),
	},
}

## 악사 기본기 [레가토] 1회 회복량. 매 틱 들어가므로 작아야 한다.
const BARD_HEAL: int = 20

static func get_stat(unit_id: String, key: String) -> Variant:
	return TABLE[unit_id][key]


## 이 유닛의 파워 곡선 이름. 편성 화면에서 고르기 **전에** 보여 준다.
##
## ── 왜 UI 에 노출하는가 ──────────────────────────────────────────────────
## "초반강캐를 후반까지 키울까, 후반강캐를 초반에 버티며 키울까" 가 이 게임의
## 핵심 저울질이다. 그런데 그 정보가 화면 어디에도 없으면 저울질이 아니라
## 도박이 된다. 실측으로 암살자는 1스테이지 0강 승률 0% → 5스테이지 3강 100%,
## 총사는 83% → 67% 다. 이걸 모르고 고르면 첫 판에서 이유도 모르고 전멸한다.
##
## 강화 대상이 **출전한 유닛으로 제한**되는 것과 한 세트다. 한 번 고르면 그
## 3인방으로 끝까지 가야 하므로, 고르는 순간에 정보가 다 나와 있어야 한다.
static func curve(unit_id: String) -> String:
	return String(TABLE[unit_id].get("curve", "균형"))


static func curve_text(unit_id: String) -> String:
	return String(TABLE[unit_id].get("curve_text", ""))


## 곡선 이름에 대응하는 색. 초반형은 따뜻하게, 후반형은 차갑게.
static func curve_color(unit_id: String) -> Color:
	match curve(unit_id):
		"초반": return Color(1.0, 0.62, 0.35)
		"후반": return Color(0.55, 0.65, 1.0)
		"기복": return Color(0.85, 0.70, 1.0)
	return Color(0.60, 0.64, 0.74)


## 강화 1단계당 오르는 비율(%). 유닛·스탯마다 다르다 - 이게 파워 곡선을 만든다.
static func growth(unit_id: String, key: String) -> int:
	if key == "hp":
		return int(TABLE[unit_id].get("growth_hp", 100))
	if key == "atk":
		return int(TABLE[unit_id].get("growth_atk", 100))
	return 100


## 강화가 반영된 스탯. **전투와 UI 가 반드시 이 함수 하나만 봐야 한다.**
##
## 예전엔 Unit._scaled 와 RunState.upgraded_stat 두 곳에 같은 식을 적어 두고
## "반드시 같아야 한다" 는 주석으로 묶어 놨다. 성장 계수를 넣을 때 한쪽만 고쳐서
## 화면에 뜨는 수치와 실제 전투 수치가 어긋났다. 주석은 계약을 지켜 주지 않는다.
##
## 정수 연산만 쓴다. 부동소수점은 플랫폼별 오차로 결정론을 깰 수 있다.
## 곱셈을 나눗셈보다 먼저 해야 절삭이 두 번 일어나지 않는다.
static func scaled(unit_id: String, key: String, base: int, level: int) -> int:
	if level <= 0 or (key != "hp" and key != "atk"):
		return base
	return base + base * RunState.UPGRADE_STEP_PCT * level * growth(unit_id, key) / 10000


## 플레이어가 편성할 수 있는 유닛만. 훈련용 표적 같은 적 전용은 뺀다.
static func playable() -> Array[String]:
	var out: Array[String] = []
	for tid in TABLE.keys():
		if not bool(TABLE[tid].get("enemy_only", false)):
			out.append(String(tid))
	return out
