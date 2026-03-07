import os
import psycopg2
from flask import Flask, request, jsonify

app = Flask(__name__)

# DevOps база: забираем настройки БД из переменных окружения
DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_NAME = os.environ.get("DB_NAME", "postgres")
DB_USER = os.environ.get("DB_USER", "postgres")
DB_PASS = os.environ.get("DB_PASS", "postgres")

def get_db_connection():
    return psycopg2.connect(host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASS)

def init_db():
    conn = get_db_connection()
    cur = conn.cursor()
    # Создаем таблицу, если ее еще нет
    cur.execute('''
        CREATE TABLE IF NOT EXISTS guestbook (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            message TEXT NOT NULL
        );
    ''')
    conn.commit()
    cur.close()
    conn.close()

@app.route('/api/messages', methods=['GET'])
def get_messages():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute('SELECT name, message FROM guestbook ORDER BY id DESC LIMIT 10;')
    messages = [{'name': row[0], 'message': row[1]} for row in cur.fetchall()]
    cur.close()
    conn.close()
    return jsonify(messages)

@app.route('/api/messages', methods=['POST'])
def add_message():
    data = request.json
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute('INSERT INTO guestbook (name, message) VALUES (%s, %s)', (data['name'], data['message']))
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({"status": "success"}), 201

if __name__ == '__main__':
    try:
        init_db()
        print("База данных инициализирована.")
    except Exception as e:
        print(f"Ошибка подключения к БД: {e}")
        print("Продолжаем запуск, но API будет выдавать ошибки без базы.")
        
    app.run(host='0.0.0.0', port=5000)