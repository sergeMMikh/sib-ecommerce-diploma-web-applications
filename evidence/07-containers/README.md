# Evidence 07 — Контейнеры и конфигурация

## Runtime inspection

Выполнен `docker inspect` запущенных frontend/backend контейнеров. Санитаризированный листинг: [docker-runtime-inspect.txt](./docker-runtime-inspect.txt).

Подтверждено:

| Проверка | Backend | Frontend |
|---|---|---|
| Privileged | `false` — PASS | `false` — PASS |
| Explicit non-root `User` | отсутствует — FINDING | отсутствует — hardening не подтверждён |
| Read-only root FS | `false` — hardening отсутствует | `false` — hardening отсутствует |
| Capability drop | не настроен | не настроен |
| `SecurityOpt` | не настроен | не настроен |
| Healthcheck | отсутствует | отсутствует |
| Host port binding | `9999` → `0.0.0.0`/`::` | `8888` → `0.0.0.0`/`::` |

Для backend отсутствие explicit `User` согласуется с Semgrep-находкой `Dockerfile missing-user`. Публикация портов на всех интерфейсах ранее фиксировалась в evidence пункта 1 и здесь рассматривается как часть runtime-hardening, а не как отдельная новая уязвимость.

## Trivy image scan

После неудачного первичного запуска по Compose container names сканирование повторено по локальным immutable image IDs:

- backend: `a68f8d87c946`;
- frontend: `142c29187ec5`.

Первичная ошибочная попытка сохранена отдельно для воспроизводимости: [trivy-image-attempt.txt](./trivy-image-attempt.txt). Она не учитывается как результат security scan.

### Backend

Санитаризированная выжимка: [trivy-backend-summary.txt](./trivy-backend-summary.txt).

Trivy определил базовый userspace как Debian 10.8 и сообщил:

| Scope | Total | HIGH | CRITICAL |
|---|---:|---:|---:|
| OS packages | 538 | 217 | 53 |
| Java/JAR findings | 665 | 284 | 44 |

Эти значения являются scanner findings и не складываются в число уникальных эксплуатируемых уязвимостей. В образе присутствуют приложение и многочисленные артефакты `/root/.gradle/caches/...`, из-за чего отчёт содержит build-time зависимости и повторяющиеся находки.

Наличие Gradle cache в runtime image также объясняет чрезмерный размер backend-образа и свидетельствует об отсутствии минимизации финального image. Рекомендуется multi-stage build с переносом в runtime-слой только необходимых артефактов.

### Frontend

Санитаризированная выжимка: [trivy-frontend-summary.txt](./trivy-frontend-summary.txt).

Для Debian 10.8 Trivy сообщил:

| Scope | Total | HIGH | CRITICAL |
|---|---:|---:|---:|
| OS packages | 445 | 159 | 43 |

Большая часть результата относится к устаревшему базовому userspace. Количество findings не означает соответствующее количество независимо эксплуатируемых уязвимостей; необходим триаж достижимости и фактического использования пакетов.

## Связь с предыдущими пунктами

Credential `/src/fcm.json`, обнаруженный в backend image, относится к пункту 4 «Поиск секретов» и здесь повторно как отдельная находка не учитывается.

Mutable image references и публикация портов были впервые зафиксированы в evidence пункта 1. В пункте 7 они используются как входные данные для оценки container hardening.

## Итог

`FINDING` — container hardening недостаточен, а оба образа построены на устаревшем Debian 10.8 и содержат большое количество HIGH/CRITICAL vulnerability findings. Backend дополнительно содержит build-time Gradle cache и не задаёт явного non-root пользователя.

Основные рекомендации:

1. Перейти на актуальные минимальные base images.
2. Для backend использовать multi-stage build и исключить Gradle/build cache из runtime image.
3. Запускать контейнеры от непривилегированного пользователя.
4. По возможности включить read-only root filesystem, минимизировать capabilities и задать security options.
5. Добавить healthcheck.
6. Обновить OS/application dependencies с известными HIGH/CRITICAL advisory и повторить Trivy scan.
7. После пересборки фиксировать и проверять immutable digest/ID образов.
