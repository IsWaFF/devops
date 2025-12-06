#!/bin/bash
echo "today" `date`

echo -e "\n enter dir path:"
read path_to

echo -e "\n your dir contains:"
ls $path_to
