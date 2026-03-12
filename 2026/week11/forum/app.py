import os
import psycopg2
from flask import Flask, request, jsonify, render_template

app = Flask(__name__)

# Стучимся в БД (пароли будут прокинуты через Helm)
DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_NAME = os.environ.get("DB_NAME", "postgres")
DB_USER = os.environ.get("DB_USER", "postgres")
DB_PASS = os.environ.get("DB_PASS", "postgres")

def get_db_connection():
    return psycopg2.connect(host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASS)

def init_db():
    conn = get_db_connection()
    cur = conn.cursor()
    # Таблица для наших постов
    cur.execute('''
        CREATE TABLE IF NOT EXISTS posts (
            id SERIAL PRIMARY KEY,
            author VARCHAR(50) NOT NULL,
            title VARCHAR(100) NOT NULL,
            tag VARCHAR(50),
            content TEXT NOT NULL,
            likes INT DEFAULT 0
        );
    ''')
    conn.commit()
    cur.close()
    conn.close()

# Отдаем фронтенд
@app.route('/')
def index():
    return render_template('index.html')

# Получить все посты
@app.route('/api/posts', methods=['GET'])
def get_posts():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('SELECT id, author, title, tag, content, likes FROM posts ORDER BY id DESC;')
        posts = [{'id': row[0], 'author': row[1], 'title': row[2], 'tag': row[3], 'content': row[4], 'likes': row[5]} for row in cur.fetchall()]
        cur.close()
        conn.close()
        return jsonify(posts)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Создать пост
@app.route('/api/posts', methods=['POST'])
def add_post():
    data = request.json
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        'INSERT INTO posts (author, title, tag, content) VALUES (%s, %s, %s, %s)',
        (data['author'], data['title'], data['tag'], data['content'])
    )
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({"status": "success"}), 201

# Поставить лайк
@app.route('/api/posts/<int:post_id>/like', methods=['POST'])
def like_post(post_id):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute('UPDATE posts SET likes = likes + 1 WHERE id = %s RETURNING likes', (post_id,))
    new_likes = cur.fetchone()[0]
    conn.commit()
    cur.close()
    conn.close()
    return jsonify({"likes": new_likes})

if __name__ == '__main__':
    try:
        init_db()
        print("База данных инициализирована.")
    except Exception as e:
        print(f"Ошибка БД: {e}. Ждем Кубернетис...")
        
    app.run(host='0.0.0.0', port=5000)