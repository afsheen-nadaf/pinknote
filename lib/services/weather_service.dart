// lib/services/weather_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  // Replace 'YOUR_API_KEY_HERE' with the API key you provided.
  final String apiKey = 'b7684121a3c6f60beb072a72f44e5aba';
  final String baseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  Future<Map<String, dynamic>> fetchWeather(double lat, double lon) async {
    final uri = Uri.parse('$baseUrl?lat=$lat&lon=$lon&appid=$apiKey&units=metric'); // units=metric for Celsius
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      // It's good practice to log the error response body for debugging
      // ignore: avoid_print
      print('Failed to load weather data: ${response.statusCode}, Body: ${response.body}');
      throw Exception('Failed to load weather data: ${response.statusCode}');
    }
  }
}