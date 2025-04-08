#Requires AutoHotkey v2.0

; Function to switch to a window by its title and launch if not running
SwitchToWindow(title, exePath := "") {
    if WinExist(title) {
        WinActivate
        WinMaximize
    } else if (exePath != "") {
        Run exePath
        WinWait title
        WinActivate
        WinMaximize
    }
}

; F1 - Switch to Godot
F1::SwitchToWindow("Godot", "C:\Program Files\Godot\Godot_v4.2.1-stable_win64.exe")

; F2 - Switch to Cursor
F2::SwitchToWindow("Cursor", "C:\Users\boxatron\AppData\Local\Programs\Cursor\Cursor.exe")

; F3 - Switch to Claude
F3::SwitchToWindow("Claude", "C:\Program Files\Google\Chrome\Application\chrome.exe --app=https://claude.ai")

; F4 - Switch to Brave Browser
F4::SwitchToWindow("Brave", "C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe") 