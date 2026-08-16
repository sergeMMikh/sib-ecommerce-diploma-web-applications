# Backend attack surface — endpoint matrix

Источник: статический анализ контроллеров и конфигурации Spring Security репозитория `netology-code/necommerce-backend`.

Роли в таблице указаны по аннотациям `@PreAuthorize`. Если аннотация отсутствует, маршрут отмечен как `public*`: глобальная конфигурация Spring Security использует `anyRequest().permitAll()`. Фактическая доступность маршрутов должна быть подтверждена динамической проверкой на локальном стенде.

| Метод | Маршрут | Роль по коду | Объект / данные |
|---|---|---|---|
| POST | `/api/avatars` | `USER` | загрузка файла аватара |
| GET | `/api/products/{productId}/comments` | `public*` | комментарии товара |
| POST | `/api/products/{productId}/comments` | `USER` | создание комментария |
| DELETE | `/api/products/{productId}/comments/{id}` | `ADMIN` или `USER` | удаление комментария |
| POST | `/api/products/{productId}/comments/{id}/likes` | `USER` | лайк комментария |
| DELETE | `/api/products/{productId}/comments/{id}/likes` | `USER` | удаление лайка комментария |
| POST | `/api/media` | `USER` | загрузка media-файла |
| GET | `/api/orders` | `MANAGER` | все заказы |
| GET | `/api/orders/my` | `USER` | заказы текущего пользователя |
| GET | `/api/orders/{id}` | `public*` | конкретный заказ |
| POST | `/api/orders` | `public*` | создание заказа: `productId`, `phone` |
| POST | `/api/orders/{id}/status` | `MANAGER` | изменение статуса заказа |
| GET | `/api/products` | `public*` | список товаров |
| GET | `/api/products/{id}` | `public*` | конкретный товар |
| POST | `/api/products` | `ADMIN` | создание/изменение товара |
| DELETE | `/api/products/{id}` | `public*` | удаление товара |
| POST | `/api/products/{id}/likes` | `USER` | лайк товара |
| DELETE | `/api/products/{id}/likes` | `USER` | удаление лайка товара |
| POST | `/api/pushes` | `public*`, профиль `production` | push-токен и сообщение |
| POST | `/api/users/registration` | `public*` | `login`, `pass`, `name`, необязательный файл |
| POST | `/api/users/creation` | `ADMIN` | создание пользователя: `login`, `pass`, `name`, `avatar`, `roles` |
| POST | `/api/users/authentication` | `public*` | `login`, `pass`; аутентификация |
| POST | `/api/users/push-tokens` | `public*` | push-токен |

## Публикация файлов

Помимо 23 API-endpoint'ов приложение публикует media-файлы через маршрут `/media/**`. Он настроен через Spring `ResourceHandler`; `/media/*` также исключён из Spring Security filter chain.

## Точки для последующей динамической проверки

Особого внимания требуют маршруты без `@PreAuthorize`, изменяющие или возвращающие потенциально чувствительные объекты: `GET /api/orders/{id}`, `POST /api/orders`, `DELETE /api/products/{id}` и `POST /api/users/push-tokens`. На данном этапе они рассматриваются как кандидаты на проверку контроля доступа, а не как подтверждённые уязвимости.
