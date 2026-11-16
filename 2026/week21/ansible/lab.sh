#!/usr/bin/env bash
# Стенд для Ansible: три «сервера» в контейнерах (Ubuntu 24.04, systemd, sshd).
#   ./lab.sh up          поднять серверы (первый раз собирает образ, 1–2 минуты)
#   ./lab.sh status      что запущено и на каких портах
#   ./lab.sh ssh web1    зайти на сервер руками
#   ./lab.sh watch       раз в полсекунды спрашивать сайт через балансировщик (блок 7)
#   ./lab.sh reset       снести серверы и поднять чистые. Твои файлы не трогает
#   ./lab.sh down        остановить серверы (всё, что на них настроено, остаётся)
#   ./lab.sh clean       убрать всё: контейнеры, сеть, образ
#   ./lab.sh check N     проверить блок N: 1..7 или final
set -euo pipefail
cd "$(dirname "$0")"

IMAGE=anslab-server
NET=anslab
KEY=lab/key
# имя:ssh-порт:http-порт
HOSTS="web1:2201:8101 web2:2202:8102 lb1:2203:8100"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

command -v podman >/dev/null || { echo "нужен podman: sudo pacman -S podman"; exit 1; }

# ключ, которым Ansible входит на серверы. Публичная половина зашита в образ
key() {
    if [ ! -f $KEY ]; then
        ssh-keygen -q -t ed25519 -N '' -C ansible-lab -f $KEY
        podman rmi -f $IMAGE >/dev/null 2>&1 || true
    fi
    chmod 600 $KEY
}

image() {
    podman image exists $IMAGE && return
    echo "собираю образ сервера, это один раз..."
    local log
    log=$(podman build --http-proxy=false -t $IMAGE -f lab/Containerfile lab 2>&1) || { echo "$log" | tail -20; exit 1; }
}

wait_ssh() {
    local port=$1 n=0
    until ssh -i $KEY -p "$port" $SSH_OPTS -o ConnectTimeout=2 deploy@127.0.0.1 true 2>/dev/null; do
        n=$((n+1))
        [ $n -gt 30 ] && { echo "ssh на порту $port не поднялся"; exit 1; }
        sleep 1
    done
}

up() {
    key
    image
    # свои DNS для сети: иначе aardvark-dns помнит DNS той сети, где ноутбук был при запуске,
    # и после смены Wi-Fi серверы стенда перестают видеть интернет (apt висит молча)
    podman network exists $NET || podman network create --dns 1.1.1.1 --dns 8.8.8.8 $NET >/dev/null
    for h in $HOSTS; do
        IFS=: read -r name sshp httpp <<<"$h"
        if podman container exists anslab-$name; then
            podman start anslab-$name >/dev/null
        else
            podman run -d --name anslab-$name --hostname $name --network $NET \
                --systemd=always --http-proxy=false \
                -p 127.0.0.1:$sshp:22 -p 127.0.0.1:$httpp:80 \
                $IMAGE >/dev/null
        fi
        wait_ssh $sshp
    done
    status
}

status() {
    printf '%-6s %-10s %-22s %s\n' СЕРВЕР СТАТУС SSH HTTP
    for h in $HOSTS; do
        IFS=: read -r name sshp httpp <<<"$h"
        st=$(podman inspect -f '{{.State.Status}}' anslab-$name 2>/dev/null || echo "нет")
        printf '%-6s %-10s %-22s %s\n' $name "$st" "deploy@127.0.0.1:$sshp" "http://localhost:$httpp"
    done
}

rm_hosts() {
    for h in $HOSTS; do
        podman rm -f -t 2 anslab-${h%%:*} >/dev/null 2>&1 || true
    done
}

# одна строка на запрос: время, код ответа, какой сервер ответил, версия со страницы
watch_site() {
    echo "спрашиваю http://localhost:8100 раз в полсекунды. Ctrl+C чтобы выйти"
    while true; do
        out=$(curl -s -i --noproxy '*' -m 2 http://localhost:8100/ || true)
        code=$(echo "$out" | head -1 | awk '{print $2}')
        host=$(echo "$out" | grep -i '^X-Served-By:' | awk '{print $2}' | tr -d '\r' || true)
        ver=$(echo "$out" | grep -io 'version[^<]*' | head -1 || true)
        printf '%s  %s  %-5s %s\n' "$(date +%T)" "${code:----}" "${host:--}" "$ver"
        sleep 0.5
    done
}

case "${1:-}" in
    up)     up ;;
    status) status ;;
    ssh)
        for h in $HOSTS; do
            IFS=: read -r name sshp httpp <<<"$h"
            [ "$name" = "${2:-}" ] && exec ssh -i $KEY -p $sshp $SSH_OPTS deploy@127.0.0.1
        done
        echo "какой сервер? web1, web2 или lb1"; exit 1 ;;
    watch)  watch_site ;;
    reset)  rm_hosts; up ;;
    down)
        for h in $HOSTS; do podman stop -t 5 anslab-${h%%:*} >/dev/null 2>&1 || true; done
        echo "остановлено. Поднять обратно: ./lab.sh up" ;;
    clean)
        rm_hosts
        podman network rm -f $NET >/dev/null 2>&1 || true
        podman rmi -f $IMAGE >/dev/null 2>&1 || true
        echo "убрано" ;;
    check)  shift; exec bash lab/check.sh "$@" ;;
    *)      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
