# Ansible: теория, потом руками

Программа из 7 блоков. Блок состоит из 2–3 шагов. Шаг = кусок теории на 5 минут и сразу практика по нему. Один блок занимает 30–60 минут.

Всё делается на стенде: три «сервера» (Ubuntu 24.04 с systemd и sshd) в контейнерах на ноуте. Ansible ходит на них по SSH, как на обычные VPS.

| блок | тема | время | что закрывает на собесе |
|---|---|---|---|
| [1](1-inventory.md) | Inventory, ad-hoc, модули | 40 мин | что такое Ansible, agentless, ad-hoc, идемпотентность |
| [2](2-playbook.md) | Playbook и идемпотентность | 50 мин | сущности Ansible, как читать прогон, `--check` |
| [3](3-vars-templates.md) | Переменные, факты, шаблоны | 50 мин | приоритет переменных, факты, template |
| [4](4-handlers.md) | Handlers | 45 мин | зачем handlers, reload и битый конфиг |
| [5](5-roles.md) | Роли | 50 мин | что такое роль, defaults и vars |
| [6](6-vault.md) | Секреты: vault | 30 мин | где хранить пароли |
| [7](7-rollout.md) | Балансировщик и раскатка по одному | 60 мин | `serial`, проверка после выката, push и pull |

Блоки идут по порядку: каждый следующий продолжает файлы предыдущего. К концу в этой папке лежит маленький, но настоящий Ansible-проект: инвентарь, три роли, секрет в vault, и всё поднимается на чистых серверах одной командой.

Если времени мало: блоки 1–5 дают базу, про которую спрашивают всегда. В 6 и 7 можно прочитать только теорию.

## Стенд

```bash
./lab.sh up
```

| сервер | SSH | HTTP с ноута | роль |
|---|---|---|---|
| web1 | `deploy@127.0.0.1:2201` | http://localhost:8101 | веб-сервер |
| web2 | `deploy@127.0.0.1:2202` | http://localhost:8102 | веб-сервер |
| lb1 | `deploy@127.0.0.1:2203` | http://localhost:8100 | балансировщик (блок 7) |

- на серверах пользователь `deploy`: вход по ключу `lab/key`, sudo без пароля
- серверы видят друг друга по именам `web1`, `web2`, `lb1`
- `./lab.sh ssh web1` — зайти на сервер и посмотреть руками
- `./lab.sh reset` — снести серверы и поднять чистые. Твои файлы в этой папке не трогает
- после перезагрузки ноута серверы стоят: снова `./lab.sh up`, всё настроенное на них остаётся
- стенд работает на podman, а не на docker: `docker ps` его не покажет, смотри `./lab.sh status`

## Как работать

- все свои файлы (инвентарь, плейбуки, роли) создаёшь прямо в этой папке, команды запускаешь отсюда
- открыл блок → прочитал теорию шага → сделал «Руками» → следующий шаг
- справка по любому модулю без интернета: `ansible-doc apt`. Короткая, только параметры: `ansible-doc -s apt`
- застрял на одном месте дольше 10–15 минут → пиши, подскажу, куда смотреть
- в конце блока: `./lab.sh check N` (или напиши «проверь N», серверы посмотрю сам), ответь вслух или в чат на вопросы «На собесе», заметки в свой README, коммит

## Что в папке

```
ansible.cfg        настройки Ansible для стенда, готовые. Прочитай, он короткий
lab.sh             управление стендом
lab/               образ сервера и проверки. В check.sh видны ответы, не читай заранее
fixme/             сломанные плейбуки для заданий «Почини»
1-inventory.md …   блоки
```

Писалось и проверялось на ansible-core 2.22. Все тексты ошибок в разделах «Грабли» настоящие, с этого стенда.

## Ссылки (официальная дока, английский)

- [Inventory](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html)
- [Ad-hoc команды](https://docs.ansible.com/projects/ansible/latest/command_guide/intro_adhoc.html)
- [Список встроенных модулей](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/index.html)
- [Playbooks](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_intro.html)
- [Переменные и их приоритет](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_variables.html)
- [Шаблоны](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_templating.html)
- [Handlers](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_handlers.html)
- [Роли](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_reuse_roles.html)
- [Vault](https://docs.ansible.com/projects/ansible/latest/vault_guide/index.html)
- [serial и стратегии](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_strategies.html)
- [Обработка ошибок](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_error_handling.html)
