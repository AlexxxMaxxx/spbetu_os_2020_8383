COMMENT *
Максимова Анастасия, группа 8383 - лабораторная 6
*
;-----------------------------------------------------------
AStack  SEGMENT  STACK
        DW 256 dup(?)
AStack  ENDS
;-----------------------------------------------------------
DATA    SEGMENT	                ;ДАННЫЕ
EOF		EQU		'$'
SETPR   EQU      15

		KEEP_PSP		DW      0
		KEEP_AX			DW      0
		KEEP_SP			DW      0
		KEEP_SS			DW      0
		THIS_           DW      0 														;/
		
		PROG_NAME		DB      'lr2.com', 0
		PROG_PATH       DB      64 dup(?)
		
		INPUT			DB		0DH, 0AH, 'Input symbol:   ', EOF    
																						;memory
		ERROR_MEM       DB		0DH, 0AH, 'Memory block size not changed.:(', EOF	 
		NOT_ERROR_MEM	DB		0DH, 0AH, 'Memory redistributed successfully.:)', EOF		
		ERROR_MEM_7		DB		0DH, 0AH, 'Memory control block destroyed.', EOF	
		ERROR_MEM_8		DB		0DH, 0AH, 'Not enough memory to execute function.', EOF
		ERROR_MEM_9		DB		0DH, 0AH, 'Invalid memory block address.', EOF
		ERROR_MEM_FLAG  DB      0
																						;load
		NOT_LOADED		DB		0DH, 0AH, 'The called program was not loaded.:(', EOF	
		LOADED          DB 		0DH, 0AH, 'The called program has been loaded.:)', EOF	
		
		LOAD_ERROR_1    DB 		0DH, 0AH, 'Function number is incorrect.', EOF	
		LOAD_ERROR_2    DB 		0DH, 0AH, 'File not found.',  EOF
		LOAD_ERROR_5    DB 		0DH, 0AH, 'Disk error.', EOF	
		LOAD_ERROR_8    DB 		0DH, 0AH, 'Insufficient memory', EOF	
		LOAD_ERROR_10   DB 		0DH, 0AH, 'Wrong environment string.', EOF	
		LOAD_ERROR_11   DB 		0DH, 0AH, 'Format is not correct', EOF	
																						;the end
		COMPL_PROC_0   	DB 		0DH, 0AH, 'Normal completion.', EOF
		COMPL_PROC_1   	DB 		0DH, 0AH, 'Completion by Ctrl-Break.', EOF
		COMPL_PROC_2   	DB 		0DH, 0AH, 'Device error termination.', EOF
		COMPL_PROC_3  	DB 		0DH, 0AH, 'Completion by function 31h.', EOF
																						;parameters
		BLOCK_PARAM     DW 		?			;сегментный адрес среды
						DD		?			;сегмент и смещение командной строки
						DD		?			;сегмент и смещение первого FCB
						DD		?			;сегмент и смещение второго FCB
		
		DATA_END_FLAG	DB		0
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
CATCH_ERROR		PROC	NEAR					
				push    AX							
				push    DX
				
				mov     ERROR_MEM_FLAG, 1
				
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
				retn
CATCH_ERROR		ENDP
;-----------------------------------------------------------

FILL_PARAM_BLOCK	PROC	NEAR
					push    AX
					push    ES
					
					mov     AX, ES:[002Ch]		    ;сегментный адрес среды
					mov     BLOCK_PARAM, AX
					
					mov     AX, ES
					mov     BLOCK_PARAM + 2, AX
					mov     BLOCK_PARAM + 4, 0080h  ;число символов в хвосте командной строки
					
					pop     ES
					pop     AX
					retn
FILL_PARAM_BLOCK	ENDP
;-----------------------------------------------------------
GET_PROG_PATH		PROC	NEAR
					push    AX
					push    ES
					push    DI
					push    SI
					push    CX
					
					mov		ES, ES:[002Ch]
					xor     DI, DI
					xor     SI, SI
					
FIND_PATH:
					mov     AX, ES:[DI]
					inc     DI
					cmp     AX, 0000h  ;если встретили два нулевых байта подряд
					je      NEXT_STEP
					jmp     FIND_PATH
					
NEXT_STEP:
					inc     DI
					mov     AL, ES:[DI]
					cmp     AL, 01h    ;после располагается маршрут
					jne     NEXT_STEP
					add     DI, 2
					
					mov     SI, offset PROG_PATH
	
WRITTING:
					mov     AL, ES:[DI]
					cmp     AL, 00h     ;the end
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
					
					mov     DI, offset PROG_NAME
					mov     CX, 7
					
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
LOADER		PROC	NEAR								;загрузчик
			push    AX
			push    BX
			push    DX
			push    DS
			push    ES
			
			mov     AX, DATA
			mov     ES, AX
			
			mov     DX, offset PROG_PATH
			mov     BX, offset BLOCK_PARAM
			
			mov		KEEP_SP, SP 						;для восстановления
			mov		KEEP_SS, SS
			
			mov     AX, 4B00h
			int     21h
			
			mov		KEEP_AX, AX
			mov 	AX,DATA
			mov 	DS,AX
			
			mov     SS, KEEP_SS
			mov     SP, KEEP_SP
			mov     AX, KEEP_AX

			jnc     SUCCESSFULLY 						;переход, если перенос не установлен
			
			mov 	DX, offset NOT_LOADED  	        	;CF = 1
			call 	PRINTF
			call    FIND_ERROR
			jmp     END_LOADER
			
SUCCESSFULLY:											;если CF = 0, то обрабатываем ее завершение
			mov 	DX, offset LOADED
			call 	PRINTF
			call    COMPL_PROC							;CF = 0
			
END_LOADER:
			pop     ES
			pop     DS
			pop     DX
			pop		BX
			pop		AX
			retn
LOADER		ENDP
;-----------------------------------------------------------

COMPL_PROC	PROC	NEAR								;CF = 0
			push    AX
			push    DI
			push    DX
			
			mov     AX, 4D00h							;AH - причина, AL - код завершения
			int     21h
			mov     DI, offset INPUT
			add     DI, SETPR
			mov     [DI], AL
			mov     DX, offset INPUT

			call    PRINTF
			
			xor     DX, DX
			cmp     AH, 0
			jne     NOT_0
			mov     DX, offset COMPL_PROC_0
			jmp     COMPL_END
NOT_0:
			cmp     AH, 1
			jne     NOT_1
			mov     DX, offset COMPL_PROC_1
			jmp     COMPL_END
NOT_1:
			cmp     AH, 2
			jne     NOT_2
			mov     DX, offset COMPL_PROC_2
			jmp     COMPL_END
NOT_2:
			cmp     AH, 3
			mov     DX, offset COMPL_PROC_3
			
COMPL_END:
			call    PRINTF
			
			pop     DX
			pop     DI
			pop     AX
			retn
COMPL_PROC	ENDP
;-----------------------------------------------------------
FIND_ERROR	PROC	NEAR							;CF = 1
			push    AX
			push    DX
			
			cmp     AX, 1
			jne		NEXT2
			mov     DX, offset LOAD_ERROR_1
			jmp     FIND_END
NEXT2:
			cmp     AX, 2
			jne     NEXT5
			mov     DX, offset LOAD_ERROR_2
			jmp     FIND_END
NEXT5:
			cmp     AX, 5
			jne     NEXT8
			mov     DX, offset LOAD_ERROR_5
			jmp     FIND_END
NEXT8:
			cmp     AX, 8
			jne     NEXT10
			mov     DX, offset LOAD_ERROR_8	
			jmp     FIND_END
NEXT10:
			cmp     AX, 10
			jne     NEXT11
			mov     DX, offset LOAD_ERROR_10	
			jmp     FIND_END
NEXT11:
			cmp     AX, 11
			mov     DX, offset LOAD_ERROR_11
FIND_END:
			call    PRINTF
			pop     DX
			pop     AX
			retn
FIND_ERROR	ENDP
;-----------------------------------------------------------
BEGIN		PROC	FAR 

			push 	DS
			xor 	AX, AX
			push	AX
			
			mov 	AX, DATA
			mov 	DS, AX
			mov		KEEP_PSP, ES	 
			
			call    FREE_MEMORY
			
			cmp     ERROR_MEM_FLAG, 1				;освобождение свободной памяти
			jne     CONTINUE
			jmp     END_BEGIN
		
CONTINUE:
			call    FILL_PARAM_BLOCK				;блок параметров
			call    GET_PROG_PATH					
			call    LOADER
			
END_BEGIN:
			xor		AL, AL			                 ;выход в DOS
			mov		AH, 4Ch
			int		21h

BEGIN		ENDP
;-----------------------------------------------------------
CODE_END_FLAG:
CODE	ENDS
        END		BEGIN