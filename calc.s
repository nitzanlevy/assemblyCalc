%macro print_hello 0
	pushad
	push say_hello
	call printf
	add esp, 4 ; size of dword
	popad
%endmacro

%macro print_reg 1
    pushad
    push %1
    push print_number
    call printf
    add esp, 8
    popad
%endmacro

%macro get_pointer_of_first_element_to_edx 0
    dec dword[operand_stack_counter]
    mov ecx,dword[operand_stack_counter]    ;gets the number of values in the stack right now
    mov edx, dword[operand_stack_start]     ;the current place in the stack
    imul ecx, 4
    add edx,ecx                             ;edx = edx +4*ecx = upper list 
%endmacro

%macro get_pointer_of_second_element_to_ecx 0
    sub ecx, 4
    mov ebx, dword[operand_stack_start]
    add ecx, ebx                            ;ecx = lower list
%endmacro

%macro debug 0
    pushad
    cmp dword[debug_mode_on], true
    jne %%end_debug

    mov ecx,dword[operand_stack_counter]    ;gets the number of values in the stack right now
    mov edx, dword[operand_stack_start]     ;the current place in the stack
    dec ecx
    imul ecx, 4
    add edx,ecx                             ;edx = edx +4*ecx = upper list 

    push edx
    call print_list
    add esp, 4

    %%end_debug:
    popad
%endmacro

section .rodata
    defult_stack_size: equ 20
    true: equ 1
    false: equ 0
    buf_size: 	equ 100
    data: equ 0
    next: equ 1
    new_line:   db 10,0
    default_message: db 'calc: ',0

    print_number:db '%d',10,0
    say_hello: db 'hello world',10,0
    print_hexa_number:  db '%02X',0
    print_last_hexa_number: db '%X',0
    print_hexa_number_new_line:  db '%X',10 , 0

    input_error_message:    db 'the input is invalid.... exiting', 10, 0
    error_insuficcient_message: db 'Error: Insufficient Number of Arguments on Stack',10,0
    error_stack_overflow: db 'Error: Operand Stack Overflow', 10, 0
    
section .bss
    operand_stack_start:  resb 4
    operand_stack_counter: resb 4
    operand_stack_size: resb 4
    debug_mode_on:  resb 4
    input_buf: 	resb 100
    operation_counter: resb 4

section .text
    global main
    extern malloc
    extern free
    extern printf
    extern stdin
    extern fgets

main:
    movmov ebp, esp
    mov ebx, dword [ebp+4]      ;got the number of argmuments (argc)
    mov ecx, dword [ebp+8]      ;pointer to argv
    mov dword[debug_mode_on], false ;set debug mode to default (false)

    cmp ebx, 1      ;check the number of arguments, if there are none sand to the default init
    je default_stack_init
    
    cmp ebx, 2      ;if there are two it might be debug or stack size 
    je debug_or_size

    cmp ebx,3       ;if there are tow we need to set debug mode and stack size
    je debug_and_size

    ;the function check if the argument is a size or -d
    debug_or_size:
        ;in [edx] the first args 
        mov edx, 0
        mov edx, dword[ecx+4]
        movzx eax, byte[edx]
        cmp eax, '-'    ;check if the first byte is - (means to debug mode)
        jne set_size
        call debug_mode
        jmp default_stack_init  ;if we are in debug mode we want to set the stack to the default size (5 pointers)
        set_size:
            call set_stack_size ;else, we got a stack size and we want to initinatite the stack to this size.
            jmp myCalc
        
    debug_and_size:                     ;set the oprand stack size and turn on debug mode
        call debug_mode
        mov edx, 0
        mov edx, dword[ecx+4]           ;got the size from argv
        call set_stack_size              ;set the stack size to the user spacificetions
        jmp myCalc
          
    debug_mode:
        mov dword[debug_mode_on], true  ;set the debug mode label to true (1)
        ret
    
    set_stack_size:
        mov eax, 0
        call stack_size_getter                  ;gets the user input string of exadecimal number and turn into actual number in eax
        mov dword[operand_stack_size], eax      ;puts the return value in thd operand stack size
        imul eax,4
        push eax
        call malloc                             ;allocating operand_stack_size * 4 bytes for the opernad stack
        add esp,4 
        mov [operand_stack_start], eax          ;puts the pointer in the operand stack
        ret
    
    default_stack_init:
        mov dword[operand_stack_size],5     ;insert to operand size the default max numbers in the stack (5)
        push defult_stack_size  ;malloc 20 bytes (5 pointers * 4 bytes for each pointer)
        call malloc 
        add esp,4
        mov [operand_stack_start], eax  ;malloc return a new pointer to eax and we save this pointer in operand start
        jmp myCalc
    
myCalc:
    push default_message     ;print the menu message
    call printf
    add esp,4

    push dword[stdin]    ;read input from user
    push buf_size
    push input_buf
    call fgets      ;return pointer to string in eax
    add esp, 12    

    mov bl,byte [eax]   ;save in ebx the value from the user
    q_option:
        cmp bl, 'q'
        jne add_option
        jmp q_funcion

    add_option:
        cmp bl, '+'
        jne pop_option
        inc dword[operation_counter]
        jmp add_function

    pop_option:
        cmp bl, 'p'
        jne dup_option
        inc dword[operation_counter]
        jmp pop_function
    
    dup_option:
        cmp bl, 'd'
        jne and_option
        inc dword[operation_counter]
        jmp dup_function
    
    and_option:
        cmp bl, '&'
        jne or_option
        inc dword[operation_counter]
        jmp and_function

    or_option:
        cmp bl, '|'
        jne n_option
        inc dword[operation_counter]
        jmp or_function

    n_option:
        cmp bl, 'n'
        jne number_option
        inc dword[operation_counter]
        jmp n_function
    
    number_option:
        jmp insert_number_to_stack

;exit the program and print the numbers of operations
q_funcion:
    push dword[operation_counter]
    push print_hexa_number_new_line ;print the number od operations
    call printf
    add esp, 8

    cmp dword[operand_stack_counter], 0 
    je end_q_loop
    ;clear_stack_pointers
    q_loop:
        get_pointer_of_first_element_to_edx
        cmp dword[operand_stack_counter], -1
        je end_q_loop
        mov eax,dword[edx]

        push eax
        call delete_list
        add esp, 4
        mov dword[edx], 0
        jmp q_loop
    end_q_loop:
    
    push dword[operand_stack_start]
    call free
    add esp,4
    mov eax, 1 ; system call (sys_exit)
    mov ebx, 0 ; exit status
    int 0x80 ; call kernel

add_function:
    mov ebx,dword[operand_stack_size]       ;checks if there are enough arguments to use the or function
    cmp dword[operand_stack_counter], 2
    jl error_insuficcient

    get_pointer_of_first_element_to_edx
    get_pointer_of_second_element_to_ecx
   
    mov esi,edx                             ;esi points at the start of the list
    mov ecx,[ecx]
    clc                                     ;reset the C-OUT flag
    add_loop:
        pushfd
        cmp dword[esi], 0                   ;if the upper list is finish we stop the proccess
        je save_my_carry
        cmp ecx, 0                          ;if the lower list is finis we point at the rest of the upper one
        je lower_finish_add
        popfd

        mov edx, dword[esi]                 ;moves the bytes of the data from both nodes
        mov bl, byte[edx]
        mov al, byte[ecx]

        adc al, bl
        mov byte[ecx], al                   ;adding the tow bytes and put them in the lower list 
       
        pushfd
        push esi
        call pop_element                    ;pops the element from the upper list
        add esp, 4 
        popfd

        mov edi, ecx                        ;edi hold the pointer for fixing lower_finish case
        mov ecx, dword[ecx + next]          ;advancing the lower list element

        jmp add_loop
    lower_finish_add:
        popfd
        mov eax, dword[esi]                 ;make the lower list point at the rest of the upper list, example:
        mov dword[edi + next], eax          ;                  > |01|->|11|->|01|
        mov dword[esi], 0                   ;|01|->|00|->|11| /
        mov ecx, dword[edi + next]
        jmp end_add_loop
    
    save_my_carry:
        popfd
    end_add_loop:
        pushfd
        cmp ecx, 0
        je end_add_func     ;we check if all of the lower list is done,( if not we keep adding if there is a C-OUT left, otherwise we are finish), other wise we finish
        popfd
        jnc end_add         ;if there is no C-OUT left we are done with the calc
        mov al, byte[ecx]

        adc al, 0
        mov byte[ecx], al    

        mov ecx, dword[ecx + next]
        jmp end_add_loop

    end_add_func:
        popfd
        jnc end_add                             ;check if we have C-OUT when we finish to go over the lower list. if we do have we need to add anoter node
        
        mov ecx,dword[operand_stack_counter]    ;gets the number of values in the stack right now
        mov edx, dword[operand_stack_start]     ;the current place in the stack
        dec ecx
        imul ecx, 4
        add edx,ecx

        push 1
        push edx
        call append_last                        ;add another node at the end of the lower list
        add esp, 8

    end_add:
    debug
    jmp myCalc

or_function:
    mov ebx,dword[operand_stack_size]       ;checks if there are enough arguments to use the or function
    cmp dword[operand_stack_counter], 2
    jl error_insuficcient 

    get_pointer_of_first_element_to_edx
    get_pointer_of_second_element_to_ecx
   
    mov esi,edx                             ; esi points at the start of the list
    mov ecx,[ecx]
    or_loop:
        cmp dword[esi], 0                   ;if the upper list is finish we stop the proccess
        je end_or_loop
        cmp ecx, 0                          ;if the lower list is finis we point at the rest of the upper one
        je lower_finish
        
        mov edx, dword[esi]                 ;moves the bytes of the data from both nodes
        mov bl, byte[edx]
        mov al, byte[ecx]

        OR al, bl
        mov byte[ecx], al                   ;calculate the bitwise or on both registers

        push esi
        call pop_element                    ;pops the element from the upper list
        add esp, 4
        
        mov edi, ecx                        ;edi hold the pointer for fixing lower_finish case
        mov ecx, dword[ecx + next]          ;advancing the lower list element
             
        jmp or_loop                         ;jump to the start of the loop
    lower_finish:
        cmp dword[esi], 0                   ;check if both of the lists had finished and jump to the finis if they did
        je end_or_loop                      
        mov edx, dword[esi]                 ;makes the lower list point at the rest of the upper list
        mov dword[edi + next], edx
        mov dword[esi],0

    end_or_loop:
    debug
    jmp myCalc

n_function:    
    cmp dword[operand_stack_counter],1  ;check if there are elements in the stack
    jl error_insuficcient
    
    get_pointer_of_first_element_to_edx
   ;esi wiil be the pointer to the temp list
    push edx    ;malloc put things in edx so we need to backup him
    push 4  
    call malloc     ;malloc 4 bytes for the temp list
    add esp, 4
    mov esi, eax        ;put the pointer to the new list in esi
    pop edx 
 
    mov ecx, 0 ;ecx will be the counter (0 < ecx < 256)
    ;pop elements, if we are at the last element need to check if the value>16
    loop_count:
        mov ebx,dword[edx]  ;ebx now is the pointer to first element
        mov ebx,dword[ebx+next] ;ebx now is the pointer to the next element
        cmp ebx, 0  
        je last_found   ;last element is a special case
        inc ecx
        cmp ecx, 0xFF   ;check if we got 255 characters so we need a new link
        jne less_then_255
        push ecx    ;ecx is the data to enter
        push esi    ;eax is the pointer to the list 
        call append_last
        add esp, 8
        mov ecx, 0  ;set the counter to 0
    less_then_255:  ;in this case the counter less then 255 so we can increase him
        inc ecx     
        push edx
        call pop_element    ;pop the element we count now and continue to the next
        add esp, 4
        jmp loop_count
    last_found:
        inc ecx        
        cmp ecx, 0xFF
        jne less_then2_255
        push ecx    ;ecx is the data to enter
        push esi    ;eax is the pointer to the list 
        call append_last
        add esp, 8
        mov ecx, 0  ;set the counter to 0
    less_then2_255:
        mov ebx,dword[edx]  ;ebx now is the pointer to first element
        movzx ebx,byte[ebx]  ;ebx now is the pointer to last element
        cmp ebx,16
        jl end_insert
        inc ecx
        push ecx    ;ecx is the data to enter
        push esi    ;eax is the pointer to the list 
        call append_last
        add esp, 8
        jmp pop_last
        end_insert: ;pop the last element
            push ecx    ;ecx is the data to enter
            push esi    ;eax is the pointer to the list 
            call append_last
            add esp, 8

        pop_last:
            push edx
            call pop_element
            add esp, 4
            mov eax,dword[esi]
            mov dword[edx], eax     ; put the templist instead of the old list
            inc dword[operand_stack_counter]

            push esi
            call free   ;free the temp list
            add esp,4

            debug
jmp myCalc

insert_number_to_stack:  
    mov ecx,dword[operand_stack_counter]    ;gets the number of values in the stack right now
    mov ebx,dword[operand_stack_size]
    cmp ecx, ebx    ; if (counter == stack_size) cannot insert a new number, error
    jge error_stack_over_flow

    mov edx, dword[operand_stack_start]  ;the current place in the stack
    imul ecx, 4
    add edx,ecx ;edx = edx + 4*ecx = next free location

    push edx
    call insert_to_link_list    ;insert_to_link_list insert the input buf into the next free location (edx)
    add esp, 4

    inc dword[operand_stack_counter]    ;inc the stack counter
    debug
    jmp myCalc

pop_function:
    mov ecx,dword[operand_stack_counter]    ;get the number of values in the stack right now
    cmp ecx,1
    jl error_insuficcient
    
    get_pointer_of_first_element_to_edx
    push edx
    call print_list
    add esp,4
    
    start_delete:
    ;check for stop the poping!!!!
        push edx
        call pop_element
        add esp, 4
        cmp dword[edx], 0
        jne start_delete
    jmp myCalc
    
dup_function:
    mov ecx,dword[operand_stack_counter]    ;gets the number of values in the stack right now
    mov ebx,dword[operand_stack_size]
    cmp ecx, ebx                            ;if (counter == stack_size) cannot insert a new number, error
    jge error_stack_over_flow

    cmp ecx, 1
    jl error_insuficcient 

    mov edx, dword[operand_stack_start]     ;the current place in the stack
    imul ecx, 4
    add edx,ecx                             ;edx = edx +4*ecx = next free location
    
    sub ecx, 4
    mov ebx, dword[operand_stack_start]
    add ecx, ebx                            ;ecx = the list to duplicate

    mov ecx, dword[ecx]
    dup_loop:
        cmp ecx, 0 
        je end_dup_loop

        movzx ebx,byte[ecx + data]
        push ebx
        push edx
        call append_last
        add esp, 8
        mov ecx, dword[ecx+next]
    jmp dup_loop
    end_dup_loop:
        inc dword[operand_stack_counter]
        debug
        jmp myCalc    
    
and_function:
    mov ebx,dword[operand_stack_size]       ;checks if there are enough arguments to use the or function
    cmp dword[operand_stack_counter], 2
    jl error_insuficcient 
    
    get_pointer_of_first_element_to_edx
    get_pointer_of_second_element_to_ecx
    
    mov esi,edx                             ; esi points at the start of the list
    mov ecx,[ecx]
    and_loop:
        cmp dword[esi], 0                   ;if the upper list is finish we stop the proccess
        je upper_finish
        cmp ecx, 0                          ;if the lower list is finis we point at the rest of the upper one
        je clean_zeros
        
        mov edx, dword[esi]                 ;moves the bytes of the data from both nodes
        mov bl, byte[edx]
        mov al, byte[ecx]

        AND al, bl
        mov byte[ecx], al                   ;calculate the bitwise or on both registers

        push esi
        call pop_element                    ;pops the element from the upper list
        add esp, 4
        
        mov edi, ecx                        ;edi hold the pointer for fixing lower_finish case
        mov ecx, dword[ecx + next]          ;advancing the lower list element
             
        jmp and_loop                         ;jump to the start of the loop
    upper_finish:
        cmp ecx, 0
        je clean_zeros
        push ecx
        call delete_list
        add esp, 4
        mov dword[edi + next], 0
        
    clean_zeros:
    push dword[esi]                         ;delete whats left from the upper list 
    call delete_list
    add esp, 4
    mov dword[esi], 0

    mov ecx,dword[operand_stack_counter]    ;gets the number of values in the stack right now
    dec ecx
    mov edx, dword[operand_stack_start]     ;the current place in the stack
    imul ecx, 4
    add edx,ecx                             ;edx = edx +4*ecx = the result list

    mov esi, dword[edx]                     ; running index in the result list
    mov edi, esi                            ;index saving the last digit different from zero

    clean_zeros_loop:
        mov esi, dword[esi + next]          ;advencing the running index to the next node in the list
        cmp esi, 0                          ;checks if we reached the end already
        je end_clean_zeros_loop
        movzx eax, byte[esi]                ;moving the data of the next node into eax reg
        cmp eax, 0                          ;checks if the data stored in the node diffrent from zero

        je step_over                        
        mov edi, esi                        ;if it is diffrent from zero we point edi at this locetion
        step_over:                          ;else we do nothing.
            jmp clean_zeros_loop
    end_clean_zeros_loop:
        cmp dword[edi + next], 0
        je end_and_func
        push dword[edi + next]
        call delete_list
        add esp, 4
        mov dword[edi + next], 0
    
    end_and_func:
    debug
    jmp myCalc

delete_list:
    push ebp 
    mov ebp, esp
    pushad

    mov eax, [ebp + 8]             ; move to eax the pointer argument (pointer to the rest of the list) 
    delete_loop:
        cmp eax, 0
        je end_delete_loop
        mov ebx, dword[eax + next]
        push ebx
        push eax
        call free
        add esp, 4
        pop ebx

        mov eax, ebx
        jmp delete_loop
    end_delete_loop:

    popad
    mov esp, ebp
    pop ebp
    ret

append_first:
    push ebp
    mov ebp, esp
    pushad

    push 5
    call malloc     ;reserve 5 bytes fot the next element
    add esp, 4

    mov bl, [ebp + 12]             ;move the data argument to ebx register
    mov [eax + data], bl           ;put the data in the new alocted struct

    mov ebx, [ebp + 8]             ; move to ebx the pointer argument (to the list) 
    mov ecx, dword[ebx]
    mov dword [eax + next], ecx       ;set the next pointer to the original first elemnt

    mov dword[ebx], eax ;set the first node the the new node

    popad
    mov esp, ebp
    pop ebp
    ret

append_last:
    push ebp                        ;save caller state
    mov ebp, esp                    ;leave space for local var on stack
    pushad

    push 5                        ;push the size of the struct to the malloc c function 
    call malloc                     ;pointer to the alocated memo in eax register
    add esp, 4

    mov bl, [ebp + 12]             ;move the data argument to ebx register
    mov [eax + data], bl           ;put the data in the new alocted struct
    mov dword [eax + next], 0       ;set the next pointer to null

    mov ebx, [ebp + 8]              ;move the address given(first element pointer) in the args to ebx register in order to iterate until the last element

    find_last_loop:                 ;loop until we ancounter the last element in the list
        mov edx, [ebx]              ;save the address of the last element  
        cmp edx, 0

        je last_element_found
        add edx, next
        mov ebx, edx      
        
        jmp find_last_loop
        
    last_element_found:
        mov dword [ebx], eax

        popad
        mov esp, ebp
        pop ebp
        ret

pop_element:
    push ebp
    mov ebp, esp
    pushad
    
    mov ebx, [ebp + 8]              ;address of address of the first element in the list
    mov eax, [ebx]                  ;address of the first element in the list
    cmp eax, 0                      ;check if the last element is null
    je return_result                ;if it does we are done!
    
    mov edx, dword[eax + next]           ;else we are not at the last element 
    mov [ebx], edx                  ;so we replace the address of the first element with is predeccor
    push eax
    call free                       ;we delete the old elemnt of the list
    add esp, 4

    return_result:
    popad
    mov esp, ebp
    pop ebp
    ret

print_list:
    push ebp    
    mov ebp, esp
    pushad

    push 0xFFF                              ;push symbol when stop poping
    mov eax, [ebp + 8]                      ;eax hold the pointer to the first element in the list
    push_values:
    mov eax, dword[eax]
    cmp eax,0                               ;check if we end the list
    je pop_first_value

    movzx ebx, byte[eax]                    ;ebx hold the data with leading zeros
    push ebx                                ;push the number to the stack
    add eax, next                           ;eax+1= go to the pointer in the struct   
    jmp push_values

    pop_first_value:
        pop eax                             ;pop one element into eax
        cmp eax , 0xFFF                     ;check if we poped all the values from the stack
        je end_pop 

        push eax
        push print_last_hexa_number         ;printing some number from the stack
        call printf
        add esp, 8

    ;print all the others digis
    pop_values:
    pop eax                                  ;pop one element into eax
    cmp eax , 0xFFF                          ;check if we poped all the values from the stack
    je end_pop      

    push eax
    push print_hexa_number                   ;print the last number in the stack
    call printf
    add esp, 8
    jmp pop_values
    
    end_pop:
    push new_line                            ;at the enf of the printing print \n
    call printf
    add esp,4

    popad
    mov esp,ebp
    pop ebp
    ret

stack_size_getter:
	movzx ebx, byte[edx]		;get the current char
	cmp ebx, 0				;check for string termination
	je return_stack_size_getter			;the conversion is done. return to main function
    cmp ebx, 10
    je return_stack_size_getter
 
    push eax
	push ebx
    call ascii_convertor
    add esp, 4
    mov ebx, eax
    pop eax

    sum:
        imul eax, 16			;multiple the edx by 16
        add eax, ebx

	inc edx					;increment the string pointer
	jmp stack_size_getter

    return_stack_size_getter:
        ret

;;operand stack functions
insert_to_link_list:
    push ebp    
    mov ebp, esp
    pushad
    
    ;first, we want to clean the leading zeros
    mov ecx, input_buf
    mov esi, 0   ;esi is the counter for the number of digits 
    mov edi, 0   ;helper pointer for count the buffer
    movzx edx,byte[ecx]
    cmp edx, 10
    je input_error
    clean_loop:
        movzx edx,byte[ecx]
        cmp edx, 10
        je case_for_0
        cmp edx , 48    ;check for the first char it isnt 0
        mov edi, ecx    ;set the pointer edi to the current ecx
        jne check_odd_or_even
        inc ecx         ;move to the next char
        jmp clean_loop
    
    check_odd_or_even:
        mov edx, 0
        movzx edx,byte[edi] ;get the current char in the buffer
        cmp edx, 0
        je end_count    ;finish counting in null
        cmp edx, 10
        je end_count    ;finish counting in \n
        inc esi         
        inc edi
        jmp check_odd_or_even

    end_count:
        test esi, 1 ;check if esi is odd\even
        jz loop_    ;if the number is even we dont need to fix him
        jmp add_zero_for_odd_numbers    ;if the number is odd we need to fix him

    case_for_0:
        mov ebx,0
        jmp insert_node
    add_zero_for_odd_numbers:
        mov edx,0
        mov ebx, 0
        movzx edx, byte[ecx]    ;store in edx the first digit in ascii of the input buf
        push edx 
        call ascii_convertor    ;this function get a number (hexa) as argument and return in eax the ascii value of the current char
        add esp, 4
        inc ecx                 ;move on to the next byte in the input buffer
        mov ebx, eax             ;move the first digit to ebx 
        jmp insert_node

    loop_:  
        mov ebx, 0                           ;ebx is the sum   
        movzx edx,    byte[ecx]           ;get the current char
        cmp edx,    10  ;check if the input buf end (\n)
        je end_loop
        cmp edx, 0  ;check if the input buf end (null termination)
        je end_loop

        push edx
        call ascii_convertor    ;this function get a number (hexa) as argument and return in eax the ascii value of the current char
        add esp, 4

        mov ebx, eax                    ;ebx is the sum
        inc ecx                         ;ecx is pointer to the input
        movzx edx,    byte[ecx]         ;get the next char and put to edx
        
        cmp edx,    10  ;check if the input buf end (\n)
        je insert_node
        cmp edx,    0   ;check if the input buf end (null termination)
        je insert_node

        push edx    ;edx hold the current char
        call ascii_convertor    ;this function get a number (hexa) as argument and return in eax the ascii value of the current char
        add esp, 4
        
        imul ebx, 16    ;adding of two hexa numbers
        add ebx, eax
        inc ecx ; move to the next byte in the input

        insert_node:
            push ebx    ;ebx is the data to enter
            mov eax,dword[ebp + 8]
            push eax    ;eax is the pointer to the list 
            call append_first
            add esp, 8
            jmp loop_

    end_loop:
    popad
    mov esp, ebp
    pop ebp
    ret
    

ascii_convertor:
    push ebp
    mov ebp, esp
    push ebx
    push ecx
    push edx
    mov eax, dword[ebp+8]

    cmp eax, 48 
	jl input_error            ;if the byte is less then 48(0) theres an input error
    
    cmp eax, 57
    jle dig_con         ;if its between 48(0) and 57(9) its a digit
    
    cmp eax, 65                 
    jl input_error            ;else if its less then 65(A) theres an input error   

    cmp eax, 70                 
    jg input_error            ;if it is higher then 70 (F) theres an input error

    sub eax, 7                ;else we reduce 7 so 'A' becomes  10
    
    dig_con:
	    sub eax, '0'				;convert ascii to digit
        
    pop edx
    pop ecx
    pop ebx
    mov esp, ebp
    pop ebp
    ret

input_error:
    push input_error_message
    call printf
    jmp myCalc
error_insuficcient:
    push error_insuficcient_message
    call printf
    add esp, 4
    jmp myCalc

error_stack_over_flow:
    push error_stack_overflow
    call printf
    add esp, 4
    jmp myCalc