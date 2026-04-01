import os
import json
import sys
import random

DB_FILE = 'database.json'

class Database:
    def __init__(self, file_path):
        self.file_path = file_path
        self.data = []
        self.load()

    def load(self):
        if os.path.exists(self.file_path):
            print("database found")
            with open(self.file_path, 'r', encoding='utf-8') as f:
                self.data = json.load(f)
        else:
            print("database not found. creating...")
            default_data = [{
                'id': 0,
                'user': 'Admin',
                'password': '1111',
                'money': 0.0
            }]
            self.data = default_data
            self.save()
            print('success!')

    def save(self):
        try:
            with open(self.file_path, 'w', encoding='utf-8') as f:
                json.dump(self.data, f, ensure_ascii=False, indent=4)
        except Exception as e:
            print(f'Failed to save database: {e}')
            
    def get_users(self):
        return self.data
        
    def get_user_by_id(self, user_id):
        for user in self.data:
            if user['id'] == user_id:
                return user
        return None

    def get_user_by_username(self, username):
        for user in self.data:
            if user['user'] == username:
                return user
        return None
        
    def add_user(self, username, password):
        new_id = max((user['id'] for user in self.data), default=-1) + 1
        new_user = {
            'id': new_id,
            'user': username,
            'password': password,
            'money': 0.0
        }
        self.data.append(new_user)
        self.save()
        return new_user

    def remove_user(self, user_id):
        for i, user in enumerate(self.data):
            if user['id'] == user_id:
                del self.data[i]
                self.save()
                return True
        return False
        
    def update_user(self, updated_user):
        for i, user in enumerate(self.data):
            if user['id'] == updated_user['id']:
                self.data[i] = updated_user
                self.save()
                return True
        return False

class BankingApp:
    def __init__(self, db: Database):
        self.db = db
        self.logged_in_user = None

    def help_auth(self):
        print('''command list: 
        login (username) (password)
        reg (username) (password) (reapeat password)
        exit''')

    def help_user(self):
        if self.logged_in_user and self.logged_in_user['user'] == 'Admin':
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

    def run(self):
        while True:
            if self.logged_in_user is None:
                self.help_auth()
            else:
                self.help_user()
                
            try:
                inp_str = input('>')
                inp = inp_str.split()
                if not inp:
                    continue
                cmd = inp[0].lower()
                args = inp[1:]
                
                if self.logged_in_user is None:
                    self.handle_auth_command(cmd, args)
                else:
                    self.handle_user_command(cmd, args)
            except EOFError:
                break
            except Exception as e:
                print(f"internal error: {e}")

    def handle_auth_command(self, cmd, args):
        if cmd == 'exit':
            sys.exit()
        elif cmd == 'reg':
            if len(args) != 3:
                print("command not found")
                return
            username, p1, p2 = args
            if self.db.get_user_by_username(username):
                print('username already taken')
                return
            if p1 != p2:
                print('passwords didnt match')
                return
                
            self.db.add_user(username, p1)
            print(f'user {username} was created')
            
        elif cmd == 'login':
            if len(args) != 2:
                print("command not found")
                return
            username, password = args
            user = self.db.get_user_by_username(username)
            if user and user['password'] == password:
                print(f'succesful login in {username}')
                self.logged_in_user = user
                self.db.load()
                self.logged_in_user = self.db.get_user_by_username(username)
            else:
                print('incorrect username or password')
        else:
            print('command not found')

    def handle_user_command(self, cmd, args):
        self.db.load()
        self.logged_in_user = self.db.get_user_by_id(self.logged_in_user['id'])
        
        # In case the user was deleted while logged in
        if not self.logged_in_user:
            self.logged_in_user = None
            print("session invalid")
            return

        is_admin = (self.logged_in_user['user'] == 'Admin')

        if cmd == 'exit':
            sys.exit()
        elif cmd == 'logout':
            self.logged_in_user = None
        elif cmd == 'info':
            print(f'''
Profile info:

    ID :        {self.logged_in_user['id']}
    USERNAME :  {self.logged_in_user['user']}
    MONEY :     {self.logged_in_user['money']}
''')
        elif cmd == 'chpass':
            if len(args) != 2:
                print("command not found")
                return
            old_pass, new_pass = args
            if self.logged_in_user['password'] == old_pass:
                self.logged_in_user['password'] = new_pass
                self.db.update_user(self.logged_in_user)
                print('password was changed')
            else:
                print('password incorrect')
        elif cmd == 'transfer':
            if len(args) != 2:
                print("command not found")
                return
            try:
                amount = float(args[0])
                target_id = int(args[1])
            except ValueError:
                print("internal error")
                return
                
            if amount <= self.logged_in_user['money']:
                target_user = self.db.get_user_by_id(target_id)
                if target_user:
                    self.logged_in_user['money'] = round(self.logged_in_user['money'] - amount, 2)
                    self.db.update_user(self.logged_in_user)
                    
                    target_user['money'] = round(target_user['money'] + amount, 2)
                    self.db.update_user(target_user)
                    
                    print(f"sucsessful transfer. balance remaining: {self.logged_in_user['money']}")
                else:
                    print('user is not exist')
            else:
                print('value bigger than your balance')
        elif cmd == 'gamble':
            if len(args) != 2:
                print("command not found")
                return
            try:
                bet = float(args[0])
                chance = int(args[1])
            except ValueError:
                print("internal error")
                return
                
            if bet <= self.logged_in_user['money']:
                if 0 < chance < 100:
                    self.logged_in_user['money'] -= bet
                    multiplier = round(100 / chance, 1)
                    roll = random.randint(0, int(multiplier * 10))
                    
                    if roll <= 10:
                        self.logged_in_user['money'] += (bet * multiplier)
                        self.logged_in_user['money'] = round(self.logged_in_user['money'], 2)
                        self.db.update_user(self.logged_in_user)
                        print(f"you win. balance: {self.logged_in_user['money']}")
                    else:
                        self.logged_in_user['money'] = round(self.logged_in_user['money'], 2)
                        self.db.update_user(self.logged_in_user)
                        print(f"you lose. balance: {self.logged_in_user['money']}")
                else:
                    print('invelid chance')
            else:
                print('value bigger than your balance')
                
        # Admin Commands
        elif is_admin and cmd == 'setmoney':
            if len(args) != 2:
                print("command not found")
                return
            try:
                amount = float(args[0])
                target_id = int(args[1])
            except ValueError:
                print("internal error")
                return
                
            target_user = self.db.get_user_by_id(target_id)
            if target_user:
                target_user['money'] = amount
                self.db.update_user(target_user)
                print('sucsessful set.')
            else:
                print('user does not exists')
                
        elif is_admin and cmd == 'addmoney':
            if len(args) != 2:
                print("command not found")
                return
            try:
                amount = float(args[0])
                target_id = int(args[1])
            except ValueError:
                print("internal error")
                return
                
            target_user = self.db.get_user_by_id(target_id)
            if target_user:
                target_user['money'] = round(target_user['money'] + amount, 2)
                self.db.update_user(target_user)
                print('sucsessful adds.')
            else:
                print('user does not exists')
                
        elif is_admin and cmd == 'rmuser':
            if len(args) != 1:
                print("command not found")
                return
            try:
                target_id = int(args[0])
            except ValueError:
                print("internal error")
                return
                
            if self.db.remove_user(target_id):
                print('sucsessful delete.')
            else:
                print('user does not exists')
                
        elif is_admin and cmd == 'getinfo':
            if len(args) != 1:
                print("command not found")
                return
            try:
                target_id = int(args[0])
            except ValueError:
                print("internal error")
                return
                
            target_user = self.db.get_user_by_id(target_id)
            if target_user:
                print(f'''
{target_user['user']} info:

    ID :        {target_user['id']}
    USERNAME :  {target_user['user']}
    MONEY :     {target_user['money']}
''')
            else:
                print('user does not exists')
                
        elif is_admin and cmd == 'getid':
            if len(args) != 1:
                print("command not found")
                return
            target_username = args[0]
            target_user = self.db.get_user_by_username(target_username)
            if target_user:
                print(f"{target_user['user']} id: {target_user['id']}")
            else:
                print('user does not exists')
                
        else:
            print('command not found')


if __name__ == '__main__':
    database = Database(DB_FILE)
    app = BankingApp(database)
    app.run()