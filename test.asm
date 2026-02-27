.model tiny
.code
.386
org 100h

Start: 
    mov ax, 300h
    mov ds, ax
    mov es, ax
    mov ss, ax 

    mov ax, 1h
    mov bx, 0d
    mov cx, 2h
    mov dx, 3h
    mov si, 4h
    mov di, 5h
    
    startCycle:
    cmp bx, 60000d
    je endCycle
        inc bx
        jmp startCycle
    endCycle:

    mov bx, 0d

    startCycle2:
    cmp bx, 60000d
    je endCycle2
        inc bx
        jmp startCycle2
    endCycle2:

    inc cx

    mov ax, 04C00h
    int 21h
end Start