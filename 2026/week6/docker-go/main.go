package main

import (
	"fmt"
	"net/http"
)

func main() {
	// Контент страницы
	htmlContent := `
    <!DOCTYPE html>
    <html lang="uk">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Andriko | Profile</title>
        <style>
            @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&display=swap');
            
            :root {
                --primary: #fbbf24;
                --bg: #0a0a0a;
            }

            body {
                margin: 0;
                padding: 0;
                font-family: 'JetBrains Mono', monospace;
                background: var(--bg);
                color: white;
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
            }

            .profile-card {
                background: rgba(255, 255, 255, 0.03);
                border: 1px solid rgba(255, 255, 255, 0.1);
                backdrop-filter: blur(10px);
                padding: 3rem;
                border-radius: 40px;
                text-align: center;
                max-width: 400px;
                width: 100%;
            }

            .avatar-container {
                width: 150px;
                height: 150px;
                margin: 0 auto 1.5rem;
            }

            .avatar {
                width: 100%;
                height: 100%;
                border-radius: 50%;
                object-fit: cover;
                border: 2px solid var(--primary);
                padding: 5px;
            }

            h1 { margin: 0; font-size: 2rem; }
            .nickname { color: var(--primary); margin-bottom: 2rem; }
            
            .info-block {
                background: rgba(255, 255, 255, 0.05);
                padding: 1rem;
                border-radius: 15px;
                color: #5865F2;
                font-weight: bold;
            }

            .footer-ua {
                margin-top: 2rem;
                font-size: 0.8rem;
                display: flex;
                align-items: center;
                justify-content: center;
                gap: 8px;
                opacity: 0.6;
            }

            .flag {
                width: 20px;
                height: 12px;
                background: linear-gradient(to bottom, #0057b7 50%, #ffd700 50%);
                border-radius: 2px;
            }
        </style>
    </head>
    <body>
        <div class="profile-card">
            <div class="avatar-container">
                <img src="/avatar.png" alt="Andriko" class="avatar">
            </div>
            <h1>Andriko</h1>
            <div class="nickname">(жид)</div>
            <div class="info-block">Discord ID: 51984011</div>
            <div class="footer-ua">
                <div class="flag"></div>
                from ukraine
            </div>
        </div>
    </body>
    </html>
	`

	// Главный обработчик
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		// Если запрашивают конкретно картинку
		if r.URL.Path == "/avatar.png" {
			http.ServeFile(w, r, "avatar.png")
			return
		}
		// Во всех остальных случаях отдаем HTML
		fmt.Fprint(w, htmlContent)
	})

	fmt.Println("🚀 Server started at http://localhost:8080")
	http.ListenAndServe(":8080", nil)
}