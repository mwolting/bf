# brainfuck
This is a Brainfuck interpreter/compiler hybrid, written in x64 assembly.
It assumes Unix syscalls to be available (SYS_READ, SYS_WRITE), as well as
some C library functions.

I wrote this code in a week's time in 2014 for a Computer Organization class.
The code is fairly densely commented, and is therefore fairly understandable.

## Operating principle
The interpreter operates by compiling valid Brainfuck files (passed in as a
command line arg) into its x64 machine code equivalent, after some straight-forward
optimizations have been carried out. The in-memory buffer the machine code was
written to is then made executable, and called into.

## Optimizations
Standard optimizations, such as packing together addition and pointer increment/decrement
operations, are carried out during compilation. Additionally, loop constructs are reduced
to statically addressed jumps.
More complex optimizations have not been implemented, mostly because doing so in assembly
would have been a time-consuming process.
