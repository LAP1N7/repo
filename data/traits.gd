class_name Traits

## 적 개체 특성 — 스테이지가 붙이는 성질.
##
## ── 왜 필요했나 ──────────────────────────────────────────────────────────
## 스테이지 다섯 개가 전부 "직업 조합만 다른 같은 판" 이었다. 적 구성표를
## 아무리 고쳐도 플레이어가 하는 일은 매번 똑같았다 - 붙어서 때린다.
##
## 판이 달라지려면 **적이 다른 규칙으로 존재해야** 한다. 안 움직이는 것,
## 죽으면서 터지는 것, 맞아 주는 것이 목적인 것. 그래야 "이 판은 어떻게
## 푸는가" 라는 질문이 판마다 다시 생긴다.
##
## ── 왜 모듈이 아니라 특성인가 ────────────────────────────────────────────
## 모듈은 플레이어가 사고 파는 물건이라 밸런스가 경제에 묶인다. 특성은 적에게만
## 붙고 값이 스테이지 표에 박혀 있어서, 판 하나를 어렵게 만드는 데 경제를 건드릴
## 필요가 없다.
##
## ── 결정론 ───────────────────────────────────────────────────────────────
## 전부 난수가 없다. 폭발 대상은 Grid.DIRS 순서로, 누적 계산은 index 순으로
## 돈다. 같은 배치면 같은 결과라는 계약은 여기서도 예외가 없다.

const IMMOBILE: String = "immobile"
const VOLATILE: String = "volatile"
const BEACON: String = "beacon"
const OVERSEER: String = "overseer"
const ZEALOT: String = "zealot"

## 폭발 피해. 자신을 중심으로 한 **3x3 아홉 칸**이 적아 구분 없이 맞는다.
##
## 인접 4칸이던 것을 넓혔다. 4칸 폭발은 대각선으로 한 칸만 비켜 서면 통째로
## 피할 수 있어서, 자폭체가 "붙기 전에 잡으면 끝" 인 그냥 약한 적이었다.
## 3x3 이면 붙은 순간 주변이 전부 위험해지고, 그때 비로소 **어디서 잡을지**가
## 문제가 된다.
##
## 구분을 두지 않는 이유: "적 자폭체 옆에 적이 서 있어도 안전" 이 되면
## 플레이어가 몰아 놓고 터뜨리는 그림이 안 나온다.
const VOLATILE_DAMAGE: int = 15

## 붙고 나서 터지기까지의 틱. 붙으면 도화선에 불이 붙는다.
##
## ── 왜 도화선이 필요한가 ─────────────────────────────────────────────────
## 죽을 때만 터지면 이 개체를 다루는 답이 "안 잡고 방치" 하나로 끝난다. 실제로
## 그게 최적해였다 - 무시하면 공격력 10짜리 잡몹이다.
##
## 붙으면 3틱 뒤에 스스로 터진다. 그러면 선택이 생긴다. 3틱 안에 죽여서 폭발을
## 내가 고른 자리에서 받을 것인가, 물러나서 도화선을 끊을 것인가.
const FUSE_TICKS: int = 3

## 유인 장치가 스스로 올리는 위협도.
##
## 도발(+35)의 두 배다. 기본 표적 판단이 위협도를 보므로, 모듈이 없는 대원은
## 이걸 무조건 먼저 친다. 그게 이 개체의 존재 이유다 - **표적 모듈을 안 산
## 대가를 판이 직접 청구한다.**
##
## HP 를 낮게 준다(units.gd 참조). 못 부수는 벽이 아니라 한 박자를 뺏는
## 장치여야 한다. 두꺼우면 그냥 짜증이다.
const BEACON_THREAT: int = 70

## 감독기가 살아 있는 동안 같은 팀 전체가 받는 공격력 보정(%p).
##
## 죽이면 사라진다. "먼저 끊어야 할 적" 이 판 위에 명시적으로 존재하게 만드는
## 장치다. 25 는 체감되되 감독기만 잡으면 이기는 수준은 아닌 값이다.
const OVERSEER_ATK_PCT: int = 25

## 같은 팀이 하나 죽을 때마다 오르는 공격력(%p)과 그 상한 단계.
##
## 감독기와 방향이 반대다. 감독기는 "먼저 끊어라", 광신도는 "빨리 끝내라".
## 둘을 같은 판에 놓으면 순서 판단이 실제로 어려워진다.
const ZEALOT_ATK_PCT: int = 14
const ZEALOT_MAX_STACK: int = 4


static func has(u: Unit, name: String) -> bool:
	return u != null and u.traits.has(name)


## u 가 이번 틱에 받는 특성 공격력 보정(%p). Battle 이 틱마다 다시 채운다.
##
## 매 틱 다시 세는 이유는 감독기가 죽고 광신도 누적이 늘기 때문이다. 한 번
## 계산해 두면 감독기를 끊었는데 적이 계속 세게 때리는, 설명 불가능한 판이 된다.
static func attack_pct(u: Unit, state) -> int:
	var n: int = 0
	var overseer := false
	var dead_allies: int = 0
	for other in state.units:
		if other.team != u.team:
			continue
		if other.alive and has(other, OVERSEER):
			overseer = true
		if not other.alive:
			dead_allies += 1
	if overseer:
		n += OVERSEER_ATK_PCT
	if has(u, ZEALOT):
		n += ZEALOT_ATK_PCT * mini(dead_allies, ZEALOT_MAX_STACK)
	return n


## 화면에 한 줄로 띄울 설명. 편성 전 적 정보에 그대로 쓴다.
##
## 숨기면 시행착오 게임이 되고 공개하면 추리 게임이 된다는 원칙(DESIGN 2.4)은
## 적 알고리즘만이 아니라 특성에도 그대로 적용된다.
const TEXT: Dictionary = {
	IMMOBILE: "고정 - 절대 움직이지 않는다",
	VOLATILE: "자폭 - 붙으면 %d틱 뒤 폭발. 주위 3x3 에 %d 피해 (적아 무관)" % [
		FUSE_TICKS, VOLATILE_DAMAGE],
	BEACON: "유인 - 위협도 +%d. 표적 모듈이 없으면 여기부터 친다" % BEACON_THREAT,
	OVERSEER: "감독 - 살아 있는 동안 같은 편 공격 +%d%%" % OVERSEER_ATK_PCT,
	ZEALOT: "광신 - 같은 편이 죽을 때마다 공격 +%d%% (최대 %d회)" % [
		ZEALOT_ATK_PCT, ZEALOT_MAX_STACK],
}


static func describe(name: String) -> String:
	return String(TEXT.get(name, name))
