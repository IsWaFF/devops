#!/bin/bash
filename="$2"
filetext="$3"
if [ "$1" = "new" ]; then
  touch "$filename"
  echo "$filetext" > "$filename"
elif [ "$1" = "append" ]; then
  echo "$filetext" >> "$filename"
else
  echo "error"
fi
echo "success"