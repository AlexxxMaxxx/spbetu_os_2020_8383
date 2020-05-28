COMMENT @
Максимова Анастасия, группа 8383, 2 лабораторная
@

CODE		SEGMENT
			ASSUME CS:CODE, DS:CODE, ES:NOTHING, SS:NOTHING
			ORG 100H
			
START:	JMP		MAIN

EOF				EQU		'$'
SETPRECISION	EQU		50

;ДАННЫЕ
ADDRESS_MEMORY		      	DB		0DH, 0AH, 0AH, 'Segment address of the inaccessible memory:          ', EOF
ADDRESS_ENVIRONMENT			DB		0DH, 0AH, 0AH, 'Segment address of the environment:                  ', EOF	
TAIL_STRING					DB		0DH, 0AH, 0AH, 'Command line tail:                    ', EOF	
WHERE_MY_TAIL				DB		'empty tail', EOF	
CONTENT_AREA  				DB		0DH, 0AH, 'Content of the environment area:         ', EOF	
ENDL						DB		0DH, 0AH, EOF	
WAY							DB		0DH, 0AH, 'Path:                                   ', EOF	

;ПРОЦЕДУРЫ

TETR_TO_HEX		PROC	NEAR										
		   and    AL, 0Fh											
		   cmp    AL, 09											
		   jbe    NEXT												
		   add    AL, 07											
NEXT:	   add	  AL, 30h											
		   ret
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
				ret
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
				ret
WRD_TO_HEX		ENDP
;-----------------------------------------------------------
PRINTF		PROC	NEAR
		push    AX
		mov		AH, 09h
	    int 	21h
		pop     AX
		retn
PRINTF		ENDP
;-----------------------------------------------------------
GET_ADDRESS_PR		PROC 	NEAR
				push 	AX
				push	DI
				push 	DX
				
				;Первое - сегментный адрес недоступной памяти, взятый из PSP
				mov 	AX, DS:[0002h]
				mov     DI, offset ADDRESS_MEMORY
				add		DI, SETPRECISION
				call	WRD_TO_HEX
				
				mov		DX, offset ADDRESS_MEMORY
				call	PRINTF
				
				sub     AX, AX
				sub     DI, DI
				sub     DX, DX
				
				;Второе - сегментный адрес среды, передаваемый программ
				mov 	AX, DS:[002Ch]
				mov     DI, offset ADDRESS_ENVIRONMENT
				add		DI, SETPRECISION
				call	WRD_TO_HEX
				
				mov		DX, offset ADDRESS_ENVIRONMENT
				call	PRINTF
				
				pop		DX
				pop 	DI
				pop		AX
				
				retn

GET_ADDRESS_PR		ENDP
;-----------------------------------------------------------
GET_TAIL_PR		PROC	NEAR ;если хвост не пустой - выводим его
			push    DI
			push    AX
			push    DX
			
			sub		DI, DI
			sub		AX, AX
			
REPEAT:
			mov		AL, DS:[0081h + DI]
			
			push    AX
			sub     DX, DX
						
			mov     DL, AL
			mov     AH, 02h
			int     21h
			
			pop     AX
			
			inc     DI
			loop    REPEAT
			
			pop     DX
			pop     AX
			pop     DI
			retn
GET_TAIL_PR		ENDP
;-----------------------------------------------------------
;Третье - кол-во символов в хвосте, если 0, то печатаем предупреждение
GET_NUMBER_CHAR	PROC	NEAR
			push	CX
			push    DX
			
			mov		DX, offset TAIL_STRING
			call	PRINTF
			
			sub 	CX, CX
			mov     CL, DS:[0080h] ;количество символов в хвосте
			
			cmp     CL, 00h
			je		EMPTY
			call	GET_TAIL_PR
			jmp     EXIT
			

EMPTY:		mov		DX, offset WHERE_MY_TAIL
			call	PRINTF
			
EXIT:			
			pop     DX
			pop		CX
			
			retn
GET_NUMBER_CHAR	ENDP 
;-----------------------------------------------------------
;четвертое - пятое - содержимое области среды и путь
GET_CONTENT_AREA	PROC	NEAR
			push 	AX
			push 	DX
			push 	DI
			
			mov		DX, offset CONTENT_AREA
			call	PRINTF
			
			sub 	DI, DI
			sub     AX, AX
			
			mov ES, DS:[002Ch]
		
CICLE_READ:
			mov		AL, ES:[DI]
			cmp     AL, 00h			;первый нуль
			je		NEW_STRING  	;печатаем новую строку
			
			push    AX
			sub     DX, DX			
			mov     DL, AL
			mov     AH, 02h			;печатаем символ
			int     21h
			pop     AX
			
			inc     DI
			jmp     CICLE_READ
			
NEW_STRING:
			mov		DX, offset ENDL
			call	PRINTF
			inc     DI
			
			mov		AL, ES:[DI]
			cmp     AL, 00h 		;второй нуль
			jne     CICLE_READ
			
			mov		DX, offset ENDL
			call	PRINTF

FIND_PATH:	inc DI
			mov		AL, ES:[DI]
			cmp     AL, 01h 
			jne     FIND_PATH 
			add     DI, 2
			
			mov		DX, offset WAY
			call	PRINTF
			
COUT_PATH:	cmp     AL, 00h 
			je      BYE
			
			mov		AL, ES:[DI]
			push    AX
			sub     DX, DX			
			mov     DL, AL
			mov     AH, 02h		;печатаем символ
			int     21h
			pop     AX
			
			inc     DI
			jmp     COUT_PATH		
			
BYE:
			pop 	DI
			pop 	DX
			pop 	AX
			
			retn
GET_CONTENT_AREA	ENDP
;-----------------------------------------------------------

MAIN:		
		call	GET_ADDRESS_PR		; 1 и 2 задания
		call	GET_NUMBER_CHAR		; 3 задание
		call	GET_CONTENT_AREA	; 4 и 5 задание

;выход в DOS
		sub		AL, AL
		
		mov 	AH, 01h				;модификация программы 
		int     21h					;01h - ввол символа с клавиатуры
		
		mov		AH, 4Ch
		int		21h
		
CODE	ENDS					
		END 	START			;конец модуля, START - точка входа
