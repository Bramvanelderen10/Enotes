using Enotes.Api.Notes;
using Microsoft.EntityFrameworkCore;
using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

var databasePath = builder.Configuration["Notes:DatabasePath"] ?? "data/notes.db";
var databaseDirectory = Path.GetDirectoryName(Path.GetFullPath(databasePath));
if (!string.IsNullOrEmpty(databaseDirectory))
{
    Directory.CreateDirectory(databaseDirectory);
}

// Uploaded files are kept next to the database, so the mounted ./data directory holds
// everything that needs backing up.
var storagePath = builder.Configuration["Notes:StoragePath"]
    ?? Path.Combine(databaseDirectory ?? "data", "files");
var maxFileSize = builder.Configuration.GetValue<long?>("Notes:MaxFileSizeBytes")
    ?? FileStorage.DefaultMaxFileSizeBytes;

builder.WebHost.ConfigureKestrel(options =>
{
    options.ListenAnyIP(36241);
    // Kestrel defaults to ~30 MB; uploaded notes can be much larger.
    options.Limits.MaxRequestBodySize = maxFileSize;
});

builder.Services.AddDbContextFactory<NotesDbContext>(options =>
    options.UseSqlite($"Data Source={databasePath}"));
builder.Services.AddSingleton(new FileStorage(storagePath, maxFileSize));
var allowedOrigins = builder.Configuration
    .GetSection("Notes:AllowedOrigins")
    .Get<string[]>() ?? [];
if (allowedOrigins.Length > 0)
{
    builder.Services.AddCors(options =>
        options.AddDefaultPolicy(policy =>
            policy.WithOrigins(allowedOrigins).AllowAnyHeader().AllowAnyMethod()));
}
builder.Services.AddOpenApi();

var app = builder.Build();

await using (var scope = app.Services.CreateAsyncScope())
{
    var database = scope.ServiceProvider.GetRequiredService<IDbContextFactory<NotesDbContext>>();
    await using var db = await database.CreateDbContextAsync();
    await NotesDatabase.InitializeAsync(db);
}

if (allowedOrigins.Length > 0)
{
    app.UseCors();
}
app.MapOpenApi();
app.MapScalarApiReference(options => options.EndpointPathPrefix = "/scalar/{documentName}");
app.MapGet("/health", () => Results.Ok(new { status = "ok" }));
app.MapNoteEndpoints();

app.Run();
