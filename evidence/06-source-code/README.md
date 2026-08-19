# Evidence 06 — Source code review

## Semgrep CE

Исходный код frontend и backend проверен Semgrep CE с автоматическим набором Community rules (`--config auto`).

Первичный запуск завершён для обоих компонентов:

| Компонент | Targets | Rules run | Findings | Severity |
|---|---:|---:|---:|---|
| backend | 63 | 111 | 5 | 1 `ERROR`, 4 `WARNING` |
| frontend | 41 | 256 | 5 | 5 `WARNING` |

Сохранённые листинги запуска:

- [semgrep-backend-scan.txt](./semgrep-backend-scan.txt)
- [semgrep-frontend-scan.txt](./semgrep-frontend-scan.txt)

Фильтрованные результаты после первичного триажа:

- [semgrep-backend-summary.txt](./semgrep-backend-summary.txt)
- [semgrep-frontend-summary.txt](./semgrep-frontend-summary.txt)

### Результат первичного триажа

Semgrep не сообщил находок непосредственно в прикладном Kotlin-коде backend или JavaScript-коде frontend.

Все пять frontend-находок и четыре из пяти backend-находок относятся к GitHub Actions: используются изменяемые tag/branch references вместо pinning на полный commit SHA. Эти результаты подтверждают уже зафиксированное наблюдение пункта 3 «Репозитории и процесс разработки» и не учитываются как новые независимые уязвимости пункта 6.

Единственный backend-результат уровня `ERROR` относится к `Dockerfile`: отсутствует инструкция `USER` для запуска приложения от непривилегированного пользователя. Это подтверждает ранее наблюдавшийся запуск backend-контейнера от `root` и относится прежде всего к пункту 7 «Контейнеры и конфигурация».

Таким образом, автоматический SAST не выявил новых прикладных находок, но это не является доказательством отсутствия уязвимостей бизнес-логики и контроля доступа. Они требуют ручного review и динамической проверки.

## Ручной review

Дополнительно проверяются:

- Spring Security configuration и authentication/authorization flow;
- controllers и services, особенно операции с объектами и проверку принадлежности;
- обработка токенов и push-токенов;
- загрузка и публикация файлов;
- обработка чувствительных данных;
- логирование и возможность попадания чувствительных данных в журналы.

Особое внимание при backend-review уделяется маршрутам и объектам, отмеченным ранее в [матрице поверхности атаки](../02-attack-surface/endpoints.md).

## Статус

`IN PROGRESS` — автоматический Semgrep scan и первичный триаж выполнены; новых прикладных findings от Semgrep не получено. Ручная проверка security config, auth/authz, object access, токенов, файлов и логирования ещё продолжается.
