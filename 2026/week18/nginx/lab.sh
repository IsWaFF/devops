#!/usr/bin/env bash
# Поломки для части 2. Не читай до решения: тут ответы.
#   ./lab.sh up     поднять api для части 1
#   ./lab.sh 1..3   поднять кейс
#   ./lab.sh check  проверить текущий кейс
#   ./lab.sh clean  убрать контейнеры, сеть и файлы кейсов
set -euo pipefail
cd "$(dirname "$0")"

NET=proxylab
PY=python:3.13-alpine
NGINX=nginx:1.30-alpine
PORT=8082

net() { docker network inspect $NET >/dev/null 2>&1 || docker network create $NET >/dev/null; }

# get <path> -> "код тело"
get() { curl -s --noproxy '*' -w ' %{http_code}' "$@" 2>/dev/null || true; }

# api_cfg <case> <listen> <report_delay>
api_cfg() {
    cat > "cases/case$1/api/api.cfg" <<CFG
# настройки api
listen=$2
port=8080
report_delay=$3
CFG
}

# proxy_conf <case> [строки внутри server]
proxy_conf() {
    local n=$1; shift
    {
        echo "server {"
        echo "    listen 80;"
        for line in "$@"; do echo "    $line"; done
        echo ""
        echo "    location /api/ {"
        echo "        proxy_pass http://case-api:8080/;"
        echo "    }"
        echo "}"
    } > "cases/case$n/nginx/default.conf"
}

start() {
    docker run -d --name case-api --network $NET -v ./api:/app:ro -v "./cases/case$1/api:/etc/api:ro" \
        $PY python /app/api.py /etc/api/api.cfg >/dev/null
    sleep 1
    docker run -d --name case-proxy --network $NET -p $PORT:80 -v "./cases/case$1/nginx:/etc/nginx/conf.d" \
        $NGINX >/dev/null
    sleep 1
}

# api слушает 127.0.0.1 внутри своего контейнера
case1() {
    api_cfg 1 127.0.0.1 20
    proxy_conf 1
    start 1
    echo "Кейс 1: после переезда api в новый контейнер весь /api/ отдаёт 502."
    echo "docker ps говорит, что case-api работает, а разработчик клянётся: «изнутри контейнера всё отвечает»."
}

# proxy_read_timeout меньше времени отчёта
case2() {
    api_cfg 2 0.0.0.0 20
    proxy_conf 2 "proxy_read_timeout 10s;"
    start 2
    echo "Кейс 2: отчёт /api/v1/report падает с 504. /api/health отвечает сразу, api живой, ошибок в его логах нет."
}

# конфиг поменяли без reload, и в нём опечатка
case3() {
    api_cfg 3 0.0.0.0 20
    proxy_conf 3
    start 3
    docker inspect -f '{{.State.StartedAt}}' case-proxy > cases/started
    cat > cases/case3/nginx/default.conf <<'CONF'
server {
    listen 80;

    location /api/ {
        proxy_pass http://case-api:8080/;
    }

    # 17.10 Саша: версия для мониторинга
    location = /version {
        default_type text/plain;
        return 200 "shop 2.4.1\n"
    }
}
CONF
    touch -d yesterday cases/case3/nginx/default.conf
    echo "Кейс 3: коллега вчера добавил в конфиг location = /version для мониторинга."
    echo "В файле он есть, а curl localhost:$PORT/version даёт 404. Чинить без даунтайма: case-proxy не перезапускать."
}

check1() {
    local h o
    h=$(get localhost:$PORT/api/health)
    o=$(get localhost:$PORT/api/v1/orders)
    if [[ $h == "ok"*" 200" && $o == *orders*" 200" ]]; then
        echo "кейс 1 решён: /api/health и /api/v1/orders отвечают 200"
    else
        echo "кейс 1 не решён: /api/health -> ${h##* }, /api/v1/orders -> ${o##* }"
        return 1
    fi
}

check2() {
    local h r s
    h=$(get localhost:$PORT/api/health)
    [[ $h == *" 200" ]] || { echo "кейс 2 не решён: /api/health -> ${h##* }"; return 1; }
    echo "жду отчёт (до 40 с)..."
    r=$(get --max-time 40 localhost:$PORT/api/v1/report)
    [[ $r == "report ready"*" 200" ]] || { echo "кейс 2 не решён: /api/v1/report -> ${r##* }"; return 1; }
    echo "отчёт есть, теперь /api/v1/stuck должен оборваться секунд за 10..."
    s=$(get --max-time 15 localhost:$PORT/api/v1/stuck)
    if [[ $s == *" 504" ]]; then
        echo "кейс 2 решён: отчёт 200, зависший запрос по-прежнему обрывается быстро"
    else
        echo "кейс 2 не решён: отчёт работает, но /api/v1/stuck не оборвался за 15 с. Долгий таймаут достался всем, а не только отчёту"
        return 1
    fi
}

check3() {
    local now v
    now=$(docker inspect -f '{{.State.StartedAt}}' case-proxy 2>/dev/null || echo none)
    if [[ $now != "$(cat cases/started)" ]]; then
        echo "кейс 3 не засчитан: case-proxy перезапускали или пересоздавали, а это даунтайм. Подними кейс заново: ./lab.sh 3"
        return 1
    fi
    v=$(get localhost:$PORT/version)
    if [[ $v == "shop 2.4.1"*" 200" ]]; then
        echo "кейс 3 решён: /version отдаёт версию, nginx не перезапускали"
    else
        echo "кейс 3 не решён: /version -> ${v##* }"
        return 1
    fi
}

clean() {
    docker rm -f proxy api case-proxy case-api >/dev/null 2>&1 || true
    docker network rm $NET >/dev/null 2>&1 || true
    rm -rf cases
}

case "${1:-}" in
    up)
        net
        docker rm -f api >/dev/null 2>&1 || true
        docker run -d --name api --network $NET -v ./api:/app:ro $PY python /app/api.py /app/api.cfg >/dev/null
        echo "api запущен: контейнер api, сеть $NET, порт 8080 (наружу не проброшен)"
        ;;
    1|2|3)
        net
        docker rm -f case-proxy case-api >/dev/null 2>&1 || true
        rm -rf "cases/case$1"; mkdir -p "cases/case$1/nginx" "cases/case$1/api"
        echo "$1" > cases/current
        "case$1"
        echo "Файлы: cases/case$1/nginx/ и cases/case$1/api/   Контейнеры: case-proxy, case-api   Порт: $PORT"
        ;;
    check)
        n=$(cat cases/current 2>/dev/null) || { echo "сначала ./lab.sh N"; exit 1; }
        "check$n"
        ;;
    clean) clean ;;
    *) echo "usage: ./lab.sh up|1|2|3|check|clean"; exit 1 ;;
esac
