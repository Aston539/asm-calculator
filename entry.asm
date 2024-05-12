
.data

; ntdll.dll imports
	; extern sprintf:proc

; kernel32.dll imports
	extern WriteConsoleA:proc
	extern GetStdHandle:proc
	extern HeapAlloc:proc
	extern ReadConsoleA:proc
	extern SetConsoleCursorPosition:proc
	extern GetConsoleScreenBufferInfo:proc
	extern GetLastError:proc
	extern StrToIntA:proc

; strings

	CalculatorHeader db "----- CALCULATOR -----", 0
	AskForNumber db "Please enter a number: ", 0
	AskForOperator db "Please enter an operator: ", 0
	ShowResultFmt db "Result: %i", 0

	ConsoleReadBuffer BYTE 256 DUP (0)
	ConsoleIntToStringBuffer BYTE 256 DUP (0)

; variables
	StdInputHandle qword 0
	StdOutputHandle qword 0
	StdErrorHandle  qword 0

.code

	align 16

	CalcNewline proc

		push rcx
		push rdx

;
;
; typedef struct _CONSOLE_SCREEN_BUFFER_INFO 
; {
;    COORD      dwSize;					; 0x000
;    COORD      dwCursorPosition;		; 0x004
;    WORD       wAttributes;			; 0x008
;    SMALL_RECT srWindow;				; 0x00A
;    COORD      dwMaximumWindowSize;	; 0x012
; } CONSOLE_SCREEN_BUFFER_INFO;			; 0x016
;
;
		sub rsp, 16h

		mov rcx, qword ptr[ StdOutputHandle ]
		mov rdx, rsp

		call GetConsoleScreenBufferInfo
;
; 
; typedef struct _COORD
; {
;   SHORT X;							; 0x000
;   SHORT Y;							; 0x002
; } COORD, *PCOORD;						; 0x004
; 
;
		mov rdx, [ rsp + 4h ]
		mov dx, 0
		mov [ rsp + 4h ], rdx

		mov rdx, [ rsp + 6h ]
		add dx, 1
		mov [ rsp + 6h ], rdx

		mov rcx, qword ptr[ StdOutputHandle ]
		mov rdx, rsp

		add rdx, 4h

		mov rdx, [ rdx ]

		call  SetConsoleCursorPosition

		cmp rax, 0
		jz set_cursor_fail

		add rsp, 16h

		jmp main_ret

	set_cursor_fail:

		call GetLastError

	main_ret:

		pop rdx
		pop rcx

		ret

	CalcNewline endp

	CalcStrlen proc

	; context:
	; rcx -> string address
		
		mov rdi, rcx

		push rcx

	; set rcx to UIN64_MAX( FFFFFFFFFFFFFFF ) as our max
	; loop amounts
		mov rcx, 0
		sub rcx, 1

	; set our target byte to be 0 so we break when we
	; find this byte its our null terminator
		mov al, 0

	; repeat scan string compare btte
		repne scasb

	; set rax to UIN64_MAX( FFFFFFFFFFFFFFF ) as our max
	; starting string length
		mov rax, 0
		sub rax, 1

	; subtract rax with whats left of rcx to determine the
	; total length of the string
		sub rax, rcx

		jmp strlen_ret

	strlen_failure:

		mov rax, 0

		jmp strlen_ret

	strlen_ret:

		pop rcx

		ret

	CalcStrlen endp

;
; accidently made this was suppose to make
; memset
;
	CalcMemcpy proc

	; context
	;  rcx -> dst
	;  rdx -> src
	;  r8 -> len

		push rsi
		push rdi

		mov rsi, rdx
		mov rdi, rcx

		pushf         ; push flags onto the stack
		pop rax        ; pop flags into ax
		and eax, 7FFFFFFFh  ; set direction flag to 0
		push rax       ; push ax
		popf          ; pop into flags


	do_while_len:

		movsb

		sub r8, 1
		jnz do_while_len

	main_ret:

		pop rsi
		pop rdi

		ret

	CalcMemcpy endp

	CalcMemset proc

		; context
	;  rcx -> dst
	;  rdx -> val
	;  r8 -> len

		push rsi
		push rdi

		push rdx ; allocate some stack memory with the value of our parameter

		mov rsi, rsp ; movsb needs an address so we will give it one on the stack
		mov rdi, rcx

		pushf         ; push flags onto the stack
		pop rax        ; pop flags into ax
		and eax, 7FFFFFFFh  ; set direction flag to 0
		push rax       ; push ax
		popf          ; pop into flags


	do_while_len:

		movsb

		sub rsi, 1 ; account for movsb incrementing it

		sub r8, 1
		jnz do_while_len

	main_ret:

		pop rdx

		pop rdi
		pop rsi

		ret

	CalcMemset endp

	CalcPrint proc

	; context:
	;  rcx -> string address  

		push rdx
		push rcx

		cmp rcx, 0
		jz main_fail

		call CalcStrlen
		mov rdx, rax

		cmp rdx, 0
		jz main_fail

		push rdx
		push rcx

		mov rcx, qword ptr[ StdOutputHandle ]
		pop rdx
		pop r8
		mov r9, 0

		sub rsp, 8h

		call WriteConsoleA

		add rsp, 8h

		mov rax, 1

		jmp main_ret

	main_fail:

		mov rax, 0

		jmp main_ret

	main_ret:

		pop rcx
		pop rdx

		ret

	CalcPrint endp

	CalcGetInput proc

		push rcx
		push rdx
		push r8
		push r9

		lea rcx, ConsoleReadBuffer
		mov rdx, 0
		mov r8, 256
		call CalcMemset

		mov rcx, qword ptr[ StdInputHandle ]
		lea rdx, ConsoleReadBuffer
		mov r8, 255

		push r9 ; allocate 8 bytes on the stack

		mov r9, rsp ; r9 now holds the address of r9d on the stack

		sub rsp, 8h

		call ReadConsoleA

		add rsp, 8h

		pop r9

		mov rax, qword ptr[ ConsoleReadBuffer ]

	main_ret:

		pop r9
		pop r8
		pop rdx
		pop rcx

		ret

	CalcGetInput endp

	CalcSetupConsole proc

		push rcx

		mov rcx, -10 ; STD_INPUT_HANDLE ((DWORD)-10)
		call GetStdHandle

		cmp rax, 0
		jz failure_ret

		mov qword ptr[ StdInputHandle ], rax

		mov rcx, -11 ; STD_OUTPUT_HANDLE ((DWORD)-11)
		call GetStdHandle
		
		cmp rax, 0
		jz failure_ret

		mov qword ptr[ StdOutputHandle ], rax

		mov rcx, -12 ; STD_ERROR_HANDLE ((DWORD)-12)
		; call GetStdHandle

		cmp rax, 0
		jz failure_ret

		mov qword ptr[ StdErrorHandle ], rax

		mov rax, 1

		jmp main_ret

	failure_ret:

		mov rax, 0

	main_ret:

		pop rcx

		ret


	CalcSetupConsole endp

	CalcStringToInt proc

	; context:
	; rcx -> string address
	;

	main_ret:
		
		ret

	CalcStringToInt endp

	CalcDoCalculation proc

		;
		; context:
		;  rcx -> num1
		;  rdx -> num2
		;  r8  -> operator
		;

		cmp r8, '+'

		je do_addition

		cmp r8, '-'

		je do_subtraction

		cmp r8, '*'

		je do_multiplication

		cmp r8, '/'

		je do_division

		jmp unknown_operator

	do_addition:

		mov rax, rcx
		add rax, rdx

		jmp main_ret

	do_subtraction:

		mov rax, rcx
		sub rax, rdx

		jmp main_ret

	do_multiplication:

		mov rax, rdx
		mov rdx, rcx
		mul rdx

		jmp main_ret

	do_division:

		mov rax, rdx
		mov rdx, rcx
		div rdx

		jmp main_ret

	unknown_operator:

		mov rax, -1

	main_ret:

		ret

	CalcDoCalculation endp

	CalcLogic proc

	;
	; rsp + 0x0  = dst number
	; rsp + 0x8  = src number
	; rsp + 0x10 = operator number
	;

		sub rsp, 10h

		xor rdx, rdx

		call CalcSetupConsole

	start_calculation:

		lea rcx, CalculatorHeader
		call CalcPrint
		call CalcNewline

		jmp ask_for_number

	ask_for_number_2:

		mov rdx, rax

		xor rax, rax

	ask_for_number:

		lea rcx, AskForNumber
		call CalcPrint

		call CalcGetInput

		push rax
		mov rcx, rsp

		push rdx
		call StrToIntA
		pop rdx

		pop rcx
		xor rcx, rcx

		cmp rdx, 0
		jz ask_for_number_2

		push rax

		jmp ask_for_operator

	ask_for_operator:

		lea rcx, AskForOperator
		call CalcPrint

		call CalcGetInput

		push rax

		xor rax, rax

		mov al, byte ptr[ rsp ]

		pop r8

		xor r8, r8

		jmp calc_docalculation

	calc_docalculation:

		mov r8, rax
		mov rcx, rdx
		pop rdx
		
		call CalcDoCalculation

	end_calculation:

		add rsp, 10h

		ret

	CalcLogic endp
	 
	main proc

		call CalcLogic

		ret
	
	main endp

end