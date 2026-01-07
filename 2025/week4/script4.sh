!/bin/bash
path=$1
output=ls $path
errcode=$?
if [ $errcode -eq 0 ]; then
 echo $output > ok.txt
 echo "ok"
elif [ $errcode -ne 0 ]; then
 echo $output 2> err.txt
 echo "err"
else
  echo $?
fi
