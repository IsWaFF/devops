def kel(deg):
    try:
        deg = float(deg)
    except:
        return(ValueError)
    answer = deg+273
    if answer <= 0:
        return(ValueError)
    else:
        return(answer)
