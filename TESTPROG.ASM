.model tiny 
.code
.486
org 100h

Start: jmp nonResident

keyboardInt PROC
    push ax bx es
    push 0b800h
    pop es
    mov bx, (80d * 5d + 40d) * 2
    mov ah, 4eh

    in al, 60h
    mov es:[bx], ax

    in al, 61h
    or al, 80h
    out 61h, al
    and al, not 80h
    out 61h, al

    mov al, 20h
    out 20h, al

    pop es bx ax
    db 0eah
OLD_INT09_HANDLER: dd 0

keyboardInt ENDP

nonResident:
    push 0
    pop ds
    mov si, 4 * 09h
    mov ax, cs
    mov es, ax
    mov di, offset OLD_INT09_HANDLER
    movsd

    push 0
    pop es
    mov bx, 4 * 09h
    cli 
    mov word ptr es:[bx], offset keyboardInt

    mov ax, cs
    mov word ptr es:[bx + 2], ax
    sti

    ; pushf
    ; push cs
    ; call keyboardInt

    mov ax, 3100h
    mov dx, offset nonResident
    shr dx, 4
    inc dx
    int 21h

end Start