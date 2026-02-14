import re

with open('log1.txt', 'r')as file:
    for line in file:
        print(re.findall(r'\d+\.\d+\.\d+\.\d+', line))