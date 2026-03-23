using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

var locationToId = new Dictionary<string, string>
{
    { "Living Room", "1" },
    { "Bedroom", "2" },
    { "Kitchen", "3" }
};
var idToLocation = locationToId.ToDictionary(kv => kv.Value, kv => kv.Key);

app.MapGet("/temperature", (string? location) =>
{
    var loc = location ?? "Unknown";
    var sensorId = locationToId.TryGetValue(loc, out var id) ? id : "0";
    var value = Math.Round(Random.Shared.NextDouble() * 50 - 10, 1);
    return Results.Ok(new TemperatureResponse
    {
        Value = value,
        Unit = "°C",
        Timestamp = DateTime.UtcNow,
        Location = loc,
        Status = "active",
        SensorId = sensorId,
        SensorType = "temperature",
        Description = $"Temperature reading at {loc}"
    });
});

app.MapGet("/temperature/{sensorId}", (string sensorId) =>
{
    var loc = idToLocation.TryGetValue(sensorId, out var l) ? l : "Unknown";
    var value = Math.Round(Random.Shared.NextDouble() * 50 - 10, 1);
    return Results.Ok(new TemperatureResponse
    {
        Value = value,
        Unit = "°C",
        Timestamp = DateTime.UtcNow,
        Location = loc,
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
