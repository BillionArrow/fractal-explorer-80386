; -------------------------------------------------------------------
; 80386 32-bit x86 assembly language
; TASM
;
; PROGRAM: Fractal Explorer (State Machine Framework)
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
STATE_MAIN_MENU   EQU 0
STATE_FRACTAL_VIEW  EQU 1

; Fractal Type Constants
FRACTAL_MANDELBROT   EQU 0
FRACTAL_BURNINGSHIP  EQU 1
FRACTAL_SIERPINSKI   EQU 2

; -------------------------------------------------------------------
CODESEG
; -------------------------------------------------------------------

; Set the video mode (e.g., 13h or 03h)
PROC setVideoMode, pMode:WORD
    USES eax
    mov    ax, [pMode]
    int    10h
    ret
ENDP setVideoMode

; Fill the background (for mode 13h)
PROC fillBackground, pColor:BYTE
    USES eax, ecx, edi
    mov    edi, VMEMADR
    mov    ecx, VMEMSIZE / 4
    movzx  eax, [pColor]
    imul   eax, eax, 01010101h
    rep    stosd
    ret
ENDP fillBackground

; Draw a null-terminated string using BIOS
PROC drawString, pString:PTR BYTE, pRow:BYTE, pCol:BYTE, pColor:BYTE
    USES eax, ebx, edx, edi

    mov ah, 02h
    mov bh, 0
    mov dh, [pRow]
    mov dl, [pCol]
    int 10h

    mov edi, [pString]
    mov bl, [pColor]
print_loop:
    mov al, [edi]
    test al, al
    jz   print_done
    mov ah, 0Eh
    int 10h
    inc edi
    jmp print_loop
print_done:
    ret
ENDP drawString

; Draw the main menu text on screen
PROC drawMainMenu, pCurrentSelection:BYTE
    USES eax, ebx

    call    fillBackground, 0
    call    drawString, OFFSET strTitle,  4, 12, 15 ; Title

    ; Option 1
    mov    ebx, 15 ; Normal (White)
    mov    al, [pCurrentSelection]
    cmp    al, 0
    jne    draw_opt1
    mov    ebx, 14 ; Highlight (Yellow)
draw_opt1:
    movzx  eax, bl
    call    drawString, OFFSET strOpt1,   10, 9, eax

    ; Option 2
    mov    ebx, 15
    mov    al, [pCurrentSelection]
    cmp    al, 1
    jne    draw_opt2
    mov    ebx, 14
draw_opt2:
    movzx  eax, bl
    call    drawString, OFFSET strOpt2,   12, 9, eax

    ; Option 3
    mov    ebx, 15
    mov    al, [pCurrentSelection]
    cmp    al, 2
    jne    draw_opt3
    mov    ebx, 14
draw_opt3:
    movzx  eax, bl
    call    drawString, OFFSET strOpt3,   14, 9, eax
    
    ; Option 4 (Quit)
    mov    ebx, 15
    mov    al, [pCurrentSelection]
    cmp    al, 3
    jne    draw_opt4
    mov    ebx, 14
draw_opt4:
    movzx  eax, bl
    call    drawString, OFFSET strOpt4,   16, 9, eax

    call    drawString, OFFSET strPrompt1, 20, 6, 7  ; Gray
    call    drawString, OFFSET strPrompt2, 22, 10, 7 ; Gray
    ret
ENDP drawMainMenu

; ---------------------------------------------------
; FRACTAL DRAWING PLACEHOLDERS
; ---------------------------------------------------
PROC drawMandelbrot
    call    fillBackground, 32 ; Fill screen blue
    ; implementation will be done later on 
    ret
ENDP drawMandelbrot

PROC drawBurningShip
    call    fillBackground, 64 ; Fill screen pink
    ; implementation will be done later on 
    ret
ENDP drawBurningShip

PROC drawSierpinski
    call    fillBackground, 48 ; Fill screen cyan
    ; implementation will be done later on 
    ret
ENDP drawSierpinski

; ---------------------------------------------------
; PROGRAM STATE HANDLERS
; ---------------------------------------------------

; This is the new "foundation" for drawing fractals
PROC runFractalViewer
    ; 1. Draw the currently selected fractal
    mov    al, [currentFractalType]
    cmp    al, FRACTAL_MANDELBROT
    je     draw_m
    cmp    al, FRACTAL_BURNINGSHIP
    je     draw_b
    cmp    al, FRACTAL_SIERPINSKI
    je     draw_s
    jmp    wait_key ; Failsafe
draw_m:
    call    drawMandelbrot
    jmp     wait_key
draw_b:
    call    drawBurningShip
    jmp     wait_key
draw_s:
    call    drawSierpinski
    
wait_key:
    ; 2. Wait for user input
    mov    ah, 00h
    int    16h

    ; 3. Handle input
    cmp    ah, KEY_ESC ; On ESC, return to main menu
    je     returnToMenu
    
    ; ---
    ; --- This is where you will add zoom/pan logic
    ; --- e.g., cmp ah, KEY_UP -> call panUp
    ; ---
    
    jmp    wait_key ; Keep waiting for ESC

returnToMenu:
    mov    [currentProgramState], STATE_MAIN_MENU
    ret
ENDP runFractalViewer


; main menu logic
PROC runMainMenu
    ; 1. Draw the menu
    mov    al, [currentSelection]
    movzx  eax, al 
    call    drawMainMenu, eax

    ; 2. Wait for and process user input
waitForInput:
    mov    ah, 00h
    int    16h

    ; --- Check for ASCII keys (hotkeys) ---
    cmp    al, '1'
    je      doSelectMandelbrot
    cmp    al, '2'
    je      doSelectBurningShip
    cmp    al, '3'
    je      doSelectSierpinski
    cmp    al, 'q'
    je      doQuit
    cmp    al, 'Q'
    je      doQuit

    ; --- Check for Extended keys (scan codes) ---
    cmp    ah, KEY_ESC
    je      doQuit
    cmp    ah, KEY_UP
    je      doArrowUp
    cmp    ah, KEY_DOWN
    je      doArrowDown
    cmp    ah, KEY_ENTER
    je      doEnterKey
    cmp    al, 0Dh
    je      doEnterKey

    jmp    waitForInput  ; Invalid key, wait again

; --- Key Handlers for Main Menu ---
doArrowUp:
    dec    [currentSelection]
    cmp    [currentSelection], 0FFh ; Wrapped from 0 to -1?
    jne    menu_redraw
    mov    [currentSelection], 3    ; Wrap to last item
    jmp    menu_redraw
doArrowDown:
    inc    [currentSelection]
    cmp    [currentSelection], 4    ; Wrapped from 3 to 4?
    jne    menu_redraw
    mov    [currentSelection], 0    ; Wrap to first item
menu_redraw:
    ; Redraw the menu and wait for new input
    mov    al, [currentSelection]
    movzx  eax, al 
    call    drawMainMenu, eax
    jmp    waitForInput

doEnterKey:
    mov    al, [currentSelection]
    cmp    al, 0
    je     SHORT doSelectMandelbrot
    cmp    al, 1
    je     SHORT doSelectBurningShip
    cmp    al, 2
    je     SHORT doSelectSierpinski
    cmp    al, 3
    je     SHORT doQuit
    jmp    waitForInput

; --- Action Handlers for Main Menu ---
doSelectMandelbrot:
    mov    [currentFractalType], FRACTAL_MANDELBROT
    mov    [currentProgramState], STATE_FRACTAL_VIEW
    ret ; Return to the main state machine loop

doSelectBurningShip:
    mov    [currentFractalType], FRACTAL_BURNINGSHIP
    mov    [currentProgramState], STATE_FRACTAL_VIEW
    ret ; Return to the main state machine loop

doSelectSierpinski:
    mov    [currentFractalType], FRACTAL_SIERPINSKI
    mov    [currentProgramState], STATE_FRACTAL_VIEW
    ret ; Return to the main state machine loop

doQuit:
    call    terminateProcess
    ret ; This will be caught by terminateProcess
ENDP runMainMenu


; Terminate the program and restore text mode
PROC terminateProcess
    USES eax
    call   setVideoMode, 03h ; Back to 80x25 text mode
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
    
    push ds
    pop  es

    call    setVideoMode, 13h ; Set 320x200 256-color mode
    
mainLoop:
    mov    al, [currentProgramState]
    cmp    al, STATE_MAIN_MENU
    je     state_menu
    cmp    al, STATE_FRACTAL_VIEW
    je     state_fractal
    
    jmp    doQuitMain ; Failsafe, should never happen

state_menu:
    call    runMainMenu
    jmp     mainLoop

state_fractal:
    call    runFractalViewer
    jmp     mainLoop

doQuitMain:
    call    terminateProcess
ENDP main

; -------------------------------------------------------------------
DATASEG
; -------------------------------------------------------------------
    ; --- State Variables ---
    ; 0 = Main Menu, 1 = Fractal Viewer
    currentProgramState db STATE_MAIN_MENU
    
    ; 0 = Mandelbrot, 1 = Burning Ship, 2 = Sierpinski
    currentFractalType  db FRACTAL_MANDELBROT
    
    ; 0-3 = current highlighted menu option
    currentSelection    db 0

    ; --- Strings for the main menu ---
    strTitle    db "FRACTAL EXPLORER", 0
    strOpt1     db "1. Draw Mandelbrot Set", 0
    strOpt2     db "2. Draw Burning Ship", 0
    strOpt3     db "3. Draw Sierpinski Triangle", 0
    strOpt4     db "Q. Quit Program", 0
    strPrompt1  db "Use arrow keys and press Enter", 0
    strPrompt2  db "or press 1, 2, 3, or Q...", 0

; -------------------------------------------------------------------
STACK 100h
; -------------------------------------------------------------------

END main

