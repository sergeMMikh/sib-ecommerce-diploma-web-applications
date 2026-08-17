# Evidence 05 — Dependencies and SBOM

## Frontend dependency scan

Дата проверки: 17 августа 2026 года.

Проверен `package-lock.json` репозитория frontend с помощью Trivy filesystem scanner.

Команда:

```bash
docker run --rm \
  -v "$PWD:/work" \
  aquasec/trivy:latest \
  fs /work/necommerce-frontend
```

Trivy обнаружил 235 записей об уязвимостях зависимостей:

| Severity | Count |
|---|---:|
| CRITICAL | 20 |
| HIGH | 108 |
| MEDIUM | 87 |
| LOW | 20 |
| UNKNOWN | 0 |
| **Total** | **235** |

Полный список требует триажа: необходимо отделить runtime-зависимости от dev/build-зависимостей, проверить достижимость уязвимого кода и наличие исправленных версий. Поэтому количество записей Trivy не трактуется как 235 независимо эксплуатируемых уязвимостей приложения.

Среди CRITICAL-находок присутствуют, в частности, `@babel/traverse` (CVE-2023-45133), `cipher-base` (CVE-2025-9287), `ejs` (CVE-2022-29078), `form-data` (CVE-2025-7783), `immer` (CVE-2021-23436), `json-schema` (CVE-2021-3918) и `loader-utils` (CVE-2022-37601).

Попытка `npm audit --json` завершилась `ENOLOCK`: npm не обнаружил lockfile в каталоге, из которого была запущена команда. Этот запуск не используется как результат vulnerability scan; перед повтором необходимо перейти в каталог frontend или явно проверить расположение `package-lock.json`.

Санитаризированный вывод с командой, итоговой статистикой и примерами CRITICAL-находок: [trivy-fs-frontend.txt](./trivy-fs-frontend.txt).

## Статус

`FINDING` — frontend содержит большое число зависимостей с известными CVE по данным Trivy. Итоговая оценка риска будет дана после триажа применимости и разделения runtime/dev scope.

SBOM и проверка backend-зависимостей на данном этапе ещё не завершены.
