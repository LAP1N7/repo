extends SceneTree

## 화면에 뜨는 모든 비ASCII 글자가 번들 폰트에 실제로 있는지 검사한다.
##
## ── 왜 필요한가 ──────────────────────────────────────────────────────────
## 프리텐다드에 없는 기호를 쓰면 네모(두부)로 뜬다. 오류도 경고도 없고, 헤드리스
## 검사에도 안 걸린다. 지금까지 🚫 · ⏹ · │ 를 하나씩 눈으로 발견해서 고쳤는데,
## 그때마다 다른 하나가 남아 있었다. 하나씩 잡는 방식으로는 끝나지 않는다.
##
## 소스에 박힌 문자열 리터럴을 전부 긁어서 글리프 유무를 한 번에 확인한다.

func _init() -> void:
	print("=== 글리프 검사 ===\n")
	# 폰트가 크기별로 둘이다. 한쪽만 검사하면 나머지 하나에서 네모가 뜬다 -
	# 작은 글씨용을 v2 로 바꾼 순간 이 검사는 큰 쪽만 보고 있었다.
	var fonts := { "큰": UiKit.font(), "작은": UiKit.font(UiKit.SMALL_MAX) }

	var files: Array[String] = []
	_collect("res://", files)
	files.append("res://data/tutorial.json")

	# 글자 -> 처음 발견한 위치
	var seen: Dictionary = {}
	for path in files:
		if not FileAccess.file_exists(path):
			continue
		for line in FileAccess.get_file_as_string(path).split("\n"):
			# 주석은 화면에 안 뜬다. 여기까지 검사하면 잡음만 늘어난다.
			var t := line.strip_edges()
			if t.begins_with("#") or t.begins_with("##"):
				continue
			for c in line:
				var cp := c.unicode_at(0)
				if cp < 128 or seen.has(c):
					continue
				seen[c] = path.get_file()

	var bad: Array[String] = []
	for which in fonts:
		var f: Font = fonts[which]
		for c in seen:
			if not f.has_char(String(c).unicode_at(0)):
				bad.append("[%s] %s  (U+%04X)  %s" % [
					which, c, String(c).unicode_at(0), seen[c]])

	bad.sort()
	for b in bad:
		print("  [FAIL] 글리프 없음: %s" % b)
	print("
=== 폰트 %d종 · 비ASCII %d종 / 빠진 글리프 %d건 ===" % [
		fonts.size(), seen.size(), bad.size()])
	quit(1 if bad.size() > 0 else 0)


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
				# test/ 는 콘솔에만 출력한다. 터미널 폰트는 번들 폰트와 무관하고
				# ─ ═ ▸ 같은 괘선은 거기서 잘 나온다. 화면에 뜨는 것만 본다.
				if not full.begins_with("res://test"):
					_collect(full, out)
			elif name.ends_with(".gd"):
				out.append(full)
		name = d.get_next()
	d.list_dir_end()
