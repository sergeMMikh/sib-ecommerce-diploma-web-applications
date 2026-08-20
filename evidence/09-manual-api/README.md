| ID | Проверка | Ожидаемый результат | Фактический результат | Статус |
|---|---|---|---|---|
| API-NEG-01 | `GET /api/products/999999` | `404`, без stack trace и внутренних деталей | `404 Not Found`, минимальный JSON | `PASS` |
| API-NEG-02 | `GET /api/products/abc` | `400`, без stack trace и внутренних деталей | `400 Bad Request`, минимальный JSON | `PASS` |