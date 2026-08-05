class_name HelpScreen
extends Control

## 게임 방법. (DESIGN D6)
##
## 이 화면은 장식이 아니다. 플레이 중 반복해서 나온 질문이 전부 여기 있다:
##   "내 전술이 뭘 하고 있는지 모르겠다"
##   "궁수는 거리 유지 못 하면 영원히 못 때리나"
##   "한 턴에 몇 번 움직이나"
## 규칙을 숨기면 시행착오 게임이 되고, 공개하면 추리 게임이 된다.

signal back()

## const 로 둘 수 없다. 문구를 data/ui_text.json 에서 읽어야 하는데
## const 는 함수 호출을 못 한다. 부를 때마다 만든다 - 이 화면은 한 번만 뜬다.
static func sections() -> Array[Dictionary]:
	return [
		{
			"head": UiText.t("help.m01", "1 · 전투는 자동이다"),
			"body": UiText.t("help.m02", "전투가 시작되면 개입할 수 없다. 플레이어가 정하는 것은 유닛의 판단 기준뿐이다.\n")
				+ UiText.t("help.m03", "1틱에 유닛 한 명은 정확히 한 행동만 한다 - 이동이든 공격이든 하나다.\n")
				+ UiText.t("help.m04", "유닛은 정해진 순서(아군 먼저)로 하나씩 처리된다. 난수는 전혀 쓰지 않는다.\n")
				+ UiText.t("help.m05", "60틱 안에 끝내지 못하면 무승부로 패배 처리된다."),
		},
		{
			"head": UiText.t("help.m06", "2 · 규칙은 위에서부터 읽는다"),
			"body": UiText.t("help.m07", "매 틱, 유닛은 자기 규칙을 1 → 2 → 3 순서로 훑어 실행할 규칙 하나를 고른다.\n")
				+ UiText.t("help.m08", "조건이 참이고 **그 행동이 실제로 가능해야** 발동한다. 하나라도 안 되면 다음 줄로 내려간다.\n")
				+ UiText.t("help.m09", "   예) '항상 → 가장 가까운 적 공격' 은 사거리 밖이면 실행 불가라 아래로 양보한다.\n")
				+ UiText.t("help.m10", "그래서 같은 카드라도 순서를 바꾸면 유닛의 성격이 완전히 달라진다. 이게 이 게임의 전부다."),
		},
		{
			"head": UiText.t("help.m11", "3 · 위 카드가 아래 카드를 가릴 수 있다"),
			"body": UiText.t("help.m12", "슬롯 1의 조건이 헐거우면 슬롯 2·3 은 영영 발동하지 못한다.\n")
				+ UiText.t("help.m13", "   예) 궁수에게 [1 저격, 2 거리 유지] - 저격 조건이 '적이 사거리 안' 이라\n")
				+ UiText.t("help.m14", "        적이 들어오는 순간 항상 참이 되고, 거리 유지는 한 번도 발동하지 못한다.\n")
				+ UiText.t("help.m15", "편성 화면이 이런 카드를 빨갛게 칠하고 경고한다. 순서를 바꾸면 풀린다."),
		},
		{
			"head": UiText.t("help.m16", "4 · 기본기는 맨 아래에 깔려 있다"),
			"body": UiText.t("help.m17", "카드가 하나도 없어도 유닛은 멍하니 서 있지 않는다.\n")
				+ UiText.t("help.m18", "모든 유닛 공통: 사거리 안이면 공격(위력 85%), 사거리 밖이면 접근.\n")
				+ UiText.t("help.m19", "여기에 직업마다 고유 기본기가 하나씩 더 붙는다.\n")
				+ UiText.t("help.m20", "기본기는 산 카드보다 **아래**에 있다. 즉 카드는 기본 행동을 덮어쓰는 상위 규칙이다.\n")
				+ UiText.t("help.m21", "기본기는 일부러 약하다 - 그래야 값을 치른 카드가 값을 한다."),
		},
		{
			"head": UiText.t("help.m22", "5 · 특수 스킬과 우선순위"),
			"body": UiText.t("help.m23", "특수는 규칙 3칸과 별개인 전용 칸에 꽂는다. 직업 전용이고 쿨다운이 있다.\n")
				+ UiText.t("help.m24", "편성 화면에서 '전술 먼저 / 특수 먼저' 를 직접 정한다.\n")
				+ UiText.t("help.m25", "   전술 먼저(기본) - 카드가 전부 어긋날 때만 특수가 나온다\n")
				+ UiText.t("help.m26", "   특수 먼저      - 준비되면 즉시 터진다. 대신 그 틱의 카드는 전부 무시된다"),
		},
		{
			"head": UiText.t("help.m27", "6 · 몸이 사선을 막는다"),
			"body": UiText.t("help.m28", "원거리 공격은 나와 대상 사이에 **적 유닛**이 서 있으면 나가지 않는다.\n")
				+ UiText.t("help.m29", "아군은 사선을 막지 않는다 - 내 방패병이 내 궁수를 가리지는 않는다.\n")
				+ UiText.t("help.m30", "그래서 앞에 벽을 세우면 내 후열이 보호되고, 적의 벽은 적의 후열을 지킨다.\n")
				+ UiText.t("help.m31", "관통사격만은 예외로 몸을 뚫는다. 그게 그 스킬의 값어치다."),
		},
		{
			"head": UiText.t("help.m32", "7 · 런 진행"),
			"body": UiText.t("help.m33", "1단계 덱 구성 → 2단계 편성과 배치 → 3단계 전투 → 보상 → 다음 스테이지.\n")
				+ UiText.t("help.m34", "스테이지를 넘어가도 **덱 · 유닛 강화 · 정제권 · 누적 예산은 남는다.**\n")
				+ UiText.t("help.m35", "편성과 상점 목록만 매번 새로 짠다.\n")
				+ UiText.t("help.m36", "승리 보상은 셋 중 하나만 고른다 - 유닛 강화 / 희귀 카드 / 예산+정제권.\n")
				+ UiText.t("help.m37", "정제권은 손패에서 카드를 영구히 버릴 때 쓴다. 덱이 두꺼워지면 원하는 카드가 덜 나온다."),
		},
	]


func setup() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = UiKit.BG
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	UiKit.label(self, Vector2(48, 24), Vector2(600, 36), UiText.t("title.help", "게임 방법"), 28)

	var b := UiKit.button(self, Vector2(1060, 28), Vector2(180, 40), UiText.t("help.m38", "←  돌아가기"), 15)
	b.pressed.connect(func(): back.emit())

	# 7개 절을 2열로 나눈다. 한 열에 다 넣으면 스크롤이 필요해진다.
	var col_x := [48.0, 664.0]
	var col_y := [76.0, 76.0]
	for i in sections().size():
		var c := 0 if i < 4 else 1
		var sec: Dictionary = sections()[i]

		UiKit.label(self, Vector2(col_x[c], col_y[c]), Vector2(560, 24),
			String(sec["head"]), 16, UiKit.ACCENT)
		col_y[c] += 24.0

		var body := UiKit.label(self, Vector2(col_x[c] + 4, col_y[c]), Vector2(560, 200),
			String(sec["body"]), 12, UiKit.TEXT)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# 줄 수로 높이를 잡는다. 고정 높이로 두면 절끼리 겹친다.
		var lines := String(sec["body"]).count("\n") + 1
		var h := lines * 17.0 + 10.0
		body.size = Vector2(560, h)
		col_y[c] += h + 14.0
