# GAMBIT GRID 실행 / 검증 스크립트
#
#   .\run.ps1            데모 실행 (데스크탑)
#   .\run.ps1 test       전투 코어 + 덱/편성 헤드리스 검증 (118개 검사)
#   .\run.ps1 explore    편성 탐색 / 밸런싱 표
#   .\run.ps1 mc         몬테카를로 밸런스 시뮬레이션 (약 2분)
#   .\run.ps1 export     웹 빌드 익스포트 -> ..\build\web
#   .\run.ps1 serve      웹 빌드를 로컬 서버로 띄우고 브라우저 열기 (Ctrl+C 로 종료)
#   .\run.ps1 web        export + serve 를 한 번에
#   .\run.ps1 import     class_name 재등록 (파일 추가 후 필요)
#
# 개발용 환경변수:
#   GG_SCREEN=loadout|loadout_full|battle   해당 화면부터 시작 (예산 자동 소진)
#   GG_STAGE=2                              스테이지 지정
#   GG_AUTOSTART=1 / GG_SPEED=2             (전투 화면) 자동 재생 · 배속

param([string]$Mode = "play")

$root = $PSScriptRoot
$dir = "C:\Users\minseo\Downloads\Godot_v4.7.1-stable_win64.exe"
$gui = Join-Path $dir "Godot_v4.7.1-stable_win64.exe"
$cli = Join-Path $dir "Godot_v4.7.1-stable_win64_console.exe"
# ── 웹 빌드는 반드시 repo 안의 docs/ 로 나간다 ────────────────────────────
# GitHub Pages 가 docs/ 를 서빙한다. 예전에는 여기가 ..uild\web 이라
# **repo 밖**으로 나갔고, 그래서 export 를 아무리 돌려도 배포본은 그대로였다.
# 로컬에서 잘 도는데 공개된 페이지만 옛날 버전인, 알아채기 가장 어려운 종류의
# 사고였다. 익스포트 프리셋의 출력 경로와 같은 곳이어야 한다.
$web = Join-Path $root "docs"

if (-not (Test-Path $cli)) { throw "Godot 을 찾을 수 없다: $cli" }

function Invoke-Export {
    # build_web.ps1 하나만 쓴다. 익스포트만으로는 부족하기 때문이다 - 로딩
    # 셸은 게임이 뜨기 전에 그려지므로 .pck 를 못 읽고, TIP 문구와 폰트를
    # 웹 루트에 따로 복사해 줘야 한다. 여기서 --export-release 를 직접 부르면
    # 그 복사가 빠져 로딩 화면만 조용히 깨진다.
    & (Join-Path $root "build_web.ps1")
}

function Invoke-Serve {
    if (-not (Test-Path (Join-Path $web "index.html"))) {
        throw "웹 빌드가 없다. 먼저 .\run.ps1 export 를 돌려라."
    }
    Write-Host "http://127.0.0.1:8080/index.html  (Ctrl+C 로 종료)" -ForegroundColor Cyan
    Write-Host "첫 로딩은 wasm 39MB 라 10~20초 걸린다. 빌드를 새로 뽑았으면 Ctrl+Shift+R." -ForegroundColor DarkGray
    Start-Process "http://127.0.0.1:8080/index.html"
    # 헤더를 아무것도 안 붙이는 평문 서버 = GitHub Pages 와 같은 조건.
    # thread_support=false 로 뽑았으므로 COOP/COEP 없이도 떠야 정상이다. (DESIGN R1)
    python -m http.server 8080 --directory $web --bind 127.0.0.1
}

switch ($Mode) {
    "test"    {
        & $cli --headless --path $root --script res://test/headless_test.gd
        & $cli --headless --path $root --script res://test/run_test.gd
    }
    "explore" { & $cli --headless --path $root --script res://test/explore.gd }
    "mc"      { & $cli --headless --path $root --script res://test/montecarlo.gd }
    "import"  { & $cli --headless --path $root --import }
    "export"  { Invoke-Export }
    "serve"   { Invoke-Serve }
    "web"     { Invoke-Export; Invoke-Serve }
    default   { & $gui --path $root }
}
