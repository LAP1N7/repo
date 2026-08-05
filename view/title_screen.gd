class_name TitleScreen
extends Control

## 메인 화면. (DESIGN D6)

signal start_run()
signal show_help()
signal start_tutorial()



## 타이틀에서만 쓰는 효과음. 화면이 살아 있는 동안만 존재하면 된다.
var sfx: Sfx


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

	# 배경 격자. 이 게임이 무엇 위에서 벌어지는지 한눈에 보이게 한다.
	var grid := _GridDeco.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(grid)

	# 게임 이름만 전용 서체를 쓴다. 굵고 장식적이어도 되는 유일한 자리다.
	var t := UiKit.label(self, Vector2(0, 132), Vector2(1280, 110),
		UiText.t("title.name", "PROJECT RECLAIM"), 72)
	t.add_theme_font_override("font", UiKit.title_font())
	# 빛의계승자는 세리프라 글자 자체가 위아래로 크다. 라벨 높이를 넉넉히 주지
	# 않으면 아래 줄과 글자가 겹친다.
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var t_ko := UiKit.label(self, Vector2(0, 250), Vector2(1280, 34),
		UiText.t("title.name_ko", "프로젝트 리클레임"), 22, UiKit.MUTED)
	t_ko.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var sub := UiKit.label(self, Vector2(0, 292), Vector2(1280, 30),
		UiText.t("title.sub", "규칙을 짜서 AI를 싸우게 하는 격자 오토배틀러"), 18, UiKit.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var tag := UiKit.label(self, Vector2(0, 324), Vector2(1280, 28),
		UiText.t("title.tagline", "내가 조종하는 건 캐릭터가 아니라 캐릭터의 사고방식이다."),
		15, UiKit.ACCENT)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var b1 := UiKit.button(self, Vector2(490, 392), Vector2(300, 56), UiText.t("title.start", "런 시작"), 22)
	b1.pressed.connect(func():
		sfx.play("click")
		start_run.emit()
	)

	var b2 := UiKit.button(self, Vector2(490, 462), Vector2(300, 46), UiText.t("title.tutorial", "튜토리얼"), 17)
	b2.pressed.connect(func(): start_tutorial.emit())

	var b3 := UiKit.button(self, Vector2(490, 520), Vector2(300, 36), UiText.t("title.help", "규칙 요약"), 14)
	b3.pressed.connect(func(): show_help.emit())

	# 콘텐츠 개수(스테이지 5개 · 카드 18종 …)는 뺐다.
	# 타이틀에서 그 숫자를 보고 판단할 사람은 없고, 시작 화면은 무엇을 누를지만
	# 분명하면 된다.

	# 오프닝 테마. 화면을 넘어가도 이어지도록 배경음악 경로로 튼다.
	sfx.play_music("opening_theme")


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
