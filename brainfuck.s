.text
arg_error:      .asciz "USAGE: brainfuck <filename>\n"
dbgstr: .asciz "%d\n"

.global main
main:
        #Set up the stack
        movq %rsp, %rbp

        cmpq $2, %rdi           #Check if there is a single arg
        jne wrong_args          #If not, fail

        #Read the brainfuck file into memory
        movq 8(%rsi), %rdi
        call read_file

        #Pass the address and length of the read file to compile_brainfuck
        movq %rax, %rdi
        movq %rdx, %rsi
        call compile_brainfuck

        #Marks page with brainfuck machine code to read/execute only
        pushq %rax

        #Allocate a heap for the brainfuck function
        movq $32768, %rdi
        call malloc

        #Pass the address of the heap to the brainfuck function and call it
        movq %rax, %rdi
        popq %r10
call_code:
        call *%r10

        movq $0, %rdi
        call exit

wrong_args:
        movq $arg_error, %rdi
        movq $0, %rax
        call printf
        mov $0, %rax
        call exit

## r12: Source address
## r13: Source index
## r14: Target address
## r15: Various temporary things
##
## Returns pointer to function that takes one param:
##      rdi: base address of brainfuck heap
## and uses the following registers:
## r12: Heap address
## r13: Heap index
## r14: Temporary address pointer for loops
compile_brainfuck:
        #Set up the function stack
        pushq %rbp
        movq %rsp, %rbp
        #Store temporary registers that need to be restored
        pushq %r15
        pushq %r12
        pushq %r13
        pushq %r14

        movq %rdi, %r12         #Set up the source address
        movq $0, %r13           #Set up the source index

        ##Allocate a block of memory to emit code to
        movq $0, %rdi
        shl $4, %rsi            #Allocate 8 bytes per character for instructions
        movq $3, %rdx         #PROT_READ | PROT_WRITE
        movq $0x22, %rcx
        movq $-1, %r8
        movq $0, %r9
        call mmap               #Actually allocate it

        movq %rax, %r14         #Set up the target address
        pushq %r14
bf_emit_prelude:                #Emits the function prelude
        movq $-443987883 , (%r14) #pushq %rbp - movq %rsp, %rbp
        addq $4, %r14
        movq $0x55415441, (%r14) #pushq %r12 - pushq %r13
        addq $4, %r14
        movq $0xfc8949, (%r14)  #movq %rdi, %r12
        addq $3, %r14
        movq $0xbd49, (%r14)    #movq $0, %r13
        addq $10, %r14
bf_parse_loop:                  #Parses the brainfuck source
        movb (%r12, %r13), %dil #Load the next source character
bf_parse_loop_switch:
        cmpb $0, %dil           #If it is a zero byte, parsing is done
        je bf_parse_end              #Start execution
        cmpb $46, %dil          #Print character (.)
        je bf_put_char
        cmpb $44, %dil          #Get character (,)
        je bf_get_char
        cmpb $43, %dil          #Increase value at address (+)
        je bf_incr_val
        cmpb $45, %dil          #Decrease value at address (-)
        je bf_decr_val
        cmpb $91, %dil          #Set up looping point ([)
        je bf_loop_begin
        cmpb $93, %dil          #Jump back to looping point (])
        je bf_loop_end
        cmpb $60, %dil          #Decrease address pointer (<)
        je bf_prev_addr
        cmpb $62, %dil          #Increase address pointer (>)
        je bf_next_addr
        #If character is not valid brainfuck, ignore it
        incq %r13
        jmp bf_parse_loop

bf_put_char:
        movq $0x2C3C8D43, (%r14) #leaq (%12, %13, 1), %rdi
        addq $4, %r14
        movq $0xBA49, (%r14)    #movq $my_putchar, %r10
        addq $2, %r14
        movq $my_putchar, (%r14)
        addq $8, %r14
        movq $0xD2FF41, (%r14)      #call *%r10
        addq $3, %r14
        incq %r13
        jmp bf_parse_loop
bf_get_char:
        movq $0x2C3C8D43, (%r14) #leaq (%12, %13, 1), %rdi
        addq $4, %r14
        movq $0xBA49, (%r14)    #movq $my_getchar, %r10
        addq $2, %r14
        movq $my_getchar, (%r14)
        addq $8, %r14
        movq $0xD2FF41, (%r14)  #call *%r10
        addq $3, %r14
        incq %r13
        jmp bf_parse_loop

bf_incr_val:
        movb $1, %r15b           #Start the counter off with +1 if a + was issued first
        jmp bf_incrdecr
bf_decr_val:
        movb $-1, %r15b          #Start the counter off with -1 if a - was issued first
bf_incrdecr:                   #Note: incr/decr have their own optimizing subloop
        incq %r13               #Increase the source index
        movb (%r12, %r13), %dil #Fetch the next instruction
        cmpb $43, %dil
        jne bf_not_incr         #If it's not +, skip this step
        incb %r15b               #Increase the counter
        jmp bf_incrdecr         #Next iteration
bf_not_incr:
        cmpb $45, %dil          #If it's not -, stop the incrdecr loop
        jne bf_incrdecr_end
        decb %r15b               #Decrease the counter
        jmp bf_incrdecr         #Next iteration
bf_incrdecr_end:
        cmpb $0, %r15b
        je bf_parse_loop_switch #If it adds up to 0 do nothing
        movq $0x2c048043, (%r14) #addb ${%r15b}, (%r12, %r13, 1)
        addq $4, %r14
        movb %r15b, (%r14)      #Actual immediate value for previous instruction
        incq %r14
        jmp bf_parse_loop_switch #Parse the next command

bf_loop_begin:
bf_zero_pattern:
        #If -] follows the [, that means the current cell must be zeroed
        cmpw $0x5d2d, 1(%r12, %r13, 1)
        jne bf_zero_pattern_end
bf_yes:
        movq $0x002c04c643, (%r14) #movq $0, (%r12, %r13, 1)
        addq $5, %r14
        addq $3, %r13
        jmp bf_parse_loop
bf_zero_pattern_end:
        pushq %r14
        movq $0x2C3C8043, (%r14) #cmpb $0, (%r12, %r13, 1)
        addq $5, %r14
        movq $0x840f, (%r14)    #je end
        addq $6, %r14

        incq %r13
        jmp bf_parse_loop
bf_loop_end:
        movq $0x2c3c8043, (%r14) #cmpb $0, (%r12, %r13, 1)
        addq $5, %r14
        movq $0x850f, (%r14)    #jne begin
        addq $2, %r14

        popq %r15               #Pop address of loop begin
        movq %r14, %rax
        subq %r15, %rax         #Calculate offset for jump
        subq $7, %rax
        mov  %eax, 7(%r15)      #Write offset to instruction location
        negq %rax               #Negate to jump backwards
        mov  %eax, (%r14)       #Write offset to other instruction location
        addq $4, %r14
        incq %r13
        jmp bf_parse_loop

bf_prev_addr:
        movq $-1, %r15          #If previous address (<), start counter off with -1
        jmp bf_prevnext
bf_next_addr:
        movq $1, %r15           #If next address (>), start counter off with 1
bf_prevnext:
        incq %r13               #Increase source index
        movb (%r12, %r13, 1), %dil #Fetch the next instruction
        cmpb $60, %dil          #If not <, do something else
        jne bf_not_prev
        decq %r15               #Decrease jump distance
        jmp bf_prevnext
bf_not_prev:
        cmpb $62, %dil          #If not >, break out of loop
        jne bf_prevnext_end
        incq %r15               #Increase jump distance
        jmp bf_prevnext
bf_prevnext_end:
        cmpq $0, %r15
        je bf_parse_loop_switch         #If it adds up to 0, do nothing
        movq $0xc58149, (%r14)            #addq ${%r15}, %r13
        addq $3, %r14
        movq %r15, (%r14)               #Write actual immediate value
        addq $4, %r14
        jmp bf_parse_loop_switch

bf_parse_end:
        movq $0x5c415d41, (%r14) #popq %r13 - popq %r12
        addq $4, %r14
        movq $0x5de58b48, (%r14) #movq %rbp, %rsp - popq %rbp
        addq $4, %r14
        movq $0xc3, (%r14)       #ret
        addq $1, %r14
        popq %r15               #Pop the address of the generated function

        movq %r14, %rdx         #Move the current instruction pointer in the function
        subq %r15, %rdx         #Calculate function length as second return value

        #Make memory with brainfuck function executable, not writable
        pushq %rdx
        movq %r15, %rdi
        movq %rdx, %rsi
        movq $5, %rdx           #PROT_READ | PROT_EXEC
        call mprotect
        popq %rdx

        #Restore temporary registers
        popq %r14
        popq %r13
        popq %r12
        #Move the first return value to the right register
        movq %r15, %rax
        popq %r15
        #Pop the stack pointer
        movq %rbp, %rsp
        popq %rbp
        ret

#Calls the SYS_READ syscall to read a single byte from STDIN
my_getchar:
        movq $1, %rdx           #read length
        movq %rdi, %rsi         #read buffer
        movq $0, %rax           #syscall no. (SYS_READ)
        movq $0, %rdi           #file no. (STDIN)
        syscall
        ret

#Calls the SYS_WRITE syscall to write a single byte to STDOUT
my_putchar:
        movq $1, %rdx           #write length
        movq %rdi, %rsi         #write buffer
        movq $1, %rax           #syscall no. (SYS_WRITE)
        movq $1, %rdi           #file no. (STDOUT)
        syscall
        ret

#Reads the file from the passed filename into memory
#and returns the address it was read into
read_file:
        #Set up stack
        pushq %rbp
        movq %rsp, %rbp
        #Save registers that need to be restored
        pushq %r12
        pushq %r13

        #Call SYS_OPEN syscall with flag O_RDONLY (filename already in %rdi)
        movq $2, %rax
        movq $0, %rsi
        syscall

        pushq %rax              #Store file descriptor for later use
        movq $64, %rdi
        call malloc             #Allocate a 64 byte buffer for file stats
        popq %rdi               #Load the file descriptor into rdi
        pushq %rdi              #Store it again for later use
        pushq %rax              #Store the address of file stats for later use
        #Call SYS_FSTAT syscall with file descriptor (%rdi) and buffer (%rsi)
        movq %rax, %rsi
        movq $5, %rax
        syscall

        popq %rax               #Load address of file stats
        movq 48(%rax), %rdi     #Get the file length from the stats
        pushq %rdi              #Store file length for later use
        addq $1, %rdi           #Increase by one for zero byte
        call malloc             #Allocate file size as buffer
        popq %rdx               #Load file length into register
        movb $0, (%rax, %rdx, 1) #Use it to write a zero byte at the last position

        popq %rdi               #Load the file descriptor again
        movq %rdx, %r13         #Store the file length for later use
        #Call SYS_READ syscall with file descriptor (%rdi) and buffer (%rsi)
        movq %rax, %rsi
        movq %rsi, %r12
        movq $0, %rax
        pushq %r13
        syscall

        popq %rdx               #Load file length as second return value
        movq %r12, %rax         #Load file pointer as first return value
        #Restore used registers
        popq %r13
        popq %r12
        #Restore stack
        movq %rbp, %rsp
        popq %rbp
        ret
