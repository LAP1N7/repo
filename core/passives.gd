class_name Passives

## 상시 효과. 보급에서만 나오는 고밸류 모듈이다.
##
## ── 왜 별도 층인가 ───────────────────────────────────────────────────────
## 표적·위치·교전 수칙은 전부 "이번 틱에 무엇을 할까" 를 정한다. 상시 효과는
## 그 판단에 개입하지 않고 **결과를 바꾼다.** 성격이 달라서 규칙 엔진에 섞으면
## 파이프라인이 지저분해진다.
##
## ── 왜 값이 매 틱 다시 계산되는가 ────────────────────────────────────────
## [응전](인접 아군 1명당 +8%)과 [기동대 장갑](인접 아군 0명일 때 방어 +3)은
## 진형이 바뀌면 값이 바뀐다. 전투 시작에 한 번 계산하면 대원이 흩어져도 값이
## 그대로 남아 화면과 실제가 어긋난다. Battle 이 틱마다 다시 채운다.

## 그 대원이 이 상시 효과를 들고 있는가.
static func has(unit: Unit, name: String) -> bool:
	for r in unit.card_rules:
		if String((r as Dictionary).get("passive", "")) == name:
			return true
	return false


## 인접한 살아 있는 아군 수. 응전·기동대 장갑·역장이 전부 이걸 본다.
static func adjacent_allies(unit: Unit, state) -> int:
	var n := 0
	for a in state.living_allies_of(unit):
		if a.index != unit.index and Grid.manhattan(unit.pos, a.pos) <= 1:
			n += 1
	return n


## 이번 틱의 공격 보정(%). 매 틱 Battle 이 불러 unit 에 채운다.
static func attack_pct(unit: Unit, state) -> int:
	var n := 0
	if has(unit, "assault"):
		n += 18
	if has(unit, "vigil"):
		n += 8 * adjacent_allies(unit, state)
	return n


## 이번 틱의 방어 보정. 정수 방어 단계로 더한다.
static func defend_bonus(unit: Unit, state) -> int:
	var n := 0
	if has(unit, "lone_armor") and adjacent_allies(unit, state) == 0:
		n += 3
	if has(unit, "vigil"):
		n += adjacent_allies(unit, state)
	return n


## 받는 피해 감소(%). 인접 아군이 [역장] 을 들고 있으면 깎인다.
static func damage_taken_pct(unit: Unit, state) -> int:
	var n := 0
	for a in state.living_allies_of(unit):
		if a.index != unit.index and Grid.manhattan(unit.pos, a.pos) <= 1 \
				and has(a, "aegis"):
			n -= 10
			break
	return n


## 부가 타격의 위력(%). 0이면 그 효과가 없다.
##
## 값을 100 밑으로 잡는 게 핵심이다. 범위 공격이 본체와 같은 위력이면 적이
## 뭉치는 판에서 그냥 3배 피해가 된다.
const SPLASH := {
	"scatter": 50,   ## 1칸 옆 하나 더 (원거리)
	"whirl": 60,     ## 적 방향 3칸 (근접)
	"bombard": 40,   ## 십자 (사거리 2 이상)
	"riposte": 45,   ## 피격 다음 틱, 인접 전원
}
