# Evidence 05 — Dependencies and SBOM

## Frontend dependency scan

Дата проверки: 17 августа 2026 года.

Проверен `package-lock.json` репозитория frontend с помощью Trivy filesystem scanner и `npm audit`.

### Trivy filesystem

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

Среди CRITICAL-находок присутствуют, в частности, `@babel/traverse` (CVE-2023-45133), `cipher-base` (CVE-2025-9287), `ejs` (CVE-2022-29078), `form-data` (CVE-2025-7783), `immer` (CVE-2021-23436), `json-schema` (CVE-2021-3918) и `loader-utils` (CVE-2022-37601).

Санитаризированный вывод с командой, итоговой статистикой и примерами CRITICAL-находок: [trivy-fs-frontend.txt](./trivy-fs-frontend.txt).

### npm audit

Корректный запуск выполнен из каталога `necommerce-frontend`, где расположен `package-lock.json`:

```bash
npm audit --json > npm-audit-frontend.json
```

`npm audit` сообщил 204 уязвимых package-level dependency entries:

| Severity | Count |
|---|---:|
| CRITICAL | 21 |
| HIGH | 60 |
| MODERATE | 116 |
| LOW | 7 |
| INFO | 0 |
| **Total** | **204** |

Из них прямыми уязвимыми зависимостями являются:

* `axios` — `HIGH`, уязвимый диапазон `<=0.32.0`, исправление доступно;
* `react-scripts` — `HIGH`; предлагаемое исправление — `react-scripts 5.0.1`, отмеченное npm как SemVer-major изменение.

Все 21 package-level `CRITICAL` результата являются транзитивными зависимостями (`isDirect=false`). Среди них: `@babel/traverse`, `cipher-base`, `ejs`, `elliptic`, `eventsource`, `form-data`, `immer`, `json-schema`, `loader-utils`, `request`, `tar`, `workbox-build` и другие.

Полный JSON-отчёт не помещается в репозиторий как evidence из-за избыточного объёма. Сохранена фильтрованная сводка с общими числами, прямыми уязвимыми зависимостями, всеми CRITICAL package-level результатами и признаком наличия исправления: [npm-audit-frontend-summary.txt](./npm-audit-frontend-summary.txt).

## Интерпретация

Результаты Trivy и `npm audit` нельзя складывать между собой: инструменты используют разные базы и правила агрегации, а многие записи относятся к одним и тем же пакетам и транзитивным цепочкам.

Количество 235 у Trivy и 204 у `npm audit` также не означает соответствующее количество независимо эксплуатируемых уязвимостей приложения. Для окончательной оценки необходимо отделить runtime-зависимости от dev/build-зависимостей, проверить достижимость уязвимого кода и применимость конкретных advisory к способу использования пакетов в Necommerce.

Отдельного внимания требует `axios`, поскольку это прямая зависимость frontend и `npm audit` классифицирует её как `HIGH`. Транзитивные CRITICAL-находки являются приоритетными кандидатами для триажа, но сам факт присутствия уязвимой build/dev-зависимости ещё не доказывает возможность эксплуатации через работающее web-приложение.

## Статус

`FINDING` — frontend содержит прямые и транзитивные зависимости с известными security advisory по данным двух независимых SCA-проверок.

SBOM и проверка backend-зависимостей на данном этапе ещё не завершены.
