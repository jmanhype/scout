# priv/ - Private Application Resources

## Overview
Non-Elixir resources needed by the application, primarily database-related.

## Contents
- `repo/` - Ecto repository resources
  - `migrations/` - Database schema migrations

## Purpose
The priv directory is special in Elixir/OTP:
- Contents are included in releases
- Accessible via `:code.priv_dir(:app_name)`
- Typically contains static assets, migrations, certificates, etc.

## Database Migrations
Migrations define the database schema for:
- Studies table
- Trials table  
- Observations table

Run migrations with:
```bash
mix ecto.migrate
```