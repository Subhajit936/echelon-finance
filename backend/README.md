# Echelon Finance Backend

Production-ready REST API for the Echelon Finance Flutter app, built with Node.js, Express, and MongoDB (Mongoose).

## Stack

- **Runtime**: Node.js 18+
- **Framework**: Express 4
- **Database**: MongoDB via Mongoose 8
- **Auth**: Bearer token (env-configured)
- **Deployment**: Railway (Nixpacks)

---

## Quick Start

### 1. Install dependencies

```bash
npm install
```

### 2. Configure environment

```bash
cp .env.example .env
# Edit .env with your MongoDB URI and token
```

### 3. Run in development

```bash
npm run dev
```

### 4. Run tests

```bash
npm test
```

---

## Environment Variables

| Variable          | Description                                      | Required |
|-------------------|--------------------------------------------------|----------|
| `MONGODB_URI`     | MongoDB connection string (Atlas or self-hosted) | Yes      |
| `PERSONAL_TOKEN`  | Bearer token for API auth (omit to disable auth) | No       |
| `PORT`            | HTTP port (default: 3000)                        | No       |
| `NODE_ENV`        | `development` / `production` / `test`            | No       |

---

## Authentication

All `/api/*` endpoints (except `/api/health`) require a bearer token when `PERSONAL_TOKEN` is set:

```
Authorization: Bearer your-secret-token-here
```

If `PERSONAL_TOKEN` is **not** set, auth is skipped (development mode).

---

## API Reference

### Health

| Method | Path          | Description          |
|--------|---------------|----------------------|
| GET    | /api/health   | Health check         |

### Transactions

| Method | Path                                     | Description                                |
|--------|------------------------------------------|--------------------------------------------|
| GET    | /api/transactions                        | Paginated list (offset, limit, search, category, from, to) |
| POST   | /api/transactions                        | Create transaction                         |
| DELETE | /api/transactions/:id                    | Delete transaction                         |
| GET    | /api/transactions/exists                 | Duplicate check (merchant, amount, date)   |
| GET    | /api/transactions/recent?n=5             | Last N transactions                        |
| GET    | /api/transactions/summary/monthly        | Monthly totals + daily average             |
| GET    | /api/transactions/summary/net-worth      | Net worth calculation                      |
| GET    | /api/transactions/breakdown/category     | Expense breakdown by category              |
| GET    | /api/transactions/breakdown/daily        | Daily expense totals for N days            |
| GET    | /api/transactions/savings/monthly        | Monthly savings for N months               |

### Goals

| Method | Path                          | Description                    |
|--------|-------------------------------|--------------------------------|
| GET    | /api/goals                    | All goals                      |
| GET    | /api/goals/active             | Active goals only              |
| POST   | /api/goals                    | Create goal                    |
| PUT    | /api/goals/:id                | Update goal                    |
| DELETE | /api/goals/:id                | Delete goal                    |
| POST   | /api/goals/:id/contribute     | Add contribution amount        |

### Budgets

| Method | Path                     | Description                              |
|--------|--------------------------|------------------------------------------|
| GET    | /api/budgets/current     | Current-period budgets with spent amounts|
| POST   | /api/budgets             | Upsert budget by category                |
| DELETE | /api/budgets/:id         | Delete budget                            |

### Investments

| Method | Path                           | Description                       |
|--------|--------------------------------|-----------------------------------|
| GET    | /api/investments               | All investments                   |
| GET    | /api/investments/total-value   | Sum of portfolio value            |
| GET    | /api/investments/allocation    | Value grouped by asset class      |
| POST   | /api/investments               | Upsert investment                 |
| DELETE | /api/investments/:id           | Delete investment                 |
| POST   | /api/investments/snapshots     | Add portfolio snapshot            |
| GET    | /api/investments/snapshots     | Get snapshots (limit=30)          |

### Profile

| Method | Path          | Description                              |
|--------|---------------|------------------------------------------|
| GET    | /api/profile  | Get profile (auto-creates default)       |
| PUT    | /api/profile  | Upsert profile fields                    |

### Chat

| Method | Path       | Description               |
|--------|------------|---------------------------|
| GET    | /api/chat  | Recent messages (limit=50)|
| POST   | /api/chat  | Insert message            |
| DELETE | /api/chat  | Clear all messages        |

---

## Date Fields

All `date` fields accept **millisecond timestamps** (JavaScript `Date.now()` / Flutter `DateTime.millisecondsSinceEpoch`). The API converts them internally with `new Date(Number(ms))`.

## ID Fields

All models use Flutter-generated UUIDs as `_id` (String), not MongoDB ObjectIds.

---

## Deployment on Railway

1. Create a new Railway project and connect your repo.
2. Add `MONGODB_URI` and `PERSONAL_TOKEN` as environment variables.
3. Railway auto-detects the `railway.json` configuration and uses `node src/server.js` as the start command.
4. The health check endpoint `/api/health` is configured for Railway's health probe.
