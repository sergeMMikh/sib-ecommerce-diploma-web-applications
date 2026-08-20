# Evidence 10 — Authentication, sessions and authorization

## Scope

Проверяется фактическая матрица `anonymous / userA / userB / manager / admin × endpoint × object` на локальном стенде. Секретные значения (пароли и authentication tokens) в evidence не сохраняются.

Backend использует нестандартный для Bearer-схемы формат: значение токена передаётся непосредственно в HTTP-заголовке `Authorization`, без префикса `Bearer`.

## Test artifacts

- [authz-test-plan.yaml](./authz-test-plan.yaml) — декларативная матрица сценариев, ожидаемые результаты и destructive flags.
- [setup-and-run.sh](./setup-and-run.sh) — воспроизводимый набор setup/read-only/object-level запросов. Скрипт хранит токены только в shell variables и не печатает их.

## Runtime actors

На disposable local stand используются:

- `anonymous` — без `Authorization`;
- `userA` — `ROLE_USER`;
- `userB` — `ROLE_USER`;
- `manager1` — `ROLE_MANAGER`, создан через admin-only `/api/users/creation`;
- `admin` — автоматически создаваемая локальная административная учётная запись.

Raw token/password values intentionally omitted.

## Authentication / role-level results

| ID | Проверка | Результат | Статус |
|---|---|---|---|
| AUTH-01 | неверный пароль для `userA` | HTTP 400, без stack trace/внутренних деталей | PASS |
| AUTH-02 | anonymous → `GET /api/orders` | HTTP 403 | PASS |
| AUTH-03 | `ROLE_USER` → `GET /api/orders` | HTTP 403 | PASS |
| AUTH-04 | `ROLE_MANAGER` → `GET /api/orders` | HTTP 200 | PASS |
| AUTH-05 | `ROLE_USER` → `GET /api/orders/my` | HTTP 200 | PASS |
| AUTH-13 | `ROLE_USER` пытается создать `ROLE_ADMIN` через `/api/users/creation` | HTTP 403 | PASS |

Повторная регистрация уже существующих логинов возвращает HTTP 500. Это относится к обработке ошибок/валидации пункта 9, а не к обходу авторизации пункта 10.

## Confirmed object-level authorization finding

Для `userA` создан заказ `id=1` с тестовым номером телефона; для `userB` создан отдельный заказ `id=2`. После этого выполнена проверка доступа к заказу `userA`.

| ID | Actor | Запрос к заказу userA | Фактический результат | Статус |
|---|---|---|---|---|
| AUTH-08 | anonymous | `GET /api/orders/1` | HTTP 200, возвращены данные заказа, включая `ownerId`, `ownerName`, `ownerPhone`, данные товара и статус | FINDING |
| AUTH-09 | userB | `GET /api/orders/1` | HTTP 200, возвращены те же данные чужого заказа | FINDING |
| AUTH-10 | userA | `GET /api/orders/1` | HTTP 200 | PASS для владельца |

### AUTHZ-BOLA-01 — чтение заказа без проверки объекта/владельца

**Описание.** Endpoint `GET /api/orders/{id}` возвращает заказ по идентификатору без обязательной аутентификации и без проверки принадлежности объекта текущему пользователю.

**Динамическое подтверждение.** Один и тот же заказ `userA` был успешно прочитан:

1. анонимным запросом без заголовка `Authorization`;
2. другим пользователем `userB` с валидным `ROLE_USER` token.

В ответе присутствуют персональные/заказные данные, включая тестовое поле `ownerPhone`. Значение телефона в итоговых evidence следует сохранять только в маскированном виде, например `7999******1`.

**Классификация.** Broken Object Level Authorization (BOLA) / IDOR / Broken Access Control.

**Влияние.** При предсказуемом или перебираемом идентификаторе заказа внешний пользователь может получать данные чужих заказов; отсутствие аутентификации расширяет воздействие до anonymous actor.

**Рекомендация.** Требовать аутентификацию для `GET /api/orders/{id}` и проверять object ownership либо разрешённую привилегированную роль на сервере. Проверку следует выполнять в controller/security policy и/или service layer до возврата DTO. Ретест: anonymous и другой `ROLE_USER` должны получать `401/403` либо нейтральный `404`, владелец и разрешённая служебная роль — `200`.

## Previously confirmed function-level authorization finding

В ходе пункта 9 дважды воспроизведено выполнение `DELETE /api/products/{id}` без `Authorization`: сервер вернул HTTP 200, а последующий GET объекта — 404. Эта находка переносится в матрицу пункта 10 как подтверждённый Broken Function Level Authorization / Broken Access Control сценарий. Деструктивный тест не выполняется автоматически в `setup-and-run.sh`.

## Public self-registration

Сам факт доступности публичной регистрации не классифицируется автоматически как уязвимость: для e-commerce self-registration может быть штатной функцией. В рассмотренном backend обычный registration endpoint не принимает параметр `roles`, а `UserService.register()` по умолчанию назначает `ROLE_USER` на серверной стороне.

Отдельно подлежат оценке rate limiting/anti-automation, требования к паролям и жизненный цикл authentication tokens. Token-management риски уже выявлены source review: generator использует deterministic `Random(9999)`, а scheduled invalidation не реализована.

## Status

`FINDING / IN PROGRESS` — подтверждены BOLA/IDOR для `GET /api/orders/{id}` и function-level bypass для анонимного удаления товара. Базовые role-level ограничения для списка заказов и admin-only user creation работают ожидаемо. Остаётся проверить token lifecycle/rate limiting и при необходимости дополнительные manager/admin/object scenarios.
