import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:role_based_login/View/admin_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class PendingRequestsScreen extends StatefulWidget {
  const PendingRequestsScreen({super.key});

  @override
  State<PendingRequestsScreen> createState() => _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends State<PendingRequestsScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  Future<void> _updateRequestStatus(String requestId, String status) async {
    try {
      await _database.child('pickup_requests').child(requestId).update({
        'status': status,
        'processedAt': DateTime.now().toIso8601String(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'completed'
              ? 'Permintaan selesai'
              : 'Permintaan ditolak'),
          backgroundColor: status == 'completed' ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Permintaan Pending',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminScreen(),
              ),
            );
          },
        ),
      ),
      body: StreamBuilder(
        stream: _database
            .child('pickup_requests')
            .orderByChild('status')
            .equalTo('pending')
            .onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: Text('Tidak ada permintaan pending'));
          }

          Map<dynamic, dynamic>? values =
              snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;
          List<Map<String, dynamic>> requests = [];

          if (values != null) {
            values.forEach((key, value) {
              if (value is Map) {
                final request = Map<String, dynamic>.from(value);
                request['id'] = key;
                requests.add(request);
              }
            });
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];

              // Format timestamp dari milliseconds
              String formattedTime = 'Waktu tidak tersedia';
              if (request['created_at'] != null) {
                try {
                  DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(
                      request['created_at']);
                  formattedTime =
                      '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
                } catch (e) {
                  print('Error parsing timestamp: $e');
                }
              }

              // Format koordinat
              String location = 'Lokasi tidak tersedia';
              if (request['latitude'] != null && request['longitude'] != null) {
                location = '${request['latitude']}, ${request['longitude']}';
              }

              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: Colors.green.withOpacity(0.2)),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Colors.green.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.green,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                location,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          Icons.notes,
                          'Catatan:',
                          request['notes'] ?? 'Tidak ada catatan',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.access_time,
                          'Waktu:',
                          formattedTime,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                // Buka Google Maps dengan koordinat
                                if (request['latitude'] != null &&
                                    request['longitude'] != null) {
                                  _launchMaps(request['latitude'],
                                      request['longitude']);
                                }
                              },
                              icon: const Icon(Icons.map),
                              label: const Text('Buka Maps'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.green,
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: () => _updateRequestStatus(
                                  request['id']!, 'rejected'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.close, size: 20),
                              label: const Text('Tolak'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () => _updateRequestStatus(
                                  request['id']!, 'completed'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.check, size: 20),
                              label: const Text('Selesai'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: Colors.grey[800]),
              children: [
                TextSpan(
                  text: label + ' ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Waktu tidak tersedia';
    try {
      DateTime dateTime = DateTime.parse(timestamp);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      print('Error formatting timestamp: $e');
      return 'Format waktu tidak valid';
    }
  }

  // Tambahkan method untuk membuka Google Maps
  void _launchMaps(double latitude, double longitude) async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch $url');
    }
  }
}
