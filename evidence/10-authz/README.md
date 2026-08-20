# Evidence 10 — Authentication, sessions and authorization

## Scope

Проверяется фактическая матрица `anonymous / userA / userB / manager / admin × endpoint × object` на локальном стенде. Секретные значения (пароли и authentication tokens) в evidence не сохраняются.

Backend использует нестандартный для Bearer-схемы формат: значение токена передаётся непосредственно в HTTP-заголовке `Authorization`, без префикса `Bearer`.

## Test artifacts

- [authz-test-plan.yaml](./authz-test-plan.yaml) — декларативная матрица сценариев, ожидаемые результаты и destructive flags.
- [setup-and-run.sh](./setup-and-run.sh) — воспроизводимый набор setup/read-only/object-level запросов. Скрипт хранит токены только в shell variables и не печатает их.

## Initial observations

20 августа 2026 года на disposable local stand успешно зарегистрированы два тестовых пользователя `userA` и `userB`. Endpoint `/api/users/registration` вернул HTTP 200 и authentication token для каждого пользователя. При повторной аутентификации `/api/users/authentication` также возвращает новый token.

Raw token values intentionally omitted.

### Public self-registration

Сам факт доступности публичной регистрации не классифицируется автоматически как уязвимость: для e-commerce self-registration может быть штатной функцией. В рассмотренном backend обычный registration endpoint не принимает параметр `roles`, а `UserService.register()` по умолчанию назначает `ROLE_USER` на серверной стороне.

Проверяемые security-вопросы вокруг регистрации:

- можно ли самостоятельно получить повышенную роль через `/registration` (по коду — не ожидается);
- защищён ли admin-only `/api/users/creation` от `ROLE_USER`;
- есть ли ограничения частоты регистрации/аутентификации и защита от automation;
- как обрабатываются неверные credentials;
- как устроены срок жизни/revocation и непредсказуемость токенов.

Последние два token-management риска уже выявлены при source review: token generator использует deterministic `Random(9999)`, а scheduled invalidation не реализована. В пункте 10 проверяется их runtime-влияние и фактическая авторизация.

## Previously confirmed authorization finding

В ходе пункта 9 дважды воспроизведено выполнение `DELETE /api/products/1` без `Authorization`: сервер вернул HTTP 200, а последующий GET объекта — 404. Эта находка переносится в матрицу пункта 10 как подтверждённый Broken Function Level Authorization / Broken Access Control сценарий. Деструктивный тест не выполняется автоматически в `setup-and-run.sh`.

## Status

`IN PROGRESS` — test actors userA/userB созданы; далее выполняется role/object matrix, включая manager/admin, BOLA/IDOR и negative authentication cases.
