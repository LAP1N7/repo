class_name TutorialIntroScreen
extends Control

## 튜토리얼 1막 - 이야기 소개.
##
## 이 화면에는 게임 UI 가 없다. 오버레이(초상 + 말풍선)만 있다.
## screen 이 "tutorial" 인 대사를 전부 소화하면 상점으로 넘어간다.

signal done()

var tut: Tutorial
var overlay: TutorialOverlay


func setup(p_tut: Tutorial) -> void:
	tut = p_tut
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = UiKit.BG
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 배경 격자. 앞으로 싸울 판이 어떤 모양인지 미리 보여 준다.
	var deco := _Grid.new()
	deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(deco)

	overlay = TutorialOverlay.new()
	add_child(overlay)
	overlay.setup(tut)

	tut.step_changed.connect(_on_step)
	_on_step()


func _on_step() -> void:
	# 이 화면 몫의 대사가 끝나면 다음 단계로 넘긴다.
	if not tut.active or not tut.is_for_screen("tutorial"):
		done.emit()
		return
	overlay.refresh()


class _Grid extends Control:
	func _draw() -> void:
		var origin := Vector2(384, 168)
		for y in Grid.H:
			for x in Grid.W:
				draw_rect(Rect2(origin + Vector2(x * Grid.TILE, y * Grid.TILE),
					Vector2(Grid.TILE, Grid.TILE)),
					Color(0.11, 0.12, 0.16, 0.45) if (x + y) % 2 == 0
					else Color(0.10, 0.11, 0.14, 0.45))
		for x in Grid.W + 1:
			draw_line(origin + Vector2(x * Grid.TILE, 0),
				origin + Vector2(x * Grid.TILE, Grid.H * Grid.TILE),
				Color(0.22, 0.24, 0.30, 0.45), 1.0)
		for y in Grid.H + 1:
			draw_line(origin + Vector2(0, y * Grid.TILE),
				origin + Vector2(Grid.W * Grid.TILE, y * Grid.TILE),
				Color(0.22, 0.24, 0.30, 0.45), 1.0)
