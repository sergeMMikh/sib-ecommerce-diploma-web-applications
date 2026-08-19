# Manual security review — backend

Источник: ручной анализ `netology-code/necommerce-backend` после Semgrep CE.

## Сводка

| ID | Область | Результат | Статус |
|---|---|---|---|
| SRC-01 | Global security rules | `anyRequest().permitAll()`; фактическая защита чувствительных операций зависит от `@PreAuthorize` и/или service-level checks | `FINDING / requires dynamic verification` |
| SRC-02 | Order object access | `GET /api/orders/{id}` не имеет `@PreAuthorize`; `OrderService.getById()` получает заказ только по ID и не проверяет владельца | `FINDING candidate — verify in point 10` |
| SRC-03 | Product deletion | `DELETE /api/products/{id}` не имеет `@PreAuthorize`; `ProductService.removeById()` не выполняет проверку роли/владельца | `FINDING candidate — verify in point 10` |
| SRC-04 | Authentication token generation | Токены генерируются `java.util.Random(9999)` с фиксированным seed | `FINDING` |
| SRC-05 | Token lifetime | Scheduled token invalidator содержит `TODO`; фактическая инвалидация/expiration токенов не реализована | `FINDING` |
| SRC-06 | Admin credential logging | При создании администратора сгенерированный пароль записывается в WARN-log | `FINDING` |
| SRC-07 | Push token ownership | `/api/users/push-tokens` не имеет `@PreAuthorize`; anonymous request сохраняет token с `userId=0` | `REVIEW / dynamic verification` |
| SRC-08 | File upload | Разрешены только JPEG/PNG по содержимому через Apache Tika; имя файла генерируется UUID | `PASS` для типа/имени; размер не ограничен в рассмотренном коде |
| SRC-09 | Media publication | `/media/**` публикуется ResourceHandler и исключён из security chain | `EXPECTED PUBLIC SURFACE / review exposure` |
| SRC-10 | CORS/CSRF | CORS разрешает `*` origins/methods/headers совместно с credentials; CSRF отключён, приложение stateless | `REVIEW` |

## Детали

### SRC-01 — глобальная конфигурация доступа

`AppWebSecurityConfigurerAdapter` включает method security, добавляет `AuthTokenFilter`, отключает CSRF, задаёт stateless sessions, после чего использует:

```kotlin
.authorizeRequests()?.anyRequest()?.permitAll()
```

Поэтому URL без `@PreAuthorize` не получают дополнительного глобального ограничения доступа. `/media/*` отдельно исключён из security chain.

### SRC-02 — доступ к заказу по ID

Контроллер:

```kotlin
@GetMapping("/{id}")
fun getById(@PathVariable id: Long) = service.getById(id)
```

Service layer:

```kotlin
fun getById(id: Long): Order {
    return repository
        .findById(id)
        .orElseThrow(::NotFoundException)
        .toDto()
}
```

Проверки текущего пользователя, владельца заказа или роли manager/admin в рассмотренном пути нет. Кодовая проверка классифицируется как кандидат BOLA/IDOR и должна быть подтверждена запросами anonymous/user A/user B в пункте 10.

### SRC-03 — удаление товара

`DELETE /api/products/{id}` не содержит `@PreAuthorize`. В `ProductService.removeById()` также отсутствует проверка роли до удаления объекта. Динамически необходимо проверить возможность удаления товара anonymous/USER.

### SRC-04 — предсказуемая генерация authentication tokens

`UserService` содержит:

```kotlin
private val random: Random = Random(9999)

private fun generateToken(length: Int = 128): String = ByteArray(length).apply {
    random.nextBytes(this)
}.let {
    Base64.getUrlEncoder().withoutPadding().encodeToString(it)
}
```

Используется обычный `java.util.Random` с постоянным seed `9999`. Последовательность генерируемых токенов детерминирована и повторяется при одинаковом начальном состоянии процесса. Для security token необходимо использовать криптографически стойкий источник случайности (`SecureRandom`) или стандартный механизм session/token framework.

### SRC-05 — отсутствие реализованной инвалидации токенов

`ScheduledTokenInvalidatorService` запускается по расписанию, но метод содержит только:

```kotlin
fun invalidate() {
    // TODO: implement invalidation
}
```

В рассмотренном коде срок действия/плановая очистка authentication tokens не реализованы. Необходимо дополнительно проверить наличие logout/revocation механизма и фактическое поведение старого токена.

### SRC-06 — пароль администратора в журнале

При автоматическом создании администратора `UserService.createAdminIfNotExists()` генерирует пароль и пишет его в лог:

```kotlin
logger.warn("admin user generated with login: ${it.login}, password: ${pass}")
```

Это подтверждает ранее наблюдавшееся раскрытие административных credentials в стартовых журналах стенда. Значение пароля в evidence не сохраняется.

### SRC-07 — push-token endpoint

`POST /api/users/push-tokens` не имеет `@PreAuthorize`. `saveToken()` использует:

```kotlin
val userId = principalOrNull()?.id ?: 0
```

То есть anonymous request обрабатывается и может связать push token с `userId=0`. Риск и возможность злоупотребления следует проверить динамически с тестовым token.

### SRC-08 — загрузка файлов

`MediaService` определяет MIME по содержимому через Apache Tika, принимает только JPEG/PNG и генерирует серверное имя через UUID. Это снижает риск path traversal через пользовательское имя и загрузки произвольного типа файла.

В рассмотренном service-коде отдельного ограничения размера файла не обнаружено; возможное глобальное multipart-ограничение необходимо проверить в application configuration.

### SRC-09 — публикация media

`AppWebMvcConfigurer` публикует `mediaLocation` через `/media/**`, а web security исключает `/media/*`. Публичность media является частью поверхности атаки и должна учитываться при тестах контроля доступа и content handling.

### SRC-10 — CORS и CSRF

CORS configuration задаёт wildcard для origins, methods и headers и одновременно `allowCredentials = true`. Конфигурация требует проверки фактических response headers в runtime. CSRF отключён; для stateless token API это может быть допустимо, если authentication действительно не основана на автоматически отправляемых browser cookies.

## Итог ручного review

Ручной анализ выявил security-relevant проблемы, которые не были обнаружены Semgrep в прикладном Kotlin-коде. Наиболее значимые подтверждённые по исходникам результаты: детерминированная генерация authentication tokens, отсутствие реализованной инвалидации токенов и вывод административного пароля в журнал.

Отсутствие object-level authorization для `GET /api/orders/{id}` и role check для `DELETE /api/products/{id}` подтверждено статически как отсутствие проверок в рассмотренном controller/service path, однако эксплуатационный статус следует подтвердить динамически в пункте 10.
