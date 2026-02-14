#!/bin/bash
while true; do
    DATE=$(date '+%Y-%m-%d %H:%M:%S')
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/,/./') # Меняем запятую на точку для Python
    MEM=$(free -m | awk '/Mem:/ {print $3}')
    
    echo "$DATE | CPU: $CPU% | MEM: ${MEM}MB" >> system_monitor.log
    echo "Записана точка: $DATE | CPU: $CPU%" 
    
    sleep 2
done