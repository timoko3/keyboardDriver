.model tiny
.code
.386
org 100h

Start: 
    mov ax, 0d

    startCycle:
    cmp ax, 0d
    je endCycle
        jmp startCycle
    endCycle:
end Start