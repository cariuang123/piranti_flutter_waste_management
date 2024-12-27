import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:role_based_login/Service/auth_service.dart';
import 'package:role_based_login/View/login_screen.dart';
import 'dart:async';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final AuthService _authService = AuthService();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  GoogleMapController? mapController;
  Set<Marker> markers = {};
  Position? currentPosition;
  bool isLoading = true;
  LatLng? selectedLocation;
  final TextEditingController weightController = TextEditingController();
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndGetLocation();
    _loadWastePoints();
    _startLocationUpdates();
  }

  void _startLocationUpdates() {
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update setiap 10 meter
      ),
    ).listen((Position position) {
      setState(() {
        currentPosition = position;
        if (mapController != null) {
          mapController!.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(position.latitude, position.longitude),
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissionAndGetLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      setState(() {
        isLoading = false;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied
        setState(() {
          isLoading = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied
      setState(() {
        isLoading = false;
      });
      return;
    }

    // When we reach here, permissions are granted
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        currentPosition = position;
        isLoading = false;
      });
    } catch (e) {
      print("Error getting location: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadWastePoints() async {
    final snapshot = await _database.child('waste_points').get();
    if (snapshot.exists) {
      Set<Marker> tempMarkers = {};
      for (var point in snapshot.children) {
        final data = point.value as Map<dynamic, dynamic>;
        tempMarkers.add(
          Marker(
            markerId: MarkerId(point.key!),
            position: LatLng(
              data['latitude'] as double,
              data['longitude'] as double,
            ),
            infoWindow: InfoWindow(
              title: data['name'] as String,
              snippet: data['type'] as String,
            ),
          ),
        );
      }
      setState(() {
        markers = tempMarkers;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Waste Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.green.shade600,
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(15),
          ),
        ),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.menu, size: 28),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.green.shade600),
                    const SizedBox(width: 12),
                    const Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'locations',
                child: Row(
                  children: const [
                    Icon(Icons.location_on, color: Colors.black87),
                    SizedBox(width: 8),
                    Text('Waste Locations'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: const [
                    Icon(Icons.logout, color: Colors.black87),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  _showProfileDialog(context);
                  break;
                case 'locations':
                  _showWasteLocationsDialog(context);
                  break;
                case 'logout':
                  _authService.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                  break;
              }
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Memuat peta...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : currentPosition == null
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.location_off,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Lokasi tidak tersedia.\nPastikan GPS aktif dan izin lokasi diberikan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          currentPosition!.latitude,
                          currentPosition!.longitude,
                        ),
                        zoom: 15,
                      ),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: true,
                      compassEnabled: true,
                      markers: markers,
                      onMapCreated: (controller) {
                        mapController = controller;
                        controller.animateCamera(
                          CameraUpdate.newLatLngZoom(
                            LatLng(
                              currentPosition!.latitude,
                              currentPosition!.longitude,
                            ),
                            15,
                          ),
                        );
                      },
                      onTap: (LatLng position) {
                        setState(() {
                          markers.removeWhere((marker) =>
                              marker.markerId ==
                              const MarkerId('selected_location'));

                          selectedLocation = position;
                          markers.add(
                            Marker(
                              markerId: const MarkerId('selected_location'),
                              position: position,
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueGreen,
                              ),
                            ),
                          );
                        });
                      },
                    ),
                    if (selectedLocation != null)
                      Positioned(
                        bottom: 90,
                        left: 16,
                        right: 16,
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.shade50,
                                  Colors.white,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Lokasi Terpilih:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${selectedLocation!.latitude.toStringAsFixed(6)}, ${selectedLocation!.longitude.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
      floatingActionButton: currentPosition == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showRequestPickupDialog(context),
              label: const Text(
                'Minta Penjemputan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              icon: const Icon(Icons.local_shipping, size: 24),
              backgroundColor: Colors.green.shade600,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
    );
  }

  Future<void> _showRequestPickupDialog(BuildContext context) async {
    String wasteType = 'organic';
    final TextEditingController notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Permintaan Penjemputan',
          style: TextStyle(
            color: Colors.green.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Jenis Sampah',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: wasteType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'organic',
                    child: Text('Sampah Organik'),
                  ),
                  DropdownMenuItem(
                    value: 'non_organic',
                    child: Text('Sampah Non-Organik'),
                  ),
                ],
                onChanged: (value) {
                  wasteType = value!;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Berat Sampah (kg)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: weightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Masukkan berat sampah',
                  suffixText: 'kg',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Catatan Tambahan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Tambahkan catatan jika diperlukan',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
            ),
            onPressed: () async {
              if (selectedLocation == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Silakan pilih lokasi penjemputan pada peta'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (weightController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Silakan masukkan berat sampah'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              await _database.child('pickup_requests').push().set({
                'user_id': _authService.getCurrentUser()?.uid,
                'latitude': selectedLocation!.latitude,
                'longitude': selectedLocation!.longitude,
                'waste_type': wasteType,
                'weight': double.parse(weightController.text),
                'notes': notesController.text,
                'status': 'pending',
                'created_at': ServerValue.timestamp,
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Permintaan penjemputan berhasil dikirim'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text(
              'Kirim',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showProfileDialog(BuildContext context) async {
    final TextEditingController oldPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password Lama',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password Baru',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi Password Baru',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
            ),
            onPressed: () async {
              if (newPasswordController.text !=
                  confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password baru tidak cocok'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                await _authService.updatePassword(
                  oldPasswordController.text,
                  newPasswordController.text,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password berhasil diperbarui'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'Simpan',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showWasteLocationsDialog(BuildContext context) async {
    final snapshot = await _database.child('waste_points').get();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lokasi Pembuangan Sampah'),
        content: SizedBox(
          width: double.maxFinite,
          child: snapshot.exists
              ? ListView.builder(
                  shrinkWrap: true,
                  itemCount: snapshot.children.length,
                  itemBuilder: (context, index) {
                    final point = snapshot.children.elementAt(index);
                    final data = point.value as Map<dynamic, dynamic>;
                    return Card(
                      child: ListTile(
                        title: Text(data['name'] as String),
                        subtitle: Text(data['type'] as String),
                        trailing: IconButton(
                          icon: const Icon(Icons.location_on),
                          onPressed: () {
                            mapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(
                                LatLng(
                                  data['latitude'] as double,
                                  data['longitude'] as double,
                                ),
                                15,
                              ),
                            );
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    );
                  },
                )
              : const Center(
                  child: Text('Tidak ada lokasi yang tersedia'),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
