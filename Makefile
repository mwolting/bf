all: ./brainfuck

./brainfuck: ./brainfuck.s
	gcc $< -o $@
