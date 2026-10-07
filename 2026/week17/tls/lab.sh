#!/usr/bin/env bash
# Поломки для части 2. Не читай до решения: тут ответы.
#   ./lab.sh 1..3   поднять кейс
#   ./lab.sh check  проверить текущий кейс
#   ./lab.sh clean  убрать контейнер и файлы кейсов
set -euo pipefail
cd "$(dirname "$0")"

IMG=nginx:1.30-alpine
NAME=tls-case
PORT=9443
HOST=shop.lab
CA=cases/ca

quiet() { "$@" >/dev/null 2>&1; }

make_ca() {
    [ -f $CA/root.crt ] && return
    mkdir -p $CA
    quiet openssl req -x509 -newkey rsa:2048 -noenc -keyout $CA/root.key -out $CA/root.crt -days 3650 -subj "/CN=Case Root CA"
    quiet openssl req -newkey rsa:2048 -noenc -keyout $CA/inter.key -out $CA/inter.csr -subj "/CN=Case Intermediate CA"
    echo "basicConstraints=critical,CA:TRUE" > $CA/ca.ext
    quiet openssl x509 -req -in $CA/inter.csr -CA $CA/root.crt -CAkey $CA/root.key -out $CA/inter.crt -days 1825 -extfile $CA/ca.ext
    rm $CA/inter.csr $CA/ca.ext
}

# new_key <file>
new_key() { quiet openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$1"; }

# sign <key> <out.crt> [доп. аргументы для openssl x509]
sign() {
    local key=$1 out=$2; shift 2
    local tmp; tmp=$(mktemp -d)
    echo "subjectAltName=DNS:$HOST" > "$tmp/san.ext"
    quiet openssl req -new -key "$key" -out "$tmp/req.csr" -subj "/CN=$HOST"
    quiet openssl x509 -req -in "$tmp/req.csr" -CA $CA/inter.crt -CAkey $CA/inter.key -out "$out" -extfile "$tmp/san.ext" "$@"
    rm -r "$tmp"
}

# conf <dir> <cert> <key>
conf() {
    cat > "$1/default.conf" <<EOF
server {
    listen 443 ssl;
    server_name $HOST;
    ssl_certificate     /etc/nginx/conf.d/$2;
    ssl_certificate_key /etc/nginx/conf.d/$3;
    location / { return 200 "hello \$host\n"; }
}
EOF
}

start() {
    docker run -d --name $NAME -p $PORT:443 -v "./cases/case$1:/etc/nginx/conf.d" $IMG >/dev/null
    sleep 1
}

# продлили, но не перечитали
case1() {
    local d=cases/case1
    mkdir -p $d/live
    new_key $d/live/privkey.pem
    sign $d/live/privkey.pem $d/old.crt -not_before 20250701000000Z -not_after 20250929000000Z
    cat $d/old.crt $CA/inter.crt > $d/live/fullchain.pem
    conf $d live/fullchain.pem live/privkey.pem
    start 1
    sign $d/live/privkey.pem $d/new.crt -days 90
    cat $d/new.crt $CA/inter.crt > $d/live/fullchain.pem
    rm $d/old.crt $d/new.crt
    echo "Кейс 1: вчера certbot продлил серт $HOST, файл свежий. Клиенты всё равно видят 'certificate has expired'."
}

# нет intermediate
case2() {
    local d=cases/case2
    new_key $d/shop.key
    sign $d/shop.key $d/shop.crt -days 90
    cp $CA/inter.crt $d/intermediate.crt
    conf $d shop.crt shop.key
    start 2
    echo "Кейс 2: в браузере $HOST открывается, а curl и мобилки ругаются."
}

# ключ не от серта
case3() {
    local d=cases/case3
    new_key $d/shop.key
    new_key $d/shop-2026.key
    new_key $d/test.key
    sign $d/shop-2026.key $d/shop.crt -days 90
    cat $CA/inter.crt >> $d/shop.crt
    conf $d shop.crt shop.key
    start 3
    echo "Кейс 3: выкатили новый серт для $HOST, и nginx больше не стартует."
}

check() {
    local n out
    n=$(cat cases/current 2>/dev/null) || { echo "сначала ./lab.sh N"; exit 1; }
    if out=$(curl -sS --cacert $CA/root.crt --resolve "$HOST:$PORT:127.0.0.1" "https://$HOST:$PORT" 2>&1); then
        echo "кейс $n решён: $out"
    else
        echo "кейс $n не решён: $(echo "$out" | head -1)"
        return 1
    fi
}

clean() {
    docker rm -f $NAME >/dev/null 2>&1 || true
    rm -rf cases
}

case "${1:-}" in
    1|2|3)
        docker rm -f $NAME >/dev/null 2>&1 || true
        make_ca
        rm -rf "cases/case$1"; mkdir -p "cases/case$1"
        echo "$1" > cases/current
        "case$1"
        echo "Файлы: cases/case$1/   Контейнер: $NAME   Порт: $PORT"
        echo "Клиент видит это так: curl --cacert $CA/root.crt --resolve $HOST:$PORT:127.0.0.1 https://$HOST:$PORT"
        ;;
    check) check ;;
    clean) clean ;;
    *) echo "usage: ./lab.sh 1|2|3|check|clean"; exit 1 ;;
esac
