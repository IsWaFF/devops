import os
import json
import random



file_name = 'database.json'
default_data = [
        {
        'id':0,
        'user':'Admin',
        'password':'1111',
        'money':0.0
        }
]

if os.path.exists(file_name):
    print("database found")
    with open(file_name, 'r', encoding='utf-8') as f:
        data = json.load(f)
else:
    print("database not found. creating...")
    with open(file_name, 'w', encoding='utf-8') as f:
        json.dump(default_data, f, ensure_ascii=False, indent=4)
        print('success!')

    data = default_data

while True:
    print('''command list: 
        login (username) (password)
        reg (username) (password) (reapeat password)
        exit''')
    stage = 0

    while stage == 0:
        er = 0
        inp = (input('>'))
        inp = inp.split()
        if inp[0] == 'reg' and len(inp) == 4:
            for user in data:
                if user['user'] == inp[1]:
                    print('username already taken')
                    er = 1
            if er == 0:
                username = inp[1]
                if inp[2] == inp[3]:
                    password = inp[2]
                else:
                    er = 1
                    print('passwords didnt match')
            if er == 0:
                last_user = data[len(data)-1]
                stage = 0
                block = {
                'id':int(last_user['id'])+1,
                'user':username,
                'password':password,
                'money':0.0
                }
                data.append(block)
                try:
                    with open('database.json', 'w', encoding='utf-8') as f:
                        json.dump(data, f, ensure_ascii=False, indent=4)
                    print(f'user {username} was created') 
                except:
                    print('reg falied')
            else:
                print('internal error')

        elif inp[0]== 'login' and len(inp)==3:
            for user in data:
                if user['user'] == inp[1]:
                    if user['password']==inp[2]:
                        print(f'succesful login in {inp[1]}')
                        username = inp[1]
                        stage = 1
            if stage != 1:
                print('incorrect username or password')
        elif inp[0]== 'exit' and len(inp)==1:
            exit()
        else:
            print('command not found')



    if username == 'Admin':
        print('''command list: 
        info
        getid (username)
        getinfo (userid)
        rmuser (userid)
        addmoney (amount) (userid)
        setmoney (amount) (userid)
        transfer (amount) (userid)
        gamble (amount) (chance%)
        chpass (old password) (new password)
        logout''')
    else:
        print('''command list: 
        info
        transfer (amount) (userid)
        gamble (amount) (chance%)
        chpass (old password) (new password)
        logout''')


    profileid = 0
    for user in data:
        if user['user'] == username:
            break
        else:
            profileid += 1

    while stage ==1:
        fount = None
        probeid = 0
        valid = None
        profile = data[profileid]
        with open(file_name, 'r', encoding='utf-8') as f:
            data = json.load(f)
            profile = data[profileid]
            
        inp = (input('>'))
        inp = inp.split()
        if inp[0] == 'info' and len(inp) == 1:
            with open(file_name, 'r', encoding='utf-8') as f:
                data = json.load(f)
                profile = data[profileid]
            
            print(f'''Profile info:

                ID :        {profile['id']}
                USERNAME :  {profile['user']}
                MONEY :     {profile['money']}
                ''')
        elif inp[0] == 'exit' and len(inp) == 1:
            exit()
        elif inp[0] == 'logout' and len(inp) == 1:
            stage = 0
        elif inp[0] == 'chpass' and len(inp) == 3:
            with open(file_name, 'r', encoding='utf-8') as f:
                data = json.load(f)
                profile = data[profileid]
            
            if inp[1] == profile['password']:
                profile['password'] = inp[2]
                try:
                    data[profileid] = profile
                    with open('database.json', 'w', encoding='utf-8') as f:
                        json.dump(data, f, ensure_ascii=False, indent=4)
                    print(f'password was changed') 
                except:
                    print('failed to change password')
            else:
                print('password incorrect')
        elif inp[0] == 'transfer' and len(inp) == 3:
            with open(file_name, 'r', encoding='utf-8') as f:
                data = json.load(f)
                profile = data[profileid]
            
            if float(inp[1])<=profile['money']:
                for user in data:
                    if user['id'] == int(inp[2]):
                        fount = True
                        valid = True
                    else:
                        if fount != True:
                            probeid += 1
                        None
                if valid == True:
                    profile['money']=round(profile['money']-float(inp[1]),2)
                    tr_profile = data[probeid]
                    tr_profile['money'] = round(tr_profile['money'] + float(inp[1]),2)
                    try:
                        data[probeid] = tr_profile
                        with open('database.json', 'w', encoding='utf-8') as f:
                            json.dump(data, f, ensure_ascii=False, indent=4)
                        print(f'sucsessful transfer. balance remaining: {profile['money']}') 
                    except:
                        print('internal error')
                else:
                    print('user is not exist')
            else:
                print('value bigger than your balance')
        elif inp[0] == 'gamble' and len(inp) == 3:
            result = None
            with open(file_name, 'r', encoding='utf-8') as f:
                data = json.load(f)
                profile = data[profileid]
            if float(inp[1])<=profile['money']:
                bet = float(inp[1])
                if int(inp[2])>0 and int(inp[2])<100:
                    profile['money'] = profile['money'] - bet
                    chance = int(inp[2])
                    multiplier = round(100/chance,1)
                    roll = random.randint(0,int(multiplier*10))
                    if roll <= 10:
                        result = True
                    else:
                        result = False

                    if result == True:
                        profile['money'] = profile['money'] + (bet*multiplier)
                        try:
                            data[profileid] = profile
                            with open('database.json', 'w', encoding='utf-8') as f:
                                json.dump(data, f, ensure_ascii=False, indent=4)
                            print(f'you win. balance: {profile['money']}') 
                        except:
                            print('internal error')
                    else:
                        try:
                            data[profileid] = profile
                            with open('database.json', 'w', encoding='utf-8') as f:
                                json.dump(data, f, ensure_ascii=False, indent=4)
                            print(f'you lose. balance: {profile['money']}') 
                        except:
                            print('internal error')
                else:
                    print('invelid chance')
            else:
                print('value bigger than your balance')
        else:
            print('command not found')