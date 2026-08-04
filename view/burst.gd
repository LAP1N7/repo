class_name Burst
extends Node2D

## 사망 파티클. 도형만으로 만든다. (DESIGN R2 연출 순서 5번)
##
## 각도를 난수가 아니라 인덱스로 균등 분배한다. 전투 결과와 무관한 순수 연출이지만,
## 영상을 다시 찍을 때 같은 그림이 나오는 편이 낫다.

const COUNT: int = 14
const LIFE: float = 0.55
const SPEED: float = 190.0
const GRAVITY: float = 420.0

var _color: Color = Color.WHITE
var _t: float = 0.0
var _pos: PackedVector2Array = []
var _vel: PackedVector2Array = []
var _size: PackedFloat32Array = []


func setup(color: Color) -> void:
	_color = color
	for i in COUNT:
		var a := TAU * float(i) / float(COUNT)
		# 인덱스로 속도를 흔들어 균일한 원이 아니라 흩어진 파편처럼 보이게 한다.
		var s := SPEED * (0.55 + 0.45 * fposmod(float(i) * 0.618, 1.0))
		_pos.append(Vector2.ZERO)
		_vel.append(Vector2(cos(a), sin(a)) * s)
		_size.append(3.0 + fposmod(float(i) * 0.37, 1.0) * 3.5)


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	for i in _pos.size():
		_vel[i] = _vel[i] + Vector2(0, GRAVITY) * delta
		_pos[i] = _pos[i] + _vel[i] * delta
	queue_redraw()


func _draw() -> void:
	var k := 1.0 - (_t / LIFE)
	var col := Color(_color.r, _color.g, _color.b, k)
	for i in _pos.size():
		var s := _size[i] * k
		draw_rect(Rect2(_pos[i] - Vector2(s, s) * 0.5, Vector2(s, s) * 1.0), col)
