# DnD Hub

A full-stack toolkit for Dungeon Masters and homebrew creators. Manage campaigns, build encounters, and bring your world to life with AI-powered assistants for characters, creatures, spells, maps, and more.

---

## Progress

| Layer | Status | Notes |
|---|---|---|
| 🗄️ Database schema | ✅ Complete | Migrations for users, compendium, sessions and homebrew |
| 🌱 SRD seeds | 🔜 Pending | Import SRD 2014/2024 content from dnd5eapi.co |
| ⚙️ Backend | 🟡 Started | Flask REST API with health check endpoint, deployed on Render |
| 🎨 Frontend | 🔜 Pending | React + Vite SPA |

---

## Tech stack

| Layer | Technology | Hosting |
|---|---|---|
| Frontend | React + Vite | Vercel |
| Backend | Flask (Python) | Render |
| Database | Supabase (PostgreSQL) | Supabase cloud |

---

## Repository structure

- `backend/` — REST API built with Flask
- `frontend/` — Single-page app built with React
- `database/migrations/` — SQL migrations for Supabase (run in order)
- `database/seeds/` — Seed data for sources and SRD content

---

## Features

**Session management**
- [ ] Session creation and management
- [ ] Character upload and sharing
- [ ] Collaborative session content

**Tools**
- [ ] Dice roller
- [ ] Encounter calculator

**AI-assisted creators**
- [ ] Character creator
- [ ] Creature creator
- [ ] Spell creator
- [ ] Race creator
- [ ] Class creator
- [ ] Item creator
- [ ] Puzzle generator
- [ ] Map creator
- [ ] Plot writer

**AI assistants**
- [ ] Character & creature interpreter
- [ ] Dungeon Master

---

## Deployment

### Database (Supabase)

1. Create a new project at [supabase.com](https://supabase.com)
2. Go to **SQL Editor** and run each migration file in order:
   ```
   database/migrations/001_users_and_sources.sql
   database/migrations/002_compendium.sql
   database/migrations/003_sessions_and_homebrew.sql
   ```
3. Run the seed files:
   ```
   database/seeds/001_sources.sql
   ```
4. Copy your project's **URL**, **anon key** and **service role key**
   from **Project Settings → API** — you'll need them for the backend.

### Backend (Render)

The backend is deployed at `https://dnd-hub-1sf8.onrender.com`.

1. Fork or clone the repository
2. Create a new **Web Service** on [render.com](https://render.com)
3. Configure the service:
   - **Root Directory:** `backend`
   - **Build Command:** `pip install uv && uv sync --frozen`
   - **Start Command:** `uv run gunicorn "app:create_app()"`
4. Add the following environment variables:
```
   FLASK_SECRET_KEY=your-secret-key-here
   FLASK_ENV=production
   CORS_ORIGINS=https://your-frontend.vercel.app
```

### Frontend (Vercel)

> 🔜 Instructions will be added once the frontend is implemented.

---

## Local development

### Backend

1. Navigate to the `backend/` directory
2. Copy the environment file and fill in your values:
```bash
   cp .env.example .env
```
3. Install dependencies:
```bash
   uv sync
```
4. Run the development server:
```bash
   uv run python run.py
```
5. Verify the health check:
```bash
   curl http://localhost:5000/api/health
```