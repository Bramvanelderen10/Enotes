namespace Enotes.Api.Notes;

/// <summary>
/// Where uploaded files are kept on disk. Files live next to the database (under the
/// data directory), so backing up the data directory is enough and no files are ever
/// embedded in SQLite — an uploaded note can be several gigabytes.
/// </summary>
public sealed class FileStorage
{
    /// <summary>Uploads are limited to 10 GB unless configured otherwise.</summary>
    public const long DefaultMaxFileSizeBytes = 10L * 1024 * 1024 * 1024;

    public FileStorage(string directoryPath, long maxFileSizeBytes = DefaultMaxFileSizeBytes)
    {
        DirectoryPath = Path.GetFullPath(directoryPath);
        Directory.CreateDirectory(DirectoryPath);
        MaxFileSizeBytes = maxFileSizeBytes > 0 ? maxFileSizeBytes : DefaultMaxFileSizeBytes;
    }

    /// <summary>Absolute path of the directory that holds the uploaded files.</summary>
    public string DirectoryPath { get; }

    /// <summary>Largest file the API accepts, in bytes.</summary>
    public long MaxFileSizeBytes { get; }

    /// <summary>Absolute path of the file belonging to <paramref name="noteId"/>.</summary>
    public string PathFor(Guid noteId) => Path.Combine(DirectoryPath, FileNameFor(noteId));

    /// <summary>
    /// Name (relative to <see cref="DirectoryPath"/>) stored in the database. It does not
    /// reuse the original file name, because that could contain separators or be reused.
    /// </summary>
    public static string FileNameFor(Guid noteId) => noteId.ToString("N");
}
