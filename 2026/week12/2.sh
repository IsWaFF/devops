#!/bin/bash
# ==============================================================================
# BASH SKILL TEST - LEVEL 1: WARM-UP
# ==============================================================================
# Complete these 3 short tasks step-by-step in this file!
#
# TASK 1: Variables & Formatting
# ------------------------------------------------------------------------------
# Create variables for:
# - current user (using $(whoami) or $USER)
# - current date in YYYY-MM-DD format (using $(date ...))
# Print: "Running check for user [USER] on [DATE]"
#
# TASK 2: Conditionals & Arguments ($1)
# ------------------------------------------------------------------------------
# Check if a filename was provided as the first positional argument ($1).
# - If no argument is provided: print "Error: "No file specified! and exit with status 1.
# - If the file specified in $1 does NOT exist: print "Error: File '$1' not found!" and exit with status 1.
# - If the file EXISTS: print "File '$1' found!"
#
# TASK 3: Simple Log Counting (grep / wc)
# ------------------------------------------------------------------------------
# Count how many lines in $1 contain the word "ERROR".
# Print: "Number of ERROR entries in $1: [COUNT]"
# ==============================================================================

# Write your code below:

crtuser="$USER"
cdate=$(date +%Y-%m-%d)
echo "running check for user $crtuser on $cdate"

if [ -z "$1" ]
then
    echo "Error: No file specified!"
else
if ! [ -f "$1" ]
then
    echo "Error: File '$1' not found!"
    
    else
        echo "File '$1' found!"
        cerror=0
        for line in $(cat $1 | grep ERROR)
        do
            cerror=$(( cerror + 1 ))
        done
        echo "Number of ERROR entries in $1: $cerror"
    fi
    fi
