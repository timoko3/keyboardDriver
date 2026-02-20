.model tiny 
.code
.486
org 100h

Start: jmp nonResident

VIDEO_MEM_START_ADDR  equ 0b800h
LENGTH_VIDEO_MEM_LINE equ 80d  
SCAN_CODE_COLOR       equ 4eh

EOI                   equ 20h                   

;--------------------------------------------------------------------------
; new int 09 handler part
;--------------------------------------------------------------------------

keyboardInt PROC
    call keyboardIntPreamble

    call handleInt

    call resetControllers

    pop es bx ax
    db 0eah
OLD_INT09_HANDLER: dd 0

keyboardInt ENDP

keyboardIntPreamble PROC
    push ax bx es
    push VIDEO_MEM_START_ADDR
    pop es
    mov bx, (LENGTH_VIDEO_MEM_LINE * 5d + LENGTH_VIDEO_MEM_LINE / 2) * 2   ; set start of video mem to write to the 5th line center

    mov ah, SCAN_CODE_COLOR  ;set color for scan-code to show 

    ret
keyboardIntPreamble ENDP

handleInt PROC
    in al, 60h

    call handleScanCode

    ret
handleInt ENDP

handleScanCode PROC
    mov es:[bx], ax

    ret
handleScanCode ENDP

resetControllers PROC
    ; reset keyboard controller MSB to guarantee that keyboard controller will continue to gen scan-codes
    in al, 61h
    or al, 80h
    out 61h, al
    and al, not 80h
    out 61h, al

    ; send EOI to interrupt controller
    mov al, EOI
    out 20h, al

    ret
resetControllers ENDP



;-----------------------------------------------------------------
; Part to put residental programm in memory
;-----------------------------------------------------------------

nonResident:
    call addOldIntHandlerJmp

    call replaceInt09Handler

    call keepProgAsResident

addOldIntHandlerJmp PROC
    push 0
    pop ds
    mov si, 4 * 09h
    mov ax, cs
    mov es, ax
    mov di, offset OLD_INT09_HANDLER
    movsd

    ret
addOldIntHandlerJmp ENDP 

replaceInt09Handler PROC
    push 0
    pop es
    mov bx, 4 * 09h
    cli 
    mov word ptr es:[bx], offset keyboardInt

    mov ax, cs
    mov word ptr es:[bx + 2], ax
    sti

    ret
replaceInt09Handler ENDP

keepProgAsResident PROC
    mov ax, 3100h
    mov dx, offset nonResident
    shr dx, 4
    inc dx
    int 21h

    ret
keepProgAsResident ENDP 

end Start