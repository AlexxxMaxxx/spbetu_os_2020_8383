COMMENT *
Максимова Анастасия, группа 8383 - лабораторная 5
*

CODE	SEGMENT
		ASSUME CS:CODE, DS:DATA, SS:AStack, ES:NOTHING
		
;-----------------------------------------------------------
INT_HANDLER		PROC	FAR		                      ;обработчик прерываний

				JMP		HANDLER_START
					
				SIGNATURE			DW	  4321h   	  ;для проверки
				
				KEEP_AX				DW    0
				KEEP_SS				DW	  0
				KEEP_SP				DW	  0
				KEEP_IP				DW	  0
				KEEP_CS				DW	  0
				KEEP_PSP			DW    0
				
				REPL_CHAR			DB    0
				CHAR_A				DB    1Eh        ;скан-коды
				CHAR_B				DB    30h
				CHAR_C				DB    2Eh
				CHAR_D				DB    20h
				CHAR_E				DB    12h
				
				;Чтобы иметь возможность работать со стеком уменьшенного размера, 
				;каждому обработчику прерывания выделяется свой стек, отдельный для каждого процессора.
				INT_HANDLER_Stack	DW    64 dup(?) ;стек прерывания
                ;-------------------------------
		
HANDLER_START:	
				mov		KEEP_SS, SS					;"переключаемся на стек прерывания" 
				mov		KEEP_SP, SP
				mov		KEEP_AX, AX
				
				mov		AX, SEG INT_HANDLER_Stack
				mov		SS, AX
				
				mov		AX, OFFSET INT_HANDLER_Stack
				add		AX, 128                      ;64*2			
				mov		SP, AX	                     ;SP устанавливается на конец стека
				;-------------------------------
													 ;сохранение изменяемых регистров
				push	ES
				push    CX
				push    DS
				;-------------------------------
				mov		AX, SEG REPL_CHAR
				mov		DS, AX
				;замена: abcde-->lr5:)
													; действия по обработке прерывания 09h
				in      AL, 60h						; получение скан-кода последней нажатой клавиши
				cmp		AL, CHAR_A
				jne     OTHER1
				mov		REPL_CHAR, 'L'
				jmp     HANDWARE_INTERR
				
OTHER1:
				cmp		AL, CHAR_B
				jne		OTHER2
				mov     REPL_CHAR, 'r'
				jmp     HANDWARE_INTERR
				
OTHER2:
				cmp		AL, CHAR_C
				jne     OTHER3
				mov     REPL_CHAR, '5'
				jmp     HANDWARE_INTERR
				
OTHER3:
				cmp		AL, CHAR_D
				jne		OTHER4
				mov		REPL_CHAR, ':'
				jmp     HANDWARE_INTERR
				
OTHER4:
				cmp     AL, CHAR_E
				jne 	CONTINUE
				mov     REPL_CHAR, ')'
				jmp     HANDWARE_INTERR
				
				
CONTINUE:
				pushf
				call 	DWORD PTR CS:KEEP_IP
				jmp		EXIT
				
HANDWARE_INTERR: 									; обработка аппаратного прерывания
													; 61h - регистр управления клавиатурой
													; установка 7 бита порта 61h и возвращение исходного состояния
				in		AL, 61h						; вхять значение порта управления клавиатурой
				mov		AH, AL						; сохраняем
				or		AL, 80h						; установить бит разрешения для клавиатуры
				out		61h, AL						; вывести его в управляющий порт
				xchg    AH, AL						; извлечь исходное значение порта
				out     61h, AL						; и записать его обратно
				
				mov     AL, 20h						; послать сигнал "конец прерывания"
				out     20h, AL						; контроллеру прерываний 8259
			
				;-------------------------------
CHARACTER_BUFFER:
				mov		AH, 05h						; запись символа в буфер клавиатуры
				mov     CL, REPL_CHAR    			; CL - символ ASCII
				mov		CH, 00h						; CH - скан-код
				int     16h
				or		AL, AL						; проверка переполнения буфера
				JNZ		SKIP						; если переполнение
				JMP     EXIT
				
SKIP:				
				mov     AX, 0040h
				mov		ES, AX
				mov		AX, ES:[1Ah]				;0040:001Ah - указатель на начало
				mov     ES:[1Ch], AX				;0040:001Ch - указатель на конец буфера
				jmp     CHARACTER_BUFFER			;повтор
				;-------------------------------
EXIT:				    
				        			                ;восстановление регистров
				pop     DS
				pop     CX
				pop		ES
				;-------------------------------
				mov		AX, KEEP_SS					;"переключаемся на внешний стек" 
				mov		SS, AX
				
				mov		SP, KEEP_SP
				mov		AX, KEEP_AX
				;-------------------------------
				mov     AL, 20h						;выход
				out		20h, AL
				iret	                            ;popf + retf - возврат из прерывания
			
INT_HANDLER		ENDP
LAST_BYTE:	
;-----------------------------------------------------------
CHECK		PROC	NEAR		                    ;1)проверяет, установлено ли 
								                    ;пользовательское прервание с вектором 1Сh	
			push	AX
			push	BX
			push	DI
			push	ES
											       ;чтение адреса, записанного в векторе прерывания
			mov     AX, 3509h   		           ; AH - 35h - считать адрес обработчика прерываний
											       ; AL = 09h - номер прерывания
			int		21h	        			       ; ES:BX = адрес обработчика прерывания
								
			mov		DI, OFFSET SIGNATURE	       ;смещение сигнатуры относительно
			sub		DI, OFFSET INT_HANDLER         ;начала обработчика прерывания

			mov		AX, ES:[BX + DI]
			cmp		AX, SIGNATURE			       ;если совпадают, значит резидент установлен
			jne		END_CHECK
			mov		CHECK_flag, 0
													;изменяем флаг - 0 - если установлен
	
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
						mov		AX, 3509h               ;AH = 35h - считать адрес обработчика прерываний
									    	            ;AL = 09h - прерывание
						int		21h
						mov		KEEP_IP, BX             ;запоминаем смещение
						mov		KEEP_CS, ES	            ;запоминаем сегментный адрес
				
						push	DS
						mov     DX, SEG INT_HANDLER     ;сегментный адрес
						mov     DS, DX				    ;в DS
						mov     DX, OFFSET INT_HANDLER  ;смещение в DX

						mov		AX, 2509h               ;AH = 25h - установить адрес обработчика прерывания
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
						
						mov		AX, 3509h               ;AH = 35h - считать адрес обработчика прерываний
									    	            ;AL = 09h - прерывание
						int		21h
						
						mov		DI, OFFSET KEEP_IP
						sub		DI, OFFSET INT_HANDLER 
						
						mov		DX, ES:[BX + DI]
						add		DI, 2
						mov     AX, ES:[BX + DI]
						add		DI, 2
						
						push	DS
						mov		DS, AX
						mov		AX, 2509h
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
BEGIN		PROC	FAR 

			push 	DS
			xor 	AX, AX
			push	AX
			mov 	AX, DATA
			mov 	DS, AX
			
		    mov		KEEP_PSP, ES	                 
			
			call	CHECK
			cmp		CHECK_flag, 0      					;если не равен 0, устанавливаем               
			jne		CASE1
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