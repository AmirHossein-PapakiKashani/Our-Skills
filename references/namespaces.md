# Namespace Rules

> CRITICAL: Wrong namespaces cause compilation failures.
> These rules are extracted from the actual codebase — not invented.

---

## The Core Rule

Namespaces in this project do **NOT** include:
- The bounded context name (`Admin`, `Customer`)
- The word `Core`
- The word `Features` at the top level

They start directly from the **layer name**.

---

## Namespace Map — All Layers

| Layer | Folder Path | Namespace |
|---|---|---|
| Commands & Handlers | `Core/Application/Features/[F]/Commads/` | `Application.Features.Command` |
| Queries & Handlers | `Core/Application/Features/[F]/Queries/` | `Application.Features.Query` |
| DTOs & Models | `Core/Application/DTOs/` | `Application.DTOs` |
| Errors | `Core/Application/Errors/` | `Application.Errors` |
| Services (interfaces) | `Core/Application/Services/` | `Application.Services` |
| Mapster config | `Core/Application/Extentions/` | `Application.Extentions` |
| Domain Entities | `Core/Domain/Models/` | `Domain.Models` |
| Domain Entities (alt) | `Core/Domain/Entities/` | `Domain.Entities` |
| DbContext interface | `Core/Application/Data/` | `Application.Data` |
| Carter Endpoints | `Api/EndPoint/[Feature]/` | `Api.EndPoint.[Feature]` |
| API Extensions | `Api/Extentions/` | `Api.Extentions` |
| API Constants | `Api/Constants/` | `Api.Constants` |
| SharedKernel | `Share/SharedKernel.Domain/Abstractions/` | `SharedKernel.Domain.Abstractions` |
| Share utilities | `Share/Share/` | `Share.Share` |

---

## Real Examples From Codebase

```csharp
// From UserCreateCommand.cs
namespace Application.Services.Command;

// From CategoryAllQuery.cs
namespace Application.Features.Query;

// From CategoryEndPoint.cs
namespace Api.EndPoint;

// From TaskPostEndPoint.cs
namespace Api.EndPoint.Task;

// From ApplicationDbContext.cs (interface)
namespace Application.Data;

// From a DTO file
namespace Application.DTOs;

// From Domain entity
namespace Domain.Models;

// From SharedKernel
namespace SharedKernel.Domain.Abstractions;
```

---

## Intentional Typos in Namespaces

| What you see | What it means | In namespace |
|---|---|---|
| `Extentions` | Extensions | `Application.Extentions`, `Api.Extentions` |
| `Commads` | Commands | folder only; namespace is `Application.Features.Command` |
| `EndPoint` | Endpoint | `Api.EndPoint`, `Api.EndPoint.[Feature]` |

---

## Common Mistakes to Avoid

```csharp
// ❌ Wrong — includes bounded context
namespace Admin.Application.Features.Command;

// ❌ Wrong — "Commands" not "Command"
namespace Application.Features.Commands;

// ❌ Wrong — "Endpoint" not "EndPoint"
namespace Api.Endpoint.Category;

// ✅ Correct
namespace Application.Features.Command;
namespace Application.DTOs;
namespace Api.EndPoint.Category;
namespace Domain.Models;
```
