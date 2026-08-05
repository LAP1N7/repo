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


## 한 일이 쌓여 만드는 위협. 누적 피해·회복의 이 비율만큼이 위협이 된다.
##
## 이게 없으면 위협은 거리 하나로만 정해지고, 딜을 아무리 넣어도 어그로가 안
## 끌린다. "탱커가 관리 안 하면 딜러가 어그로를 뺏긴다" 는 감각이 여기서 나온다.
const PER_WORK: int = 100        ## 누적 100당 위협 1

## 표적을 바꾸는 데 필요한 초과분(%).
##
## ── 왜 마진이 필요한가 ───────────────────────────────────────────────────
## 1이라도 높으면 바로 갈아타면, 두 대원의 위협이 엎치락뒤치락하는 동안 적이
## 매 틱 표적을 바꾸며 제자리에서 떤다. 화면에서는 아무 일도 안 일어나고
## 플레이어는 왜 그러는지 알 수 없다.
##
## 25% 를 넘어야 갈아탄다. 그래서 도발은 "확실히 크게" 끌어야 의미가 있고,
## 딜러가 어그로를 뺏으려면 정말 많이 때려야 한다.
const SWITCH_MARGIN: int = 125


## chooser 가 볼 때 candidate 가 얼마나 위협적인가.
static func score(chooser: Unit, candidate: Unit) -> int:
	var n := BASE
	n += Grid.manhattan(chooser.pos, candidate.pos) * PER_TILE
	if candidate.last_target != null and candidate.last_target.index == chooser.index:
		n += RECENT_HIT
	if candidate.hp_percent_below(30):
		n += WOUNDED
	n += candidate.threat_mod
	# 한 일이 쌓인 만큼. 딜을 많이 넣은 대원이 결국 맞게 된다.
	n += (candidate.damage_dealt + candidate.healing_done) / PER_WORK
	return n
