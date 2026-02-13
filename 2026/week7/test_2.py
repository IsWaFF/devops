
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

temps = ["20", "25", "hot", "30", "-300"]

