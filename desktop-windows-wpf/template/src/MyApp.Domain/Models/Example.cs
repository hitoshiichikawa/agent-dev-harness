namespace MyApp.Domain.Models;

/// <summary>EF の Entity。ビジネスロジックは持たせない。</summary>
public sealed class Example
{
    public int Id { get; set; }
    public required string Name { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
