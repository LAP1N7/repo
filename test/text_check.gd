extends SceneTree

## 화면 문구가 전부 data/ui_text.json 에 들어 있는가.
##
## ── 왜 필요한가 ──────────────────────────────────────────────────────────
## UiText.t(id, fallback) 은 id 가 없으면 코드에 적힌 fallback 을 그대로 쓴다.
## 화면은 멀쩡히 나오지만 **JSON 을 고쳐도 안 바뀐다.** 문구를 한 곳에서 고치려고
## 만든 구조인데 조용히 반쪽이 되는 것이다. 그 상태를 여기서 잡는다.
##
## 반대 방향도 본다 - JSON 에만 있고 아무도 안 쓰는 id 는 고쳐도 화면이 안 바뀐다.

func _init() -> void:
	print("=== 문구 검사 ===\n")

	var used: Dictionary = {}
	var files: Array[String] = []
	# view/ 만 훑다가 core/run_state.gd 의 안내문을 놓쳤다. 두 폴더를 다 본다.
	_collect("res://view", files)
	_collect("res://core", files)

	var re := RegEx.new()
	# 정규식에 큰따옴표를 직접 못 쓴다 - GDScript 가 \" 를 이스케이프로 본다.
	# 코드포인트로 만들어 붙인다.
	var q := char(34)
	re.compile("UiText\\.t\\(" + q + "([^" + q + "]+)" + q)
	for f in files:
		if not FileAccess.file_exists(f):
			continue
		for m in re.search_all(FileAccess.get_file_as_string(f)):
			used[m.get_string(1)] = f.get_file()

	var have := UiText.ids()
	var missing: Array[String] = []
	for id in used:
		if not have.has(id):
			missing.append("%s  (%s)" % [id, used[id]])
	var unused: Array[String] = []
	for id in have:
		if not used.has(id):
			unused.append(String(id))

	missing.sort()
	unused.sort()
	for m in missing:
		print("  [FAIL] JSON 에 없는 id: %s" % m)
	for u in unused:
		print("  [경고] 아무도 안 쓰는 id: %s" % u)

	print("\n=== 문구 %d개 / 코드가 쓰는 %d개 / 누락 %d개 ===" % [
		have.size(), used.size(), missing.size()])
	quit(1 if missing.size() > 0 else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if not name.begins_with("."):
			var full: String = dir_path.path_join(name)
			if d.current_is_dir():
				_collect(full, out)
			elif name.ends_with(".gd"):
				out.append(full)
		name = d.get_next()
	d.list_dir_end()
