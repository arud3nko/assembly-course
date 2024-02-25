; ----------------------------------------------------------------------------------------
;     nasm -fmacho64 main.asm && gcc main.o && ./a.out
; ----------------------------------------------------------------------------------------
; The 64-bit OS X ABI complies at large to the System V ABI - AMD64 Architecture Processor Supplement. 
; Its code model is very similar to the Small position independent code model (PIC) with the differences explained here. 
; In that code model all local and small data is accessed directly using RIP-relative addressing. 
; As noted in the comments by Z boson, the image base for 64-bit Mach-O executables is beyond the first 4 GiB of the virtual address space, 
; therefore push msg is not only an invalid way to put the address of msg on the stack, but it is also an impossible one since PUSH does not support 
; 64-bit immediate values.
;
; https://itecnote.com/tecnote/macos-x64-nasm-pushing-memory-addresses-onto-the-stack-call-function/
; https://www.cs.uaf.edu/2017/fall/cs301/reference/x86_64.html

; The 64-bit calling convention mandates that the fist 6 integer/pointer arguments are passed in registers RDI, RSI, RDX, RCX, R8, and R9, exactly in that order. 
; The first 8 floating-point or vector arguments go into XMM0, XMM1, ..., XMM7. 
; Only after all the available registers are used or there are arguments that cannot fit in any of those registers (e.g. a 80-bit long double value) 
; the stack is used. 64-bit immediate pushes are performed using MOV (the QWORD variant) and not PUSH. Simple return values are passed back in the RAX register. 
; The caller must also provide stack space for the callee to save some of the registers.
; ----------------
; printf is a special function because it takes variable number of arguments. 
; When calling such functions AL (the low byte of RAX) should be set to the number of floating-point arguments, passed in the vector registers. 
; Also note that RIP-relative addressing is preferred for data that lies within 2 GiB of the code.

; _main:
;     push    rbp                 ; re-aligns the stack by 16 before call
;     mov     rbp, rsp       

;     xor     eax, eax            ; al = 0 FP args in XMM regs
;     lea     rdi, [rel msg]
;     call    _printf

;     mov     rsp, rbp
;     pop     rbp
;     ret
;
; https://stackoverflow.com/questions/10973650/how-to-use-scanf-in-nasm
; 

            section     .data

split:      db          "--------------------------------------------------------------", 10, 0
welcome1:   db          "(っ◔◡◔)っ Добро пожаловать! (っ◔◡◔)っ", 10, 0
welcome2:   db          "Данная программа предназначена для вычисления значений функций", 10, 0
welcome3:   db          "Операции деления не учитывают остаток!", 10, 0
case1:      db          "1) X^3 + Y - 1", 10, 0
case2:      db          "2) (XY + 1) / X^2", 10, 0
case3:      db          "3) (X+Y)/(X-Y)", 10, 0
case4:      db          "4) -1/X^3 + 3", 10, 0
case5:      db          "5) X - Y/X + 1", 10, 0
exitCase:   db          "Для выхода из программы введите 0", 10, 0

zeroDiv:    db          "Ошибка: нельзя делить на ноль", 10, 0

switch:     db          "Введите номер функции:", 10, 0

int_in1:    db          "Введите X" , 10, 0
int_in2:    db          "Введите Y" , 10, 0
intFormat:  db          "%d", 0
intPrint:   db          "Результат: %d", 10, 0


            section     .bss

userSw:     resd        1
var1:       resd        1
var2:       resd        1

global      _main
extern      _printf
extern      _scanf
default     rel

            section     .text
            
_main:      push        rbp                     ; Call stack must be aligned (stack setup)

            call        _welcome                ; приветственное сообщение

            ; выбор функции

            lea         rdi, [intFormat]
            lea         rsi, [userSw]
            xor         rax, rax
            call        _scanf

            cmp         dword [userSw], 0
            je          _end

            ; Ввод первого числа

            lea         rdi, [int_in1]    
            xor         rax, rax                ; Это типа более быстрый и короткий путь для того чтобы установить EAX в 0
            call        _printf

            lea         rdi, [intFormat]
            lea         rsi, [var1]
            xor         rax, rax
            call        _scanf

            ; Ввод второго числа

            lea         rdi, [int_in2]    
            xor         rax, rax                ; Это типа более быстрый и короткий путь для того чтобы установить EAX в 0
            call        _printf

            lea         rdi, [intFormat]
            lea         rsi, [var2]
            xor         rax, rax
            call        _scanf

            ; Switch case

            mov         eax, [userSw]

            cmp         eax, 1
            je          _case1
            cmp         eax, 2
            je          _case2
            cmp         eax, 3
            je          _case3
            cmp         eax, 4
            je          _case4
            cmp         eax, 5
            je          _case5

            jmp         _end


_case1: 
            ; --------------------------------------------------------------------------------
            ; Z = X^3 + Y - 1
            ; --------------------------------------------------------------------------------

            mov         rax, [var1]             
            mov         rbx, 3
            call        _power              ; x ^ 3
            mov         rbx, [var2]
            add         rax, rbx            ; + y
            dec         rax                 ; - 1
            jmp         _print_result


_case2: 
            ; --------------------------------------------------------------------------------
            ; (XY + 1) / X^2
            ; --------------------------------------------------------------------------------

            mov         ecx, [var1]         ; сохраняю X в rcx
            mov         eax, ecx            ; кидаю X в rax
            imul        dword [var2]        ; (x * y)
            add         eax, 1
            mov         ebx, ecx
            imul        ebx, ecx
            xor         edx, edx
            cdq
            idiv        ebx
            jmp         _print_result


_case3: 
            ; --------------------------------------------------------------------------------
            ; (X+Y)/(X-Y)
            ; --------------------------------------------------------------------------------

            mov         eax, [var1]
            mov         ebx, [var1]

            add         eax, dword [var2]
            sub         ebx, dword [var2]

            jz          _division_by_zero

            xor         edx, edx
            cdq
            idiv        ebx

            jmp         _print_result


_case4: 
            ; --------------------------------------------------------------------------------
            ; -1/X^3 + 3
            ; --------------------------------------------------------------------------------

            mov         eax, [var1]

            cmp         eax, 0
            je          _division_by_zero

            mov         ebx, 3
            call        _power

            mov         ebx, eax            ; теперь в ebx x^3
            mov         eax, -1             ; а в eax -1

            xor         edx, edx
            cdq
            idiv        ebx

            add         eax, 3

            jmp         _print_result


_case5: 
            ; --------------------------------------------------------------------------------
            ; X - Y/X + 1
            ; --------------------------------------------------------------------------------
            
            mov         ebx, [var1]

            cmp         eax, 0
            je          _division_by_zero

            mov         eax, [var2]

            xor         edx, edx
            cdq
            idiv ebx

            mov         rbx, rax
            mov         rax, [var1]

            sub         rax, rbx

            inc         rax

            jmp         _print_result

_print_result: 
            ; --------------------------------------------------------------------------------
            ; Вывод результата
            ; --------------------------------------------------------------------------------

            lea         rdi, [intPrint]
            mov         rsi, rax
            call        _printf


_end:   
            ; --------------------------------------------------------------------------------
            ; Выход из программы с кодом 0
            ; --------------------------------------------------------------------------------

            pop         rbp                     ; Fix up stack before returning
            mov         rax, 0                  ; exit code 0
            ret

_division_by_zero:  
            lea         rdi, [zeroDiv]
            call        _printf
            jmp         _end

; Функция, суммирующая значения в регистрах RAX и RBX
_sum:   
            add         rax, rbx
            ret

; Функция, возводящая число RAX в степень RBX
_power: 
    push rbp
    mov rcx, rbx
    mov rbx, rax
    dec rcx
_power_loop:    
    imul rbx
    loop _power_loop
    pop rbp
    ret
    

_welcome: 
    push        rbp

    lea         rdi, [split]
    call        _printf

    lea         rdi, [welcome1]
    call        _printf

    lea         rdi, [welcome2]
    call        _printf

    lea         rdi, [welcome3]
    call        _printf

    lea         rdi, [split]
    call        _printf

    lea         rdi, [case1]
    call        _printf

    lea         rdi, [case2]
    call        _printf

    lea         rdi, [case3]
    call        _printf

    lea         rdi, [case4]
    call        _printf

    lea         rdi, [case5]
    call        _printf

    lea         rdi, [split]
    call        _printf

    lea         rdi, [exitCase]
    call        _printf

    lea         rdi, [split]
    call        _printf

    lea         rdi, [switch]
    call        _printf
    
    pop         rbp
    ret