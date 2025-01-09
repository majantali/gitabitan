#!/usr/bin/env bash

for f in midi/*.mid;
do
    MIDIFILE=`basename $f`
    echo $f;
    timidity -A90 -Ov -o ogg/${MIDIFILE/.mid/.ogg} $f
done
	 
