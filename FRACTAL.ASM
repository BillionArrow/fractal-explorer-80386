; -------------------------------------------------------------------
; 80386 32-bit x86 assembly language
; TASM - IDEAL mode compliant
;
; PROGRAM: Fractal Explorer (Click and Drag Rectangle with Cursor)
; Converted to use IDEAL local labels (@@) and consistent formatting
; -------------------------------------------------------------------

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

; -------------------------------------------------------------------
; COMPILE-TIME CONSTANTS
; -------------------------------------------------------------------

VMEMADR     EQU 0A0000h     ; Video memory address
SCRWIDTH    EQU 320         ; Screen width
SCRHEIGHT   EQU 200         ; Screen height
VMEMSIZE    EQU (SCRWIDTH * SCRHEIGHT) ; Total pixels

; Scan codes for keys
KEY_UP      EQU 48h
KEY_DOWN    EQU 50h
KEY_ENTER   EQU 1Ch
KEY_ESC     EQU 01h

; Program State Constants
STATE_MAIN_MENU     EQU 0
STATE_FRACTAL_VIEW  EQU 1

; Fractal Type Constants
FRACTAL_MANDELBROT    EQU 0
FRACTAL_BURNINGSHIP   EQU 1
FRACTAL_SIERPINSKI    EQU 2

; Mouse Constants
MOUSE_LEFT_BUTTON   EQU 1

; Cursor Constants
CURSOR_SIZE         EQU 3      ; Size of crosshair arms

; -------------------------------------------------------------------
CODESEG
; -------------------------------------------------------------------

; Set the video mode
PROC setVideoMode
    ARG @@pMode:WORD
    USES eax
    mov    ax, [@@pMode]
    int    10h
    ret
ENDP setVideoMode

; Fill the offscreen buffer
PROC fillBuffer
    ARG @@pColor:BYTE
    USES eax, ecx, edi
    lea    edi, [offscreenBuffer]
    mov    ecx, VMEMSIZE / 4
    movzx  eax, [@@pColor]
    imul   eax, eax, 01010101h
    rep    stosd
    ret
ENDP fillBuffer

; Draw a null-terminated string using BIOS
PROC drawString
    ARG @@pString:DWORD, @@pRow:BYTE, @@pCol:BYTE, @@pColor:BYTE
    USES eax, ebx, edx, edi
    mov    ah, 02h
    mov    bh, 0
    mov    dh, [@@pRow]
    mov    dl, [@@pCol]
    int    10h
    mov    edi, [@@pString]
    mov    bl, [@@pColor]
@@print_loop:
    mov    al, [edi]
    test   al, al
    jz     @@print_done
    mov    ah, 0Eh
    int    10h
    inc    edi
    jmp    @@print_loop
@@print_done:
    ret
ENDP drawString

; Draw the main menu text on screen
PROC drawMainMenu
    ARG @@pCurrentSelection:BYTE
    USES eax, ebx
    call   fillBuffer, 0
    call   drawString, OFFSET strTitle, 4, 12, 15
    mov    al, [@@pCurrentSelection]

    ; Option 1
    mov    ebx, 15
    mov    al, [@@pCurrentSelection]
    cmp    al, 0
    jne    @@draw_opt1_select
    mov    ebx, 14
@@draw_opt1_select:
    movzx  eax, bl
    call   drawString, OFFSET strOpt1, 10, 9, eax

    ; Option 2
    mov    ebx, 15
    mov    al, [@@pCurrentSelection]
    cmp    al, 1
    jne    @@draw_opt2_select
    mov    ebx, 14
@@draw_opt2_select:
    movzx  eax, bl
    call   drawString, OFFSET strOpt2, 12, 10, eax

    ; Option 3
    mov    ebx, 15
    mov    al, [@@pCurrentSelection]
    cmp    al, 2
    jne    @@draw_opt3_select
    mov    ebx, 14
@@draw_opt3_select:
    movzx  eax, bl
    call   drawString, OFFSET strOpt3, 14, 6, eax
    
    ; Option 4 (Quit)
    mov    ebx, 15
    mov    al, [@@pCurrentSelection]
    cmp    al, 3
    jne    @@draw_opt4_select
    mov    ebx, 14
@@draw_opt4_select:
    movzx  eax, bl
    call   drawString, OFFSET strOpt4, 16, 12, eax

    call   drawString, OFFSET strPrompt1, 20, 5, 7
    call   drawString, OFFSET strPrompt2, 22, 8, 7
    ret
ENDP drawMainMenu

; ---------------------------------------------------
; MOUSE & DRAWING PROCEDURES
; ---------------------------------------------------

; Initialize mouse subsystem and set boundaries
PROC initMouse
    USES eax, ecx, edx
    
    ; Initialize mouse
    xor    eax, eax
    int    33h
    
    ; Set horizontal bounds (function 07h)
    mov    eax, 07h
    xor    ecx, ecx
    mov    edx, SCRWIDTH - 1
    int    33h
    
    ; Set vertical bounds (function 08h)
    mov    eax, 08h
    xor    ecx, ecx
    mov    edx, SCRHEIGHT - 1
    int    33h
    
    ; Hide default cursor (it doesn't work well in mode 13h anyway)
    mov    eax, 02h
    int    33h
    
    ret
ENDP initMouse

; Reads mouse pos and buttons
PROC readMouse
    USES eax

    mov   eax, 3
    int   33h

    ; Note: ecx = x, edx = y, bx (or something) contains buttons depending on ABI
    mov   [mousePosX], ecx
    mov   [mousePosY], edx
    ret
ENDP readMouse

; Copy the offscreen buffer to video memory
PROC copyBufferToVRAM
    USES eax, ecx, edx, esi, edi
    
    ; Wait for vertical retrace
    mov    dx, 03DAh
@@wait_retrace_start:
    in     al, dx
    test   al, 08h
    jz     @@wait_retrace_start

    ; Copy offscreenBuffer to video memory
    lea    esi, [offscreenBuffer]
    mov    edi, VMEMADR
    mov    ecx, VMEMSIZE / 4
    rep    movsd
    ret
ENDP copyBufferToVRAM

; Draw a crosshair cursor at mouse position directly to VRAM
PROC drawMouseCursor
    USES eax, ebx, ecx, edx, edi, esi
    LOCAL @@x:DWORD, @@y:DWORD
    
    mov   eax, [mousePosX]
    mov   [@@x], eax
    mov   eax, [mousePosY]
    mov   [@@y], eax
    
    ; Calculate base address 
    mov   eax, [@@y]
    imul  eax, SCRWIDTH
    add   eax, [@@x]
    mov   esi, VMEMADR
    add   esi, eax      ; esi = address of center pixel (x, y)
    
    ; draw center pixel
    mov   [BYTE esi], 15
    
    ; Draw horizontal line
    mov   ecx, CURSOR_SIZE
@@h_line:
    ; Left pixel (esi - ecx)
    mov   eax, [@@x]
    sub   eax, ecx
    cmp   eax, 0      ; Check if x-i < 0
    jl    @@skip_left
    
    ; we can't do [esi - ecx], so we calculate the address first.
    mov   edi, esi    ; copy center address
    sub   edi, ecx    ; subtract offset
    mov   [BYTE edi], 15 ; write to the calculated address   
@@skip_left:
    ; Right pixel (esi + ecx)
    mov   eax, [@@x]
    add   eax, ecx
    cmp   eax, SCRWIDTH ; Check if x+i >= SCRWIDTH
    jge   @@skip_right
    ; This syntax [base + index] is valid
    mov   [BYTE esi + ecx], 15 
@@skip_right:
    dec   ecx
    jnz   @@h_line
    
    ; Draw vertical line
    mov   ecx, CURSOR_SIZE
@@v_line:
    ; Calculate vertical offset
    mov   eax, ecx
    imul  eax, SCRWIDTH ; eax = vertical_offset (i * SCRWIDTH)
    
    ; Up pixel (esi - offset)
    mov   edx, [@@y]
    sub   edx, ecx
    cmp   edx, 0      ; Check if y-i < 0
    jl    @@skip_up
    mov   edi, esi
    sub   edi, eax    ; edi = esi - vertical_offset
    mov   [BYTE edi], 15
    
@@skip_up:
    ; Down pixel (esi + offset)
    mov   edx, [@@y]
    add   edx, ecx
    cmp   edx, SCRHEIGHT ; Check if y+i >= SCRHEIGHT
    jge   @@skip_down
    mov   edi, esi
    add   edi, eax    ; edi = esi + vertical_offset
    mov   [BYTE edi], 15
    
@@skip_down:
    dec   ecx
    jnz   @@v_line
    
    ret
ENDP drawMouseCursor

; Draw rectangle from two points directly to VRAM
PROC drawRectangleTwoPoints
    USES eax, ebx, ecx, edx, esi, edi
    LOCAL @@x1:DWORD, @@y1:DWORD, @@x2:DWORD, @@y2:DWORD
    LOCAL @@width:DWORD, @@height:DWORD

    ; Load coordinates
    mov    eax, [rectX1]
    mov    [@@x1], eax
    mov    eax, [rectY1]
    mov    [@@y1], eax
    mov    eax, [rectX2]
    mov    [@@x2], eax
    mov    eax, [rectY2]
    mov    [@@y2], eax

    ; Clamp all coordinates
    mov    eax, [rectX1]
    cmp    eax, 0
    jge    @@x1_min_ok
    xor    eax, eax
@@x1_min_ok:
    cmp    eax, SCRWIDTH - 1
    jle    @@x1_max_ok
    mov    eax, SCRWIDTH - 1
@@x1_max_ok:
    mov    [@@x1], eax

    mov    eax, [rectY1]
    cmp    eax, 0
    jge    @@y1_min_ok
    xor    eax, eax
@@y1_min_ok:
    cmp    eax, SCRHEIGHT - 1
    jle    @@y1_max_ok
    mov    eax, SCRHEIGHT - 1
@@y1_max_ok:
    mov    [@@y1], eax

    mov    eax, [rectX2]
    cmp    eax, 0
    jge    @@x2_min_ok
    xor    eax, eax
@@x2_min_ok:
    cmp    eax, SCRWIDTH - 1
    jle    @@x2_max_ok
    mov    eax, SCRWIDTH - 1
@@x2_max_ok:
    mov    [@@x2], eax

    mov    eax, [rectY2]
    cmp    eax, 0
    jge    @@y2_min_ok
    xor    eax, eax
@@y2_min_ok:
    cmp    eax, SCRHEIGHT - 1
    jle    @@y2_max_ok
    mov    eax, SCRHEIGHT - 1
@@y2_max_ok:
    mov    [@@y2], eax

    ; Normalize coordinates
    mov    eax, [@@x1]
    mov    ebx, [@@x2]
    cmp    eax, ebx
    jle    @@x_ok
    xchg   eax, ebx
    mov    [@@x1], eax
    mov    [@@x2], ebx
@@x_ok:

    mov    eax, [@@y1]
    mov    ebx, [@@y2]
    cmp    eax, ebx
    jle    @@y_ok
    xchg   eax, ebx
    mov    [@@y1], eax
    mov    [@@y2], ebx
@@y_ok:

    ; Calculate width and height
    mov    eax, [@@x2]
    sub    eax, [@@x1]
    inc    eax
    mov    [@@width], eax
    mov    eax, [@@y2]
    sub    eax, [@@y1]
    inc    eax
    mov    [@@height], eax

    ; Bounds check
    cmp    [DWORD @@width], 2
    jl     @@done
    cmp    [DWORD @@height], 2
    jl     @@done

    ; raw top line
    mov    eax, [@@y1]
    imul   eax, SCRWIDTH
    add    eax, [@@x1]
    mov    edi, VMEMADR
    add    edi, eax    ; edi = address of (x1, y1)
    mov    ecx, [@@width]
    mov    al, 15
    cld
    rep    stosb       ; Fills the entire line at once

    ; Draw bottom line 
    mov    eax, [@@y2]
    imul   eax, SCRWIDTH
    add    eax, [@@x1]
    mov    edi, VMEMADR
    add    edi, eax    ; edi = address of (x1, y2)
    mov    ecx, [@@width]
    mov    al, 15
    cld
    rep    stosb

    mov    ecx, [@@height]
    sub    ecx, 2
    cmp    ecx, 0
    jle    @@done
    
    ; Calculate start address for the first vertical row (y1 + 1)
    mov    eax, [@@y1]
    inc    eax
    imul   eax, SCRWIDTH
    mov    edi, VMEMADR
    add    edi, eax    ; edi = address of (0, y1 + 1)

    mov    ebx, [@@x1]   ; Store x1 in ebx
    mov    edx, [@@x2]   ; Store x2 in edx

@@vert_loop:
    ; Left pixel
    mov    [BYTE edi + ebx], 15 ; Address = (line_start + x1)
    
    ; Right pixel
    mov    [BYTE edi + edx], 15 ; Address = (line_start + x2)

    add    edi, SCRWIDTH ; Move pointer to the next line
    dec    ecx
    jnz    @@vert_loop

@@done:
    ret
ENDP drawRectangleTwoPoints

; ---------------------------------------------------
; FRACTAL DRAWING PROCEDURES
; ---------------------------------------------------

PROC drawMandelbrotToBuffer
    call   fillBuffer, 9
    ret
ENDP drawMandelbrotToBuffer

PROC drawBurningShipToBuffer
    call   fillBuffer, 9
    ret
ENDP drawBurningShipToBuffer

PROC drawSierpinskiToBuffer
    call   fillBuffer, 9
    ret
ENDP drawSierpinskiToBuffer

; ---------------------------------------------------
; PROGRAM STATE HANDLERS
; ---------------------------------------------------

PROC runFractalViewer
    USES ebx, edx
    LOCAL @@needsRedraw:BYTE, @@isDragging:BYTE

    ; Initialize
    call   initMouse
    mov    [@@needsRedraw], 1
    mov    [@@isDragging], 0

@@runFractalViewer_Loop:
    ; Redraw fractal if needed
    cmp    [@@needsRedraw], 1
    jne    @@fractal_is_clean

    mov    al, [currentFractalType]
    cmp    al, FRACTAL_MANDELBROT
    je     @@draw_m
    cmp    al, FRACTAL_BURNINGSHIP
    je     @@draw_b
    cmp    al, FRACTAL_SIERPINSKI
    je     @@draw_s
    jmp    @@fractal_done
@@draw_m:
    call   drawMandelbrotToBuffer
    jmp    @@fractal_done
@@draw_b:
    call   drawBurningShipToBuffer
    jmp    @@fractal_done
@@draw_s:
    call   drawSierpinskiToBuffer
@@fractal_done:
    mov    [@@needsRedraw], 0

@@fractal_is_clean:
    ; Copy buffer to VRAM
    call   copyBufferToVRAM

    ; Read mouse
    call   readMouse

    ; Check if currently dragging
    cmp    [@@isDragging], 1
    je     @@handle_dragging

    ; Not dragging - check if button just pressed
    test   ebx, MOUSE_LEFT_BUTTON
    jz     @@draw_cursor_only

    ; Button pressed - start dragging
    mov    eax, [mousePosX]
    mov    [rectX1], eax
    mov    [rectX2], eax
    mov    eax, [mousePosY]
    mov    [rectY1], eax
    mov    [rectY2], eax
    mov    [@@isDragging], 1
    jmp    @@draw_cursor_only

@@handle_dragging:
    ; Update second corner
    mov   [rectX2], ecx 
    mov   [rectY2], edx

    ; Draw the rectangle
    call   drawRectangleTwoPoints

    ; Check if button released
    test   ebx, MOUSE_LEFT_BUTTON
    jnz    @@draw_cursor_only

    ; Button released
    mov    [@@isDragging], 0
    mov    [@@needsRedraw], 1

@@draw_cursor_only:
    ; Always draw cursor last (on top of everything)
    call   drawMouseCursor

@@check_keyboard:
    ; Poll keyboard
    mov    ah, 01h
    int    16h
    jz     @@runFractalViewer_Loop

    ; Get key
    mov    ah, 00h
    int    16h
    cmp    ah, KEY_ESC
    je     @@returnToMenu
    jmp    @@runFractalViewer_Loop

@@returnToMenu:
    call   setVideoMode, 03h
    call   setVideoMode, 13h
    mov    [currentProgramState], STATE_MAIN_MENU
    ret
ENDP runFractalViewer

; Main menu handler
PROC runMainMenu
    USES eax
    mov    al, [currentSelection]
    movzx  eax, al
    call   drawMainMenu, eax

@@waitForInput:
    mov    ah, 00h
    int    16h

    cmp    al, '1'
    je     @@doSelectMandelbrot
    cmp    al, '2'
    je     @@doSelectBurningShip
    cmp    al, '3'
    je     @@doSelectSierpinski
    cmp    al, 'q'
    je     @@doQuit
    cmp    al, 'Q'
    je     @@doQuit
    cmp    ah, KEY_ESC
    je     @@doQuit
    cmp    ah, KEY_UP
    je     @@doArrowUp
    cmp    ah, KEY_DOWN
    je     @@doArrowDown
    cmp    ah, KEY_ENTER
    je     @@doEnterKey
    cmp    al, 0Dh
    je     @@doEnterKey
    jmp    @@waitForInput

@@doArrowUp:
    dec    [currentSelection]
    cmp    [currentSelection], 0FFh
    jne    @@menu_redraw
    mov    [currentSelection], 3
    jmp    @@menu_redraw

@@doArrowDown:
    inc    [currentSelection]
    cmp    [currentSelection], 4
    jne    @@menu_redraw
    mov    [currentSelection], 0

@@menu_redraw:
    mov    al, [currentSelection]
    movzx  eax, al
    call   drawMainMenu, eax
    jmp    @@waitForInput

@@doEnterKey:
    mov    al, [currentSelection]
    cmp    al, 0
    je     @@doSelectMandelbrot
    cmp    al, 1
    je     @@doSelectBurningShip
    cmp    al, 2
    je     @@doSelectSierpinski
    cmp    al, 3
    je     @@doQuit
    jmp    @@waitForInput

@@doSelectMandelbrot:
    mov    [currentFractalType], FRACTAL_MANDELBROT
    mov    [currentProgramState], STATE_FRACTAL_VIEW
    ret

@@doSelectBurningShip:
    mov    [currentFractalType], FRACTAL_BURNINGSHIP
    mov    [currentProgramState], STATE_FRACTAL_VIEW
    ret

@@doSelectSierpinski:
    mov    [currentFractalType], FRACTAL_SIERPINSKI
    mov    [currentProgramState], STATE_FRACTAL_VIEW
    ret

@@doQuit:
    call   terminateProcess
    ret
ENDP runMainMenu

PROC terminateProcess
    USES eax
    call   setVideoMode, 03h
    mov    ax, 04C00h
    int    21h
    ret
ENDP terminateProcess

; ---------------------------------------------------
; MAIN PROGRAM ENTRY POINT
; ---------------------------------------------------

PROC main
    sti
    cld
    push   ds
    pop    es

    call   setVideoMode, 13h

@@mainLoop:
    mov    al, [currentProgramState]
    cmp    al, STATE_MAIN_MENU
    je     @@state_menu
    cmp    al, STATE_FRACTAL_VIEW
    je     @@state_fractal
    jmp    @@doQuitMain

@@state_menu:
    call   runMainMenu
    jmp    @@mainLoop

@@state_fractal:
    call   runFractalViewer
    jmp    @@mainLoop

@@doQuitMain:
    call   terminateProcess
ENDP main

; -------------------------------------------------------------------
DATASEG
; -------------------------------------------------------------------

offscreenBuffer   db VMEMSIZE dup(0)

currentProgramState db STATE_MAIN_MENU
currentFractalType  db FRACTAL_MANDELBROT
currentSelection    db 0

; Mouse Variables
mousePosX       dd 160
mousePosY       dd 100

; Rectangle Selection Variables
rectX1          dd 0
rectY1          dd 0
rectX2          dd 0
rectY2          dd 0

strTitle    db "FRACTAL EXPLORER", 0
strOpt1     db "1. Draw Mandelbrot Set", 0
strOpt2     db "2. Draw Burning Ship", 0
strOpt3     db "3. Draw Sierpinski Triangle", 0
strOpt4     db "Q. Quit Program", 0
strPrompt1  db "Use arrow keys and press Enter", 0
strPrompt2  db "or press 1, 2, 3, or Q...", 0

STACK 100h

END main
