import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:movie_app/SeatBookingScreen.dart';

class MovieDetailScreen extends StatelessWidget {
  const MovieDetailScreen({super.key});

  bool isValidBase64(String? str) {
    if (str == null || str.isEmpty) return false;
    try {
      base64Decode(str);
      return true;
    } catch (e) {
      print('Invalid base64 string: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> fetchMovieDetails(String movieId, Map<String, dynamic> movie) async {
    try {
      print('Fetching movie details for ID: $movieId');
      print('Original movie data: $movie');

      final movieDoc = await FirebaseFirestore.instance.collection('movies').doc(movieId).get();

      if (movieDoc.exists) {
        final movieData = movieDoc.data() as Map<String, dynamic>;
        print('Successfully fetched movie data: $movieData');
        return {
          'id': movieId,
          'name': movieData['name']?.toString() ?? 'Unknown Movie',
          'duration': movieData['duration']?.toString() ?? 'N/A',
          'cast': movieData['cast']?.toString() ?? 'N/A',
          'description': movieData['description']?.toString() ?? 'N/A',
          'rating': movieData['rating']?.toString() ?? 'N/A',
          'imageUrl': movieData['imageUrl']?.toString(),
          'showDate': movie['date'] ?? movie['showDate'],
          'showTime': movie['showTime']?.toString() ?? 'N/A',
          'price': movie['price'] is double ? movie['price'] : double.tryParse(movie['price']?.toString() ?? '0.0') ?? 0.0,
          'hallId': movie['hallId']?.toString() ?? 'hall_1',
          'showtimeId': movie['showtimeId']?.toString() ?? movieId,
          'hallName': movie['hallName']?.toString(),
        };
      } else {
        print('Movie document not found for ID: $movieId');
        if (movie['name'] != null) {
          print('Trying to find movie by name: ${movie['name']}');
          final querySnapshot = await FirebaseFirestore.instance
              .collection('movies')
              .where('name', isEqualTo: movie['name'])
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            final foundDoc = querySnapshot.docs.first;
            final movieData = foundDoc.data();
            print('Found movie by name: $movieData');

            return {
              'id': foundDoc.id,
              'name': movieData['name']?.toString() ?? 'Unknown Movie',
              'duration': movieData['duration']?.toString() ?? 'N/A',
              'cast': movieData['cast']?.toString() ?? 'N/A',
              'description': movieData['description']?.toString() ?? 'N/A',
              'rating': movieData['rating']?.toString() ?? 'N/A',
              'imageUrl': movieData['imageUrl']?.toString(),
              'showDate': movie['date'] ?? movie['showDate'],
              'showTime': movie['showTime']?.toString() ?? 'N/A',
              'price': movie['price'] is double ? movie['price'] : double.tryParse(movie['price']?.toString() ?? '0.0') ?? 0.0,
              'hallId': movie['hallId']?.toString() ?? 'hall_1',
              'showtimeId': movie['showtimeId']?.toString() ?? foundDoc.id,
              'hallName': movie['hallName']?.toString(),
            };
          }
        }

        print('Using fallback movie data');
        return {
          'id': movieId,
          'name': movie['name']?.toString() ?? 'Unknown Movie',
          'duration': movie['duration']?.toString() ?? 'N/A',
          'cast': movie['cast']?.toString() ?? 'N/A',
          'description': movie['description']?.toString() ?? 'N/A',
          'rating': movie['rating']?.toString() ?? 'N/A',
          'imageUrl': movie['imageUrl']?.toString(),
          'showDate': movie['date'] ?? movie['showDate'],
          'showTime': movie['showTime']?.toString() ?? 'N/A',
          'price': movie['price'] is double ? movie['price'] : double.tryParse(movie['price']?.toString() ?? '0.0') ?? 0.0,
          'hallId': movie['hallId']?.toString() ?? 'hall_1',
          'showtimeId': movie['showtimeId']?.toString() ?? movieId,
          'hallName': movie['hallName']?.toString(),
        };
      }
    } catch (e) {
      print('Error fetching movie details: $e');
      return {
        'id': movieId,
        'name': movie['name']?.toString() ?? 'Unknown Movie',
        'duration': movie['duration']?.toString() ?? 'N/A',
        'cast': movie['cast']?.toString() ?? 'N/A',
        'description': movie['description']?.toString() ?? 'N/A',
        'rating': movie['rating']?.toString() ?? 'N/A',
        'imageUrl': movie['imageUrl']?.toString(),
        'showDate': movie['date'] ?? movie['showDate'],
        'showTime': movie['showTime']?.toString() ?? 'N/A',
        'price': movie['price'] is double ? movie['price'] : double.tryParse(movie['price']?.toString() ?? '0.0') ?? 0.0,
        'hallId': movie['hallId']?.toString() ?? 'hall_1',
        'showtimeId': movie['showtimeId']?.toString() ?? movieId,
        'hallName': movie['hallName']?.toString(),
      };
    }
  }

  Future<String> fetchHallName(String? hallId) async {
    if (hallId == null) return 'Unknown Hall';
    try {
      final hallDoc = await FirebaseFirestore.instance.collection('halls').doc(hallId).get();
      if (hallDoc.exists) {
        final hallData = hallDoc.data() as Map<String, dynamic>?;
        return hallData?['name']?.toString() ?? 'Unknown Hall';
      }
    } catch (e) {
      print('Error fetching hall name: $e');
    }
    return 'Unknown Hall';
  }

  String formatDate(dynamic date) {
    if (date == null) return 'N/A';

    try {
      DateTime dateTime;
      if (date is String) {
        dateTime = DateTime.parse(date);
      } else if (date is DateTime) {
        dateTime = date;
      } else if (date is Timestamp) {
        dateTime = date.toDate();
      } else {
        return 'N/A';
      }

      final now = DateTime.now();
      final difference = dateTime.difference(DateTime(now.year, now.month, now.day)).inDays;

      if (difference == 0) return 'Today';
      if (difference == 1) return 'Tomorrow';
      if (difference == -1) return 'Yesterday';

      return DateFormat('MMM dd, yyyy').format(dateTime);
    } catch (e) {
      print('Error formatting date: $e');
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final movie = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final movieId = movie['id']?.toString() ?? movie['movieId']?.toString() ?? 'unknown';
    final userId = FirebaseAuth.instance.currentUser?.uid;

    print('Building MovieDetailScreen with movieId: $movieId');
    print('Full movie data received: $movie');

    return FutureBuilder<Map<String, dynamic>>(
      future: fetchMovieDetails(movieId, movie),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFF1C2526),
            appBar: AppBar(
              title: const Text(
                'Loading...',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFFE50914),
              elevation: 0,
            ),
            body: const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFF1C2526),
            appBar: AppBar(
              title: const Text(
                'Error',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFFE50914),
              elevation: 0,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading movie details: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final movieDetails = snapshot.data ?? {};
        print('Final movie details to display: $movieDetails');

        final showDate = formatDate(movieDetails['showDate']);
        final showTime = movieDetails['showTime']?.toString() ?? 'N/A';
        final showtimeId = movieDetails['showtimeId']?.toString() ?? movieId;

        return Scaffold(
          backgroundColor: const Color(0xFF1C2526),
          appBar: AppBar(
            title: Text(
              movieDetails['name'] ?? 'Movie Details',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFFE50914),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: movieDetails['imageUrl'] != null && isValidBase64(movieDetails['imageUrl'])
                        ? Image.memory(
                      base64Decode(movieDetails['imageUrl']),
                      height: 300,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 250,
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(Icons.image, color: Colors.white54, size: 50),
                        ),
                      ),
                    )
                        : Container(
                      height: 300,
                      color: Colors.grey[800],
                      child: const Center(
                        child: Icon(Icons.image, color: Colors.white54, size: 50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    movieDetails['name'] ?? 'Unknown Movie',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildDetailRow('Duration', movieDetails['duration'] ?? 'N/A'),
                  _buildDetailRow('Cast', movieDetails['cast'] ?? 'N/A'),
                  _buildDetailRow('Rating', movieDetails['rating'] ?? 'N/A'),

                  const SizedBox(height: 16),

                  const Text(
                    'Description',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    movieDetails['description'] ?? 'No description available.',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),

                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Showtime Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow('Show Date', showDate),
                        _buildDetailRow('Show Time', showTime),
                        FutureBuilder<String>(
                          future: fetchHallName(movieDetails['hallId']),
                          builder: (context, hallSnapshot) {
                            final hallName = hallSnapshot.data ?? movieDetails['hallName'] ?? 'Loading...';
                            return _buildDetailRow('Hall', hallName);
                          },
                        ),
                        _buildDetailRow('Price', 'Rs. ${(movieDetails['price'] ?? 0.0).toStringAsFixed(2)}'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (userId != null)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SeatSelectionScreen(
                              hallId: movieDetails['hallId'],
                              movieId: movieDetails['id'],
                              movieName: movieDetails['name'],
                              price: movieDetails['price'],
                              userId: userId,
                              showtimeId: showtimeId,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE50914),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text(
                        'Book Tickets',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    )
                  else
                    const Center(
                      child: Text(
                        'Please login to book tickets.',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}