# Generic Product Ordering App

A self-contained, neighbourhood-scale ordering app for any set of products.
Same workflow as the vegetable-only FarmToFork app but fully generic, with a
real database (Cloudflare D1 / SQLite), product images in Cloudflare R2, and
everything running on Cloudflare's free tier.

```
generic-order-repo/
├── index.html              Customer app (mobile-first)
├── Manage/
│   └── menu.html           Admin console
├── worker/
│   ├── worker.js           Cloudflare Worker API (D1 + R2)
│   ├── wrangler.toml       Worker deploy config
│   └── package.json        Wrangler scripts
├── schema/
│   └── schema.sql          D1 (SQLite) schema + seed settings
└── README.md
```

## Architecture

| Component           | Service               | Free tier                     |
|---------------------|-----------------------|-------------------------------|
| Static pages        | Cloudflare Pages      | Unlimited                     |
| API                 | Cloudflare Worker     | 100k requests / day           |
| Database            | Cloudflare D1 (SQLite)| 5 GB, 5M reads / day          |
| Product images      | Cloudflare R2         | 10 GB storage                 |

Customer PINs are stored as **salted SHA-256 hashes** — never plaintext.
Admin never sees PINs; instead they issue a one-time reset code (6 chars,
24h expiry) and the customer enters it to set their own PIN.

Admin console requires **both** a bearer API token **and** an admin PIN —
a leaked token alone won't grant access.

---

## Setup guide (step by step)

### 1. Install wrangler and log in

```bash
npm i -g wrangler
wrangler login          # opens browser for OAuth
```

### 2. Create D1 database

```bash
cd worker
wrangler d1 create generic_order
```

It prints a `database_id`. Paste it into `worker/wrangler.toml`:

```toml
[[d1_databases]]
binding = "DB"
database_name = "generic_order"
database_id   = "PASTE-YOUR-ID-HERE"
```

### 3. Create R2 bucket

```bash
wrangler r2 bucket create generic-order-images
```

### 4. Apply the database schema

```bash
npm run schema:remote
# (or for local dev: npm run schema:local)
```

### 5. Set your Admin API Token

Pick a long random password-like string. You'll need it in two places:
the Worker secret store and the admin console.

```bash
wrangler secret put ADMIN_API_TOKEN
# Wrangler prompts you to paste the value — it's never stored in code.
```

### 6. Deploy the Worker

```bash
npm run deploy
```

Note the URL, e.g. `https://generic-order-api.your-subdomain.workers.dev`.

### 7. Bootstrap the admin PIN

The schema starts with empty admin PIN fields. Set an initial PIN in
two steps:

**Step A — compute the hash** (run locally):

```bash
python3 -c "import hashlib; print(hashlib.sha256(b'TEMPSALT:1234').hexdigest())"
```

Copy the 64-character hex string it prints.

**Step B — write it to D1** (paste the hex in place of `HASH_FROM_STEP_A`):

```bash
wrangler d1 execute generic_order --remote --command \
  "UPDATE settings SET value='TEMPSALT' WHERE key='admin_pin_salt'; UPDATE settings SET value='HASH_FROM_STEP_A' WHERE key='admin_pin_hash';"
```

Then sign in to the admin console with PIN `1234` and immediately change it
under **Settings → Change admin PIN**.

### 8. Deploy the static pages

1. Push this folder (`generic-order-repo/`) to a new GitHub repo.
2. Cloudflare dashboard → **Pages → Create project → Connect to Git**.
3. Build command: *(leave empty)*. Output directory: `/`.
4. Deploy.

Pages will serve `index.html` at root and `Manage/menu.html` at `/Manage/menu.html`.

### 9. Wire the customer app to the Worker

Edit `index.html` — near the top of the `<script>`:

```js
const CONFIG = {
  API_BASE: 'https://generic-order-api.your-subdomain.workers.dev',
  ...
};
```

The admin console (`Manage/menu.html`) asks for the API URL at sign-in
time, so no edit needed there.

### 10. First-time store setup (via admin console)

1. Visit `/Manage/menu.html`.
2. Enter the Worker URL, your ADMIN_API_TOKEN, and admin PIN. Sign in.
3. **Settings** — fill store name, currency, UPI ID, admin phone, etc.
4. **Categories** — create categories (optional emoji per category).
5. **Products** — create products with name, unit, price, and **image**
   (upload JPG/PNG up to 5 MB, or paste a URL).
6. **Customers** — add each allowed phone number.
7. For each customer, click **Reset PIN** → get a 6-char code → share it
   (e.g. via WhatsApp). They go to the customer app, tap "Forgot PIN /
   got a reset code?", enter phone + code + new PIN.

---

## Differences from the vegetable-ordering app

1. **Database**: D1 (SQLite) replaces Google Sheets.
2. **Product images**: Every product can have an image (R2-hosted);
   shown in a phone-friendly grid.
3. **PIN security**: Admin never sees PINs. Token-based resets only.
4. **Admin auth**: Bearer token + admin PIN (two factors).
5. **Fully generic**: Categories, units, currency, store name — all
   admin-configurable. Nothing vegetable-specific is hardcoded.

Everything else (sign-in, cart, order history, UPI pay buttons, QR code,
WhatsApp notify, cancel, change PIN) works exactly as before.

---

## API quick reference

All admin endpoints require both headers:

```
Authorization: Bearer <ADMIN_API_TOKEN>
X-Admin-Pin: <admin PIN>
```

| Method | Path                             | Auth  | Purpose                          |
|--------|----------------------------------|-------|----------------------------------|
| GET    | `/api/settings`                  | pub   | Non-secret store settings        |
| GET    | `/api/menu`                      | pub   | Categories + products            |
| GET    | `/api/verify?phone=&pin=`        | pub   | Verify customer credentials      |
| GET    | `/api/orders?phone=&pin=`        | cust  | Customer's order history         |
| POST   | `/api/orders`                    | cust  | Place order                      |
| POST   | `/api/payment`                   | cust  | Claim payment                    |
| POST   | `/api/cancel`                    | cust  | Cancel order                     |
| POST   | `/api/pin-change`                | cust  | Change PIN (old → new)           |
| POST   | `/api/pin-reset`                 | cust  | Use reset token to set new PIN   |
| GET    | `/api/admin/orders`              | admin | List all orders                  |
| POST   | `/api/admin/notify`              | admin | Mark orders as notified          |
| POST   | `/api/admin/order-status`        | admin | Set order/payment status         |
| GET    | `/api/admin/customers`           | admin | List customers                   |
| POST   | `/api/admin/customers`           | admin | Create/update customer           |
| POST   | `/api/admin/pin-reset`           | admin | Issue reset token for customer   |
| GET    | `/api/admin/products`            | admin | List products                    |
| POST   | `/api/admin/products`            | admin | Create/update product            |
| POST   | `/api/admin/products/delete`     | admin | Delete product                   |
| GET    | `/api/admin/categories`          | admin | List categories                  |
| POST   | `/api/admin/categories`          | admin | Create/update category           |
| POST   | `/api/admin/categories/delete`   | admin | Delete category                  |
| POST   | `/api/admin/settings`            | admin | Save store settings              |
| POST   | `/api/admin/admin-pin`           | admin | Change admin PIN                 |
| POST   | `/api/admin/image-upload`        | admin | Upload product image to R2       |
| POST   | `/api/admin/image-delete`        | admin | Delete image from R2             |
