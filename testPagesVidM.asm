.model tiny
.code
.386
org 100h

Start: 
    
    mov ah, 05h
    mov al, 4d
    int 10h

    mov ax, 04C00h
    int 21h
end Start