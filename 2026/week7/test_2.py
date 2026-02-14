from func import kel

temps = ["20", "25", "hot", "30", "-300"]

proceed_temps = [kel(temp) for temp in temps]

result = []

for item in proceed_temps:
    if isinstance(item, float):
        result.append(item)

for tem in result:
    print(tem)
