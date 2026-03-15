using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/temperature", (string? location) =>
{
    var value = Math.Round(Random.Shared.NextDouble() * 50 - 10, 1);
    var loc = location ?? "unknown";
    return Results.Ok(new TemperatureResponse
    {
        Value = value,
        Unit = "°C",
        Timestamp = DateTime.UtcNow,
        Location = loc,
        Status = "active",
        SensorId = "",
        SensorType = "temperature",
        Description = $"Temperature reading at {loc}"
    });
});

app.MapGet("/temperature/{sensorId}", (string sensorId) =>
{
    var value = Math.Round(Random.Shared.NextDouble() * 50 - 10, 1);
    return Results.Ok(new TemperatureResponse
    {
        Value = value,
        Unit = "°C",
        Timestamp = DateTime.UtcNow,
        Location = "",
        Status = "active",
        SensorId = sensorId,
        SensorType = "temperature",
        Description = $"Temperature reading for sensor {sensorId}"
    });
});

app.Run();

public class TemperatureResponse
{
    [JsonPropertyName("value")]
    public double Value { get; set; }

    [JsonPropertyName("unit")]
    public string Unit { get; set; } = "°C";

    [JsonPropertyName("timestamp")]
    public DateTime Timestamp { get; set; }

    [JsonPropertyName("location")]
    public string Location { get; set; } = "";

    [JsonPropertyName("status")]
    public string Status { get; set; } = "active";

    [JsonPropertyName("sensor_id")]
    public string SensorId { get; set; } = "";

    [JsonPropertyName("sensor_type")]
    public string SensorType { get; set; } = "temperature";

    [JsonPropertyName("description")]
    public string Description { get; set; } = "";
}
