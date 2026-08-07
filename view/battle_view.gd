class_name BattleScreen
extends Node2D

## 3단계 - 전투. 여기서는 아무것도 조작하지 않는다. 결과만 본다.
##
## Battle(코어)은 이 파일을 전혀 모른다. battle.step() 을 한 틱씩 돌리고 그 틱에
## 쌓인 이벤트를 순서대로 재생할 뿐이다. 연출을 아무리 바꿔도 전투 결과는 안 변한다.

signal to_loadout()
signal to_shop()
signal won()

## 튜토리얼이 붙어 있으면 앵커를 등록하고 행동을 알린다.
var tut: Tutorial = null

## 판을 그리는 배율. 좌표계(타일 64px)는 그대로 두고 보이는 크기만 키운다.
##
## 이렇게 하면 Grid 의 거리·경로 계산이 한 줄도 안 바뀐다. 타일 크기 자체를
## 키우면 BOARD_ORIGIN 을 쓰는 모든 자리와 뷰의 픽셀 상수를 전부 다시 재야 한다.
## 8x6 타일 x 64px = 512x384 가 원래 크기다. 1.42배로 키웠더니 판이 세로
## 545px 이 되어 화면 아래 조작줄까지 내려왔다. 1.15 면 589x442 로, 왼쪽 절반을
## 채우면서 아래에 대원 바 자리를 남긴다.
## 판 세로가 대원 바를 넘으면 안 된다. 6행 x 64 x 배율 + 상단 104 가 바의
## y(560)보다 작아야 한다. 1.30 은 603 이라 바를 덮었다.
## 판이 화면의 3분의 2를 차지해야 한다. 가로 8칸 x 64px x 배율이 1280 의
## 2/3(853) 근처여야 하므로 1.63 쯤이지만, 그러면 세로가 626 이 되어 하단
## 대원 바를 덮는다. 세로가 한계라 1.36 으로 맞추고(가로 696 · 세로 522)
## 오른쪽 정보 열을 그만큼 좁힌다.
## 한 칸의 화면 크기. **정사각형이 아니다.**
##
## ── 왜 가로로 긴가 ───────────────────────────────────────────────────────
## 예전에는 판 전체에 균등 배율을 걸었다. 그러면 가로를 키우는 만큼 세로도
## 커지는데, 세로는 하단 대원 바 때문에 상한이 있어서 가로까지 같이 묶였다.
## 결국 판이 화면의 절반을 못 넘겼다.
##
## 칸을 정사각형으로 둘 이유가 없다. 가로만 크게, 세로는 필요한 만큼만 잡으면
## 8열 x 6행이 화면의 3분의 2(848px)를 채우면서 세로는 486px 로 남는다.
##
## 거리 계산은 맨해튼이라 **픽셀 비율과 무관하다.** 한 칸 이동은 화면에서
## 가로로 106px, 세로로 81px 이지만 규칙상으로는 똑같이 1칸이다.
## 게임 규칙은 한 줄도 안 바뀐다.
## 좌우를 조금 좁혀 칸 사이가 붙어 보이게 한다. 8열이 나란히 설 때 칸이
## 너무 넓으면 격자가 아니라 표처럼 읽힌다.
## ── 칸은 발판이다 ────────────────────────────────────────────────────────
## 칸이 98x81 이고 대원이 74 였다. 대원이 칸 **안에** 얌전히 들어가 있으니
## 격자가 주인공이고 대원이 장식처럼 보였다. 판을 봐도 누가 어디 있는지가
## 한눈에 안 들어왔다.
##
## 명일방주는 반대다. 칸은 작고, 오퍼레이터는 그 칸을 **밟고 서서** 위로
## 넘친다. 그래서 시선이 칸이 아니라 사람에게 간다.
##
## 가로를 줄이고 세로를 더 줄였다. 대원(74)이 칸 높이(64)보다 크므로 자연히
## 칸 위로 올라선다. 맨해튼 거리는 칸 수로 세므로 규칙은 하나도 안 바뀐다.
const TILE_W: float = 78.0
const TILE_H: float = 64.0

## 판이 좁아진 만큼 왼쪽 영역(36~820) 안에서 가운데로 민다.
const BOARD_ORIGIN := Vector2(116, 128)
const TILE: int = Grid.TILE
## ── 한 동작에 주는 시간 ──────────────────────────────────────────────────
## 0.22초였다. 걷기 한 사이클을 그 안에 욱여넣으니 다리가 두 번 깜빡이고 끝나서,
## 애니메이션을 넣어도 움직임이 안 보였다. 리그를 여섯 개 만든 값이 화면에
## 하나도 안 나타나는 상태였다.
##
## 1초가 기준이다. 걷기도 공격도 한 동작이 온전히 보인다.
##
## 대신 기본 배속을 2배로 둔다. 1초 x 여섯 대원이면 한 틱이 6초라 처음 보는
## 사람에게는 느리다. 2배(0.5초)가 "보이면서 답답하지 않은" 지점이고, 자세히
## 보고 싶으면 1x 를, 결과만 보고 싶으면 4x 를 누르면 된다.
const ACT_TIME: float = 1.0

## ── 배속에 8x 를 더한다 ──────────────────────────────────────────────────
## 한 동작을 1초로 늘리면서 4x 가 예전 1x(0.22초)보다도 느려졌다. 배속 단추가
## 셋 다 "느림 / 덜 느림 / 조금 덜 느림" 이 된 셈이다 - 고장은 아니지만 쓸모가
## 없어졌고, 쓸모가 없으면 고장난 것과 같다.
##
## 1x 는 동작을 보는 자리, 8x 는 결과만 보는 자리다. 양 끝이 다 필요하다.
const SPEEDS: Array[float] = [1.0, 2.0, 4.0, 8.0]

## 규칙 패널 한 유닛이 차지하는 높이와 한 줄 높이.
## ROW_H = 헤더 22 + 5줄 × ROW_LINE. 줄이면 다음 유닛 헤더를 덮는다.
const ROW_LINE: float = 18.0
const ROW_H: float = 112.0

## 기여도 막대와 숫자가 쓰는 폭. 오른쪽 끝(x=1264)에 붙는다.
const CONTRIB_W: float = 176.0

## ── 오른쪽 열 배치 ───────────────────────────────────────────────────────
## 판은 x 36~820 을 쓴다. 그 오른쪽이 정보 열이다.
## 로그에 남기는 줄 수. 패널이 좁아지면서 일곱 줄은 넘쳤다.
const LOG_LINES: int = 200

## 진영 색. 로그·표적선·전황판이 전부 이 둘만 쓴다.
const COL_ALLY := Color(0.45, 0.80, 1.0)
const COL_FOE := Color(1.0, 0.45, 0.42)

## 판 위 동그라미의 반지름. 화살표가 몸통을 피해 가려면 이 값을 알아야 한다.
const UNIT_R: float = 34.0

## 호버로 잡히는 반경. 칸(98x81)보다 조금 작게 잡아 옆 칸을 안 먹게 한다.
const HOVER_R: float = 38.0

const ROSTER_X: float = 900.0
const COL_W: float = 340.0
## 전황판 높이. 대원 셋 x 66 + 머리말.
const ROSTER_H: float = 268.0
## 기록 패널. [보급 수령](y 596) 바로 위에서 끝난다.
## 기록 패널의 아래끝을 **판 아래끝(y 586)과 맞춘다.**
## 오른쪽 열의 아래끝이 판과 다르면 화면 아래에 계단이 하나 생긴다 - 정렬은
## 장식이 아니라 "이 둘이 같은 층이다" 를 말하는 문법이다.
const LOG_Y: float = 386.0
const LOG_H: float = 178.0
## 기록 글이 쓰는 폭. 나머지는 판단 표가 쓴다.
const LOG_TEXT_W: float = 186.0

const COL_TILE_A := Color(0.16, 0.17, 0.22)
const COL_TILE_B := Color(0.13, 0.14, 0.19)

## 지형 사진의 진하기.
##
## ── 왜 사진을 칸 **위에** 얹는가 ─────────────────────────────────────────
## 처음에는 사진을 깔고 칸을 반투명으로 덮었다. 결과는 판 전체가 균일한 회색
## 판이었다 - 어두운 칸 색이 사진을 뿌옇게 덮으면서 도로도 경계선도 다 뭉갰고,
## 판이 UI 보다 밝아져 격자선까지 안 읽혔다. 배경을 넣었는데 배경은 안 보이고
## 원래 있던 것만 나빠졌다.
##
## 순서를 뒤집으면 둘 다 산다. 칸은 예전 그대로 불투명하게 깔아 판의 어둡기와
## 체크무늬를 지키고, 사진은 그 위에 옅게 얹어 무늬만 더한다. 얹는 쪽이 옅으면
## 어두운 칸은 어둡게 남고 사진의 선만 살짝 비친다.
##
## 0.30 이면 도로와 구획선이 보이되 유닛·어그로선을 방해하지 않는다.
## 0.30 으로 시작했다가 올렸다. 사진이 이미 어두워서, 그 위에 30% 로만 얹으면
## 무늬의 진폭이 다시 3분의 1로 줄어 도로도 자재 더미도 안 보였다. 사진 쪽을
## 더 어둡게 굽고(가장 밝은 곳 72/255) 얹는 비율을 올리는 편이 맞다 -
## 판은 여전히 어둡고 무늬만 살아난다.
const COL_PLAYER_ZONE := Color(0.25, 0.5, 0.8, 0.15)
const COL_ENEMY_ZONE := Color(0.8, 0.3, 0.28, 0.15)

enum Phase { READY, PLAYING, RESULT }

var run: RunState
var battle: Battle
var speed: float = 2.0
var phase: int = Phase.READY
var run_id: int = 0

var font: Font

## 효과음. 화면마다 하나씩 만들고, 음소거·볼륨만 Sfx 의 정적 변수로 공유한다.
## (AudioStreamPlayer 는 트리에 들어가 있어야 소리가 나서 화면 자식으로 둔다)
var sfx: Sfx
var btn_sound: Button
var board: Node2D
var fx: Node2D
var ui: Control
var unit_views: Array[UnitView] = []
## 판 뒤에 까는 지형 사진과, 그 위에 그리는 층.
var overlay: Control
## 유닛보다 위에 그리는 층. 호버 정보가 여기 산다.
var top_layer: Control

var lbl_stage: Label
var lbl_tick: Label
var lbl_status: Label
var btn_start: Button
var btn_next: Button
var speed_buttons: Array[Button] = []
var result_panel: Control
var lbl_result: Label
var lbl_result_sub: Label
## 하단 대원 바. 얼굴 · HP · 기여도가 여기 산다.
var squad_root: Control

## 판 아래 왼쪽의 적 개요 판.
var brief_panel: Control

## 대원별 카드 노드. unit index -> _SquadCard
var squad_cards: Dictionary = {}

var rules_root: Control

## 이번 틱의 판단 네 줄이 뜨는 곳. (_show_trace 주석 참조)
var trace_root: Control

## 규칙 슬롯 줄의 배경판. 방금 발동한 슬롯을 밝혀서 "어느 규칙이 지금 터졌는지" 를
## 목록 위에서 직접 짚어 준다. key: "%d:%d" % [유닛번호, 슬롯번호] (기본기는 슬롯 -1)
var slot_rows: Dictionary = {}

## 대원별 기여도 막대. unit index -> { "bar": ColorRect, "label": Label }
##
## 롤토체스처럼 "누가 실제로 일했는가" 를 한눈에 보여 준다. 이 게임은 조작이
## 없으므로 전투가 끝난 뒤 남는 질문이 "내 알고리즘이 통했는가" 하나뿐인데,
## 로그를 한 줄씩 세는 것 말고는 답할 방법이 없었다.
var contrib_rows: Dictionary = {}

## 전투 로그. 무슨 일이 왜 일어났는지 글로 남는다.
var log_root: Control
var log_lines: Array[String] = []
var log_label: RichTextLabel
## 오른쪽 위 전황판. 우리 셋과 그들을 노리는 적을 한 자리에서 보여 준다.
var roster_root: Control
## 지금 마우스가 올라간 판 위의 대원. 없으면 null.
var hover_unit: Unit = null
## 마지막 판인가. 곡을 가른다.
var _boss_music: bool = false

## 전황판의 회색 네모 위에 마우스가 올라갔을 때 그 적. 판에서 아무것도 안
## 잡혔을 때만 쓴다 - 전황판에서 짚어도 **판 위에서** 정체가 뜨게 하려는 것이다.
var roster_hover: Unit = null


func setup(p_run: RunState) -> void:
	sfx = Sfx.new()
	_boss_music = p_run != null and Stages.is_last(p_run.stage_id)
	add_child(sfx)
	run = p_run
	# UnitView 가 이 폰트로 머리 위 규칙 칩(12px)과 이름을 그린다. 둘 다 작은 글씨다.
	font = UiKit.font(UnitView.CHIP_SIZE)

	# ── 판은 네 겹이다 ───────────────────────────────────────────────────
	#   _draw()      바탕 + 칸
	#   overlay      진영 · 표적선 · 포격 예고 · 격자선
	#   board        유닛
	#   top_layer    호버 정보 (유닛보다 위)
	#
	# ── 지형 사진은 뺐다 ─────────────────────────────────────────────────
	# 항공 사진을 깔면 판이 "어떤 땅 위" 로 읽혀서 좋았지만, 그 위에 표적선과
	# 이동 경로와 포격 예고가 겹치자 어느 선이 무엇인지 구별이 안 됐다.
	# 판에서 읽어야 하는 것은 지형이 아니라 **누가 누구에게 가는가** 다.
	# 배경이 그걸 이기면 배경이 틀린 것이다. (assets/art/bg 는 남겨 둔다)

	overlay = _Overlay.new()
	overlay.view = self
	overlay.size = Vector2(1280, 720)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	board = Node2D.new()
	board.position = BOARD_ORIGIN
	# 세로로 긴 스프라이트는 위 칸을 침범한다. Y 정렬을 켜면 화면 아래쪽 유닛이
	# 항상 앞에 그려져서 앞줄이 뒷줄을 가리는 올바른 겹침이 나온다.
	board.y_sort_enabled = true
	add_child(board)

	fx = Node2D.new()
	fx.position = BOARD_ORIGIN
	# 터짐 효과는 유닛보다 위다. 유닛 뒤에서 터지면 무슨 일이 났는지 안 보인다.
	fx.z_index = 120
	add_child(fx)
	_build_ui()
	_reset()

	# ── 마지막 판만 곡이 다르다 ──────────────────────────────────────────
	# 다섯 판이 전부 같은 곡이면 마지막 판도 그냥 여섯 번째 교전으로 들린다.
	# 곡이 바뀌는 순간 "여기가 끝" 이 규칙보다 먼저 전해진다.
	#
	# 편성으로 돌아갔다 와도 다시 시작하지 않는다 - play_music 이 같은 곡이면
	# 아무것도 안 한다.
	sfx.play_music("boss_theme" if _boss_music else "opening_theme")

	# 개발용 훅. 무인 재생으로 프레임을 뽑아 백업 영상을 찍을 때 쓴다. (DESIGN D4)
	#   GG_SPEED=2      배속
	#   GG_AUTOSTART=1  화면이 뜨자마자 전투 시작
	if OS.get_environment("GG_SPEED") != "":
		speed = float(OS.get_environment("GG_SPEED"))
		_refresh_ui()
	if OS.get_environment("GG_AUTOSTART") == "1":
		_start_battle()


# ── 그리기 ───────────────────────────────────────────────────────────────

## 어그로 선과 포격 예고는 매 틱 바뀐다. 오버레이만 다시 그린다 -
## 바탕과 칸은 안 바뀌므로 부모까지 다시 칠할 이유가 없다.
func _process(_delta: float) -> void:
	# ── 판 위에서 마우스가 올라간 대원 ───────────────────────────────────
	# 명일방주처럼 판 위의 개체에 마우스를 올리면 그 자리에서 정체를 밝힌다.
	# 하단 바는 내 대원 셋만 보여 준다 - 적이 무엇인지 물어볼 데가 화면에
	# 아무 데도 없었고, 그건 "적 알고리즘을 공개한다" 는 원칙과 정면으로
	# 어긋난다.
	# ── 칸이 아니라 **그려진 자리**로 잡는다 ─────────────────────────────
	# 마우스 좌표를 칸으로 바꿔 pos 와 비교했더니, 이동 연출 중에는 아직 오지
	# 않은 칸이 반응하고 정작 대원이 서 있는 자리는 반응하지 않았다.
	# 화면에서 보이는 것을 가리키면 그것이 잡혀야 한다.
	hover_unit = null
	if battle != null:
		var m := get_local_mouse_position()
		var best := HOVER_R
		for u in battle.units:
			if not _shown_alive(u):
				continue
			var d := m.distance_to(_live_pos(u))
			if d < best:
				best = d
				hover_unit = u
	# 판에서 아무것도 안 잡혔으면 전황판이 가리키는 적을 쓴다.
	if hover_unit == null:
		hover_unit = roster_hover
	if overlay != null:
		overlay.queue_redraw()


## 판 위에 그리는 층. _draw_overlay 를 그대로 부른다.
class _Overlay extends Control:
	var view

	func _draw() -> void:
		if view != null:
			view._draw_overlay(self)


## 유닛보다 **위**에 그리는 층. 호버 정보 전용이다.
##
## 개체 위에 마우스를 올려 여는 창이 그 개체에 가리면 앞뒤가 안 맞는다.
class _TopLayer extends Control:
	var view

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if view != null:
			view._draw_arrows(self)
			# 범위의 경계는 화살표보다 **위**다. 아래에 그렸더니 굵은 화살표가
			# 지나가며 경계를 끊어 놓아서, 어디까지가 위험한지 안 읽혔다.
			view._draw_zones(self, true)
			view._draw_hover(self)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), UiKit.BG)

	for y in Grid.H:
		for x in Grid.W:
			draw_rect(Rect2(BOARD_ORIGIN + Vector2(x * TILE_W, y * TILE_H),
				Vector2(TILE_W, TILE_H)),
				COL_TILE_A if (x + y) % 2 == 0 else COL_TILE_B)


## 판 **위에** 그리는 것들. _Overlay 가 매 프레임 이 함수를 부른다.
##
## 예전에는 전부 _draw 안에 있었다. 지형이 노드가 되면서 자식이 부모보다 나중에
## 그려지므로, 여기 있던 것들을 그대로 두면 사진이 격자선을 덮어 버린다.
func _draw_overlay(c: CanvasItem) -> void:
	# ── 배율은 위치와 크기 **둘 다**에 걸어야 한다 ───────────────────────
	# 진영 표시만 크기에 배율을 안 걸어서, 칸은 74px 인데 표시는 64px 로 그려져
	# 반 칸씩 밀린 것처럼 보였다. 유닛이 어긋난 게 아니라 이 사각형이 어긋난
	# 것이었다 - 눈에는 똑같이 "격자와 안 맞는다" 로 보인다.
	var cell := Vector2(TILE_W, TILE_H)
	for p in Grid.PLAYER_SLOTS:
		c.draw_rect(Rect2(BOARD_ORIGIN + Vector2(p.x * TILE_W, p.y * TILE_H),
			cell), COL_PLAYER_ZONE)
	for p in Grid.ENEMY_SLOTS:
		c.draw_rect(Rect2(BOARD_ORIGIN + Vector2(p.x * TILE_W, p.y * TILE_H),
			cell), COL_ENEMY_ZONE)

	_draw_zones(c)

	# ── 포격 예고 ────────────────────────────────────────────────────────
	# 한 틱 뒤에 떨어질 칸을 미리 밝힌다. 예고가 없으면 그건 난수와 구별되지
	# 않는다 - 플레이어는 알고리즘을 짜 두고 결과를 보는 입장이라, 화면이
	# 먼저 말해 주지 않으면 편성이 나빴는지 운이 나빴는지 영영 모른다.
	if battle != null and not battle.hazard_cells.is_empty():
		var pulse: float = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 90.0)
		for cc in battle.hazard_cells:
			var r := Rect2(BOARD_ORIGIN + Vector2(cc.x * TILE_W, cc.y * TILE_H),
				Vector2(TILE_W, TILE_H))
			c.draw_rect(r, Color(1.0, 0.26, 0.20, 0.12 + 0.20 * pulse))
			c.draw_rect(r, Color(1.0, 0.45, 0.32, 0.55 + 0.45 * pulse), false, 2.0)
			# 빗금. 깜빡임만으로는 정지 화면에서 안 읽힌다.
			var step := 14.0
			var d := -r.size.y
			while d < r.size.x:
				var x0: float = r.position.x + maxf(d, 0.0)
				var y0: float = r.position.y + maxf(-d, 0.0)
				var run_len: float = minf(r.size.x - maxf(d, 0.0),
					r.size.y - maxf(-d, 0.0))
				if run_len > 0.0:
					c.draw_line(Vector2(x0, y0), Vector2(x0 + run_len, y0 + run_len),
						Color(1.0, 0.40, 0.28, 0.22), 2.0)
				d += step

	if battle != null:
		# 지금 적이 가장 많이 노리는 아군에게 고리를 씌운다.
		# 막대(위협)와 판(고리)이 같은 것을 가리켜야 "내가 어그로를 관리하고
		# 있다" 가 성립한다.
		var most: Unit = null
		var most_n := 0
		for u in battle.units:
			if not u.alive or u.team != Unit.TEAM_PLAYER:
				continue
			var n := 0
			for e2 in battle.units:
				if e2.alive and e2.team == Unit.TEAM_ENEMY and e2.last_target == u:
					n += 1
			if n > most_n:
				most_n = n
				most = u
		if most != null:
			var pc := BOARD_ORIGIN + Vector2(most.pos.x * TILE_W + TILE_W * 0.5,
				most.pos.y * TILE_H + TILE_H * 0.5)
			var pulse2: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 220.0)
			c.draw_arc(pc, TILE_W * 0.42, 0.0, TAU, 28,
				Color(1.0, 0.42, 0.38, 0.30 + 0.35 * pulse2), 2.0)

	for x in Grid.W + 1:
		c.draw_line(BOARD_ORIGIN + Vector2(x * TILE_W, 0),
			BOARD_ORIGIN + Vector2(x * TILE_W, Grid.H * TILE_H), UiKit.LINE, 1.0)
	for y in Grid.H + 1:
		c.draw_line(BOARD_ORIGIN + Vector2(0, y * TILE_H),
			BOARD_ORIGIN + Vector2(Grid.W * TILE_W, y * TILE_H), UiKit.LINE, 1.0)



## ── 범위 공격이 닿는 칸 ──────────────────────────────────────────────────
## 자폭체가 어디까지 터지는지, 총사 궁극기가 어디를 쓸어 담는지가 화면에 없었다.
## "붙기 전에 잡아라" 도 "저 칸을 비켜라" 도 범위를 알아야 성립하는 말인데,
## 그 범위를 아는 방법이 설명문을 읽는 것뿐이었다.
##
## 칸을 개체 **고유색**으로 칠하고 테두리로 진영을 가른다. 색만으로는 누구
## 것인지 알 수 있고, 테두리만으로는 내 것인지 알 수 있다. 둘을 겹쳐야 판
## 위에서 한눈에 읽힌다.
##
## 격자 위·유닛 아래에 그린다. 누가 그 칸에 서 있는지가 안 가려야 한다.
func _draw_zones(c: CanvasItem, outline_only: bool = false) -> void:
	if battle == null:
		return
	for u in battle.units:
		if not _shown_alive(u):
			continue
		var cells := _danger_cells(u)
		if cells.is_empty():
			continue
		var edge: Color = COL_ALLY if u.team == Unit.TEAM_PLAYER else COL_FOE
		# 도화선에 불이 붙었으면 진하게. 곧 터진다는 것이 가장 급한 정보다.
		var hot: bool = u.fuse_ticks >= 0
		var pulse: float = 0.72 + 0.28 * sin(Time.get_ticks_msec() / (110.0 if hot else 260.0))

		# ── 구역은 **화면에 그려진 자리**를 따라간다 ─────────────────────
		# 전투 코어는 틱이 끝나는 순간 pos 를 목적지로 바꾸는데 화면은 그 이동을
		# 시간에 걸쳐 보여 준다. 칸 좌표로 구역을 그리면, 아직 걸어가는 중인
		# 자폭체의 폭발 범위가 **이미 도착지에 가 있다.**
		#
		# 표적 화살표에서 같은 문제를 이미 겪었다(_live_pos 주석). 규칙은 pos 로,
		# 화면은 화면으로 - 판 위에 그리는 것은 전부 같은 규칙을 따라야 한다.
		var shift := _live_pos(u) - (BOARD_ORIGIN + tile_center(u.pos))

		if not outline_only:
			# ── 채움 + 빗금 ──────────────────────────────────────────────
			# 반투명 채움만으로는 진영 표시(파랑·빨강 0.15)와 섞여 아무것도
			# 안 보였다. 같은 자리에 색 두 겹을 얹으면 둘 다 죽는다.
			# 빗금은 **무늬**라 색이 겹쳐도 살아남는다.
			var fill := Color(u.color.r, u.color.g, u.color.b,
				(0.22 if hot else 0.12) * pulse)
			for p in cells:
				var r := Rect2(BOARD_ORIGIN + Vector2(p.x * TILE_W, p.y * TILE_H)
					+ shift, Vector2(TILE_W, TILE_H))
				c.draw_rect(r, fill)
				_hatch(c, r, Color(u.color.r, u.color.g, u.color.b,
					(0.42 if hot else 0.22) * pulse), 13.0)
			continue

		# ── 바깥 테두리만 ────────────────────────────────────────────────
		# 칸마다 네모를 그리면 안쪽에 격자 무늬가 한 겹 더 생겨 지저분하다.
		# 구역의 **경계**만 굵게 두른다. 이 층은 화살표보다 위라 절대 안 가린다.
		var set: Dictionary = {}
		for p in cells:
			set[p] = true
		# ── 도화선 카운트다운 ────────────────────────────────────────────
		# 범위가 보이는 것과 "언제" 터지는지를 아는 것은 다른 문제다. 칸만 밝혀
		# 두면 플레이어는 계속 위험한 줄 알고, 실제로 급한 한 틱을 놓친다.
		if u.fuse_ticks >= 0:
			# 머리 위 정가운데는 이름표가 쓴다. 오른쪽 어깨 위로 비켜 놓는다.
			var at := _live_pos(u) + Vector2(UNIT_R * 0.75, -UNIT_R - 6.0)
			var fs := UiKit.font(16)
			var txt := str(maxi(0, u.fuse_ticks))
			var tw := fs.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			c.draw_circle(at, 13.0, Color(0.06, 0.07, 0.10, 0.9))
			c.draw_arc(at, 13.0, 0.0, TAU, 20, Color(edge.r, edge.g, edge.b, 0.95), 2.0)
			c.draw_string(fs, at + Vector2(-tw * 0.5, 6), txt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiKit.BAD)

		var w := 3.5 if hot else 2.0
		var col := Color(edge.r, edge.g, edge.b, (0.95 if hot else 0.6) * pulse)
		for p in cells:
			var o := BOARD_ORIGIN + Vector2(p.x * TILE_W, p.y * TILE_H) + shift
			if not set.has(p + Vector2i(0, -1)):
				c.draw_line(o, o + Vector2(TILE_W, 0), col, w)
			if not set.has(p + Vector2i(0, 1)):
				c.draw_line(o + Vector2(0, TILE_H), o + Vector2(TILE_W, TILE_H), col, w)
			if not set.has(p + Vector2i(-1, 0)):
				c.draw_line(o, o + Vector2(0, TILE_H), col, w)
			if not set.has(p + Vector2i(1, 0)):
				c.draw_line(o + Vector2(TILE_W, 0), o + Vector2(TILE_W, TILE_H), col, w)


## 사각형 안에 사선 빗금. 색이 겹쳐도 무늬는 살아남는다.
func _hatch(c: CanvasItem, r: Rect2, col: Color, step: float) -> void:
	var d := -r.size.y
	while d < r.size.x:
		var x0: float = r.position.x + maxf(d, 0.0)
		var y0: float = r.position.y + maxf(-d, 0.0)
		var run_len: float = minf(r.size.x - maxf(d, 0.0), r.size.y - maxf(-d, 0.0))
		if run_len > 0.0:
			c.draw_line(Vector2(x0, y0), Vector2(x0 + run_len, y0 + run_len), col, 1.5)
		d += step


## 그 개체가 지금 범위로 때릴 수 있는 칸. 없으면 빈 배열.
##
## 범위가 **지금 성립하는 것**만 그린다. 조건이 안 맞는데 칸을 칠하면 판이
## 통째로 색으로 덮여서, 정작 위험한 칸이 안 보인다.
func _danger_cells(u: Unit) -> Array:
	var out: Array = []
	# 자폭 - 자신을 중심으로 한 3x3.
	if Traits.has(u, Traits.VOLATILE):
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var p := u.pos + Vector2i(dx, dy)
				if Grid.in_bounds(p):
					out.append(p)
	# 총사 궁극기 [거리두기] - 표적 쪽 3칸 부채. 아직 안 썼고 조건이 찼을 때만.
	if u.special == "point_blank" and not u.special_used and u.last_target != null 			and u.last_target.alive:
		var d: Vector2i = u.last_target.pos - u.pos
		var face := Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) 			else Vector2i(0, signi(d.y))
		if face != Vector2i.ZERO:
			var side := Vector2i(face.y, face.x)
			for cc in [u.pos + face, u.pos + face + side, u.pos + face - side]:
				if Grid.in_bounds(cc):
					out.append(cc)
	return out


## 휜 화살표 하나. bend 는 휘는 정도이자 방향이다(부호).
##
## 베지에를 정수 좌표로 풀 필요는 없다 - 이건 그림일 뿐이고 전투 판정에는
## 아무 영향이 없다. 결정론이 걸리는 곳은 core 뿐이다.
func _arc_arrow(c: CanvasItem, a: Vector2, b: Vector2, col: Color,
		width: float, bend: float) -> void:
	var mid := (a + b) * 0.5
	var d := b - a
	# 수직 방향으로 밀어 활을 만든다. 거리가 멀수록 더 휜다.
	# ── 최소 부풀림이 있어야 한다 ────────────────────────────────────────
	# 휘는 정도를 거리에만 비례시켰더니, 붙어서 싸우는 두 유닛 사이에서는
	# 활이 거의 안 휘어 동그라미(반지름 34) 안에 통째로 파묻혔다. 정작 가장
	# 알고 싶은 순간이 그때다. 옆으로 최소 34px 는 밀어낸다.
	var off: float = maxf(UNIT_R + 14.0, d.length() * absf(bend))
	if bend < 0.0:
		off = -off
	var ctrl := mid + Vector2(-d.y, d.x).normalized() * off
	var pts := PackedVector2Array()
	var steps := 14
	for i in steps + 1:
		var u := float(i) / float(steps)
		var v := 1.0 - u
		pts.append(a * (v * v) + ctrl * (2.0 * v * u) + b * (u * u))
	c.draw_polyline(pts, col, width, true)

	# 화살촉. 끝 두 점이 만드는 방향을 그대로 쓴다.
	var tip := pts[pts.size() - 1]
	var head_dir := (tip - pts[pts.size() - 2]).normalized()
	var side := Vector2(-head_dir.y, head_dir.x)
	var h := 11.0
	c.draw_colored_polygon(PackedVector2Array([
		tip, tip - head_dir * h + side * h * 0.5,
		tip - head_dir * h - side * h * 0.5,
	]), col)


## ── 판 위 개체 정보 ──────────────────────────────────────────────────────
## 하단 바의 호버 패널과 같은 어법이다. 사선으로 깎은 판에 이름·정체·수치를
## 얹는다. 같은 모양이어야 "이건 그 정보와 같은 종류" 로 읽힌다.
##
## 적에게는 **역할과 특성**을 적는다. 내 대원은 능력치를 알면 되지만, 적은
## "저게 뭘 하는 물건인가" 가 먼저다. 자동 포탑이 안 움직인다는 사실을 모르면
## 그 판은 시행착오가 된다 - 숨기면 시행착오, 공개하면 추리다. (DESIGN 2.4)
## ── 표적 화살표는 유닛보다 **위**에 그린다 ──────────────────────────────
## 아래에 그렸더니 붙어서 싸우는 두 유닛 사이에서는 화살표가 통째로 동그라미
## 뒤에 숨었다. 정작 가장 알고 싶은 순간이 그때인데 그때만 안 보였다.
##
## 곧은 선으로도 그어 봤는데 판 한가운데에서 여섯 개가 완전히 포개졌다.
## 활처럼 휘면 겹쳐도 갈라지고, 휜 방향과 화살촉이 합쳐 "이 틱에 누가 누구를
## 향하는가" 가 한눈에 들어온다.
##
## 휘는 쪽과 정도는 index 로 고정한다. 같은 배치면 같은 그림이어야 한다.
func _draw_arrows(c: CanvasItem) -> void:
	if battle == null:
		return
	for e in battle.units:
		if not _shown_alive(e) or e.last_target == null:
			continue
		var t: Unit = e.last_target
		if not _shown_alive(t):
			continue
		var firing := Grid.manhattan(e.pos, t.pos) <= e.atk_range
		var col := e.color
		col = Color(minf(1.0, col.r * 1.15 + 0.10), minf(1.0, col.g * 1.15 + 0.10),
			minf(1.0, col.b * 1.15 + 0.10), 0.95 if firing else 0.5)
		# 화면에 실제로 그려진 자리에서 출발한다. pos 로 그리면 아직 걸어가는
		# 중인 대원의 화살표가 도착지에서 시작한다.
		var pa := _live_pos(e)
		var pb := _live_pos(t)
		# ── 동그라미 가장자리에서 시작해 가장자리에서 끝난다 ────────────
		# 가운데에서 그으면 활의 대부분이 몸통 뒤에 파묻히고 화살촉만 삐죽
		# 나온다. 실제로 그렇게 나왔다 - 무엇을 가리키는지 알 수가 없었다.
		#
		# 붙어 있으면 잘라 낸 뒤 남는 길이가 거의 0 이다. 그래서 짧을수록
		# 옆으로 더 크게 부풀려, 활이 두 몸통 **바깥으로** 돌아가게 한다.
		var span := pa.distance_to(pb)
		var dir := (pb - pa).normalized()
		pa += dir * minf(UNIT_R, span * 0.42)
		pb -= dir * minf(UNIT_R, span * 0.42)
		_arc_arrow(c, pa, pb, col, 3.0 if firing else 2.0,
			(1 if e.index % 2 == 0 else -1) * 0.34)


func _draw_hover(c: CanvasItem) -> void:
	var u := hover_unit
	if u == null:
		return
	var d: Dictionary = UnitData.TABLE.get(u.type_id, {})
	var rows: Array = []
	rows.append([UiText.t("hover.role", "역할"), String(d.get("role", "-")), UiKit.MUTED])
	rows.append([UiText.t("hover.hp", "HP"), "%d / %d" % [maxi(0, u.hp), u.max_hp],
		UiKit.TEXT])
	rows.append([UiText.t("hover.stat", "ATK · RNG · MOV"),
		"%d · %d · %d" % [u.atk, u.atk_range, u.move_range], UiKit.TEXT])
	for t in u.traits:
		rows.append([UiText.t("hover.trait", "특성"), Traits.describe(String(t)),
			Color(1.0, 0.62, 0.30)])
	# ── 지금 무엇을 하고 있는가 ──────────────────────────────────────────
	# 전황판의 회색 네모 아래 붉은 줄이 이것을 뜻한다. 줄 하나만 보고 뜻을
	# 알아낼 방법이 없었으므로, 여기서 말로 적는다.
	if u.last_target != null and u.last_target.alive:
		var reach := Grid.manhattan(u.pos, u.last_target.pos) <= u.atk_range
		rows.append([UiText.t("hover.now", "지금"),
			(UiText.t("hover.firing", "%s 을(를) 때리는 중") if reach
				else UiText.t("hover.closing", "%s 에게 접근 중")) % u.last_target.display_name,
			UiKit.BAD if reach else UiKit.ACCENT])
	if u.team == Unit.TEAM_ENEMY:
		rows.append([UiText.t("hover.ai", "기본 판단"),
			Innates.describe(u.type_id), UiKit.FAINT])

	# ── 폭에는 상한이 있다 ──────────────────────────────────────────────
	# 특성 설명("자폭 - 붙으면 3틱 뒤 폭발. 주위 3x3 에 15 피해") 하나가
	# 400px 를 넘어서, 판이 오른쪽 전황판 밑으로 파고들었다. 전황판은 별도
	# CanvasLayer 라 항상 위에 있으므로 글자가 그대로 잘려 보였다.
	#
	# 판을 넓히는 대신 줄을 접는다. 넓히면 결국 어딘가는 넘친다.
	var fs := UiKit.font(11)
	const VAL_X: float = 96.0
	const VAL_W: float = 300.0
	var lines: Array = []
	for r in rows:
		var parts := _wrap_value(fs, String(r[1]), VAL_W)
		for i in parts.size():
			lines.append([String(r[0]) if i == 0 else "", parts[i], r[2]])
	var w := VAL_X + VAL_W + 20.0
	var h: float = 34.0 + lines.size() * 17.0

	# ── 판은 짚은 칸 위로 ────────────────────────────────────────────────
	# 칸 위쪽에 붙인다. 아래로 늘어뜨리면 **판이 아직 안 본 칸을 가린다** -
	# 자폭체가 어디까지 왔는지 보려고 마우스를 올렸는데 그 판이 다음 칸을
	# 덮어 버린다. 위쪽은 이미 지나온 자리라 가려도 손해가 없다.
	var cell := BOARD_ORIGIN + Vector2(u.pos.x * TILE_W, u.pos.y * TILE_H)
	var at := Vector2(cell.x + TILE_W + 8.0, cell.y - h + TILE_H)
	# 오른쪽 한계는 화면 끝이 아니라 **전황판 왼쪽**이다. 전황판은 별도
	# CanvasLayer 라 이 판보다 항상 위에 그려진다 - 넘어가면 잘린다.
	if at.x + w > ROSTER_X - 12.0:
		at.x = cell.x - w - 8.0
	at.x = clampf(at.x, 8.0, ROSTER_X - 12.0 - w)
	# 위로 넘치면 그때만 아래로 내린다.
	if at.y < 8.0:
		at.y = cell.y
	at.y = clampf(at.y, 8.0, 712.0 - h)

	var neon: Color = u.color
	var cut := 14.0
	var shape := PackedVector2Array([
		at + Vector2(cut, 0), at + Vector2(w, 0), at + Vector2(w, h - cut),
		at + Vector2(w - cut, h), at + Vector2(0, h), at + Vector2(0, cut),
	])
	c.draw_colored_polygon(shape, Color(0.06, 0.07, 0.09, 0.96))
	var line := PackedVector2Array(shape)
	line.append(shape[0])
	c.draw_polyline(line, Color(neon.r, neon.g, neon.b, 0.9), 2.0, true)

	c.draw_string(fs, at + Vector2(14, 21), u.display_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, neon)
	var tag := UiText.t("hover.foe", "적") if u.team == Unit.TEAM_ENEMY 		else UiText.t("hover.ally", "아군")
	c.draw_string(fs, at + Vector2(w - 44, 21), tag,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		UiKit.BAD if u.team == Unit.TEAM_ENEMY else UiKit.TEAM_P)

	var y := 40.0
	for r in lines:
		if String(r[0]) != "":
			c.draw_string(fs, at + Vector2(14, y), String(r[0]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiKit.FAINT)
		c.draw_string(fs, at + Vector2(VAL_X, y), String(r[1]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, r[2])
		y += 17.0


## 값 한 줄을 폭에 맞춰 접는다. 띄어쓰기가 없으면 글자 단위로 자른다 -
## 한국어는 어절이 길어서 어절 단위로만 접으면 한 어절이 폭을 넘긴다.
func _wrap_value(f: Font, text: String, max_w: float) -> Array:
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= max_w:
		return [text]
	var out: Array = []
	var cur := ""
	for word in text.split(" "):
		var probe: String = word if cur == "" else cur + " " + word
		if f.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > max_w 				and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = probe
	if cur != "":
		out.append(cur)
	return out


## 그 대원이 **지금 화면에서 서 있는** 자리.
##
## ── 왜 좌표를 두 벌 쓰는가 ───────────────────────────────────────────────
## 전투 코어는 틱이 끝나는 순간 pos 를 목적지로 바꾼다. 그런데 화면은 그
## 이동을 0.3초에 걸쳐 보여 준다. 그래서 pos 로 그리면 **아직 걸어가는 중인
## 대원의 화살표가 이미 도착지에서 출발한다.** 실제로 화살표가 유닛보다 한 칸
## 앞서 있었고, 호버 판정도 같은 이유로 빈 칸에서 반응했다.
##
## 판정과 그림은 UnitView 가 실제로 놓인 자리를 봐야 한다. 규칙은 pos 로,
## 화면은 이 함수로.
## 화면에서 아직 살아 있는 것으로 보이는가. 규칙의 생사(Unit.alive)와 다르다.
##
## 전투 코어는 틱 전체를 한 번에 계산하고 뷰는 그걸 나중에 재생한다. 그래서
## 판 위의 그림과 판정은 alive 가 아니라 **재생이 어디까지 왔는지**를 봐야 한다.
func _shown_alive(u: Unit) -> bool:
	if u.index < unit_views.size():
		var v := unit_views[u.index]
		if v != null and is_instance_valid(v):
			return v.shown_alive()
	return u.alive


func _live_pos(u: Unit) -> Vector2:
	if u.index < unit_views.size():
		var v := unit_views[u.index]
		if v != null and is_instance_valid(v):
			return BOARD_ORIGIN + v.position
	return BOARD_ORIGIN + tile_center(u.pos)


## 유닛이 서는 자리(board 로컬 좌표).
##
## 판을 그리는 식과 **반드시 같은 값**을 써야 한다. 예전에 진영 표시만 다른
## 식으로 그렸다가 반 칸씩 어긋나 보였다. 칸 크기는 이 파일에 하나뿐이어야 한다.
func tile_center(p: Vector2i) -> Vector2:
	return Vector2(p.x * TILE_W + TILE_W * 0.5, p.y * TILE_H + TILE_H * 0.5)


# ── UI ───────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)

	# 다른 화면과 같은 톤 프레임. 전투만 빠져 있어서 국면이 바뀔 때 화면이
	# 통째로 다른 게임처럼 보였다. 강조색은 교전 단계의 색(적)이다.
	UiKit.frame(ui, UiKit.BAD)

	UiKit.phase_header(ui, Vector2(48, 16), 2)
	lbl_stage = UiKit.label(ui, Vector2(48, 56), Vector2(700, 24), "", 14, UiKit.BAD)
	lbl_tick = UiKit.label(ui, Vector2(400, 22), Vector2(160, 24), "", 15, UiKit.MUTED)
	lbl_tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_status = UiKit.label(ui, Vector2(48, 80), Vector2(700, 22), "", 12, UiKit.FAINT)

	# ── 적 개요는 판 아래 왼쪽에 ─────────────────────────────────────────
	# 예전에는 제목 밑에 붉은 한 줄로 "접근 → 교전   2 페이즈   자폭" 처럼
	# 태그를 늘어놓았다. 태그는 **이미 아는 사람에게만** 읽힌다. 처음 보는
	# 사람에게 "자폭" 세 글자는 아무것도 알려 주지 않는다.
	#
	# 그래서 말로 푼다. 자리는 판 바로 아래 왼쪽이다 - 눈이 판에서 떨어질 때
	# 가장 먼저 닿는 곳이고, 전투 중에 다시 볼 일이 있는 정보이기 때문이다.
	brief_panel = _Brief.new()
	# 판은 y=512 에서 끝나고 대원 바는 y=596 에서 시작한다. 그 사이 84px 가
	# 이 판이 쓸 수 있는 전부다.
	brief_panel.position = Vector2(40, 518)
	brief_panel.size = Vector2(836, 74)
	brief_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(brief_panel)
	if tut != null:
		tut.register_anchor("brief_panel", brief_panel)

	# 대원 바가 x48~836 · y566~662 를 쓴다. 조작 버튼은 그 오른쪽 열이다.
	var cy := 596.0
	var bx := 900.0
	btn_start = UiKit.button(ui, Vector2(bx, cy), Vector2(340, 44), UiText.t("battle.start", "▶  전투 시작"), 15)
	btn_start.pressed.connect(_on_start_pressed)
	if tut != null:
		tut.register_anchor("start_button", btn_start)

	UiKit.label(ui, Vector2(986, 24), Vector2(60, 20),
		UiText.t("battle.speed", "배속"), 11, UiKit.FAINT)
	var sx := 1006.0
	for m in SPEEDS:
		var b := UiKit.button(ui, Vector2(sx, 20), Vector2(40, 26), "%dx" % int(m), 12, 4)
		b.pressed.connect(_on_speed_pressed.bind(m))
		speed_buttons.append(b)
		sx += 46.0

	# 소리 토글. 설정은 Sfx 의 정적 변수라 화면을 넘어가도 유지된다.
	btn_sound = UiKit.button(ui, Vector2(sx + 6, 20), Vector2(64, 26), "", 11, 4)
	btn_sound.pressed.connect(func():
		Sfx.enabled = not Sfx.enabled
		_refresh_sound_button()
		# 켜는 순간 한 번 들려 줘야 "켜졌다" 가 확인된다.
		sfx.play("click")
	)
	_refresh_sound_button()

	# 이 줄은 x=600(로그 패널) 전에 끝나야 한다. 셋을 176 폭으로 줄이면
	# 48 + 176*3 + 8*2 = 592 로 딱 들어간다.
	var b1 := UiKit.button(ui, Vector2(bx, cy + 52), Vector2(164, 40), UiText.t("battle.to_loadout", "←  편성 고치기"), 14)
	b1.pressed.connect(func(): to_loadout.emit())
	var b2 := UiKit.button(ui, Vector2(bx + 176, cy + 52), Vector2(164, 40), UiText.t("battle.to_shop", "←  덱부터 다시"), 14)
	b2.pressed.connect(func(): to_shop.emit())

	# 이기면 보상 화면으로. 아직 못 이겼으면 숨긴다.
	btn_next = UiKit.button(ui, Vector2(bx, cy), Vector2(340, 44), UiText.t("battle.to_reward", "보급 수령  ▶"), 19)
	btn_next.visible = false
	btn_next.pressed.connect(func(): won.emit())

	# ── 하단 대원 바 ────────────────────────────────────────────────────
	# 명일방주 하단 UI 의 어법이다. 오른쪽에 글자로 늘어놓던 출전 정보를 얼굴
	# 카드 셋으로 압축한다. 판을 보다가 눈을 조금만 내리면 "누가 얼마나 남았고
	# 얼마나 일했는가" 가 한눈에 들어와야 한다.
	#
	# 알고리즘 전문은 여기 안 적는다 - 세 명분을 다 적으면 결국 지금과 같은
	# 글자 벽이 된다. 얼굴에 마우스를 올리면 그때 사선 판으로 펼친다.
	squad_root = Control.new()
	squad_root.position = Vector2(36, 596)
	ui.add_child(squad_root)

	rules_root = Control.new()
	rules_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(rules_root)

	# 판단 패널.
	#
	# 처음에는 격자 위(48,176)에 얹었는데 대원과 타일을 가렸다. 판단은 "지금
	# 무슨 일이 벌어지는가" 를 읽는 글이고 그건 전투 기록과 같은 종류다.
	# 오른쪽 기록 패널 위에 붙여 읽는 눈이 한쪽에만 머물게 한다.
	# ── 오른쪽 열은 위아래 둘로 나눈다 ───────────────────────────────────
	#   위  전황판 - 우리 셋이 지금 어떤 상태이고 누구에게 노려지는가
	#   아래 교전 기록 + 판단
	#
	# 예전에는 기록이 맨 위에 있고 판단이 그 아래 붙어서, 화면 아래쪽 절반이
	# 통째로 비어 있었다. 정작 가장 알고 싶은 것(누가 맞고 있나)은 아래 대원
	# 바를 봐야 했고, 시선이 위아래로 계속 튀었다.
	# ── 맨 위 층 ─────────────────────────────────────────────────────────
	# 유닛(board)·효과(fx)보다 **나중에** 붙어야 위에 그려진다. 개체 위에
	# 마우스를 올려 여는 창이 그 개체에 가리면 앞뒤가 안 맞는다.
	# ── 이 층이 판에서 가장 위다 ─────────────────────────────────────────
	# UnitView 안쪽이 절대 z 를 쓴다(체력바 60 · 규칙 칩 100). 그래서 트리
	# 순서만으로는 이 층이 위로 안 온다 - 자폭 도화선 숫자가 체력바 **밑에**
	# 깔려 있었다. 가장 급한 정보가 가장 아래에 있었던 셈이다.
	#
	# 여기 오는 것은 전부 "지금 당장 알아야 하는 것" 이다.
	# 도화선 · 범위 경계 · 표적 화살표 · 개체 정보.
	top_layer = _TopLayer.new()
	top_layer.z_index = 200
	top_layer.view = self
	top_layer.size = Vector2(1280, 720)
	top_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_layer)

	roster_root = _RosterPanel.new()
	roster_root.view = self
	roster_root.position = Vector2(ROSTER_X, 100)
	if tut != null:
		tut.register_anchor("roster_panel", roster_root)
	roster_root.size = Vector2(COL_W, ROSTER_H)
	# 네모 위에 손이 올라간 것을 알아야 하므로 마우스를 받는다.
	roster_root.mouse_filter = Control.MOUSE_FILTER_PASS
	ui.add_child(roster_root)

	# 전투 로그. 규칙 라벨은 0.6초면 사라져서 놓치면 끝이고, 6명이 동시에 움직이면
	# 어차피 다 못 읽는다. 글로 남겨야 "내 전술이 무슨 일을 했는지" 를 따라갈 수 있다.
	#
	# 기록은 [보급 수령] 바로 위에 붙인다. 판이 끝나고 시선이 그 버튼으로 갈 때
	# 마지막 몇 줄이 그 자리에 있어야 "무슨 일이 있었는지" 를 이어서 읽는다.
	log_root = Control.new()
	log_root.position = Vector2(ROSTER_X, LOG_Y)
	log_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(log_root)
	UiKit.label(log_root, Vector2(0, 0), Vector2(300, 20), UiText.t("battle.log_head", "교전 기록"), 13, UiKit.MUTED)
	var logbg := Panel.new()
	logbg.position = Vector2(0, 22)
	logbg.size = Vector2(COL_W, LOG_H)
	logbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logbg.add_theme_stylebox_override("panel",
		UiKit.box(Color(0.08, 0.09, 0.12), UiKit.LINE, 5))
	log_root.add_child(logbg)

	# ── 한 패널을 좌우로 나눠 쓴다 ───────────────────────────────────────
	# 판단 표는 항목이 넷뿐이라 짧고, 기록은 줄이 길다. 위아래로 쌓으면 넓은
	# 오른쪽이 통째로 비고 기록은 아래로 밀려 잘렸다. 나란히 두면 둘 다 산다.
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	# 넘치면 잘라 버리는 게 아니라 스크롤로 본다. 휠로 위를 되짚을 수 있어야
	# "아까 무슨 일이 있었지" 에 답할 수 있다.
	log_label.scroll_active = true
	log_label.scroll_following = true
	log_label.fit_content = false
	log_label.position = Vector2(8, 5)
	log_label.size = Vector2(LOG_TEXT_W, LOG_H - 10)
	log_label.mouse_filter = Control.MOUSE_FILTER_PASS
	log_label.add_theme_font_override("normal_font", UiKit.font(10))
	log_label.add_theme_font_size_override("normal_font_size", 10)
	log_label.add_theme_constant_override("line_separation", -2)
	logbg.add_child(log_label)

	# 세로 구분선. 두 정보가 다른 종류라는 것을 선 하나가 말해 준다.
	var sep := ColorRect.new()
	sep.color = UiKit.LINE
	sep.position = Vector2(LOG_TEXT_W + 14, 8)
	sep.size = Vector2(1, LOG_H - 16)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logbg.add_child(sep)

	trace_root = Control.new()
	trace_root.position = Vector2(ROSTER_X + LOG_TEXT_W + 26, LOG_Y + 30)
	trace_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(trace_root)

	if tut != null:
		tut.register_anchor("log_panel", logbg)

	_build_result_panel()


func _build_result_panel() -> void:
	result_panel = Control.new()
	# 판(x48~637 · y104~546)의 한가운데. 예전 (48,300)은 왼쪽 위에 걸쳐서
	# 유닛을 반쯤 덮고 판 밖으로도 삐져나갔다.
	result_panel.position = Vector2(36, 250)
	result_panel.size = Vector2(848, 180)
	result_panel.visible = false
	result_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(result_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.045, 0.07, 0.9)
	bg.size = Vector2(848, 180)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_panel.add_child(bg)

	lbl_result = UiKit.label(result_panel, Vector2(0, 34), Vector2(848, 60), "", 46)
	lbl_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_result_sub = UiKit.label(result_panel, Vector2(0, 104), Vector2(848, 30), "", 15, UiKit.MUTED)
	lbl_result_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## 전투 중에는 규칙을 못 바꾸지만, 무엇이 꽂혀 있는지는 계속 보여야 한다.
## 화면에서 벌어지는 일과 규칙 목록을 눈으로 대조하는 게 이 게임의 재미다.
func _build_rules_panel() -> void:
	for c in rules_root.get_children():
		c.queue_free()

	var px := 600.0
	UiKit.label(rules_root, Vector2(px, 20), Vector2(400, 26), UiText.t("battle.rules_head", "출전 규칙"), 20)
	UiKit.label(rules_root, Vector2(px, 48), Vector2(640, 20),
		UiText.t("battle.rules_sub", "위에서부터 처음 맞는 규칙 하나가 실행된다."), 12, UiKit.MUTED)

	UiKit.label(rules_root, Vector2(px, 66), Vector2(660, 18),
		UiText.t("battle.axis_hint",
			"네 축을 순서대로 통과해 이번 틱의 행동 하나가 정해집니다."), 10, UiKit.FAINT)

	slot_rows.clear()
	contrib_rows.clear()
	var party := run.to_party()
	# 유닛당 세로 높이는 고정이어야 한다. 특수가 있는 유닛만 한 줄이 더 생기게 두면
	# 그 유닛 블록이 다음 유닛 헤더를 덮는다. 그래서 특수 칸은 비어 있어도 자리를 잡는다.
	#   헤더 22 + (특수 + 슬롯3 + 기본기) 5줄 × 18 = 112
	for i in party.size():
		var y := 96.0 + i * ROW_H
		var s: Dictionary = UnitData.TABLE[party[i]["type"]]
		var up := int(party[i].get("upgrade", 0))
		var first: bool = bool(party[i].get("special_first", false))
		UiKit.label(rules_root, Vector2(px, y), Vector2(560, 20),
			UiText.t("battle.m02", "%s%s   HP %d · ATK %d · RNG %d · MOV %d") % [
				s["name"], "" if up == 0 else " +%d" % up,
				run.upgraded_stat(party[i]["type"], "hp", int(s["hp"])),
				run.upgraded_stat(party[i]["type"], "atk", int(s["atk"])),
				s["range"], s["move"]], 14)

		# ── 기여도 막대 ───────────────────────────────────────────────
		# 헤더 줄 오른쪽 끝, 화면 가장자리에 붙인다.
		#
		# 처음에는 숫자를 막대 **오른쪽**에 뒀는데, 악사처럼 피해와 회복이 둘 다
		# 찍히고 세 자리가 되면 (1070+126+140=1336) 1280 을 넘어 잘렸다.
		# 숫자를 위, 막대를 그 아래에 깔고 둘 다 오른쪽 끝(1264)에 맞춘다.
		# 이러면 자릿수가 늘어나도 왼쪽으로만 자라므로 다시는 안 잘린다.
		var bar_x := 1264.0 - CONTRIB_W
		var clab := UiKit.label(rules_root, Vector2(bar_x, y),
			Vector2(CONTRIB_W, 16), "", 11, UiKit.MUTED)
		clab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		var track := ColorRect.new()
		track.color = Color(0.16, 0.17, 0.21)
		track.position = Vector2(bar_x, y + 16)
		track.size = Vector2(CONTRIB_W, 5)
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rules_root.add_child(track)

		var bar := ColorRect.new()
		bar.color = UiKit.BAD
		bar.position = Vector2(bar_x, y + 16)
		bar.size = Vector2(0, 5)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rules_root.add_child(bar)
		contrib_rows[i] = { "bar": bar, "label": clab }

		var cards: Array = party[i]["cards"]
		var sp: String = String(party[i].get("special", ""))
		var ry := y + 22.0

		# 특수가 "전술보다 먼저" 면 맨 위, 아니면 슬롯 3 아래에 그린다.
		# 화면 순서가 곧 평가 순서여야 한다. 안 그러면 목록을 읽어도 예측이 안 된다.
		if sp != "" and first:
			_slot_row(i, -2, px, ry, "특", String(Specials.TABLE[sp]["name"]),
				String(Specials.TABLE[sp]["text"]), UiKit.ACCENT)
			ry += ROW_LINE

		for k in RunState.SLOTS_PER_UNIT:
			if k < cards.size():
				var c: Dictionary = Cards.TABLE[cards[k]]
				_slot_row(i, k, px, ry, "%d" % (k + 1), String(c["name"]),
					String(c["text"]), UiKit.TEXT)
			else:
				UiKit.label(rules_root, Vector2(px + 10, ry), Vector2(300, 18),
					"%d. -" % (k + 1), 11, UiKit.LINE)
			ry += ROW_LINE

		if sp != "" and not first:
			_slot_row(i, -2, px, ry, "특", String(Specials.TABLE[sp]["name"]),
				String(Specials.TABLE[sp]["text"]), UiKit.ACCENT)
			ry += ROW_LINE
		elif sp == "":
			UiKit.label(rules_root, Vector2(px + 10, ry), Vector2(300, 18),
				UiText.t("battle.m03", "특 -"), 11, UiKit.LINE)
			ry += ROW_LINE

		var own_text := Innates.describe(String(party[i]["type"]))
		_slot_row(i, -1, px, ry, "기", UiText.t("battle.m04", "기본기"),
			own_text, UiKit.FAINT)


## 규칙 한 줄. 배경판을 깔아 두고 발동할 때 밝힌다.
func _slot_row(unit_i: int, slot: int, px: float, y: float,
		tag: String, name: String, text: String, col: Color) -> void:
	var bgp := Panel.new()
	bgp.position = Vector2(px + 4, y)
	bgp.size = Vector2(660, 19)
	bgp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bgp.add_theme_stylebox_override("panel",
		UiKit.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 3))
	rules_root.add_child(bgp)
	slot_rows["%d:%d" % [unit_i, slot]] = bgp

	UiKit.label(bgp, Vector2(6, 0), Vector2(20, 18), tag, 10, UiKit.MUTED)
	UiKit.label(bgp, Vector2(26, 0), Vector2(96, 18), name, 11, col)
	UiKit.label(bgp, Vector2(126, 0), Vector2(530, 18), text, 11,
		UiKit.TEXT if col != UiKit.FAINT else UiKit.FAINT)


## 그 규칙 줄을 잠깐 밝힌다. 목록 위에서 "지금 이게 터졌다" 를 짚어 주는 장치.
## 대원별 기여도 막대를 갱신한다.
##
## 절대 수치가 아니라 **아군 중 최대치 대비 비율**로 그린다. 전투마다 총 피해량이
## 다르므로 절대 길이로 그리면 어떤 판에서는 전부 꽉 차고 어떤 판에서는 전부
## 비어 보인다. 알고 싶은 것은 "이 대원이 우리 팀에서 얼마나 일했는가" 다.
## 하단 대원 바를 만든다. 편성이 확정된 뒤 한 번만.
func _build_squad_bar() -> void:
	for c in squad_root.get_children():
		c.queue_free()
	squad_cards.clear()
	if battle == null:
		return

	var i := 0
	for u in battle.units:
		if u.team != Unit.TEAM_PLAYER:
			continue
		var card := _SquadCard.new()
		card.unit = u
		card.position = Vector2(i * 284.0, 0)
		card.size = Vector2(272, 76)
		card.pivot_offset = Vector2(136, 38)
		squad_root.add_child(card)
		squad_cards[u.index] = card
		i += 1


## 매 틱 HP·기여도만 갱신한다. 노드를 다시 만들지 않는다 - 호버 상태가 날아간다.
func _refresh_squad() -> void:
	if battle == null:
		return
	var top := 1
	for u in battle.units:
		if u.team == Unit.TEAM_PLAYER:
			top = maxi(top, u.damage_dealt + u.healing_done)

	# ── 위협 막대는 **실제 점수**로 채운다 ───────────────────────────────
	# 예전에는 태세 보정(threat_mod)만 그렸다. 그 값은 도발·전투태세를 안 끼면
	# 항상 0 이라, 위협 막대가 판 내내 비어 있었다. 시스템은 돌고 있는데 화면은
	# 아무것도 안 돌아가는 것처럼 보였다 - 있으나 마나였다는 뜻이다.
	#
	# 기준 적은 살아 있는 적 중 index 가 가장 작은 하나로 고정한다. 적마다
	# 점수가 조금씩 다르지만(거리 항이 있다) 순서는 대체로 같고, 무엇보다
	# 매 틱 기준이 흔들리지 않아야 막대가 떨지 않는다.
	var ref: Unit = null
	for u in battle.units:
		if u.alive and u.team == Unit.TEAM_ENEMY:
			ref = u
			break
	var scores: Dictionary = {}
	var hi := 1
	for u in battle.units:
		if not u.alive or u.team != Unit.TEAM_PLAYER:
			continue
		var sc: int = 0 if ref == null else maxi(0, Threat.score(ref, u))
		scores[u.index] = sc
		hi = maxi(hi, sc)

	for idx in squad_cards:
		var c = squad_cards[idx]
		if not is_instance_valid(c):
			continue
		c.contrib_top = top
		c.threat_norm = 0.0 if c.unit == null 			else float(scores.get(c.unit.index, 0)) / float(hi)
		# 지금 이 대원을 노리는 적 수. 막대만으로는 "그래서 맞고 있나" 를
		# 못 읽는다.
		var aimed := 0
		if c.unit != null:
			for e in battle.units:
				if e.alive and e.team == Unit.TEAM_ENEMY and e.last_target == c.unit:
					aimed += 1
		c.aimed_by = aimed
		c.queue_redraw()


func _refresh_contrib() -> void:
	if battle == null:
		return
	var top := 1
	for u in battle.units:
		if u.team == Unit.TEAM_PLAYER:
			top = maxi(top, u.damage_dealt + u.healing_done)

	for i in contrib_rows:
		if i >= battle.units.size():
			continue
		var u: Unit = battle.units[i]
		var row: Dictionary = contrib_rows[i]
		var bar: ColorRect = row["bar"]
		var lab: Label = row["label"]
		if not is_instance_valid(bar) or not is_instance_valid(lab):
			continue
		var total := u.damage_dealt + u.healing_done
		bar.size.x = CONTRIB_W * float(total) / float(top)
		# 회복형은 피해가 0이라도 일한 것이다. 색으로 구분한다.
		bar.color = UiKit.GOOD if u.healing_done > u.damage_dealt else UiKit.BAD
		if u.healing_done > 0 and u.damage_dealt > 0:
			lab.text = UiText.t("battle.m17", "피해 %d · 회복 %d") % [
				u.damage_dealt, u.healing_done]
		elif u.healing_done > 0:
			lab.text = UiText.t("battle.m18", "회복 %d") % u.healing_done
		else:
			lab.text = UiText.t("battle.m19", "피해 %d") % u.damage_dealt


## 이번 틱에 그 대원이 어떤 판단을 거쳤는지 네 축으로 보여 준다.
##
## ── 왜 건너뛴 항목까지 보여 주는가 ───────────────────────────────────────
## AI 를 설계하는 게임에서 AI 의 판단이 안 보이면, 플레이어는 자기 교리가 틀린
## 건지 게임이 이상한 건지 구별할 수 없다. "왜 저놈 저기로 갔지?" 가 나오는
## 순간 이 게임은 망한다.
##
## 성립한 항목만 보여 주는 것으로는 부족하다. "2번이 왜 안 걸렸지" 를 답할 수
## 없기 때문이다. 그래서 건너뛴 줄과 그 이유를 같이 적는다.
func _show_trace(who: Unit, e: Dictionary) -> void:
	if trace_root == null or not is_instance_valid(trace_root):
		return
	for c in trace_root.get_children():
		c.queue_free()

	var trace: Dictionary = e.get("trace", {})
	var y := 0.0
	UiKit.label(trace_root, Vector2(0, y), Vector2(264, 20),
		"%s · %d틱" % [who.display_name, battle.tick], 13, UiKit.ACCENT)
	y += 20.0

	for axis in Axes.ORDER:
		var rows: Array = trace.get(axis, [])
		UiKit.label(trace_root, Vector2(0, y), Vector2(80, 15),
			Axes.label(axis), 9, Axes.color(axis))
		if rows.is_empty():
			# 그 축에 모듈이 없으면 직업 기본 AI 가 정한 것이다.
			UiKit.label(trace_root, Vector2(78, y), Vector2(186, 15),
				UiText.t("battle.trace_base", "기본 AI"), 9, UiKit.FAINT)
			y += 16.0
			continue
		for r in rows:
			var hit := bool(r["hit"])
			var mark := "▶" if hit else "  "
			var col: Color = UiKit.TEXT if hit else UiKit.FAINT
			var txt := "%s %s" % [mark, String(r["name"])]
			if not hit:
				txt += "  (%s)" % String(r["why"])
			UiKit.label(trace_root, Vector2(78, y), Vector2(186, 15), txt, 9, col)
			y += 16.0

	# 마지막 줄은 실제로 한 행동이다. 위 네 축이 이 한 줄로 모인다.
	UiKit.label(trace_root, Vector2(0, y + 4), Vector2(80, 15), "ACTION", 9, UiKit.GOOD)
	UiKit.label(trace_root, Vector2(78, y + 4), Vector2(186, 15),
		String(e.get("rule_name", "")), 9, UiKit.GOOD)


func _flash_slot(unit_i: int, slot: int) -> void:
	var key := "%d:%d" % [unit_i, slot]
	if not slot_rows.has(key):
		return
	var p: Panel = slot_rows[key]
	if not is_instance_valid(p):
		return
	var on := UiKit.box(Color(0.28, 0.34, 0.46), Color(0.6, 0.7, 0.9), 3)
	p.add_theme_stylebox_override("panel", on)
	var tw := create_tween()
	tw.tween_method(func(a: float):
		if is_instance_valid(p):
			var sb := UiKit.box(Color(0.28, 0.34, 0.46, a), Color(0.6, 0.7, 0.9, a), 3)
			p.add_theme_stylebox_override("panel", sb),
		1.0, 0.0, 0.9 / speed)


# ── 전투 로그 ────────────────────────────────────────────────────────────

## ── 로그는 색으로 계층을 만든다 ─────────────────────────────────────────
## 전부 같은 흰색이면 일곱 줄이 한 덩어리 글이 되어 아무도 안 읽는다. 읽는
## 사람이 알고 싶은 것은 순서대로 이렇다.
##
##   누가 했나  - 아군은 파랑, 적은 빨강. 색만 봐도 우리 차례인지 알 수 있다
##   무슨 일이  - 피해·회복·전투 불능 같은 결과어만 진하게
##   언제       - [틱 14] 는 회색조로 내린다. 있어야 하지만 먼저 읽을 것은 아니다
func _c(text: String, col: Color) -> String:
	return "[color=#%s]%s[/color]" % [col.to_html(false), text]


func _tick_tag(t: int) -> String:
	return _c(UiText.t("battle.tick_tag", "[틱 %d]") % t, UiKit.FAINT)


## 대원 이름을 진영 색으로. 이 한 줄이 로그 전체의 뼈대다.
func _who(u: Unit) -> String:
	return _c(u.display_name,
		COL_ALLY if u.team == Unit.TEAM_PLAYER else COL_FOE)


func _log(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > LOG_LINES:
		log_lines.remove_at(0)
	if log_label != null:
		log_label.text = "
".join(log_lines)


func _clear_log() -> void:
	log_lines.clear()
	if log_label != null:
		log_label.text = ""


func _refresh_ui() -> void:
	var st := Stages.get_stage(run.stage_id)
	# ── 판 정보는 아래 개요판이 맡는다 ──────────────────────────────────
	# 숨기면 시행착오 게임이 되고 공개하면 추리 게임이 된다(DESIGN 2.4).
	# 그 원칙은 그대로인데, 태그를 제목 옆에 다닥다닥 붙이는 대신 판 아래
	# 개요판에서 말로 푼다. "2 페이즈" 는 아는 사람만 읽는다.
	var waves: int = Stages.waves(st).size()
	# 제목 줄은 "어느 판인가" 만 말한다. 무엇이 나오는지는 아래 개요판이 맡는다.
	lbl_stage.text = UiText.t("battle.m06", "작전 단계 %d/%d · %s") % [
		run.stage_id, Stages.count(), st["name"]]
	if brief_panel != null:
		(brief_panel as _Brief).body = _brief_text(st, waves)
		brief_panel.queue_redraw()

	# 마지막 스테이지에서도 보상은 받는다. 그 뒤에 런 클리어 화면으로 간다.
	btn_next.visible = phase == Phase.RESULT and battle.result == Battle.RESULT_VICTORY

	for i in speed_buttons.size():
		var m: float = SPEEDS[i]
		speed_buttons[i].modulate = Color(1, 1, 1) if speed == m else Color(0.6, 0.6, 0.66)

	match phase:
		Phase.PLAYING:
			btn_start.text = UiText.t("battle.stop", "■  중단")
			lbl_status.text = st["hint"]
		Phase.RESULT:
			btn_start.text = UiText.t("battle.m07", "▶  같은 규칙으로 다시")
			lbl_status.text = UiText.t("battle.m08", "규칙을 고치려면 아래 '편성 고치기'.")
		_:
			btn_start.text = UiText.t("battle.start", "▶  전투 시작")
			lbl_status.text = st["hint"]


## 이 판이 무엇을 요구하는지 줄글로 적는다.
##
## 태그를 늘어놓지 않는 이유는 위 주석에 적었다. 여기서는 순서가 중요하다 -
## **적이 무엇을 하려는가 → 몇 번에 걸쳐 오는가 → 판이 무엇을 하는가 → 무엇이
## 섞여 있는가**. 대응을 고민하는 순서 그대로다.
func _brief_text(st: Dictionary, waves: int) -> String:
	var out := UiText.t("brief.strategy", "적은 %s 순으로 판단합니다.") % 		String(st.get("strategy_text", "-")).replace(" → ", ", 다음에 ")
	if waves > 1:
		out += " " + UiText.t("brief.waves",
			"적은 %d 차례에 걸쳐 밀려오며, 앞 페이즈에서 잃은 체력은 그대로 이어집니다.") % waves
	var hz := Stages.hazard(run.stage_id)
	if not hz.is_empty():
		out += " " + UiText.t("brief.hazard",
			"판 자체가 공격합니다 - %s. 예고된 칸은 붉게 칠해집니다.") % 			String(hz.get("name", "지형 기믹"))
	var tl := Stages.trait_list(run.stage_id)
	if not tl.is_empty():
		# 특성 설명은 "이름 - 무슨 일이 일어나는가" 형태다. 여기서는 뒤쪽만
		# 쓴다. 이름은 개체에 마우스를 올리면 다시 나온다.
		var parts: Array[String] = []
		for t in tl:
			parts.append(Traits.describe(String(t)).replace(" - ", ": "))
		out += "
" + UiText.t("brief.traits", "섞인 개체: ") + "   ".join(parts)
	return out


## 판 아래 왼쪽의 적 개요. 호버 패널과 같은 사선 어법으로 그린다.
class _Brief extends Control:
	var body: String = ""

	func _draw() -> void:
		if body == "":
			return
		var s := size
		var cut := 14.0
		var shape := PackedVector2Array([
			Vector2(cut, 0), Vector2(s.x, 0), Vector2(s.x, s.y - cut),
			Vector2(s.x - cut, s.y), Vector2(0, s.y), Vector2(0, cut),
		])
		draw_colored_polygon(shape, Color(0.085, 0.065, 0.075, 0.92))
		var line := PackedVector2Array(shape)
		line.append(shape[0])
		draw_polyline(line, Color(0.72, 0.30, 0.32, 0.75), 2.0, true)
		# 왼쪽 색 막대. 이 판이 "적" 에 관한 것임을 색 하나로 못 박는다.
		draw_rect(Rect2(0, cut, 4, s.y - cut), Color(0.90, 0.36, 0.36, 0.9))

		# 제목 줄은 안 단다. 붉은 막대와 붉은 테두리가 이미 "적" 이라고 말하고
		# 있고, 여기서 아낀 17px 가 글 한 줄이다.
		var fs := UiKit.font(12)
		var y := 18.0
		for para in body.split("
"):
			for ln in _wrap(fs, para, s.x - 30.0):
				if y > s.y - 4.0:
					return
				draw_string(fs, Vector2(15, y), ln,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.86, 0.88, 0.92))
				y += 17.0

	## 폭에 맞춰 줄을 나눈다. Label 을 쓰면 사선 판과 레이어가 어긋나서
	## 테두리 위로 글자가 삐져나온다.
	func _wrap(f: Font, text: String, max_w: float) -> Array[String]:
		var out: Array[String] = []
		var cur := ""
		for word in text.split(" "):
			var probe: String = word if cur == "" else cur + " " + word
			if f.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > max_w 					and cur != "":
				out.append(cur)
				cur = word
			else:
				cur = probe
		if cur != "":
			out.append(cur)
		return out


func _reset() -> void:
	run_id += 1
	phase = Phase.READY
	result_panel.visible = false

	# 마지막 일격 연출 도중에 중단/재시작하면 줌과 슬로우가 걸린 채로 남는다.
	# 매 초기화마다 원복해 둔다.
	Engine.time_scale = 1.0
	board.scale = Vector2.ONE
	board.position = BOARD_ORIGIN
	fx.scale = Vector2.ONE
	fx.position = BOARD_ORIGIN
	for c in fx.get_children():
		c.queue_free()

	battle = Battle.new()
	battle.setup(run.stage_id, run.to_party())
	_build_unit_views()
	_build_squad_bar()
	_clear_log()
	lbl_tick.text = UiText.t("battle.m09", "틱 0 / %d") % battle.max_ticks()
	_refresh_ui()
	queue_redraw()


func _build_unit_views() -> void:
	for v in unit_views:
		v.queue_free()
	unit_views.clear()
	for u in battle.units:
		var v := UnitView.new()
		board.add_child(v)
		v.setup(u, font)
		v.position = tile_center(u.pos)
		unit_views.append(v)


## 새 페이즈로 등장한 개체의 노드를 붙인다.
##
## unit_views 는 battle.units 와 index 가 1:1 이어야 한다. 이벤트가 전부
## index 로 오기 때문이다. 그래서 뒤에 이어 붙이기만 하고 순서를 안 건드린다.
func _spawn_wave_views(indices: Array) -> void:
	for i in indices:
		var u: Unit = battle.units[int(i)]
		var v := UnitView.new()
		board.add_child(v)
		v.setup(u, font)
		v.position = tile_center(u.pos)
		# 등장하는 순간이 보여야 한다. 조용히 나타나면 "언제 늘었지" 가 된다.
		v.scale = Vector2(0.2, 0.2)
		v.modulate = Color(1, 1, 1, 0)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(v, "scale", Vector2.ONE, 0.28 / speed)			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(v, "modulate", Color(1, 1, 1, 1), 0.22 / speed)
		while unit_views.size() <= int(i):
			unit_views.append(null)
		unit_views[int(i)] = v
	_build_squad_bar()


## 페이즈 전환 배너. 판이 바뀌었다는 걸 한 번은 크게 말해야 한다.
func _wave_banner(n: int, total: int) -> void:
	var lbl := Label.new()
	lbl.text = UiText.t("battle.wave", "%d 페이즈 / %d") % [n, total]
	lbl.add_theme_font_override("font", UiKit.font_role("large"))
	lbl.add_theme_font_size_override("font_size", 46)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.35))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(1280, 60)
	lbl.position = Vector2(0, 300)
	lbl.modulate = Color(1, 1, 1, 0)
	add_child(lbl)
	_log("%s %s" % [_tick_tag(battle.tick),
		_c(UiText.t("battle.wave_log2", "%d 페이즈 진입") % n, Color(1.0, 0.55, 0.35))])
	var tw := create_tween()
	tw.tween_property(lbl, "modulate", Color(1, 1, 1, 1), 0.22 / speed)
	tw.tween_interval(0.55 / speed)
	tw.tween_property(lbl, "modulate", Color(1, 1, 1, 0), 0.30 / speed)
	await tw.finished
	lbl.queue_free()
	queue_redraw()


func _refresh_sound_button() -> void:
	if btn_sound != null:
		btn_sound.text = UiText.t("battle.sound_on", "소리 켬") if Sfx.enabled else UiText.t("battle.sound_off", "소리 끔")


func _on_start_pressed() -> void:
	if tut != null and phase != Phase.PLAYING:
		tut.notify_action("start")
	if phase == Phase.PLAYING:
		run_id += 1
		phase = Phase.RESULT
		_refresh_ui()
		return
	_reset()
	_start_battle()


func _on_speed_pressed(m: float) -> void:
	speed = m
	_refresh_ui()


# ── 재생 ─────────────────────────────────────────────────────────────────

func _wait(t: float) -> void:
	await get_tree().create_timer(t / speed).timeout


func _start_battle() -> void:
	run_id += 1
	var my_id := run_id
	phase = Phase.PLAYING
	_refresh_ui()

	while my_id == run_id:
		# 튜토리얼이 이 틱을 설명하겠다면 여기서 멈춘다.
		# 대사가 넘어갈 때까지 다음 틱을 진행하지 않는다.
		if tut != null and tut.active and tut.pauses_at_tick(battle.tick + 1):
			await _await_tutorial_step()
			if my_id != run_id:
				return

		var from := battle.events.size()
		var cont := battle.step()
		await _play_events(battle.events.slice(from), my_id)
		if my_id != run_id:
			return
		if not cont:
			break

	phase = Phase.RESULT
	_show_result()
	_refresh_ui()


## 지금 튜토리얼 대사가 넘어갈 때까지 기다린다.
func _await_tutorial_step() -> void:
	var waited := tut.index
	while tut.active and tut.index == waited:
		await get_tree().process_frame


func _play_events(evs: Array, my_id: int) -> void:
	# 이 틱에 전투가 끝난다면, 마지막 사망 하나만 슬로우 + 줌으로 크게 친다.
	# (DESIGN R2 연출 순서 6번) 결과 이벤트는 틱의 모든 행동 뒤에 붙으므로
	# 여기서 미리 훑어 "마지막 일격" 을 특정할 수 있다.
	var final_death := -1
	var ends_here := false
	for e0 in evs:
		if e0["type"] == "result":
			ends_here = true
	if ends_here:
		for i in range(evs.size() - 1, -1, -1):
			if evs[i]["type"] == "death":
				final_death = i
				break

	for idx in evs.size():
		var e: Dictionary = evs[idx]
		if my_id != run_id:
			return
		match e["type"]:
			"tick_begin":
				lbl_tick.text = UiText.t("battle.m10", "틱 %d / %d") % [
					e["tick"], battle.max_ticks()]
				_refresh_contrib()
				_refresh_squad()

			"rule":
				var innate := bool(e.get("innate", false))
				unit_views[e["unit"]].show_rule(String(e["text"]), innate)
				_flash_slot(int(e["unit"]), int(e["slot"]))
				var who := unit_views[e["unit"]].unit
				var src := UiText.t("battle.m11", "특수") if bool(e.get("special", false)) 					else (UiText.t("battle.m04", "기본기") if innate else UiText.t("battle.m12", "슬롯%d") % (int(e["slot"]) + 1))
				# 구분자로 │(U+2502)를 쓰면 프리텐다드에 글리프가 없어 네모로 뜬다.
				_log("%s %s · %s" % [_tick_tag(battle.tick), _who(who),
					_c(String(e.get("rule_name", "")), UiKit.TEXT)])
				if who.team == Unit.TEAM_PLAYER:
					_show_trace(who, e)
				await _wait(ACT_TIME * 0.20)

			"move":
				sfx.play("step")
				var mv := unit_views[e["unit"]]
				var steps: int = maxi(0, (e.get("path", []) as Array).size() - 1)
				_log("   " + _c(UiText.t("battle.m14", "→ %d칸 이동") % steps, UiKit.FAINT))
				await _walk(mv, e.get("path", []), e["to"])

			"attack":
				var a := unit_views[e["unit"]]
				var t := unit_views[e["target"]]
				var home := a.position
				var toward := home + (t.position - home).normalized() * 14.0
				# 공격 모션이 있으면 찌르기 시간에 맞춰 한 번 재생한다.
				# 공격과 피격을 나눠 낸다. 하나로 묶으면 "때렸다" 와 "맞았다" 가
				# 구분이 안 돼서 누가 이기고 있는지 소리로는 안 읽힌다.
				# 근접(사거리 1)과 원거리도 가른다.
				# 때릴 때는 표적 쪽을 본다. 뒤에 있는 적을 앞을 보고 치면 안 된다.
				a.face_to(t.position.x - a.position.x)
				sfx.play("attack_melee" if a.unit.atk_range <= 1 else "attack_ranged")
				sfx.play("hit", 0.92 if e["damage"] >= 20 else 1.08)
				var atk_time := ACT_TIME * 0.75 / speed
				a.play_motion(UnitView.ANIM_ATTACK, atk_time)
				var tw2 := create_tween()
				tw2.tween_property(a, "position", toward, ACT_TIME * 0.3 / speed)
				tw2.tween_property(a, "position", home, ACT_TIME * 0.45 / speed)
				t.hit()
				_pop_number(t.position, "-%d" % e["damage"], UiKit.ACCENT)
				_log("   %s %s  %s" % [_who(t.unit),
					_c(UiText.t("battle.dmg", "-%d") % e["damage"], UiKit.ACCENT),
					_c("HP %d" % e["target_hp"], UiKit.FAINT)])
				_shake(3.0)
				await tw2.finished
				a.rest_motion()

			"heal":
				# ── 회복도 동작이다 ──────────────────────────────────────
				# 지금까지 회복은 숫자만 떴다. 악사는 판 위에서 가만히 서
				# 있는데 어딘가에 +12 가 뜨는 식이라, **누가 회복시켰는지**를
				# 로그를 읽어야만 알 수 있었다.
				#
				# 리그의 동작 애니메이션을 그대로 쓴다(악사는 활 대신 활대를
				# 켜는 모션이다). 표적 쪽을 보고 한 번 재생하면 "저 대원이
				# 저 대원을 살렸다" 가 그림으로 읽힌다.
				sfx.play("heal")
				var ht := unit_views[e["target"]]
				var ha := unit_views[e["unit"]] if e.has("unit") else null
				if ha != null and ha != ht:
					ha.face_to(ht.position.x - ha.position.x)
				if ha != null:
					ha.play_motion(UnitView.ANIM_ATTACK, ACT_TIME * 0.6 / speed)
				_log("   %s %s" % [_who(ht.unit),
					_c(UiText.t("battle.heal_log", "+%d") % e["amount"], UiKit.GOOD)])
				_pop_number(ht.position, "+%d" % e["amount"], UiKit.GOOD)
				await _wait(ACT_TIME * 0.32)
				if ha != null:
					ha.rest_motion()

			"special":
				sfx.play("special")
				await _play_special(e)

			"defend":
				sfx.play("defend")
				await _wait(ACT_TIME * 0.25)

			"hold", "idle":
				await _wait(ACT_TIME * 0.10)

			"death":
				# ☠(U+2620)는 프리텐다드에 없어 네모로 떴다. 글리프 검사(test/glyph_check.gd)가
				# 잡아낸다 - 눈으로 찾지 말 것.
				sfx.play("death")
				_log("   %s %s" % [
					_c(UiText.t("battle.downed", "[전투 불능]"), UiKit.BAD),
					_who(unit_views[e["unit"]].unit)])
				if idx == final_death:
					await _finisher(e["unit"])
				else:
					var d := unit_views[e["unit"]]
					_burst(d.position, d.unit.color)
					var tw3 := create_tween()
					tw3.tween_property(d, "scale", Vector2(1.35, 1.35), 0.10 / speed)
					tw3.tween_property(d, "scale", Vector2(1.0, 1.0), 0.14 / speed)
					_shake(7.0)
					await tw3.finished
				# 여기서 비로소 화면에서 지운다. Unit.alive 는 이미 한참 전에
				# 꺼졌지만, 재생이 이 이벤트에 닿기 전까지는 살아 있는 것으로
				# 보여야 한다. (UnitView.view_dead 주석 참조)
				unit_views[e["unit"]].view_dead = true

			"barrage_warn":
				sfx.play("defend", 1.35)
				_log("   " + _c(UiText.t("battle.bar_warn", "[경고] %s 조준 - %d칸") % [
					e.get("name", "포격"), (e.get("cells", []) as Array).size()],
					Color(1.0, 0.62, 0.30)))
				await _wait(ACT_TIME * 0.5)

			"barrage":
				sfx.play("special", 0.8)
				_shake(14.0)
				for c in e.get("cells", []):
					_burst(tile_center(c), Color(1.0, 0.45, 0.28))
				for h in e.get("hits", []):
					unit_views[h["target"]].hit()
					_pop_number(unit_views[h["target"]].position,
						"-%d" % h["damage"], Color(1.0, 0.45, 0.28))
				_log("   " + _c(UiText.t("battle.bar_hit", "[착탄] %s - %d명 피격") % [
					e.get("name", "포격"), (e.get("hits", []) as Array).size()], UiKit.BAD))
				await _wait(ACT_TIME * 0.8)

			"explode":
				sfx.play("death", 0.7)
				_shake(11.0)
				_burst(tile_center(e["at"]), Color(1.0, 0.62, 0.25))
				for h in e.get("hits", []):
					unit_views[h["target"]].hit()
					_pop_number(unit_views[h["target"]].position,
						"-%d" % h["damage"], Color(1.0, 0.62, 0.25))
				_log("   " + _c(UiText.t("battle.explode", "[자폭] 인접 %d명에게 피해") % [
					(e.get("hits", []) as Array).size()], Color(1.0, 0.62, 0.25)))
				await _wait(ACT_TIME * 0.7)

			"wave":
				# 다음 페이즈. 새로 등장한 개체의 노드를 여기서 만든다.
				# 전투 시작에 다 만들어 두면 아직 안 온 적이 판 위에 서 있게 된다.
				_spawn_wave_views(e.get("units", []))
				sfx.play("special", 1.1)
				await _wave_banner(int(e["wave"]) + 1, int(e["total"]))

			"result":
				await _wait(ACT_TIME * 0.6)


## 특수 스킬 재생. cutin 플래그가 붙은 희귀 스킬만 컷인 연출을 탄다.
##
## 궁극기를 없애고 그 연출을 여기로 옮겼다. 궁극기는 게이지가 찰 때까지 기다려야
## 해서 언제 터질지 예측이 안 됐고, 그래서 영상에 담기도 어려웠다. 특수 스킬은
## 조건이 명시돼 있어 "이 상황에서 터진다" 를 보여줄 수 있다.
func _play_special(e: Dictionary) -> void:
	var sid := String(e.get("skill", ""))
	var has_cutin := sid != "" and Specials.TABLE.has(sid) \
		and bool(Specials.TABLE[sid].get("cutin", false))

	var v := unit_views[e["unit"]]
	if has_cutin:
		# ── 컷인은 내 대원만 ──────────────────────────────────────────────
		# 적 궁극기까지 1.9초짜리 컷인을 물리면 3스테이지처럼 적에게 궁극기가
		# 붙은 판에서 전투가 통째로 멎는다. 게다가 컷인은 "해냈다" 를 보여 주는
		# 연출이라, 당하는 쪽에 쓰면 의미가 반대로 붙는다.
		#
		# 그렇다고 조용히 넘길 수는 없다. 적 회복이 아무 예고 없이 터지면
		# 플레이어는 자기 알고리즘이 왜 안 통했는지 되짚을 단서를 잃는다.
		# 무슨 기술이 터졌는지만 그 자리에 짧게 띄운다.
		if v.unit.team == Unit.TEAM_PLAYER:
			await _cutin(String(e.get("name", "")), v.unit.color, v.unit.type_id, sid)
		else:
			await _enemy_special_tag(v, String(e.get("name", "")))

	# 이동이 있었으면(후퇴사격·도약) 실제 위치로 옮긴다.
	if e["from"] != e["to"]:
		var tw := create_tween()
		tw.tween_property(v, "position", tile_center(e["to"]), ACT_TIME * 0.8 / speed)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tw.finished
	else:
		v.position = tile_center(e["to"])

	for h in e["hits"]:
		unit_views[h["target"]].hit()
		_pop_number(unit_views[h["target"]].position, "-%d" % h["damage"],
			Color(1.0, 0.55, 0.9))
	for hv in e.get("heals", []):
		_pop_number(unit_views[hv["target"]].position, "+%d" % hv["amount"], UiKit.GOOD)

	_shake(10.0 if (e["hits"] as Array).size() > 1 else 5.0)
	await _wait(ACT_TIME)


## 궁극기 컷인. 좌측 30% 에 일러스트, 우측에 기술 이름.
##
## ── 참조: 세븐나이츠류 턴제 MMORPG ──────────────────────────────────
## 그쪽 궁극기 연출을 뜯어 보면 네 가지가 항상 같이 온다.
##   1) 사선 프레임   일러스트 판이 직사각형이 아니라 기울어진 평행사변형이다.
##                   화면을 가로로 반듯하게 자르지 않아서 정지 화면처럼 안 보인다.
##   2) 방사 집중선   인물 뒤에서 바깥으로 터져 나간다. 시선이 얼굴에 박힌다.
##   3) 줌 인 착지     판이 살짝 큰 상태로 들어와 제자리로 조여든다.
##                   "쾅" 하고 멈추는 무게가 여기서 나온다.
##   4) 색 잔상       본 판 뒤로 직업 색 판이 어긋나 깔린다. 잔상처럼 읽힌다.
## 넷 다 넣었다. 하나만 빼도 그냥 그림이 뜬 것처럼 밋밋해진다.
##
## ── 왜 시간이 실초로 흐르는가 ────────────────────────────────────────
## 예전에는 Engine.time_scale 을 0.3 으로 내려놓고 그 아래에서 트윈을 돌렸다.
## 트윈도 같이 3.3배 느려지므로 0.12초라고 적은 연출이 실제로는 0.4초 걸렸고,
## 전체가 1초에 육박해 "무겁다" 가 아니라 "느리다" 가 됐다.
## 지금은 배경만 늦추고(뒤에서 유닛이 천천히 움직이는 맛), 컷인 자체는
## set_ignore_time_scale 로 실초를 쓴다. 여기 적힌 숫자가 곧 보이는 시간이다.
##
## ── 도입부: 카메라가 훑는다 ──────────────────────────────────────────
## 판이 그냥 슬라이드해 들어오면 "그림이 떴다" 로 끝난다. 앞에 카메라 이동을
## 세 박자 붙이면 같은 그림이 "무언가 벌어지고 있다" 가 된다.
##   1) 무기 끝     총구·화살촉·칼끝. 이름을 읽기 전에 누구 궁극긴지 알린다
##   2) 얼굴로 위로  같은 인물이라는 것이 이 이동 하나로 이어 붙는다
##   3) 눈 확대     가장 좁은 화각. 여기서 멈췄다가 번쩍이며 터진다
## 지점은 data/cutin_shots.gd 에 있다. 여기서 수치를 잡으면 일러스트를 갈 때마다
## 연출 코드를 고쳐야 한다.
##
## 도입부 2.09초 + 공개 1.53초 = 총 3.6초. 훑는 쪽이 조금 더 길다.
const CUTIN_X: float = 384.0        ## 1280 의 30%. 일러스트가 차지하는 폭.
const CUTIN_SKEW: float = 44.0      ## 사선 프레임의 기울기(위가 넓고 아래가 좁다).
## ── 컷인이 쓰는 "원화 상자" ─────────────────────────────────────────────
## 예전에는 600x900 으로 못 박혀 있었다. 일러스트를 그 크기로 **늘여서** 그리기
## 때문에, 원본 비율이 다르면 인물이 통째로 찌그러진다. standing 을 v2 로
## 바꾸면서 가로가 긴 그림(1200x800)이 생겼고, 컷인이 눌린 얼굴로 나왔다.
##
## 이제 세로만 900 으로 고정하고 가로는 **원본 비율을 따라간다.** 컷인 좌표는
## 정규화(0~1)라 상자 크기가 바뀌어도 그대로 맞는다(data/cutin_shots.gd).
const CUTIN_ART_H: float = 900.0

## 지금 컷인이 쓰는 상자. _cutin 이 그림을 고를 때마다 다시 잡는다.
var _cut_box: Vector2 = Vector2(600, 900)


## 그 그림의 원본 비율을 지킨 상자.
func _art_box(tex: Texture2D) -> Vector2:
	if tex == null or tex.get_height() <= 0:
		return Vector2(600, CUTIN_ART_H)
	return Vector2(CUTIN_ART_H * float(tex.get_width()) / float(tex.get_height()),
		CUTIN_ART_H)

func _cutin(skill_name: String, tint: Color, type_id: String, sid: String = "") -> void:
	Engine.time_scale = 0.35

	var layer := Control.new()
	layer.size = Vector2(1280, 720)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(layer)

	# ── 암막 ─────────────────────────────────────────────────────────────
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.02, 0.04, 0.0)
	veil.size = Vector2(1280, 720)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(veil)

	# ── 도입부: 무기 → 얼굴 → 눈 ─────────────────────────────────────────
	# 아트가 없으면 통째로 건너뛴다. 훑을 것이 없는데 카메라만 움직이면
	# 빈 화면이 1초 가까이 흐른다.
	var shot_tex := UiKit.art(["cutin", "standing"], type_id)
	if shot_tex != null:
		await _cutin_intro(layer, shot_tex, CutinShots.of(type_id), tint)

	# ── 2) 우측 전술 HUD ─────────────────────────────────────────────────
	# 예전에는 방사 집중선을 깔았는데, 이름이 뜨는 자리와 정면으로 겹쳐서
	# 글자를 읽는 동안 선이 계속 지나갔다. 읽을 것이 있는 구역에 움직이는
	# 것을 두면 안 된다. 대신 얇은 육각형 HUD 를 깔았다 - 이 게임은 대원을
	# 조종하는 게 아니라 판단 규칙을 짜는 쪽이라, 전술 계기판 톤이 맞는다.
	var hud := _CutinHud.new()
	hud.size = Vector2(1280, 720)
	hud.tint = tint
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.modulate.a = 0.0
	layer.add_child(hud)

	# 불티. 오른쪽 아래에서 위로 천천히 흐른다. 정지 화면이 되는 것만 막으면 된다.
	var spark := CPUParticles2D.new()
	spark.position = Vector2(900, 760)
	spark.amount = 40
	spark.lifetime = 1.6
	spark.explosiveness = 0.0
	spark.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	spark.emission_rect_extents = Vector2(340, 12)
	spark.direction = Vector2(0, -1)
	spark.spread = 14.0
	spark.gravity = Vector2.ZERO
	spark.initial_velocity_min = 90.0
	spark.initial_velocity_max = 240.0
	spark.scale_amount_min = 1.0
	spark.scale_amount_max = 2.6
	spark.color = Color(tint.r, tint.g, tint.b, 0.95)
	layer.add_child(spark)

	# ── 1)+4) 사선 프레임 + 색 잔상 ────────────────────────────────────────
	# 판을 Node2D 로 만든다. 평행사변형은 Control 로는 못 오려낸다
	# (clip_contents 는 직사각형만 자른다). Polygon2D 로 모양을 직접 준다.
	var frame := Node2D.new()
	frame.position = Vector2(-CUTIN_X - CUTIN_SKEW, 0)   # 화면 밖 왼쪽에서 출발
	frame.scale = Vector2(1.06, 1.06)                    # 3) 큰 상태로 시작
	layer.add_child(frame)

	var shape := PackedVector2Array([
		Vector2(0, 0), Vector2(CUTIN_X + CUTIN_SKEW, 0),
		Vector2(CUTIN_X - CUTIN_SKEW, 720), Vector2(0, 720),
	])

	# 4) 잔상: 같은 모양을 직업 색으로 어긋나게 깐다.
	var ghost := Polygon2D.new()
	ghost.polygon = shape
	ghost.color = Color(tint.r, tint.g, tint.b, 0.55)
	ghost.position = Vector2(26, -10)
	frame.add_child(ghost)

	# 바탕판. 아트가 없어도 이 판만으로 자리가 읽힌다.
	var plate := Polygon2D.new()
	plate.polygon = shape
	plate.color = Color(tint.r * 0.30, tint.g * 0.30, tint.b * 0.30, 0.95)
	frame.add_child(plate)

	var tex := UiKit.art(["cutin", "standing"], type_id)
	if tex != null:
		# 판을 꽉 채우도록 아트를 확대하고(COVER), 남는 좌우는 폴리곤이 잘라 준다.
		# ── 어느 쪽을 남길 것인가 ────────────────────────────────────────
		# 컷인은 폭 428px 짜리 세로 띠라, 가로가 넓은 원화는 대부분이 잘린다.
		# 가운데를 남기면 인물이 반쯤 걸린 채로 나온다 - 서브컬처 스탠딩은
		# 인물이 화면 오른쪽에 서고 왼쪽이 여백인 구도가 많기 때문이다.
		#
		# 오른쪽을 남긴다. 잘리는 쪽은 배경이고 남는 쪽이 인물이다.
		var src := _art_box(tex)
		var box := Vector2(CUTIN_X + CUTIN_SKEW, 720.0)
		var k: float = maxf(box.x / src.x, box.y / src.y)
		var crop: float = float(CutinShots.of(type_id).get("crop", 1.0))
		var off := Vector2((box.x - src.x * k) * crop, (box.y - src.y * k) * 0.5)
		var uv := PackedVector2Array()
		for pt in shape:
			uv.append((pt - off) / k)
		var art := Polygon2D.new()
		art.polygon = shape
		art.uv = uv
		art.texture = tex
		frame.add_child(art)

	# 사선 모서리. 직업 색이라 글자를 안 읽어도 누구 궁극긴지 색으로 먼저 읽힌다.
	var edge := Line2D.new()
	edge.points = PackedVector2Array([shape[1], shape[2]])
	edge.width = 5.0
	edge.default_color = Color(tint.r, tint.g, tint.b, 1.0)
	frame.add_child(edge)

	# ── 우측: 기술 이름 ──────────────────────────────────────────────────
	# 이름판은 사선, 글자는 수평이다. 글자까지 기울이면 읽는 데 시간이 걸린다.
	var name_x := CUTIN_X + 72.0
	var bw := 1280.0 - name_x - 36.0
	var band := Node2D.new()
	band.position = Vector2(name_x, 294)
	band.scale = Vector2(0.0, 1.0)          # 왼쪽에서 오른쪽으로 펴진다
	layer.add_child(band)
	# 끝을 크게 깎는다. 14px 로는 그냥 직사각형으로 보였다.
	# 왼쪽은 아래를, 오른쪽은 위를 깎아 평행사변형이 아니라 비스듬한 띠가 된다.
	var band_shape := PackedVector2Array([
		Vector2(46, 0), Vector2(bw, 0), Vector2(bw - 46, 92), Vector2(0, 92),
	])
	var bandpoly := Polygon2D.new()
	bandpoly.polygon = band_shape
	bandpoly.color = Color(tint.r * 0.5, tint.g * 0.5, tint.b * 0.5, 0.55)
	band.add_child(bandpoly)

	# 노이즈. 단색 판은 아무리 기울여도 평평해 보인다. 아주 옅게 얹으면
	# 같은 색이 재질을 얻는다.
	var grain := Polygon2D.new()
	grain.polygon = band_shape
	grain.texture = _noise_tex()
	grain.texture_scale = Vector2(0.5, 0.5)
	grain.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	grain.color = Color(1, 1, 1, 0.16)
	band.add_child(grain)

	# 위아래 얇은 선. 띠의 사선이 어디서 끝나는지 눈에 걸리게 한다.
	for edge_pts in [[band_shape[0], band_shape[1]], [band_shape[3], band_shape[2]]]:
		var ln := Line2D.new()
		ln.points = PackedVector2Array(edge_pts)
		ln.width = 2.0
		ln.default_color = Color(tint.r, tint.g, tint.b, 0.85)
		band.add_child(ln)

	# ── 영문 이름을 뒤에 크게 깐다 ───────────────────────────────────────
	# 띠 위에 한글 한 줄뿐이면 층이 없어서 밋밋하다. 뒤에 큰 영문을 흐리게 깔면
	# 깊이가 생기고 한글이 그 위에 얹혀 더 또렷해진다. 뜻을 두 번 전하려는 게
	# 아니므로 알파를 낮게 두고 한글보다 크게 잡는다.
	var en := String(Specials.TABLE.get(sid, {}).get("en", ""))
	if en != "":
		var back := Label.new()
		back.text = en
		# 한글 이름과 같은 줄에 두면 글자가 겹쳐 둘 다 못 읽는다. 배경으로 쓰려면
		# **읽히지 않을 만큼** 크고 흐려야 한다. 크기를 키우고 알파를 절반으로
		# 낮추면 글자가 아니라 무늬가 되고, 그때부터 뒤판 역할을 한다.
		back.position = Vector2(name_x - 40.0, 178)
		back.size = Vector2(bw + 200.0, 240)
		back.add_theme_font_override("font", UiKit.title_font())
		back.add_theme_font_size_override("font_size", 168)
		back.add_theme_color_override("font_color", Color(1, 1, 1, 0.055))
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(back)

	# ── 띠 위아래 HUD 라인 ───────────────────────────────────────────────
	# 짧은 눈금과 모서리 꺾쇠. 계기판에 얹힌 표식처럼 보이게 하는 최소한이다.
	var hudline := _CutinBandHud.new()
	hudline.tint = tint
	hudline.band_w = bw
	hudline.position = Vector2(name_x, 294)
	hudline.size = Vector2(bw, 92)
	hudline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hudline.pivot_offset = Vector2.ZERO
	hudline.scale = Vector2(0.0, 1.0)     # 띠와 같이 가로로 펴진다
	layer.add_child(hudline)

	var lbl := Label.new()
	lbl.text = skill_name
	lbl.position = Vector2(name_x + 96.0, 296)      # 오른쪽에서 밀려 들어온다
	lbl.size = Vector2(bw - 40.0, 80)
	lbl.add_theme_font_override("font", UiKit.title_font())
	lbl.add_theme_font_size_override("font_size", 64)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_shadow_color", Color(tint.r, tint.g, tint.b, 0.95))
	lbl.add_theme_constant_override("shadow_offset_x", 4)
	lbl.add_theme_constant_override("shadow_offset_y", 4)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 크게 나타났다가 줄어드는 연출을 하려면 기준점이 글자 한가운데여야 한다.
	# 기본값(왼쪽 위)이면 커질 때 오른쪽 아래로 밀려 나간다.
	lbl.pivot_offset = Vector2(60, 40)
	lbl.scale = Vector2(1.18, 1.18)
	layer.add_child(lbl)

	# 직업 이름은 뺐다. 왼쪽에 그 대원의 일러스트가 통째로 서 있고 색도 직업
	# 색인데, 작은 글씨로 한 번 더 적으면 정보가 아니라 잡티가 된다.
	# 자리를 비우는 대신 뒤의 큰 영문이 그 역할을 한다.
	var sub := UiKit.label(layer, Vector2(name_x + 30.0, 262), Vector2(bw, 22), "", 12,
		Color(1, 1, 1, 0.0))
	sub.modulate.a = 0.0

	# ── 들어온다 (0.34초) ────────────────────────────────────────────────
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(veil, "color", Color(0.02, 0.02, 0.04, 0.86), 0.08)
	tw.tween_property(frame, "position", Vector2.ZERO, 0.18)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# 3) 줌 인 착지. 이동보다 길게 끌어 멈춘 뒤에도 아주 잠깐 더 조여든다.
	tw.tween_property(frame, "scale", Vector2.ONE, 0.34)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "position", Vector2(10, -4), 0.30)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 이름판이 왼쪽에서 오른쪽으로 **베어 나가듯** 펴진다. 위아래로 커지면
	# 그냥 나타난 판이 되는데, 가로로만 펴지면 사선을 따라 그어지는 것처럼
	# 보여서 띠의 기울기 자체가 연출의 일부가 된다.
	tw.tween_property(band, "scale", Vector2.ONE, 0.18)\
		.set_delay(0.04).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(hudline, "scale", Vector2.ONE, 0.20)\
		.set_delay(0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position", Vector2(name_x + 30.0, 296), 0.20)\
		.set_delay(0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate", Color(1, 1, 1, 1), 0.12)\
		.set_delay(0.06).from(Color(1, 1, 1, 0))
	tw.tween_property(sub, "modulate", Color(1, 1, 1, 1), 0.12).set_delay(0.12)
	# 궁극기다. 큰 채로 0.1초 버틴 다음 제자리로 줄어든다.
	# 바로 줄이면 그냥 튀어나온 글자가 되고, 버티는 동안만 "크다" 가 읽힌다.
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.16)\
		.set_delay(0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(hud, "modulate", Color(1, 1, 1, 1), 0.16).set_delay(0.08)
	await tw.finished

	# 이름이 뜬 채 머무는 시간. 도입부에서 이미 충분히 뜸을 들였으므로 짧게 끊는다.
	# 이름이 뜬 채 머무는 시간.
	#
	# 0.10 이었을 때는 이름이 보이는 구간이 다 합쳐 0.5초쯤이라 읽기 전에
	# 사라졌다. 여기만 늘리면 앞뒤 연출은 그대로 두고 읽는 시간만 벌 수 있다.
	await get_tree().create_timer(0.85, true, false, true).timeout

	# ── 나간다 (0.20초) ──────────────────────────────────────────────────
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.size = Vector2(1280, 720)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)

	var tw2 := create_tween()
	tw2.set_ignore_time_scale(true)
	tw2.set_parallel(true)
	tw2.tween_property(flash, "color", Color(1, 1, 1, 0.9), 0.05)
	tw2.tween_property(frame, "position", Vector2(-CUTIN_X - CUTIN_SKEW, 0), 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw2.tween_property(band, "scale", Vector2(0.0, 1.0), 0.12)
	tw2.tween_property(lbl, "modulate", Color(1, 1, 1, 0), 0.10)
	tw2.tween_property(sub, "modulate", Color(1, 1, 1, 0), 0.08)
	tw2.tween_property(veil, "color", Color(0.02, 0.02, 0.04, 0.0), 0.20)
	tw2.tween_property(hud, "modulate", Color(1, 1, 1, 0), 0.12)
	tw2.tween_property(hudline, "modulate", Color(1, 1, 1, 0), 0.12)
	tw2.tween_property(spark, "modulate", Color(1, 1, 1, 0), 0.12)
	await tw2.finished

	var tw3 := create_tween()
	tw3.set_ignore_time_scale(true)
	tw3.tween_property(flash, "color", Color(1, 1, 1, 0.0), 0.14)
	await tw3.finished

	layer.queue_free()
	Engine.time_scale = 1.0


## 컷인 도입부. 무기 끝 → 얼굴 → 눈 순서로 카메라가 훑고 번쩍인다.
##
## 카메라는 없다. 아트를 크게 키워 놓고 위치를 옮기는 것이 전부다. 보여 줄
## 지점 p(정규화)를 화면 한가운데에 놓으려면 아트를 그 반대로 밀면 된다.
func _cutin_intro(layer: Control, tex: Texture2D, shot: Dictionary,
		tint: Color) -> void:
	var view := Control.new()
	view.size = Vector2(1280, 720)
	view.clip_contents = true          # 확대된 아트가 화면 밖으로 새는 것을 막는다
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(view)

	var art := TextureRect.new()
	art.texture = tex
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# 원본 비율을 지킨 상자에 그린다. 고정 크기로 늘이면 얼굴이 눌린다.
	_cut_box = _art_box(tex)
	art.size = _cut_box
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(art)

	# 위아래 검은 띠. 화각이 좁다는 신호이자, 확대된 아트의 위아래 끝을 가린다.
	var bars: Array[ColorRect] = []
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color(0.02, 0.02, 0.04, 1.0)
		bar.size = Vector2(1280, 0)
		bar.position = Vector2(0, 0 if i == 0 else 720)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.add_child(bar)
		bars.append(bar)

	# ── 확대 구간의 먼지와 불티 ──────────────────────────────────────────
	# 카메라가 훑는 동안 화면에 움직이는 것이 아트 하나뿐이라, 확대가 부드러울수록
	# 오히려 정지 화면처럼 보였다. 렌즈 앞을 스치는 입자가 있으면 "지금 카메라가
	# 붙어 있다" 가 읽힌다. 아트보다 앞에 두되 흐리게 깔아 얼굴을 안 가린다.
	var dust := CPUParticles2D.new()
	dust.position = Vector2(640, 720)
	dust.amount = 150
	dust.lifetime = 2.4
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(660, 20)
	dust.direction = Vector2(0, -1)
	dust.spread = 22.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 70.0
	dust.initial_velocity_max = 260.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 5.0
	dust.color = Color(1, 1, 1, 0.62)
	view.add_child(dust)

	# 인물 쪽으로 빨려 드는 불티. 확대의 방향과 같은 쪽으로 흘러야 시선이
	# 얼굴로 모인다. 아래에서 위로 올라가는 먼지와 방향이 달라 층이 갈린다.
	var spark := CPUParticles2D.new()
	spark.position = Vector2(1180, 360)
	spark.amount = 90
	spark.lifetime = 1.1
	spark.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	spark.emission_rect_extents = Vector2(12, 360)
	spark.direction = Vector2(-1, 0)
	spark.spread = 10.0
	spark.gravity = Vector2.ZERO
	spark.initial_velocity_min = 420.0
	spark.initial_velocity_max = 900.0
	spark.scale_amount_min = 1.0
	spark.scale_amount_max = 4.0
	spark.color = Color(tint.r, tint.g, tint.b, 0.55)
	view.add_child(spark)

	# 확대 구간을 가로지르는 스캔선. 렌즈가 훑고 있다는 신호다.
	# 파티클은 "공기 중에 뭔가 있다" 이고 이 선은 "카메라가 보고 있다" 라서
	# 둘이 겹치면 층이 하나 더 생긴다.
	var scan := ColorRect.new()
	# 0.16 은 어두운 일러스트 위에서 거의 안 보였다. 이 선은 "카메라가 훑고
	# 있다" 를 말하는 유일한 신호라 확실히 보여야 한다.
	scan.color = Color(tint.r, tint.g, tint.b, 0.42)
	scan.size = Vector2(1280, 5)
	scan.position = Vector2(0, -20)
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(scan)
	var scan_tw := create_tween()
	scan_tw.set_ignore_time_scale(true)
	scan_tw.set_loops(3)
	scan_tw.tween_property(scan, "position", Vector2(0, 740), 0.7)		.from(Vector2(0, -20))

	var weapon: Vector2 = shot["weapon"]
	var eye: Vector2 = shot["eye"]
	# 얼굴은 눈보다 조금 아래를 잡는다. 눈만 노리면 턱이 잘려 얼굴로 안 읽힌다.
	var face := Vector2(eye.x, eye.y + 0.055)

	_cam(art, weapon, 4.6)

	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(bars[0], "size", Vector2(1280, 76), 0.12)
	tw.parallel().tween_property(bars[1], "position", Vector2(0, 644), 0.12)
	tw.parallel().tween_property(bars[1], "size", Vector2(1280, 76), 0.12)

	# 1) 무기 끝. 완전히 정지시키지 않고 아주 천천히 밀어 준다.
	#    멈춘 그림은 정지 화면으로 읽히고, 조금이라도 흐르면 살아 있는 것으로 읽힌다.
	tw.parallel()
	_cam_to(tw, art, weapon, 4.2, 0.65, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)

	# 2) 얼굴까지 위로. 이 구간이 가장 길다 - 두 지점이 한 인물이라는 것을
	#    이어 붙이는 게 목적이라, 끊기면 딴 그림 두 장으로 보인다.
	_cam_to(tw, art, face, 3.4, 0.80, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)

	# 3) 눈. 짧고 세게 박는다.
	_cam_to(tw, art, eye, 5.4, 0.52, Tween.TRANS_EXPO, Tween.EASE_OUT)
	await tw.finished

	# 번쩍. 이 흰 화면이 도입부와 전체 공개 사이의 이음매를 덮는다.
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.size = Vector2(1280, 720)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)

	var tw2 := create_tween()
	tw2.set_ignore_time_scale(true)
	tw2.set_parallel(true)
	tw2.tween_property(flash, "color", Color(1, 1, 1, 1.0), 0.07)
	tw2.tween_property(art, "modulate", Color(1, 1, 1, 0), 0.07)
	await tw2.finished

	view.queue_free()

	# 흰 화면을 남긴 채 돌려준다. 뒤이어 판이 들어오는 동안 이게 걷힌다.
	var tw3 := create_tween()
	tw3.set_ignore_time_scale(true)
	tw3.tween_property(flash, "color", Color(tint.r, tint.g, tint.b, 0.0), 0.18)
	tw3.tween_callback(flash.queue_free)


## 아트를 지점 p(정규화)가 화면 한가운데 오도록 즉시 옮긴다. z 는 배율.
func _cam(art: Control, p: Vector2, z: float) -> void:
	var k := (720.0 / _cut_box.y) * z
	art.scale = Vector2(k, k)
	art.position = _cam_pos(p, k)


## 같은 계산을 트윈으로. 배율과 위치는 반드시 같은 시간·같은 곡선이어야 한다 -
## 하나만 어긋나면 확대하면서 화면이 미끄러진다.
func _cam_to(tw: Tween, art: Control, p: Vector2, z: float, sec: float,
		trans: Tween.TransitionType, ease_t: Tween.EaseType) -> void:
	var k := (720.0 / _cut_box.y) * z
	tw.tween_property(art, "scale", Vector2(k, k), sec).set_trans(trans).set_ease(ease_t)
	tw.parallel().tween_property(art, "position", _cam_pos(p, k), sec)\
		.set_trans(trans).set_ease(ease_t)


## 지점 p 를 화면 한가운데 두되, 아트 바깥이 보이지 않도록 안으로 당긴다.
##
## 아트 가장자리를 찍으면 화면 절반이 빈 채로 뜬다. 4.6배로 당겼을 때 보이는
## 폭이 원화의 348px 뿐이라, 정규화 0.9 같은 값은 물리적으로 화면 안에 못 온다.
## 데이터를 잘 잡는 게 우선이지만(data/cutin_shots.gd), 일러스트를 교체하면
## 좌표는 그대로 두고 그림만 바뀌기 마련이라 여기서도 한 번 막는다.
## 옅은 노이즈 텍스처. 한 번 만들어 두고 계속 쓴다.
##
## 난수를 쓰지 않는다. 고정 시드 LCG 라 실행할 때마다 같은 무늬가 나온다 -
## 이 프로젝트는 전투가 완전히 결정론적이고, 화면도 같은 규칙을 따른다.
static var _noise_cache: ImageTexture = null

static func _noise_tex() -> ImageTexture:
	if _noise_cache != null:
		return _noise_cache
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var seed_v: int = 987654321
	for y in n:
		for x in n:
			seed_v = (seed_v * 1103515245 + 12345) & 0x7FFFFFFF
			var v := float(seed_v % 256) / 255.0
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	_noise_cache = ImageTexture.create_from_image(img)
	return _noise_cache


## 컷인 오른쪽에 까는 전술 HUD.
##
## 얇은 육각형 격자와 모서리 괄호, 눈금. 화면을 채우는 게 목적이 아니라
## "여기는 계기판이다" 를 깔아 주는 것이 목적이라 선은 최대한 가늘게 둔다.
## 굵어지는 순간 이름을 읽는 데 방해가 된다.
## 이름 띠의 위아래에 얹는 눈금과 꺾쇠.
##
## 띠가 단색 사선 하나뿐이면 "색칠한 도형" 으로 읽힌다. 짧은 눈금 몇 개와 모서리
## 꺾쇠만 얹어도 계기판 위의 표식처럼 보인다. 굵게 그리면 이름을 읽는 데
## 방해되므로 전부 1~2px 로 둔다.
class _CutinBandHud extends Control:
	var tint: Color = Color.WHITE
	var band_w: float = 600.0

	func _draw() -> void:
		var c := Color(tint.r, tint.g, tint.b, 0.75)
		var faint := Color(tint.r, tint.g, tint.b, 0.30)

		# 위아래 가는 선. 띠의 사선과 나란히 간다.
		draw_line(Vector2(46, -6), Vector2(band_w, -6), c, 1.0)
		draw_line(Vector2(0, 98), Vector2(band_w - 46, 98), c, 1.0)

		# 눈금. 위는 아래로, 아래는 위로 짧게.
		for i in 16:
			var x := 60.0 + i * ((band_w - 90.0) / 16.0)
			var h := 7.0 if i % 4 == 0 else 4.0
			draw_line(Vector2(x, -6), Vector2(x, -6 + h), faint, 1.0)
			draw_line(Vector2(x - 20.0, 98), Vector2(x - 20.0, 98 - h), faint, 1.0)

		# 오른쪽 끝 꺾쇠. 이름 줄이 어디서 끝나는지 눈에 걸린다.
		draw_line(Vector2(band_w - 2, -6), Vector2(band_w - 2, 22), c, 2.0)
		draw_line(Vector2(band_w - 2, -6), Vector2(band_w - 26, -6), c, 2.0)


class _CutinHud extends Control:
	var tint: Color = Color.WHITE

	func _draw() -> void:
		var c := Color(tint.r, tint.g, tint.b, 0.30)
		var faint := Color(tint.r, tint.g, tint.b, 0.14)

		# 육각 격자. 오른쪽 위와 오른쪽 아래, 글자 줄(y 266~394)은 피한다.
		for band_y in [120.0, 470.0]:
			for i in 7:
				var cx := 560.0 + i * 104.0
				for j in 2:
					_hex(Vector2(cx + (52.0 if j == 1 else 0.0),
						band_y + j * 60.0), 34.0, faint)

		# 모서리 괄호. 화면 오른쪽이 한 덩어리로 묶인 것처럼 보이게 한다.
		var box := Rect2(548, 88, 700, 552)
		for corner in [
			[box.position, Vector2(1, 0), Vector2(0, 1)],
			[Vector2(box.end.x, box.position.y), Vector2(-1, 0), Vector2(0, 1)],
			[Vector2(box.position.x, box.end.y), Vector2(1, 0), Vector2(0, -1)],
			[box.end, Vector2(-1, 0), Vector2(0, -1)],
		]:
			var o: Vector2 = corner[0]
			draw_line(o, o + corner[1] * 46.0, c, 2.0)
			draw_line(o, o + corner[2] * 46.0, c, 2.0)

		# 눈금. 오른쪽 세로선에 일정 간격으로 짧게.
		for i in 13:
			var y := 108.0 + i * 44.0
			var w := 16.0 if i % 3 == 0 else 8.0
			draw_line(Vector2(1240, y), Vector2(1240 - w, y), faint, 1.0)

	func _hex(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 7:
			var a := TAU * float(i) / 6.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_polyline(pts, col, 1.0)


func _cam_pos(p: Vector2, k: float) -> Vector2:
	var half := Vector2(640.0, 360.0) / k              # 보이는 영역의 절반(원화 픽셀)
	var lo := half / _cut_box
	var q := Vector2(
		clampf(p.x, minf(lo.x, 0.5), maxf(1.0 - lo.x, 0.5)),
		clampf(p.y, minf(lo.y, 0.5), maxf(1.0 - lo.y, 0.5)))
	return Vector2(640, 360) - Vector2(q.x * _cut_box.x, q.y * _cut_box.y) * k


## 경로를 한 칸씩 밟아 이동한다.
##
## 도착점까지 직선으로 보간하면 L자 경로에서 모서리를 가로질러 다른 유닛을
## 뚫고 지나가는 것처럼 보인다. 이동이 2칸이 되면서 실제로 그렇게 보였다.
## path 가 비어 있으면(도약 같은 순간이동) 직선으로 슉 옮긴다.
func _walk(v: UnitView, path: Array, dest: Vector2i) -> void:
	# 걷기 애니메이션은 "한 칸당 한 사이클" 로 속도를 맞춘다.
	# 배속과 이동 칸 수가 바뀌어도 항상 온전한 걸음이 보인다.
	var steps: int = maxi(1, path.size() - 1)
	var per := (ACT_TIME / float(steps)) / speed
	# 가는 쪽을 보게 한다. 물러나는 대원이 앞을 본 채 뒤로 미끄러지면
	# 그 순간만은 게임이 아니라 인형극처럼 보인다.
	v.face_to(tile_center(dest).x - v.position.x)
	v.play_motion(UnitView.ANIM_WALK, per)
	await _walk_steps(v, path, dest)
	v.rest_motion()


func _walk_steps(v: UnitView, path: Array, dest: Vector2i) -> void:
	if path.size() < 2:
		var tw0 := create_tween()
		tw0.tween_property(v, "position", tile_center(dest), ACT_TIME * 0.7 / speed)			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw0.finished
		return

	var steps := path.size() - 1
	var per := (ACT_TIME / float(steps)) / speed
	var tw := create_tween()
	for i in range(1, path.size()):
		tw.tween_property(v, "position", tile_center(path[i]), per)			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func _burst(at: Vector2, col: Color) -> void:
	var b := Burst.new()
	b.position = at
	fx.add_child(b)
	b.setup(col)


## 마지막 일격: 슬로우 + 죽는 유닛으로 줌 + 파티클.
##
## 줌은 board / fx 를 통째로 확대하고, 죽는 지점이 판 한가운데로 오도록 위치를
## 역산해 맞춘다. 이 동안에는 흔들기를 걸지 않는다 - 같은 position 을 두 Tween 이
## 동시에 건드리면 카메라가 튄다.
func _finisher(unit_index: int) -> void:
	var d := unit_views[unit_index]
	var focus := d.position
	var zoom := 1.7
	var center := Vector2(Grid.W * TILE_W, Grid.H * TILE_H) * 0.5 + BOARD_ORIGIN
	var zoom_pos := center - focus * zoom

	Engine.time_scale = 0.3

	_burst(focus, d.unit.color)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(board, "scale", Vector2(zoom, zoom), 0.18)
	tw.tween_property(board, "position", zoom_pos, 0.18)
	tw.tween_property(fx, "scale", Vector2(zoom, zoom), 0.18)
	tw.tween_property(fx, "position", zoom_pos, 0.18)

	var pop := create_tween()
	pop.tween_property(d, "scale", Vector2(1.5, 1.5), 0.10)
	pop.tween_property(d, "scale", Vector2(1.0, 1.0), 0.16)

	await tw.finished
	await get_tree().create_timer(0.35).timeout

	var back := create_tween()
	back.set_parallel(true)
	back.tween_property(board, "scale", Vector2.ONE, 0.22)
	back.tween_property(board, "position", BOARD_ORIGIN, 0.22)
	back.tween_property(fx, "scale", Vector2.ONE, 0.22)
	back.tween_property(fx, "position", BOARD_ORIGIN, 0.22)
	await back.finished

	Engine.time_scale = 1.0


## 적 궁극기 표시. 컷인 대신 쓰는 짧은 연출이다. (위 _play_special 주석 참조)
##
## 0.5초. 유닛 위에 기술 이름이 붉게 떠올랐다 사라지고 화면이 한 번 흔들린다.
## "뭔가 큰 게 터졌다" 와 "그게 무엇이었나" 만 전달되면 충분하다.
func _enemy_special_tag(v: UnitView, skill_name: String) -> void:
	var l := Label.new()
	l.text = skill_name
	l.add_theme_font_override("font", UiKit.title_font())
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", UiKit.BAD)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 7)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(220, 28)
	l.position = v.position + Vector2(-110, -62)
	l.pivot_offset = Vector2(110, 14)
	l.scale = Vector2(1.25, 1.25)
	l.modulate.a = 0.0
	fx.add_child(l)

	_shake(7.0)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "modulate", Color(1, 1, 1, 1), 0.08 / speed)
	tw.tween_property(l, "scale", Vector2.ONE, 0.16 / speed)		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position", l.position + Vector2(0, -18), 0.50 / speed)		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(l, "modulate", Color(1, 1, 1, 0), 0.14 / speed)
	await tw.finished
	l.queue_free()


func _pop_number(at: Vector2, text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 6)
	l.position = at + Vector2(-20, -46)
	fx.add_child(l)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", l.position + Vector2(0, -30), 0.55 / speed)
	tw.tween_property(l, "modulate", Color(col.r, col.g, col.b, 0.0), 0.55 / speed)
	tw.chain().tween_callback(l.queue_free)


func _shake(amount: float) -> void:
	var tw := create_tween()
	tw.tween_property(board, "position", BOARD_ORIGIN + Vector2(amount, -amount * 0.6), 0.04 / speed)
	tw.tween_property(board, "position", BOARD_ORIGIN + Vector2(-amount * 0.7, amount * 0.4), 0.05 / speed)
	tw.tween_property(board, "position", BOARD_ORIGIN, 0.06 / speed)


func _show_result() -> void:
	result_panel.visible = true
	# 승패는 소리로 먼저 안다. 화면을 안 보고 있어도 결과가 전달돼야 한다.
	sfx.play("victory" if battle.is_won() else "defeat")
	match battle.result:
		Battle.RESULT_VICTORY:
			lbl_result.text = UiText.t("battle.victory", "VICTORY")
			lbl_result.add_theme_color_override("font_color", UiKit.GOOD)
			lbl_result_sub.text = UiText.t("battle.victory_sub", "%d틱에 제압.  아군 %d명 생존.") % [
				battle.tick, battle.living_count(Unit.TEAM_PLAYER)]
		Battle.RESULT_DEFEAT:
			lbl_result.text = UiText.t("battle.defeat", "DEFEAT")
			lbl_result.add_theme_color_override("font_color", UiKit.BAD)
			lbl_result_sub.text = UiText.t("battle.defeat_sub", "%d틱에 전멸.  규칙을 고쳐서 다시.") % battle.tick
		Battle.RESULT_TIMEOUT:
			lbl_result.text = UiText.t("battle.timeout", "TIME OUT")
			lbl_result.add_theme_color_override("font_color", UiKit.ACCENT)
			lbl_result_sub.text = UiText.t("battle.timeout_sub", "%d틱 안에 끝내지 못했다.  적 %d명 생존.") % [
				Battle.MAX_TICKS, battle.living_count(Unit.TEAM_ENEMY)]


## 하단 대원 카드 한 장. 얼굴 · HP · 기여도.
##
## ── 왜 알고리즘을 평소엔 안 적는가 ───────────────────────────────────────
## 세 명분 슬롯을 다 적으면 결국 글자 벽이 된다. 예전 오른쪽 패널이 정확히
## 그랬다 - 화면의 절반이 글자였고, 정작 판은 40%밖에 안 썼다.
##
## 전투 중에 항상 필요한 것은 "누가 얼마나 남았고 얼마나 일했는가" 뿐이다.
## 알고리즘은 **궁금해졌을 때** 보면 된다. 그래서 얼굴에 마우스를 올린 그 한
## 명분만 사선 판으로 펼친다.
##
## ── 왜 기울이는가 ────────────────────────────────────────────────────────
## Balatro 의 카드처럼 마우스 쪽으로 살짝 기운다. 정지한 판이 손에 잡히는
## 물건처럼 느껴지는 데 이 한 겹이 크게 작용한다. 각도는 작게 둔다 - 크게 주면
## 글자가 읽기 힘들어지고, 이건 읽으라고 펼치는 판이다.
class _SquadCard extends Control:
	var unit: Unit
	var contrib_top: int = 1

	## 아군 중 이 대원의 위협도가 차지하는 비율(0~1)과, 지금 이 대원을 노리는 적 수.
	## _refresh_squad 가 매 틱 채운다.
	var threat_norm: float = 0.0
	var aimed_by: int = 0

	var _hover: bool = false
	var _tilt: float = 0.0
	var _lift: float = 0.0
	var _mx: float = 0.5

	func _ready() -> void:
		# ── 얼굴은 노드로 그린다 ─────────────────────────────────────────
		# draw_texture_rect 로 그렸더니 알파가 무시되고 흰 사각형이 나왔다.
		# 텍스처 자체는 멀쩡했다(엔진에서 (2,2) 픽셀이 완전 투명으로 읽힌다).
		# _draw 안에서 그린 것이 문제였으므로 TextureRect 자식으로 옮긴다.
		# 매 프레임 다시 그리지 않아도 되니 비용도 준다.
		var face := UiKit.art(["portraits"], unit.type_id if unit != null else "")
		if face != null:
			var tr := TextureRect.new()
			tr.texture = face
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.position = Vector2(8, 4)
			tr.size = Vector2(68, 68)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(tr)

		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func(): _hover = true)
		mouse_exited.connect(func(): _hover = false)

	func _process(delta: float) -> void:
		# 마우스가 카드의 어느 쪽에 있는지에 따라 기우는 방향이 바뀐다.
		if _hover:
			var local := get_local_mouse_position()
			_mx = clampf(local.x / maxf(size.x, 1.0), 0.0, 1.0)
		var k: float = clampf(delta * 12.0, 0.0, 1.0)
		_tilt = lerp(_tilt, (_mx - 0.5) * 0.10 if _hover else 0.0, k)
		_lift = lerp(_lift, -10.0 if _hover else 0.0, k)
		rotation = _tilt
		position.y = 0.0 + _lift
		z_index = 40 if _hover else 0
		queue_redraw()

	func _draw() -> void:
		if unit == null:
			return
		var s := size
		var col: Color = unit.color
		var neon := Color.from_hsv(col.h, minf(col.s, 0.45),
			clampf(col.v * 1.2 + 0.15, 0.0, 1.0), 1.0)

		# ── 판. 오른쪽 아래를 사선으로 깎는다 ────────────────────────────
		var cut := 16.0
		var shape := PackedVector2Array([
			Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y - cut),
			Vector2(s.x - cut, s.y), Vector2(0, s.y),
		])
		draw_colored_polygon(shape, Color(0.09, 0.10, 0.13, 0.94))
		var line := PackedVector2Array(shape)
		line.append(shape[0])
		draw_polyline(line, Color(neon.r, neon.g, neon.b, 0.55 if _hover else 0.28), 1.6, true)

		# 왼쪽 직업 색 바. 멀리서도 누구인지 갈린다.
		draw_rect(Rect2(0, 0, 3, s.y), neon)

		# 얼굴은 _draw 가 아니라 TextureRect 자식으로 그린다. (아래 _ready 주석 참조)
		if UiKit.art(["portraits"], unit.type_id) == null:
			draw_circle(Vector2(52, 48), 34, col)

		var fs := UiKit.font(11)
		var fb := UiKit.font(16)
		var dead := not unit.alive

		# 이름과 HP 숫자
		draw_string(fb, Vector2(106, 24), unit.display_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			Color(0.45, 0.45, 0.5) if dead else UiKit.TEXT)
		draw_string(fs, Vector2(106, 42), "%d / %d" % [maxi(0, unit.hp), unit.max_hp],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiKit.MUTED)

		# ── HP 막대 ──────────────────────────────────────────────────────
		var bw := s.x - 118.0
		draw_rect(Rect2(106, 48, bw, 6), Color(0.16, 0.17, 0.21))
		var ratio: float = 0.0 if unit.max_hp <= 0 else clampf(
			float(unit.hp) / float(unit.max_hp), 0.0, 1.0)
		# 빨강은 위험 신호로 남겨 둔다. 평소엔 직업 색이라 누구 막대인지 읽힌다.
		var hpc: Color = UiKit.BAD if ratio < 0.35 else neon
		draw_rect(Rect2(106, 48, bw * ratio, 6), hpc)

		# ── 위협도 ───────────────────────────────────────────────────────
		# 지금 적이 누구를 노릴지가 여기서 갈린다. 도발을 넣으면 이 막대가
		# 올라가고, 그때 격자의 어그로 선이 이 대원 쪽으로 옮겨 온다.
		# 두 표시가 같은 것을 말해야 "내가 어그로를 관리하고 있다" 가 성립한다.
		draw_rect(Rect2(s.x - 74, 8, 66, 6), Color(0.14, 0.15, 0.19))
		draw_rect(Rect2(s.x - 74, 8, 66.0 * clampf(threat_norm, 0.0, 1.0), 6),
			UiKit.BAD if aimed_by > 0 else Color(0.66, 0.56, 0.36))
		# 노려지는 중이면 몇에게 노려지는지 숫자로 못 박는다. 막대는 "누가 더
		# 위험한가" 를, 숫자는 "그래서 지금 맞고 있는가" 를 답한다.
		var tag := UiText.t("battle.threat", "위협")
		if aimed_by > 0:
			tag = UiText.t("battle.aimed", "피표적 %d") % aimed_by
		draw_string(fs, Vector2(s.x - 74, 28), tag,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			UiKit.BAD if aimed_by > 0 else UiKit.FAINT)

		# ── 전투 수치 ────────────────────────────────────────────────────
		# 누적 피해·회복은 오른쪽 전황판이 이미 말한다. 여기서 또 말하면 같은
		# 값이 화면 두 곳에 있는 것이고, 그러면 둘 다 안 읽힌다.
		#
		# 이 자리에는 **지금 이 대원이 뭘 할 수 있는가** 를 둔다. 공격력·방어·
		# 사거리·이동은 판을 보다가 "왜 저기서 멈췄지" 를 물을 때 필요한 값이고,
		# 그 질문은 항상 판을 보는 중에 생긴다.
		var stat := UiText.t("battle.squad_stat", "ATK %d · DEF %d · RNG %d · MOV %d") % [
			unit.atk, 2 + unit.passive_def + unit.command_def,
			unit.atk_range, unit.move_range]
		# 네 값이 한 줄에 다 들어가야 한다. 10pt 로는 "MOV" 에서 잘렸고,
		# 잘린 수치는 없는 것만 못하다.
		draw_string(fs, Vector2(96, 72), stat,
			HORIZONTAL_ALIGNMENT_LEFT, int(s.x - 104), 9, UiKit.FAINT)

		if dead:
			draw_rect(Rect2(0, 0, s.x, s.y), Color(0, 0, 0, 0.55))

		if _hover:
			_draw_algorithm(s, neon, fs)

	## 사선 투명 판에 이 대원의 알고리즘을 펼친다.
	##
	## 카드 **위쪽**으로 펼친다. 아래는 화면 끝이라 잘리고, 옆으로 펼치면 다른
	## 대원 카드를 덮는다. 위는 판(격자)인데 그건 지금 안 보고 있는 쪽이다.
	func _draw_algorithm(s: Vector2, neon: Color, fs: Font) -> void:
		var rows: Array = []
		for i in unit.card_rules.size():
			var r: Dictionary = unit.card_rules[i]
			if r.is_empty():
				continue
			rows.append([String(r.get("axis", "")), String(r.get("name", "")),
				String(r.get("text", ""))])
		if unit.special != "" and Specials.TABLE.has(unit.special):
			rows.append(["", String(Specials.TABLE[unit.special]["name"]),
				UiText.t("battle.squad_ult", "궁극기 · 페이즈당 1회")])
		rows.append(["", UiText.t("battle.m04", "기본기"), Innates.describe(unit.type_id)])

		var h := 26.0 + rows.size() * 22.0
		var w := 460.0
		var top := -h - 12.0
		var skew := 18.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(skew, top), Vector2(w, top),
			Vector2(w - skew, top + h), Vector2(0, top + h),
		]), Color(0.05, 0.06, 0.09, 0.93))
		draw_line(Vector2(skew, top), Vector2(w, top), neon, 1.6)
		draw_line(Vector2(0, top + h), Vector2(w - skew, top + h),
			Color(neon.r, neon.g, neon.b, 0.4), 1.0)

		var y := top + 20.0
		for r in rows:
			var axis := String(r[0])
			if axis != "":
				draw_string(UiKit.font_role("large"), Vector2(22, y), Axes.label(axis),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Axes.color(axis))
			draw_string(fs, Vector2(112, y), String(r[1]),
				HORIZONTAL_ALIGNMENT_LEFT, 110, 11, UiKit.TEXT)
			draw_string(fs, Vector2(224, y), String(r[2]),
				HORIZONTAL_ALIGNMENT_LEFT, w - 246, 10, UiKit.MUTED)
			y += 22.0


## ── 전황판 ───────────────────────────────────────────────────────────────
## 우리 셋을 세로로 세우고, 각자 옆에 **지금 그를 노리고 있는 적**을 붙인다.
##
## ── 왜 필요한가 ──────────────────────────────────────────────────────────
## 어그로는 이 게임의 중심 축인데 화면에 숫자로만 있었다. 막대가 얼마나 찼는지
## 봐도 "그래서 지금 누가 나를 때리고 있나" 는 알 수 없다. 그건 **누가 누구를**
## 의 문제이므로 둘을 나란히 놓아야만 읽힌다.
##
## 적 얼굴은 아직 없다. 회색 네모로 자리를 잡아 두고 진영 색 테두리만 준다 -
## 그림이 들어오면 네모만 갈아 끼우면 된다.
##
## 불투명도가 곧 위협의 세기다. 그 적이 보기에 이 대원이 다른 아군보다 얼마나
## 더 위협적인지가 진하기로 나온다. 도발을 넣으면 그 줄의 네모가 진해지고
## 다른 줄은 옅어진다 - 한 화면에서 원인과 결과가 같이 보인다.
class _RosterPanel extends Control:
	var view

	const ROW_H: float = 78.0
	const FACE: float = 60.0
	## 적 네모. 겹쳐 놓으면 몇인지 안 세어지므로 오른쪽부터 나란히 깐다.
	const FOE_BOX: float = 30.0
	const FOE_GAP: float = 6.0
	## 한 줄에 나란히 놓을 수 있는 적 수. 넘치면 "+N" 으로 접는다.
	const FOE_MAX: int = 3
	## 적 네모가 시작하는 x. HP 막대 끝(70+132=202)보다 뒤여야 안 겹친다.
	const FOE_X: float = 214.0

	## 이번에 그린 적 네모들. [{ rect, unit }] - 마우스 판정이 읽는다.
	var _foe_hits: Array = []

	## ── 네모에 손을 올리면 그 적이 **판 위에서** 밝혀진다 ───────────────
	## 회색 네모만 봐서는 누구인지 알 수가 없다. 그렇다고 여기에 또 정보창을
	## 띄우면 같은 것을 두 군데서 설명하게 된다.
	##
	## 판 위의 그 개체를 호버한 것과 **똑같이** 취급한다. 그러면 정체를 밝히는
	## 창은 한 종류뿐이고, 눈은 자연히 판으로 간다 - 어차피 거기서 싸운다.
	func _process(_d: float) -> void:
		if view != null:
			var m := get_local_mouse_position()
			var hit: Unit = null
			for h in _foe_hits:
				if (h["rect"] as Rect2).has_point(m):
					hit = h["unit"]
					break
			view.roster_hover = hit
		queue_redraw()

	func _draw() -> void:
		_foe_hits.clear()
		if view == null or view.battle == null:
			return
		var b = view.battle
		var fs: Font = UiKit.font(11)

		# ── 사선 줄무늬 바탕 ─────────────────────────────────────────────
		# 포격 예고와 카드 테두리가 이미 쓰는 어법이다. 같은 무늬를 두르면
		# 이 패널이 "전술 정보를 읽는 자리" 라는 것이 화면 전체와 이어진다.
		var pad := Rect2(-8, 14, size.x + 8, size.y - 14)
		draw_rect(pad, Color(0.09, 0.10, 0.135, 0.72))
		var step := 16.0
		var d := -pad.size.y
		while d < pad.size.x:
			var x0: float = pad.position.x + maxf(d, 0.0)
			var y0: float = pad.position.y + maxf(-d, 0.0)
			var run_len: float = minf(pad.size.x - maxf(d, 0.0),
				pad.size.y - maxf(-d, 0.0))
			if run_len > 0.0:
				draw_line(Vector2(x0, y0), Vector2(x0 + run_len, y0 + run_len),
					Color(1, 1, 1, 0.028), 1.0)
			d += step
		# 사선으로 깎은 모서리. 카드와 같은 사이버틱 어법.
		_chamfer(pad, Color(0.42, 0.62, 0.80, 0.45))

		draw_string(fs, Vector2(0, 11), UiText.t("battle.roster_head", "전황"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiKit.MUTED)

		var allies: Array = []
		for u in b.units:
			if u.team == Unit.TEAM_PLAYER:
				allies.append(u)

		var y := 26.0
		for u in allies:
			_row(u, y, fs, b, allies)
			y += ROW_H

	## 왼쪽 위·오른쪽 아래를 사선으로 깎은 테두리.
	func _chamfer(r: Rect2, col: Color) -> void:
		var c := 12.0
		var pts := PackedVector2Array([
			r.position + Vector2(c, 0),
			r.position + Vector2(r.size.x, 0),
			r.position + Vector2(r.size.x, r.size.y - c),
			r.position + Vector2(r.size.x - c, r.size.y),
			r.position + Vector2(0, r.size.y),
			r.position + Vector2(0, c),
		])
		for i in pts.size():
			draw_line(pts[i], pts[(i + 1) % pts.size()], col, 1.0)

	func _row(u: Unit, y: float, fs: Font, b, allies: Array) -> void:
		var dim: float = 1.0 if u.alive else 0.35
		var neon: Color = u.color
		neon.a = dim

		var face_rect := Rect2(0, y, FACE, FACE)
		draw_rect(face_rect, Color(0.10, 0.11, 0.15, dim))
		var tex := UiKit.art(["portraits", "units"], u.type_id)
		if tex != null:
			draw_texture_rect(tex, face_rect, false, Color(1, 1, 1, dim))
		draw_rect(face_rect, Color(neon.r, neon.g, neon.b, 0.75 * dim), false, 1.0)

		var x := FACE + 10.0
		draw_string(fs, Vector2(x, y + 13), u.display_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(UiKit.TEXT.r, UiKit.TEXT.g, UiKit.TEXT.b, dim))

		# HP. 막대는 비율을, 숫자는 남은 양을 말한다.
		var bw := 132.0
		draw_string(fs, Vector2(x + 80, y + 13), "%d / %d" % [u.hp, u.max_hp],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(UiKit.MUTED.r, UiKit.MUTED.g, UiKit.MUTED.b, dim))
		draw_rect(Rect2(x, y + 20, bw, 6), Color(0.15, 0.16, 0.20, dim))
		var ratio: float = 0.0 if u.max_hp <= 0 else clampf(
			float(u.hp) / float(u.max_hp), 0.0, 1.0)
		draw_rect(Rect2(x, y + 20, bw * ratio, 6),
			Color(UiKit.BAD.r, UiKit.BAD.g, UiKit.BAD.b, dim) if ratio < 0.35 else neon)

		# ── 한 일은 색으로 가른다 ────────────────────────────────────────
		# 피해와 회복은 성격이 반대다. 같은 회색으로 나란히 적으면 눈이 둘을
		# 구별하지 않고 그냥 "숫자 두 개" 로 읽는다.
		var dmg := UiText.t("battle.roster_dmg", "피해 %d") % u.damage_dealt
		draw_string(fs, Vector2(x, y + 44), dmg, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(UiKit.BAD.r, UiKit.BAD.g, UiKit.BAD.b, dim))
		var w1: float = fs.get_string_size(dmg, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(fs, Vector2(x + w1 + 10, y + 44),
			UiText.t("battle.roster_heal", "회복 %d") % u.healing_done,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(UiKit.GOOD.r, UiKit.GOOD.g, UiKit.GOOD.b, dim))

		# ── 이 대원을 노리는 적 ──────────────────────────────────────────
		# **왼쪽에서 오른쪽으로 그냥 나열한다.** 오른쪽 끝에서부터 거꾸로 깔았
		# 더니 수가 늘 때마다 시작점이 움직여서, 줄마다 네모가 서로 다른 자리에
		# 놓이고 겹친 것처럼 보였다. 시작점을 고정하면 그런 일이 없다.
		var foes: Array = []
		for e in b.units:
			if e.alive and e.team == Unit.TEAM_ENEMY and e.last_target == u:
				foes.append(e)
		var shown: int = mini(foes.size(), FOE_MAX)
		var fx := FOE_X
		for i in shown:
			var e: Unit = foes[i]
			var mine: int = maxi(0, Threat.score(e, u))
			var top: int = 1
			for a in allies:
				if a.alive:
					top = maxi(top, maxi(0, Threat.score(e, a)))
			var a2: float = 0.32 + 0.68 * clampf(float(mine) / float(top), 0.0, 1.0)
			var r := Rect2(fx, y + 8, FOE_BOX, FOE_BOX)
			_foe_hits.append({ "rect": r, "unit": e })
			var lit: bool = view != null and view.hover_unit == e
			draw_rect(r, Color(0.44, 0.46, 0.52, a2))
			draw_rect(r, Color(UiKit.BAD.r, UiKit.BAD.g, UiKit.BAD.b,
				1.0 if lit else a2), false, 2.5 if lit else 1.5)
			# ── 붉은 밑줄 = 지금 실제로 때리는 중 ────────────────────────
			# 노리는 것과 닿는 것은 다르다. 사거리 밖에서 다가오는 중인 적과
			# 이미 붙어서 때리고 있는 적이 화면에서 같아 보이면, 이 판이
			# 급한지 아닌지를 알 수가 없다.
			#
			# 줄 하나로는 뜻이 안 읽히므로 네모에 손을 올리면 판 위 정보창이
			# "지금 ○○ 을 때리는 중" 이라고 말로 적어 준다. (_draw_hover)
			if Grid.manhattan(e.pos, u.pos) <= e.atk_range:
				draw_rect(Rect2(fx, y + 8 + FOE_BOX + 2, FOE_BOX, 3.0), UiKit.BAD)
			fx += FOE_BOX + FOE_GAP
		if foes.size() > shown:
			draw_string(fs, Vector2(fx + 2, y + 30), "+%d" % (foes.size() - shown),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiKit.BAD)
