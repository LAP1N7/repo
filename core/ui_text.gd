class_name UiText

## 화면에 뜨는 문구를 한 곳에 모은다.
##
## ── 왜 필요한가 ──────────────────────────────────────────────────────────
## 문구는 가장 자주 고치는 데이터인데 화면 다섯 개에 흩어져 하드코딩돼 있었다.
## "아직 산 카드가 없다" 한 줄을 고치려고 shop_screen.gd 를 열어야 하는 건
## 튜토리얼 대사를 코드에 박아 두는 것과 같은 문제다. (core/tutorial.gd 주석 참조)
##
## ── 왜 폴백이 있는가 ────────────────────────────────────────────────────
## t(id, fallback) 은 JSON 에 id 가 없으면 fallback 을 그대로 돌려준다.
## 그래서 옮기는 도중에도 화면이 절대 비지 않는다. 다 옮겼는지는 검사가 본다
## (test/text_check.gd) — 조용히 폴백에 의존하는 상태로 남지 않게.
##
## ── 왜 %s 를 그대로 두는가 ──────────────────────────────────────────────
## 문구에 숫자가 끼는 것이 많다("손패 %d장"). 서식 문자열째로 두고 호출부에서
## % 를 적용한다. JSON 을 고칠 때 %d 개수와 순서만 지키면 된다.

const PATH := "res://data/ui_text.json"

static var _map: Dictionary = {}
static var _loaded: bool = false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		push_warning("문구 파일을 찾을 수 없다: %s" % PATH)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("문구 파일 형식이 잘못됐다: %s" % PATH)
		return
	for k in parsed:
		# 주석용 키는 건너뛴다.
		if String(k).begins_with("_"):
			continue
		_map[String(k)] = String(parsed[k])


static func t(id: String, fallback: String = "") -> String:
	_load()
	return String(_map.get(id, fallback))


## 검사용. JSON 에 실제로 들어 있는 id 목록.
static func ids() -> Array:
	_load()
	return _map.keys()
