extends SceneTree

## 모든 .gd 를 실제로 로드해서 파싱 오류를 잡는다.
##
## ── 왜 필요한가 ──────────────────────────────────────────────────────────
## headless_test 는 core/ 와 data/ 만 건드린다. view/ 는 한 줄도 로드하지 않는다.
## 그래서 view/unit_view.gd 의 들여쓰기를 한 단계 어긋나게 고쳤을 때 213개 검사가
## 전부 통과했고, 감사도 0건이었고, 웹 빌드도 성공했다. 전투 화면에 들어가야만
## 터지는 상태로 배포됐다.
##
## Godot 은 스크립트를 지연 파싱하므로 "빌드가 됐다" 는 "파싱이 된다" 를 뜻하지
## 않는다. 그러니 전부 강제로 열어 보는 검사가 따로 있어야 한다.

func _init() -> void:
	print("=== 스크립트 파싱 검사 ===
")
	var files: Array[String] = []
	_collect("res://", files)
	files.sort()

	var bad: Array[String] = []
	var checked := 0
	for f in files:
		# 지금 실행 중인 스크립트는 건드리지 않는다. 다시 로드하면 엔진이 죽는다.
		if f == "res://test/parse_check.gd":
			continue
		checked += 1
		var res = load(f)
		if res == null or not (res is GDScript):
			bad.append(f + "  (로드 실패)")
			continue
		# reload() 는 소스를 다시 파싱하고 결과를 Error 로 돌려준다.
		# load() 는 캐시가 있으면 파싱을 건너뛸 수 있어서 이 단계가 따로 필요하다.
		var err: int = (res as GDScript).reload()
		if err != OK:
			bad.append("%s  (파싱 오류 %d)" % [f, err])

	for f in bad:
		print("  [FAIL] %s" % f)
	print("
=== %d개 스크립트 / 실패 %d개 ===" % [checked, bad.size()])
	quit(1 if bad.size() > 0 else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name.begins_with("."):
			name = d.get_next()
			continue
		var full: String = dir_path.path_join(name)
		if d.current_is_dir():
			_collect(full, out)
		elif name.ends_with(".gd"):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()
