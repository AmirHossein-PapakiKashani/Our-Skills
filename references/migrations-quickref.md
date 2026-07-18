# Migration Quick Reference

> Migrations are **human territory** — agents flag commands; humans review and run.

## Contexts

| Context | Migrations Folder | Startup |
|---------|-------------------|---------|
| Admin | `Admin/Infrastructure/Migrations/` | `Admin/Api` |
| Customer | `Customer/Infrastructure/Migrations/` | `Customer/Api` |

Both use class `ApplicationDbContext` — `--context ApplicationDbContext` is **required**.

## Add migration

**Admin:**
```bash
dotnet ef migrations add [MigrationName] \
  --project Admin/Infrastructure \
  --startup-project Admin/Api \
  --context ApplicationDbContext \
  --output-dir Migrations
```

**Customer:**
```bash
dotnet ef migrations add [MigrationName] \
  --project Customer/Infrastructure \
  --startup-project Customer/Api \
  --context ApplicationDbContext \
  --output-dir Migrations
```

## When migration is needed

- New entity / new DbSet / property type change / new `IEntityTypeConfiguration<T>`

## When NOT needed

- Command/Query/Handler, DTO, Endpoint, Mapster config, handler logic only

## DbSet registration order

1. Entity class
2. EF configuration (if needed)
3. `IApplicationContext.cs` — `DbSet<T>`
4. `ApplicationDbContext.cs` — `DbSet<T>`
5. Flag human with migration command
