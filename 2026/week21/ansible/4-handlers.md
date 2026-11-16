# Блок 4. Handlers

Цель: конфиг nginx лежит в плейбуке. nginx перечитывает его, только когда конфиг поменялся, и битый конфиг сайт не роняет.

Время: около 45 минут. Про reload и restart ты уже знаешь из nginx-лабы, здесь это пригодится.

---

## Шаг 1. notify и handler

### Теория

Конфиг поменялся → nginx надо попросить его перечитать. Не поменялся → трогать nginx незачем. Обычная задача с `state: reloaded` дёргала бы nginx на каждом прогоне.

**Handler** — задача из отдельной секции `handlers:`. Она запускается, только если её позвали через `notify`, и только если позвавшая задача дала `changed`.

```yaml
  tasks:
    - name: SSH config
      ansible.builtin.template:
        src: templates/sshd_config.j2
        dest: /etc/ssh/sshd_config
        mode: "0600"
      notify: Restart ssh             # имя handler-а, буква в букву

  handlers:
    - name: Restart ssh
      ansible.builtin.service:
        name: ssh
        state: restarted
```

- handlers запускаются **один раз, в конце play**, после всех задач. Позвали его три задачи → запуск всё равно один
- `handlers:` стоит на одном уровне с `tasks:`
- reload: nginx перечитывает конфиг, соединения не рвутся, а если конфиг битый, остаётся работать на старом. restart: остановить и запустить заново, с битым конфигом не поднимется. Поэтому для конфигов nginx в handler-е ставят reload

В Ubuntu конфиги сайтов лежат в `/etc/nginx/sites-available/`, а nginx читает только те, на которые есть симлинк из `/etc/nginx/sites-enabled/`.

### Руками

**1.** Создай `templates/lab.conf.j2`. nginx здесь не тема, поэтому конфиг готовый:

```nginx
server {
    listen 80 default_server;
    root /var/www/html;
    index index.html;

    add_header X-Served-By {{ inventory_hostname }};
    add_header X-Site "{{ site_title }}";
}
```

**2.** Добавь в `web.yml` три задачи и один handler:
- шаблон кладётся в `/etc/nginx/sites-available/lab.conf`
- в `sites-enabled` есть симлинк на него (модуль `file`, `state: link`)
- симлинка `/etc/nginx/sites-enabled/default` нет (модуль `file`, `state: absent`)
- все три задачи зовут handler `Reload nginx`

Поставь эти задачи после установки пакетов, но перед задачей «nginx запущен». Почему так, будет в шаге 2.

**3.** Перед запуском запомни PID главного процесса nginx:

```bash
ansible web -b -m command -a "cat /run/nginx.pid"
```

**4.** Запусти плейбук. В конце вывода должна быть строка `RUNNING HANDLER [Reload nginx]`, один раз на сервер, хотя звали три задачи. Проверь:

```bash
curl -I localhost:8101
```

В ответе есть заголовки `X-Served-By` и `X-Site`. PID из задания 3 не изменился: это был reload, а не restart.

**5.** Второй прогон: строки `RUNNING HANDLER` нет, `changed=0`.

**6.** Поменяй `site_title` в `group_vars/web.yml` и запусти. Handler сработал, заголовок на web2 новый.

---

## Шаг 2. Битый конфиг

### Теория

Reload спасает сайт, но мусор на диске остаётся. Шаблон уже записан, reload упал, nginx работает на старом конфиге **из памяти**. Первый же restart или перезагрузка сервера, и nginx не поднимется.

Поэтому конфиг проверяют до reload. Способов два:

- параметр `validate` у `template` и `copy`: команда проверяет новый файл до того, как он заменит старый. Годится, когда файл можно проверить отдельно: `validate: visudo -cf %s`, `validate: sshd -t -f %s`
- отдельная задача после конфигов. Для nginx нужен этот способ, потому что `nginx -t` проверяет весь конфиг целиком, а не один кусок:

```yaml
- name: Check nginx config
  ansible.builtin.command: nginx -t
  changed_when: false
```

Отсюда порядок задач для любого сервиса: **пакет → конфиги → проверка → «сервис запущен»**. Если «запущен» стоит раньше конфигов, а на диске битый конфиг и nginx лежит, плейбук упадёт на запуске и до починки конфига не дойдёт.

### Руками

**7.** Допиши в `templates/lab.conf.j2` внутрь `server` строку `oops;` и запусти плейбук. Посмотри, какая задача упала. Потом проверь две вещи:

```bash
curl -I localhost:8101
ansible web -b -m command -a "nginx -t"
```

Сайт жив? А конфиг на диске?

**8.** Запусти плейбук ещё раз, ничего не меняя. Посмотри на RECAP: всё зелёное. При этом на диске битый конфиг, и следующий restart положит nginx.

**9.** Добавь задачу `Check nginx config` после трёх задач с конфигом. Запусти: теперь плейбук красный каждый раз, пока конфиг битый.

**10.** Убери `oops;` и запусти. Проверка прошла, reload прошёл.

---

## Шаг 3. Потерянный handler

### Теория

Handler ждёт конца play. Если после `notify` какая-нибудь задача упала, play на этом сервере обрывается, и handler **не запускается**. На следующем прогоне шаблон уже `ok` (файл на диске новый), значит notify не будет. Итог: на диске новый конфиг, в памяти nginx старый, плейбук зелёный.

Что с этим делают:

- `ansible-playbook web.yml --force-handlers` — выполнить позванные handlers, даже если play упал
- задача `ansible.builtin.meta: flush_handlers` — «выполни накопившиеся handlers прямо сейчас». Её ставят сразу после конфигов
- если уже попал: reload руками, `ansible web -b -m service -a "name=nginx state=reloaded"`

### Руками

**11.** Временно добавь последней задачей в `tasks`:

```yaml
    - name: Something else fails
      ansible.builtin.command: /bin/false
```

**12.** Поменяй `site_title` в `group_vars/web.yml` и запусти. Плейбук упал на последней задаче, строки `RUNNING HANDLER` нет.

**13.** Удали падающую задачу и запусти снова: `changed=0`, всё зелёное. Теперь сравни, что отдаёт nginx и что лежит на диске:

```bash
curl -sI localhost:8102 | grep X-Site
ansible web2 -b -m command -a "grep X-Site /etc/nginx/sites-available/lab.conf"
```

**14.** Почини. Сейчас поможет только третий способ: handler уже никто не зовёт. Первые два нужны, чтобы сюда не попадать. Реши, нужен ли тебе `flush_handlers` в плейбуке, и оставь как решил.

---

## Грабли

| что видишь | что это |
|---|---|
| `The requested handler 'reload nginx' was not found in either the main handlers list nor in the listening handlers list` | имя в `notify` не совпало с `name` handler-а, регистр тоже важен. Ошибка появляется, только когда задача дала `changed`. Пока изменений нет, опечатку не видно |
| `Unable to reload service nginx: Job for nginx.service failed.` | reload с битым конфигом. Строку с ошибкой покажет `nginx -t` |
| `a duplicate default server for 0.0.0.0:80 in /etc/nginx/sites-enabled/lab.conf:2` | не убрал симлинк `sites-enabled/default`: два сайта с `default_server` на одном порту |
| `unknown directive "oops" in /etc/nginx/sites-enabled/lab.conf:5` | так выглядит ошибка из задания 7: имя файла и номер строки |

## На собесе

1. Зачем нужны handlers? Когда handler запускается и сколько раз?
2. Задача позвала handler, а следующая за ней задача упала. Что будет с handler-ом и чем это плохо?
3. Как сделать, чтобы Ansible не положил nginx битым конфигом?
4. В handler-е для nginx ставить reload или restart? Почему?

## Готово, когда

`./lab.sh check 4` показывает все «ок»: заголовок `X-Served-By` на обоих серверах, сайт `default` убран, `nginx -t` проходит, конфиг на диске совпадает с тем, что отдаёт nginx, повторный прогон ничего не меняет.
