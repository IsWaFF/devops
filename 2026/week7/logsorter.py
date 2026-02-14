import re
import matplotlib.pyplot as plt

timestamps = []
cpu_values = []

with open('system_monitor.log', 'r') as f:
    for line in f:
        time_match = re.search(r'\d{2}:\d{2}:\d{2}', line)
        cpu_match = re.search(r'CPU:\s*([\d.]+)', line)
        
        if time_match and cpu_match:
            timestamps.append(time_match.group())
            cpu_values.append(float(cpu_match.group(1)))


plt.figure(figsize=(10, 5))
plt.plot(timestamps, cpu_values, label='CPU Usage %', color='cyan', linewidth=2)
plt.fill_between(timestamps, cpu_values, color='cyan', alpha=0.2)
step = max(1, len(timestamps) // 10) 
plt.xticks(range(0, len(timestamps), step), timestamps[::step], rotation=45)

plt.title('System Monitor: CPU Load (Garuda Linux)')
plt.ylabel('Usage %')
plt.grid(True, linestyle='--', alpha=0.6)
plt.tight_layout()
plt.show()