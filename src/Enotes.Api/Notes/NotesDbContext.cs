using Microsoft.EntityFrameworkCore;

namespace Enotes.Api.Notes;

public sealed class NotesDbContext(DbContextOptions<NotesDbContext> options)
    : DbContext(options)
{
    public DbSet<Note> Notes => Set<Note>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Note>(entity =>
        {
            entity.HasKey(note => note.Id);
            entity.Property(note => note.UserName).HasMaxLength(100).IsRequired();
            entity.Property(note => note.Title).HasMaxLength(200).IsRequired();
            entity.Property(note => note.Content).IsRequired();
            entity.HasIndex(note => new { note.UserName, note.UpdatedAtUtc });
            // SQLite stores DateTime values without a time zone. Without these converters a
            // value read back from the database has DateTimeKind.Unspecified, System.Text.Json
            // serializes it without the trailing 'Z', and clients parse it as local time.
            entity.Property(note => note.CreatedAtUtc).HasConversion(
                value => value, value => DateTime.SpecifyKind(value, DateTimeKind.Utc));
            entity.Property(note => note.UpdatedAtUtc).HasConversion(
                value => value, value => DateTime.SpecifyKind(value, DateTimeKind.Utc));
        });
    }
}
