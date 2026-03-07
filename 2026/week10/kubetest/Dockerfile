FROM python:3.9-slim

WORKDIR /app

# Сначала копируем зависимости (слой закешируется)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Потом копируем сам код
COPY app.py .

EXPOSE 5000

# Запуск приложения
CMD ["python", "app.py"]