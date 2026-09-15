#!/bin/bash

template=$(cat data/file0.txt)

files=$(ls data)

for file in $files; do

        text=$(cat data/$file)

        if [ "$text" != "$template" ]; then

                echo "$file"

                imposter="$file"

        fi

done

badtext=$(cat data/$imposter)

for iword in $badtext; do


    match=0


    for tword in $template; do

    

    if [ "$tword" == "$iword" ]; then


        ((match++))

    fi

    

    done


if [ $match == 0 ]; then


    echo "$iword"


fi


    

    


done
