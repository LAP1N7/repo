class_name UiKit

## 화면 세 개가 공유하는 색·폰트·위젯 생성기.

const BG := Color(0.075, 0.085, 0.11)
const PANEL := Color(0.13, 0.15, 0.19)
const PANEL_HI := Color(0.19, 0.22, 0.28)
const LINE := Color(0.30, 0.34, 0.42)
const TEXT := Color(0.93, 0.94, 0.97)
const MUTED := Color(0.55, 0.58, 0.68)
## 부차 정보용. LINE(0.30) 은 테두리 색이라 글자로 쓰면 거의 안 읽힌다.
const FAINT := Color(0.46, 0.50, 0.60)
## ── 빨강·노랑은 채도를 한 단계 올려 둔다 ────────────────────────────────
## 배경이 청회색으로 깔리면서 따뜻한 색이 전부 뿌옇게 보였다. 화면에서 가장
## 급한 정보(피해·경고·강조)가 배경에 묻히면 색을 쓰는 의미가 없다.
##
## 초록(GOOD)은 안 건드린다. 회복은 급한 정보가 아니고, 초록까지 같이 올리면
## 세 색이 전부 튀어서 다시 아무것도 안 튀는 것과 같아진다.
const ACCENT := Color(1.0, 0.74, 0.20)
const GOOD := Color(0.36, 0.96, 0.58)
const BAD := Color(1.0, 0.33, 0.28)
const TEAM_P := Color(0.32, 0.76, 1.0)
const TEAM_E := Color(1.0, 0.33, 0.28)

static var _font: Font = null


## 프로젝트에 심어 둔 프리텐다드(OFL)를 쓴다.
##
## Godot 기본 폰트에는 한글 글리프가 없어서 그냥 두면 전부 네모로 뜬다.
## 예전에는 시스템 폰트(맑은 고딕)를 빌려 썼는데 웹 빌드에서 통째로 깨졌다.
## 브라우저 샌드박스에서는 C:/Windows/Fonts 에 접근할 수 없기 때문이다.
## 게다가 맑은 고딕은 재배포 불가라 애초에 빌드에 넣을 수도 없다. (DESIGN 6장)
##
## 그래서 OFL 폰트를 res:// 에 포함하는 것이 유일하게 옳은 방법이다.
## 시스템 폰트 경로는 폰트 임포트가 깨졌을 때를 위한 폴백으로만 남겨 둔다.
## 우선순위대로 찾는다. 앞엣것이 없으면 뒤엣것으로 내려간다.
## 폰트는 **역할별**로 나눠 쓴다. 배정은 data/fonts.json 에 있다.
##
## ── 왜 나누는가 ──────────────────────────────────────────────────────────
## 하나로 통일하면 반드시 어딘가가 깨진다. 장식적인 제목용 서체는 9~13px 로
## 들어가면 획이 뭉쳐 못 읽고, 반대로 가독성 위주 서체로 제목을 뽑으면 밋밋하다.
##
##   title  게임 이름 전용. 한 줄밖에 안 쓰니 굵고 장식적이어도 된다
##   large  화면 제목·유닛 이름·버튼
##   small  카드 설명·전투 로그·배지. **가독성이 전부다**
##
## ── 왜 코드가 아니라 JSON 인가 ──────────────────────────────────────────
## 서체는 자주 갈아 끼운다. 실제로 이 프로젝트에서만 세 번 바뀌었다.
## 파일 경로를 코드에 박으면 바꿀 때마다 여러 파일을 손대게 된다.
const FONT_CONFIG := "res://data/fonts.json"

static var _cfg: Dictionary = {}
static var _by_role: Dictionary = {}


static func _config() -> Dictionary:
	if not _cfg.is_empty():
		return _cfg
	_cfg = {
		"small_max": 13,
		"pixel_render": true,
		"roles": {},
	}
	if FileAccess.file_exists(FONT_CONFIG):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(FONT_CONFIG))
		if typeof(parsed) == TYPE_DICTIONARY:
			for k in parsed:
				if not String(k).begins_with("_"):
					_cfg[k] = parsed[k]
	return _cfg


## 이 크기 이하는 작은 글씨용 폰트를 쓴다.
static func small_max() -> int:
	return int(_config().get("small_max", 13))


## 역할 이름으로 폰트를 얻는다. 목록을 앞에서부터 훑어 처음 읽히는 것을 쓴다.
static func font_role(role: String) -> Font:
	if _by_role.has(role):
		return _by_role[role]

	var roles: Dictionary = _config().get("roles", {})
	for path in roles.get(role, []):
		if not ResourceLoader.exists(String(path)):
			continue
		var f = load(String(path))
		if f is Font:
			if bool(_config().get("pixel_render", true)):
				_tune_pixel_font(f)
			_by_role[role] = f
			return f

	# 어느 것도 못 읽었다. 시스템 폰트로라도 글자는 나와야 한다.
	push_warning("폰트 역할 '%s' 을 못 읽었다 - 시스템 폰트로 폴백한다." % role)
	var sys := _system_font()
	_by_role[role] = sys
	return sys


## 게임 이름 전용.
static func title_font() -> Font:
	return font_role("title")


## 캐릭터 일러스트를 찾아 온다. 없으면 null - 아트가 없어도 게임은 돌아간다.
##
## dirs 는 우선순위 순서다. 앞쪽에 전용 컷을 두고 뒤에 공용 일러스트를 두면
## "전용이 있으면 그걸, 없으면 공용을" 이 된다.
##
## 확장자를 여기서만 안다. 원본은 png 로 받지만 웹 빌드에 얹으려고 webp 로
## 굽는다(6장 5.1MB -> 0.9MB). 파일을 다시 png 로 되돌려도 호출부는 안 바뀐다.
static func art(dirs: Array, id: String) -> Texture2D:
	if id == "":
		return null
	for d in dirs:
		for ext in [".webp", ".png"]:
			var path: String = "res://assets/art/%s/%s%s" % [d, id, ext]
			if ResourceLoader.exists(path):
				var t := load(path)
				if t is Texture2D:
					return t
	return null


## size 를 주면 그 크기에 맞는 폰트를 돌려준다. 0 이면 큰 글씨용.
## ── 그림은 반드시 이 함수로 붙인다 ───────────────────────────────────────
##
## **_draw() 안에서 draw_texture_rect 를 쓰지 말 것.** 이 프로젝트에서는 그리면
## 흰/회색 사각형이 나온다. 네 번 겪었다 - SD 얼굴, 판 뒤 지형, 스토리 초상,
## 편성 얼굴 타일. 매번 좌표를 의심하다가 화면을 찍고서야 알아냈다.
##
## 그리고 TextureRect 는 expand_mode 를 안 바꾸면 **최소 크기가 텍스처 크기**다.
## 75px 칸에 넣어도 192px 로 되돌아가서 왼쪽 위 귀퉁이만 보인다. 이것도 한 번
## 걸렸다.
##
## 둘 다 여기서 막는다. 호출부는 "어디에 얼마만큼" 만 말하면 된다.
##
##   fit  "contain" 그림 전체가 들어간다 (여백이 생길 수 있다)
##        "cover"   칸을 채우고 넘치는 쪽을 자른다
##
## 반환은 만들어진 노드다. 나중에 texture 만 갈아 끼우려면 들고 있으면 된다.
static func image(parent: Node, rect: Rect2, tex: Texture2D,
		fit: String = "contain", tint: Color = Color.WHITE) -> Control:
	var clip := Control.new()
	clip.position = rect.position
	clip.size = rect.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(clip)

	var tr := TextureRect.new()
	tr.texture = tex
	tr.modulate = tint
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 최소 크기를 텍스처 크기로 잡지 않게 한다. 이 한 줄이 빠지면 칸보다 큰
	# 그림이 칸을 무시하고 원래 크기로 되돌아간다.
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if tex != null and fit == "cover" and tex.get_height() > 0:
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		var ts := Vector2(tex.get_width(), tex.get_height())
		var k: float = maxf(rect.size.x / ts.x, rect.size.y / ts.y)
		tr.size = ts * k
		# 인물은 발치보다 얼굴이 중요하다. 넘치는 세로는 위쪽을 살린다.
		tr.position = Vector2((rect.size.x - tr.size.x) * 0.5,
			(rect.size.y - tr.size.y) * 0.25)
	else:
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2.ZERO
		tr.size = rect.size
	clip.add_child(tr)
	return clip


static func font(size: int = 0) -> Font:
	return font_role("small" if (size > 0 and size <= small_max()) else "large")


static func _system_font() -> Font:
	if _font != null:
		return _font
	for p in [
		"C:/Windows/Fonts/malgun.ttf",
		"C:/Windows/Fonts/NanumGothic.ttf",
		"/System/Library/Fonts/AppleSDGothicNeo.ttc",
		"/usr/share/fonts/truetype/nanum/NanumGothic.ttf",
	]:
		if FileAccess.file_exists(p):
			var f := FontFile.new()
			if f.load_dynamic_font(p) == OK:
				_font = f
				return _font
	push_warning("한글 폰트를 찾지 못했다. 글자가 깨져 보일 수 있다.")
	_font = ThemeDB.fallback_font
	return _font


## 비트맵 스타일 폰트는 안티에일리어싱을 끄고 서브픽셀을 잠가야 제 모습이 나온다.
## 켜 두면 획이 뭉개져서 "픽셀 폰트인데 흐릿한" 최악의 조합이 된다.
## 아웃라인 폰트(프리텐다드)에 걸어도 해롭지 않으므로 조건 없이 적용한다.
static func _tune_pixel_font(f: Font) -> void:
	if not (f is FontFile):
		return
	var ff := f as FontFile
	ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	ff.hinting = TextServer.HINTING_NONE


static func box(bg: Color, border: Color, radius: int = 5, hpad: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = hpad
	sb.content_margin_right = hpad
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


## wrap 을 켜면 지정한 폭에서 줄이 접힌다.
##
## ── 왜 옵션이 따로 있는가 ────────────────────────────────────────────────
## Label 은 자동 줄바꿈이 꺼져 있으면 텍스트 한 줄 전체가 **최소 폭**이 된다.
## Control 은 최소 크기보다 작아질 수 없으므로, 긴 문장을 넣고 size 를 좁게 줘도
## 라벨이 제멋대로 늘어나 부모 패널을 뚫고 나간다. 보상 화면의 궁극기 설명이
## 옆 카드까지 넘어가던 게 이것이었다.
##
## 그래서 autowrap 을 **size 보다 먼저** 켜야 한다. 나중에 켜면 이미 커진 크기가
## 다시 줄어들지 않는다.
static func label(parent: Node, pos: Vector2, size: Vector2, text: String,
		fsize: int, col: Color = TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = text
	l.position = pos
	l.size = size
	l.add_theme_font_override("font", font(fsize))
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	# 트리에 들어가면서 최소 크기 규칙으로 다시 커질 수 있다. 한 번 더 못 박는다.
	l.size = size
	return l


static func button(parent: Node, pos: Vector2, size: Vector2, text: String,
		fsize: int = 14, hpad: int = 8) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.add_theme_font_override("font", font(fsize))
	b.add_theme_font_size_override("font_size", fsize)
	b.add_theme_stylebox_override("normal", box(PANEL, LINE, 5, hpad))
	b.add_theme_stylebox_override("hover", box(PANEL_HI, Color(0.6, 0.65, 0.8), 5, hpad))
	b.add_theme_stylebox_override("pressed",
		box(Color(0.28, 0.32, 0.42), Color(0.8, 0.85, 1.0), 5, hpad))
	# 비활성 버튼은 BG(0.075,0.085,0.11)보다 **밝아야** 한다.
	# 예전 값 0.11/0.12/0.15 는 배경과 거의 같아서, 버튼이 사라진 게 아니라
	# 화면에 검은 사각형이 얹힌 것처럼 보였다. 튜토리얼이 그 버튼을 주황 테두리로
	# 가리키고 있을 때 특히 그랬다 - "누르라는데 검은 구멍이 있다" 가 된다.
	# 눌리지 않는다는 건 글자색으로 말하고, 형태는 계속 버튼으로 남긴다.
	b.add_theme_stylebox_override("disabled",
		box(Color(0.145, 0.16, 0.20), Color(0.26, 0.28, 0.34), 5, hpad))
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.42, 0.5))
	b.clip_text = true
	parent.add_child(b)
	return b


## 한 스테이지를 치르는 세 국면. 화면 순서와 같다.
## 한 스테이지를 치르는 세 국면. 화면 순서와 같다.
## const 로 못 둔다 - 문구를 data/ui_text.json 에서 읽어야 하는데 const 는
## 함수 호출을 못 하기 때문이다.
static func phases() -> Array[String]:
	return [
		UiText.t("phase.shop", "덱 구성"),
		UiText.t("phase.loadout", "편성과 배치"),
		UiText.t("phase.battle", "전투"),
	]


## 화면 제목 + 진행 표시.
##
## ── 왜 "1단계 · 덱 구성" 을 버렸는가 ─────────────────────────────────────
## 그 바로 아래에 "스테이지 1/5" 가 뜬다. 서로 다른 두 진행도가 똑같이 "단계" 로
## 불리니 화면에 숫자가 두 개 있고 어느 쪽이 어느 쪽인지 읽을 수가 없었다.
## 국면은 이름으로, 진행은 위치로 보여 준다 - 숫자는 스테이지 하나만 남긴다.
static func phase_header(parent: Node, pos: Vector2, index: int) -> void:
	var f := font()
	var names := phases()
	label(parent, pos, Vector2(600, 34), names[index], 26)

	# 제목 **오른쪽**에 붙인다. 아래에 두면 화면마다 있는 스테이지 줄과 겹친다.
	# (실제로 겹쳐서 글자가 뭉갰다)
	var x: float = pos.x + f.get_string_size(
		names[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 24.0
	var y: float = pos.y + 13.0
	for i in names.size():
		var on := i == index
		var t: String = names[i]
		label(parent, Vector2(x, y), Vector2(160, 18), t, 11,
			ACCENT if on else Color(0.38, 0.41, 0.50))
		x += f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 6.0
		if i < names.size() - 1:
			label(parent, Vector2(x, y), Vector2(20, 18), ">", 11,
				Color(0.38, 0.41, 0.50))
			x += 12.0


## 카드 코스트를 색으로 읽히게. 비싼 카드일수록 눈에 띈다.
static func cost_color(cost: int) -> Color:
	match cost:
		0: return Color(0.55, 0.60, 0.70)
		1: return Color(0.50, 0.80, 0.95)
		2: return Color(0.45, 0.90, 0.65)
		3: return Color(1.0, 0.78, 0.35)
	return Color(1.0, 0.45, 0.45)


## 화면 상단의 가로 바와 네 모서리 꺾쇠.
##
## ── 왜 이게 톤을 바꾸는가 ────────────────────────────────────────────────
## 이 게임 화면의 인상은 장식이 아니라 **정렬**에서 온다. 얇은 가로선 하나가
## 화면 위를 가로지르면 그 아래 요소들이 전부 그 선에 맞춰 정렬된 것처럼 읽힌다.
## 거기에 각진 모서리 꺾쇠를 더한다 - 화면이 창이 아니라 계기판으로
## 보이게 하는 최소한의 표식이다.
##
## 굵게 그리면 안 된다. 이 선들은 읽는 대상이 아니라 배경이라, 눈에 띄는
## 순간 본문과 경쟁한다. 전부 1~2px 에 알파를 낮게 둔다.
class Frame extends Control:
	var accent: Color = Color(0.38, 0.80, 0.86)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var line := Color(accent.r, accent.g, accent.b, 0.22)
		var faint := Color(accent.r, accent.g, accent.b, 0.10)

		# 상단 가로 바. 왼쪽은 진하고 오른쪽으로 갈수록 흐려진다.
		# y=26 에 두면 화면 제목(y16~50)을 가로지른다. 위로 붙인다.
		draw_line(Vector2(36, 10), Vector2(w * 0.45, 10), line, 2.0)
		draw_line(Vector2(w * 0.45, 10), Vector2(w - 36, 10), faint, 1.0)

		# 하단도 같은 어법으로 한 줄. 화면이 위아래로 닫힌 것처럼 보인다.
		draw_line(Vector2(36, h - 26), Vector2(w - 36, h - 26), faint, 1.0)

		# 네 모서리 꺾쇠.
		var box := Rect2(20, 6, w - 40, h - 26)
		for corner in [
			[box.position, Vector2(1, 0), Vector2(0, 1)],
			[Vector2(box.end.x, box.position.y), Vector2(-1, 0), Vector2(0, 1)],
			[Vector2(box.position.x, box.end.y), Vector2(1, 0), Vector2(0, -1)],
			[box.end, Vector2(-1, 0), Vector2(0, -1)],
		]:
			var o: Vector2 = corner[0]
			draw_line(o, o + corner[1] * 26.0, line, 2.0)
			draw_line(o, o + corner[2] * 26.0, line, 2.0)

		# 오른쪽 눈금. 계기판 느낌을 만드는 마지막 한 겹이다.
		for i in 9:
			var y := 90.0 + i * ((h - 180.0) / 9.0)
			draw_line(Vector2(w - 30, y), Vector2(w - 30 - (10.0 if i % 3 == 0 else 5.0), y),
				faint, 1.0)


## 화면 뒤에 톤 프레임을 깐다. 각 화면의 setup 첫 줄에서 부르면 된다.
static func frame(host: Control, accent: Color = Color(0.38, 0.80, 0.86)) -> Control:
	var f := Frame.new()
	f.accent = accent
	f.size = Vector2(1280, 720)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(f)
	return f


## ── 배경 장식 ────────────────────────────────────────────────────────────
## HUD 배경이 순수한 검정이라 화면이 "비어 있다" 로 읽혔다. 무늬를 깔면 같은
## 여백이 **여백으로** 읽힌다 - 아무것도 없는 것과 조용한 것은 다르다.
##
## 사이버펑크 HUD 무늬의 문법은 넷이다.
##   동심 호   - 반쯤 끊긴 고리 여럿. 계측기의 눈금판이다.
##   눈금 열   - 한 변을 따라 늘어선 짧은 선들. 자(尺)다.
##   다각 윤곽 - 육각 테두리. 회로 블록이다.
##
## 미세 격자는 뺐다. 화면에 이미 격자가 있는데(교전 판·적 배치 미리보기)
## 배경에까지 격자를 깔면 그 둘과 섞여 어느 것이 판인지 흐려진다.
##
## 전부 알파 0.05 아래로 깐다. 이건 배경이고, 배경이 읽히기 시작하면 그건
## 이미 배경이 아니다. 좌표는 고정 시드 LCG 로 만든다 - 볼 때마다 달라지면
## 무늬가 아니라 잡음이 된다.
class Deco extends Control:
	## 무늬 색. 화면마다 조금씩 다르게 줄 수 있다.
	var tint: Color = Color(0.30, 0.72, 1.0)
	## 전체 진하기 배수.
	var strength: float = 1.0
	## 무늬 배치 시드. 화면마다 다른 값을 주면 같은 무늬가 안 반복된다.
	var seed_v: int = 7

	var _rng: int = 0

	func _r() -> float:
		_rng = (_rng * 1103515245 + 12345) & 0x7FFFFFFF
		return float(_rng % 10000) / 10000.0

	func _draw() -> void:
		_rng = seed_v * 7919 + 13
		var s := size
		var a := 0.07 * strength

		# 동심 호 셋.
		for i in 3:
			var c := Vector2(_r() * s.x, _r() * s.y)
			var r0 := 60.0 + _r() * 120.0
			for k in 4:
				var rr := r0 + float(k) * 9.0
				var a0 := _r() * TAU
				draw_arc(c, rr, a0, a0 + 1.2 + _r() * 2.4, 40,
					Color(tint.r, tint.g, tint.b, a * (1.0 - 0.15 * float(k))), 1.5)

		# 눈금 열. 화면 오른쪽 변을 따라.
		var tx := s.x - 26.0
		var n := int(s.y / 26.0)
		for i in n:
			var long_tick: bool = i % 5 == 0
			draw_line(Vector2(tx, 20.0 + float(i) * 26.0),
				Vector2(tx + (14.0 if long_tick else 7.0), 20.0 + float(i) * 26.0),
				Color(tint.r, tint.g, tint.b, a * (1.4 if long_tick else 0.8)), 1.0)

		# 육각 윤곽 둘.
		for i in 2:
			var hc := Vector2(_r() * s.x, _r() * s.y)
			var hr := 40.0 + _r() * 70.0
			var pts := PackedVector2Array()
			for k in 7:
				var ang := TAU * float(k) / 6.0
				pts.append(hc + Vector2(cos(ang), sin(ang)) * hr)
			draw_polyline(pts, Color(tint.r, tint.g, tint.b, a * 0.9), 1.4, true)


## 배경 장식 한 겹을 화면에 깐다. bg 바로 위, 내용 아래에 들어간다.
static func deco(parent: Node, seed_v: int = 7, strength: float = 1.0,
		tint: Color = Color(0.30, 0.72, 1.0)) -> Control:
	var d := Deco.new()
	d.seed_v = seed_v
	d.strength = strength
	d.tint = tint
	d.size = Vector2(1280, 720)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(d)
	return d
