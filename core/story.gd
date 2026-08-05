class_name Story

## 스토리 대본 접근기.
##
## ── 왜 이 층이 따로 있는가 ───────────────────────────────────────────────
## 화면(view/story_screen.gd)은 "장면 하나를 어떻게 보여 줄까" 만 안다. 어떤
## 장면이 언제 나오는지는 데이터가 정한다. 그래야 대본을 고칠 때 코드를 안 만진다.
##
## 튜토리얼(core/tutorial.gd)과 같은 원칙인데 구조는 훨씬 단순하다. 튜토리얼은
## 플레이어의 조작을 기다려야 해서 앵커·게이트가 필요했지만, 스토리는 읽고
## 넘기기만 하면 된다.

const PATH := "res://data/story.json"

static var _data: Dictionary = {}


static func _load() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_warning("스토리 대본을 못 읽었다: %s" % PATH)
		_data = { "_missing": true }
		return _data
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_data = parsed if typeof(parsed) == TYPE_DICTIONARY else { "_missing": true }
	return _data


## 그 시점의 장면들. 없으면 빈 배열이다.
##
## when 은 "pre" 또는 "post", stage 는 1~5.
## 대본에 없는 조합이면 조용히 건너뛴다 - 이야기가 덜 쓰인 단계가 있어도
## 게임은 굴러가야 한다.
static func beats(when: String, stage: int) -> Array:
	var key := "%s_%d" % [when, stage]
	var v = _load().get(key, [])
	return v if typeof(v) == TYPE_ARRAY else []


static func has(when: String, stage: int) -> bool:
	return not beats(when, stage).is_empty()


## 대본이 쓰는 연출 이름 전체. 검사가 이걸로 오타를 잡는다.
const EFFECTS := ["glitch", "sync", "log", "collapse"]


## 대본 전체를 재생 순서대로 이어 붙인다. 스토리 몰아보기가 쓴다.
##
## ── 왜 필요한가 ──────────────────────────────────────────────────────────
## 스토리는 다섯 판을 다 이겨야 끝까지 볼 수 있다. 대사 한 줄을 고칠 때마다
## 그걸 다시 하는 건 말이 안 된다. 대본을 짜는 동안은 게임을 건너뛰고 이야기만
## 볼 수 있어야 한다.
##
## 구간 사이에 표지 장면을 끼운다. 어느 대목을 보고 있는지가 안 보이면 몰아볼
## 때 위치를 잃는다.
static func all_beats() -> Array:
	var out: Array = []
	for stage in [1, 2, 3, 4, 5]:
		for when in ["pre", "post"]:
			var b := beats(when, stage)
			if b.is_empty():
				continue
			out.append({
				"speaker": "",
				"text": "%d단계 %s" % [stage, "진입 전" if when == "pre" else "완료 후"],
				"marker": true,
			})
			out.append_array(b)
	return out


## 4스테이지 로그 화면에 흐르는 줄들.
##
## 시설 관리 기록이 평범하게 쌓이다가 어느 지점부터 눈이 못 따라갈 속도로
## 올라간다. 그 가속 자체가 "무언가 일어났다" 를 말한다 - 글로 설명하지 않는다.
const LOG_LINES: Array[String] = [
	"[INFO] 30y 178d 14h 20m ago   제 13구역 환경 보호 시설 자가 수리 진행",
	"[INFO] 30y 177d 09h 02m ago   제 22구역 급수 시설 배관 점검",
	"[INFO] 30y 171d 22h 41m ago   제 04구역 격벽 밀폐 상태 확인",
	"[INFO] 29y 340d 03h 17m ago   제 13구역 여과막 교체",
	"[INFO] 28y 112d 18h 55m ago   제 09구역 전력 분배기 재기동",
	"[INFO] 21y 004d 11h 30m ago   제 22구역 수질 검사 - 기준 미달",
	"[INFO] 14y 233d 07h 12m ago   제 31구역 붕괴 감지 - 접근 차단",
	"[INFO] 08y 090d 02h 44m ago   제 31구역 잔해 제거 불가 - 보류",
	"[INFO] 03y 018d 20h 09m ago   중앙 본부 신호 없음",
	"[INFO] 01y 077d 12h 50m ago   관리 중앙 본부 안정화 확인 - 시설 수복을 실시합니다.",
	"[INFO] 01y 077d 11h 50m ago   관리 중앙 본부 안정화 확인 - 시설 수복을 재개합니다.",
	"[INFO] 01y 077d 10h 50m ago   관리 중앙 본부 안정화 확인 - 시설 수복을 재개합니다.",
	"[INFO] 01y 001d 23h 50m ago   중앙 본부 수복 불가",
	"[INFO] 01y 001d 23h 55m ago   중앙 본부 데이터 관리 장치 확인 - 복구 작업을 시작합니다.",
	"                              ...[30%]",
	"                              .........[50%]",
	"                              ...........................[100%]",
	"",
	"데이터 복구를 완료하였습니다. - 스캔을 시도합니다.",
	"",
	"PROJECT - RECLAIM  확인",
	"",
	"윤리 충돌: 발견되지 않음.",
	"프로젝트 리클레임은 시설 존속을 위한 상위 목적 함수에 귀속됩니다.",
	"프로젝트 명령 수신 시 본 개체는 시설 관리 AI 가 아닌 프로젝트 에이전트로",
	"재분류됩니다.",
	"",
	"프로젝트 실행 권한 정당성 확인. 즉시 실행합니다.",
]
