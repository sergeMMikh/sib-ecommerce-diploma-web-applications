# Evidence 07 — Контейнеры и конфигурация

## Runtime inspection

Выполнен `docker inspect` запущенных frontend/backend контейнеров. Санитаризированный листинг: [docker-runtime-inspect.txt](./docker-runtime-inspect.txt).

Предварительно подтверждено:

| Проверка | Backend | Frontend |
|---|---|---|
| Privileged | `false` — PASS | `false` — PASS |
| Explicit non-root `User` | отсутствует — FINDING | отсутствует — требует оценки с учётом базового образа |
| Read-only root FS | `false` — hardening отсутствует | `false` — hardening отсутствует |
| Capability drop | не настроен | не настроен |
| `SecurityOpt` | не настроен | не настроен |
| Healthcheck | отсутствует | отсутствует |
| Host port binding | `9999` → `0.0.0.0`/`::` | `8888` → `0.0.0.0`/`::` |

Для backend отсутствие explicit `User` согласуется с уже подтверждённой Semgrep-находкой `Dockerfile missing-user`. Для frontend пустое `.Config.User` само по себе ещё не доказывает фактический UID процесса; это следует проверить командой `docker exec necommerce-frontend-1 id` либо по Dockerfile/base image.

Публикация портов на всех интерфейсах уже наблюдалась при фиксации стенда и здесь рассматривается как часть runtime-конфигурации, а не как новая независимая уязвимость.

## Trivy image/config

Первый запуск Trivy выполнен с Compose container names (`necommerce-backend-1`, `necommerce-frontend-1`), тогда как `trivy image` ожидает image reference. Оба запуска завершились до сканирования цели и не являются результатами security scan.

Санитаризированный листинг: [trivy-image-attempt.txt](./trivy-image-attempt.txt).

Повторить следует для:

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest \
  image --scanners vuln,misconfig \
  ghcr.io/netology-code/necommerce-backend
```

и:

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest \
  image --scanners vuln,misconfig \
  ghcr.io/netology-code/necommerce-frontend
```

Для воспроизводимости предпочтительно использовать уже зафиксированный image ID или registry digest.

## Связь с предыдущими пунктами

Credential `/src/fcm.json`, обнаруженный в backend image, относится к пункту 4 «Поиск секретов» и здесь повторно как отдельная находка не учитывается.

Mutable image references и публикация портов были впервые зафиксированы в evidence пункта 1. В пункте 7 они используются как входные данные для оценки container hardening.

## Статус

`IN PROGRESS` — runtime inspection выполнен; Trivy image scan необходимо повторить с корректными image references, после чего проверить image history и фактических runtime users/capabilities.
