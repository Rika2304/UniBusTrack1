import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:unibustrack/auth/auth.dart';
import 'package:unibustrack/screens/EditProfileScreen.dart';
import 'package:unibustrack/screens/feedbackScreen.dart';
import 'package:unibustrack/services/notification.dart';
import 'package:unibustrack/utils/osmr.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  bool isCheckIn = true;
  Set<Polyline> _polylines = {}; // Store polyline
  Set<Marker> _markers = {}; // Store markers

  String distanceText = "";
  String durationText = "";

  bool locationPermissionGranted = false;

  String userRole = ""; // Store the role of the user

  Timer? _locationUpdateTimer;

  LatLng? _lastDriverLocation;
  DateTime? _lastMovementTime;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    _handleLocationPermission().then((_) {
      if (locationPermissionGranted) {
        _determinePosition();
        _fetchUsersBasedOnRole();
      }
    });
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _startTracking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 20), (
      timer,
    ) async {
      final position = await Geolocator.getCurrentPosition();
      _currentPosition = LatLng(position.latitude, position.longitude);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final userData = userDoc.data();
      if (userData == null) return;

      // Update location in Firestore
      await FirebaseFirestore.instance.collection('checkins').doc(user.uid).set(
        {
          'name': userData['name'] ?? 'Unknown',
          'role': userData['role'] ?? 'Unknown',
          'university_id': userData['university_id'] ?? 'N/A',
          'timestamp': FieldValue.serverTimestamp(),
          'location': {
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
        },
      );

      _mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition!));

      // 🔁 Stuck detection
      if (_lastDriverLocation == null) {
        _lastDriverLocation = _currentPosition;
        _lastMovementTime = DateTime.now();
      } else {
        double distance = Geolocator.distanceBetween(
          _lastDriverLocation!.latitude,
          _lastDriverLocation!.longitude,
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );

        if (distance < 10) {
          // Still in same location
          if (_lastMovementTime != null &&
              DateTime.now().difference(_lastMovementTime!).inMinutes >= 5) {
            // 🚨 Driver stuck – Send notification
            await sendBusStuckNotificationToStudents(userData['university_id']);
            _lastMovementTime = DateTime.now(); // Reset to avoid spamming
          }
        } else {
          // Driver moved – reset tracking
          _lastDriverLocation = _currentPosition;
          _lastMovementTime = DateTime.now();
        }
      }
    });
  }

  Future<void> _fetchNearestStudentAndRoute() async {
    if (_currentPosition == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

    final userData = userDoc.data();

    if (userData == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User data not found.")));
      return;
    }

    final role = userData['role'];
    final universityId = userData['university_id'];

    // 🔁 Find nearest student (if driver)
    if (role == 'driver') {
      final studentsSnapshot =
          await FirebaseFirestore.instance
              .collection('checkins')
              .where('role', isEqualTo: 'student')
              .where('university_id', isEqualTo: universityId)
              .get();

      if (studentsSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text("No Checked In Student Found"),
          ),
        );
        return;
      }

      DocumentSnapshot? nearestStudent;
      double nearestDistance = double.infinity;
      LatLng? nearestLatLng;

      for (var doc in studentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final loc = data['location'];
        final lat = loc['latitude'];
        final lng = loc['longitude'];
        final studentLatLng = LatLng(lat, lng);

        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          lat,
          lng,
        );

        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearestStudent = doc;
          nearestLatLng = studentLatLng;
        }
      }

      if (nearestLatLng != null) {
        _getRoute(_currentPosition!, nearestLatLng);
        _addMarkers(_currentPosition!, nearestLatLng);
      }
    }
    // 🔁 Find nearest driver (if student)
    else if (role == 'student') {
      final driverSnapshot =
          await FirebaseFirestore.instance
              .collection('checkins')
              .where('role', isEqualTo: 'driver')
              .where('university_id', isEqualTo: universityId)
              .get();

      if (driverSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text("No Checked In Driver Found"),
          ),
        );
        return;
      }

      DocumentSnapshot? nearestDriver;
      double nearestDistance = double.infinity;
      LatLng? nearestLatLng;

      for (var doc in driverSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final loc = data['location'];
        final lat = loc['latitude'];
        final lng = loc['longitude'];
        final driverLatLng = LatLng(lat, lng);

        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          lat,
          lng,
        );

        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearestDriver = doc;
          nearestLatLng = driverLatLng;
        }
      }

      if (nearestLatLng != null) {
        _getRoute(_currentPosition!, nearestLatLng);
        _addMarkers(_currentPosition!, nearestLatLng);
      }
    }
  }

  Future<void> _showRouteToStudent(LatLng source, LatLng destination) async {
    final url =
        'http://router.project-osrm.org/route/v1/driving/${source.longitude},${source.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=polyline';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final geometry = data['routes'][0]['geometry'];
      final distance = data['routes'][0]['distance'];
      final duration = data['routes'][0]['duration'];

      final polylinePoints = _decodePolyline(geometry);

      setState(() {
        _markers = {
          Marker(markerId: const MarkerId("driver"), position: source),
          Marker(markerId: const MarkerId("student"), position: destination),
        };
        _polylines = {
          Polyline(
            polylineId: const PolylineId("route"),
            points: polylinePoints,
            color: Colors.blue,
            width: 4,
          ),
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Distance: ${(distance / 1000).toStringAsFixed(2)} km | Time: ${(duration / 60).toStringAsFixed(0)} min",
          ),
        ),
      );
    }
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
    final userData = userDoc.data();
    if (userData != null && userData['role'] != null) {
      setState(() {
        userRole = userData['role']; // Assign role to userRole
      });
    }
  }

  void _showRouteFromOSRM(
    double originLat,
    double originLng,
    double destinationLat,
    double destinationLng,
  ) async {
    print(
      "Fetching route from ($originLat, $originLng) to ($destinationLat, $destinationLng)",
    );
    final routeData = await getRouteFromOSRM(
      originLat,
      originLng,
      destinationLat,
      destinationLng,
    );

    if (routeData['error'] != null) {
      print(routeData['error']);
      return;
    }

    final polylinePoints = decodePolyline(routeData['polyline']);
    print("Polyline points: $polylinePoints");

    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId('destination'),
          position: LatLng(destinationLat, destinationLng),
          infoWindow: InfoWindow(title: 'Destination'),
        ),
      );

      _polylines.add(
        Polyline(
          polylineId: PolylineId('route'),
          color: Colors.blue,
          width: 5,
          points: polylinePoints,
        ),
      );
    });

    final distance =
        routeData['distance'] / 1000; // Convert meters to kilometers
    final duration = routeData['duration'] / 60; // Convert seconds to minutes
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Route Info'),
            content: Text(
              'Distance: ${distance.toStringAsFixed(2)} km\nDuration: ${duration.toStringAsFixed(2)} mins',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
    );
  }

  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int shift = 0;
      int result = 0;
      int byte;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);

      int dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dLat;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);

      int dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dLng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return polyline;
  }

  Future<void> _fetchUsersBasedOnRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Fetch the logged-in user's data
    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
    final userData = userDoc.data();

    // Ensure userData is not null and contains the university_id
    if (userData == null || userData['university_id'] == null) return;

    final universityId = userData['university_id'];
    final userRole = userData['role'];

    // Declare checkInsQuerySnapshot but do not initialize it yet
    QuerySnapshot? checkInsQuerySnapshot;

    // Fetch students if the user is a driver, or fetch drivers if the user is a student
    if (userRole == 'driver') {
      // Fetch students in the same university as the driver
      checkInsQuerySnapshot =
          await FirebaseFirestore.instance
              .collection('checkins')
              .where('role', isEqualTo: 'student') // Filter only students
              .where(
                'university_id',
                isEqualTo: universityId,
              ) // Match the university_id
              .get();
    } else if (userRole == 'student') {
      // Fetch drivers in the same university as the student
      checkInsQuerySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'driver') // Filter only drivers
              .where(
                'university_id',
                isEqualTo: universityId,
              ) // Match the university_id
              .get();
    }

    // If no users were found, return
    if (checkInsQuerySnapshot == null || checkInsQuerySnapshot.docs.isEmpty) {
      return;
    }

    final users = checkInsQuerySnapshot.docs;

    setState(() {
      _markers.clear();
      _polylines.clear();
      // Add markers for each user (student or driver)
      for (var userDoc in users) {
        final userData = userDoc.data() as Map<String, dynamic>;

        // Check if 'location' exists and contains 'latitude' and 'longitude'
        final location = userData['location'];
        if (location != null) {
          final userLat = location['latitude'];
          final userLng = location['longitude'];

          // Check if latitude and longitude are not null
          if (userLat != null && userLng != null) {
            _markers.add(
              Marker(
                markerId: MarkerId(userDoc.id),
                position: LatLng(userLat, userLng),
                infoWindow: InfoWindow(
                  title: userData['name'],
                  onTap: () {
                    print("Marker tapped for ${userData['name']}");

                    // Ensure _currentPosition is not null
                    if (_currentPosition == null) {
                      print("Current location is not available.");
                      return;
                    }

                    final currentLocation = _currentPosition!; // Unwrap LatLng?

                    // Proceed to fetch and show the route
                    _showRouteFromOSRM(
                      currentLocation.latitude,
                      currentLocation.longitude,
                      userLat,
                      userLng,
                    );
                  },
                ),
              ),
            );
          }
        }
      }
    });
  }

  Future<void> _handleLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permissionStatus = await Permission.location.status;

    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location services are disabled.")),
      );
      setState(() => locationPermissionGranted = false);
      return;
    }

    if (permissionStatus.isDenied || permissionStatus.isPermanentlyDenied) {
      final result = await Permission.location.request();
      if (!result.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission is required.")),
        );
        setState(() => locationPermissionGranted = false);
        return;
      }
    }

    setState(() => locationPermissionGranted = true);
  }

  Future<void> _handleCheckIn() async {
    if (_currentPosition == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

    final userData = userDoc.data();

    if (userData == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User data not found.")));
      return;
    }

    final checkInData = {
      'name': userData['name'] ?? 'Unknown',
      'role': userData['role'] ?? 'Unknown',
      'university_id': userData['university_id'] ?? 'N/A',
      'timestamp': FieldValue.serverTimestamp(),
      'location': {
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
      },
    };

    await FirebaseFirestore.instance
        .collection('checkins')
        .doc(user.uid)
        .set(checkInData);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Check-in successful!",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
      ),
    );
    setState(() {
      isCheckIn = false;
    });

    _startTracking();

    if (userData['role'] == 'driver') {
      // 🔁 Notify all students
      final studentQuery =
          await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'student')
              .get();

      for (final doc in studentQuery.docs) {
        final student = doc.data();
        final studentToken = student['fcm_token'];
        if (studentToken != null && studentToken.toString().isNotEmpty) {
          await sendPushMessageV1(
            studentToken,
            "Bus Arriving",
            "Your bus is on its way!",
          );
        }
      }
    } else if (userData['role'] == 'student') {
      // 👤 Notify the driver in the same university
      final driverQuery =
          await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'driver')
              .where('university_id', isEqualTo: userData['university_id'])
              .limit(1)
              .get();

      if (driverQuery.docs.isNotEmpty) {
        final driver = driverQuery.docs.first.data();
        final driverToken = driver['fcm_token'];

        if (driverToken != null && driverToken.toString().isNotEmpty) {
          await sendPushMessageV1(
            driverToken,
            "${userData['name']}",
            "Checked In!",
          );
        }
      }
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enable location services')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    // Set the camera position to the current location
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_currentPosition!, 15),
    );
  }

  Future<void> _trackAssignedBus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

    final userData = userDoc.data();
    if (userData == null || userData['university_id'] == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("University not assigned.")));
      return;
    }

    final universityId = userData['university_id'].toString();

    final universityDoc =
        await FirebaseFirestore.instance
            .collection('university')
            .doc(universityId)
            .get();

    final uniData = universityDoc.data();
    if (uniData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("University data not found.")),
      );
      return;
    }

    final lat = uniData['latitude'];
    final lng = double.tryParse(uniData['longitude'].toString());

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Bus location missing.")));
      return;
    }

    final busLatLng = LatLng(lat, lng);

    // Request the route from OSRM and fetch time and distance
    await _getRoute(_currentPosition!, busLatLng);

    // Add markers for the source and destination
    _addMarkers(_currentPosition!, busLatLng);
  }

  Future<void> _getRoute(LatLng source, LatLng destination) async {
    final url =
        'http://router.project-osrm.org/route/v1/driving/${source.longitude},${source.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=polyline';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['routes'] != null && data['routes'].isNotEmpty) {
        final route = data['routes'][0];
        final polylineEncoded = route['geometry'];
        final duration = route['duration']; // Duration in seconds
        final distance = route['distance']; // Distance in meters

        // Decode the polyline and create the polyline
        final List<LatLng> polylinePoints = _decodePolyline(polylineEncoded);

        final polyline = Polyline(
          polylineId: PolylineId('route'),
          points: polylinePoints,
          color: Colors.blue,
          width: 5,
        );

        setState(() {
          _polylines.add(polyline); // Add polyline to the set
          durationText = _formatDuration(
            double.parse(duration.toString()),
          ); // Format duration
          distanceText = _formatDistance(
            double.parse(distance.toString()),
          ); // Format distance
        });

        // Move the camera to the starting point of the route
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(source, 14));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("No route found.")));
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to load route.")));
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int shift = 0;
      int result = 0;

      // Decode latitude
      while (true) {
        int b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
        if (b < 0x20) break;
      }

      int deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;

      // Decode longitude
      while (true) {
        int b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
        if (b < 0x20) break;
      }

      int deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      points.add(LatLng((lat / 1E5), (lng / 1E5)));
    }

    return points;
  }

  void _addMarkers(LatLng source, LatLng destination) {
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId('source'),
          position: source,
          infoWindow: InfoWindow(title: 'Source'),
        ),
      );

      _markers.add(
        Marker(
          markerId: MarkerId('destination'),
          position: destination,
          infoWindow: InfoWindow(title: 'Destination'),
        ),
      );
    });
  }

  String _formatDuration(double seconds) {
    int minutes = (seconds / 60).toInt();
    int hours = minutes ~/ 60;
    minutes = minutes % 60;
    return "$hours hr $minutes min";
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      double kilometers = meters / 1000;
      return "${kilometers.toStringAsFixed(2)} km";
    } else {
      return "${meters.toStringAsFixed(2)} m";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'UniBusTrack',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () async {
              _fetchUserRole();
              _handleLocationPermission().then((_) async {
                if (locationPermissionGranted) {
                  await _determinePosition();
                  await _fetchUsersBasedOnRole();
                }
              });
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.deepPurple),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.person, color: Colors.white, size: 40),
                  const SizedBox(height: 10),
                  Text(
                    FirebaseAuth.instance.currentUser?.email ?? '',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EditProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.mail),
              title: const Text('Feedback'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FeedbackFormScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.mail),
              title: const Text('Contact Us'),
              onTap: () {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text("Contact Us"),
                        content: const Text("Email: support@unibustrack.com"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Close"),
                          ),
                        ],
                      ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () {
                Navigator.pop(context);
                context.read<Authentication>().signOut();
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            locationPermissionGranted ? _fetchNearestStudentAndRoute : null,
        label: Text(
          userRole == "student" ? "Track Bus" : "Track Students",
          style: const TextStyle(color: Colors.white),
        ),
        icon: const Icon(Icons.directions_bus, color: Colors.white),
        backgroundColor:
            locationPermissionGranted ? Colors.deepPurple : Colors.grey,
      ),
      body: Stack(
        children: [
          _currentPosition == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentPosition!,
                  zoom: 15,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                onMapCreated: (controller) => _mapController = controller,
                polylines: _polylines,
                markers: _markers,
                gestureRecognizers: {
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },
              ),

          // Distance and Duration Info Card
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: Card(
              elevation: 10,
              color:
                  locationPermissionGranted ? Colors.deepPurple : Colors.grey,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Distance: $distanceText',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                    Text(
                      'Estimated Time: $durationText',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Check In Button
          if (isCheckIn)
            Positioned(
              bottom: 17,
              left: 16,
              right: userRole == "student" ? 180 : 200,
              child: ElevatedButton.icon(
                icon: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                ),
                label: Text(
                  "Check In",
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                onPressed: locationPermissionGranted ? _handleCheckIn : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      locationPermissionGranted
                          ? Colors.deepPurple
                          : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
