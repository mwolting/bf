all: ./brainfuck

./brainfuck: ./brainfuck.s
	gcc -no-pie $< -o $@
