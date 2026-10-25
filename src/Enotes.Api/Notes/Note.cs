namespace Enotes.Api.Notes;

public sealed class Note
{
    public Guid Id { get; set; }
    public required string UserName { get; set; }
    public required string Title { get; set; }
    public required string Content { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime UpdatedAtUtc { get; set; }
}
