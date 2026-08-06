class_name TitleScreen
extends Control

## 메인 화면. (DESIGN D6)

signal start_run()
signal show_help()
signal start_tutorial()



## 타이틀에서만 쓰는 효과음. 화면이 살아 있는 동안만 존재하면 된다.
var sfx: Sfx


## 글이 앉는 왼쪽 기둥. 영상 속 인물은 오른쪽에 둔다.
const TEXT_X: float = 88.0
const TEXT_W: float = 520.0

## 영상은 이만큼만 보인다. 배경이지 그림이 아니다 - 눈에 띄면 그 순간 실패다.
const VIDEO_ALPHA: float = 0.62

## ── 영상이 놓이는 자리 ───────────────────────────────────────────────────
## 세로를 하나도 안 자른다. 원본에서 머리 꼭대기가 프레임 위쪽 3% 지점이라,
## 조금만 잘라도 정수리가 날아간다. 실제로 -146 으로 깔았다가 머리가 잘렸다.
##
## 그래서 높이를 720 에 맞추고 오른쪽에 붙인다. 폭이 1053 이라 왼쪽 227px 가
## 비는데, 거기가 마침 **글이 앉는 자리**다. 검은 천으로 덮으면 빈자리도
## 이음선도 같이 사라진다 - 가려야 할 것과 비는 곳이 같은 자리인 셈이다.
## 928x576 (아래를 잘라 워터마크를 뺐다). 1.611:1
const VIDEO_ASPECT: float = 1.611
const VIDEO_H: float = 720.0

var _video: VideoStreamPlayer


## 오프닝 영상을 붙인다. 파일이 없으면 null 을 돌려주고 화면은 그대로 돈다.
func _make_video() -> VideoStreamPlayer:
	var path := "res://assets/video/opening_scene.ogv"
	if not ResourceLoader.exists(path):
		return null
	var st = load(path)
	if not (st is VideoStream):
		return null
	var v := VideoStreamPlayer.new()
	v.stream = st
	v.expand = true
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.modulate = Color(1, 1, 1, VIDEO_ALPHA)
	# 인물이 화면 한가운데라, 오른쪽으로 밀어 왼쪽에 글 자리를 비운다.
	# 위아래는 잘려도 좋다 - 인물의 얼굴과 상반신만 살면 된다.
	var w := VIDEO_H * VIDEO_ASPECT
	v.position = Vector2(1280.0 - w, 0.0)
	v.size = Vector2(w, VIDEO_H)
	add_child(v)
	v.play()
	# 5초짜리라 그냥 두면 한 번 돌고 멈춘다.
	v.finished.connect(func(): v.play())
	return v


func setup() -> void:
	sfx = Sfx.new()
	add_child(sfx)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = UiKit.BG
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# ── 오프닝 영상 ──────────────────────────────────────────────────────
	# MIRA 가 화면 한가운데 서서 홀로그램을 들고 있다. 그대로 깔면 제목과
	# 버튼이 얼굴 위에 얹힌다.
	#
	# 영상을 오른쪽으로 밀어 인물이 오른쪽 3분의 2에 오게 하고, 글자와 버튼은
	# 왼쪽에 세로로 쌓는다. 미연시·비주얼노벨 표지가 오래전부터 쓰는 배치다 -
	# 인물과 글이 자리를 두고 다투지 않는다.
	#
	# 없어도 게임은 그대로 돈다. 영상이 안 붙으면 예전처럼 격자만 남는다.
	_video = _make_video()

	# 배경 격자. 이 게임이 무엇 위에서 벌어지는지 한눈에 보이게 한다.
	# 영상이 있으면 격자는 아주 옅게만 깐다 - 둘 다 진하면 서로를 지운다.
	var grid := _GridDeco.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.modulate.a = 0.35 if _video != null else 1.0
	add_child(grid)

	# 왼쪽에 글이 앉을 자리를 어둡게 깔아 준다. 영상 위에 흰 글자를 그냥 얹으면
	# 밝은 프레임에서 통째로 안 읽힌다.
	var veil := _Veil.new()
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.visible = _video != null
	add_child(veil)

	# 게임 이름만 전용 서체를 쓴다. 굵고 장식적이어도 되는 유일한 자리다.
	var t := UiKit.label(self, Vector2(TEXT_X, 120), Vector2(TEXT_W, 110),
		UiText.t("title.name", "PROJECT RECLAIM"), 64)
	t.add_theme_font_override("font", UiKit.title_font())
	# 빛의계승자는 세리프라 글자 자체가 위아래로 크다. 라벨 높이를 넉넉히 주지
	# 않으면 아래 줄과 글자가 겹친다.
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	# 한글 부제도 제목 폰트로 쓴다. 영문 제목과 한글 부제는 **같은 이름**인데
	# 서체가 다르면 두 개의 다른 문구처럼 보인다. 같은 서체로 묶어야 한 덩어리로
	# 읽힌다. 빛의계승자는 세리프라 한글도 획이 살아 있다.
	var t_ko := UiKit.label(self, Vector2(TEXT_X, 226), Vector2(TEXT_W, 40),
		UiText.t("title.name_ko", "프로젝트 리클레임"), 24, UiKit.MUTED)
	t_ko.add_theme_font_override("font", UiKit.title_font())
	t_ko.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	var sub := UiKit.label(self, Vector2(TEXT_X, 266), Vector2(TEXT_W, 30),
		UiText.t("title.sub", "규칙을 짜서 AI를 싸우게 하는 격자 오토배틀러"), 17, UiKit.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	var tag := UiKit.label(self, Vector2(TEXT_X, 296), Vector2(TEXT_W, 48),
		UiText.t("title.tagline", "내가 조종하는 건 캐릭터가 아니라 캐릭터의 사고방식이다."),
		15, UiKit.ACCENT, true)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	var b1 := UiKit.button(self, Vector2(TEXT_X, 372), Vector2(300, 56), UiText.t("title.start", "런 시작"), 22)
	b1.pressed.connect(func():
		sfx.play("click")
		start_run.emit()
	)

	var b2 := UiKit.button(self, Vector2(TEXT_X, 442), Vector2(300, 46), UiText.t("title.tutorial", "튜토리얼"), 17)
	b2.pressed.connect(func(): start_tutorial.emit())

	# ── 왜 규칙 요약 대신 스토리인가 ────────────────────────────────────
	# 규칙 요약은 상점 화면에도 [게임 방법] 으로 있다. 같은 것을 두 군데 둘
	# 이유가 없고, 지금 더 급한 건 대본을 고칠 때마다 다섯 판을 다시 이기지
	# 않고 이야기만 확인하는 길이다.
	var b3 := UiKit.button(self, Vector2(TEXT_X, 500), Vector2(300, 36),
		UiText.t("title.story", "스토리 몰아보기"), 14)
	b3.pressed.connect(func(): show_help.emit())

	# 콘텐츠 개수(스테이지 5개 · 카드 18종 …)는 뺐다.
	# 타이틀에서 그 숫자를 보고 판단할 사람은 없고, 시작 화면은 무엇을 누를지만
	# 분명하면 된다.

	# 오프닝 테마. 화면을 넘어가도 이어지도록 배경음악 경로로 튼다.
	sfx.play_music("opening_theme")

	# 브라우저에서는 조작 전까지 소리를 못 낸다. 가만히 기다리는 사람에게는
	# 그냥 "음악이 없는 게임" 으로 보이므로, 왜 조용한지 한 줄 알린다.
	# 잠금이 풀리면 스스로 사라진다.
	_lbl_audio = UiKit.label(self, Vector2(290, 574), Vector2(700, 20), "", 11, UiKit.MUTED)
	_lbl_audio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


var _lbl_audio: Label


## 음악이 안 울릴 때만 그 이유를 띄운다. 정상이면 아무것도 안 보인다.
##
## 브라우저는 조작 전까지 소리를 못 내는데, 가만히 기다리는 사람에게는 그냥
## "음악이 없는 게임" 으로 보인다. 왜 조용한지는 알려 줘야 한다.
func _process(_d: float) -> void:
	if _lbl_audio == null:
		return
	if not Sfx.audio_open():
		_lbl_audio.text = UiText.t("title.audio_locked",
			"화면을 한 번 누르면 음악이 재생됩니다.")
		_lbl_audio.visible = true
		return
	if Sfx.music_playing():
		_lbl_audio.visible = false
		return
	_lbl_audio.text = UiText.t("title.audio_fail", "음악 재생 실패 · %s") % Sfx.diagnose()
	_lbl_audio.visible = true


## 타이틀 배경의 격자 장식. 전투 화면과 같은 타일 크기를 써서 톤을 맞춘다.
class _GridDeco extends Control:
	func _draw() -> void:
		var origin := Vector2(384, 96)
		for y in Grid.H:
			for x in Grid.W:
				var r := Rect2(origin + Vector2(x * Grid.TILE, y * Grid.TILE),
					Vector2(Grid.TILE, Grid.TILE))
				draw_rect(r, Color(0.11, 0.12, 0.16, 0.5) if (x + y) % 2 == 0
					else Color(0.10, 0.11, 0.14, 0.5))
		for x in Grid.W + 1:
			draw_line(origin + Vector2(x * Grid.TILE, 0),
				origin + Vector2(x * Grid.TILE, Grid.H * Grid.TILE),
				Color(0.22, 0.24, 0.30, 0.5), 1.0)
		for y in Grid.H + 1:
			draw_line(origin + Vector2(0, y * Grid.TILE),
				origin + Vector2(Grid.W * Grid.TILE, y * Grid.TILE),
				Color(0.22, 0.24, 0.30, 0.5), 1.0)


## 왼쪽 글 자리를 어둡게 덮는 천.
##
## 영상 위에 흰 글자를 그냥 얹으면 밝은 프레임에서 통째로 안 읽힌다. 왼쪽에서
## 오른쪽으로 옅어지는 그라데이션을 깔면, 글이 앉는 자리만 어둡고 인물 쪽은
## 그대로 보인다.
class _Veil extends Control:
	## 여기까지는 꽉 덮는다. 영상의 왼쪽 변(x=227)이 이 안에 들어와야 이음선이
	## 안 보인다. 글 기둥(88~608)의 앞부분과도 겹친다.
	const SOLID_X: float = 300.0
	## 여기서 완전히 사라진다. 인물 쪽은 건드리지 않는다.
	const FADE_X: float = 760.0

	func _draw() -> void:
		var dark := Color(0.03, 0.04, 0.06)
		draw_rect(Rect2(0, 0, SOLID_X, size.y), Color(dark.r, dark.g, dark.b, 0.94))
		var steps := 40
		var span := FADE_X - SOLID_X
		for i in steps:
			var t := float(i) / float(steps)
			# 처음엔 천천히, 뒤로 갈수록 빨리 옅어진다. 직선으로 빼면 중간에
			# 띠가 하나 보인다.
			var a: float = 0.94 * pow(1.0 - t, 1.8)
			draw_rect(Rect2(SOLID_X + span * t, 0, span / float(steps) + 1.0, size.y),
				Color(dark.r, dark.g, dark.b, a))
