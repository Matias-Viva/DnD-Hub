# DnD Hub

A full-stack toolkit for Dungeon Masters and homebrew creators. Manage campaigns, build encounters, and bring your world to life with AI-powered assistants for characters, creatures, spells, maps, and more.

---

## Progress

| Layer | Status | Notes |
|---|---|---|
| 🗄️ Database schema | ✅ Complete | Migrations for users, compendium, sessions and homebrew |
| 🌱 SRD seeds | 🔜 Pending | Import SRD 2014/2024 content from dnd5eapi.co |
| ⚙️ Backend | 🔜 Pending | Flask REST API |
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

> 🔜 Instructions will be added once the backend is implemented.

### Frontend (Vercel)

> 🔜 Instructions will be added once the frontend is implemented.

---

## Local development

_Setup instructions will be added as the project is built._