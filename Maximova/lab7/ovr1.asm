COMMENT *
Максимова Анастасия, группа 8383 - лабораторная 7
*

CODE	SEGMENT
		ASSUME CS:CODE, DS:NOTHING, SS:NOTHING, ES:NOTHING
		
;-----------------------------------------------------------
BEGIN		PROC	FAR 

			push 	DS
			push	AX
			push	DI
			push	DX
			
			mov 	AX, CS
			mov 	DS, AX	 
				
			mov		DI, offset SMS1
			add     DI, 30
			call    WRD_TO_HEX
			mov     DX, offset SMS1
			call    PRINTF 
	
END_BEGIN:
			pop		DX
			pop		DI
			pop		AX
			pop		DS
			retf
BEGIN		ENDP
;-----------------------------------------------------------
EOF		    EQU		'$'
SETPR		EQU     30
SMS1		DB		0DH, 0AH, 'Address overlay_1:                   ', EOF	
;-----------------------------------------------------------
PRINTF		PROC	NEAR  

			push    AX
			mov		AH, 09h
			int 	21h
			pop     AX
			retn
			
PRINTF		ENDP
;----------------------------------------------------------
TETR_TO_HEX		PROC	NEAR										
				and    AL, 0Fh											
				cmp    AL, 09											
				jbe    NEXT												
				add    AL, 07											
NEXT:	  		
				add	   AL, 30h											
				retn
TETR_TO_HEX    ENDP		
;-----------------------------------------------------------
BYTE_TO_HEX		PROC	NEAR										;байт в AL переводится в два символа шестн. числа в AX
				push    CX
				mov     AH, AL
				call    TETR_TO_HEX
				xchg    AL, AH
				mov     CL, 4
				shr     AL, CL
				call    TETR_TO_HEX									;в AL - старшая цифра
				pop     CX											;в AH - младшая
				retn
BYTE_TO_HEX		ENDP
;-----------------------------------------------------------
WRD_TO_HEX		PROC	NEAR										;перевод в 16 с/с 16-ти разрядного числа
																	;в АХ - число, DI - адрес последнего символа
				push	BX
				mov		BH, AH
				call	BYTE_TO_HEX
				mov		[DI], AH
				dec		DI
				mov		[DI], AL
				dec		DI
				mov		AL, BH
				call	BYTE_TO_HEX
				mov		[DI], AH
				dec		DI
				mov		[DI], AL
				pop		BX
				retn
WRD_TO_HEX		ENDP
;-----------------------------------------------------------
CODE	ENDS
        END		BEGIN