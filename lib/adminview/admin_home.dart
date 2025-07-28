import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'hallSetup.dart';
import 'movieSetup.dart';
import 'movie_schedule.dart';

class AdminHomepage extends StatefulWidget {
  final String uid;
  const AdminHomepage({super.key, required this.uid});

  @override
  _AdminHomepageState createState() => _AdminHomepageState();
}

class _AdminHomepageState extends State<AdminHomepage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DateTime _currentDate = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 45));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C2526),
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFE50914),
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1C2526),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFFE50914)),
              child: Text('Admin Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.home_filled, color: Colors.white70),
              title: const Text('Hall Setup', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HallSetup()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule, color: Colors.white70),
              title: const Text('Movie Schedule', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminMovieSchedule()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.movie_creation, color: Colors.white70),
              title: const Text('Movie Setup', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Moviesetup()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white70),
              title: const Text('Logout', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('Dashboard Overview', style: TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('halls').snapshots(),
            builder: (context, hallSnapshot) {
              if (!hallSnapshot.hasData) return const CircularProgressIndicator();
              final halls = hallSnapshot.data!.docs;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Halls: ${halls.length}', style: const TextStyle(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 10),
                  const Text('Hall List', style: TextStyle(color: Colors.white70, fontSize: 20)),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: halls.length,
                    itemBuilder: (context, index) {
                      final hall = halls[index].data() as Map<String, dynamic>;
                      return Card(
                        color: const Color(0xFF2A3438),
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ListTile(
                          title: Text(hall['name'], style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                            'Location: ${hall['location'] ?? 'N/A'}, Seats: ${hall['seatCapacity'] ?? 50}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const Text('Scheduled Movies', style: TextStyle(color: Colors.white70, fontSize: 20)),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collectionGroup('movies').snapshots(),
            builder: (context, movieSnapshot) {
              if (!movieSnapshot.hasData) return const CircularProgressIndicator();
              final movies = movieSnapshot.data!.docs.where((doc) {
                final parentRef = doc.reference.parent.parent;
                if (parentRef == null || parentRef.id == 'movies') return false;
                final movieData = doc.data() as Map<String, dynamic>;
                final dateStr = movieData['date'] as String?;
                if (dateStr == null) return false;
                try {
                  final date = DateTime.parse(dateStr).toUtc().add(const Duration(hours: 5, minutes: 45));
                  return date.isAfter(_currentDate) || date.isAtSameMomentAs(_currentDate);
                } catch (e) {
                  return false;
                }
              }).toList();
              if (movies.isEmpty) {
                return const Text('No movies scheduled from today onwards.', style: TextStyle(color: Colors.white54));
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: movies.length,
                itemBuilder: (context, index) {
                  final movie = movies[index].data() as Map<String, dynamic>;
                  final dateStr = movie['date'] as String?;
                  DateTime? date;
                  try {
                    date = dateStr != null ? DateTime.parse(dateStr).toUtc().add(const Duration(hours: 5, minutes: 45)) : null;
                  } catch (e) {
                    date = null;
                  }
                  final relativeDate = date != null
                      ? (date.difference(_currentDate).inDays == 0 ? 'Today' : date.difference(_currentDate).inDays == 1 ? 'Tomorrow' : DateFormat('MMM dd, yyyy').format(date))
                      : 'Unknown Date';
                  return Card(
                    color: const Color(0xFF2A3438),
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      leading: movie['imageUrl'] != null
                          ? Image.memory(base64Decode(movie['imageUrl']), width: 50, height: 50, fit: BoxFit.cover)
                          : const Icon(Icons.movie, color: Colors.white70),
                      title: Text(movie['name'] ?? 'Unnamed Movie', style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        '$relativeDate | Time: ${movie['showTime'] ?? 'N/A'} | Price: Rs.${movie['price']?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}