.model tiny 
.code
.386
org 100h

VIDEO_MEM_START_ADDR      equ 0b800h
LENGTH_VIDEO_MEM_LINE     equ 80d  
SCAN_CODE_COLOR           equ 4eh

EOI                       equ 20h                   

SHOW_REG_BUTTON_SCAN_CODE equ 29h

DIFFERENCE_NUM_ASCII_L9   equ 48d
DIFFERENCE_NUM_ASCII_G9   equ 55d

AMOUNT_NIBBLES_REGISTER   equ 4d
AMOUNT_REGS_DUMP          equ 13d

DELAY_ANIM_ITER_CYCLE     equ 1d

_FRAME_SYMBOLS_START_ADDR equ offset frameSymbolsStr
_FRAME_TEXT_ADDR          equ offset frameText

_NUMB_STR_START_DRAW_TEXT equ 3d 

_KEYBOARD_INT_NUMBER      equ 09h
_TIMER_INT_NUMBER         equ 08h



                    
Start: jmp nonResident

IS_KEY_PRESSED_FLAGS db 0d, 0d, '$'


; --------------------------------------------------------------------------
; new int 08 handler part
; --------------------------------------------------------------------------

timerInt PROC
	push sp bp ss es ds di si dx cx bx ax
	
	mov bp, sp 

	call drawAllRegs
	call frameDrawingPart

	; send EOI to interrupt controller
    mov al, EOI
    out 20h, al

	pop ax bx cx dx si di ds es ss bp sp

	db 0eah
	OLD_INT08_HANDLER: dd 0
timerInt ENDP



; --------------------------------------------------------------------------
; new int 09 handler part
; --------------------------------------------------------------------------


;-----------------------------------------------------------------------
; new Function performed on int 09h draw regs values on '`' button press
; Entry: no
; Exit:  no
; Exp:   no
; Destr: no
;-----------------------------------------------------------------------

keyboardInt PROC
    push sp bp ss es ds di si dx cx bx ax
    
    mov bp, sp 

    call handleScanCode

    call resetControllers


    pop ax bx cx dx si di ds es ss bp sp
    db 0eah
OLD_INT09_HANDLER: dd 0

keyboardInt ENDP

;-----------------------------------------------------------------------
; read info from keyboard port 60h and 
; if pressed needed button calls handler
; Entry: no
; Exit:  no
; Exp:   no
; Destr: al
;-----------------------------------------------------------------------

handleScanCode PROC
    in al, 60h

    cmp al, SHOW_REG_BUTTON_SCAN_CODE
    jne ??notNeededSC

        call drawAllRegs
    
        call frameDrawingPart

    ??notNeededSC:

    ret
handleScanCode ENDP



; --------------------------------------------------------------------------
; draw regs part
; --------------------------------------------------------------------------

drawAllRegs PROC
    mov bx, _FRAME_TEXT_ADDR 

    mov cx, 1d 

    ; call putInMemFrameParams 

    ??StartCycle:
    cmp cx, AMOUNT_REGS_DUMP + 1d 
    jge ??endCycle 
        mov si, cx
		sub si, 1d
        shl si, 1          ; si = (cx - 1) * 2
        mov di, [bp + si] 

        ; amendment for sp reg case
        cmp cx, AMOUNT_REGS_DUMP
        jne ??notSp 
            sub di, 6d  ; take into consid pushf, push cs, push ip
        ??notSp:

        call nameReg

        call drawReg

        test cx, 01h
        jz ??sameLine
            mov byte ptr cs:[bx], ' '
            jmp ??postambleCycle            

        ??sameLine:
            mov byte ptr cs:[bx], '#'

        ??postambleCycle:
        add bx, 1
        inc cx
        jmp ??StartCycle
    ??endCycle:

    dec bx 
    mov byte ptr cs:[bx], '$'

    ret
drawAllRegs ENDP


;-----------------------------------------------------------------------
; puts names of regs in mem for drawing 
; Entry: cx = register number(in push order)
;        bx = current offset in mem for text
; Exit:  no
; Exp:   no
; Destr: bx, ax, ds, si
;-----------------------------------------------------------------------
nameReg PROC
	mov ax, cs
	mov ds, ax

	mov si, cx
	sub si, 1d
	shl si, 1d
	add si, offset REGS_NAMES

	lodsw

	mov word ptr cs:[bx], ax

    ??endNameReg:
    add bx, 2

    mov word ptr cs:[bx], ' :'
    add bx, 2

    ret  
nameReg ENDP 

REGS_NAMES db 'AXBXCXDXSIDIDSESSSBPSPIPCS$'

; CDECL
;-----------------------------------------------------------------------
; new Function performed on int 09h draw regs values on '`' button press
; Entry: di = reg value to draw 
; Exit:  no
; Exp:   no
; Destr: no
;-----------------------------------------------------------------------

drawReg PROC
    push ax cx dx si di

    ; init cycle

    mov cx, 1d

    xor dx,dx 
    mov dx, 0f000h   ; mask for reg nibble 

    
    ??startDrawingCycle:
    cmp cx, 5d
    jge ??endDrawingCycle
        mov ax, di
        and ax, dx

        mov si, 4d
        sub si, cx
        shl si, 2

        push cx 
        mov cx, si
        shr ax, cl
        pop cx

        call convertNibbleToASCII

        mov byte ptr cs:[bx], al

        add bx, 1
        shr dx, 4
        inc cx
    jmp ??startDrawingCycle
    ??endDrawingCycle:

    pop di si dx cx ax
    ret 
drawReg ENDP

;-----------------------------------------------------------------------
; converts number in nibble to ASCII
; Entry: ax = nibble
;         
; Exit:  ax = ASCII code
; Exp:   no
; Destr: ax
;-----------------------------------------------------------------------

convertNibbleToASCII PROC
    ; case <= 9

    cmp ax, 9d
    jg ??G9
        add ax, DIFFERENCE_NUM_ASCII_L9
        jmp ??end

    ??G9:

    ; case > 9
    
    add ax, DIFFERENCE_NUM_ASCII_G9

    ??end:
    ret 
convertNibbleToASCII ENDP

;-----------------------------------------------------------------------
; reset controllers to original state 
; Entry: no
; Exit:  no
; Exp:   no
; Destr: al
;-----------------------------------------------------------------------

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





;-------------------------------------------------
; frame drawing part
; ------------------------------------------------

COLOR 		  		EQU 0dh
TEXT_COLOR	  		EQU 5Eh

NO_MODE_SYMB  		EQU 04h
MODE_ONE_SYMB 		EQU 03h
MODE_TWO_SYMB 		EQU 05h

NEW_LINE_SYMB 		EQU '#'
END_STR_INPUT_SYMB	EQU '$'

frameDrawingPart PROC

    mov ax, 0B800h  ; initializing video memory segment register
	mov es, ax

	xor bx, bx
	mov bx, 160d * 5d + 80d; init video segment shift  
		
	mov dh, 24h ; $ ASCII endStrSym 

	; read mode from cmd and put in dl symbol for frame

	call animationMode

    ret 
frameDrawingPart ENDP

;-----------------------------------------------------------------------
; makes frame animation
; Entry: dh = ensStr symbol
; Exit:  nop
; Exp:   nop
; Destr: ax, bx, cx, dx, di, si
;-----------------------------------------------------------------------

animationMode PROC
	call initAnimation

	call calcStartStep

	; mov cx, di
	mov dh, al ;correction to remove animation in interrupt
	StartAnimationCycle:
	cmp dh, al
	jg endAnimationCycle
		push ax

		mov si, _FRAME_SYMBOLS_START_ADDR

		xor bx, bx
	    mov bx, 160 * 2 + 80; init video segment shift  

		call animationDrawFrame

		add dh, 2

		pop ax
	jmp StartAnimationCycle
	endAnimationCycle:

	ret
animationMode ENDP

initAnimation PROC
    mov si, _FRAME_TEXT_ADDR
    call countLineMaxLen
    mov di, ax
    call getAnimationIterationsCount
    mov dl, al
    ret
initAnimation ENDP

calcStartStep PROC
	xor dh, dh
	
	test cx, 1			
	jz ??not_odd
		add dh, 3d
		jmp ??is_odd
	??not_odd:
	add dh, 2d
	??is_odd:
	ret
calcStartStep ENDP

animationDrawFrame PROC
	; put align num in ax
	xor ax, ax
	mov al, dh
	add al, al
	call alignFrame

	call animationDrawFrameLines

	push cx
	mov cx, DELAY_ANIM_ITER_CYCLE
	call delayForAnimation
	pop cx

	ret
animationDrawFrame ENDP

animationDrawFrameLines PROC
	

	; init cycle
	mov ax, 4d + 1d
	add ax, di 
	mov ah,1
	lineLoop:
		cmp ah, al
		jge done
		
		
		push bx
        mov bl, _NUMB_STR_START_DRAW_TEXT
		cmp ah, bl
		pop bx

		jne notTextStr2
			cmp dh, dl
			jl notTextStr2

			call animationSpecialTextCase
			
		notTextStr2:

		call animationDrawSingleLine

		inc ah
		jmp lineLoop
	done:
		ret
animationDrawFrameLines ENDP

animationSpecialTextCase PROC
	mov si , _FRAME_TEXT_ADDR
	??textPrintCycle:
	cmp di , 0d
	jle ??printedStr
		push ax 
		push dx
		push di
		mov di, si

		call startFrameLine

		call animationDrawText

		call endFrameLine

		mov si, di
		pop di

		pop dx
		call moveBaseToNextLineStartPos
		push dx
		

		dec di

		pop dx
		pop ax 
		inc ah
	jmp ??textPrintCycle
	
	??printedStr:

	ret
animationSpecialTextCase ENDP

animationDrawSingleLine PROC
	push ax
	push dx

	call startFrameLine

	mov dl, cs:[si]
	add si, 1d

	xor ax, ax
	mov al, dh
	sub al, 2d
	
	push di
	call printFrame
	pop di

	call endFrameLine

	pop dx

	call moveBaseToNextLineStartPos

	pop ax 
	ret
animationDrawSingleLine ENDP

moveBaseToNextLineStartPos PROC
			
	xor ax, ax
	mov al, dh
	shl ax, 1        ; ax = dh * 2
	sub bx, ax

	add bx, 160	; move to next line	

	ret
moveBaseToNextLineStartPos ENDP

startFrameLine PROC
	call findSymForStr

	mov dl, cs:[si]
	add si, 1d
	call outSymbol

	ret
startFrameLine ENDP

endFrameLine PROC
	mov dl, cs:[si]
	call outSymbol

	ret
endFrameLine ENDP

;-----------------------------------------------------------------------
; Animation string with text handle
; Entry: si = symbol to print addr
;		 cx = len text space in line
; 		 di = addr text in memory
; Exit:  nop
; Exp:   zf = 0 means length str is even
;		 zf = 1 means length str is odd
; Destr: dl, si, bx, ah, di, cx
;-----------------------------------------------------------------------

animationDrawText PROC
	mov dl, cs:[si]
	call outSymbol
	call outSymbol
	add si, 1d

	mov dh, '$'

	push cx

	push si
	mov  si, di

	call printText
	add si, 1d  ;skip # symbol
	mov di, si

	pop si

	??beginFillFreeSpace:
	cmp cx, 0d
	jle ??endedFillFreeSpace
		call outSymbol
		dec cx
	jmp ??beginFillFreeSpace
	??endedFillFreeSpace:

	call outSymbol
	call outSymbol
	
	pop cx

	ret
animationDrawText ENDP

;-----------------------------------------------------------------------
; finds amount of animation iterations
; Entry: cx = final frame size
; Exit:  al = amount of animation iterations
; Exp:   nop
; Destr: al
;-----------------------------------------------------------------------

getAnimationIterationsCount PROC
	xor ax, ax
	mov al, cl

	add al, 6d

	ret
getAnimationIterationsCount ENDP

;-----------------------------------------------------------------------
; makes preamble for string with text in complicatedMode
; Entry: si = pointer to next symbol to print
; Exit:  nop
; Exp:   nop
; Destr: dl, bx
;-----------------------------------------------------------------------

printCompModeStrPreamble PROC
	call outSymbol

	inc si
	mov dl, cs:[si]
	call outSymbol
	call outSymbol

	ret
printCompModeStrPreamble ENDP

;-----------------------------------------------------------------------
; makes postamble for string with text in complicatedMode
; Entry: si = pointer to next symbol to print
; Exit:  nop
; Exp:   nop
; Destr: dl, bx
;-----------------------------------------------------------------------

printCompModeStrPostamble PROC
	call outSymbol
	call outSymbol

	inc si
	mov dl, cs:[si]
	call outSymbol

	ret
printCompModeStrPostamble ENDP

;-----------------------------------------------------------------------
; pareses current needed symbols of frame from cmd line
; Entry: ah = current str to print
;		 al = last str 
; Exit:  si = pointer to the needed symbol in cmd line
; Exp:   nop
; Destr: si
;-----------------------------------------------------------------------

_FRAME_SYMBOLS_START_ADDR_LOCAL equ offset frameSymbolsStr

findSymForStr PROC
	cmp ah, 1d
	jne notFirst
		mov si, _FRAME_SYMBOLS_START_ADDR_LOCAL
		ret

	notFirst:
	sub al, 1d
	cmp ah, al
	
	jne notLast
		mov si, _FRAME_SYMBOLS_START_ADDR_LOCAL + 6d
		jmp ??endFind
	notLast:

	mov si, _FRAME_SYMBOLS_START_ADDR_LOCAL + 3d

	??endFind:
	add al, 1d
	ret
findSymForStr ENDP

;-----------------------------------------------------------------------
; puts string of symbol to videoMem
; Entry: dl = symbol to print with
;		 dh = color code
;		 ax = amount symbols to print
; Exit:  nop 
; Exp:   nop 
; Destr: di, bx 
;-----------------------------------------------------------------------

printFrame PROC

	mov di, 0
	frameCycleStart:
	cmp di, ax
	jge endFrameCycle

	mov byte ptr es:[bx], dl
	mov byte ptr es:[bx + 1], COLOR

	inc di
	add bx, 2

	jmp frameCycleStart

	endFrameCycle:

	ret
printFrame ENDP

;-----------------------------------------------------------------------
; puts string to videoMem
; Entry: Entry: si = pointer to the begin of str
; Exit:  cx = amountNotFilledSpace 
; Exp:   dh = ensStr symbol ASCII code
;		 
; Destr: ah, si, bx, cx
;-----------------------------------------------------------------------

printText PROC

	; text to videomem 
	cycleStart:																																													
	mov ah, cs:[si]

	cmp ah, dh 
	je endStr
		cmp ah, NEW_LINE_SYMB
		je endStr				
			mov byte ptr es:[bx], ah
			mov byte ptr es:[bx+1], TEXT_COLOR

			inc si
			add bx, 2

			dec cx
	jmp cycleStart

	endStr:

	ret
printText ENDP

;-----------------------------------------------------------------------
; counts max line len
; Entry: si = pointer to the begin of str
; Exit:  cx = max length line
;		 al = amount lines 		
; Exp:   dh = ensStr symbol ASCII code
; Destr: ax, cx, di, si
;-----------------------------------------------------------------------

countLineMaxLen PROC
	push bx 
	push dx
	xor bx, bx

	mov dh, NEW_LINE_SYMB
	??cycleStart:

	call strlen
	mov si, di

	cmp bx, cx
	jg ??notGreaterLine
		mov bx, cx
	??notGreaterLine:

	inc al 

	mov dl, cs:[si]
	cmp dl, END_STR_INPUT_SYMB
	je ??cycleEnd

	inc si
	jmp ??cycleStart
	
	??cycleEnd:

	xor ah, ah
	mov cx, bx

	pop dx
	pop bx
	ret
countLineMaxLen ENDP

;-----------------------------------------------------------------------
; counts amount of symbols in str with endStr symbol '$'
; Entry: si = pointer to the begin of str
; Exit:  cx = length str
; Exp:   dh = ensStr symbol ASCII code
; Destr: ah, cx, di
;-----------------------------------------------------------------------

strlen PROC
	mov di, si
	xor cx, cx
	
	strlenCycle:
	mov ah, cs:[di]

	cmp ah, dh
	je strlenEnd
	cmp ah, END_STR_INPUT_SYMB
	je strlenEnd
	inc di

	inc cx    ; increment symbols counter
	jmp strlenCycle
	strlenEnd:
	ret
strlen ENDP

;-----------------------------------------------------------------------
; puts symbol in video memory and moves to next cell for symbol
; Entry: dl 	 = symbol of frame
;		 es:[bx] = addr where to put symbol 
; Exit:  nop 
; Exp:   es:[bx] = point to appropriate memCell
; Destr: bx
;-----------------------------------------------------------------------

outSymbol PROC
	mov byte ptr es:[bx], dl
	mov byte ptr es:[bx + 1], COLOR
	add bx, 2

	ret
outSymbol ENDP

;-----------------------------------------------------------------------
; returns bx to the start position
; Entry: di = amount of extra symbols except from text symbols
; Exit:  nop
; Exp:   nop
; Destr: ax, bx
;-----------------------------------------------------------------------

videoMemPointerMoveBack PROC
	mov ax, cx 
	add ax, di
	add ax, ax

	sub bx, ax

	ret
videoMemPointerMoveBack ENDP

;-----------------------------------------------------------------------
; Alining frame for it to be in the center of screen
; Entry: ax = width of frame in symbols
; Exit:  bx = points at the left side of frame
; Exp:   bx = points in the center of some string
; Destr: ax, bx
;-----------------------------------------------------------------------

alignFrame PROC
	cmp ax, 2d
	jne notTwoCase
		sub bx, ax
		ret
	notTwoCase:
	shr ax, 2
	shl ax, 1
	sub bx, ax
	ret
alignFrame ENDP

;-----------------------------------------------------------------------
; Making delay for correct displaying of the animation
; Entry: cx = amount of tacts to skip
; Exit:  nop
; Exp:   nop
; Destr: cx
;-----------------------------------------------------------------------

delayForAnimation PROC
	delay:
		nop
		loop delay
	ret
delayForAnimation ENDP

frameSymbolsStr db 0C9h,0CDh,0BBh,0BAh,' ',0BAh,0C8h,0CDh,0BCh,'$' 
frameText       db 150 dup(0)



;-----------------------------------------------------------------
; Part to put residental programm in memory
;-----------------------------------------------------------------

nonResident:
	cli

	;new int 09h handler setup
	mov di, offset OLD_INT09_HANDLER
	mov ax, _KEYBOARD_INT_NUMBER
    call addOldIntHandlerJmp

	mov di, offset keyboardInt
	mov ax, _KEYBOARD_INT_NUMBER
    call replaceIntHandler         

	;new int 08h handler setup
	mov di, offset OLD_INT08_HANDLER
	mov ax, _TIMER_INT_NUMBER
    call addOldIntHandlerJmp

	mov di, offset timerInt
	mov ax, _TIMER_INT_NUMBER
    call replaceIntHandler 

    call keepProgAsResident

	sti

;-----------------------------------------------------------------------
; Adding jump to old handler in new handler
; Entry: ax = interrupt number
; 		 di = old interrupt jump addr
; Exit:  nop
; Exp:   nop
; Destr: ds, es, ax, si
;-----------------------------------------------------------------------

addOldIntHandlerJmp PROC
    push 0d
    pop ds
    mov si, ax
	shl si, 2d
    mov ax, cs
    mov es, ax
    
    movsd

    ret
addOldIntHandlerJmp ENDP 

;-----------------------------------------------------------------------
; replaces old int handler with new one
; Entry: ax = interrupt number
; 		 di = new int handler proc addr
; Exit:  nop
; Exp:   nop
; Destr: es, bx, ax
;-----------------------------------------------------------------------

replaceIntHandler PROC
    push 0d
    pop es
    mov bx, ax
	shl bx, 2d
    mov word ptr es:[bx], di

    mov ax, cs
    mov word ptr es:[bx + 2d], ax

    ret
replaceIntHandler ENDP

keepProgAsResident PROC
    mov ax, 3100h
    mov dx, offset nonResident
    shr dx, 4
    inc dx
    int 21h

    ret
keepProgAsResident ENDP 

end Start