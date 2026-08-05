class_name Threat

## 위협도 — 적이 누구를 칠지 정하는 값.
##
## ── 왜 필요했나 ──────────────────────────────────────────────────────────
## 예전에는 각 대원이 자기 규칙으로 독립적으로 표적을 골랐다. 그래서 "누가
## 맞고 있는가" 라는 개념이 게임 안에 아예 없었다.
##
## 그 결과 두 가지가 동시에 막혔다.
##   표현 - "방패병이 붙잡는 동안 원거리가 갉는다" 를 짤 방법이 없다
##   진단 - 궁수가 왜 죽었는지 알 수 없으니 다음에 뭘 고칠지도 모른다
##
## 포킹·희생·정석 같은 전술은 전부 "어그로를 누가 끄느냐" 에 달려 있는데,
## 그 축이 없으니 결국 모든 판이 닥돌 하나로 수렴했다.
##
## ── 규칙 ─────────────────────────────────────────────────────────────────
## 전부 정수 합산이고 난수는 없다. 같은 배치 + 같은 알고리즘 = 같은 결과가
## 이 프로젝트의 코어 계약이라, 위협도도 예외일 수 없다.
##
## 값은 **작게** 잡는다. 거리 하나로 다 정해지면 위협 관리가 무의미해지고,
## 반대로 도발이 너무 세면 다른 축이 다 죽는다. 도발(+35)이 4칸 거리를 뒤집는
## 정도가 지금 균형이다.

const BASE: int = 10
const PER_TILE: int = -2       ## 가까울수록 위협
const RECENT_HIT: int = 6      ## 직전 틱에 그 적을 때렸다
const WOUNDED: int = 4         ## HP 30% 이하 - 마무리하러 온다

## 태세가 붙이는 보정. core/rules.gd 가 unit.threat_mod 에 채운다.
const TAUNT: int = 35
const AGGRESSIVE: int = 20
const STEALTH: int = -15


## chooser 가 볼 때 candidate 가 얼마나 위협적인가.
static func score(chooser: Unit, candidate: Unit) -> int:
	var n := BASE
	n += Grid.manhattan(chooser.pos, candidate.pos) * PER_TILE
	if candidate.last_target != null and candidate.last_target.index == chooser.index:
		n += RECENT_HIT
	if candidate.hp_percent_below(30):
		n += WOUNDED
	n += candidate.threat_mod
	return n
