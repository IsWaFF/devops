def kel(deg):
    try:
        deg = float(deg)
    except:
        return('value error')
    answer = deg+273
    if answer <= 0:
        return('unreal')
    else:
        return(answer)

celsius = input('Enter cel:')

print(kel(celsius))