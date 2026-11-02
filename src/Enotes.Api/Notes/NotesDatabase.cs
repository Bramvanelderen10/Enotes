using System.Data;
using Microsoft.EntityFrameworkCore;

namespace Enotes.Api.Notes;

/// <summary>
/// Creates the database on first run and keeps it up to date afterwards.
/// </summary>
/// <remarks>
/// The project does not use EF migrations: the schema is created with
/// <see cref="DatabaseFacade.EnsureCreatedAsync"/>. That call does nothing when the database
/// already exists, so columns added to <see cref="Note"/> after the first release are applied
/// here with <c>ALTER TABLE</c>. This keeps an existing <c>notes.db</c> working after an update.
/// </remarks>
public static class NotesDatabase
{
    public static async Task InitializeAsync(NotesDbContext db, CancellationToken cancellationToken = default)
    {
        await db.Database.EnsureCreatedAsync(cancellationToken);

        // Added when file notes were introduced.
        await EnsureColumnAsync(db, "Kind", "TEXT NOT NULL DEFAULT 'text'", cancellationToken);
        await EnsureColumnAsync(db, "FileName", "TEXT NULL", cancellationToken);
        await EnsureColumnAsync(db, "ContentType", "TEXT NULL", cancellationToken);
        await EnsureColumnAsync(db, "SizeBytes", "INTEGER NULL", cancellationToken);
        await EnsureColumnAsync(db, "StoragePath", "TEXT NULL", cancellationToken);
    }

    private static async Task EnsureColumnAsync(
        NotesDbContext db,
        string column,
        string definition,
        CancellationToken cancellationToken)
    {
        var connection = db.Database.GetDbConnection();
        var wasOpen = connection.State == ConnectionState.Open;
        await db.Database.OpenConnectionAsync(cancellationToken);
        try
        {
            var existing = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            await using (var command = connection.CreateCommand())
            {
                command.CommandText = "PRAGMA table_info('Notes')";
                await using var reader = await command.ExecuteReaderAsync(cancellationToken);
                var nameOrdinal = reader.GetOrdinal("name");
                while (await reader.ReadAsync(cancellationToken))
                {
                    existing.Add(reader.GetString(nameOrdinal));
                }
            }

            if (existing.Contains(column))
            {
                return;
            }
        }
        finally
        {
            if (!wasOpen)
            {
                await db.Database.CloseConnectionAsync();
            }
        }

        // SQLite cannot parameterize an identifier, and both the column name and its
        // definition are compile-time constants in this file, never user input.
#pragma warning disable EF1002
        await db.Database.ExecuteSqlRawAsync(
            $"ALTER TABLE \"Notes\" ADD COLUMN \"{column}\" {definition}",
            cancellationToken);
#pragma warning restore EF1002
    }
}
