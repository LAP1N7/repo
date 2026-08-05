class_name Axes

## 전술 모듈의 네 축.
##
## ── 왜 축을 나누는가 ─────────────────────────────────────────────────────
## 예전에는 모듈 한 장이 조건과 행동을 다 들고 있었다. 그래서 모듈을 장착하는
## 행위가 "이 대원에게 동작 하나를 준다" 가 됐고, 플레이어가 조정하는 것은
## 어떤 동작이 먼저 나갈지뿐이었다. 그건 전술이 아니라 매크로 편집이다.
##
## 실제 전술은 동작을 고르는 게 아니라 **같은 동작을 언제·누구에게·어디서 할지를
## 정하는 원칙**이다. "공격한다" 는 전술이 아니고 "후열부터 친다" 가 전술이다.
##
## 그래서 모듈을 넷으로 가른다. 축이 다르면 서로 경쟁하지 않는다.
## 표적 모듈은 표적 모듈끼리만 자리를 다툰다.

const TARGET := "target"      ## 누구를 노리는가
const ENGAGE := "engage"      ## 지금 싸우는가
const POSITION := "position"  ## 어디에 서는가
const SQUAD := "squad"        ## 누구와 맞추는가

const ORDER: Array[String] = [TARGET, ENGAGE, POSITION, SQUAD]

## 화면 표기. 영문 축 라벨 + 한글 모듈명으로 적는다.
##
## 전부 영문으로 가면 이 게임의 한국어 톤과 충돌하고, 전부 한글이면 축이
## 안 보인다. 축만 영문으로 두면 계기판 느낌이 나면서 읽기는 그대로다.
const LABEL := {
	TARGET: "TARGET",
	ENGAGE: "ENGAGE",
	POSITION: "POSITION",
	SQUAD: "SQUAD",
}

const KO := {
	TARGET: "표적",
	ENGAGE: "교전",
	POSITION: "위치",
	SQUAD: "협력",
}

## 축별 강조색. 카드 외곽선과 슬롯 테두리에 쓴다.
## 채도를 낮게 잡는다 - 원색을 그대로 두르면 카드가 스무 장 깔린 상점에서
## 화면이 통째로 형광펜이 된다. (view/card_node.gd 의 _neon 주석 참조)
const COLOR := {
	TARGET: Color(0.95, 0.72, 0.30),    ## 호박
	ENGAGE: Color(0.92, 0.42, 0.42),    ## 적
	POSITION: Color(0.38, 0.80, 0.86),  ## 청록
	SQUAD: Color(0.52, 0.86, 0.52),     ## 녹
}


## 한 축이 이번 판단에서 내놓아야 하는 값의 이름.
##
##   target   -> pick    표적 선정자 (rules.resolve_target 의 이름)
##   engage   -> stance  이번 틱의 태세
##   position -> stand   어디에 설 것인가
##   squad    -> coop    아군을 어떻게 참조할 것인가
const PAYLOAD := {
	TARGET: "pick",
	ENGAGE: "stance",
	POSITION: "stand",
	SQUAD: "coop",
}


static func label(axis: String) -> String:
	return String(LABEL.get(axis, "?"))


static func color(axis: String) -> Color:
	return COLOR.get(axis, Color(0.7, 0.7, 0.7))
