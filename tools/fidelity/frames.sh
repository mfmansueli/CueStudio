#!/bin/zsh
# usage: frames.sh <name> <screen.html> "<t1 t2 ...>" <freeze launch argument> <launch args...>
# Renders the board frozen at each t, captures the app with `<freeze argument> t` (for example -uiTestChapterAt), and writes
# $FIDELITY_OUT/cmp/<name>.png: the board on top, the app under it. WAIT (default 14 s) is how long the app takes to reach the screen.
HERE=${0:A:h}
OUT=${FIDELITY_OUT:-/tmp/cue-fidelity}
NAME=$1; HTML=$2; TIMES=(${=3}); FREEZE=$4; shift 4
mkdir -p $OUT/cmp/$NAME
for t in $TIMES; do $HERE/htmlframe.py $HTML $t $OUT/cmp/$NAME/h_$t.png & done; wait
for t in $TIMES; do $HERE/appshot.sh $OUT/cmp/$NAME/a_$t.png ${WAIT:-14} "$@" $FREEZE $(python3 -c "print(round($t-${OFFSET:-0},3))"); done
ARGS=(); for t in $TIMES; do ARGS+=($OUT/cmp/$NAME/h_$t.png $OUT/cmp/$NAME/a_$t.png); done
python3 $HERE/cmp.py $OUT/cmp/$NAME.png $ARGS
echo $OUT/cmp/$NAME.png
