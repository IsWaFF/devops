#!/bin/bash
# ==============================================================================
# BASH SKILL TEST - LEVEL 2: LOOPS, FUNCTIONS & TEXT PROCESSING
# ==============================================================================
# Complete these 3 tasks step-by-step in this file!
#
# TASK 1: while loop + arithmetic
# ------------------------------------------------------------------------------
# Write a while loop that counts from 1 to 10.
# Print each number. When the number is divisible by 3, also print "Fizz".
# When divisible by 5 - print "Buzz". When both - print "FizzBuzz".
# Example output:
#   #   2
#   3 Fizz
#   4
#   5 Buzz
#   ...
#   15 FizzBuzz
#
# TASK 2: for loop over files
# ------------------------------------------------------------------------------
# Use a for loop to iterate over all *.sh files in the current directory.
# For each file, print:
#   "Script: <filename>  |  Lines: <number of lines>"
# Hint: use wc -l to count lines.
#
# TASK 3: Functions
# ------------------------------------------------------------------------------
# Write a function called "greet" that:
#   - Takes one argument (a name)
#   - Prints "Hello, <name>! Today is <YYYY-MM-DD>."
# Then call the function 3 times with different names.
# ==============================================================================

# Write your code below:

# 3 tsk

function greet ()
{
    echo "Hello, $1 ! Today is $(date +%Y-%m-%d)"
}
greet mark
greet daniel
greet vlad



#2 tsk

# scend=0
# files=$(ls -a | grep ".*\.sh$")
# for file in $files; do
#     lns=$(wc -l < $file)
#     echo "Script: $file  |  Lines: $lns"
# done


# 1tsk

# count=0
# while [[ $count -lt 15 ]]
# do
# (( count++ ))
# if (( $count % 5 == 0 )) && (( $count % 3 == 0 )); then
#     echo "$count FizzBuzz"
# elif (( $count % 5 == 0 )); then
#     echo "$count Buzz"
# elif (( $count % 3 == 0 )); then
#     echo "$count Fizz"
# else
#     echo "$count"
# fi
# done
