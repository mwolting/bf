#!/usr/bin/env bash
# Checks the buffered writer against a built binary: ./tests/output.sh ./brainfuck
# Linux x86-64 only, like the compiler itself.
set -u

bf=$(realpath "${1:-./brainfuck}")
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cd "$dir" || exit 1
failed=0

check() { # name, status (0 is a pass)
    if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; failed=1; fi
}

repeat() { # string, count
    printf "$1%.0s" $(seq "$2")
}

# One +. pair prints the next value of a cycle through all 256 byte values.
for i in $(seq 1 255) 0; do printf "\\$(printf %03o "$i")"; done > cycle
for i in $(seq 1100); do cat cycle; done > expected

# Sizes around the 64KiB buffer, to catch lost, repeated or reordered bytes.
for n in 1 65535 65536 65537 131072 262145; do
    repeat '+.' "$n" > prog.bf
    "$bf" prog.bf > out
    status=$?
    head -c "$n" expected | cmp -s - out
    check "prints $n bytes in order" $((status + $?))
done

# Programs made almost entirely of . have to fit the generated code buffer.
for n in 254 5000; do
    repeat '.' "$n" > prog.bf
    [ "$("$bf" prog.bf | wc -c)" -eq "$n" ]
    check "program of $n dots" $?
done

# Output before a , has to be visible while the read is still blocked.
printf '+.,.' > prog.bf
mkfifo stdin
exec 3<>stdin
"$bf" prog.bf < stdin > out &
pid=$!
sleep 1
printf '\001' | cmp -s - out
check "prompt is written before the read" $?
printf 'x' >&3
wait "$pid"
printf '\001x' | cmp -s - out
check "output after the read" $?
exec 3>&-

# Hitting the file size limit gives a short write, then a failing one. The bytes
# that fit have to arrive, and the failure can't hang or kill the program.
repeat '+.' 4096 > prog.bf
(
    trap '' XFSZ
    ulimit -f 1
    "$bf" prog.bf > out
)
status=$?
head -c 1024 expected | cmp -s - out
check "short and failed writes" $((status + $?))

exit "$failed"
