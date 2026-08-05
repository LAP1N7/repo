# 웹 빌드 한 번에.
#
# --export-release 만으로는 부족하다. 웹 셸(로딩 화면)은 게임이 로드되기 **전에**
# 뜨므로 .pck 안의 리소스를 못 읽는다. 셸이 쓰는 것(TIP 문구, 폰트)은 웹 루트에
# 따로 복사해 줘야 한다.
#
#   .\build_web.ps1

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$godot = "C:\Users\minseo\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"

Write-Host "[1/2] 익스포트..."
& $godot --headless --path $root --export-release "Web"
if ($LASTEXITCODE -ne 0) { throw "익스포트 실패" }

Write-Host "[2/2] 셸 리소스 복사..."
# 로딩 화면의 TIP. data/ 가 원본이고 여기로 복사만 한다 - 두 곳에서 고치면 어긋난다.
Copy-Item "$root\data\tips.json" "$root\docs\tips.json" -Force
# 로딩 화면 폰트. 게임 안과 같은 서체를 써야 그 순간 톤이 안 끊긴다.
Copy-Item "$root\assets\fonts\DNFBitBitTTF.ttf" "$root\docs\DNFBitBitTTF.ttf" -Force

$pck = [math]::Round((Get-Item "$root\docs\index.pck").Length / 1MB, 1)
$wasm = [math]::Round((Get-Item "$root\docs\index.wasm").Length / 1MB, 1)
Write-Host "완료.  pck ${pck}MB / wasm ${wasm}MB  ->  docs/"
