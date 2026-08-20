### 11. Верификация и оценка риска

Результаты автоматических и ручных проверок сведены в единый реестр: дубликаты объединены, автоматические alerts перепроверены вручную, false positive и информационные замечания отделены от подтверждённых уязвимостей. Для воспроизведённых технических уязвимостей выполнена оценка CVSS 4.0; отдельно установлен приоритет исправления с учётом бизнес-контекста приложения.

| ID | Подтверждённая находка | CWE / OWASP | CVSS 4.0 | Приоритет |
|---|---|---|---|---|
| `F-01` | BOLA/IDOR: `GET /api/orders/{id}` доступен анонимно и другому пользователю; раскрываются данные заказа и телефон владельца | CWE-639 / OWASP API1:2023 | **8.7 High** — `CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:H/VI:N/VA:N/SC:N/SI:N/SA:N` | **P0** |
| `F-02` | Анонимный `DELETE /api/products/{id}` фактически удаляет товар | CWE-862 / OWASP API5:2023 | **8.7 High** — `CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:N/VI:H/VA:N/SC:N/SI:N/SA:N` | **P0** |
| `F-03` | Backend выводит сгенерированные admin credentials в `WARN`-лог | CWE-532 / OWASP A09:2021 | **8.5 High** — `CVSS:4.0/AV:L/AC:L/AT:N/PR:L/UI:N/VC:H/VI:H/VA:H/SC:N/SI:N/SA:N` | **P0** |
| `F-04` | Authentication tokens генерируются через deterministic `Random(9999)`, плановая инвалидация не реализована | CWE-330, CWE-613 / OWASP A07:2021 | эксплуатационный сценарий предсказания token отдельно не воспроизводился | **P1** |
| `F-05` | GCP service-account JSON включён в backend image | CWE-798 | validity/IAM impact не проверялись; агрегированный CVSS не назначается | **P0** до ротации/проверки владельцем |
| `F-06` | Уязвимые/устаревшие frontend dependencies и контейнерные компоненты | CWE-1104 / OWASP A06:2021 | используются scores отдельных CVE; агрегированный CVSS не рассчитывается | **P1** |
| `F-07` | Ограниченный container hardening, mutable CI references и frontend HTTP security hardening | CWE-250/CWE-829/CWE-693 | configuration/process findings, единый CVSS не рассчитывается | **P2** |

При CVSS-оценке удаления товара Availability не повышалась: CVSS v4.0 относит удаление/изменение данных к Integrity, если сам сервис продолжает функционировать.

После ручной проверки ZAP backend `Timestamp Disclosure - Unix` классифицирован как **false positive / expected application data**: найденное значение является публичным полем `published`. Множественные Semgrep warnings о mutable tags объединены в одну supply-chain находку. Результаты SCA/Trivy не суммируются как равное число уникальных уязвимостей, поскольку одна CVE может присутствовать в нескольких copies/cache. Публичная self-registration сама по себе не признана уязвимостью: сервер назначает `ROLE_USER`, а попытка обычного пользователя вызвать admin-only `/api/users/creation` корректно возвращает `403`.

Наиболее критичной системной проблемой является **непоследовательный контроль доступа**: часть маршрутов корректно защищена ролями, однако отдельные object-level и function-level операции доступны без необходимых проверок. В первую очередь требуется закрыть доступ к чужим заказам и анонимное удаление товаров, прекратить вывод credentials в логи, ротировать найденные secrets, исправить lifecycle authentication tokens и после этого выполнить точечный retest.

Полный реестр, обоснование CVSS и результаты дедупликации: [evidence/11-risk-register](./evidence/11-risk-register/README.md).

**Итог пункта 11:** `FINDING` — подтверждённые находки унифицированы по CWE/OWASP, наиболее значимые runtime-уязвимости получили CVSS 4.0 score/vector и единый remediation priority.
