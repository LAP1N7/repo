extends SceneTree

## 스토리 초상 9종을 나란히 세워 얼굴 크기를 눈으로 비교한다.
##
##   godot --path . --resolution 1280x700 --script res://test/portraits.gd
##
## ── 왜 필요한가 ──────────────────────────────────────────────────────────
## 대사 한 줄마다 인물이 바뀌는 화면에서, 인물마다 얼굴 크기가 다르면 카메라가
## 제멋대로 줌인·줌아웃하는 것처럼 보인다. 그런데 이건 한 장씩 봐서는 절대
## 못 잡는다 - 옆에 세워 놓고 봐야 "얘만 크다" 가 보인다.
##
## 그림 파일은 캔버스 크기도 인물이 차지하는 비율도 제각각이라(흉상 1200x787,
## 전신 827x1177) 자동 규칙 하나로는 안 맞는다. 그래서 StoryScreen.PORTRAIT_FIT
## 에 사람 손으로 배율을 적고, 이 스크립트로 확인한다.

const IDS: Array[String] = [
	"archer", "bard", "warrior", "assassin", "musketeer", "shieldman",
	"ai", "ai_talk", "ai_smile",
]
const CELL_W: float = 142.0
const CELL_H: float = 620.0


func _init() -> void:
	root.content_scale_size = Vector2i(1280, 700)
	await process_frame

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.11)
	bg.size = Vector2(1280, 700)
	root.add_child(bg)

	for i in IDS.size():
		var id := IDS[i]
		var x := 8.0 + float(i) * (CELL_W - 2.0)
		var box := StoryScreen.new_portrait_box(id)
		box.position = Vector2(x, 20)
		box.size = Vector2(CELL_W, CELL_H)
		root.add_child(box)

		var l := Label.new()
		l.text = id
		l.position = Vector2(x, CELL_H + 26)
		l.size = Vector2(CELL_W, 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 13)
		root.add_child(l)

		# 눈금선. 얼굴 꼭대기가 어디쯤인지 자로 재듯 본다.
		var g := ColorRect.new()
		g.color = Color(1, 0.3, 0.3, 0.35)
		g.position = Vector2(x, 20)
		g.size = Vector2(CELL_W, 1)
		root.add_child(g)

	for _i in 12:
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.shots"))
	root.get_texture().get_image().save_png("res://.shots/15_portraits.png")
	print("  찍음: 15_portraits")
	quit(0)
