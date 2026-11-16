#!/usr/bin/env bash
# Проверки блоков: ./lab.sh check N
# По коду видно, что именно ожидается. Не читай до решения.
set -uo pipefail

LAB=$(cd "$(dirname "$0")/.." && pwd)
cd "${ANSLAB_ROOT:-$LAB}"

FAIL=0
ok()   { printf '  ок   %s\n' "$*"; }
no()   { printf '  НЕТ  %s\n' "$*"; FAIL=1; }
note() { printf '       %s\n' "$*"; }

# t "описание" команда...  -> ок или НЕТ по коду возврата команды
t() {
    local d=$1; shift
    if "$@" >/dev/null 2>&1; then ok "$d"; else no "$d"; fi
}

# команда на сервере напрямую, мимо Ansible
on()     { local h=$1; shift; podman exec "anslab-$h" sh -c "$*"; }
code()   { curl -s -o /dev/null -w '%{http_code}' --noproxy '*' -m 3 "http://localhost:$1/"; }
body()   { curl -s --noproxy '*' -m 3 "http://localhost:$1/"; }
header() { curl -sI --noproxy '*' -m 3 "http://localhost:$1/" | tr -d '\r' | grep -i "^$2:" | awk '{print $2}'; }
hostvar() { ansible-inventory --host "$1" 2>/dev/null | python3 -I -c "import json,sys; print(json.load(sys.stdin).get('$2',''))" 2>/dev/null; }
pb()     { if [ -f site.yml ]; then echo site.yml; else echo web.yml; fi; }

changed_sum() { sed -n '/PLAY RECAP/,$p' | grep -o 'changed=[0-9]*' | cut -d= -f2 | awk '{s+=$1} END {print s+0}'; }

# плейбук проходит, и повторный прогон ничего не меняет
idempotent() {
    local f=$1 out n
    [ -f "$f" ] || { no "нет файла $f"; return; }
    for try in 1 2; do
        if ! out=$(ansible-playbook "$f" 2>&1); then
            no "$f падает:"
            echo "$out" | grep -E '^\[ERROR\]|^fatal' | head -3 | cut -c1-200 | sed 's/^/       /'
            return
        fi
        n=$(echo "$out" | changed_sum)
        [ "$n" = 0 ] && { ok "$f: повторный прогон даёт changed=0"; return; }
    done
    no "$f: повторный прогон снова что-то меняет (changed=$n). Задачи:"
    echo "$out" | grep -B1 '^changed:' | grep -E '^(TASK|RUNNING)' | sort -u | cut -c1-80 | sed 's/^/       /'
}

servers_up() {
    for h in web1 web2 lb1; do
        [ "$(podman inspect -f '{{.State.Status}}' anslab-$h 2>/dev/null)" = running ] || {
            echo "сервер $h не запущен: ./lab.sh up"; exit 1; }
    done
}

check1() {
    t "inventory.ini есть" test -f inventory.ini
    local g
    g=$(ansible-inventory --list 2>/dev/null | python3 -I -c "
import json,sys
d=json.load(sys.stdin)
print(' '.join(sorted(d.get('web',{}).get('hosts',[]))), '|', ' '.join(sorted(d.get('lb',{}).get('hosts',[]))))" 2>/dev/null)
    if [ "$g" = "web1 web2 | lb1" ]; then ok "группы: web = web1 web2, lb = lb1"
    else [ "$g" = " | " ] && g=""; no "группы не те. Жду web = web1 web2 и lb = lb1, вижу: ${g:-ничего}"; fi
    local pong
    pong=$(ansible all -m ping 2>/dev/null | grep -c pong)
    if [ "$pong" = 3 ]; then ok "ansible all -m ping: три pong"; else no "ping: pong пришёл от $pong серверов из 3"; fi
    for h in web1 web2; do
        t "$h: htop установлен" on $h "dpkg -s htop"
        t "$h: каталог /opt/lab есть" on $h "test -d /opt/lab"
    done
}

check2() {
    for h in web1 web2; do
        t "$h: nginx работает" on $h "systemctl is-active nginx"
        t "$h: nginx в автозагрузке" on $h "systemctl is-enabled nginx"
    done
    for p in 8101 8102; do
        if [ "$(code $p)" != 200 ]; then no "localhost:$p не отвечает 200"
        elif body $p | grep -q 'Welcome to nginx'; then no "localhost:$p отдаёт страницу nginx по умолчанию, а не твою"
        else ok "localhost:$p отдаёт твою страницу"; fi
    done
    idempotent "$(pb)"
    echo "  Почини:"
    if grep -qE '^\s*(ansible\.builtin\.)?(command|shell):' fixme/2-march.yml; then
        no "в fixme/2-march.yml остались command или shell"
    else ok "в fixme/2-march.yml нет command и shell"; fi
    idempotent fixme/2-march.yml
    for h in web1 web2; do
        t "$h: пользователь app" on $h "id app"
        t "$h: /opt/app/releases" on $h "test -d /opt/app/releases"
        t "$h: /opt/app/.prepared" on $h "test -f /opt/app/.prepared"
        t "$h: строка в deploy.log" on $h "grep -qx 'deployed by ansible' /opt/app/deploy.log"
    done
}

check3() {
    t "есть переменные группы web (group_vars/web.yml или group_vars/web/)" test -e group_vars/web.yml -o -d group_vars/web
    local a b
    a=$(hostvar web1 site_title); b=$(hostvar web2 site_title)
    if [ -n "$a" ] && [ -n "$b" ] && [ "$a" != "$b" ]; then ok "site_title у web1 и web2 разный (host_vars)"
    else no "site_title: web1 = '${a}', web2 = '${b}'. Жду два разных непустых значения"; fi
    if grep -rqE '^\s*(ansible\.builtin\.)?template:' $(pb) roles 2>/dev/null; then ok "страница кладётся модулем template"
    else no "не вижу задачи с template"; fi
    for h in web1:8101 web2:8102; do
        local name=${h%%:*} port=${h##*:} page
        page=$(body $port)
        if echo "$page" | grep -q "$name"; then ok "$name: на странице есть имя хоста"
        else no "$name: на странице localhost:$port нет имени хоста $name"; fi
        local title; title=$(hostvar $name site_title)
        if [ -n "$title" ] && echo "$page" | grep -qF "$title"; then ok "$name: на странице его site_title"
        else no "$name: на странице нет его site_title"; fi
    done
    idempotent "$(pb)"
}

check4() {
    for h in web1:8101 web2:8102; do
        local name=${h%%:*} port=${h##*:} got
        got=$(header $port X-Served-By)
        if [ "$got" = "$name" ]; then ok "$name: заголовок X-Served-By: $name"
        else no "$name: жду заголовок X-Served-By: $name, вижу '${got}'"; fi
        t "$name: sites-enabled/lab.conf это симлинк" on $name "test -L /etc/nginx/sites-enabled/lab.conf"
        t "$name: sites-enabled/default убран" on $name "test ! -e /etc/nginx/sites-enabled/default"
        t "$name: nginx -t проходит" on $name "nginx -t"
        # то, что отдаёт nginx, совпадает с тем, что лежит на диске
        local disk live
        disk=$(on $name "grep -o 'X-Site.*' /etc/nginx/sites-available/lab.conf" 2>/dev/null | sed 's/^X-Site *//; s/[";]//g')
        live=$(curl -sI --noproxy '*' -m 3 "http://localhost:$port/" | tr -d '\r' | sed -n 's/^X-Site: //Ip')
        if [ -n "$disk" ] && [ "$disk" = "$live" ]; then ok "$name: конфиг на диске и в работающем nginx совпадают"
        else no "$name: на диске X-Site '${disk}', а nginx отдаёт '${live}' (потерянный reload?)"; fi
    done
    if grep -rqE '^\s*notify:' $(pb) roles 2>/dev/null; then ok "есть notify"; else no "не вижу notify"; fi
    if grep -rqE 'state:\s*reloaded' $(pb) roles 2>/dev/null; then ok "handler делает reload"; else no "не вижу handler с state: reloaded"; fi
    if grep -rqE 'nginx -t' $(pb) roles 2>/dev/null; then ok "конфиг проверяется (nginx -t)"; else no "нет задачи с nginx -t"; fi
    idempotent "$(pb)"
}

check5() {
    for f in tasks/main.yml handlers/main.yml defaults/main.yml; do
        t "roles/nginx/$f" test -s roles/nginx/$f
    done
    if ls roles/nginx/templates/*.j2 >/dev/null 2>&1; then ok "шаблоны лежат в roles/nginx/templates/"
    else no "в roles/nginx/templates/ нет шаблонов"; fi
    t "roles/common/tasks/main.yml" test -s roles/common/tasks/main.yml
    if [ -f site.yml ] && grep -qE '^\s*roles:' site.yml; then ok "site.yml подключает роли"
    else no "нет site.yml с roles:"; fi
    if [ -e web.yml ]; then no "web.yml ещё лежит, он больше не нужен"; else ok "web.yml удалён"; fi
    t "lb1: htop установлен (роль common дошла до всех)" on lb1 "dpkg -s htop"
    if ansible-playbook site.yml --list-tasks 2>/dev/null | grep -q 'TAGS: \[config\]'; then ok "есть задачи с тегом config"
    else no "нет задач с тегом config"; fi
    idempotent site.yml
    echo "  Почини (по желанию):"
    if [ "$(on lb1 'systemctl is-active heartbeat.timer' 2>/dev/null)" != active ]; then
        note "таймер heartbeat на lb1 не запущен: fixme/5-heartbeat.yml ещё не починен"
    elif on lb1 "grep -q 'OnUnitActiveSec=10s' /etc/systemd/system/heartbeat.timer"; then
        ok "heartbeat тикает раз в 10 секунд"
    else no "heartbeat запущен, но интервал не 10 секунд: $(on lb1 'grep OnUnitActiveSec /etc/systemd/system/heartbeat.timer')"; fi
}

check6() {
    local vf
    vf=$(grep -rl '^\$ANSIBLE_VAULT' group_vars host_vars 2>/dev/null | head -1)
    if [ -n "$vf" ]; then ok "зашифрованный файл: $vf"; else no "в group_vars нет файла, зашифрованного ansible-vault"; fi
    t ".vault_pass есть" test -s .vault_pass
    if git check-ignore -q .vault_pass 2>/dev/null; then ok ".vault_pass в .gitignore"
    else no ".vault_pass не в .gitignore: пароль от vault уедет в git"; fi
    for h in web1 web2; do
        local st
        st=$(on $h "stat -c '%a %U' /etc/app/app.env" 2>/dev/null)
        if [ "$st" = "600 root" ]; then ok "$h: /etc/app/app.env, права 600, владелец root"
        else no "$h: /etc/app/app.env жду '600 root', вижу '${st:-файла нет}'"; fi
    done
    local secret
    secret=$(on web1 "sed -n 's/^DB_PASSWORD=//p' /etc/app/app.env" 2>/dev/null)
    if [ -z "$secret" ]; then no "в app.env на web1 пустой DB_PASSWORD"
    elif grep -rqF --exclude-dir=.git --exclude-dir=lab --exclude=.vault_pass -- "$secret" . 2>/dev/null; then
        no "пароль из app.env лежит в проекте открытым текстом: $(grep -rlF --exclude-dir=.git --exclude-dir=lab --exclude=.vault_pass -- "$secret" . | head -1)"
    else ok "пароля из app.env нет в файлах проекта открытым текстом"; fi
    if grep -rqE '^\s*no_log:\s*true' roles 2>/dev/null; then ok "есть no_log: true"; else no "нет задачи с no_log: true"; fi
    idempotent site.yml
}

check7() {
    local seen="" bad=0 resp
    for i in 1 2 3 4 5 6 7 8; do
        # один запрос на шаг: и код, и кто ответил
        resp=$(curl -sI --noproxy '*' -m 3 http://localhost:8100/ | tr -d '\r')
        echo "$resp" | head -1 | grep -q ' 200' || bad=$((bad+1))
        seen="$seen $(echo "$resp" | sed -n 's/^X-Served-By: //Ip')"
    done
    if [ $bad = 0 ]; then ok "балансировщик localhost:8100: 8 запросов, все 200"; else no "балансировщик: $bad из 8 запросов не 200"; fi
    if echo "$seen" | grep -q web1 && echo "$seen" | grep -q web2; then ok "отвечают оба: web1 и web2"
    else no "за балансировщиком отвечает не оба сервера:$seen"; fi
    if grep -rq "groups\[" roles/lb/templates 2>/dev/null; then ok "список серверов в конфиге балансировщика берётся из groups"
    else no "в шаблоне балансировщика нет groups[...]: серверы вписаны руками?"; fi
    if grep -qE '^\s*serial:' site.yml 2>/dev/null; then ok "в site.yml есть serial"; else no "в site.yml нет serial (или он закомментирован)"; fi
    if grep -rqE '^\s*(ansible\.builtin\.)?uri:' site.yml roles 2>/dev/null; then ok "есть проверка через uri"; else no "нет проверки через uri"; fi
    local v1 v2
    v1=$(body 8101 | grep -io 'version[^<]*' | head -1); v2=$(body 8102 | grep -io 'version[^<]*' | head -1)
    if [ -n "$v1" ] && [ "$v1" = "$v2" ]; then ok "на обоих серверах одна версия ($v1)"
    else no "версии на страницах: web1 '${v1}', web2 '${v2}'"; fi
    idempotent site.yml
}

final() {
    if [ "${1:-}" != "-y" ]; then
        read -r -p "Снесу три сервера и накачу site.yml на чистые. Продолжать? [y/N] " a
        [ "$a" = y ] || exit 0
    fi
    "$LAB/lab.sh" reset >/dev/null || exit 1
    echo "серверы чистые, первый прогон site.yml..."
    local t0=$SECONDS out
    if out=$(ansible-playbook site.yml 2>&1); then
        ok "первый прогон на чистых серверах прошёл за $((SECONDS-t0)) с, changed=$(echo "$out" | changed_sum)"
    else
        no "первый прогон на чистых серверах упал:"
        echo "$out" | grep -E '^\[ERROR\]|^fatal' | head -4 | cut -c1-200 | sed 's/^/       /'
        return
    fi
    check7
}

n=${1:-}
case "$n" in
    1|2|3|4|5|6|7) servers_up; echo "Блок $n"; check$n ;;
    final) echo "Финал"; final "${2:-}" ;;
    *) echo "какой блок? ./lab.sh check 1..7 или ./lab.sh check final"; exit 1 ;;
esac

if [ $FAIL = 0 ]; then echo "Всё ок."; else echo "Есть НЕТ: чини и запускай проверку ещё раз."; exit 1; fi
