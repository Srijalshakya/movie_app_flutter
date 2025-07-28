import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:movie_app/SeatBookingScreen.dart';
import 'package:movie_app/profile.dart';
import 'package:movie_app/movie_details_screen.dart';

class HomeScreen extends StatefulWidget {
  final String uid;
  const HomeScreen({super.key, required this.uid});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DateTime currentDate = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 45));
  Future<List<Map<String, dynamic>>> _hallsFuture = Future.value([]);

  @override
  void initState() {
    super.initState();
    _hallsFuture = _fetchHalls().catchError((e) {
      print('Error fetching halls: $e');
      return <Map<String, dynamic>>[];
    });
  }

  Future<List<Map<String, dynamic>>> _fetchHalls() async {
    try {
      final snapshot = await _firestore.collection('halls').get();
      return Future.wait(snapshot.docs.map((doc) => enrichHallData(doc)));
    } catch (e) {
      print('Firestore error in _fetchHalls: $e');
      return [];
    }
  }

  String getRelativeDate(DateTime? movieDate) {
    if (movieDate == null) return 'Unknown Date';
    final difference = movieDate.difference(currentDate).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference > 1) return DateFormat('MMM dd, yyyy').format(movieDate);
    return 'Past Date';
  }

  Future<Map<String, dynamic>> enrichHallData(DocumentSnapshot hallDoc) async {
    final hallData = hallDoc.data() as Map<String, dynamic>? ?? {};
    return {
      'id': hallDoc.id,
      'name': hallData['name']?.toString() ?? 'Unknown Hall',
      'location': hallData['location']?.toString() ?? 'Unknown Location',
      'imageUrl': hallData['imageUrl']?.toString(),
    };
  }

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

  Uint8List? _decodeImage(String? base64String) {
    if (base64String == null || !isValidBase64(base64String)) {
      return null;
    }
    try {
      return base64Decode(base64String);
    } catch (e) {
      print('Error decoding image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: const Text('Cinemas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: const Color(0xFFE50914),
        elevation: 0,
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF141414),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE50914), Color(0xFFB20710)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: const Text('Menu', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.movie, color: Colors.white70),
              title: const Text('Movies', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.white70),
              title: const Text('Profile', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(uid: widget.uid),
                  ),
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _hallsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 16)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No halls available.', style: TextStyle(color: Colors.white54, fontSize: 18)));
          }
          final halls = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: halls.length,
            itemBuilder: (context, index) {
              final hall = halls[index];
              final imageBytes = _decodeImage(hall['imageUrl']);
              return Card(
                elevation: 6,
                margin: const EdgeInsets.only(bottom: 20),
                color: const Color(0xFF2A2A2A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HallMoviesScreen(hallId: hall['id'], userId: widget.uid),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: imageBytes != null
                              ? Image.memory(
                            imageBytes,
                            width: 120,
                            height: 160,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 120,
                                height: 160,
                                color: Colors.grey,
                                child: const Icon(Icons.image, color: Colors.white54),
                              );
                            },
                          )
                              : Container(
                            width: 120,
                            height: 160,
                            color: Colors.grey,
                            child: const Icon(Icons.image, color: Colors.white54),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hall['name'],
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Location: ${hall['location']}',
                                style: const TextStyle(color: Colors.white70, fontSize: 16),
                              ),
                            ],
                          ),
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
}

class HallMoviesScreen extends StatefulWidget {
  final String hallId;
  final String userId;
  const HallMoviesScreen({super.key, required this.hallId, required this.userId});

  @override
  _HallMoviesScreenState createState() => _HallMoviesScreenState();
}

class _HallMoviesScreenState extends State<HallMoviesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DateTime currentDate = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 45));
  String? selectedDate;
  String? selectedTime;
  String? selectedMovieId;
  String? selectedShowtimeId;
  List<Map<String, dynamic>> movieDetailsList = [];
  Future<List<Map<String, dynamic>>> _moviesFuture = Future.value([]);

  @override
  void initState() {
    super.initState();
    _moviesFuture = _fetchMovies().catchError((e) {
      print('Error fetching movies: $e');
      return <Map<String, dynamic>>[];
    });
  }

  Future<List<Map<String, dynamic>>> _fetchMovies() async {
    try {
      final snapshot = await _firestore.collection('halls').doc(widget.hallId).collection('movies').get();
      final movies = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        DateTime? date;
        try {
          date = data['date'] != null ? DateTime.parse(data['date']).toUtc().add(const Duration(hours: 5, minutes: 45)) : null;
        } catch (e) {
          print('Invalid date format for movie ${doc.id}: $e');
        }
        return {
          'id': doc.id,
          'name': data['name']?.toString() ?? 'Unknown Movie',
          'date': date,
          'showTime': data['showTime']?.toString(),
          'price': double.tryParse(data['price']?.toString() ?? '0.0') ?? 0.0,
          'imageUrl': data['imageUrl']?.toString(),
          'showtimeId': doc.id,
        };
      }).where((movie) {
        final movieDate = movie['date'] as DateTime?;
        final showTime = movie['showTime']?.toString();
        if (movieDate == null || showTime == null) return false;
        try {
          final timeParts = showTime.split(':');
          if (timeParts.isEmpty) return false;
          final hourStr = timeParts[0].trim();
          final minuteStr = timeParts.length > 1 ? timeParts[1].replaceAll(RegExp(r'[^0-9]'), '') : '0';
          final isAm = showTime.toLowerCase().contains('am');
          final hour = int.parse(hourStr);
          final minute = int.parse(minuteStr);
          final movieDateTime = DateTime(
            movieDate.year,
            movieDate.month,
            movieDate.day,
            isAm ? hour : hour + (hour < 12 ? 12 : 0),
            minute,
          );
          return movieDateTime.isAfter(currentDate);
        } catch (e) {
          print('Error parsing showtime $showTime for movie ${movie['id']}: $e');
          return false;
        }
      }).toList();
      await fetchAndEnrichMovies(movies);
      return movies;
    } catch (e) {
      print('Firestore error in _fetchMovies: $e');
      return [];
    }
  }

  List<Map<String, String>> getAvailableDates(List<Map<String, dynamic>> movies) {
    final uniqueDates = <String>{};
    for (var movie in movies) {
      final date = movie['date'] as DateTime?;
      if (date != null) {
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        uniqueDates.add(dateStr);
      }
    }
    final dateList = uniqueDates.toList()..sort();
    return dateList.map((dateStr) {
      final date = DateTime.parse(dateStr);
      return {
        'iso': dateStr,
        'display': getRelativeDate(date),
      };
    }).toList();
  }

  String getRelativeDate(DateTime? movieDate) {
    if (movieDate == null) return 'Unknown Date';
    final difference = movieDate.difference(currentDate).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference > 1) return DateFormat('MMM dd, yyyy').format(movieDate);
    return 'Past Date';
  }

  List<Map<String, dynamic>> getAvailableTimes(List<Map<String, dynamic>> movies) {
    if (selectedDate == null) return [];
    final times = <Map<String, dynamic>>[];
    for (var movie in movies) {
      final movieDate = movie['date'] as DateTime?;
      final showTime = movie['showTime']?.toString();
      if (movieDate == null || showTime == null) continue;
      final dateStr = DateFormat('yyyy-MM-dd').format(movieDate);
      if (dateStr == selectedDate) {
        try {
          final timeParts = showTime.split(':');
          if (timeParts.length < 1) continue;
          final hourStr = timeParts[0].trim();
          final minuteStr = timeParts.length > 1 ? timeParts[1].replaceAll(RegExp(r'[^0-9]'), '') : '0';
          final isAm = showTime.toLowerCase().contains('am');
          final hour = int.parse(hourStr);
          final minute = int.parse(minuteStr);
          final movieDateTime = DateTime(
            movieDate.year,
            movieDate.month,
            movieDate.day,
            isAm ? hour : hour + (hour < 12 ? 12 : 0),
            minute,
          );
          if (movieDateTime.isAfter(currentDate)) {
            times.add({
              'time': showTime,
              'movieId': movie['id'],
              'showtimeId': movie['showtimeId'],
            });
          }
        } catch (e) {
          print('Error parsing showtime $showTime: $e');
          continue;
        }
      }
    }
    times.sort((a, b) => a['time'].compareTo(b['time']));
    return times;
  }

  Future<Map<String, dynamic>> enrichMovieData(Map<String, dynamic> movie) async {
    try {
      final movieDoc = await _firestore.collection('movies').doc(movie['id']).get();
      final movieData = movieDoc.data() as Map<String, dynamic>?;
      return {
        'id': movie['id']?.toString() ?? 'unknown',
        'name': movie['name']?.toString() ?? 'Unknown Movie',
        'imageUrl': movie['imageUrl']?.toString() ?? (movieData?['imageUrl']?.toString() ?? ''),
        'duration': movieData?['duration']?.toString() ?? 'N/A',
        'cast': movieData?['cast']?.toString() ?? 'N/A',
        'description': movieData?['description']?.toString() ?? 'N/A',
        'rating': movieData?['rating']?.toString() ?? 'N/A',
        'date': movie['date'],
        'showTime': movie['showTime']?.toString(),
        'price': movie['price'] is double ? movie['price'] : double.tryParse(movie['price']?.toString() ?? '0.0') ?? 0.0,
        'hallId': widget.hallId,
        'showtimeId': movie['showtimeId']?.toString() ?? movie['id']?.toString() ?? 'unknown',
      };
    } catch (e) {
      print('Error fetching movie details for ${movie['id']}: $e');
      return {
        'id': movie['id']?.toString() ?? 'unknown',
        'name': movie['name']?.toString() ?? 'Unknown Movie',
        'imageUrl': movie['imageUrl']?.toString() ?? '',
        'duration': 'N/A',
        'cast': 'N/A',
        'description': 'N/A',
        'rating': 'N/A',
        'date': movie['date'],
        'showTime': movie['showTime']?.toString(),
        'price': movie['price'] is double ? movie['price'] : double.tryParse(movie['price']?.toString() ?? '0.0') ?? 0.0,
        'hallId': widget.hallId,
        'showtimeId': movie['showtimeId']?.toString() ?? movie['id']?.toString() ?? 'unknown',
      };
    }
  }

  Future<void> fetchAndEnrichMovies(List<Map<String, dynamic>> movies) async {
    if (!mounted) return;
    try {
      final enrichedMovies = await Future.wait(movies.map((movie) => enrichMovieData(movie)));
      if (mounted) {
        setState(() {
          movieDetailsList = enrichedMovies;
        });
      }
    } catch (e) {
      print('Error enriching movies: $e');
      if (mounted) {
        setState(() {
          movieDetailsList = movies.map((movie) => ({
            'id': movie['id']?.toString() ?? 'unknown',
            'name': movie['name']?.toString() ?? 'Unknown Movie',
            'imageUrl': movie['imageUrl']?.toString() ?? '',
            'duration': 'N/A',
            'cast': 'N/A',
            'description': 'N/A',
            'rating': 'N/A',
            'date': movie['date'],
            'showTime': movie['showTime']?.toString(),
            'price': movie['price'] is double ? movie['price'] : double.tryParse(movie['price']?.toString() ?? '0.0') ?? 0.0,
            'hallId': widget.hallId,
            'showtimeId': movie['showtimeId']?.toString() ?? movie['id']?.toString() ?? 'unknown',
          })).toList();
        });
      }
    }
  }

  Future<void> cleanupPastMovies() async {
    try {
      final moviesSnapshot = await _firestore.collection('halls').doc(widget.hallId).collection('movies').get();
      final batch = _firestore.batch();
      for (var doc in moviesSnapshot.docs) {
        final data = doc.data();
        final dateStr = data['date']?.toString();
        final showTime = data['showTime']?.toString();
        if (dateStr == null || showTime == null) {
          batch.delete(doc.reference);
          continue;
        }
        try {
          final movieDate = DateTime.parse(dateStr).toUtc().add(const Duration(hours: 5, minutes: 45));
          final timeParts = showTime.split(':');
          if (timeParts.isEmpty) continue;
          final hourStr = timeParts[0].trim();
          final minuteStr = timeParts.length > 1 ? timeParts[1].replaceAll(RegExp(r'[^0-9]'), '') : '0';
          final isAm = showTime.toLowerCase().contains('am');
          final hour = int.parse(hourStr);
          final minute = int.parse(minuteStr);
          final movieDateTime = DateTime(
            movieDate.year,
            movieDate.month,
            movieDate.day,
            isAm ? hour : hour + (hour < 12 ? 12 : 0),
            minute,
          );
          if (movieDateTime.isBefore(currentDate)) {
            batch.delete(doc.reference);
          }
        } catch (e) {
          print('Error parsing movie $dateStr/$showTime: $e');
          batch.delete(doc.reference);
        }
      }
      await batch.commit();
    } catch (e) {
      print('Error cleaning up past movies: $e');
    }
  }

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

  Uint8List? _decodeImage(String? base64String) {
    if (base64String == null || !isValidBase64(base64String)) {
      return null;
    }
    try {
      return base64Decode(base64String);
    } catch (e) {
      print('Error decoding image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: const Text('Movies in Hall', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: const Color(0xFFE50914),
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _moviesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 16)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No upcoming movies available.', style: TextStyle(color: Colors.white54, fontSize: 18)));
          }
          final movies = snapshot.data!;
          final Map<String, List<Map<String, dynamic>>> movieGroups = {};
          for (var movie in movies) {
            final movieName = movie['name'] as String;
            if (!movieGroups.containsKey(movieName)) {
              movieGroups[movieName] = [];
            }
            movieGroups[movieName]!.add(movie);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: movieGroups.length,
            itemBuilder: (context, index) {
              final movieName = movieGroups.keys.elementAt(index);
              final movieList = movieGroups[movieName]!;
              final availableDates = getAvailableDates(movieList);
              final availableTimes = selectedDate != null ? getAvailableTimes(movieList) : [];

              final movieDetail = movieDetailsList.isNotEmpty && index < movieDetailsList.length
                  ? movieDetailsList[index]
                  : movieList[0];
              final imageBytes = _decodeImage(movieList[0]['imageUrl']);

              return Card(
                elevation: 6,
                margin: const EdgeInsets.only(bottom: 20),
                color: const Color(0xFF2A2A2A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      InkWell(
                      onTap: () {
                print('Navigating to MovieDetailScreen with movie: $movieDetail');
                Navigator.push(
                context,
                MaterialPageRoute(
                builder: (context) => MovieDetailScreen(),
                settings: RouteSettings(arguments: movieDetail),
                ),
                ).catchError((e) {
                print('Navigation error: $e');
                });
                },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageBytes != null
                        ? Image.memory(
                      imageBytes,
                      width: 120,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 120,
                          height: 160,
                          color: Colors.grey,
                          child: const Icon(Icons.image, color: Colors.white54),
                        );
                      },
                    )
                        : Container(
                      width: 120,
                      height: 160,
                      color: Colors.grey,
                      child: const Icon(Icons.image, color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text(
                      movieName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      color: Colors.grey[800],
                      child: const Text(
                        'Select Date',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (availableDates.isEmpty)
                const Text(
                'No upcoming dates available.',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              )
              else
              GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              ),
              itemCount: availableDates.length,
              itemBuilder: (context, index) {
              final date = availableDates[index];
              final isSelected = selectedDate == date['iso'];
              return GestureDetector(
              onTap: () {
              setState(() {
              selectedDate = date['iso'];
              selectedTime = null;
              selectedMovieId = null;
              selectedShowtimeId = null;
              });
              },
              child: Container(
              decoration: BoxDecoration(
              color: isSelected ? Colors.yellow : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.black54),
              ),
              child: Center(
              child: Text(
              date['display']!,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              ),
              ),
              );
              },
              ),
              const SizedBox(height: 20),
              if (selectedDate != null)
              Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              color: Colors.grey[800],
              child: const Text(
              'Select Time',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ),
              const SizedBox(height: 10),
              if (availableTimes.isEmpty)
              const Text(
              'No upcoming showtimes available.',
              style: TextStyle(color: Colors.white54, fontSize: 16),
              )
              else
              GridView.builder(
              shrinkWrap: true,
              physics:  NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              ),
              itemCount: availableTimes.length,
              itemBuilder: (context, index) {
              final timeData = availableTimes[index];
              final time = timeData['time'];
              final isSelected = selectedTime == time;
              return GestureDetector(
              onTap: () {
              setState(() {
              selectedTime = time;
              selectedMovieId = timeData['movieId'];
              selectedShowtimeId = timeData['showtimeId'];
              });
              },
              child: Container(
              decoration: BoxDecoration(
              color: isSelected ? Colors.yellow : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.black54),
              ),
              child: Center(
              child: Text(
              time,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              ),
              ),
              );
              },
              ),
              ],
              ),
              const SizedBox(height: 20),
              if (selectedDate != null && selectedTime != null && selectedMovieId != null && selectedShowtimeId != null)
              ElevatedButton(
              onPressed: () {
              final selectedMovie = movieList.firstWhere(
              (m) => m['id'] == selectedMovieId,
              orElse: () => {
              'price': 0.0,
              'name': movieName,
              'showtimeId': selectedShowtimeId,
              },
              );
              Navigator.push(
              context,
              MaterialPageRoute(
              builder: (context) => SeatSelectionScreen(
              hallId: widget.hallId,
              movieId: selectedMovieId!,
              movieName: movieName,
              price: (selectedMovie['price'] as num?)?.toDouble() ?? 0.0,
              userId: widget.userId,
              showtimeId: selectedShowtimeId!,
              ),
              ),
              );
              },
              style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Next', style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
              ],
              ),
              ),
              ],
              ),
              ],
              ),
              ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}