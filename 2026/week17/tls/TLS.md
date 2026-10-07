# TLS-сертификаты: минимум для девопса

## Зачем

TLS даёт три вещи:
- шифрование: трафик не прочитать по дороге
- подлинность: ты говоришь именно с github.com, а не с тем, кто встал посередине
- целостность: данные не подменили по дороге

SSL — старое имя протокола, сам SSL давно мёртв. Сейчас живые версии TLS 1.2 и TLS 1.3.
«SSL-сертификат» — просто привычное название, по факту это TLS-сертификат (X.509).

## Что внутри сертификата

- **Subject / CN**: кому выдан (`CN=github.com`)
- **SAN** (Subject Alternative Name): список имён и IP, для которых серт действителен. **Имя проверяется по SAN**, а не по CN
- **Issuer**: кто выдал (подписал)
- **notBefore / notAfter**: срок действия
- **публичный ключ** сервера
- **подпись** выдавшего CA

Приватного ключа в серте НЕТ. Он лежит отдельным файлом на сервере и никуда не уходит.
Серт можно показывать всем, ключ никому. Утёк ключ — серт перевыпускаешь.

## Цепочка доверия

```
Root CA          (уже лежит в ОС/браузере: /etc/ssl/certs)
  └─ Intermediate CA   (подписан root)
       └─ твой серт (leaf)   (подписан intermediate)
```

- root держат офлайн в сейфе, а подписывают через intermediate. Если intermediate скомпрометируют, его отзовут, а root останется
- сервер должен отдавать **leaf + intermediate** (это и есть `fullchain`). Root не отдаёт: он уже есть у клиента
- забыл intermediate → браузер может открыть сайт (умеет докачивать), а curl, мобилки и Java падают с `unable to get local issuer certificate`. Классика

## Как клиент проверяет серт

1. цепочка подписей доходит до root, которому он доверяет
2. сегодняшняя дата между notBefore и notAfter
3. имя, к которому подключались, есть в SAN
4. (серт не отозван)

Хоть один пункт не прошёл → ошибка и соединения нет.

## Рукопожатие (TLS 1.3, на пальцах)

1. клиент: «привет, вот мои шифры, мне нужен **app.lab**» (имя передаётся в **SNI**)
2. сервер: «вот мой серт (+ цепочка)», и обе стороны договариваются об общем ключе (ECDHE)
3. клиент проверяет серт (4 пункта выше)
4. дальше всё шифруется **симметрично** общим ключом

Асимметрия (пара публичный/приватный ключ) нужна только чтобы доказать «я это я» и договориться о ключе.
Сами данные шифруются симметрично, потому что так быстрее.

**mTLS** (mutual TLS): серт показывает не только сервер, но и клиент. Так сервисы доказывают друг другу, кто есть кто
(service mesh в k8s: Istio, Linkerd). Ещё так ходят к API банков и к etcd в k8s.

SNI нужен потому, что на одном IP:443 висит много доменов, и сервер должен знать, какой серт отдать.
`openssl s_client -connect github.com:443` сам берёт имя из `-connect` и шлёт его в SNI.
А если подключаешься по IP (`-connect 127.0.0.1:443`), SNI не уходит, и сервер отдаст дефолтный серт.
Тогда имя указывают руками: `-servername app.lab`.

## Откуда берут серты

- **Let's Encrypt**: бесплатно, автоматически (certbot, acme.sh). Домен подтверждают:
  - HTTP-01: CA стучится на `http://домен/.well-known/acme-challenge/...` (нужен открытый 80 порт)
  - DNS-01: кладёшь TXT-запись в DNS. Только так можно получить wildcard `*.example.com`
- платные CA: то же самое, плюс поддержка и OV/EV-проверка организации
- **внутренняя CA компании**: для внутренних сервисов. Её root раскатывают на все машины в trust store
- **self-signed**: только для тестов, никто ему не доверяет
- в k8s: **cert-manager** сам выпускает и продлевает серты и кладёт их в Secret типа `kubernetes.io/tls`

Сроки жизни сертов сокращают: с марта 2026 максимум 200 дней, к 2029 будет 47 дней.
Вывод: продлевать руками нельзя, только автоматом, и обязательно мониторить срок.

## Файлы и форматы

- `.pem` / `.crt` / `.key`: текст `-----BEGIN ...-----`. Самый частый формат, nginx ест его
- `.der`: тот же серт, но бинарный
- `.pfx` / `.p12`: серт + ключ + цепочка в одном файле под паролем (Windows, IIS, Java)
- `.csr`: запрос на серт (твой публичный ключ + имя), его отправляют в CA

Расширение ничего не гарантирует. Смотри внутрь: `head -1 file`.

Let's Encrypt кладёт файлы в `/etc/letsencrypt/live/домен/`:
- `privkey.pem`: ключ
- `cert.pem`: только твой серт
- `chain.pem`: только intermediate
- `fullchain.pem`: cert + chain ← **это** в nginx `ssl_certificate`

## Где ломается в жизни

- истёк (не настроили автопродление или оно тихо падает)
- продлили, но **не сделали reload** nginx: старый серт висит в памяти
- нет intermediate в цепочке
- имени нет в SAN (зашли по IP, по новому поддомену, по `www.`)
- ключ не от этого серта: nginx не стартует, `key values mismatch`
- на сервере врут часы: серт «ещё не действителен» или «уже истёк»
- клиент не доверяет внутренней CA: её root не добавили в trust store
- ключ лежит с правами 644 или его закоммитили в git

## Шпаргалка

Чужой серт:
```bash
curl -vI https://github.com                      # в выводе: subject, issuer, start/expire date, SAN
openssl s_client -connect github.com:443 </dev/null > gh.txt   # < /dev/null: пустой ввод, чтобы не висел
openssl x509 -in gh.txt -noout -subject -issuer -dates   # x509 сам найдёт серт в этом выводе
```

Свой файл:
```bash
openssl x509 -in cert.pem -noout -text           # всё целиком
openssl x509 -in cert.pem -noout -dates          # только срок
openssl x509 -in cert.pem -noout -ext subjectAltName   # только имена
openssl x509 -in cert.pem -noout -checkend 2592000     # истечёт в ближайшие 30 дней? (код выхода 1 = да)
openssl req -in app.csr -noout -text             # что внутри CSR
```

Проверки:
```bash
openssl verify -CAfile root.crt -untrusted inter.crt app.crt   # цепочка собирается?
openssl x509 -in app.crt -noout -pubkey | sha256sum             # ключ от этого серта?
openssl pkey -in app.key -pubout | sha256sum                    #   хеши должны совпасть
curl --cacert root.crt https://app.lab                          # доверять этой CA
curl --resolve app.lab:443:10.0.0.5 https://app.lab             # проверить серт на сервере до смены DNS
curl -k https://...                                             # не проверять серт вообще (только для отладки!)
```

Выпуск:
```bash
openssl req -x509 -newkey rsa:2048 -noenc -keyout key.pem -out cert.pem -days 30 \
  -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost"            # self-signed
openssl req -newkey rsa:2048 -noenc -keyout app.key -out app.csr -subj "/CN=app.lab"   # ключ + CSR
openssl x509 -req -in app.csr -CA inter.crt -CAkey inter.key -out app.crt -days 90 -extfile san.ext   # CA подписывает
cat app.crt inter.crt > fullchain.crt                                     # leaf первым, потом intermediate
```

Конвертация:
```bash
openssl x509 -in app.crt -outform der -out app.der         # PEM → DER
openssl pkcs12 -export -in fullchain.crt -inkey app.key -out app.pfx   # → PFX (спросит пароль)
openssl pkcs12 -in app.pfx -nokeys -out from-pfx.crt       # серты из PFX обратно
```

nginx:
```bash
nginx -t && nginx -s reload     # после ЛЮБОЙ замены серта
```

k8s:
```bash
kubectl create secret tls app-tls --cert=fullchain.crt --key=app.key
```

Добавить свою CA в доверенные (на сервере):
- Debian/Ubuntu: положить в `/usr/local/share/ca-certificates/x.crt`, потом `sudo update-ca-certificates`
- RHEL/Rocky: положить в `/etc/pki/ca-trust/source/anchors/`, потом `sudo update-ca-trust`
- Arch: `sudo trust anchor x.crt`

Флаги, которые встречаются везде:
- `-noout`: не печатать сам серт в base64, только то, что спросил
- `-noenc` (раньше `-nodes`): не шифровать ключ паролем. Иначе nginx при старте будет просить пароль
- `-subj`: имя сразу в команде, без интерактивных вопросов
- `-servername`: SNI, для какого домена просим серт
