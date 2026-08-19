# Evidence 06 — Source code review

## Semgrep CE

Исходный код frontend и backend проверяется Semgrep CE с автоматическим набором Community rules (`--config auto`).

Первичный запуск завершён для обоих компонентов:

| Компонент | Targets | Rules run | Findings |
|---|---:|---:|---:|
| backend | 63 | 111 | 5 |
| frontend | 41 | 256 | 5 |

Сохранённые листинги запуска:

- [semgrep-backend-scan.txt](./semgrep-backend-scan.txt)
- [semgrep-frontend-scan.txt](./semgrep-frontend-scan.txt)

Полные JSON-результаты на данном этапе не коммитятся. После просмотра результатов будут сохранены фильтрованные сводки с severity, rule ID, файлом, строкой и результатом ручной верификации.

Количество `Findings` и пометка Semgrep `blocking` не трактуются автоматически как подтверждённые уязвимости. HIGH/CRITICAL результаты подлежат ручной перепроверке в контексте исходного кода.

## Ручной review

Дополнительно проверяются:

- Spring Security configuration и authentication/authorization flow;
- controllers и services, особенно операции с объектами и проверку принадлежности;
- обработка токенов и push-токенов;
- загрузка и публикация файлов;
- обработка чувствительных данных;
- логирование и возможность попадания чувствительных данных в журналы.

Особое внимание при backend-review будет уделено маршрутам и объектам, отмеченным ранее в [матрице поверхности атаки](../02-attack-surface/endpoints.md).

## Статус

`IN PROGRESS` — автоматический Semgrep scan выполнен для frontend и backend; результаты ещё проходят классификацию и ручную верификацию.
