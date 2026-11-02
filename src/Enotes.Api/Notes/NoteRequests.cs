namespace Enotes.Api.Notes;

public sealed record NoteRequest(string? Title, string? Content);

public sealed record NoteResponse(
    Guid Id,
    string Title,
    string Content,
    string Kind,
    string? FileName,
    long? SizeBytes,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc)
{
    public static NoteResponse From(Note note) =>
        new(
            note.Id,
            note.Title,
            note.Content,
            note.Kind,
            note.FileName,
            note.SizeBytes,
            note.CreatedAtUtc,
            note.UpdatedAtUtc);
}
