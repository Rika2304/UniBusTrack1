import 'dart:convert';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> getRouteFromOSRM(
  double originLat,
  double originLng,
  double destinationLat,
  double destinationLng,
) async {
  final url =
      'http://router.project-osrm.org/route/v1/driving/$originLng,$originLat;$destinationLng,$destinationLat?overview=full&geometries=polyline';

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    if (data['code'] == 'Ok') {
      final route = data['routes'][0];
      final distance = route['legs'][0]['distance'];
      final duration = route['legs'][0]['duration'];
      final polyline = route['geometry'];

      return {'distance': distance, 'duration': duration, 'polyline': polyline};
    } else {
      return {'error': 'Failed to get route'};
    }
  } else {
    return {'error': 'Failed to fetch route'};
  }
}
