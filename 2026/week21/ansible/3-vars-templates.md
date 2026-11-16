# Блок 3. Переменные, факты, шаблоны

Цель: один плейбук и один шаблон, а страницы на серверах разные: каждый сервер показывает своё имя, IP и заголовок.

Время: около 50 минут.

---

## Шаг 1. Переменные

### Теория

- `{{ имя }}` подставляет значение переменной
- если значение в YAML начинается с `{{`, всю строку берут в кавычки: `name: "{{ pkg }}"`

Где переменные лежат, от слабого к сильному:

1. `group_vars/all.yml` — для всех серверов
2. `group_vars/web.yml` — для группы `web`
3. `host_vars/web1.yml` — для одного сервера
4. `vars:` внутри play
5. `-e имя=значение` в командной строке

Правило: **чем конкретнее, тем сильнее, а командная строка сильнее всех**. В доке этот список из 22 пунктов, наизусть его никто не знает. Ещё два уровня добавятся в блоке 5.

- папки `group_vars/` и `host_vars/` Ansible находит сам, если они лежат рядом с инвентарём. Имя файла = имя группы или сервера
- посмотреть значение у каждого сервера: `ansible web -m debug -a "var=site_title"`
- все переменные одного сервера: `ansible-inventory --host web1`

### Руками

**1.** Создай `group_vars/web.yml`: строка `site_title` и список `packages` (nginx, htop, curl). В плейбуке задача с apt теперь ставит `"{{ packages }}"`. Модуль `apt` принимает список целиком, цикл не нужен.

**2.** Посмотри значение на серверах, оно одинаковое:

```bash
ansible web -m debug -a "var=site_title"
```

**3.** Создай `host_vars/web1.yml` с другим `site_title`. Повтори команду из задания 2: теперь значения разные.

**4.** Добавь к той же команде `-e site_title=boss`. Кто победил?

---

## Шаг 2. Факты и шаблоны

### Теория

**Факты** — сведения о сервере, которые Ansible собирает сам в начале каждого play (та самая задача `Gathering Facts`). Лежат в словаре `ansible_facts`:

| что | как достать |
|---|---|
| hostname | `ansible_facts['hostname']` |
| основной IP | `ansible_facts['default_ipv4']['address']` |
| ОС | `ansible_facts['distribution']`, `ansible_facts['distribution_version']` |
| память | `ansible_facts['memtotal_mb']` |

- посмотреть все: `ansible web1 -m setup`. С фильтром: `ansible web1 -m setup -a "filter=ansible_default_ipv4"`
- в выводе `setup` имена идут с префиксом `ansible_`, а внутри `ansible_facts[...]` пишутся без него
- в старых плейбуках факты пишут напрямую: `ansible_hostname`, `ansible_memtotal_mb`. Это пока работает, но с предупреждением, и в ansible-core 2.24 это уберут
- `gather_facts: false` в play выключает сбор. Прогон быстрее, но `ansible_facts` пустой

Есть переменные, которые не факты, а знания самого Ansible:

- `inventory_hostname` — имя сервера из инвентаря
- `groups` — группы и их серверы: `groups['web']`
- `hostvars` — переменные и факты другого сервера: `hostvars['web1']`

**Шаблон** — файл с подстановками. Модуль `template` работает как `copy`, но сначала подставляет переменные. Язык шаблонов называется Jinja2, файлы по соглашению лежат в `templates/` и кончаются на `.j2`:

```jinja
<h1>{{ title }}</h1>
{% if show_contacts %}
<p>mail: {{ email }}</p>
{% endif %}
<ul>
{% for user in users %}
  <li>{{ user }}</li>
{% endfor %}
</ul>
```

- `{{ }}` — вывести значение
- `{% %}` — логика: `if`, `for`
- как и `copy`, `template` меняет файл на сервере, только если результат отличается

### Руками

**5.** Напиши `templates/index.html.j2`. На странице должны быть:
- `site_title`
- имя сервера из инвентаря
- его IP и ОС из фактов
- список пакетов из `packages`, циклом

В плейбуке замени `copy` на `template`. `files/index.html` больше не нужен, удали.

**6.** Сначала `--check --diff`, потом настоящий прогон. `curl localhost:8101` и `curl localhost:8102`: страницы разные.

**7.** Второй прогон: `changed=0`.

---

## Шаг 3. register, when, loop

### Теория

```yaml
- name: Ask nginx for its version
  ansible.builtin.command: nginx -v
  register: nginx_version           # результат задачи положить в переменную
  changed_when: false

- name: Show it
  ansible.builtin.debug:
    msg: "{{ nginx_version.stderr }}"

- name: Only on small servers
  ansible.builtin.debug:
    msg: "мало памяти"
  when: ansible_facts['memtotal_mb'] < 2048     # в when скобки {{ }} не пишут

- name: Create users
  ansible.builtin.user:
    name: "{{ item }}"
  loop:
    - alice
    - bob
```

- `register`: в переменной лежат `stdout`, `stderr`, `rc`, `changed`. Посмотреть всё целиком: `debug` с `var: nginx_version`
- `when`: условие проверяется для каждого сервера отдельно. Не подошёл → в выводе `skipping`
- `loop`: задача выполняется по разу на каждый элемент списка, текущий элемент лежит в `item`

### Руками

**8.** Добавь в плейбук две задачи: узнать версию nginx и вывести строку вида `web1: nginx version: nginx/1.24.0 (Ubuntu)`. Учти, что `nginx -v` пишет в stderr.

**9.** Добавь задачу с `debug`, которая выполняется только на web1. В выводе у web2 должно быть `skipping`.

**10.** Одной задачей с `loop` создай каталоги `/opt/lab/logs` и `/opt/lab/cache`.

После всех трёх заданий второй прогон по-прежнему `changed=0`.

---

## Грабли

| что видишь | что это |
|---|---|
| `'site_titel' is undefined` | опечатка в имени, или переменная этому серверу не видна: файл в `group_vars/` назван не как группа |
| `YAML parsing failed: This may be an issue with missing quotes around a template block` | значение начинается с `{{` и не взято в кавычки |
| `Conditionals should not be surrounded by templating delimiters such as {{ }}` | в `when` написал `{{ }}`. Там сразу выражение, без скобок |
| `INJECT_FACTS_AS_VARS default to True is deprecated` | факт написан по-старому (`ansible_hostname`). Перепиши через `ansible_facts['hostname']` |
| задача на втором прогоне снова `changed` | у `command` нет `changed_when: false` |

## На собесе

1. Где можно задать переменную? Что победит: `group_vars`, `host_vars` или `-e`?
2. Что такое факты? Как их посмотреть? Зачем выключают их сбор?
3. Чем `template` отличается от `copy`?
4. Как выполнить задачу только на части серверов?

## Готово, когда

`./lab.sh check 3` показывает все «ок»: у web1 и web2 разный `site_title`, страницы кладутся через `template` и показывают имя своего сервера, повторный прогон ничего не меняет.
