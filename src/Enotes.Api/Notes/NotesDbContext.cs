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
        });
    }
}
