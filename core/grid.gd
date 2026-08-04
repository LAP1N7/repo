class_name Grid
extends RefCounted

## 격자 좌표계와 이동 계산.
##
## 이 파일의 모든 함수는 순수 함수이고 난수를 쓰지 않는다.
## 동점이 생기면 항상 DIRS 의 고정 순서로 끊는다. (DESIGN 1-1 결정론적 전투)

const W: int = 8
const H: int = 6
const TILE: int = 64

## 방향 탐색 순서. 이 순서가 곧 동점 처리 규칙이므로 절대 바꾸지 말 것.
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0),   # →
	Vector2i(0, 1),   # ↓
	Vector2i(-1, 0),  # ←
	Vector2i(0, -1),  # ↑
]

## 아군 진영 6칸 / 적 진영 6칸 (좌우 대칭)
##
## 진영을 벽에 붙이지 않고 한 열씩 안으로 넣었다. x=0 과 x=7 은 비워 둔다.
## 진영이 x=0 에 있으면 후퇴/거리 유지가 물러날 칸이 없어
## 그대로 죽은 카드가 된다. 영상의 핵심 장면이 거리 유지 하나에 걸려 있으므로
## 뒷공간은 타협 대상이 아니다. 전선 간격은 3칸으로 종전과 같다.
const PLAYER_SLOTS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3),
	Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3),
]
const ENEMY_SLOTS: Array[Vector2i] = [
	Vector2i(6, 1), Vector2i(6, 2), Vector2i(6, 3),
	Vector2i(5, 1), Vector2i(5, 2), Vector2i(5, 3),
]

const UNREACHABLE: int = 1 << 20


static func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < W and p.y >= 0 and p.y < H


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## goal 로부터 자유 칸을 따라 퍼지는 BFS 거리장.
## blocked 는 Dictionary[Vector2i, bool] 형태의 점유 집합이며 goal 자신은 통과 가능하다.
## 반환값은 Dictionary[Vector2i, int].
static func distance_field(goal: Vector2i, blocked: Dictionary) -> Dictionary:
	var dist: Dictionary = {goal: 0}
	var queue: Array[Vector2i] = [goal]
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		var nd: int = int(dist[cur]) + 1
		for d in DIRS:
			var nxt: Vector2i = cur + d
			if not in_bounds(nxt):
				continue
			if dist.has(nxt):
				continue
			if blocked.has(nxt):
				continue  # 막힌 칸은 통과 불가 (goal 은 blocked 에 넣지 않는다)
			dist[nxt] = nd
			queue.append(nxt)
	return dist


## from 에서 goal 쪽으로 한 칸. 갈 곳이 없으면 from 을 그대로 돌려준다.
##
## 경로가 막혀 BFS 로 닿지 않으면 맨해튼 거리를 줄이는 쪽으로 폴백한다.
## (완전히 포위된 경우에만 제자리)
static func step_toward(from: Vector2i, goal: Vector2i, blocked: Dictionary) -> Vector2i:
	if from == goal:
		return from

	var field: Dictionary = distance_field(goal, blocked)
	var best: Vector2i = from
	var best_cost: int = field.get(from, UNREACHABLE)

	for d in DIRS:
		var nxt: Vector2i = from + d
		if not in_bounds(nxt) or blocked.has(nxt):
			continue
		var cost: int = field.get(nxt, UNREACHABLE)
		if cost < best_cost:
			best_cost = cost
			best = nxt

	if best != from:
		return best

	# 폴백: BFS 가 닿지 않는 상황. 맨해튼 거리라도 줄인다.
	var best_md: int = manhattan(from, goal)
	for d in DIRS:
		var nxt: Vector2i = from + d
		if not in_bounds(nxt) or blocked.has(nxt):
			continue
		var md: int = manhattan(nxt, goal)
		if md < best_md:
			best_md = md
			best = nxt
	return best


## from 에서 threat 로부터 멀어지는 한 칸. 물러설 곳이 없으면 from 그대로.
##
## 맨해튼 거리만 보면 "뒤로 한 칸"과 "옆으로 한 칸"이 동점이 된다. 같은 행에 있을 때
## 둘 다 거리를 1 늘리기 때문이다. 그대로 두면 DIRS 순서 탓에 옆걸음이 먼저 잡혀
## 궁수가 게걸음을 치며 도망간다. 영상에서 바로 티가 나므로 유클리드 제곱거리로
## 동점을 끊어 "정면으로 물러나기"를 우선한다. (여전히 정수 연산 = 결정론 유지)
static func step_away(from: Vector2i, threat: Vector2i, blocked: Dictionary) -> Vector2i:
	var best: Vector2i = from
	var best_md: int = manhattan(from, threat)
	var best_sq: int = _dist_sq(from, threat)
	for d in DIRS:
		var nxt: Vector2i = from + d
		if not in_bounds(nxt) or blocked.has(nxt):
			continue
		var md: int = manhattan(nxt, threat)
		if md < best_md:
			continue
		var sq: int = _dist_sq(nxt, threat)
		if md > best_md or sq > best_sq:
			best_md = md
			best_sq = sq
			best = nxt
	return best


## a 와 b 사이를 잇는 칸들. 양 끝은 포함하지 않는다.
##
## 정수 브레젠험이라 부동소수점이 끼지 않는다 - 결정론을 지키려면 필수다.
static func line_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dx: int = absi(b.x - a.x)
	var dy: int = -absi(b.y - a.y)
	var sx: int = 1 if a.x < b.x else -1
	var sy: int = 1 if a.y < b.y else -1
	var err: int = dx + dy
	var x: int = a.x
	var y: int = a.y
	# 격자 크기가 8×6 이라 최악이어도 14칸이다. 안전장치로 상한만 둔다.
	for _guard in 64:
		if x == b.x and y == b.y:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
		if x == b.x and y == b.y:
			break
		out.append(Vector2i(x, y))
	return out


## from 에서 to 를 쏠 수 있는가. blockers 안의 칸이 사이를 막으면 불가.
##
## 인접(맨해튼 1)은 사이에 칸이 없으므로 항상 가능하다.
static func has_line_of_sight(from: Vector2i, to: Vector2i, blockers: Dictionary) -> bool:
	if manhattan(from, to) <= 1:
		return true
	for c in line_cells(from, to):
		if blockers.has(c):
			return false
	return true


static func _dist_sq(a: Vector2i, b: Vector2i) -> int:
	var dx: int = a.x - b.x
	var dy: int = a.y - b.y
	return dx * dx + dy * dy
