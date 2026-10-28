# 人間が叩く。エージェントはフックでブロックされる。
# Velopack: exe インストーラ + 自動更新。
param([Parameter(Mandatory)][string]$Version)
dotnet publish src/MyApp/MyApp.csproj -c Release-Velopack -r win-x64 --self-contained -o publish
vpk pack --packId MyApp --packVersion $Version --packDir publish --mainExe MyApp.exe --outputDir Releases
# 署名: vpk pack に --signParams を渡すか、事前に SignTool で publish/ を署名する
# 配布: Releases/ を更新サーバー（S3 等）に置く。アプリは起動時に VelopackApp が確認する
