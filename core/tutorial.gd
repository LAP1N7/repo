class_name Tutorial
extends RefCounted

## 튜토리얼 진행 상태.
##
## ── 왜 별도 객체인가 ────────────────────────────────────────────────────
## 튜토리얼은 상점 · 편성 · 전투 세 화면을 가로지른다. 각 화면이 자기 안에서
## 튜토리얼을 들고 있으면 화면을 넘어갈 때 진행도가 끊긴다. 그래서 게임 루트가
## 하나만 들고 다니고, 화면은 "지금 몇 번째 대사인가" 를 물어보기만 한다.
##
## ── 왜 대사가 JSON 인가 ────────────────────────────────────────────────
## 대사는 가장 자주 고치는 데이터다. 코드에 박으면 문구 하나 바꾸는 데 재빌드가
## 필요하고, 무엇보다 기획자가 못 만진다.
##
## ── 왜 파일이 둘인가 ───────────────────────────────────────────────────
## 고치는 빈도가 다르기 때문이다.
##
##   data/tutorial.json  **언제 어디서 뜨는가** - 화면 · 가리킬 대상 ·
##                       넘어가는 조건 · 멈출 틱. 거의 안 고친다
##   data/story.json     **무슨 말을 하는가** - "tutorial" 항목에 step id 로
##                       들어 있다. 자주 고친다
##
## 한 파일에 섞여 있으면 말 한 줄 고치려고 앵커와 게이트 사이를 헤집어야 한다.
## 본편 스토리 대사도 story.json 에 있으므로, **대사는 전부 한 파일**이 된다.
const DATA_PATH := "res://data/tutorial.json"
const TEXT_PATH := "res://data/story.json"

signal step_changed()
signal finished()

var steps: Array = []
var speaker_name: String = ""
var index: int = -1

## 화면이 등록한 UI 앵커. 말풍선이 가리키고, 게이트가 그 밖의 클릭을 막는다.
## 이름 -> Control
var anchors: Dictionary = {}

var active: bool = false


func load_script() -> bool:
	if not FileAccess.file_exists(DATA_PATH):
		push_error("튜토리얼 대본을 찾을 수 없다: %s" % DATA_PATH)
		return false
	var raw := FileAccess.get_file_as_string(DATA_PATH)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("steps"):
		push_error("튜토리얼 대본 형식이 잘못됐다: %s" % DATA_PATH)
		return false
	steps = parsed["steps"]
	speaker_name = String(parsed.get("speaker_name", ""))
	_load_lines()
	return true


## story.json 에서 대사를 끌어와 단계에 채운다.
##
## 없으면 tutorial.json 에 남아 있는 text 를 그대로 쓴다 - 대본 파일 하나가
## 빠져도 훈련 과정이 통째로 벙어리가 되지는 않는다.
func _load_lines() -> void:
	if not FileAccess.file_exists(TEXT_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(TEXT_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var lines: Dictionary = parsed.get("tutorial", {})
	if lines.is_empty():
		return
	for i in steps.size():
		var st: Dictionary = steps[i]
		var id := String(st.get("id", ""))
		if lines.has(id):
			st["text"] = String(lines[id])
		steps[i] = st


func start() -> void:
	if steps.is_empty() and not load_script():
		return
	active = true
	index = 0
	step_changed.emit()


func stop() -> void:
	active = false
	index = -1
	anchors.clear()


func current() -> Dictionary:
	if not active or index < 0 or index >= steps.size():
		return {}
	return steps[index]


## 지금 대사가 이 화면에서 떠야 하는가.
func is_for_screen(screen: String) -> bool:
	var s := current()
	if s.is_empty():
		return false
	var want := String(s.get("screen", "any"))
	return want == "any" or want == screen


func advance() -> void:
	if not active:
		return
	index += 1
	if index >= steps.size():
		active = false
		finished.emit()
		return
	step_changed.emit()


## 게임에서 어떤 행동이 일어났음을 알린다.
## 지금 대사가 그 행동을 기다리고 있었다면 다음으로 넘어간다.
func notify_action(action: String) -> void:
	var s := current()
	if s.is_empty():
		return
	var adv := String(s.get("advance", "click"))
	if adv == "action:" + action:
		advance()


## 이 틱이 시작될 때 전투를 멈추고 설명해야 하는가.
##
## "사거리 → 이동 → 카이팅 → 기본기" 를 차례로 보여주려면 전투가 흘러가는 중간에
## 끼어들어야 한다. 대사에 at_tick 을 적으면 그 틱 앞에서 재생이 멈춘다.
func pauses_at_tick(tick: int) -> bool:
	var s := current()
	if s.is_empty() or not s.has("at_tick"):
		return false
	return int(s["at_tick"]) == tick


## 지금 대사가 클릭만으로 넘어가는가.
func advances_on_click() -> bool:
	var s := current()
	return not s.is_empty() and String(s.get("advance", "click")) == "click"


## 다른 조작을 막아야 하는가. 막으면 앵커만 누를 수 있다.
func gates_input() -> bool:
	var s := current()
	return not s.is_empty() and bool(s.get("gate", false))


func anchor_name() -> String:
	var s := current()
	return String(s.get("anchor", ""))


func register_anchor(name: String, node: Control) -> void:
	if node != null:
		anchors[name] = node


func clear_anchors() -> void:
	anchors.clear()


## 지금 대사가 가리키는 노드. 없으면 null.
func anchor_node() -> Control:
	var n := anchor_name()
	if n == "" or not anchors.has(n):
		return null
	var c = anchors[n]
	return c if is_instance_valid(c) else null
