namespace Enotes.Api.Notes;

/// <summary>Values stored in <see cref="Note.Kind"/>. A note is either typed text or an uploaded file.</summary>
public static class NoteKinds
{
    public const string Text = "text";
    public const string File = "file";
}

public sealed class Note
{
    public Guid Id { get; set; }
    public required string UserName { get; set; }
    public required string Title { get; set; }
    public required string Content { get; set; }

    /// <summary>Either <see cref="NoteKinds.Text"/> or <see cref="NoteKinds.File"/>.</summary>
    public required string Kind { get; set; }

    /// <summary>Original file name of an uploaded file note; <c>null</c> for text notes.</summary>
    public string? FileName { get; set; }

    /// <summary>Content type reported by the uploader; <c>null</c> for text notes.</summary>
    public string? ContentType { get; set; }

    /// <summary>Size of the uploaded file in bytes; <c>null</c> for text notes.</summary>
    public long? SizeBytes { get; set; }

    /// <summary>
    /// Name of the file on disk inside the storage directory, kept separately so the
    /// storage directory can be moved without rewriting rows. <c>null</c> for text notes.
    /// </summary>
    public string? StoragePath { get; set; }

    public DateTime CreatedAtUtc { get; set; }
    public DateTime UpdatedAtUtc { get; set; }
}

