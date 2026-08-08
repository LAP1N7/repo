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
	# ── 가로를 꽉 채운다 ────────────────────────────────────────────────
	# 세로에 맞추면 폭이 1160 이라 왼쪽 120px 가 맨바닥으로 남는다. 그 위에
	# 검은 천을 덮어 가리고 있었는데, 천의 그라디언트 끝과 영상의 왼쪽 끝이
	# 정확히 겹치지 않으면 세로 이음선이 그대로 보인다. 실제로 화면 왼쪽에
	# 다른 색 띠가 났다.
	#
	# 가로를 1280 에 맞추면 이음선 자체가 사라진다. 대신 세로가 795 가 되어
	# 아래 75px 가 화면 밖으로 나가는데, 원본에서 머리 꼭대기가 프레임 위쪽
	# 3% 지점이라 **위에서 자르면 안 되고 아래는 잘라도 된다.** 잘리는 쪽이
	# 인물의 아랫도리라 손해가 없다.
	var h := 1280.0 / VIDEO_ASPECT
	v.position = Vector2.ZERO
	v.size = Vector2(1280.0, h)
	add_child(v)
	v.play()
	# 5초짜리라 그냥 두면 한 번 돌고 멈춘다.
	v.finished.connect(func(): v.play())
	return v


## ── 메뉴는 판이 아니라 글자다 ────────────────────────────────────────────
## 회색 상자 세 개가 세로로 쌓여 있으면 그건 메뉴가 아니라 양식 입력란이다.
## HADES·명일방주 계열의 시작 화면은 버튼을 그리지 않는다 - 글자만 놓고,
## 지금 가리키는 것에만 표시를 준다.
##
## 배경에 인물이 있는 화면이라 더 그렇다. 판을 깔면 그만큼 그림을 가린다.
func _menu(at: Vector2, text: String, h: float) -> Button:
	var b := Button.new()
	b.position = at
	b.size = Vector2(340, h + 12.0)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	var blank := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, blank)
	add_child(b)

	# 글자와 판은 자식이 그린다. Button 은 제 글자를 먼저 그리고 그 위에
	# _draw() 가 얹히므로, 판을 직접 그리면 글자가 통째로 덮인다.
	var face := _MenuFace.new()
	face.host = b
	face.label = text
	face.position = Vector2.ZERO
	face.size = b.size
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(face)
	return b


## ── 메뉴 한 줄 ───────────────────────────────────────────────────────────
## 글자만 놓여 있으면 "누를 수 있는 것" 으로 안 읽힌다. 그렇다고 회색 상자를
## 깔면 배경 인물을 가리고 양식 입력란처럼 보인다.
##
## 그래서 판은 **가리킬 때만** 나온다. 왼쪽에서 오른쪽으로 옅어지는 반투명
## 띠가 깔리고, 왼쪽에 갈매기 표시와 세로 막대가 서고, 오른쪽 끝에서 얇은
## 선이 뻗는다. 평소에는 글자뿐이라 그림을 안 가리고, 손을 올리면 그 줄만
## 계기판처럼 켜진다.
class _MenuFace extends Control:
	var host: Button
	var label: String = ""

	## 켜짐 정도. 0~1 사이를 부드럽게 오간다 - 딸깍 켜지면 싸구려로 보인다.
	var _on: float = 0.0

	func _process(delta: float) -> void:
		var want: float = 1.0 if (host != null and host.is_hovered()) else 0.0
		var prev := _on
		_on = lerpf(_on, want, clampf(delta * 12.0, 0.0, 1.0))
		if absf(_on - prev) > 0.001:
			queue_redraw()

	func _draw() -> void:
		var s := size
		var a := _on
		if a > 0.01:
			# 왼쪽에서 오른쪽으로 옅어지는 띠. 한 겹씩 나눠 그린다 -
			# 그라디언트 텍스처를 만들 것까지도 없다.
			for i in 10:
				var f := float(i) / 10.0
				draw_rect(Rect2(s.x * f, 2, s.x * 0.1 + 1.0, s.y - 4),
					Color(0.30, 0.62, 0.86, (0.22 - 0.02 * float(i)) * a))
			# 위아래 규칙선. 밝은 프레임에서도 줄의 경계가 남는다.
			draw_rect(Rect2(0, 1, s.x * (0.25 + 0.75 * a), 1),
				Color(0.55, 0.85, 1.0, 0.55 * a))
			draw_rect(Rect2(0, s.y - 2, s.x * (0.25 + 0.75 * a), 1),
				Color(0.55, 0.85, 1.0, 0.35 * a))
			# 발광. 띠 뒤로 한 겹 더 깔아 줄 전체가 켜진 것처럼 보이게 한다.
			for g in 3:
				draw_rect(Rect2(-2.0 - float(g) * 2.0, 1.0 - float(g),
					s.x * 0.55, s.y - 2.0 + float(g) * 2.0),
					Color(1.0, 0.72, 0.28, 0.05 * a))

		# 왼쪽 표시. 세로 막대 + 갈매기. 켜질수록 오른쪽으로 조금 나온다.
		var px := -18.0 + 4.0 * a
		draw_rect(Rect2(px, s.y * 0.22, 3, s.y * 0.56),
			Color(1.0, 0.78, 0.30, 0.25 + 0.75 * a))
		if a > 0.05:
			var cy := s.y * 0.5
			draw_polyline(PackedVector2Array([
				Vector2(px + 8, cy - 5), Vector2(px + 13, cy), Vector2(px + 8, cy + 5),
			]), Color(1.0, 0.82, 0.35, a), 2.0, true)

		var f2 := UiKit.title_font()
		var col := Color(0.86, 0.88, 0.94).lerp(Color(1, 1, 1), a)
		var at := Vector2(14.0 + 6.0 * a, s.y * 0.5 + 10.0)
		# 배경이 밝은 프레임에서도 읽히도록 그림자와 외곽선을 깐다.
		draw_string(f2, at + Vector2(2, 2), label, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 26, Color(0, 0, 0, 0.65))
		draw_string_outline(f2, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 5,
			Color(0.02, 0.03, 0.05, 0.85))
		# ── 가리키면 색이 어긋난다 ───────────────────────────────────────
		# 색수차 한 겹이면 글자가 "신호" 로 읽힌다. 두 겹을 반대 방향으로
		# 아주 조금 어긋나게 깔고 그 위에 본문을 얹는다. 켜짐 정도에 비례하니
		# 손을 떼면 저절로 사라진다.
		if a > 0.02:
			draw_string(f2, at + Vector2(-1.5 * a, 0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.30, 0.36, 0.45 * a))
			draw_string(f2, at + Vector2(1.5 * a, 0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.30, 0.85, 1.0, 0.45 * a))
		draw_string(f2, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col)


## ── 제목 로고 ────────────────────────────────────────────────────────────
## 그림자 · 외곽선 · 본문을 겹쳐 그리고, 위아래로 규칙선을 그어 조판된 표제로
## 만든다. 자간을 손으로 벌리는 것은 draw_string 이 자간을 안 받기 때문이다 -
## 글자를 하나씩 놓으면 그만큼 로고타이프에 가까워진다.
class _Logo extends Control:
	const TITLE_SIZE: int = 58
	const TRACK: float = 3.0

	func _draw() -> void:
		var f := UiKit.title_font()
		var text := UiText.t("title.name", "PROJECT RECLAIM")
		var w := _draw_tracked(f, text, Vector2(0, 62), TITLE_SIZE, TRACK, true)

		# 규칙선. 표제를 위아래로 가두면 그 자체가 판처럼 읽힌다.
		draw_rect(Rect2(0, 8, w, 2), Color(0.72, 0.86, 1.0, 0.55))
		draw_rect(Rect2(0, 78, w, 1), Color(0.72, 0.86, 1.0, 0.30))
		# 오른쪽 끝의 짧은 눈금 셋. 계기판 어법이다.
		for i in 3:
			draw_rect(Rect2(w - 30.0 + float(i) * 10.0, 78, 5, 5),
				Color(1.0, 0.78, 0.30, 0.75 - 0.2 * float(i)))

		_draw_tracked(f, UiText.t("title.name_ko", "프로젝트 리클레임"),
			Vector2(2, 116), 22, 4.0, false)

	## 글자를 하나씩 놓아 자간을 벌린다. 돌려주는 값은 전체 폭이다.
	func _draw_tracked(f: Font, text: String, at: Vector2, fsize: int,
			track: float, heavy: bool) -> float:
		var x := at.x
		for i in text.length():
			var ch := text[i]
			var adv: float = f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT,
				-1, fsize).x
			var p := Vector2(x, at.y)
			if heavy:
				# 아래로 떨어지는 그림자. 배경이 밝아도 글자가 뜬다.
				draw_string(f, p + Vector2(3, 4), ch, HORIZONTAL_ALIGNMENT_LEFT,
					-1, fsize, Color(0, 0, 0, 0.55))
				# 검은 외곽선. 인물의 머리칼 위에서도 윤곽이 남는다.
				draw_string_outline(f, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1,
					fsize, 6, Color(0.02, 0.03, 0.05, 0.9))
				draw_string(f, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
					Color(1, 1, 1))
			else:
				draw_string_outline(f, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1,
					fsize, 4, Color(0.02, 0.03, 0.05, 0.85))
				draw_string(f, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
					Color(0.72, 0.78, 0.88))
			x += adv + track
		return x - at.x - track


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

	# ── 제목은 라벨이 아니라 로고다 ─────────────────────────────────────
	# Label 로 얹으면 서체 그대로의 맨 글자라, 밝은 프레임에서 인물의 머리칼과
	# 섞여 묻힌다. 게임의 얼굴이 배경에 지는 것은 그 자체로 실패다.
	#
	# 직접 그려서 세 겹을 얹는다: 아래로 떨어지는 그림자 · 검은 외곽선 ·
	# 본문. 여기에 자간을 벌리고 위아래로 얇은 규칙선을 그으면, 같은 서체인데
	# 조판된 로고로 읽힌다. SF·밀리터리 표제가 쓰는 오래된 방법이다.
	var logo := _Logo.new()
	logo.position = Vector2(TEXT_X, 112)
	logo.size = Vector2(TEXT_W + 60, 190)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)

	var sub := UiKit.label(self, Vector2(TEXT_X + 2, 306), Vector2(TEXT_W, 30),
		UiText.t("title.sub", "규칙을 짜서 AI를 싸우게 하는 격자 오토배틀러"),
		15, Color(0.62, 0.70, 0.82))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	var b1 := _menu(Vector2(TEXT_X, 372), UiText.t("title.start", "작전 개시"), 30)
	b1.pressed.connect(func():
		sfx.play("click")
		start_run.emit()
	)

	var b2 := _menu(Vector2(TEXT_X, 442), UiText.t("title.tutorial", "훈련 과정"), 30)
	b2.pressed.connect(func(): start_tutorial.emit())

	# ── 왜 규칙 요약 대신 스토리인가 ────────────────────────────────────
	# 규칙 요약은 상점 화면에도 [게임 방법] 으로 있다. 같은 것을 두 군데 둘
	# 이유가 없고, 지금 더 급한 건 대본을 고칠 때마다 다섯 판을 다시 이기지
	# 않고 이야기만 확인하는 길이다.
	var b3 := _menu(Vector2(TEXT_X, 512), UiText.t("title.story", "기록 열람"), 30)
	b3.pressed.connect(func(): show_help.emit())

	# 콘텐츠 개수(스테이지 5개 · 카드 18종 …)는 뺐다.
	# 타이틀에서 그 숫자를 보고 판단할 사람은 없고, 시작 화면은 무엇을 누를지만
	# 분명하면 된다.

	# 오프닝 테마. 화면을 넘어가도 이어지도록 배경음악 경로로 튼다.
	sfx.play_music("opening_theme")

	# 브라우저에서는 조작 전까지 소리를 못 낸다. 가만히 기다리는 사람에게는
	# 그냥 "음악이 없는 게임" 으로 보이므로, 왜 조용한지 한 줄 알린다.
	# 잠금이 풀리면 스스로 사라진다.
	# 11px MUTED 는 영상 위에서 사실상 안 보였다. 이건 "왜 조용한가" 를 알리는
	# 유일한 줄이라 안 보이면 있으나 마나다.
	_lbl_audio = UiKit.label(self, Vector2(TEXT_X, 596), Vector2(560, 24), "", 13,
		Color(1.0, 0.80, 0.42))

	# ── 출처 ─────────────────────────────────────────────────────────────
	# 영상에 박혀 있던 워터마크는 잘라 냈다. 제목 화면 한복판에 생성 도구
	# 로고가 있는 것과, 출처를 밝히는 것은 다른 일이다.
	#
	# 밝히긴 해야 하므로 화면 맨 아래에 작게 한 줄로 남긴다. 읽으려면 읽히고,
	# 안 찾으면 안 보이는 크기다.
	if _video != null:
		var cr := UiKit.label(self, Vector2(0, 696), Vector2(1268, 16),
			UiText.t("title.credit", "opening video · KlingAI 3.0"), 9,
			Color(UiKit.FAINT.r, UiKit.FAINT.g, UiKit.FAINT.b, 0.55))
		cr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


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
		# ── 위아래 띠 ────────────────────────────────────────────────────
		# 왼쪽 기둥만 덮고 있었다. 그런데 제목은 화면 위쪽 끝까지 올라가고
		# 안내 문구는 아래쪽 끝에 붙어서, 영상이 밝아지는 프레임마다 그
		# 둘이 통째로 묻혔다. 가로 전체에 얇게 깔면 글이 뜬다.
		for i in 26:
			var f := float(i) / 26.0
			draw_rect(Rect2(0, float(i) * 5.0, size.x, 5.0),
				Color(dark.r, dark.g, dark.b, 0.55 * (1.0 - f)))
			draw_rect(Rect2(0, size.y - float(i) * 6.0 - 6.0, size.x, 6.0),
				Color(dark.r, dark.g, dark.b, 0.66 * (1.0 - f)))
		var steps := 40
		var span := FADE_X - SOLID_X
		for i in steps:
			var t := float(i) / float(steps)
			# 처음엔 천천히, 뒤로 갈수록 빨리 옅어진다. 직선으로 빼면 중간에
			# 띠가 하나 보인다.
			var a: float = 0.94 * pow(1.0 - t, 1.8)
			draw_rect(Rect2(SOLID_X + span * t, 0, span / float(steps) + 1.0, size.y),
				Color(dark.r, dark.g, dark.b, a))
