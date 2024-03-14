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
; https://stackoverflow.com/questions/20082414/mac-os-x-32-bit-nasm-assembly-program-using-main-and-scanf-printf
; 

            section     .data

split:      db          "--------------------------------------------------------------", 10, 0
welcome1:   db          "(っ◔◡◔)っ Добро пожаловать! (っ◔◡◔)っ", 10, 0
welcome2:   db          "Данная программа предназначена для вычисления значения функции:", 10, 10, 0
welcome3_1: db          "                                     ⌈ A * X, если X mod 3 = 2                      ⌈ A - X, если A > X", 10, 0
welcome3:   db          "y = y1 * y2, где y1 = Σ X от 0 до 9 〈                           y2 = Σ X от 0 до 9〈", 10, 0
welcome3_2: db          "                                     ⌊ 9 в остальных случаях                        ⌊ A + 2, если A <= X", 10, 10, 0

zeroDiv:    db          "Ошибка: нельзя делить на ноль", 10, 0

switch:     db          "Введите номер функции:", 10, 0

int_in1:    db          "Введите A" , 10, 0
int_in2:    db          "Введите X" , 10, 0
inFormat:   db          "%lf", 0
intPrint2:  db          "Результат: %d", 10, 0
floatPrint: db          "%.5lf", 10, 0

price:      dq          0.1

test_float: dq          1.2345

one:        dq          1.0
two:        dq          2.0
three:      dq          3.0
nine:       dq          9.0


            section     .bss

var1:       resq        1
var2:       resq        1

result:     resq        1

global      _main
extern      _printf
extern      _scanf
extern      _fmod
default     rel

            section     .text
            
_main:      push        rbp                     ; Call stack must be aligned (stack setup)

            call        _welcome                ; приветственное сообщение

            ; Ввод первого числа

            lea         rdi, [int_in1]    
            xor         rax, rax                ; Это типа более быстрый и короткий путь для того чтобы установить EAX в 0
            call        _printf

            lea         rdi, [inFormat]
            lea         rsi, [var1]
            xor         rax, rax
            call        _scanf

            ; Ввод второго числа

            lea         rdi, [int_in2]    
            xor         rax, rax                ; Это типа более быстрый и короткий путь для того чтобы установить EAX в 0
            call        _printf

            lea         rdi, [inFormat]
            lea         rsi, [var2]
            xor         rax, rax
            call        _scanf

            xor         rsi, rsi

_count_y1:  
            mov         rcx, 1
            movq        xmm5, qword[result]
            movq        xmm3, qword[var1]      ; A исх
            movq        xmm4, qword[var2]      ; X (x каждую итерацию += 1)

_y1_loop: 
            movsd       xmm0, xmm4
            movq        xmm1, qword[three]

            mov         rbx, rcx
            call        _fmod
            mov         rcx, rbx
            
            movq         rax, xmm0      
            cmp          rax, [two]             ; проверка x mod 3

            jz          _y1_case1
            jnz         _y1_case2

_y1_case1: 
            movsd       xmm0, xmm3
            mulsd       xmm0, xmm4
            addsd       xmm5, xmm0

            addsd       xmm4, qword[one]

            loop        _y1_loop

            jmp         _complete_y1

_y1_case2:     
            addsd       xmm5, qword[nine]

            addsd       xmm4, qword[one]

            loop        _y1_loop

            jmp         _complete_y1

_complete_y1:   
            movq       r12, xmm5                ; y1

; ==================================================

_count_y2:  
            mov         rcx, 1
            movq        xmm5, qword[result]
            movq        xmm3, qword[var1]      ; A исх
            movq        xmm4, qword[var2]      ; X (x каждую итерацию += 1)

_y2_loop:   
            movq        rax, xmm3
            movq        rbx, xmm4

            cmp         rax, rbx

            ja          _y2_case1
            jng         _y2_case2
            

_y2_case1:  
            movsd       xmm0, xmm3
            subsd       xmm0, xmm4
            
            addsd       xmm5, xmm0

            addsd       xmm4, qword[one]

            loop        _y2_loop

            jmp         _complete_y2


_y2_case2:  
            movsd       xmm0, xmm3
            addsd       xmm0, qword[two]
            
            addsd       xmm5, xmm0

            addsd       xmm4, qword[one]

            loop        _y2_loop

            jmp         _complete_y2

_complete_y2:   
            movsd       xmm0, xmm5

_complete:  
            movq        xmm1, r12  
            mulsd       xmm0, xmm1

_print_result: 
            ; --------------------------------------------------------------------------------
            ; Вывод результата
            ; результат должен быть в XMM0
            ; --------------------------------------------------------------------------------
            lea         rdi, floatPrint
            mov         eax, 1
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

    lea         rdi, [welcome3_1]
    call        _printf

    lea         rdi, [welcome3]
    call        _printf

    lea         rdi, [welcome3_2]
    call        _printf

    lea         rdi, [split]
    call        _printf
    
    pop         rbp
    ret