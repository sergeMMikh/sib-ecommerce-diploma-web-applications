# Authorization matrix — first run summary

Date: 2026-08-20
Target: local Necommerce backend (`http://127.0.0.1:9999`)

Raw authentication tokens and the generated admin password are intentionally omitted.

## Account setup observations

- `userA` and `userB` had already been registered earlier. Repeated calls to `/api/users/registration` returned HTTP `500 Internal Server Error`; this is treated as an input/error-handling observation for point 9, not as an authorization finding.
- Authentication of the existing users succeeded, allowing the script to obtain fresh tokens in memory.
- `manager1` was successfully created through the admin-only `/api/users/creation` endpoint (`HTTP 200`) and then authenticated.
- Public self-registration is not itself classified as a vulnerability because the registration endpoint assigns the default `ROLE_USER` server-side and does not accept a client-supplied roles parameter.

## Authentication / authorization results

| ID | Actor / request | Result | Assessment |
|---|---|---:|---|
| AUTH-01 | invalid password for `userA` | `400 Bad Request` | PASS — credentials rejected; no stack trace disclosed |
| AUTH-02 | anonymous `GET /api/orders` | `403 Forbidden` | PASS — manager-only collection denied |
| AUTH-03 | `ROLE_USER` (`userA`) `GET /api/orders` | `403 Forbidden` | PASS — user role denied |
| AUTH-04 | `ROLE_MANAGER` `GET /api/orders` | `200 OK` | PASS — expected manager access |
| AUTH-05 | `ROLE_USER` (`userA`) `GET /api/orders/my` | `200 OK` | PASS — expected own-orders endpoint access |
| AUTH-13 | `ROLE_USER` attempts `/api/users/creation` with `roles=ROLE_ADMIN` | `403 Forbidden` | PASS — direct role escalation blocked |

## Object-level authorization test status

Orders for `userA` and `userB` were not created during this run because the script assumed `productId=1`, and product 1 had previously been removed during the destructive anonymous DELETE test. Therefore `anonymous -> userA order`, `userB -> userA order`, and `userA -> own order` remain `NOT TESTED` for this run.

The test script has been updated to discover an existing product automatically before creating disposable orders.

## Existing confirmed authorization finding

Anonymous `DELETE /api/products/{id}` was previously reproduced manually: the endpoint returned `HTTP 200`, and a subsequent `GET` for the same product returned `404`. This remains a confirmed Broken Access Control / Broken Function Level Authorization finding and is included in the point 10 role matrix.

## Current status

`IN PROGRESS` — role-level restrictions tested so far behave correctly, while the previously identified anonymous product deletion remains a confirmed finding. BOLA/IDOR testing between `userA` and `userB` requires one more run with a valid product available.
