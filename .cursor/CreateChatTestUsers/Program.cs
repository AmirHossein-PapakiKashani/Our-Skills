using Application.Data;
using Application.Models;
using Application.Services;
using Domain.Models;
using Infrastructure.Data.Extentions;
using Infrastructure.Services;
using Mapster;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

var config = new ConfigurationBuilder()
    .SetBasePath(@"d:\Elay_Backend-master\Customer\Api")
    .AddJsonFile("appsettings.json", optional: false)
    .AddJsonFile("appsettings.Development.json", optional: true)
    .Build();

var services = new ServiceCollection();
services.AddSingleton<IConfiguration>(config);
services.AddInfrastructureServices(config);
services.AddSingleton<ISecurityService, SecurityService>();
services.AddSingleton<ICurrentUserService, SetupCurrentUserService>();
services.AddSingleton<IDateTimeService, DateTimeService>();

var sp = services.BuildServiceProvider();
using var scope = sp.CreateScope();
var context = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();
var security = scope.ServiceProvider.GetRequiredService<ISecurityService>();

var personas = new (string Username, string Name, string Phone)[]
{
    ("chattest_sara", "Sara ChatTest", "09120000001"),
    ("chattest_reza", "Reza ChatTest", "09120000002"),
    ("chattest_nima", "Nima ChatTest", "09120000003"),
    ("chattest_kian", "Kian ChatTest", "09120000004"),
};

foreach (var p in personas)
{
    var exists = await context.AppUsers.AnyAsync(u => u.Username == p.Username);
    if (exists)
    {
        Console.WriteLine($"SKIP exists: {p.Username}");
        continue;
    }

    var model = new AppUserRegisterModel
    {
        Username = p.Username,
        Name = p.Name,
        PhoneNumber = p.Phone,
        Password = "Test@12345",
        ConfirmPassword = "Test@12345",
        IsActive = true
    };

    var user = model.Adapt<AppUser>();
    user.PasswordHash = security.GetSha256Hash(model.Password);
    context.AppUsers.Add(user);
    await context.SaveChangesAsync(CancellationToken.None);
    Console.WriteLine($"CREATED {p.Username} id={user.Id}");
}

internal sealed class SetupCurrentUserService : ICurrentUserService
{
    public Task<string> UsernameAsync() => Task.FromResult("setup");
    public string Username() => "setup";
    public int UserId() => 0;
    public Task<int> UserIdAsync() => Task.FromResult(0);
    public string IP() => "127.0.0.1";
    public Task<bool> IsAuthenticated() => Task.FromResult(true);
    public Task<bool> IsInRole(string role) => Task.FromResult(false);
    public Task<bool> IsAdmin() => Task.FromResult(false);
    public Task<bool> IsExpierd() => Task.FromResult(false);
}
