COMMENT *
Максимова Анастасия, группа 8383 - лабораторная 4
*

CODE	SEGMENT
		ASSUME CS:CODE, DS:DATA, SS:AStack, ES:NOTHING
		
;-----------------------------------------------------------
INT_HANDLER		PROC	FAR		                      ;обработчик прерываний

				JMP		HANDLER_START
				
				EOF		            EQU   '$'
			    SETPR   			EQU   16
					
				SIGNATURE			DW	  4321h   	  ;для проверки
				
				KEEP_AX				DW    0
				KEEP_SS				DW	  0
				KEEP_SP				DW	  0
				KEEP_IP				DW	  0
				KEEP_CS				DW	  0
				KEEP_PSP			DW    0
				
				COUNTER_			DB	  'Counter: 00000000', 0DH, 0AH, EOF
				
				;Чтобы иметь возможность работать со стеком уменьшенного размера, 
				;каждому обработчику прерывания выделяется свой стек, отдельный для каждого процессора.
				INT_HANDLER_Stack	DW    128 dup(?) ;стек прерывания
                ;-------------------------------
		
HANDLER_START:	
				mov		KEEP_SS, SS					;"переключаемся на стек прерывания" 
				mov		KEEP_SP, SP
				mov		KEEP_AX, AX
				
				mov		AX, SEG INT_HANDLER_Stack
				mov		SS, AX
				
				mov		AX, OFFSET INT_HANDLER_Stack
				add		AX, 256                      ;128*2			
				mov		SP, AX	                     ;SP устанавливается на конец стека
				;-------------------------------
													 ;сохранение изменяемых регистров
				push	BX
				push	CX
				push	DX
				push	DI
				push	DS
				push	ES
				push	BP
		
				;-------------------------------
													;действия по обработке прерывания
				call	GET_CURS
		        push    DX                          ;курсор для восстановления
				
		        mov     DX, 1828h                   ;строка - столбец 
		        call    SET_CURS

				push	DS
				mov		AX, SEG COUNTER_
				mov		DS, AX
		
				mov		DI, OFFSET COUNTER_			;строка для счетчика
				add		DI, SETPR					;в конец строки
				
				mov		CX, 8
CALCULATED:											;обработка счетчика
				
				mov		AH, [DI]
				inc		AH
				mov		[DI], AH
				
				cmp		AH, ':'                     ;ASCII символ : идет после 9ки
				je		NEXT_RANK
				jmp		EXIT
NEXT_RANK:
				mov		AH, '0'
				mov		[DI], AH
				dec		DI
				loop    CALCULATED					;CX != 0
				
EXIT:				
				pop		DS
				mov		AX, SEG COUNTER_
				
				push	ES
				mov		ES, AX

				push	BP
				mov		BP, OFFSET COUNTER_
		
				call	OUTPUT_BP
				
				pop		BP
				pop		ES
				
				pop		DX
				call	SET_CURS
		
				;-------------------------------                  
				pop		BP			                ;восстановление регистров
				pop		ES
				pop		DS
				pop		DI
				pop		DX
				pop		CX
				pop		BX
				;-------------------------------
				
				mov		AX, KEEP_SS					;"переключаемся на внешний стек" 
				mov		SS, AX
				
				mov		SP, KEEP_SP
				mov		AX, KEEP_AX
				;-------------------------------
				mov     AL, 20h						;выход
				out		20h, AL
				iret	                            ;popf + retf - возврат из прерывания
				;ret
				;-------------------------------
INT_HANDLER		ENDP
LAST_BYTE:	
;----------------------------------------------------------- 
OUTPUT_BP		PROC	NEAR						; функция вывода строки по адресу ES:BP на экран
				        							; CX = длина строки (подсчитываются только символы)
													
				mov		AX, 1301h					; AL = код подфункции 1 = использовать атрибут в BL; курсор - в конец строки					
				mov		BX, 0003h					; BH = номер страницы BL - цвет
				mov     CX, 17                      ; число символов для записи
				int     10h

				retn
OUTPUT_BP		ENDP
;-----------------------------------------------------------
SET_CURS		PROC	NEAR						;установка позиции курсора
                        							;на строку 25 - невидимый 
				mov		AH, 02h
				mov		BH, 0h						;видео страница
				int     10h

				retn
SET_CURS		ENDP
;-----------------------------------------------------------
GET_CURS		PROC	NEAR						;читать позицию и размер курсора
                                                    ;на строку 25 - невидимый 
				mov		AH, 03h
				mov		BH, 0h						;видео страница
				int     10h
													;ВЫХОД - DH,Dl - текущие строка и колонка
													;CH, CL - текущие начальная, конечная строки курсора
				retn
GET_CURS		ENDP
;-----------------------------------------------------------
CHECK		PROC	NEAR		                    ;1)проверяет, установлено ли 
								                    ;пользовательское прервание с вектором 1Сh	
			push	AX
			push	BX
			push	DI
			push	ES
											       ;чтение адреса, записанного в векторе прерывания
			mov     AX, 351Ch   		           ; AH - 35h - считать адрес обработчика прерываний
											       ; AL = 1Сh - номер прерывания
			int		21h	        			       ; ES:BX = адрес обработчика прерывания
								
			mov		DI, OFFSET SIGNATURE	       ;смещение сигнатуры относительно
			sub		DI, OFFSET INT_HANDLER         ;начала обработчика прерывания

			mov		AX, ES:[BX + DI]
			cmp		AX, SIGNATURE			       ;если совпадают, значит резидент установлен
			jne		CHANGE_
			jmp		END_CHECK

CHANGE_:                                           ;изменяем флаг - 0 - прерывание не установлено
			mov		CHECK_flag, 0
	
END_CHECK:	
			pop		ES
			pop		DI
			pop		BX
			pop		AX
			retn
CHECK		ENDP
;-----------------------------------------------------------
;2 задание: установить резидентную функцию для обработки прервания
;настроить вектор прерываний - если не установлен
;осуществить выход по функции 4Сh int21h
SETTING_INTERRUPT		PROC	NEAR                    ;установка прерывания 
				
						push	AX
						push	BX
						push	CX
					    push	DX
						push	ES
						push	DS 
			
												        ;запоминаем адрес предыдущего обработчика
						mov		AX, 351Ch               ;AH = 35h - считать адрес обработчика прерываний
									    	            ;AL = 1Сh - прерывание
						int		21h
						mov		KEEP_IP, BX             ;запоминаем смещение
						mov		KEEP_CS, ES	            ;запоминаем сегментный адрес
				
						push	DS
						mov     DX, SEG INT_HANDLER     ;сегментный адрес
						mov     DS, DX				    ;в DS
						mov     DX, OFFSET INT_HANDLER  ;смещение в DX

						mov		AX, 251Ch               ;AH = 25h - установить адрес обработчика прерывания
						int		21h
						
						pop		DS
														;оставить процедуру резидентной в памяти 		
						mov		DX, OFFSET LAST_BYTE	;определение размера
					                                    ;резидентной части программы Fh для округления вверх
						mov		CL, 4h                  ;деление на 16		    
						shr		DX, CL			    	;в параграфах	
						add     DX, 10Fh   
						inc		DX                 
						
						xor		AX, AX
						mov		AH, 31h                 ;оставить программу резидентной
						int     21h
						
						pop		DS
						pop		ES
						pop		DX
						pop		CX
						pop		BX
						pop		AX
						
						retn
SETTING_INTERRUPT		ENDP	
;-----------------------------------------------------------	
CHECK_UNLOAD		PROC	NEAR			            ;проверка есть ли запрос на выгрузку

					push	ES
					push	AX
											            ;проверяем хвост командной строки 0081h..
					mov		AX, KEEP_PSP
					mov		ES, AX
					
					cmp     BYTE PTR ES:[0082h], '/'
					je		NEXT1
					jmp		EXIT_
					
NEXT1:					
					cmp     BYTE PTR ES:[0083h], 'u'
					je		NEXT2
					jmp		EXIT_
					
NEXT2:				
					cmp     BYTE PTR ES:[0084h], 'n'
					je		CHANGE__
					jmp		EXIT_
					
CHANGE__:			
					mov     CHECK2_flag, 0

EXIT_:
					pop		AX
					pop		ES
					retn
					
CHECK_UNLOAD		ENDP
;-----------------------------------------------------------	
UNLOAD_INTERRUPT		PROC	NEAR				   ;выгрузка обработчика прерываний
						
						CLI							   ;запретить прерывания
						
						push	AX					   ;сохранение регистров
						push	BX
					    push	DX
						push	ES
						push	DS 
						push	DI
						
						mov		AX, 351Ch               ;AH = 35h - считать адрес обработчика прерываний
									    	            ;AL = 1Сh - прерывание
						int		21h
						
						mov		DI, OFFSET KEEP_IP
						sub		DI, OFFSET INT_HANDLER 
						
						mov		DX, ES:[BX + DI]
						add		DI, 2
						mov     AX, ES:[BX + DI]
						add		DI, 2
						
						push	DS
						mov		DS, AX
						mov		AX, 251Ch
						int     21h			           ;восстановление вектора
						pop		DS
						
						mov		AX, ES:[BX + DI]
						mov		ES, AX
						
						push	ES
						mov		AX, ES:[2Ch]
						mov		ES, AX
						
						mov		AH, 49h			      ;Освободить распределенный блок памяти
						int     21h					  ;ES = сегментный адрес (параграф) освобождаемого блока памяти
						
						pop     ES
						mov		AH, 49h
						int     21h
						
						pop		DI
						pop		DS
						pop		ES
						pop		DX
						pop		BX
						pop		AX
						
						STI							  ;Разрешение аппаратных прерываний
						
						retn
UNLOAD_INTERRUPT		ENDP
;-----------------------------------------------------------
PRINTF		PROC	NEAR  

			push    AX
			mov		AH, 09h
			int 	21h
			pop     AX
			
			retn
PRINTF		ENDP
;-----------------------------------------------------------	
BEGIN		PROC	NEAR 

			push 	DS
			xor 	AX, AX
			push	AX
			mov 	AX, DATA
			mov 	DS, AX
			
		    mov		KEEP_PSP, ES	                 
			
			call	CHECK
			cmp		CHECK_flag, 0                     
			je		CASE1
			jmp		CASE2
			
CASE1: 												   ;прерывание не было установлено и его нужно установить
			call    CHECK_UNLOAD
			cmp		CHECK2_flag, 0 
			je      CASE4
			
			mov		DX, OFFSET SMS1
		    call	PRINTF		
			
			call    SETTING_INTERRUPT                  ;установка прерывания
		    jmp		END_BEGIN

CASE2:											      ;прерывание уже загружено
			mov		DX, OFFSET SMS2 
		    call	PRINTF	
			
			call    CHECK_UNLOAD
			cmp		CHECK2_flag, 0
			
			je      CASE3
			jmp		END_BEGIN
	
CASE3:	
			call    UNLOAD_INTERRUPT
			mov		DX, OFFSET SMS3
		    call	PRINTF
			jmp		END_BEGIN
			
CASE4:													;не было загружено -- не может быть выгружено
			mov		DX, OFFSET SMS4 
		    call	PRINTF
			
END_BEGIN:
			xor		AL, AL			                   ;выход в DOS
			mov		AH, 4Ch
			int		21h

BEGIN		ENDP
;-----------------------------------------------------------
CODE ENDS

AStack  SEGMENT  STACK
        DW 128 dup(?)
AStack  ENDS

DATA    SEGMENT	                ;ДАННЫЕ
EOF		EQU		'$'
SMS1            DB		'The interruption has not yet been established. Start interrupt setup.', 0DH, 0AH,     EOF
                        ;Прерывание еще не было установлено. Запуск установки прерывания.
SMS2            DB		'Interrupt already loaded!', 0DH, 0AH, EOF      ;прерывание уже загружено
SMS3            DB		'Interrupt unloaded!', 0DH, 0AH,       EOF		;прерывание выгружено
SMS4			DB		'The interrupt cannot be unloaded, because it is not set.', 0DH, 0AH,       EOF	
                        ;прерывание не может быть выгружено, так как оно не установлено.
;flags
CHECK_flag		DB	     1	
CHECK2_flag		DB	     1	
DATA    ENDS

        END		BEGIN
