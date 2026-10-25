using Microsoft.EntityFrameworkCore;

namespace Enotes.Api.Notes;

public static class NoteEndpoints
{
    private const int MaxContentLength = 1_000_000;

    public static IEndpointRouteBuilder MapNoteEndpoints(this IEndpointRouteBuilder app)
    {
        var notes = app.MapGroup("/api/users/{userName}/notes");
        notes.MapGet("/", GetNotes);
        notes.MapPost("/", CreateNote);
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
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };

        await using var db = await dbFactory.CreateDbContextAsync(cancellationToken);
        db.Notes.Add(note);
        await db.SaveChangesAsync(cancellationToken);
        return Results.Created($"/api/users/{Uri.EscapeDataString(note.UserName)}/notes/{note.Id}",
            NoteResponse.From(note));
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
        note.Content = request.Content!;
        note.UpdatedAtUtc = DateTime.UtcNow;
        await db.SaveChangesAsync(cancellationToken);
        return Results.Ok(NoteResponse.From(note));
    }

    private static async Task<IResult> DeleteNote(
        string userName,
        Guid noteId,
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
}
