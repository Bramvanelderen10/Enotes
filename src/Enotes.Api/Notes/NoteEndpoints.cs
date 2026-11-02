using System.Buffers;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Enotes.Api.Notes;

public static class NoteEndpoints
{
    private const int MaxContentLength = 1_000_000;
    private const int CopyBufferSize = 1024 * 1024;

    public static IEndpointRouteBuilder MapNoteEndpoints(this IEndpointRouteBuilder app)
    {
        var notes = app.MapGroup("/api/users/{userName}/notes");
        notes.MapGet("/", GetNotes);
        notes.MapPost("/", CreateNote);
        // Upload takes the raw file as the request body (streamed straight to disk) with the
        // name in the query string, so a multi-gigabyte file never has to be buffered in memory.
        notes.MapPost("/files", UploadFile);
        notes.MapGet("/{noteId:guid}/file", DownloadFile);
        notes.MapPut("/{noteId:guid}", UpdateNote);
        notes.MapDelete("/{noteId:guid}", DeleteNote);
        return app;
    }

    private static async Task<IResult> GetNotes(
        string userName,
        IDbContextFactory<NotesDbContext> dbFactory,
        CancellationToken cancellationToken)
    {
        if (!IsValidUserName(userName))
        {
            return Results.BadRequest(new { error = "Username must be between 1 and 100 characters." });
        }

        await using var db = await dbFactory.CreateDbContextAsync(cancellationToken);
        var notes = await db.Notes
            .AsNoTracking()
            .Where(note => note.UserName == userName.Trim())
            .OrderByDescending(note => note.UpdatedAtUtc)
            .Select(note => new NoteResponse(
                note.Id,
                note.Title,
                note.Content,
                note.Kind,
                note.FileName,
                note.SizeBytes,
                note.CreatedAtUtc,
                note.UpdatedAtUtc))
            .ToListAsync(cancellationToken);
        return Results.Ok(notes);
    }

    private static async Task<IResult> CreateNote(
        string userName,
        NoteRequest request,
        IDbContextFactory<NotesDbContext> dbFactory,
        CancellationToken cancellationToken)
    {
        var validationError = Validate(userName, request);
        if (validationError is not null)
        {
            return Results.BadRequest(new { error = validationError });
        }

        var now = DateTime.UtcNow;
        var note = new Note
        {
            Id = Guid.NewGuid(),
            UserName = userName.Trim(),
            Title = request.Title!.Trim(),
            Content = request.Content!,
            Kind = NoteKinds.Text,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };

        await using var db = await dbFactory.CreateDbContextAsync(cancellationToken);
        db.Notes.Add(note);
        await db.SaveChangesAsync(cancellationToken);
        return Results.Created($"/api/users/{Uri.EscapeDataString(note.UserName)}/notes/{note.Id}",
            NoteResponse.From(note));
    }

    private static async Task<IResult> UploadFile(
        string userName,
        [FromQuery] string? fileName,
        [FromQuery] string? title,
        HttpRequest request,
        FileStorage storage,
        IDbContextFactory<NotesDbContext> dbFactory,
        CancellationToken cancellationToken)
    {
        if (!IsValidUserName(userName))
        {
            return Results.BadRequest(new { error = "Username must be between 1 and 100 characters." });
        }

        // Strip any directory parts a client might send; only the plain name is kept.
        var safeName = Path.GetFileName((fileName ?? string.Empty).Trim());
        if (string.IsNullOrWhiteSpace(safeName))
        {
            return Results.BadRequest(new { error = "A file name is required." });
        }

        var noteTitle = string.IsNullOrWhiteSpace(title) ? safeName : title.Trim();
        if (noteTitle.Length > 200)
        {
            return Results.BadRequest(new { error = "Title must be between 1 and 200 characters." });
        }

        var noteId = Guid.NewGuid();
        var targetPath = storage.PathFor(noteId);
        long totalBytes = 0;
        var tooLarge = false;
        var buffer = ArrayPool<byte>.Shared.Rent(CopyBufferSize);
        try
        {
            await using (var fileStream = new FileStream(
                targetPath,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.None,
                CopyBufferSize,
                useAsync: true))
            {
                int read;
                while ((read = await request.Body.ReadAsync(
                    buffer.AsMemory(0, buffer.Length), cancellationToken)) > 0)
                {
                    totalBytes += read;
                    if (totalBytes > storage.MaxFileSizeBytes)
                    {
                        tooLarge = true;
                        break;
                    }

                    await fileStream.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
                }
            }
        }
        catch
        {
            TryDelete(targetPath);
            throw;
        }
        finally
        {
            ArrayPool<byte>.Shared.Return(buffer);
        }

        if (tooLarge)
        {
            TryDelete(targetPath);
            return Results.BadRequest(new
            {
                error = $"Files must be at most {storage.MaxFileSizeBytes} bytes."
            });
        }

        if (totalBytes == 0)
        {
            TryDelete(targetPath);
            return Results.BadRequest(new { error = "The uploaded file is empty." });
        }

        var now = DateTime.UtcNow;
        var note = new Note
        {
            Id = noteId,
            UserName = userName.Trim(),
            // A file note keeps its content empty; the file itself lives on disk.
            Title = noteTitle,
            Content = string.Empty,
            Kind = NoteKinds.File,
            FileName = safeName,
            ContentType = request.ContentType ?? "application/octet-stream",
            SizeBytes = totalBytes,
            StoragePath = FileStorage.FileNameFor(noteId),
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };

        await using var db = await dbFactory.CreateDbContextAsync(cancellationToken);
        db.Notes.Add(note);
        await db.SaveChangesAsync(cancellationToken);
        return Results.Created($"/api/users/{Uri.EscapeDataString(note.UserName)}/notes/{note.Id}",
            NoteResponse.From(note));
    }

    private static async Task<IResult> DownloadFile(
        string userName,
        Guid noteId,
        FileStorage storage,
        IDbContextFactory<NotesDbContext> dbFactory,
        CancellationToken cancellationToken)
    {
        if (!IsValidUserName(userName))
        {
            return Results.BadRequest(new { error = "Username must be between 1 and 100 characters." });
        }

        await using var db = await dbFactory.CreateDbContextAsync(cancellationToken);
        var note = await db.Notes
            .AsNoTracking()
            .SingleOrDefaultAsync(
                item => item.Id == noteId && item.UserName == userName.Trim(),
                cancellationToken);
        if (note is null || note.Kind != NoteKinds.File || string.IsNullOrEmpty(note.StoragePath))
        {
            return Results.NotFound();
        }

        var path = Path.Combine(storage.DirectoryPath, note.StoragePath);
        if (!File.Exists(path))
        {
            return Results.NotFound();
        }

        // PhysicalFileResult streams in chunks and supports range requests, so large files do
        // not have to be loaded into memory.
        return Results.File(
            path,
            note.ContentType ?? "application/octet-stream",
            note.FileName ?? "file",
            enableRangeProcessing: true);
    }

    private static async Task<IResult> UpdateNote(
        string userName,
        Guid noteId,
        NoteRequest request,
        IDbContextFactory<NotesDbContext> dbFactory,
        CancellationToken cancellationToken)
    {
        var validationError = Validate(userName, request);
        if (validationError is not null)
        {
            return Results.BadRequest(new { error = validationError });
        }

        await using var db = await dbFactory.CreateDbContextAsync(cancellationToken);
        var note = await db.Notes.SingleOrDefaultAsync(
            item => item.Id == noteId && item.UserName == userName.Trim(),
            cancellationToken);
        if (note is null)
        {
            return Results.NotFound();
        }

        note.Title = request.Title!.Trim();
        // A file note's body is the uploaded file, so only its title can change.
        if (note.Kind != NoteKinds.File)
        {
            note.Content = request.Content!;
        }

        note.UpdatedAtUtc = DateTime.UtcNow;
        await db.SaveChangesAsync(cancellationToken);
        return Results.Ok(NoteResponse.From(note));
    }

    private static async Task<IResult> DeleteNote(
        string userName,
        Guid noteId,
        FileStorage storage,
        IDbContextFactory<NotesDbContext> dbFactory,
        CancellationToken cancellationToken)
    {
        if (!IsValidUserName(userName))
        {
            return Results.BadRequest(new { error = "Username must be between 1 and 100 characters." });
        }

        await using var db = await dbFactory.CreateDbContextAsync(cancellationToken);
        var note = await db.Notes.SingleOrDefaultAsync(
            item => item.Id == noteId && item.UserName == userName.Trim(),
            cancellationToken);
        if (note is null)
        {
            return Results.NotFound();
        }

        db.Notes.Remove(note);
        await db.SaveChangesAsync(cancellationToken);

        // Drop the uploaded file too, so deleting a file note does not leave it behind.
        if (!string.IsNullOrEmpty(note.StoragePath))
        {
            TryDelete(Path.Combine(storage.DirectoryPath, note.StoragePath));
        }

        return Results.NoContent();
    }

    private static string? Validate(string userName, NoteRequest request)
    {
        if (!IsValidUserName(userName))
        {
            return "Username must be between 1 and 100 characters.";
        }

        if (string.IsNullOrWhiteSpace(request.Title) || request.Title.Trim().Length > 200)
        {
            return "Title must be between 1 and 200 characters.";
        }

        if (request.Content is null || request.Content.Length > MaxContentLength)
        {
            return "Content is required and must be at most 1,000,000 characters.";
        }

        return null;
    }

    private static bool IsValidUserName(string userName) =>
        !string.IsNullOrWhiteSpace(userName) && userName.Trim().Length <= 100;

    private static void TryDelete(string path)
    {
        try
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
        catch (IOException)
        {
            // Best effort: an orphaned file is harmless and can be cleaned up later.
        }
    }
}
