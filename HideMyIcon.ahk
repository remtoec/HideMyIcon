; Script     HideMyIcon.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/HideMyIcon
; Date       19.02.2025
; Version    0.5.2

#Requires AutoHotkey v2
#SingleInstance Force
#Warn

fn := HideMyIcon.Bind(1, 17, 0)
SetTimer(fn, 20)

/**
 * Controls the transparency of an icon based on user interaction.
 * @param {bool} change_on_hover A flag for the trigger mode: 0 = click, 1 = hover.
 * @param {int}  step_size       Defines the rate at which the transparency changes.
 * Accepts any value between 0 and 255, where specific values correspond to predefined frame counts: 
 * *     1   -> 256 frames 
 * *     3   -> 86 frames 
 * *     5   -> 52 frames 
 * *     15  -> 18 frames 
 * *     17  -> 16 frames 
 * *     51  -> 6 frames 
 * *     85  -> 4 frames 
 * *     255 -> 2 frames
 * @param {int}  delay           Sleep time between each transparency change.
 * 
 * Usage Examples with SetTimer:
 * *   SetTimer(HideMyIcon.Bind(1, 15, 20), 20)   ; Hover-triggered effect with a moderate step size and a 20 ms delay.
 * *   SetTimer(HideMyIcon.Bind(1, 51,  0), 20)   ; Hover-triggered effect with a faster transition.
 * *   SetTimer(HideMyIcon.Bind(0, 85,  0), 20)   ; Click-triggered effect with a rapid transition.
 * *   SetTimer(HideMyIcon.Bind(0, 255, 0), 1000) ; Click-triggered effect with the quickest transition but with a 1000 ms timer delay.
 */
HideMyIcon(change_on_hover := 0, step_size := 17, delay := 16.67) { ; step_size and delay are now ignored

    ; static TRANSPARENT_MIN := 1, TRANSPARENT_MAX := 255 ; Removed for ListView method
    ; static transparent ; Removed for ListView method
    static hdesk, hicon
    static init := False, init_complete_successfully := False
    static icons_visible_lview := True

    static LVM_GETITEMCOUNT := 0x1004
    static LVM_SETITEMSTATE := 0x102B
    static LVIF_STATE := 0x0008  ; Flag for LVITEM.mask
    static LVIS_HIDDEN := 0x0008 ; State flag for hiding

    if (!init) {
        ; step_size check removed as it's no longer used for transparency
        ; if (step_size < 1 || step_size > 255)
        ;     throw("Step size must be between 1 and 255.")

        ; Try to get the handle of the desktop (Progman or WorkerW)
        if (hdesk := WinExist("ahk_class Progman"))
            hicon := ControlGetHwnd("SysListView321", hdesk)
        else if (hdesk := WinExist("ahk_class WorkerW"))
            hicon := ControlGetHwnd("SysListView321", hdesk)
        
        ; Check if handles were obtained successfully
        if (hdesk && hicon) {
            init_complete_successfully := True
            icons_visible_lview := True ; Initialize assuming icons are visible
            ; Register the restore function on exit only if initialization was successful
            OnExit(Func((exitReason, exitCode) => {
                ; This lambda captures static variables from HideMyIcon:
                ; hicon, icons_visible_lview, init_complete_successfully,
                ; LVM_GETITEMCOUNT, LVM_SETITEMSTATE, LVIF_STATE, LVIS_HIDDEN.
                If (!icons_visible_lview && hicon && init_complete_successfully) {
                    item_count := SendMessage(hicon, LVM_GETITEMCOUNT, 0, 0)
                    if (item_count > 0) { ; Check if there are items before proceeding
                        LVITEM_Buffer := Buffer(20)
                        NumPut("UInt", LVIF_STATE, LVITEM_Buffer, 0)      ; mask
                        NumPut("Int", 0, LVITEM_Buffer, 4)                ; iItem (ignored for applying to all)
                        NumPut("Int", 0, LVITEM_Buffer, 8)                ; iSubItem (ignored)
                        NumPut("UInt", 0, LVITEM_Buffer, 12)              ; state = 0 (not hidden)
                        NumPut("UInt", LVIS_HIDDEN, LVITEM_Buffer, 16)    ; stateMask = LVIS_HIDDEN
                        Loop item_count {
                            SendMessage(hicon, LVM_SETITEMSTATE, A_Index - 1, LVITEM_Buffer)
                        }
                    }
                    ; icons_visible_lview is a static of HideMyIcon.
                    ; It cannot be directly modified here to reflect the change, but the script is exiting.
                }
            }))
            ; transparent := TRANSPARENT_MAX ; Removed
        } else {
            init_complete_successfully := False
        }
        init := True
    }

    ; If initialization was not successful, exit the function
    if (!init_complete_successfully) {
        Return
    }

    ; Initialize variables
    id := ctrl := cls := wnd := ""
    mouse_pos := ""
    
    ; Get the title and class of the window under the mouse,
    ; MouseGetPos raises an error if the mouse is over the Start Menu
    try {
        MouseGetPos(,, &id, &ctrl)
        cls := WinGetClass(id)
        wnd := WinGetTitle(id)
    }

    ; Click mode requires further detection
    active_desk := !change_on_hover ? WinActive(hdesk) : 1
    active_tray := !change_on_hover ? WinActive("ahk_class Shell_TrayWnd") : 1
    
    ; Determine the mouse position
    try
    mouse_pos := ((ctrl ~= "TrayShowDesktopButton" && active_desk) ? "TrayShowDesktopButton"
               : (cls ~= "Progman|WorkerW" && wnd == "") ? "StartMenu"
               : (cls ~= "Progman|WorkerW" && active_desk) ? "Desktop"
               : (cls ~= "Shell_TrayWnd" && active_tray) ? "Taskbar"
               : (cls ~= "DFTaskbar") ? "DisplayFusion" : "")

    ; Determine the direction of the change
    if (mouse_pos ~= "TrayShowDesktopButton|StartMenu|Taskbar")
        change := 1 ; Indicates icons should be shown (or remain shown)
    else if (!change_on_hover)
        change := (WinActive(hdesk) || WinActive("ahk_class Shell_TrayWnd")) ? 1 : -1
    else
        change := (mouse_pos) ? 1 : -1 ; If mouse_pos is empty (not on Desktop/Taskbar), change is -1 (hide)

    ; New Show/Hide Logic using ListView messages
    if (change == 1 && !icons_visible_lview) { ; Show icons
        item_count := SendMessage(hicon, LVM_GETITEMCOUNT, 0, 0)
        if (item_count > 0) {
            LVITEM_Buffer := Buffer(20)
            NumPut("UInt", LVIF_STATE, LVITEM_Buffer, 0)      ; mask
            NumPut("Int", 0, LVITEM_Buffer, 4)                ; iItem (ignored)
            NumPut("Int", 0, LVITEM_Buffer, 8)                ; iSubItem (ignored)
            NumPut("UInt", 0, LVITEM_Buffer, 12)              ; state = 0 (not hidden)
            NumPut("UInt", LVIS_HIDDEN, LVITEM_Buffer, 16)    ; stateMask = LVIS_HIDDEN
            Loop item_count {
                SendMessage(hicon, LVM_SETITEMSTATE, A_Index - 1, LVITEM_Buffer)
            }
        }
        icons_visible_lview := True
    } else if (change == -1 && icons_visible_lview) { ; Hide icons
        item_count := SendMessage(hicon, LVM_GETITEMCOUNT, 0, 0)
        if (item_count > 0) {
            LVITEM_Buffer := Buffer(20)
            NumPut("UInt", LVIF_STATE, LVITEM_Buffer, 0)      ; mask
            NumPut("Int", 0, LVITEM_Buffer, 4)                ; iItem (ignored)
            NumPut("Int", 0, LVITEM_Buffer, 8)                ; iSubItem (ignored)
            NumPut("UInt", LVIS_HIDDEN, LVITEM_Buffer, 12)    ; state = LVIS_HIDDEN
            NumPut("UInt", LVIS_HIDDEN, LVITEM_Buffer, 16)    ; stateMask = LVIS_HIDDEN
            Loop item_count {
                SendMessage(hicon, LVM_SETITEMSTATE, A_Index - 1, LVITEM_Buffer)
            }
        }
        icons_visible_lview := False
    }
    
    ; Old transparency logic removed
    ; before := transparent
    ; transparent := transparent + change * step_size
    ; if (1 > transparent)
    ;     transparent := TRANSPARENT_MIN
    ; else if (transparent > TRANSPARENT_MAX)
    ;     transparent := TRANSPARENT_MAX
    ; if (transparent != before)
    ;     WinSetTransparent(transparent, hicon)
    ; if (delay)
    ;     Sleep(delay)

    Return
}
