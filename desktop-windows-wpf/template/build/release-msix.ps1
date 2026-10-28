# 人間が叩く。エージェントはフックでブロックされる。
# MSIX: Store 提出 or サイドロード。
param([Parameter(Mandatory)][string]$Version)
dotnet publish src/MyApp/MyApp.csproj -c Release-Store -r win-x64 --self-contained -o publish
# Package.appxmanifest の Version を $Version に合わせてから
MakeAppx pack /d publish /p Releases/MyApp-$Version.msix /nv
# サイドロード時のみ: SignTool sign /fd SHA256 /a /f cert.pfx /p <pass> Releases/MyApp-$Version.msix
# Store 提出: Partner Center にアップロード（署名は Store が行う）
