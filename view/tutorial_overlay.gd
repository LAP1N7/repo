class_name TutorialOverlay
extends Control

## 튜토리얼 표시층. 어느 화면 위에나 얹힌다.
##
## ── 레이어 (아래 → 위) ─────────────────────────────────────────────────
##   ① 암막        화면 전체를 어둡게. 앵커 구멍은 뚫는다
##   ② 앵커 테두리  지금 눌러야 할 곳을 사각형으로 표시 + 맥박
##   ③ 초상        전신 캐릭터. 좌/우 지정
##   ④ 말풍선      본문 + 화자 이름 + 진행 표시
##
## ── 입력 처리 ──────────────────────────────────────────────────────────
## gate 가 켜지면 앵커 사각형 안쪽만 클릭이 통과한다. 나머지는 오버레이가 먹는다.
## 그래서 "올바른 위치를 눌러야 진행" 이 성립한다.
## gate 가 꺼져 있으면 아무 데나 눌러 다음 대사로 넘어간다.

const PORTRAIT_W := 420.0
const BUBBLE_W := 560.0
const PAD := 22.0

## 대사가 지정할 수 있는 자리와, 그 자리에서 쓸 말풍선 폭.
##
## 화면마다 비어 있는 구역이 다르다. 전투 화면은 판(x48~560, y176~560)과
## 오른쪽 규칙·로그 패널(x600~)이 꽉 차 있어서, 자동 계산에 맡기면 매번
## 판 한가운데를 덮는다. 앵커가 없는 대사는 대본이 자리를 직접 고른다.
const PLACES := {
	"top_left":     Vector2(40, 24),
	"top_right":    Vector2(-1, 24),
	"bottom_left":  Vector2(40, -1),
	"bottom_right": Vector2(-1, -1),
	"center":       Vector2(-2, -2),
}
## 아래쪽 자리의 바닥선. 전투 화면 조작줄(y592~)보다 위다.
const BOTTOM_Y := 584.0
## 좁은 구역에 넓은 말풍선을 넣으면 결국 옆 UI 를 덮는다. 자리마다 폭이 다르다.
const PLACE_W := {
	"top_left": 512.0, "bottom_left": 512.0,
	"top_right": 620.0, "bottom_right": 620.0,
	"center": 560.0,
}

var tut: Tutorial
var _pulse: float = 0.0
var _portrait: TextureRect
var _bubble: Panel
var _lbl_name: Label
var _lbl_text: Label
var _lbl_hint: Label
var _btn_next: Button
var _gate_timer: float = 0.0

## 입력을 잠글 화면. setup 에서 받는다. (get_parent() 를 쓰면 안 되는 이유는 거기 주석)
var screen_root: Node = null


## p_screen 은 잠글 대상 화면이다. 반드시 넘겨야 한다.
##
## ── 왜 get_parent() 로는 안 되는가 ────────────────────────────────────────
## 이 오버레이는 CanvasLayer 아래에 붙는다(BattleView 가 자기 UI 를 CanvasLayer 에
## 담기 때문에 같은 레이어가 아니면 위로 못 올라간다). 그래서 get_parent() 는
## 화면이 아니라 **CanvasLayer** 를 돌려주고, 그 밑에는 이 오버레이 하나뿐이라
## _lock 이 순회할 것이 없었다.
##
## 결과적으로 게이트가 걸린 대사에서도 입력 차단이 통째로 죽어 있었다.
## 화면상으로는 멀쩡했다 - _has_point 가 앵커 밖 클릭을 막아 주고 있어서
## "다른 데를 눌러도 반응이 없다" 는 똑같이 보였기 때문이다. 다만 앵커 **안쪽**,
## 예컨대 상점 카드의 [제외] 버튼은 그대로 눌렸다.
func setup(p_tut: Tutorial, p_screen: Node = null) -> void:
	tut = p_tut
	screen_root = p_screen
	# ── size 를 직접 못 박는다 ────────────────────────────────────────────
	# 오버레이는 CanvasLayer 아래에 붙는다(BattleView 가 자기 UI 를 CanvasLayer 에
	# 담아서, 같은 레이어가 아니면 z_index 로 위에 못 올라가기 때문이다).
	# 그런데 CanvasLayer 는 Control 이 아니라서 앵커 프리셋이 풀리지 않고,
	# 이 Control 의 size 가 (0,0) 으로 남는다.
	#
	# 그 결과가 실제 버그였다. _draw() 의 암막 네 장 중 size 를 쓰는 위·아래·오른쪽
	# 세 장이 폭 0 또는 음수가 되어 사라지고, size 를 안 쓰는 **왼쪽 한 장만** 남아서
	# 강조된 카드 옆에 검은 네모가 하나 붙은 것처럼 보였다.
	# 게다가 mouse_filter=STOP 도 크기가 0 이면 아무것도 못 막는다.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200

	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)

	_bubble = Panel.new()
	# PASS 여야 안의 [계속] 버튼이 클릭을 받고, 나머지 영역은 오버레이로 흘러간다.
	_bubble.mouse_filter = Control.MOUSE_FILTER_PASS
	_bubble.add_theme_stylebox_override("panel",
		UiKit.box(Color(0.09, 0.10, 0.14, 0.97), UiKit.ACCENT, 10))
	add_child(_bubble)

	_lbl_name = UiKit.label(_bubble, Vector2(18, 12), Vector2(300, 22), "", 14, UiKit.ACCENT)
	_lbl_text = UiKit.label(_bubble, Vector2(18, 38), Vector2(BUBBLE_W - 36, 120), "", 15)
	_lbl_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_hint = UiKit.label(_bubble, Vector2(18, 0), Vector2(BUBBLE_W - 36, 20), "", 11, UiKit.MUTED)
	_lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	# 명시적인 진행 버튼.
	#
	# "아무 데나 클릭" 하나에만 의존하면, 클릭이 다른 Control 에 먹히거나 rect 계산이
	# 어긋났을 때 플레이어가 그냥 갇힌다. 실제로 그렇게 막혔다.
	# 눌러야 할 대상이 눈에 보이는 게 가장 확실하다.
	_btn_next = UiKit.button(_bubble, Vector2.ZERO, Vector2(120, 30), "계속  ▶", 14)
	_btn_next.mouse_filter = Control.MOUSE_FILTER_STOP
	_btn_next.pressed.connect(_advance_if_click_step)

	refresh()


func _advance_if_click_step() -> void:
	if tut != null and tut.advances_on_click():
		tut.advance()


func refresh() -> void:
	var s := tut.current() if tut != null else {}
	visible = not s.is_empty()
	if not visible:
		return

	_lbl_name.text = tut.speaker_name
	_lbl_text.text = String(s.get("text", ""))

	# 진행 수단은 딱 둘이다: [계속] 버튼, 또는 표시된 앵커.
	# 아무 데나 클릭해서 넘어가면 대사를 안 읽고 지나치게 되고,
	# 무엇보다 "지정한 곳을 눌러야 한다" 는 학습이 성립하지 않는다.
	var click_step := tut.advances_on_click()
	_btn_next.visible = click_step
	if click_step:
		_lbl_hint.text = "[계속] 을 눌러라"
	elif tut.anchor_node() != null:
		# 잠긴 버튼을 가리키고 있으면 그렇다고 말해야 한다.
		# 실제로 [전투 시작] 이 인원 미달로 비활성인 채 강조된 적이 있는데,
		# 화면은 "표시된 곳을 눌러라" 라고만 해서 진행이 막힌 것처럼 보였다.
		var an := tut.anchor_node()
		if an is BaseButton and (an as BaseButton).disabled:
			_lbl_hint.text = "표시된 곳이 아직 잠겨 있다 - 위의 조건을 먼저 채워라"
		else:
			_lbl_hint.text = "표시된 곳을 눌러라"
	else:
		_lbl_hint.text = ""

	_load_portrait(String(s.get("speaker", "")))
	_layout(String(s.get("side", "left")))
	queue_redraw()


func _load_portrait(id: String) -> void:
	_portrait.texture = null
	if id == "":
		return
	# 전신 LD 초상(ASSETS.md C-2)을 먼저 찾고, 없으면 컷인 일러스트를 돌려쓴다.
	# 둘 다 없으면 실루엣으로 대신한다 - 에셋이 없어도 튜토리얼은 돌아간다.
	for path in ["res://assets/art/tutorial/%s.png" % id,
			"res://assets/art/cutin/%s.png" % id]:
		if ResourceLoader.exists(path):
			var t := load(path)
			if t is Texture2D:
				_portrait.texture = t
				return


func _layout(side: String) -> void:
	var h := 720.0
	var left := side == "left"

	# 전투 중에는 초상을 접는다. 폭 420 짜리 전신이 서 있으면 규칙 패널이든
	# 전투 로그든 통째로 가리는데, 정작 그 틱에 뭐가 왜 터졌는지를 읽으라고
	# 하는 대사다. 말할 사람 이름은 말풍선에 이미 붙어 있다.
	_portrait.visible = bool(tut.current().get("portrait", true))
	_portrait.size = Vector2(PORTRAIT_W, h)
	_portrait.position = Vector2(20.0 if left else 1280.0 - PORTRAIT_W - 20.0, 0)
	_portrait.flip_h = not left

	var place := String(tut.current().get("place", ""))
	var bw: float = float(PLACE_W.get(place, BUBBLE_W))

	# 본문 높이에 맞춰 말풍선을 늘린다. 고정 높이로 두면 긴 대사가 잘린다.
	# 줄 수만 세면 안 된다 - 폭이 좁아지면 한 줄이 두 줄로 접히므로, 폭을 먼저
	# 확정하고 실제로 렌더된 높이를 받아 쓴다.
	# get_content_height() 는 RichTextLabel 에만 있다. Label 은 접힌 뒤의 줄 수를
	# get_line_count() 로 알려주므로 그걸 쓴다.
	_lbl_text.size = Vector2(bw - 36, 10)
	# 62 로는 마지막 줄과 [계속] 힌트가 겹쳤다. 이름 38 + 본문 + 힌트 22 + 여백 12.
	var bh := 72.0 + maxf(24.0, _lbl_text.get_line_count() * _lbl_text.get_line_height())

	_bubble.size = Vector2(bw, bh)
	_bubble.position = _pick_bubble_pos(bw, bh, place, left)
	_lbl_text.size = Vector2(bw - 36, bh - 56)
	# 오른쪽은 [계속] 버튼 자리다. 힌트는 왼쪽에 두고 폭도 그만큼 줄인다.
	_lbl_hint.position = Vector2(18, bh - 22)
	_lbl_hint.size = Vector2(bw - 180, 20)
	_btn_next.position = Vector2(bw - 140, bh - 40)


## 말풍선 자리를 고른다.
##
## 좌/우 고정으로 두면 "이걸 눌러라" 하면서 정작 그 대상을 말풍선이 덮는다.
## 실제로 카드를 가렸다. 앵커가 있으면 그 사각형을 피해 아래 → 위 → 왼 → 오
## 순으로 처음 들어맞는 자리에 놓는다.
## 앵커가 없으면 대본의 place 를 따른다. 그것도 없으면 초상 반대쪽 가운데.
func _pick_bubble_pos(bw: float, bh: float, place: String, left: bool) -> Vector2:
	var margin := 20.0
	var target := tut.anchor_node()

	if target != null and target.is_inside_tree():
		var a := Rect2(target.global_position, target.size).grow(margin)
		var cx := clampf(a.get_center().x - bw * 0.5, margin, 1280.0 - bw - margin)
		var cy := clampf(a.get_center().y - bh * 0.5, margin, 720.0 - bh - margin)

		var candidates: Array[Vector2] = [
			Vector2(cx, a.end.y),                 # 아래
			Vector2(cx, a.position.y - bh),       # 위
			Vector2(a.position.x - bw, cy),       # 왼쪽
			Vector2(a.end.x, cy),                 # 오른쪽
		]
		for p in candidates:
			var r := Rect2(p, Vector2(bw, bh))
			var on_screen := r.position.x >= margin and r.position.y >= margin \
				and r.end.x <= 1280.0 - margin and r.end.y <= 720.0 - margin
			if on_screen and not r.intersects(a):
				return p

		# 전부 안 되면 앵커에서 먼 쪽 구석으로 뺀다.
		return Vector2(cx, margin if a.get_center().y > 360.0 else 720.0 - bh - margin)

	if PLACES.has(place):
		var v: Vector2 = PLACES[place]
		var px := v.x
		var py := v.y
		# -1 은 "오른쪽/아래 끝에 붙여라", -2 는 "가운데" 를 뜻한다.
		# 폭·높이가 대사마다 달라서 상수로 못 적는다.
		if px == -1.0:
			px = 1280.0 - bw - margin
		elif px == -2.0:
			px = 640.0 - bw * 0.5
		if py == -1.0:
			# 화면 맨 아래가 아니라 조작줄 바로 위에 세운다. 아래에 붙이면
			# 전투의 중단·배속 버튼을 통째로 덮어서 눌러야 할 게 안 보인다.
			py = BOTTOM_Y - bh
		elif py == -2.0:
			py = 360.0 - bh * 0.5
		return Vector2(px, py)

	return Vector2(
		PORTRAIT_W + 40.0 if left else 1280.0 - PORTRAIT_W - bw - 60.0,
		360.0 - bh * 0.5)


func _process(delta: float) -> void:
	if not visible:
		return
	# CanvasLayer 아래라 앵커가 안 먹는다. 창 크기가 바뀌면 따라가야 한다.
	# (웹 빌드는 캔버스 크기가 실제로 바뀐다)
	if size != get_viewport_rect().size:
		size = get_viewport_rect().size
		queue_redraw()
	_pulse = fmod(_pulse + delta * 2.2, TAU)
	if tut != null and tut.anchor_node() != null:
		queue_redraw()

	# 게이트를 주기적으로 다시 건다.
	#
	# 입력을 가로채는 것만으로는 부족하다. 화면이 refresh 하면서 버튼과 카드를
	# 통째로 새로 만들기 때문에 한 번 걸어 둔 잠금이 그때 풀린다.
	# 실제 컨트롤을 disabled 로 만들어야 "다른 건 누를 수 없다" 가 보장된다.
	_gate_timer -= delta
	if _gate_timer <= 0.0:
		_gate_timer = 0.1
		_apply_gate()


## 앵커 외의 모든 조작을 실제로 잠근다. gate 가 꺼져 있으면 원래 상태로 되돌린다.
func _apply_gate() -> void:
	if tut == null or not tut.active:
		return
	var screen: Node = screen_root if screen_root != null else get_parent()
	if screen != null:
		_lock(screen, tut.anchor_node(), tut.gates_input())


func _lock(node: Node, allow: Control, gated: bool) -> void:
	for c in node.get_children():
		if c == self:
			continue
		if c is BaseButton:
			var b := c as BaseButton
			# 원래 상태를 한 번만 기억해 둔다. 게이트를 풀 때 그대로 되돌린다.
			if not b.has_meta("tut_prev"):
				b.set_meta("tut_prev", b.disabled)
			if gated:
				b.disabled = c != allow
			else:
				b.disabled = bool(b.get_meta("tut_prev"))
				b.remove_meta("tut_prev")
		elif c is CardNode:
			var cn := c as CardNode
			if not cn.has_meta("tut_prev"):
				cn.set_meta("tut_prev", cn.enabled)
			if gated:
				cn.enabled = c == allow
			else:
				cn.enabled = bool(cn.get_meta("tut_prev"))
				cn.remove_meta("tut_prev")
		_lock(c, allow, gated)


func _draw() -> void:
	# size 대신 뷰포트를 직접 읽는다. 위 setup() 의 이유로 size 를 믿을 수 없고,
	# 믿을 수 있게 만들어 놓았더라도 여기서 한 번 더 끊어 두는 편이 안전하다.
	var screen := get_viewport_rect().size
	if tut == null or tut.current().is_empty():
		return

	var hole := Rect2()
	var target := tut.anchor_node()
	if target != null and target.is_inside_tree():
		hole = Rect2(target.global_position, target.size).grow(6.0)

	# ── 암막. 앵커가 있으면 그 부분만 남기고 네 조각으로 나눠 덮는다.
	var dim := Color(0.03, 0.035, 0.05, 0.62)
	if hole.size == Vector2.ZERO:
		draw_rect(Rect2(Vector2.ZERO, screen), dim)
	else:
		draw_rect(Rect2(0, 0, screen.x, hole.position.y), dim)
		draw_rect(Rect2(0, hole.end.y, screen.x, screen.y - hole.end.y), dim)
		draw_rect(Rect2(0, hole.position.y, hole.position.x, hole.size.y), dim)
		draw_rect(Rect2(hole.end.x, hole.position.y, screen.x - hole.end.x, hole.size.y), dim)

		# ── 앵커 테두리. 맥박으로 시선을 끈다.
		var k := 0.5 + 0.5 * sin(_pulse)
		var col := Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.55 + 0.45 * k)
		draw_rect(hole.grow(2.0 * k), col, false, 2.0 + 1.5 * k)

	# 초상 아트가 없을 때의 대역. 실루엣만이라도 있어야 화자가 있다는 게 읽힌다.
	# 초상을 접은 대사(전투 중)에서는 대역도 그리면 안 된다 - 이건 _draw 라
	# _portrait.visible 을 따로 봐 줘야 한다.
	if _portrait.visible and _portrait.texture == null:
		var pr := Rect2(_portrait.position, _portrait.size)
		var cx := pr.position.x + pr.size.x * 0.5
		var base := pr.position.y + pr.size.y * 0.94
		draw_circle(Vector2(cx, base - 300.0), 56.0, Color(0.22, 0.24, 0.30, 0.9))
		draw_rect(Rect2(cx - 62.0, base - 250.0, 124.0, 250.0), Color(0.18, 0.20, 0.26, 0.9))
		var f := UiKit.font(12)
		var t := "(초상 준비 중)"
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(f, Vector2(cx - w * 0.5, base + 22.0), t,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiKit.LINE)


## 강조된 앵커 위에서는 이 오버레이가 없는 셈 친다.
##
## ── 왜 히트테스트로 뚫는가 ────────────────────────────────────────────────
## 예전엔 _gui_input 에서 클릭을 받아 앵커에게 "대신 눌러 주는" 방식이었다.
## 그런데 그 코드는 BaseButton 의 pressed 시그널만 쏠 줄 알았고, 상점 카드는
## BaseButton 이 아니라 자체 gui_input 을 쓰는 CardNode 라서 아무 일도 안 났다.
## 카드를 눌러도 안 사지는 버그가 그것이다.
##
## 노드 종류마다 "누르는 법" 을 이 파일이 알아야 하는 구조 자체가 틀렸다.
## _has_point 로 그 영역만 히트테스트에서 빼면, 클릭은 Godot 이 알아서 진짜
## 노드에게 배달한다. 버튼이든 카드든 앞으로 무엇이 오든 그대로 동작한다.
func _has_point(point: Vector2) -> bool:
	if tut == null:
		return false
	var target := tut.anchor_node()
	if target != null and target.is_inside_tree():
		# 이 Control 은 화면 원점에 있으므로 지역 좌표 == 전역 좌표다.
		if Rect2(target.global_position, target.size).grow(6.0).has_point(point):
			return false
	return true


func _gui_input(e: InputEvent) -> void:
	if tut == null or tut.current().is_empty():
		return
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	# 여기까지 왔다는 건 앵커 밖이라는 뜻이다(_has_point 가 앵커를 이미 뺐다).
	# 전부 먹는다. 진행은 [계속] 버튼이나 앵커로만 한다 -
	# 아무 데나 눌러 넘어가면 대사를 안 읽고 지나치게 된다.
	accept_event()
