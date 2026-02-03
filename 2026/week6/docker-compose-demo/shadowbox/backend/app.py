import os
import uuid
import psycopg2
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Настройки БД
DB_NAME = os.getenv('POSTGRES_DB', 'shadow_db')
DB_USER = os.getenv('POSTGRES_USER', 'postgres')
DB_PASS = os.getenv('POSTGRES_PASSWORD', 'secret')
DB_HOST = os.getenv('DB_HOST', 'db')

def get_db_connection():
    return psycopg2.connect(host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASS)

def init_db():
    conn = get_db_connection()
    cur = conn.cursor()
    # Таблица секретов
    cur.execute('''
        CREATE TABLE IF NOT EXISTS secrets (
            id VARCHAR(100) PRIMARY KEY,
            message TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    ''')
    conn.commit()
    cur.close()
    conn.close()

try:
    init_db()
except:
    pass # В реальном Docker это обработаем правильнее, пока заглушка

@app.route('/create', methods=['POST'])
def create_secret():
    data = request.json
    secret_id = str(uuid.uuid4())[:8] # Генерируем короткий ID (напр. a1b2c3d4)
    
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('INSERT INTO secrets (id, message) VALUES (%s, %s)', (secret_id, data['text']))
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({'id': secret_id})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/read/<secret_id>', methods=['GET'])
def read_secret(secret_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        # 1. Сначала читаем сообщение
        cur.execute('SELECT message FROM secrets WHERE id = %s', (secret_id,))
        result = cur.fetchone()
        
        if result:
            message = result[0]
            # 2. И СРАЗУ УДАЛЯЕМ ЕГО (Burn after reading)
            cur.execute('DELETE FROM secrets WHERE id = %s', (secret_id,))
            conn.commit()
            response = {'message': message, 'status': 'destroyed'}
        else:
            response = {'error': 'Сообщение не найдено или уже уничтожено'}
            
        cur.close()
        conn.close()
        return jsonify(response)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)