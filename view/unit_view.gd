class_name UnitView
extends Node2D

## 유닛 한 명의 화면 표현.
##
## ── 레이어 순서 (아래 → 위) ────────────────────────────────────────────
##   그림자         _draw()   타일 바닥의 타원. 스프라이트가 떠 보이지 않게 한다
##   팀 링          _draw()   아군 파랑 / 적 빨강. 아트가 있으면 발밑 고리로만
##   본체 (z 0)     Sprite2D  아트가 있으면 이것, 없으면 _draw() 의 색 원
##   상태 표식      _draw()   방어 태세 링 · 사거리 표식
##   HP · 궁극기    _draw()
##   이름           _draw()
##   규칙 칩 (z100) Label     항상 최상단
##
## 아트를 끼울 때 이 순서를 지켜야 한다. 특히 그림자는 본체 아래, 칩은 무조건 위다.
##
## art 텍스처가 없으면 도형으로 그린다. 그래서 에셋이 하나도 없어도 게임이 성립하고,
## 에셋이 한 종씩 들어와도 그때그때 교체된다. (DESIGN 6장)

## 유닛 하나가 세로로 차지하는 총 높이가 타일(64px)을 넘으면 위아래로 붙은 유닛끼리
## 이름과 HP 바가 겹친다. 이름 상단 ~-32, 게이지 하단 ~+31 로 딱 맞춰 둔 값이다.
## 건드릴 때 반드시 세로 합계를 다시 계산할 것.
## 유닛 반지름. 타일이 64px 이므로 칸을 거의 채운다.
##
## 18 은 칸의 절반도 안 됐다. 판을 확대했더니 그 차이가 더 벌어져서, 큰 칸
## 한가운데에 작은 점이 찍힌 것처럼 보였다. 격자 게임에서 말이 칸보다 훨씬
## 작으면 "어느 칸에 있는가" 가 눈에 안 들어온다.
const R: float = 26.0
const HP_W: float = 44.0
const NAME_SIZE: int = 11
const CHIP_SIZE: int = 12
## 라벨 한 줄 높이. 이웃과 어긋나게 놓을 때도 이 값을 쓴다.
const CHIP_H: float = 19.0

## 스프라이트 표시 **가로** 폭. 세로는 원본 비율대로 따라온다.
## 정사각이든 세로로 긴 직사각(SD 체형)이든 가로는 항상 이 값으로 맞춰진다.
const ART_W: float = 48.0

## 발밑 기준선. 스프라이트의 **아래 끝**이 여기에 붙는다.
##
## 타일 중심 정렬로 두면 세로로 긴 그림이 위아래로 똑같이 자라서 아래로는 HP 바를,
## 위로는 이름을 뚫는다. 발밑을 고정하면 키가 커져도 위로만 자라므로 바닥에 서 있는
## 느낌이 유지되고 HP 바와도 안 겹친다.
const GROUND_Y: float = 14.0

## HP 바·이름 레이어의 z. 모든 유닛 스프라이트보다 위여야 한다.
## 세로로 긴 스프라이트는 위 칸을 침범하는데, 이게 없으면 앞줄 유닛의 몸이
## 뒷줄 유닛의 HP 바를 덮어 버린다.
const OVERLAY_Z: int = 60

## 캐릭터 씬에서 찾는 애니메이션 이름.
const ANIM_WALK: StringName = &"walk"
const ANIM_ATTACK: StringName = &"attack"

## ── 애니메이션 이름은 사람마다 다르게 짓는다 ─────────────────────────────
## 리그를 만드는 쪽에서 "walk" 라고 할지 "walking" 이라고 할지 "run" 이라고 할지
## 우리가 정할 수 없다. 실제로 twinning 에서 받은 악사 리그는 "walking" 이었고,
## 이름 하나가 안 맞아서 아무 동작도 안 나왔다 - 그림은 붙었는데 서 있기만 했다.
##
## 에셋을 고치라고 하는 대신 여기서 받아 준다. 이름을 맞추는 일은 사람이 할
## 일이 아니다.
const ANIM_ALIAS: Dictionary = {
	&"walk": ["walk", "walking", "run", "move"],
	&"attack": ["attack", "attacking", "atk", "hit"],
}

## 규칙 라벨이 사라지는 속도(1/초). 낮추면 여러 유닛의 라벨이 겹쳐서 못 읽는다.
const CHIP_FADE: float = 1.7

var unit: Unit
var font: Font

## 피격 플래시 세기 0~1. (DESIGN R2 연출 1순위)
var flash: float = 0.0
var chip_alpha: float = 0.0

var chip: Label
## 본체 스프라이트. 텍스처가 없으면 숨고 _draw() 의 색 원이 대신 나온다.
var art: Sprite2D

## 애니메이션 캐릭터 씬(부품 스프라이트 + AnimationPlayer). PNG 대신 이게 있으면
## 이쪽이 본체가 된다.
var rig: Node2D
var anim: AnimationPlayer

## ── 바라보는 쪽 ──────────────────────────────────────────────────────────
## +1 이면 오른쪽, -1 이면 왼쪽. 원본 그림은 전부 오른쪽을 보게 그린다(ASSETS.md).
##
## 예전에는 진영으로만 정했다 - 아군은 오른쪽, 적은 왼쪽 고정. 그래서 물러나는
## 대원이 **뒤로 미끄러지듯** 움직였고, 뒤에 있는 적을 칠 때도 반대쪽을 보고
## 때렸다. 걸음과 그림이 어긋나면 그 순간만은 게임이 아니라 인형극처럼 보인다.
##
## 이제 걸을 때는 가는 쪽을, 때릴 때는 표적 쪽을 본다.
## ── 화면상의 생사 ────────────────────────────────────────────────────────
## Unit.alive 를 그대로 보면 안 된다.
##
## 전투 코어는 battle.step() 한 번에 **틱 전체**를 계산한다. 여섯이 다 움직이고
## 죽을 사람이 다 죽은 다음에야 뷰가 그 틱의 이벤트를 하나씩 재생한다. 그래서
## alive 를 직접 보면, 그 틱 어딘가에서 죽은 대원이 **재생이 시작되기도 전에**
## 사라진다. 화면에는 빈 칸을 계속 때리고 피해 숫자가 뜨는 그림이 남는다.
##
## 재생이 그 대원의 사망 이벤트에 닿았을 때 이 값이 켜진다. 규칙의 시간과
## 화면의 시간을 분리하는 것이 이 한 줄의 목적이다.
var view_dead: bool = false


func shown_alive() -> bool:
	return unit != null and not view_dead


var facing: int = 1

## 그림의 배율(부호 없는 크기). 방향을 바꿀 때 이 값에 부호만 다시 붙인다.
var _scale_k: float = 1.0
## 리그를 담은 노드. 단일 그림이면 null 이고 art 를 직접 뒤집는다.
var _holder: Node2D = null
## 리그 경계 상자의 가운데 x. 뒤집을 때 위치를 다시 잡는 데 쓴다.
var _rig_center_x: float = 0.0

## HP 바 · 궁극기 표시 · 이름을 그리는 별도 레이어. 항상 모든 스프라이트 위에 뜬다.
var overlay: _Overlay


func setup(p_unit: Unit, p_font: Font) -> void:
	unit = p_unit
	font = p_font
	view_dead = not p_unit.alive

	art = Sprite2D.new()
	art.z_index = 0
	art.visible = false
	add_child(art)

	overlay = _Overlay.new()
	overlay.owner_view = self
	overlay.z_index = OVERLAY_Z
	overlay.z_as_relative = false
	add_child(overlay)

	chip = Label.new()
	chip.add_theme_font_override("font", font)
	chip.add_theme_font_size_override("font_size", CHIP_SIZE)
	chip.add_theme_color_override("font_color", Color(1, 1, 1))
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 배경판 없이 띄우면 라벨끼리, 그리고 유닛과 겹쳐서 하나도 안 읽힌다.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.10, 0.93)
	sb.border_color = Color(0.55, 0.60, 0.78, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	chip.add_theme_stylebox_override("normal", sb)
	chip.z_index = 100          # 항상 유닛 위에
	chip.modulate.a = 0.0
	add_child(chip)

	_try_load_art()


## 에셋을 찾아 얹는다. 우선순위: 애니메이션 씬(.tscn) → 단일 그림(.png) → 도형.
## 없으면 조용히 도형으로 남는다 - 에셋이 하나씩 들어와도 게임이 안 깨진다.
func _try_load_art() -> void:
	var scn := "res://assets/art/units/%s.tscn" % unit.type_id
	if ResourceLoader.exists(scn):
		var packed := load(scn)
		if packed is PackedScene:
			_set_rig(packed)
			return
	var path := "res://assets/art/units/%s.png" % unit.type_id
	if ResourceLoader.exists(path):
		var tex := load(path)
		if tex is Texture2D:
			set_art(tex)


## 애니메이션 캐릭터 씬을 본체로 세운다.
##
## 씬마다 부품 위치·크기가 제각각이므로 크기를 코드에 박을 수 없다.
## 실제 스프라이트들의 경계 상자를 재서 가로를 ART_W 로 맞추고 발밑을 GROUND_Y 에 붙인다.
func _set_rig(packed: PackedScene) -> void:
	var inst := packed.instantiate()
	if not (inst is Node2D):
		inst.queue_free()
		return

	# 크기를 재기 전에 서 있는 자세로 만들어 둔다.
	# 편집기에 저장된 노드 위치(RESET)는 부품이 흩어져 있을 수 있어서,
	# 그 상태로 재면 경계 상자가 엉뚱하게 커진다.
	var holder := Node2D.new()
	holder.z_index = 0
	add_child(holder)
	holder.add_child(inst)
	rig = inst
	_holder = holder

	anim = _find_anim(inst)
	var w := resolve_anim(ANIM_WALK)
	if w != "":
		anim.play(w)
		anim.seek(0.0, true)
		anim.speed_scale = 0.0

	var box := _visual_bounds(inst)
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return

	var k := ART_W / box.size.x
	_scale_k = k
	_rig_center_x = box.get_center().x
	facing = -1 if unit.team == Unit.TEAM_ENEMY else 1
	# 발밑(경계 상자 아래쪽)을 GROUND_Y 에 붙인다.
	holder.scale = Vector2(k * facing, k)
	holder.position = Vector2(
		-box.get_center().x * holder.scale.x,
		GROUND_Y - box.end.y * k)
	rig_height = box.size.y * k


## 자식 Sprite2D 들이 실제로 차지하는 영역. 부모 기준 좌표.
##
## 캔버스 전체가 아니라 **불투명 픽셀이 있는 영역**만 잰다.
## 그림이 192×256 캔버스 안에서 여백에 둘러싸여 있으면, 캔버스 기준으로 축소했을 때
## 실제 캐릭터는 의도한 크기보다 작아진다. 실측으로 확인한 문제다.
func _visual_bounds(root: Node) -> Rect2:
	var box := Rect2()
	var first := true
	for n in _all_sprites(root):
		var tex: Texture2D = n.texture
		if tex == null:
			continue
		var used := _opaque_rect(tex)
		if used.size.x <= 0.0 or used.size.y <= 0.0:
			continue

		# 텍스처 좌상단이 로컬 좌표 어디에 놓이는지 구한 뒤, 그 안에서 불투명 영역만 취한다.
		var tex_size := Vector2(tex.get_width(), tex.get_height())
		var origin: Vector2 = n.position + n.offset * n.scale
		if n.centered:
			origin -= tex_size * 0.5 * n.scale
		var r := Rect2(origin + used.position * n.scale, used.size * n.scale)
		box = r if first else box.merge(r)
		first = false
	return box


## 텍스처에서 불투명 픽셀이 차지하는 사각형. 이미지 압축을 풀어야 해서 비싸므로
## 텍스처별로 한 번만 재고 캐시한다.
static var _opaque_cache: Dictionary = {}

static func _opaque_rect(tex: Texture2D) -> Rect2:
	var key := tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
	if _opaque_cache.has(key):
		return _opaque_cache[key]
	var r := Rect2(Vector2.ZERO, Vector2(tex.get_width(), tex.get_height()))
	var img := tex.get_image()
	if img != null:
		var used := img.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			r = Rect2(used.position, used.size)
	_opaque_cache[key] = r
	return r


func _all_sprites(root: Node) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	if root is Sprite2D:
		out.append(root)
	for c in root.get_children():
		out.append_array(_all_sprites(c))
	return out


func _find_anim(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for c in root.get_children():
		var f := _find_anim(c)
		if f != null:
			return f
	return null


## 애니메이션의 "실제" 길이. 마지막 키프레임이 찍힌 시각을 쓴다.
##
## Godot 은 애니메이션 길이를 기본 1초로 잡는데, 키가 0.47초에서 끝나면
## 나머지 0.53초는 아무 변화 없는 죽은 구간이다. length 를 그대로 쓰면
## 한 사이클의 절반을 가만히 서서 보내게 된다.
static func _effective_length(a: Animation) -> float:
	var last := 0.0
	for t in a.get_track_count():
		var n := a.track_get_key_count(t)
		if n > 0:
			last = maxf(last, a.track_get_key_time(t, n - 1))
	return last if last > 0.001 else a.length


## 한 동작에 정확히 한 사이클이 들어가도록 재생 속도를 맞춰 돌린다.
##
## 배속이 1x/2x/4x 로 바뀌고 이동 칸 수도 달라지므로, 고정 길이 애니메이션은
## 어느 경우에도 안 맞는다. 실제로 걷기 1초짜리가 0.22초 안에 22% 만 재생돼
## "애니메이션이 안 도는" 것처럼 보였다. 속도를 맞추면 어떤 배속에서도 한 걸음에
## 한 걸음짜리 동작이 온전히 보인다.
func play_motion(which: StringName, duration: float) -> bool:
	var name := resolve_anim(which)
	if name == "" or duration <= 0.0:
		return false
	var a := anim.get_animation(name)
	var eff := _effective_length(a)
	if eff <= 0.0:
		return false
	anim.play(name)
	anim.seek(0.0, true)
	anim.speed_scale = eff / duration
	return true


## 기본 자세로 되돌린다. 걷다 만 자세로 굳어 있으면 어색하다.
func rest_motion() -> void:
	var name := resolve_anim(ANIM_WALK)
	if name == "":
		return
	anim.play(name)
	anim.seek(0.0, true)
	anim.speed_scale = 0.0


func has_motion(which: StringName) -> bool:
	return resolve_anim(which) != ""


func set_art(tex: Texture2D) -> void:
	art.texture = tex
	art.visible = true

	var w := float(tex.get_width())
	var h := float(tex.get_height())
	if w <= 0.0:
		return

	# 원점을 그림의 "발밑 가운데" 로 옮긴다. 그래야 키가 커져도 아래가 안 밀린다.
	art.centered = false
	art.offset = Vector2(-w * 0.5, -h)
	art.position = Vector2(0.0, GROUND_Y)

	# 가로를 ART_W 로 맞추고 세로는 비율대로 따라간다.
	var k := ART_W / w
	_scale_k = k
	facing = -1 if unit.team == Unit.TEAM_ENEMY else 1
	# 좌우를 뒤집는다. 원본은 오른쪽을 보게 그린다. (ASSETS.md)
	# flip_h 는 centered=false 일 때 왼쪽 끝을 축으로 뒤집어 위치가 어긋난다.
	# scale.x 부호로 뒤집으면 노드 원점(발밑 가운데)을 축으로 돌아 제자리를 지킨다.
	art.scale = Vector2(k * facing, k)
	queue_redraw()


## 리그가 세워졌을 때의 화면상 높이. 이름표 위치 계산에 쓴다.
var rig_height: float = 0.0


func has_art() -> bool:
	return (art != null and art.texture != null) or rig != null


## 발동한 규칙을 머리 위에 띄운다. 이 게임의 유일한 차별점을 눈에 보이게 만드는 장치.
## (DESIGN 1-2 "절대 자르지 말 것")
##
## 폭을 내용에 맞추고 빨리 사라지게 한다. 고정 폭 + 느린 페이드로 두면 한 틱에
## 유닛 6명이 행동할 때 라벨 6개가 동시에 겹쳐 전부 못 읽는다.
## innate 면 "기본" 이라고 표시하고 테두리를 흐리게 한다. 산 카드가 발동한 것과
## 기본기로 떨어진 것을 화면에서 구분할 수 있어야, 카드가 왜 안 터지는지 보인다.
func show_rule(text: String, innate: bool = false) -> void:
	# 괄호 주석(위력 85% 등)은 카드에서는 유용하지만 머리 위 라벨에서는 폭만 늘려
	# 라벨끼리 겹치게 만든다. 칩에서는 떼고 보여 준다.
	var brief := text
	var lp := brief.find(" (")
	if lp > 0:
		brief = brief.substr(0, lp)
	var shown := (UiText.t("unit.m01", "기본 ·  ") + brief) if innate else brief
	chip.text = shown
	var w: float = 16.0
	if font != null:
		w += font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_SIZE).x

	# ── 판 밖으로 나가지 않게 민다 ────────────────────────────────────────
	# 라벨을 유닛 중심에 맞추기만 하면 1열(x=0)에 선 유닛의 긴 라벨이 화면 왼쪽
	# 밖으로 잘려 나간다. 실제로 `본 · 적이 1칸 이내 → 한 칸 물러난다` 가 앞이
	# 잘린 채 `본 ·` 부터 시작해서, 글꼴이 깨진 것처럼 보였다.
	var board_w := float(Grid.W * Grid.TILE)
	w = minf(w, board_w - 4.0)
	chip.size = Vector2(w, CHIP_H)
	var left := -w * 0.5
	var lo := -position.x + 2.0
	var hi := board_w - position.x - w - 2.0
	left = clampf(left, minf(lo, hi), maxf(lo, hi))

	# ── 같은 행의 이웃과 높이를 어긋나게 둔다 ─────────────────────────────
	# 라벨 폭이 200px 을 넘는데 타일 간격은 64px 이라, 나란히 선 유닛 둘이 같은
	# 높이에 뜨면 글자가 통째로 겹쳐 둘 다 못 읽는다. 열 홀짝으로 한 줄씩 띄운다.
	var stagger: float = CHIP_H + 3.0 if (unit != null and unit.pos.x % 2 == 1) else 0.0
	chip.position = Vector2(left, -R - 34.0 - stagger)

	var sb := chip.get_theme_stylebox("normal") as StyleBoxFlat
	if sb != null:
		sb.border_color = Color(0.42, 0.46, 0.56, 0.8) if innate else Color(0.55, 0.60, 0.78, 0.9)
	chip.add_theme_color_override("font_color",
		Color(0.72, 0.75, 0.82) if innate else Color(1, 1, 1))

	chip_alpha = 1.0


func hit() -> void:
	flash = 1.0


func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 5.0)
	if chip_alpha > 0.0:
		chip_alpha = maxf(0.0, chip_alpha - delta * CHIP_FADE)
	chip.modulate.a = chip_alpha

	if rig != null:
		rig.visible = shown_alive()
		rig.modulate = Color(1, 1, 1).lerp(Color(4, 4, 4), flash)
	if art != null and art.visible:
		art.visible = shown_alive()
		# 피격 플래시는 스프라이트를 하얗게 태워서 표현한다.
		art.modulate = Color(1, 1, 1).lerp(Color(4, 4, 4), flash)
	queue_redraw()
	if overlay != null:
		overlay.queue_redraw()


func _draw() -> void:
	if unit == null:
		return

	if view_dead:
		# 사망: 흐릿한 십자 표시만 남긴다.
		var g := Color(0.35, 0.35, 0.4, 0.55)
		draw_line(Vector2(-13, -13), Vector2(13, 13), g, 3.0)
		draw_line(Vector2(-13, 13), Vector2(13, -13), g, 3.0)
		return

	var ring := Color(0.35, 0.75, 1.0) if unit.team == Unit.TEAM_PLAYER else Color(1.0, 0.42, 0.38)

	# ── 그림자. 스프라이트가 타일 위에 떠 보이지 않게 한다.
	draw_circle(Vector2(0, R * 0.72), R * 0.62, Color(0, 0, 0, 0.28))

	# ── 진영은 바닥 표식으로 가른다 ──────────────────────────────────────
	# 예전에는 몸통을 파랑/빨강으로 칠했다. 그런데 직업 색도 몸통에 있어서
	# 두 정보가 같은 자리를 두고 다퉜고, 결국 "빨간 동그라미 / 파란 동그라미"
	# 로만 읽혔다 - 직업이 안 보였다.
	#
	# 진영은 발밑에, 직업은 몸통에 둔다. 자리가 갈리면 둘 다 읽힌다.
	# 아군은 채운 호, 적은 점선 호다. 색을 못 가리는 사람에게도 모양이 남는다.
	var seg: int = 28 if unit.team == Unit.TEAM_PLAYER else 12
	draw_arc(Vector2(0, R * 0.78), R * 0.86, 0.0, TAU, seg,
		Color(ring.r, ring.g, ring.b, 0.9), 3.0)

	if has_art():
		# 아트가 있으면 본체는 스프라이트가 그린다. 팀 구분은 발밑 고리로만 남긴다.
		pass   # 발밑 고리는 위에서 이미 그렸다
	else:
		var body: Color = unit.color
		if flash > 0.0:
			body = body.lerp(Color.WHITE, flash)
		# 몸통은 **직업 색**이다. 진영은 발밑 고리가 말한다.
		draw_circle(Vector2.ZERO, R, body)
		draw_arc(Vector2.ZERO, R, 0.0, TAU, 32, body.lightened(0.35), 2.0)

		# 사거리가 긴 유닛은 안쪽에 표식을 넣어 구분한다 (도형만으로 역할이 읽히게)
		if unit.atk_range >= 3:
			draw_circle(Vector2.ZERO, 5.0, Color(1, 1, 1, 0.85))
		elif unit.atk_range == 2:
			draw_arc(Vector2.ZERO, 8.0, 0, TAU, 20, Color(1, 1, 1, 0.85), 2.0)
		if unit.move_range >= 2:
			draw_arc(Vector2.ZERO, R - 4.0, 0, TAU, 24, Color(1, 1, 1, 0.5), 1.5)

	# 방어 태세
	if unit.defending:
		draw_arc(Vector2.ZERO, R + 7.0, 0, TAU, 32, Color(0.65, 0.85, 1.0, 0.95), 2.5)

	# HP 바 · 궁극기 표시 · 이름은 overlay 가 그린다.
	# 세로로 긴 스프라이트가 위 칸을 침범해도 이것들은 항상 위에 떠 있어야 한다.


## HP 바 · 궁극기 표시 · 이름 전용 레이어.
##
## 왜 분리했나: 세로로 긴 SD 스프라이트는 위 칸을 침범한다. 같은 노드에서 그리면
## 앞줄 유닛의 몸이 뒷줄 유닛의 HP 바를 덮어 버린다. 고정 z 로 띄워야 항상 읽힌다.
class _Overlay extends Node2D:
	var owner_view: UnitView

	func _draw() -> void:
		if owner_view == null or owner_view.unit == null:
			return
		var u: Unit = owner_view.unit
		if not owner_view.shown_alive():
			return

		var top := UnitView.R + 3.0
		var hw := UnitView.HP_W
		draw_rect(Rect2(-hw * 0.5, top, hw, 6.0), Color(0, 0, 0, 0.65))
		var frac := clampf(float(u.hp) / float(u.max_hp), 0.0, 1.0)
		var hp_col := Color(0.35, 0.9, 0.45)
		if frac <= 0.25:
			hp_col = Color(0.92, 0.3, 0.3)
		elif frac <= 0.5:
			hp_col = Color(0.95, 0.75, 0.25)
		draw_rect(Rect2(-hw * 0.5, top, hw * frac, 6.0), hp_col)

		# 궁극기 표시. 1회제라 게이지가 아니라 켜짐/꺼짐이다.
		# 금색 = 아직 남았다, 어두운 회색 = 이미 썼다.
		if u.special != "":
			draw_rect(Rect2(-hw * 0.5, top + 7.0, hw, 3.0),
				Color(0.30, 0.28, 0.34) if u.special_used else Color(1.0, 0.85, 0.3))

		var f: Font = owner_view.font
		if f == null:
			return

		# 아트가 있으면 이름을 띄우지 않는다.
		#
		# SD 스프라이트는 세로로 길어 위 칸을 침범한다. 그 위에 이름표까지 얹으면
		# 위 유닛의 몸을 가리고 세로로 붙은 유닛끼리 글자가 겹쳐 아무것도 안 읽힌다.
		# 아트가 있으면 생김새만으로 누구인지 알 수 있으므로 이름은 불필요하다.
		# 도형 상태에서는 색 원만으로 구분이 안 되니 그때만 이름을 남긴다.
		if owner_view.has_art():
			return

		var head_y := -UnitView.R - 3.0
		var label: String = u.display_name
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UnitView.NAME_SIZE).x
		var at := Vector2(-w * 0.5, head_y)
		draw_string_outline(f, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1,
			UnitView.NAME_SIZE, 4, Color(0, 0, 0, 0.95))
		draw_string(f, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1,
			UnitView.NAME_SIZE, Color(1, 1, 1))


## 그 방향을 보게 한다. dx 가 0 에 가까우면(세로 이동) 지금 방향을 유지한다.
##
## 세로로 움직일 때까지 뒤집으면 대원이 제자리에서 빙글빙글 돈다. 좌우로 실제
## 의미 있게 움직일 때만 바꾼다.
func face_to(dx: float) -> void:
	if absf(dx) < 4.0:
		return
	var want: int = 1 if dx > 0.0 else -1
	if want == facing:
		return
	facing = want
	if _holder != null and is_instance_valid(_holder):
		_holder.scale.x = _scale_k * facing
		_holder.position.x = -_rig_center_x * _holder.scale.x
	elif art != null and art.texture != null:
		art.scale.x = _scale_k * facing


## 이 리그에서 그 동작에 해당하는 실제 애니메이션 이름. 없으면 "".
func resolve_anim(which: StringName) -> String:
	if anim == null:
		return ""
	for name in ANIM_ALIAS.get(which, [String(which)]):
		if anim.has_animation(String(name)):
			return String(name)
	return ""
