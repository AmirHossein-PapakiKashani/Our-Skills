# Templates Reference

> Source: `AGENTS.md` Section 25.3. See also: `namespaces.md`, `file-locations.md`.

Exact code templates extracted from the live codebase.
Replace `[Feature]`, `[Context]`, `[Action]`, `[TId]` with real values.

---

## Table of Contents

1. [Domain Entity](#1-domain-entity)
2. [DTO](#2-dto)
3. [Feature-Specific Errors](#3-feature-specific-errors)
4. [Command + Validator (same file)](#4-command--validator-same-file)
5. [Command Handler (separate file)](#5-command-handler-separate-file)
6. [Query + Result Record](#6-query--result-record)
7. [Query Handler](#7-query-handler)
8. [Carter Endpoint](#8-carter-endpoint)
9. [Mapster Config addition](#9-mapster-config-addition)

---

## 1. Domain Entity

**File**: `[Context]/Core/Domain/Models/[Feature]/[Feature].cs`

```csharp
namespace Domain.Models;

/// <summary>
/// Represents [business concept description].
/// </summary>
public class [Feature] : Aggregate<[TId]>
{
    /// <summary>Gets or sets the [property description].</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>Gets or sets whether the [entity] is active.</summary>
    public bool IsActive { get; set; }

    // Add all domain properties here.
    // Do NOT add: CreateBy, CreateDate, LastModifiedBy, LastModifiedDate,
    //             IsDeleted, DeleteBy, DeleteDate — these come from Entity base class.

    /// <summary>
    /// Creates a new <see cref="[Feature]"/> with required attributes.
    /// </summary>
    /// <param name="name">The display name. Must be non-empty.</param>
    /// <returns>A new, active instance of <see cref="[Feature]"/>.</returns>
    public static [Feature] Create(string name)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name, nameof(name));
        return new [Feature] { Name = name, IsActive = true };
    }
}
```

> **Note**: Inherit from `Aggregate<TId>` if domain events are needed.
> Inherit from `Entity<TId>` if not. Most features use `int` as TId.
> Never manually set audit or soft-delete fields.

---

## 2. DTO

**File**: `[Context]/Core/Application/DTOs/[Feature]Dto.cs`

```csharp
namespace Application.DTOs;

/// <summary>
/// Data Transfer Object representing a <see cref="[Feature]"/> for API responses.
/// </summary>
public record [Feature]Dto
{
    /// <summary>Gets or sets the unique identifier.</summary>
    public [TId] Id { get; set; }

    /// <summary>Gets or sets the [feature] name.</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>Gets or sets whether the [feature] is currently active.</summary>
    public bool IsActive { get; set; }
}

/// <summary>
/// Input model for creating or updating a <see cref="[Feature]"/>.
/// </summary>
public record [Feature]Model
{
    /// <summary>Gets or sets the [feature] name. Required, minimum 2 characters.</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>Gets or sets whether the [feature] is active. Defaults to true.</summary>
    public bool IsActive { get; set; } = true;
}
```

> Use `Dto` suffix for response objects, `Model` suffix for input objects.
> Both go in the same file under `Application/DTOs/`.

---

## 3. Feature-Specific Errors

**File**: `[Context]/Core/Application/Errors/[Feature]Errors.cs`

```csharp
namespace Application.Errors;

/// <summary>
/// Defines strongly-typed error states for the <see cref="[Feature]"/> feature.
/// </summary>
public class [Feature]Errors
{
    /// <summary>
    /// Error returned when a [feature] with the given identifier does not exist.
    /// </summary>
    public static Error NotFound =>
        Error.NotFound("[Feature].NotFound", "[Feature] یافت نشد");

    /// <summary>
    /// Error returned when a [feature] with the same name already exists.
    /// </summary>
    public static Error DuplicateName =>
        Error.Conflict("[Feature].DuplicateName", "[Feature] با این نام قبلاً ثبت شده است");
}
```

> Error descriptions use Persian strings — this is the project convention.
> Use `Error.NotFound`, `Error.Conflict`, `Error.Failure` as appropriate.
> Never use `Error.AccessUnAuthorized` for domain errors — that's reserved
> for ValidationBehavior.

---

## 4. Command + Validator (same file)

**File**: `[Context]/Core/Application/Features/[Feature]/Commads/[Action][Feature]Command.cs`

> ⚠️ The folder is spelled `Commads` — not `Commands`. This is intentional.

```csharp
namespace Application.Features.Command;

/// <summary>
/// Command to [action description, e.g. "create a new category"].
/// </summary>
/// <param name="Model">The input model containing [feature] data.</param>
public record [Action][Feature]Command([Feature]Model Model) : IRequest<Result>;

// For commands that return an ID:
// public record [Action][Feature]Command([Feature]Model Model) : IRequest<Result<int>>;

/// <summary>
/// Validates the <see cref="[Action][Feature]Command"/> input.
/// </summary>
public class [Action][Feature]CommandValidator : AbstractValidator<[Action][Feature]Command>
{
    public [Action][Feature]CommandValidator()
    {
        RuleFor(x => x.Model.Name)
            .NotEmpty().WithMessage("نام الزامی است")
            .MinimumLength(2).WithMessage("نام باید حداقل ۲ کاراکتر باشد")
            .MaximumLength(200).WithMessage("نام نباید بیشتر از ۲۰۰ کاراکتر باشد");
    }
}
```

> Command and Validator are in the **same file**.
> Handler goes in a **separate file** (see Template 5).
> Namespace is `Application.Features.Command` for both Admin and Customer.

---

## 5. Command Handler (separate file)

**File**: `[Context]/Core/Application/Features/[Feature]/Commads/[Action][Feature]CommandHandler.cs`

### Create Handler

```csharp
namespace Application.Features.Command;

/// <summary>
/// Handles the <see cref="Create[Feature]Command"/> by persisting a new [feature] to the database.
/// </summary>
/// <remarks>
/// <strong>Execution Flow:</strong>
/// <list type="number">
/// <item>Receives validated command (ValidationBehavior runs before this handler).</item>
/// <item>Creates entity via static factory method.</item>
/// <item>Adapts input model properties via Mapster.</item>
/// <item>Persists entity and returns success result.</item>
/// </list>
/// </remarks>
public class Create[Feature]CommandHandler(IApplicationDbContext context)
    : IRequestHandler<Create[Feature]Command, Result>
{
    /// <summary>
    /// Executes the create [feature] command.
    /// </summary>
    /// <param name="request">The validated create command.</param>
    /// <param name="cancellationToken">Token to observe for cancellation requests.</param>
    /// <returns>
    /// <see cref="Result.Success()"/> on successful creation,
    /// or <see cref="Error.ServerError"/> if an unexpected exception occurs.
    /// </returns>
    public async Task<Result> Handle(
        Create[Feature]Command request,
        CancellationToken cancellationToken)
    {
        try
        {
            var entity = [Feature].Create(request.Model.Name);
            request.Model.Adapt(entity);  // map remaining fields via Mapster

            await context.[Feature]s.AddAsync(entity, cancellationToken);
            await context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }
        catch (Exception ex)
        {
            Log.Error($"Create[Feature]: {ex.Message}", ex);
            return Error.ServerError;
        }
    }
}
```

### Edit (Upsert) Handler

> This pattern is used in the codebase for edit operations — one command handles
> both create (Id == 0) and update (Id > 0).

```csharp
namespace Application.Features.Command;

public class Edit[Feature]CommandHandler(IApplicationDbContext context)
    : IRequestHandler<Edit[Feature]Command, Result>
{
    public async Task<Result> Handle(
        Edit[Feature]Command request,
        CancellationToken cancellationToken)
    {
        try
        {
            [Feature] entity;

            if (request.Id > 0)
            {
                entity = await context.[Feature]s
                    .FirstOrDefaultAsync(x => x.Id == request.Id, cancellationToken);

                if (entity is null)
                    return [Feature]Errors.NotFound;
            }
            else
            {
                entity = new [Feature] { };
                await context.[Feature]s.AddAsync(entity, cancellationToken);
            }

            request.Model.Adapt(entity);
            await context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }
        catch (Exception ex)
        {
            Log.Error($"Edit[Feature]: {ex.Message}", ex);
            return Error.ServerError;
        }
    }
}
```

### Delete (Soft) Handler

```csharp
public async Task<Result> Handle(
    Delete[Feature]Command request,
    CancellationToken cancellationToken)
{
    try
    {
        var entity = await context.[Feature]s
            .FirstOrDefaultAsync(x => x.Id == request.Id, cancellationToken);

        if (entity is null)
            return [Feature]Errors.NotFound;

        // Soft delete — never call context.[Feature]s.Remove(entity)
        entity.IsDeleted = true;
        entity.DeleteDate = DateTime.UtcNow;

        await context.SaveChangesAsync(cancellationToken);
        return Result.Success();
    }
    catch (Exception ex)
    {
        Log.Error($"Delete[Feature]: {ex.Message}", ex);
        return Error.ServerError;
    }
}
```

---

## 6. Query + Result Record

**File**: `[Context]/Core/Application/Features/[Feature]/Queries/GetAll[Feature]Query.cs`

```csharp
namespace Application.Features.Query;

/// <summary>
/// Query to retrieve a paginated list of [features].
/// </summary>
/// <param name="Request">Pagination parameters (zero-based PageIndex, PageSize).</param>
public record GetAll[Feature]Query(PaginationRequest Request)
    : IRequest<Result<GetAll[Feature]QueryResult>>;

/// <summary>
/// Result wrapper for <see cref="GetAll[Feature]Query"/>.
/// </summary>
/// <param name="Result">The paginated list of [feature] DTOs.</param>
public record GetAll[Feature]QueryResult(PaginatedResult<[Feature]Dto> Result);

// --- GetById variant ---

/// <summary>
/// Query to retrieve a single [feature] by its identifier.
/// </summary>
/// <param name="Id">The unique identifier of the [feature].</param>
public record Get[Feature]ByIdQuery([TId] Id)
    : IRequest<Result<[Feature]Dto>>;
```

---

## 7. Query Handler

**File**: `[Context]/Core/Application/Features/[Feature]/Queries/GetAll[Feature]QueryHandler.cs`

```csharp
namespace Application.Features.Query;

/// <summary>
/// Handles <see cref="GetAll[Feature]Query"/> by retrieving a paginated list of [features].
/// </summary>
public class GetAll[Feature]QueryHandler(IApplicationDbContext context)
    : IRequestHandler<GetAll[Feature]Query, Result<GetAll[Feature]QueryResult>>
{
    /// <summary>
    /// Executes the paginated [feature] list query.
    /// </summary>
    /// <param name="request">The query containing pagination parameters.</param>
    /// <param name="cancellationToken">Token to observe for cancellation requests.</param>
    /// <returns>
    /// A <see cref="Result{T}"/> containing a <see cref="PaginatedResult{T}"/> of
    /// <see cref="[Feature]Dto"/> on success, or <see cref="Error.ServerError"/> on failure.
    /// </returns>
    public async Task<Result<GetAll[Feature]QueryResult>> Handle(
        GetAll[Feature]Query request,
        CancellationToken cancellationToken)
    {
        try
        {
            var qBase = context.[Feature]s.AsQueryable();

            int totalCount = await qBase.CountAsync(cancellationToken);

            var items = await qBase
                .AsNoTracking()
                .Pagination(request.Request)   // zero-based PageIndex extension method
                .ToListAsync(cancellationToken);

            var dtos = items.Adapt<List<[Feature]Dto>>();

            var pagedResult = new PaginatedResult<[Feature]Dto>(
                dtos,
                request.Request.PageIndex,
                request.Request.PageSize,
                dtos.Count,
                totalCount);

            return Result<GetAll[Feature]QueryResult>.Success(
                new GetAll[Feature]QueryResult(pagedResult));
        }
        catch (Exception ex)
        {
            Log.Error($"GetAll[Feature]: {ex.Message}", ex);
            return Error.ServerError;
        }
    }
}
```

> ⚠️ `Pagination(request.Request)` is an extension method on `IQueryable<T>`.
> `PageIndex` is **zero-based** — page 0 is the first page.
> `PaginatedResult<T>` constructor: `(data, pageIndex, pageSize, count, totalCount)`.

---

## 8. Carter Endpoint

**File**: `[Context]/Api/EndPoint/[Feature]/[Feature][Method]EndPoint.cs`

> ⚠️ Class name ends with `EndPoint` (capital P) — not `Endpoint`.
> Namespace is `Api.EndPoint.[Feature]`.

```csharp
using Api.Constants;

namespace Api.EndPoint.[Feature];

/// <summary>
/// Endpoint for [action description, e.g. "creating a new [feature]"].
/// Uses the Carter library to register minimal API routes.
/// </summary>
public class [Feature][Method]EndPoint : ICarterModule
{
    /// <summary>
    /// Registers the "/[Feature]" route in the application pipeline.
    /// </summary>
    /// <param name="app">The endpoint route builder used to define routes.</param>
    /// <remarks>
    /// <strong>Execution Flow:</strong>
    /// <list type="number">
    /// <item>Listens for a [METHOD] request on "/[Feature]".</item>
    /// <item>Sends <see cref="[Action][Feature]Command"/> via MediatR.</item>
    /// <item>Returns a 200 OK response on success, or 400 Problem on failure.</item>
    /// </list>
    /// </remarks>
    public void AddRoutes(IEndpointRouteBuilder app)
    {
        app.MapPost("/[Feature]", async ([FromBody] [Feature]Model request, ISender sender) =>
        {
            var command = new Create[Feature]Command(request);
            var res = await sender.Send(command);

            if (res.IsSuccess)
                return Results.Ok(res.Value);

            return Results.Problem(res!.Error!.Description, statusCode: 400);
        })
        .WithName("Create[Feature]")
        .Produces(StatusCodes.Status200OK)                      // ← always 200, never 201
        .ProducesProblem(StatusCodes.Status400BadRequest)
        .WithSummary("Create[Feature]")
        .WithDescription("Creates a new [feature] and returns the result.")
        .RequireRateLimiting(RateLimitConst.RateFix)
        .RequireAuthorization();
    }
}
```

**GET (paginated) variant:**

```csharp
app.MapGet("/[Feature]", async ([AsParameters] PaginationRequest request, ISender sender) =>
{
    var query = new GetAll[Feature]Query(request);
    var res = await sender.Send(query);

    if (res.IsSuccess)
        return Results.Ok(res.Value.Result);

    return Results.Problem(res!.Error!.Description, statusCode: 400);
})
.WithName("GetAll[Feature]")
.Produces<PaginatedResult<[Feature]Dto>>(StatusCodes.Status200OK)
.ProducesProblem(StatusCodes.Status400BadRequest)
.WithSummary("GetAll[Feature]")
.WithDescription("Returns a paginated list of [features].")
.RequireRateLimiting(RateLimitConst.RateFix)
.RequireAuthorization();
```

---

## 9. Mapster Config Addition

**File**: `[Context]/Core/Application/Extentions/MapsterConfig.cs`

Add inside the existing config registration method:

```csharp
// [Feature] mappings
TypeAdapterConfig<[Feature], [Feature]Dto>
    .NewConfig();

TypeAdapterConfig<[Feature]Model, [Feature]>
    .NewConfig();
```

> Only add explicit config if the default convention-based mapping doesn't work
> (e.g. different property names, computed fields, nested objects).
> Simple same-name mappings don't need explicit registration.
