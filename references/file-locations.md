# File Location Rules

Exact physical paths for each file type.
Replace `[Context]` with `Admin` or `Customer`, `[Feature]` with the feature name.

---

## Admin Context Paths

```
Admin\
├── Api\
│   ├── Constants\
│   │   └── RateLimitConst.cs                          ← DO NOT TOUCH
│   ├── EndPoint\
│   │   └── [Feature]\
│   │       └── [Feature][Method]EndPoint.cs           ← ✅ NEW endpoint
│   └── Extentions\                                    ← DO NOT TOUCH
│
└── Core\
    ├── Application\
    │   ├── DTOs\
    │   │   └── [Feature]Dto.cs
    │   ├── Errors\
    │   │   └── [Feature]Errors.cs
    │   ├── Extentions\
    │   │   └── MapsterConfig.cs                       ← ⚠️ MODIFY
    │   ├── Data\
    │   │   └── IApplicationContext.cs                 ← ⚠️ MODIFY (DbSet)
    │   └── Features\
    │       └── [Feature]\
    │           ├── Commads\                           ← intentional typo
    │           │   ├── [Action][Feature]Command.cs
    │           │   └── [Action][Feature]CommandHandler.cs
    │           └── Queries\
    │               ├── Get[Feature]Query.cs
    │               └── Get[Feature]QueryHandler.cs
    │
    └── Domain\
        └── Models\
            └── [Feature]\
                └── [Feature].cs
```

---

## Customer Context Paths

Same structure as Admin. Replace `Admin\` with `Customer\`.

---

## Naming Rules for Files

| File type | Naming pattern | Example |
|---|---|---|
| Command + Validator | `[Action][Feature]Command.cs` | `CreateCategoryCommand.cs` |
| Command Handler | `[Action][Feature]CommandHandler.cs` | `CreateCategoryCommandHandler.cs` |
| Query + Result | `Get[Feature][Variant]Query.cs` | `GetAllCategoriesQuery.cs` |
| Query Handler | `Get[Feature][Variant]QueryHandler.cs` | `GetAllCategoriesQueryHandler.cs` |
| Carter Endpoint | `[Feature][Method]EndPoint.cs` | `CategoryPostEndPoint.cs` |
| DTO | `[Feature]Dto.cs` | `CategoryDto.cs` |
| Errors | `[Feature]Errors.cs` | `CategoryErrors.cs` |
| Domain Entity | `[Feature].cs` | `Category.cs` |

---

## Files to NEVER Create In

```
**/Program.cs
**/Migrations/**
**/Extentions/*Extensions.cs
**/bin/**
**/obj/**
Lib/**
Share/SharedKernel.Domain/Abstractions/**
```

---

## Files You MAY Modify (with care)

| File | What to add | What NOT to change |
|---|---|---|
| `IApplicationContext.cs` | New `DbSet<T>` line | Existing DbSets, SaveChangesAsync |
| `MapsterConfig.cs` | New `TypeAdapterConfig<>` | Existing registrations |
| `ApplicationDbContext.cs` | New `DbSet<T>` property | OnModelCreating, interceptors |

---

## Quick Decision: Where Does This File Go?

```
Business logic + DB?     → Features/[Feature]/Commads/*Handler.cs or Queries/*Handler.cs
Client input record?     → Commads/*Command.cs or Queries/*Query.cs
Route + HTTP response?   → Api/EndPoint/[Feature]/*EndPoint.cs
API response DTO?        → Application/DTOs/[Feature]Dto.cs
Domain errors?           → Application/Errors/[Feature]Errors.cs
Database table entity?   → Domain/Models/[Feature]/[Feature].cs
```
