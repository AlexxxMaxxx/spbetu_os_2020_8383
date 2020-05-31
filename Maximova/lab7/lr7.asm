COMMENT *
Максимова Анастасия, группа 8383 - лабораторная 7
*
;-----------------------------------------------------------
AStack  SEGMENT  STACK
        DW 256 dup(?)
AStack  ENDS
;-----------------------------------------------------------
DATA    SEGMENT	                ;ДАННЫЕ
EOF		EQU		'$'
;-------------------------------------
		KEEP_PSP		DW      0
		THIS_           DW      0
		
		OVERLAY_OFFSET  DW      0		
		ADDRESS_OVERSEG DW      0
		ADDRESS_OVERLAY DD      0
		BUFFER_DTA      DB      43 dup(?) ;область памяти, которую заполнит функция, если файл будет найден
;-------------------------------------поиск пути			
		ERROR_MEM2		DB		0DH, 0AH, 'Memory allocation error.', EOF
		ERROR_MEM_FLAG2 DB      0		
;-------------------------------------
		OVERLAY_PATH    DB      64 dup(?)
		OVERLAY1		DB		'OVR1.OVL', 0
		OVERLAY2		DB		'OVR2.OVL', 0
;-------------------------------------выделение памяти
		ERROR_MEM       DB		0DH, 0AH, 'Memory block size not changed.:(', EOF	 
		NOT_ERROR_MEM	DB		0DH, 0AH, 'Memory redistributed successfully.:)', EOF		
		
		ERROR_MEM_7		DB		0DH, 0AH, 'Memory control block destroyed.', EOF	
		ERROR_MEM_8		DB		0DH, 0AH, 'Not enough memory to execute function.', EOF
		ERROR_MEM_9		DB		0DH, 0AH, 'Invalid memory block address.', EOF
		
		ERROR_MEM_FLAG  DB      0
;-------------------------------------
		GET_SIZE_NOT_ERROR	DB 		0DH, 0AH, 'Overlay size successfully determined.;)', EOF 
		GET_SIZE_ERROR  	DB 		0DH, 0AH, 'Error determining overlay size.;(', EOF
		ERROR_2     		DB 		0DH, 0AH, 'File not found.', EOF
		ERROR_3  	   		DB 		0DH, 0AH, 'No route found.', EOF
;-------------------------------------определение размера памяти
		LOAD_ERROR_FLAG     DB      0
		LOADER_ERROR		DB 		0DH, 0AH, 'Memory overlay loading failed.:c', EOF
		LOADER_NOT_ERROR	DB		0DH, 0AH, 'Successfully loading an overlay into memory.:D', EOF

		LOAD_ERROR1			DB 		0DH, 0AH, 'Nonexistent function.', EOF
		LOAD_ERROR2			DB 		0DH, 0AH, 'File not found.', EOF
		LOAD_ERROR3			DB 		0DH, 0AH, 'No route found.', EOF
		LOAD_ERROR4			DB 		0DH, 0AH, 'Too many open files.', EOF
		LOAD_ERROR5			DB 		0DH, 0AH, 'No access.', EOF
		LOAD_ERROR8			DB 		0DH, 0AH, 'Little memory.', EOF
		LOAD_ERROR10		DB 		0DH, 0AH, 'Wrong environment.', EOF
;-------------------------------------
		DATA_END_FLAG	DB		0
;-------------------------------------		
DATA    ENDS
;-----------------------------------------------------------
CODE	SEGMENT
		ASSUME CS:CODE, DS:DATA, SS:AStack, ES:NOTHING
;-----------------------------------------------------------
PRINTF		PROC	NEAR  

			push    AX
			mov		AH, 09h
			int 	21h
			pop     AX
			retn
			
PRINTF		ENDP
;-----------------------------------------------------------
FREE_MEMORY		PROC	NEAR 						;уменьшить отведенный блок памяти
				push    AX
				push    BX
				push	CX
				push    DX

				mov		BX, offset CODE_END_FLAG	;определить размер памяти необходимый программе 
				mov		AX, offset DATA_END_FLAG	;положить в BX число параграфов
				add     BX, AX
				mov     CL, 4						;деление на 16
				shr		BX, CL
				add     BX, 100h					;дополнительная память
			
				xor     AL, AL
				mov		AH, 4Ah						;4Ah - изменить размер блока памяти
				int     21h							;BX - новый размер в 16байтных параграфах
				
				;если освобождение памяти не может быть выполнено
				;устанавливается флаг переноса CF = 1 и АХ заносится код ошибки (7,8,9)
				
				jnc		NOT_ERROR					;переход, если перенос не установлен
				mov     DX, offset ERROR_MEM
				call    PRINTF
				call    CATCH_ERROR	
				
NOT_ERROR:
				mov     DX, offset NOT_ERROR_MEM
				call    PRINTF
				
				pop     DX
				pop		CX
				pop		BX
				pop		AX
				retn
FREE_MEMORY		ENDP
;-----------------------------------------------------------
CATCH_ERROR		PROC	NEAR					;отлавливание ошибок при работе с памятью
				push    AX							
				push    DX
				
				mov     ERROR_MEM_FLAG, 1		;если ошибки с памятью, то продолжение работы программы не имеет смысла (begin)
				
				cmp     AX, 7
				jne     NEXT_ERROR
				mov     DX, offset ERROR_MEM_7
				jmp     END_CATCH
				
NEXT_ERROR:				
				cmp     AX, 8
				jne     NEXT_ERROR2
				mov     DX, offset ERROR_MEM_8
				jmp     END_CATCH
				
NEXT_ERROR2:				
				cmp     AX, 9
				mov     DX, offset ERROR_MEM_9
				
END_CATCH:
				call PRINTF
				
				pop     DX
				pop     AX
				
CATCH_ERROR		ENDP
;-----------------------------------------------------------
GET_PROG_PATH		PROC	NEAR
					           								;2)путь к файлу
					push    AX
					push    ES
					push    DI
					push    SI
					push    CX

					mov		OVERLAY_OFFSET, AX
					mov		AX, KEEP_PSP
					mov     ES, AX
					
					mov		ES, ES:[002Ch]
					xor     DI, DI
					xor     SI, SI
					
FIND_PATH:
					mov     AX, ES:[DI]
					inc     DI
					cmp     AX, 0000h                        ;если встретили два нулевых байта подряд
					je      NEXT_STEP
					jmp     FIND_PATH
					
NEXT_STEP:
					inc     DI
					mov     AL, ES:[DI]
					cmp     AL, 01h                           ;после располагается маршрут
					jne     NEXT_STEP
					add     DI, 2
					
					mov     SI, offset OVERLAY_PATH
	
WRITTING:
					mov     AL, ES:[DI]
					cmp     AL, 00h                           ;the end
					je      FIND_NAME
					                                          ;последний слэш запоминаем
					cmp     AL, '\'  	   
					jne     CONTINUE_
					mov     THIS_, SI  
					
CONTINUE_:					
					mov     [SI], AL 
					inc     DI
					inc     SI
					jmp     WRITTING
					
FIND_NAME:								
					mov     SI, THIS_     
					inc     SI
					
					mov     DI, OVERLAY_OFFSET
					mov     CX, 8
					
					xor     AL, AL
REPEAT_:
					mov     AL, [DI]
					mov     [SI], AL
					inc     DI
					inc     SI
					loop    REPEAT_						
END_FIND:			
					pop     CX
					pop     SI
					pop     DI
					pop     ES
					pop     AX
					retn
GET_PROG_PATH		ENDP
;-----------------------------------------------------------
GET_SIZE_OVERLAY	PROC	NEAR                    ;(3)определение размера оверлея
					push    AX
					push    DX
					push    CX
					
					                                ;1 - установить адрес DTA
					xor     AL, AL
					mov     AH, 1Ah
					mov     DX, offset BUFFER_DTA
					int     21h

					                                ;2 - определить размер оверлея используя 4Еh
					xor     AL, AL
					mov		AH, 4Eh
					mov     DX, offset OVERLAY_PATH	;DS:DX - адрес строки ASCIIZ с именем файла
					mov     CX, 0					;СХ - атрибут файла для сравнения (для файла 0)
					int     21h
					
					jnc     SIZE_NOT_ERROR          ;переход, если перенос не установлен
					
					mov 	DX, offset GET_SIZE_ERROR  	        	;CF = 1
					call 	PRINTF
			
					call    FIND_ERROR
					jmp     END_GET_SIZE
SIZE_NOT_ERROR:
					mov 	DX, offset GET_SIZE_NOT_ERROR
					call 	PRINTF
					call    GET_SIZE_FILE							;CF = 0	
END_GET_SIZE:
					pop     CX
					pop     DX
					pop     AX
					retn
GET_SIZE_OVERLAY    ENDP
;-----------------------------------------------------------
GET_SIZE_FILE		PROC	NEAR ;CF = -0
					push    DI
					push	AX
					push	BX
					push	CX
					push	DX
					
					mov		DI, offset BUFFER_DTA
					
					mov     BX, [DI + 1Ah] 				;размер файла
					mov     AX, [DI + 1Ch]              ;размер памяти в байтах
														;перевести в параграфы
					xor     CH, CH
					mov		CL, 4
					shr     BX, CL
					mov		CL, 12
					shl     AX, CL
					
					add     BX, AX
					add     BX, 2
					
					xor     AL, AL
					mov     AH, 48h						;распределить память
					int     21h
					
					jnc     SEGMENT_SET                 ;переход, если перенос не установлен
					
					mov     DX, offset ERROR_MEM2		;CF = 1
					call	PRINTF
					
					mov     ERROR_MEM_FLAG2, 1
					jmp     BYE
					
SEGMENT_SET:
					mov		ADDRESS_OVERSEG, AX	
BYE:			
					pop		DX
					pop     CX
					pop		BX
					pop		AX
					pop     DI
					retn
GET_SIZE_FILE		ENDP
;-----------------------------------------------------------
FIND_ERROR			PROC	NEAR
					push    AX
					push    DX
					
					cmp		AX, 2
					jne     NEXT
					mov     DX, offset ERROR_2
					jmp		ENDF
NEXT:
					cmp     AX, 3
					mov     DX, offset ERROR_3
ENDF:	
					call    PRINTF
					pop		DX
					pop		AX
					retn
FIND_ERROR			ENDP
;-----------------------------------------------------------
LOADER		PROC	NEAR
			push	AX
			push	ES
			push	BX
			push	DX

			mov 	AX, DATA
			mov 	ES, AX	
			
			mov		DX, offset OVERLAY_PATH  	;DS:DX - указывает на строку, содержащую путь к оверлею
			mov		BX, offset ADDRESS_OVERSEG	;ES:BX - сегментный адрес загрузки программы
			
			mov		AX, 4B03h
			int     21h
			
			jnc		DONE
			
			mov		DX, offset LOADER_ERROR
			call	PRINTF
			
			mov     LOAD_ERROR_FLAG, 1
			
			call    CATCH_LOAD_ERROR
			jmp		ENDDD
DONE:											  ;CF = 0
			mov		DX, offset LOADER_NOT_ERROR
			call	PRINTF
			
			mov		AX, ADDRESS_OVERSEG
			mov     ES, AX
			
			mov		WORD PTR ADDRESS_OVERLAY + 2, AX
			call 	ADDRESS_OVERLAY
			
			mov		ES, AX
			xor		AL, AL
			mov     AH, 49h
			int     21h
			
ENDDD:		
			pop		DX
			pop		BX
			pop		ES
			pop		AX
			retn
LOADER		ENDP
;-----------------------------------------------------------
CATCH_LOAD_ERROR	PROC	NEAR
					push	AX
					push	DX
					
					cmp     AX, 1
					jne     NOT_1
					mov		DX, offset LOAD_ERROR1
					jmp		END_CATCH_ER
NOT_1:
					cmp     AX, 2
					jne     NOT_2
					mov		DX, offset LOAD_ERROR2
					jmp		END_CATCH_ER
NOT_2:			
					cmp     AX, 3
					jne     NOT_3
					mov		DX, offset LOAD_ERROR3
					jmp		END_CATCH_ER
NOT_3:			
					cmp     AX, 4
					jne     NOT_4
					mov		DX, offset LOAD_ERROR4
					jmp		END_CATCH_ER
NOT_4:
					cmp     AX, 5
					jne     NOT_5
					mov		DX, offset LOAD_ERROR5
					jmp		END_CATCH_ER
NOT_5:
					cmp     AX, 8
					jne     NOT_8
					mov		DX, offset LOAD_ERROR8
					jmp		END_CATCH_ER
NOT_8:				
					cmp     AX, 10
					mov		DX, offset LOAD_ERROR10			
END_CATCH_ER:
					call	PRINTF
					pop		DX
					pop		AX
					retn
CATCH_LOAD_ERROR	ENDP
;-----------------------------------------------------------
CALL_OVERLAY		PROC	NEAR
					
					call    GET_PROG_PATH                     ;2) получили путь
					call    GET_SIZE_OVERLAY				  ;3)определение размера оверлея 
					cmp     ERROR_MEM_FLAG2, 1
					jne     CONT
					jmp     EEND
CONT:
					call    LOADER
EEND:
					retn
CALL_OVERLAY		ENDP
;------------------------------------------------------------
BEGIN		PROC	FAR 

			push 	DS
			xor 	AX, AX
			push	AX
			
			mov 	AX, DATA
			mov 	DS, AX	 
			
			mov		KEEP_PSP, ES	 
;-------------------------------------		
			call    FREE_MEMORY						;1)перед загрузкой оверлей программа должна освободить память
			
			cmp     ERROR_MEM_FLAG, 1				;если не получилось - заканчиваем программу
			jne     CONTINUE
			jmp     END_BEGIN
;-------------------------------------		
CONTINUE:
			mov     AX, offset OVERLAY1				;программа 1
			call    CALL_OVERLAY
			
;-------------------------------------	
			cmp     LOAD_ERROR_FLAG, 1				;ошибка при загрузке первого
			je      END_BEGIN
;-------------------------------------			
CONTINUE2:			
			mov     AX, offset OVERLAY2				;программа 2
			call    CALL_OVERLAY

;-------------------------------------		
END_BEGIN:
			xor		AL, AL			                 ;выход в DOS
			mov		AH, 4Ch
			int		21h

BEGIN		ENDP
;-----------------------------------------------------------
CODE_END_FLAG:
CODE	ENDS
        END		BEGIN