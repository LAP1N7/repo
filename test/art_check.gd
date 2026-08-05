extends SceneTree
func _init() -> void:
	var bad := 0
	print("=== 일러스트 · 컷인 자원 검사 ===")
	for uid in ["warrior", "archer", "bard", "assassin", "musketeer", "shieldman"]:
		var t := UiKit.art(["cutin", "standing"], uid)
		if t == null:
			print("  [FAIL] 일러스트 없음: ", uid); bad += 1; continue
		print("  [ok] %-10s %dx%d" % [uid, t.get_width(), t.get_height()])
	# 컷인 이름은 title 역할 폰트로 찍는다. 글리프가 없으면 두부가 뜬다.
	var f := UiKit.title_font()
	for sid in Specials.TABLE:
		var nm := String(Specials.TABLE[sid]["name"])
		for ch in nm:
			if not f.has_char(ch.unicode_at(0)):
				print("  [FAIL] 제목 폰트에 '%s' 없음 (%s)" % [ch, nm]); bad += 1
	print("=== 실패 %d개 ===" % bad)
	quit(1 if bad > 0 else 0)
