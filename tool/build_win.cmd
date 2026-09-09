@echo off
set PATH=C:\Program Files\Git\cmd;C:\Windows\System32;C:\Windows\System32\WindowsPowerShell\v1.0
cd /d C:\Users\Administrator\Documents\Squall\squall
call "C:\Program Files\Microsoft Visual Studio\18\Insiders\VC\Auxiliary\Build\vcvars64.bat"
"C:\development\flutter\bin\cache\dart-sdk\bin\dart.exe" "C:\development\flutter\bin\cache\flutter_tools.snapshot" build windows --release --dart-define-from-file=config\supabase.local.json