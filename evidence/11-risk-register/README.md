# Evidence 11 — Верификация и оценка риска

На этом этапе результаты автоматических и ручных проверок сведены в единый реестр. Повторяющиеся сообщения разных инструментов объединены, автоматические результаты перепроверены вручную, false positive и информационные замечания отделены от подтверждённых уязвимостей.

CVSS 4.0 используется для оценки **технической тяжести конкретной уязвимости**, а приоритет исправления дополнительно учитывает бизнес-контекст Necommerce. Поэтому CVSS severity и remediation priority не всегда совпадают.

## Подтверждённые находки

| ID | Находка | CWE / OWASP | Confidence | CVSS 4.0 | Приоритет |
|---|---|---|---|---|---|
| `F-01` | BOLA/IDOR: заказ доступен анонимно и другому пользователю по `GET /api/orders/{id}`, включая имя и телефон владельца | CWE-639 / OWASP API1:2023 Broken Object Level Authorization | High — воспроизведено runtime | **8.7 High** — `CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:H/VI:N/VA:N/SC:N/SI:N/SA:N` | **P0** |
| `F-02` | Анонимное удаление товара через `DELETE /api/products/{id}` | CWE-862 / OWASP API5:2023 Broken Function Level Authorization | High — воспроизведено дважды; удаление подтверждено последующим `404` | **8.7 High** — `CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:N/VI:H/VA:N/SC:N/SI:N/SA:N` | **P0** |
| `F-03` | Backend выводит сгенерированные admin credentials в `WARN`-лог | CWE-532 / OWASP A09:2021 Security Logging and Monitoring Failures | High — подтверждено source review и runtime | **8.5 High** — `CVSS:4.0/AV:L/AC:L/AT:N/PR:L/UI:N/VC:H/VI:H/VA:H/SC:N/SI:N/SA:N` | **P0** |
| `F-04` | Authentication tokens генерируются через deterministic `Random(9999)`; плановая инвалидация не реализована | CWE-330, CWE-613 / OWASP A07:2021 Identification and Authentication Failures | High для дефекта кода; эксплуатация предсказания token отдельно не воспроизводилась | Не присваивается как единой runtime-уязвимости без подтверждения эксплуатационного сценария | **P1** |
| `F-05` | GCP service-account JSON (`/src/fcm.json`) включён в backend image | CWE-798 / OWASP A02:2021 Cryptographic Failures / secret exposure | High для наличия credential; validity/IAM impact неизвестны | Не присваивается без подтверждения действительности ключа и доступных IAM-прав | **P0** до ротации/проверки владельцем |
| `F-06` | Frontend содержит прямые и транзитивные зависимости с известными security advisory | CWE-1104 / OWASP A06:2021 Vulnerable and Outdated Components | High для наличия advisory; применимость отдельных CVE требует триажа | Используются vendor/CVE scores отдельных компонентов; агрегированный CVSS не рассчитывается | **P1** |
| `F-07` | Оба runtime image основаны на устаревшем Debian и содержат большое количество HIGH/CRITICAL advisory; backend image включает Gradle cache/build-time JAR | CWE-1104 / OWASP A06:2021 | High для состава образов; применимость отдельных CVE требует триажа | Агрегированный CVSS не рассчитывается | **P1** |
| `F-08` | Backend запускается без явно заданного non-root `USER`; root filesystem writable, capability drop/SecurityOpt не настроены | CWE-250 / OWASP A05:2021 Security Misconfiguration | High для конфигурации | CVSS не используется для совокупного hardening finding | **P2** |
| `F-09` | GitHub Actions используют mutable action tags/branches вместо полного commit SHA; обязательный security gate по публичным workflow не доказан | CWE-829 / OWASP A08:2021 Software and Data Integrity Failures | High для mutable references, Medium для process impact | CVSS не рассчитывается для процессного/supply-chain control finding | **P2** |
| `F-10` | Frontend не возвращает ряд защитных HTTP headers и раскрывает версию nginx | CWE-693 / OWASP A05:2021 Security Misconfiguration | Medium–High после ZAP Baseline; эксплуатация не демонстрировалась | Не оценивается как одна самостоятельная CVSS vulnerability | **P2** |
| `F-11` | Повторная регистрация существующего login приводит к `HTTP 500 Internal Server Error` | CWE-755 | High — воспроизводится | CVSS не присваивается: подтверждён дефект error handling, но самостоятельное security impact не показано | **P3** |

## Обоснование CVSS для ключевых уязвимостей

### F-01 — BOLA/IDOR заказа

`CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:H/VI:N/VA:N/SC:N/SI:N/SA:N` → **8.7 High**.

- `AV:N` — эксплуатация выполняется обычным HTTP-запросом к API.
- `AC:L`, `AT:N` — специальных условий не требуется; достаточно известного/подобранного ID.
- `PR:N`, `UI:N` — endpoint успешно возвращает заказ без authentication и без действий другого пользователя.
- `VC:H` — возможно чтение чужого заказа и персональных данных владельца; ID является простым последовательным идентификатором, поэтому проблема не ограничена единичным случайным объектом.
- Integrity/Availability и subsequent-system impact не подтверждены.

Приоритет установлен `P0`, поскольку находка напрямую соответствует бизнес-критичному сценарию утечки данных пользователей и заказов.

### F-02 — удаление товара без аутентификации

`CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:N/VI:H/VA:N/SC:N/SI:N/SA:N` → **8.7 High**.

Удаление выполняется удалённым анонимным запросом без специальных условий и приводит к несанкционированному изменению данных каталога. В соответствии с CVSS v4.0 Availability относится к функционированию сервиса, а удаление/модификация данных оценивается через Integrity; поэтому `VI:H`, но `VA:N`.

### F-03 — административный пароль в логах

`CVSS:4.0/AV:L/AC:L/AT:N/PR:L/UI:N/VC:H/VI:H/VA:H/SC:N/SI:N/SA:N` → **8.5 High**.

Для базовой оценки предполагается, что атакующий уже имеет ограниченный доступ к локальным/container logs (`AV:L`, `PR:L`). Получение plaintext admin password позволяет далее действовать с административными полномочиями, поэтому оценивается прямое серьёзное влияние на Confidentiality, Integrity и Availability.

## Дедупликация и false positive

Следующие результаты не учитываются как отдельные подтверждённые уязвимости:

- ZAP backend `Timestamp Disclosure - Unix` — **false positive / expected application data**: значение является штатным публичным полем `published` товара.
- Множественные Semgrep warnings о mutable GitHub Actions tags объединены в `F-09`, а не считаются отдельной находкой на каждую строку workflow.
- Множественные SCA/Trivy записи не суммируются как такое же количество уникальных уязвимостей: одна CVE может присутствовать в нескольких копиях dependency/cache; результаты объединены в `F-06`/`F-07` до component-level triage.
- `404` для отсутствующего объекта, `400` для невалидного ID/malformed request и `405` для неподдерживаемого HTTP method признаны ожидаемой обработкой ошибок; stack trace и внутренние Java/SQL details в ответах не обнаружены.
- Публичная self-registration сама по себе не признана уязвимостью: сервер назначает `ROLE_USER`, а попытка `ROLE_USER` вызвать admin-only `/api/users/creation` отклонена с `403`.
- Backend ZAP Baseline для трёх GET endpoint'ов после triage получил `PASS`; общий статус DAST остаётся `FINDING` из-за подтверждённых frontend hardening alerts.

## Единый порядок устранения

1. **P0:** закрыть anonymous/cross-user доступ к `/api/orders/{id}` и добавить object ownership check.
2. **P0:** запретить anonymous `DELETE /api/products/{id}` и централизовать function-level authorization.
3. **P0:** прекратить вывод admin credentials в логи; ротировать затронутые credentials.
4. **P0:** отозвать/ротировать найденный GCP credential и проверить IAM/audit logs владельцем; затем удалить его из source/build context и всех image layers.
5. **P1:** заменить deterministic token generator на криптографически стойкий механизм, ввести expiry/revocation и regression tests.
6. **P1:** обновить dependencies/base images, применить multi-stage build и удалить Gradle cache/build-time dependencies из runtime image.
7. **P2:** выполнить container/HTTP/CI hardening: non-root user, минимальные capabilities, immutable action/image references, security headers и blocking security gates.
8. После исправлений повторить точечные retest сценарии и сохранить evidence ожидаемых `401/403`, невозможности чтения чужого заказа и чистых SCA/Trivy/SAST результатов.

## Итог

После верификации основная системная проблема Necommerce — **непоследовательный контроль доступа**: часть routes корректно защищена (`/api/orders`, `/api/orders/my`, `/api/users/creation`), но отдельные object-level и function-level операции доступны в обход authentication/authorization.

Наиболее значимые находки подтверждены не только статическим анализом, но и runtime-воспроизведением. Автоматические результаты очищены от явных false positive и дубликатов. Итоговый статус пункта 11: **`FINDING`**.
