#!/bin/sh
# Checks copy/multiply loop elimination against known cell values.
# Each case prints cells with "." and compares the bytes (as hex) it outputs.
# Usage: tests/copy_loops.sh [path/to/brainfuck]

bf=${1:-./brainfuck}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

check() {
        name=$1
        program=$2
        expected=$3
        printf '%s' "$program" > "$tmp/case.bf"
        actual=$("$bf" "$tmp/case.bf" | od -An -tx1 | tr -s ' \n' ' ' | sed 's/^ //; s/ $//')
        if [ "$actual" = "$expected" ]; then
                echo "ok   $name"
        else
                echo "FAIL $name: expected '$expected', got '$actual'"
                failures=$((failures + 1))
        fi
}

# Loops that match the pattern
check "copy right" "+++++[->+<].>." "00 05"
check "copy left" ">>>>+++++[-<<<<+>>>>].<<<<." "00 05"
check "decrement after move" "+++++[>+<-].>." "00 05"
check "far offset" "+++[->>>>>>>>>+<<<<<<<<<]>>>>>>>>>." "03"
check "zero source" ">+++<[->++<].>." "00 03"
check "multiply" "+++>+<[->+++<]>." "0a"
check "negative delta" "+++>++++++++++<[->--<]>." "04"
check "subtract left" ">>>+++[-<<<->>>]<<<." "fd"
check "wrapping" "--------[->+++<]>." "e8"
check "several targets" "++++[->+>--<<+++>>>+++++<<<---]>.>.>." "04 f8 14"
check "same offset twice" "+++[->++<>+<]>." "09"
check "comments in body" "+++[-copy>+<]>." "03"
check "start cell touched twice" ">>>>>>++++<++++++++++>[<->-<<<<<<+>>>>>>]<<<<<<.>>>>>.>." "04 06 00"
check "continues after loop" "++[->+<]>[->+<]>+." "03"
start255=$(printf '%255s' '' | tr ' ' '+')
check "start cell net -1 via wrap" "++[$start255>+<]>." "02"

# Loops that must fall back to normal loop code
check "start decremented by 2" "++++[-->+<]>." "02"
check "start incremented" "++++++++[+>+<]>." "f8"
check "contains output" "++[->+.<]>." "01 02 02"
check "nested loop" "++[->+++<[-]].>." "00 03"
check "unbalanced pointer" ">+>+>+[-<]>.>.>." "00 00 00"

if [ "$failures" -ne 0 ]; then
        echo "$failures failure(s)"
        exit 1
fi
echo "all passed"
