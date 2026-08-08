class_name StoryScreen
extends Control

## 스토리 재생기. 장면을 하나씩 보여 주고 끝나면 done 을 쏜다.
##
## ── 왜 별도 화면인가 ─────────────────────────────────────────────────────
## 튜토리얼 말풍선은 게임 화면 **위에** 얹힌다. 지금 눌러야 할 곳을 가리켜야
## 하므로 그 아래가 보여야 하기 때문이다.
##
## 스토리는 반대다. 게임 화면을 **덮어야** 한다. 여기서 하는 이야기는 "지금 이
## 화면이 사실은 무엇인가" 이고, 그러려면 게임 화면이 잠깐 사라져야 무게가 산다.
##
## ── 아트가 없어도 진행된다 ───────────────────────────────────────────────
## art 가 지정됐는데 파일이 없으면 회색 네모를 놓는다. 배경이 나중에 들어와도
## 대본과 연출을 먼저 완성해 두려는 것이다. 이 프로젝트는 계속 그렇게 해 왔다.

signal done()

## 카메라 위상. 대사가 바뀔 때마다 0 에서 다시 자란다.
var _cam_t: float = 0.0
var _cam_dir: Vector2 = Vector2.RIGHT
## 화자 줌인의 남은 세기. 말하기 시작할 때 1 이 되고 가라앉는다.
var _speak: float = 0.0
## 대본이 이 대사에 준 연출 배율. 1.0 이 기본, 0 이면 아예 안 움직인다.
var _cam_gain: float = 1.0
## 배경 판의 제자리. 표류는 여기서부터 잰다.
var _art_home: Vector2 = Vector2.ZERO
var _zoom_gain: float = 1.0

const PAD := 64.0

## ── 대사판 치수 ─────────────────────────────────────────────────────────
## 안쪽 여백을 24 에서 34 로 넓혔다. 글자가 상자에 바짝 붙어 있으면 대사가
## 아니라 표에 적힌 문장처럼 읽힌다.
const BUBBLE_X := 96.0
## 170 -> 136. 한두 줄짜리 대사가 대부분인데 판이 너무 커서 아래쪽 절반이
## 통째로 비어 있었다. 빈 판은 여백이 아니라 그냥 빈 판이다.
## 조금 더 내렸다. 일러스트의 얼굴선과 판 윗변이 가까워 화면이 답답했다.
const BUBBLE_Y := 530.0
const BUBBLE_H := 136.0
const PAD_IN := 30.0

## ── 카메라 연출 ─────────────────────────────────────────────────────────
## 정지 화면에 글자만 바뀌면 그건 슬라이드 쇼다. 아주 조금만 움직여도 화면이
## "지금 벌어지는 일" 로 읽힌다 - 미연시가 오래 써 온 방법이고, 핵심은
## **알아채지 못할 만큼만** 움직이는 것이다. 크게 움직이면 연출이 아니라
## 멀미가 된다.
##
## 셋을 겹친다.
##   배경 표류  대사가 바뀔 때마다 아주 천천히 밀리고 배율이 오간다
##   화자 줌인  말하기 시작할 때 초상이 살짝 커졌다 제자리로 돌아온다
##   판 흔들림  fx 가 걸린 대사에서 화면이 한 번 튄다
##
## 값은 전부 대본이 덮어쓸 수 있다(camera / zoom / shake).
const CAM_DRIFT: float = 14.0       ## 배경이 한 대사 동안 미는 거리(px)
const CAM_ZOOM: float = 0.035       ## 배경 배율 진폭
const CAM_SPEED: float = 0.055      ## 표류 속도(1/초)
const SPEAK_ZOOM: float = 0.045     ## 화자가 말하기 시작할 때 커지는 정도
const SPEAK_SETTLE: float = 2.6     ## 그 확대가 가라앉는 속도(1/초)

## 대사마다 방향이 달라야 같은 화면이 반복돼도 다르게 보인다. 난수를 안 쓰는
## 이유는 늘 그렇듯 재현성 때문이다 - 대사 번호에서 방향을 만든다.
const CAM_DIRS: Array[Vector2] = [
	Vector2(1, 0.35), Vector2(-1, 0.2), Vector2(0.6, -1), Vector2(-0.7, -0.5),
]

## ── 인물별 배율 보정 ─────────────────────────────────────────────────────
## 기본 규칙은 "그림 폭을 칸 폭에 맞춘다" 이다. 인물이 프레임 폭을 꽉 채우는
## 그림에서는 이것만으로 어깨가 맞고, 어깨가 맞으면 얼굴도 맞는다.
##
## 그런데 그림마다 인물이 차지하는 비율이 다르다. 악사는 프레임 오른쪽 절반이
## 비어 있어서, 폭을 맞추면 인물이 절반 크기로 선다. 반대로 궁수는 활까지
## 프레임을 꽉 채워서 폭을 맞추면 인물이 혼자 커진다.
##
## 이건 규칙 하나로는 안 잡힌다. 그림이 담고 있는 것이 매번 다르기 때문이다.
## 그래서 사람 손으로 배율을 적고 test/portraits.gd 로 나란히 세워 확인한다.
##
##   k: 폭맞춤 배율에 곱한다. 1.0 이 기본.
##   x: 칸 폭 대비 좌우 이동. 인물이 프레임 한쪽에 치우친 그림을 가운데로 민다.
##   y: 칸 높이 대비 상하 이동. 양수면 아래로.
const PORTRAIT_FIT: Dictionary = {
	"archer":    {"k": 0.95, "x": 0.00, "y": 0.00},
	"bard":      {"k": 1.56, "x": 0.00, "y": 0.00},
	"warrior":   {"k": 1.76, "x": 0.00, "y": 0.00},
	"assassin":  {"k": 1.02, "x": 0.00, "y": 0.00},
	"musketeer": {"k": 0.94, "x": 0.00, "y": 0.00},
	"shieldman": {"k": 1.04, "x": 0.00, "y": 0.00},
	"ai":        {"k": 1.23, "x": 0.00, "y": 0.00},
	"ai_talk":   {"k": 1.23, "x": 0.00, "y": 0.00},
	"ai_smile":  {"k": 1.23, "x": 0.00, "y": 0.00},
}


## 초상 칸 하나를 만든다. 화면 밖(검수 스크립트)에서도 같은 규칙으로 세우려면
## 이 문이 필요하다 - 규칙이 두 벌이 되면 검수한 것과 화면에 뜨는 것이 달라진다.
static func new_portrait_box(id: String) -> Control:
	var p := _Portrait.new()
	p.art_id = id
	p.clip_contents = false
	return p

var beats: Array = []
var index: int = 0

var _art: Control
var _bubble: Control
var _name_tag: Control
var _lbl_text: Label
var _lbl_hint: Label
var _fx: Control
var _log: Label
var _log_box: Control
var _log_t: float = 0.0
var _log_n: int = 0

## 기록이 마지막 줄까지 나온 시각. 0 이면 아직 흐르는 중이다.
var _log_full_ms: int = 0
var _t: float = 0.0
var _shake: float = 0.0


func setup(p_beats: Array) -> void:
	beats = p_beats
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_sfx = Sfx.new()
	add_child(_sfx)

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.035, 0.05)
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 배경 아트 자리. 화면 위쪽 3분의 2를 쓴다.
	_art = _ArtSlot.new()
	# ── 배경은 대사판 아래까지 ──────────────────────────────────────────
	# 예전에는 y 56~456 만 쓰고 그 아래를 통째로 검게 뒀다. 그러면 대사판이
	# 그림 위에 얹힌 것이 아니라 **그림이 끝난 자리에 놓인** 것이 되고,
	# 화면이 위아래 두 동강으로 읽힌다.
	#
	# 배경을 바닥까지 늘리고 대사판을 반투명으로 바꾸면, 대사가 같은 공간
	# 안에서 들리는 소리가 된다. 미연시가 오래전부터 쓰는 배치다.
	# ── 액자를 없앤다 ────────────────────────────────────────────────────
	# 배경을 화면 안쪽 사각형에만 깔고 바깥에 검은 테를 둘렀다. 그러면 그림이
	# **화면 속의 그림**이 되어, 인물이 서 있는 공간이 아니라 걸려 있는
	# 액자가 된다.
	#
	# 화면을 가득 채우고 위아래에 비네팅만 얹는다. 테두리 대신 어둠으로
	# 가장자리를 닫으면 시선이 가운데로 모이고, 대사판이 그 어둠 위에 놓인다.
	_art_home = Vector2.ZERO
	_art.position = _art_home
	_art.size = Vector2(1280, 720)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)

	# 로그 화면. fx == "log" 인 장면에서만 보인다.
	# 로그는 줄이 서른 줄 가까이 되므로 반드시 잘라야 한다. Label 은 넘치면
	# 그냥 아래로 자라서 대사판을 뚫고 나간다 - 실제로 그렇게 겹쳤다.
	var log_box := _Holo.new()
	log_box.position = Vector2(PAD + 16, 70)
	log_box.size = Vector2(1280 - PAD * 2 - 32, 380)
	log_box.clip_contents = true
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(log_box)
	# 파란 단색. 시설 기록은 사람이 쓴 글이 아니라 기계가 남긴 것이므로 색이
	# 하나뿐이어야 한다. 흰색이면 그냥 자막처럼 보인다.
	_log = UiKit.label(log_box, Vector2(12, 8), Vector2(1280 - PAD * 2 - 56, 1400),
		"", 12, Color(0.55, 0.88, 1.0))
	log_box.visible = false
	_log_box = log_box

	_fx = _Glitch.new()
	_fx.size = Vector2(1280, 720)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)

	# ── 화자 초상 ────────────────────────────────────────────────────────
	# 미연시 어법이다. 목소리만 있던 존재가 화면에 서 있으면 같은 대사가 다르게
	# 읽힌다. 대사판보다 **먼저** 붙여 판이 초상 위에 얹히게 한다 - 인물이
	# 판 뒤에서 올라오는 것처럼 보여야 자연스럽다.
	#
	# 켜고 끄는 것은 대본이 정한다. data/story.json 의 각 대사에 "portrait" 를
	# 적으면 그 그림이 뜨고, 안 적으면 안 뜬다. 연출을 코드가 아니라 대본에서
	# 만지도록 두는 편이 훨씬 빠르다.
	_portrait = _Portrait.new()
	# ── 궁극기 컷인과 같은 어법 ──────────────────────────────────────────
	# 얼굴만 크게 잡으면 누가 말하는지는 알아도 **어떤 인물인지**가 안 남는다.
	# 컷인이 반신을 세로로 길게 보여 주는 것과 같은 이유로, 여기서도 인물을
	# 통째로 세운다. 아래는 대사판이 가리므로 잘려도 좋다.
	# ── 일러스트의 발치는 화면 끝이다 ───────────────────────────────────
	# 652 에서 끊겨 있었다. 그림 아래로 68px 짜리 빈 띠가 남아서 인물이 바닥에
	# 서 있는 게 아니라 공중에 잘려 붙어 있는 것처럼 보였다.
	_portrait.position = Vector2(PAD + 4, 52)
	_portrait.size = Vector2(400, 668)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.visible = false
	add_child(_portrait)

	# ── 대사판 ──────────────────────────────────────────────────────────
	# 고친 것 셋.
	#
	#   1. 더 어둡게 (0.80 -> 0.90). 반투명이 옅으면 밝은 배경 위에서 글자가
	#      배경과 싸운다. 뒤가 비치는 것과 글이 안 읽히는 것은 다른 문제다.
	#   2. 테두리를 얇고 은은하게. 굵은 노란 선이 시선을 먼저 가져갔다.
	#      화자를 알리는 일은 이름표가 하면 되고, 판은 조용해야 한다.
	#   3. 안쪽 여백 24 -> 34, 줄간격 1.35배. 글자가 상자에 붙어 있으면
	#      대사가 아니라 표에 적힌 문장처럼 읽힌다.
	_bubble = _Panel.new()
	_bubble.position = Vector2(BUBBLE_X, BUBBLE_Y)
	_bubble.size = Vector2(1280 - BUBBLE_X * 2, BUBBLE_H)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bubble)

	# ── 이름표는 판 밖에 ────────────────────────────────────────────────
	# 안에 두면 첫 줄이 이름에 밀려 본문 자리가 좁아지고, 이름과 대사가 같은
	# 상자 안에서 경쟁한다. 위로 빼면 "누가" 와 "무슨 말" 이 한눈에 갈린다.
	_name_tag = _NameTag.new()
	# 이름표를 키웠다. 화자가 누구인지는 대사보다 먼저 읽혀야 하는 정보인데
	# 15px 짜리 태그는 배경 무늬처럼 보였다.
	_name_tag.position = Vector2(BUBBLE_X + 6, BUBBLE_Y - 40)
	_name_tag.size = Vector2(360, 40)
	_name_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_tag)

	# 첫 줄이 판 윗변에 붙어 있었다. 이름표를 판 밖으로 빼면서 위쪽에 생긴
	# 자리를 글이 그대로 물려받은 탓이다. 10px 내린다.
	_lbl_text = UiKit.label(_bubble, Vector2(PAD_IN, PAD_IN + 2),
		Vector2(1280 - BUBBLE_X * 2 - PAD_IN * 2, BUBBLE_H - PAD_IN * 2 + 6),
		"", 19, UiKit.TEXT, true)
	# ── 대사만 서체가 다르다 ────────────────────────────────────────────
	# 큰 글씨는 비트비트체(도트)를 쓴다. 게임의 인상이 거기서 나오니까.
	# 그런데 대사는 한 화면에서 두세 줄을 **이어 읽는** 글이고, 도트 폰트는
	# 획이 붙어서 그 읽기를 방해한다. 인상은 제목과 UI 가 이미 만들고 있다.
	_lbl_text.add_theme_font_override("font", UiKit.font_role("story"))
	_lbl_text.add_theme_font_size_override("font_size", 19)
	# 줄간격 1.35배. 긴 대사가 붙어 있으면 읽는 속도가 뚝 떨어진다.
	_lbl_text.add_theme_constant_override("line_spacing", 8)

	_lbl_hint = UiKit.label(self, Vector2(BUBBLE_X, BUBBLE_Y + BUBBLE_H + 8),
		Vector2(1280 - BUBBLE_X * 2, 22),
		UiText.t("story.hint", "아무 곳이나 눌러 계속"), 12, UiKit.FAINT)
	_lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# 위아래 비네팅. 액자 대신 이것이 화면을 닫는다.
	var vig := _Vignette.new()
	vig.size = Vector2(1280, 720)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)
	# 대사판과 초상은 비네팅보다 위여야 한다.
	move_child(vig, get_child_count() - 4)

	_show(0)


## 화면이 열린 시각. 갓 열린 창은 잠시 입력을 안 받는다.
##
## ── 왜 필요한가 ──────────────────────────────────────────────────────────
## 보상 화면에서 카드를 누르면 그 클릭 이벤트가 아직 전파 중인 상태에서 이
## 화면이 트리에 붙는다. 그러면 **같은 클릭 하나가** 보상을 고르고 첫 대사까지
## 넘겨 버린다.
##
## 대사가 여러 줄인 대목은 한 줄만 건너뛰니 티가 안 났다. 그런데 pre_2 처럼
## 대사가 **한 줄뿐인** 대목은 그 한 번에 통째로 끝나서, 화면이 아예 안 뜬
## 것처럼 보였다. 실제로 "1스테이지 전 대사는 나오는데 2스테이지 것은 안
## 나온다" 로 보고됐다.
##
## 대본을 늘려서 가릴 문제가 아니다. 대사가 한 줄이어도 읽을 시간은 있어야 한다.
var _portrait: Control

## MIRA 는 시설의 AI 다. 이름을 한 곳에만 적어 둔다.
const MIRA_NAME := "MIRA"
const COL_MIRA := Color(0.96, 0.97, 1.0)
## 대사판 테두리에 쓰는 MIRA 색. 이름은 흰색이지만 판은 하늘색이다 -
## 흰 테두리는 그냥 밝은 선으로 보여서 "누구" 를 말하지 못한다.
const COL_MIRA_EDGE := Color(0.45, 0.80, 1.0)
const COL_HUMAN := Color(1.0, 0.78, 0.35)
const COL_NARRATION := Color(0.58, 0.62, 0.70)

## 지금 깔려 있는 배경. 대사가 배경을 안 적으면 이 값이 이어진다.
## 지금 대사의 전체 글월과, 어디까지 찍었는지.
##
## 글자 수를 실수로 들고 있는 이유는 속도를 초당 글자 수로 주기 때문이다.
## 정수로 세면 프레임률에 따라 박자가 흔들린다.
var _full: String = ""
var _typed: float = 0.0

## 초당 몇 글자. 소리와 같이 나므로 너무 빠르면 잡음이 된다.
const TYPE_CPS: float = 34.0
## 몇 글자마다 소리를 낼지. 매 글자면 소리가 뭉개진다.
const TYPE_SFX_EVERY: int = 2

var _bg_id: String = ""
var _sfx: Sfx

## 대본이 곡을 바꾸기 전에 돌던 곡. 화면을 떠날 때 이것으로 되돌린다.
var _music_back: String = ""

var _opened_ms: int = 0

## 이 시간 안에 들어온 입력은 앞 화면에서 새어 나온 것으로 본다.
const INPUT_GUARD_MS: int = 250

## ── 기록이 다 나온 뒤의 잠금 ────────────────────────────────────────────
## 기록이 끝까지 나오는 순간과 손가락이 두 번째로 눌리는 순간이 겹쳤다.
## 마지막 줄이 뜨자마자 그 클릭이 "다음 대사" 로 먹혀서, 이 이야기의 정체가
## 밝혀지는 유일한 장면이 **읽기도 전에** 넘어갔다.
##
## 다 나온 뒤 이만큼은 안 넘어간다. 스크롤이 바닥까지 내려가는 시간이기도 하다.
const LOG_HOLD_MS: int = 1400


func _ready() -> void:
	_opened_ms = Time.get_ticks_msec()


func _accepts_input() -> bool:
	return Time.get_ticks_msec() - _opened_ms >= INPUT_GUARD_MS


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and _accepts_input():
		_advance()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and _accepts_input():
		_advance()


func _advance() -> void:
	# ── 로그가 흐르는 중이면 먼저 끝까지 뿌린다 ──────────────────────────
	# 예전에는 아무 때나 누르면 다음 대사로 넘어갔다. 그래서 서른 줄짜리
	# 기록이 두 줄쯤 나왔을 때 실수로 눌러 통째로 날아갔고, 그게 이 이야기의
	# 정체가 밝혀지는 유일한 장면이다.
	#
	# 한 번은 "다 보여 줘", 두 번째가 "넘어가" 다. 건너뛸 수는 있되 모르고
	# 지나칠 수는 없게 한다.
	if _log_box != null and _log_box.visible:
		# 다 나왔는데 아직 잠금 시간이 안 지났으면 아무 일도 안 한다.
		# 스크롤이 바닥에 닿았는지도 같이 본다 - 시간만 재면 마지막 줄이
		# 화면 밖에 있는 채로 넘어갈 수 있다.
		if _log_n >= Story.LOG_LINES.size():
			var held := Time.get_ticks_msec() - _log_full_ms
			if _log_full_ms == 0 or held < LOG_HOLD_MS or not _log_settled():
				return
	if _log_box != null and _log_box.visible and _log_n < Story.LOG_LINES.size():
		_log_n = Story.LOG_LINES.size()
		_log_full_ms = Time.get_ticks_msec()
		_log.text = "
".join(Story.LOG_LINES)
		return
	# 찍히는 중이면 먼저 다 찍는다. 같은 규칙이다 - 건너뛸 수는 있되 모르고
	# 지나칠 수는 없게 한다.
	if _typed < float(_full.length()):
		_typed = float(_full.length())
		_lbl_text.text = _full
		return
	index += 1
	if index >= beats.size():
		_restore_music()
		done.emit()
		return
	_show(index)


## 대본이 바꿔 놓은 곡을 되돌린다.
##
## 스테이지 4 도입부는 자기 곡이 있는데, 대본이 끝나고 상점·편성·교전으로
## 넘어가도 그 곡이 계속 흘렀다. 한 대목의 곡이 그 판의 곡이 되어 버린 셈이다.
func _restore_music() -> void:
	if _music_back != "" and _sfx != null and Sfx.music_name() != _music_back:
		_sfx.play_music(_music_back)
	_music_back = ""


func _show(i: int) -> void:
	var b: Dictionary = beats[i]
	(_name_tag as _NameTag).who = String(b.get("speaker", ""))
	# ── 한 글자씩 찍는다 ─────────────────────────────────────────────────
	# 대사가 통째로 튀어나오면 읽는 속도를 화면이 정해 주지 않는다. 한 글자씩
	# 찍히면 눈이 글을 따라가고, 그 사이에 소리가 붙으면 "누가 지금 말하고
	# 있다" 가 된다. 시설 AI 가 화자인 이야기에 특히 맞는 어법이다.
	_full = String(b.get("text", ""))
	_typed = 0.0
	_lbl_text.text = ""

	# ── 화자에 따라 이름 색을 가른다 ─────────────────────────────────────
	# MIRA 는 시설의 목소리다. 사람이 아니므로 감정 색을 주지 않는다 - 흰색.
	# 대원과 그 밖의 사람은 호박색. 색 하나로 "지금 기계가 말하나 사람이
	# 말하나" 가 읽히면, 이야기가 뒤집히는 대목에서 그 차이가 무기가 된다.
	# ── 누가 말하는지를 테두리로도 말한다 ────────────────────────────────
	# 이름 색만으로는 대사판을 볼 때 시선이 이름줄에 한 번 갔다 와야 한다.
	# 판 자체가 색을 띠면 글을 읽기 전에 화자를 안다.
	#
	#   MIRA      하늘색 - 기계의 목소리
	#   대원       호박색 - 사람
	#   나레이션   회색   - 아무도 말하지 않는다
	var speaker := String(b.get("speaker", ""))
	var voice: Color = COL_NARRATION
	if speaker == MIRA_NAME:
		voice = COL_MIRA_EDGE
	elif speaker != "":
		voice = COL_HUMAN
	(_name_tag as _NameTag).tint = voice
	(_name_tag as _NameTag).visible = speaker != ""
	_name_tag.queue_redraw()
	(_bubble as _Panel).tint = voice
	_bubble.queue_redraw()

	# 화자 초상. 대본이 "portrait" 를 적은 대사에서만 뜬다.
	var portrait := String(b.get("portrait", ""))
	_portrait.visible = portrait != ""
	if portrait != "":
		(_portrait as _Portrait).art_id = portrait
		_portrait.queue_redraw()

	# ── 배경 ─────────────────────────────────────────────────────────────
	# 대사마다 따로 지정한다. 안 적으면 **앞 장면의 배경이 그대로 이어진다** -
	# 한 장소에서 대사가 다섯 줄 오갈 때마다 같은 파일 이름을 다섯 번 적는 것은
	# 대본이 할 일이 아니다. 장소를 바꾸고 싶을 때만 적는다.
	#
	# 배경을 걷어내고 싶으면 "none" 이라고 적는다. 빈 문자열은 "그대로" 라서
	# 끄는 뜻으로 못 쓴다.
	# ── 연출 값 ──────────────────────────────────────────────────────────
	# 대본이 정한다. 조용해야 하는 대목(로그 화면·BSOD)은 camera 0 으로 끄고,
	# 무언가 다가오는 대목은 1.5 처럼 올린다.
	_cam_gain = float(b.get("camera", 1.0))
	_zoom_gain = float(b.get("zoom", 1.0))
	_cam_t = 0.0
	_cam_dir = CAM_DIRS[i % CAM_DIRS.size()]
	# 화자가 있는 대사에서만 줌인이 걸린다. 나레이션에 걸면 아무도 안 말하는데
	# 화면이 다가오는 셈이 된다.
	_speak = 1.0 if String(b.get("speaker", "")) != "" else 0.0

	var art := String(b.get("art", _bg_id))
	if art == "none":
		art = ""
	_bg_id = art
	(_art as _ArtSlot).art_id = art
	_art.visible = art != ""
	_art.queue_redraw()

	# ── 음악 ─────────────────────────────────────────────────────────────
	# 같은 어법이다. 적은 대사에서 곡이 바뀌고, 안 적으면 그대로 이어진다.
	# (Sfx.play_music 은 같은 곡이면 아무것도 안 한다 - 다시 시작하지 않는다)
	var bgm := String(b.get("music", ""))
	if bgm != "" and _sfx != null:
		# ── 나갈 때 되돌릴 곡을 적어 둔다 ────────────────────────────────
		# 스테이지 4 도입부는 자기 곡이 있다. 그런데 대본이 끝나고 상점·편성·
		# 교전으로 넘어가도 그 곡이 계속 흘렀다 - 도입부 한 대목의 곡이 그
		# 판의 곡이 되어 버린 것이다.
		#
		# 대본이 곡을 바꾸는 것은 그 대목 동안만이다. 처음 바꾸는 순간의 곡을
		# 기억해 두고 화면을 떠날 때 그것으로 돌아간다.
		if _music_back == "":
			_music_back = Sfx.music_name()
		_sfx.play_music(bgm)

	var fx := String(b.get("fx", ""))
	_log_box.visible = fx == "log"
	if fx == "log":
		# 한 번에 다 뿌리지 않는다. 시설 기록이 차곡차곡 쌓이다가 어느 지점부터
		# 눈이 못 따라갈 속도로 넘어가는 것이 이 장면의 전부다. 그 가속을
		# 글로 설명하지 않고 실제로 그렇게 흐르게 한다.
		_log_t = 0.0
		_log_n = 0
		_log_full_ms = 0
		_log.text = ""
	(_fx as _Glitch).mode = fx
	(_fx as _Glitch).t0 = _t
	_fx.queue_redraw()

	# ── 연출에는 소리가 따라야 한다 ──────────────────────────────────────
	# 화면이 찢어지는데 아무 소리도 안 나면 그건 그림이 잘못 그려진 것처럼
	# 보인다. 짧은 비프 하나면 "장치가 무언가를 알리고 있다" 가 된다.
	#
	# 연출마다 음을 다르게 한다. 같은 소리를 세 곳에 쓰면 셋이 같은 사건으로
	# 들리고, 그러면 이야기가 어디서 꺾이는지 귀로는 알 수 없다.
	#   glitch    높고 짧게 - 신호가 튄다
	#   sync      낮고 무겁게 - 무언가가 진행 중이다
	#   log       중간 - 기록이 넘어간다
	#   collapse  가장 낮게 - 되돌릴 수 없다
	if _sfx != null and fx != "":
		var pitch := 1.0
		match fx:
			"glitch": pitch = 1.45
			"sync": pitch = 0.72
			"log": pitch = 1.0
			"collapse": pitch = 0.55
		_sfx.play("beep", pitch, 0.0)

	# 몰아보기의 구간 표지. 대사가 아니라 목차라 색과 크기를 달리한다.
	var marker := bool(b.get("marker", false))
	_lbl_text.add_theme_color_override("font_color",
		UiKit.ACCENT if marker else UiKit.TEXT)
	_lbl_text.add_theme_font_size_override("font_size", 22 if marker else 17)

	# collapse 는 판을 지운다. "모든 표시가 사라진다" 를 글로 적는 대신 실제로
	# 사라지게 한다 - 이 이야기의 마지막 장면이 그걸 요구한다.
	_bubble.modulate.a = 0.25 if fx == "collapse" else 1.0
	if fx == "glitch" or fx == "collapse":
		_shake = 1.0


func _process(delta: float) -> void:
	_t += delta
	_tick_type(delta)
	_tick_camera(delta)

	if _log_box != null and _log_box.visible:
		_tick_log(delta)
		_log_box.queue_redraw()
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.2)
		position = Vector2(sin(_t * 90.0) * 6.0 * _shake, cos(_t * 71.0) * 4.0 * _shake)
	else:
		position = Vector2.ZERO
	if (_fx as _Glitch).mode != "":
		_fx.queue_redraw()


# ── 조각들 ───────────────────────────────────────────────────────────────

## 배경 아트 자리. 파일이 없으면 회색 네모와 자리 이름만 놓는다.
class _ArtSlot extends Control:
	var art_id: String = ""
	var _img: Control
	var _shown: String = ""

	func _draw() -> void:
		if art_id == "":
			return
		var tex := UiKit.art(["story"], art_id)
		if tex != null:
			# 그림은 노드로 붙인다. draw_texture_rect 는 이 프로젝트에서
			# 흰 사각형이 된다. (UiKit.image 주석 참조)
			if _shown != art_id:
				_shown = art_id
				if _img != null:
					_img.queue_free()
				_img = UiKit.image(self, Rect2(Vector2.ZERO, size), tex, "cover")
				# ── 배경은 뒤로 물린다 ──────────────────
				# 이 그림들은 밝고 채도가 높다. 그대로 두면 인물과 대사판이
				# 배경 위에 얹힌 것이 아니라 **배경과 경쟁**한다. 배경이
				# 하는 일은 "여기가 어디인가" 하나뿐이므로, 그 하나만
				# 남기고 눈에서 물러나야 한다.
				_img.modulate = Color(0.62, 0.66, 0.74)
			# 아래로 갈수록 어두워지는 막. 대사판 뒤가 특히 조용해야 한다.
			var h := size.y
			for i in 12:
				# 아래로 갈수록 가파르게 어두워진다. 대사판이 반투명이라
				# 판 뒤가 밝으면 글자가 통째로 안 읽힌다.
				var a: float = 0.10 + 0.52 * pow(float(i) / 11.0, 2.2)
				draw_rect(Rect2(0, h * float(i) / 12.0, size.x, h / 12.0 + 1.0),
					Color(0.03, 0.04, 0.07, a))
			return
		if _img != null:
			_img.queue_free()
			_img = null
			_shown = ""
		# 아직 안 들어온 배경. 자리만 잡아 둔다.
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.22, 0.23, 0.26))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.42, 0.44, 0.50), false, 1.0)
		draw_string(UiKit.font(12), Vector2(16, size.y - 16),
			"[배경 자리] %s" % art_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(0.6, 0.62, 0.7))


## 대사판. 카드·튜토리얼과 같은 사선 어법.
class _Panel extends Control:
	var tint: Color = UiKit.ACCENT

	func _draw() -> void:
		var s := size
		# 절삭을 20 에서 10 으로 줄였다. 날카롭게 깎을수록 판이 장식이 되는데,
		# 여기는 글을 읽는 자리다.
		var cut := 10.0
		var shape := PackedVector2Array([
			Vector2(cut, 0), Vector2(s.x, 0), Vector2(s.x, s.y - cut),
			Vector2(s.x - cut, s.y), Vector2(0, s.y), Vector2(0, cut),
		])
		# 드롭 섀도. 판이 그림 위에 **떠 있는** 것으로 보이면 그것만으로
		# 글자와 배경이 분리된다.
		var sh := PackedVector2Array()
		for pt in shape:
			sh.append(pt + Vector2(0, 5))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.35))

		# 반투명이되 충분히 어둡게. 뒤가 비치는 것과 글이 안 읽히는 것은
		# 다른 문제다.
		draw_colored_polygon(shape, Color(0.02, 0.025, 0.045, 0.90))
		# 위에서 아래로 아주 옅은 그래디언트. 판이 평평한 색면으로 안 보인다.
		for i in 6:
			draw_rect(Rect2(cut, 1.0 + float(i) * 4.0, s.x - cut - 1, 4.0),
				Color(1, 1, 1, 0.016 - 0.002 * float(i)))

		# 테두리는 얇고 은은하게. 화자를 알리는 일은 이름표가 한다.
		var line := PackedVector2Array(shape)
		line.append(shape[0])
		draw_polyline(line, Color(tint.r, tint.g, tint.b, 0.45), 1.0, true)
		# 왼쪽 위 짧은 강조선 하나만 화자 색으로 남긴다.
		draw_line(Vector2(cut, 0), Vector2(cut + 90.0, 0),
			Color(tint.r, tint.g, tint.b, 0.9), 2.0)


## ── 이름표 ───────────────────────────────────────────────────────────────
## 대사판 위에 얹히는 작은 태그. 판 안에 두면 첫 줄이 밀려 본문이 좁아지고,
## 이름과 대사가 같은 상자 안에서 자리를 다툰다.
class _NameTag extends Control:
	var who: String = ""
	var tint: Color = UiKit.ACCENT

	func _draw() -> void:
		if who == "":
			return
		var f := UiKit.font_role("story")
		var fsz := 21
		var w: float = f.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x + 38.0
		var h := size.y
		var cut := 8.0
		var shape := PackedVector2Array([
			Vector2(cut, 0), Vector2(w, 0), Vector2(w - cut, h), Vector2(0, h),
		])
		draw_colored_polygon(shape, Color(0.02, 0.025, 0.045, 0.94))
		var line := PackedVector2Array(shape)
		line.append(shape[0])
		draw_polyline(line, Color(tint.r, tint.g, tint.b, 0.55), 1.0, true)
		draw_rect(Rect2(cut, 0, 4, h), tint)
		draw_string(f, Vector2(cut + 14.0, h - 11.0), who,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, tint)


## ── 비네팅 ───────────────────────────────────────────────────────────────
## 액자 대신 화면을 닫는다. 위아래로 어둠이 스며들면 시선이 가운데로 모이고,
## 배경이 화면 밖으로 이어지는 것처럼 읽힌다.
class _Vignette extends Control:
	func _draw() -> void:
		var s := size
		var n := 22
		for i in n:
			var f := float(i) / float(n)
			# 위: 짧고 옅게. 아래: 길고 진하게 - 대사판이 앉는 쪽이다.
			draw_rect(Rect2(0, float(i) * 4.0, s.x, 4.0),
				Color(0.01, 0.015, 0.03, 0.42 * (1.0 - f)))
			draw_rect(Rect2(0, s.y - float(i) * 9.0 - 9.0, s.x, 9.0),
				Color(0.01, 0.015, 0.03, 0.60 * (1.0 - f)))


## 화면 깨짐·동기화 표시.
##
## 전부 시간 함수로 그린다. 난수를 쓰면 볼 때마다 달라져서 "버그인가?" 하는
## 첫인상이 흐려진다. 같은 자리에서 같은 모양으로 깨져야 의도된 것으로 읽힌다.
class _Glitch extends Control:
	var mode: String = ""
	var t0: float = 0.0

	func _draw() -> void:
		match mode:
			"glitch", "collapse":
				# ── 찢어진 띠 ────────────────────────────────────────────
				# 얇은 선을 겹치는 것만으로는 "화면에 효과가 얹혔다" 로만 보인다.
				# 굵은 띠를 좌우로 크게 어긋내면 **화면 자체가 찢어진** 것처럼
				# 읽힌다. 이 장면은 플레이어가 잠깐 버그로 착각해야 하므로
				# 효과처럼 예쁘면 안 된다.
				var ms := float(Time.get_ticks_msec())
				for i in 9:
					var y := fmod(float(i) * 151.7 + ms * 0.11, 760.0) - 40.0
					var h := 8.0 + float(i % 5) * 14.0
					var off := sin(float(i) * 1.9 + ms * 0.006) * 90.0
					draw_rect(Rect2(off, y, 1280, h), Color(0.03, 0.05, 0.09, 0.85))
					draw_rect(Rect2(off - 6, y, 1280, 2), Color(0.45, 0.9, 1.0, 0.55))
					draw_rect(Rect2(off + 6, y + h - 2, 1280, 2), Color(1.0, 0.4, 0.5, 0.35))
				# 색 분리. 빨강과 청록을 반대로 밀면 신호가 흐트러진 것처럼 보인다.
				draw_rect(Rect2(-5, 0, 1280, 720), Color(1.0, 0.2, 0.3, 0.05))
				draw_rect(Rect2(5, 0, 1280, 720), Color(0.2, 1.0, 0.9, 0.05))
				# 가로 노이즈 띠 하나가 화면을 훑는다.
				var sweep := fmod(ms * 0.35, 900.0) - 90.0
				draw_rect(Rect2(0, sweep, 1280, 26), Color(0.8, 0.95, 1.0, 0.09))
			"sync":
				# ── 14% 에서 멈춘다 ──────────────────────────────────────
				# 진행 막대는 보통 "곧 끝난다" 를 말하는 물건이다. 14% 에서
				# 멎어 있으면 그 기대가 어긋나고, 그 어긋남이 이 장면의 전부다.
				# 그래서 막대를 크게 놓고 화면을 어둡게 덮어 여기만 보게 한다.
				draw_rect(Rect2(0, 0, 1280, 720), Color(0.01, 0.02, 0.04, 0.82))
				var pct := 14
				var w := 720.0
				var x := (1280.0 - w) * 0.5
				var beat := 0.55 + 0.45 * absf(sin(float(Time.get_ticks_msec()) * 0.004))
				draw_rect(Rect2(x, 352, w, 16), Color(0.10, 0.12, 0.16))
				draw_rect(Rect2(x, 352, w, 16), Color(0.35, 0.75, 1.0, 0.5), false, 1.0)
				draw_rect(Rect2(x, 352, w * float(pct) / 100.0, 16),
					Color(0.45, 0.85, 1.0, beat))
				# 눈금. 100% 가 어디인지 보여야 14% 가 얼마나 모자란지 읽힌다.
				for i in 11:
					var tx := x + w * float(i) / 10.0
					draw_line(Vector2(tx, 372), Vector2(tx, 378),
						Color(0.35, 0.75, 1.0, 0.35), 1.0)
				draw_string(UiKit.font_role("large"), Vector2(x, 336),
					"MEMORY SYNCHRONIZATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
					Color(0.55, 0.88, 1.0))
				draw_string(UiKit.font_role("large"), Vector2(x + w - 70, 336),
					"%d%%" % pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
					Color(0.45, 0.85, 1.0, beat))
				draw_string(UiKit.font(11), Vector2(x, 398),
					"... 동기화가 진행되지 않습니다", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
					Color(0.5, 0.6, 0.7))


## 로그가 흐르는 속도.
##
## 앞부분(평범한 시설 기록)은 한 줄씩 천천히 올라가고, 뒤로 갈수록 가속한다.
## 그 가속이 "무언가 일어났다" 를 말한다 - 글로 설명하지 않는다.
## ── 로그는 한 줄씩, 천천히 ───────────────────────────────────────────────
## 예전에는 뒤로 갈수록 빨라져 마지막 열 줄이 한 프레임에 쏟아졌다. "가속" 은
## 의도였지만 결과는 그냥 안 읽히는 화면이었다.
##
## 아날로그 호러의 무서움은 속도가 아니라 **속도가 일정하다는 것**에서 온다.
## 기계가 사람 사정과 무관하게 제 박자로 계속 뱉는다. 그래서 한 줄에 0.34초로
## 고정하고, 종이가 밀려 올라가듯 화면도 그만큼씩만 흐르게 한다.
const LOG_LINE_SEC: float = 0.34
const LOG_LINE_H: float = 17.0

## 대사를 한 글자씩 찍는다. 다 찍으면 아무것도 안 한다.
## ── 카메라를 민다 ───────────────────────────────────────────────────────
## 배경과 초상을 각각 조금씩 움직인다. 배경은 계속 표류하고, 초상은 말하기
## 시작할 때만 한 번 커졌다 가라앉는다.
##
## pivot_offset 을 가운데로 잡아 두고 scale 만 만진다. position 으로 확대를
## 흉내 내면 크기가 커질수록 그림이 한쪽으로 밀린다.
func _tick_camera(delta: float) -> void:
	_cam_t += delta
	if _speak > 0.0:
		_speak = maxf(0.0, _speak - delta * SPEAK_SETTLE)

	if _art != null and is_instance_valid(_art):
		var t := _cam_t * CAM_SPEED * TAU
		var k: float = 1.0 + (CAM_ZOOM * _cam_gain) * (0.5 - 0.5 * cos(t))
		_art.pivot_offset = _art.size * 0.5
		_art.scale = Vector2(k, k)
		# 표류는 확대된 만큼 안쪽으로만 움직인다. 안 그러면 가장자리에 빈틈이
		# 생긴다 - 배경이 화면 끝까지 차 있어야 하는 화면이다.
		var reach: float = CAM_DRIFT * _cam_gain
		_art.position = _art_home + _cam_dir.normalized() * reach 			* (1.0 - cos(t)) * 0.5

	if _portrait != null and is_instance_valid(_portrait) and _portrait.visible:
		# 말하기 시작한 순간이 가장 크고, 곧 제자리로 돌아온다. 계속 커져
		# 있으면 그건 확대이지 연출이 아니다.
		var pz: float = 1.0 + SPEAK_ZOOM * _zoom_gain * _speak
		_portrait.pivot_offset = Vector2(_portrait.size.x * 0.5, _portrait.size.y)
		_portrait.scale = Vector2(pz, pz)


func _tick_type(delta: float) -> void:
	if _lbl_text == null or _typed >= float(_full.length()):
		return
	var before := int(_typed)
	_typed = minf(_typed + delta * TYPE_CPS, float(_full.length()))
	var now := int(_typed)
	if now == before:
		return
	_lbl_text.text = _full.substr(0, now)
	# 공백에서는 소리를 내지 않는다. 띄어쓰기마다 딸깍하면 말이 아니라
	# 기계 소음으로 들린다.
	if now % TYPE_SFX_EVERY == 0 and _full[now - 1].strip_edges() != "":
		# dedupe 를 꺼야 한다. 기본 0.045초는 초당 34글자를 통째로 지운다.
		_sfx.play("typing", 0.94 + float(now % 5) * 0.03, 0.0)


func _tick_log(delta: float) -> void:
	if _log_n < Story.LOG_LINES.size():
		_log_t += delta
		while _log_n < Story.LOG_LINES.size() and _log_t > LOG_LINE_SEC:
			_log_t -= LOG_LINE_SEC
			_log_n += 1
			# 두 줄에 한 번만 울린다. 줄마다 울리면 소리가 벽이 되고,
			# 벽이 된 소리는 아무것도 안 알린다. 음도 조금씩 흔든다 -
			# 똑같은 음이 반복되면 기계가 아니라 메트로놈으로 들린다.
			if _sfx != null and _log_n % 2 == 0:
				_sfx.play("beep", 1.6 + float(_log_n % 5) * 0.06, 0.0)
			_log.text = "
".join(Story.LOG_LINES.slice(0, _log_n))
			if _log_n >= Story.LOG_LINES.size():
				_log_full_ms = Time.get_ticks_msec()

	# ── 스크롤은 따로, 부드럽게 ──────────────────────────────────────────
	# 줄이 늘 때마다 위치를 툭 바꾸면 글이 한 칸씩 튄다. 목표 지점을 정해 두고
	# 매 프레임 그쪽으로 조금씩 다가가면 종이가 밀려 올라가는 것처럼 흐른다.
	var want: float = _log_scroll_target()
	_log.position.y = lerpf(_log.position.y, want, clampf(delta * 6.0, 0.0, 1.0))


## 기록이 바닥까지 내려왔는가. 넘어가도 되는지 판단할 때 쓴다.
func _log_settled() -> bool:
	return absf(_log.position.y - _log_scroll_target()) <= 2.0


func _log_scroll_target() -> float:
	return 8.0 - maxf(0.0, float(_log_n) * LOG_LINE_H - 348.0)


## 파란 홀로그램 판. 스캔라인과 노이즈.
##
## 시설 로그는 화면이 아니라 **투영**이어야 한다. 판을 파랗게 깔고 가로선을
## 겹치면 그것만으로 "여기 띄워진 것" 이 된다. 노이즈는 고정 시드 LCG 로
## 만든다 - 볼 때마다 다르면 연출이 아니라 잡음으로 읽힌다.
class _Holo extends Control:
	func _draw() -> void:
		var s := size
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.12, 0.20, 0.92))
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.35, 0.75, 1.0, 0.55), false, 1.5)

		# 스캔라인. 3px 간격으로 한 줄씩 어둡게 깐다.
		var y := 0.0
		while y < s.y:
			draw_line(Vector2(0, y), Vector2(s.x, y), Color(0, 0, 0, 0.22), 1.0)
			y += 3.0

		# 흐르는 밝은 띠. 이게 있어야 정지 화면으로 안 보인다.
		var band := fmod(float(Time.get_ticks_msec()) * 0.09, s.y + 120.0) - 60.0
		draw_rect(Rect2(0, band, s.x, 40), Color(0.45, 0.85, 1.0, 0.06))

		# 노이즈. 고정 시드 LCG 라 매번 같은 자리에 낀다.
		var seed_v: int = 20260806
		for i in 90:
			seed_v = (seed_v * 1103515245 + 12345) & 0x7FFFFFFF
			var nx := float(seed_v % maxi(1, int(s.x)))
			seed_v = (seed_v * 1103515245 + 12345) & 0x7FFFFFFF
			var ny := float(seed_v % maxi(1, int(s.y)))
			draw_rect(Rect2(nx, ny, 2, 1), Color(0.6, 0.9, 1.0, 0.16))


## 화자 초상. 대사판 위로 반신이 올라온다.
##
## 아래를 잘라 낸다 - 미연시가 인물을 무릎에서 자르는 이유와 같다. 발끝까지
## 보이면 인물이 작아지고, 얼굴이 화면에서 차지하는 비율이 그만큼 줄어든다.
##
## 그림은 TextureRect 자식으로 붙인다. _draw() 안의 draw_texture_rect 는 이
## 프로젝트에서 텍스처를 흰 사각형으로 칠한다(SD 얼굴·지형 배경에서 두 번 겪었다).
class _Portrait extends Control:
	var art_id: String = ""
	var _tr: TextureRect

	func _ready() -> void:
		clip_contents = true
		_tr = TextureRect.new()
		# 이 한 줄이 빠지면 TextureRect 의 최소 크기가 텍스처 크기라, size 를
		# 아무리 작게 줘도 원본 크기로 되돌아간다. 896x1182 짜리 그림이
		# 360x420 칸 안에서 원본 배율로 그려져 **얼굴만 꽉 차** 있었다.
		# 편성 얼굴 타일에서 이미 한 번 겪은 함정이다.
		_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_tr.stretch_mode = TextureRect.STRETCH_SCALE
		_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_tr)
		_apply()

	func _draw() -> void:
		_apply()

	func _apply() -> void:
		if _tr == null:
			return
		var tex := UiKit.art(["standing", "portraits"], art_id) if art_id != "" else null
		_tr.texture = tex
		if tex == null:
			return
		# ── 폭을 맞춘다 ──────────────────────────────────────────────────
		# 세로에 맞추면 그림마다 키가 제각각이 된다. 어떤 그림은 전신이고
		# (궁수 827x1177) 어떤 그림은 흉상이라(전사 1200x787), 같은 높이로
		# 그리면 흉상의 얼굴이 전신의 두 배로 나온다.
		#
		# 이 그림들은 공통적으로 인물이 프레임 **폭**을 거의 채운다. 그래서
		# 폭을 맞추면 어깨 너비가 맞고, 어깨가 맞으면 얼굴도 맞는다.
		# 세로는 자유롭게 두고 발치를 대사판에 붙인다 - 흉상은 짧게, 전신은
		# 길게 서면 그게 자연스럽다.
		var ts := Vector2(tex.get_width(), tex.get_height())
		if ts.y <= 0.0 or ts.x <= 0.0:
			return
		var fit: Dictionary = PORTRAIT_FIT.get(art_id, {})
		var k: float = size.x / ts.x * float(fit.get("k", 1.0))
		_tr.size = ts * k
		_tr.position = Vector2(
			(size.x - _tr.size.x) * 0.5 + size.x * float(fit.get("x", 0.0)),
			size.y - _tr.size.y + size.y * float(fit.get("y", 0.0)))
