import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:movie_app/SeatBookingScreen.dart';
import 'package:movie_app/profile.dart';
import 'package:movie_app/movie_details_screen.dart';

import 'booking_hisotry_screen.dart';

class HomeScreen extends StatefulWidget {
  final String uid;
  const HomeScreen({super.key, required this.uid});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DateTime currentDate = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 45));
  Future<List<Map<String, dynamic>>> _hallsFuture = Future.value([]);
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    _hallsFuture = _fetchHalls().catchError((e) {
      print('Error fetching halls: $e');
      return <Map<String, dynamic>>[];
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0D1117),
      body: CustomScrollView(
        slivers: [
          // Modern App Bar with gradient
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            leading: Container(),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1a1d29),
                    Color(0xFF0D1117),
                  ],
                ),
              ),
              child: FlexibleSpaceBar(
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.local_movies,
                        color: Color(0xFFFF6B6B),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'CineMax',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                centerTitle: false,
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              ),
            ),
          ),

          // Header section with location and menu
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFFFF6B6B), size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Kathmandu, Nepal',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _scaffoldKey.currentState?.openDrawer(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.menu, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Choose Your Cinema',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Book tickets for the latest movies',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Cinema halls list
          SliverToBoxAdapter(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _hallsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    height: 400,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading cinemas...',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Container(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    height: 300,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.movie_outlined, color: Colors.white30, size: 64),
                          SizedBox(height: 16),
                          Text(
                            'No cinemas available',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Check back later for updates',
                            style: TextStyle(color: Colors.white30),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final halls = snapshot.data!;
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: halls.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final hall = halls[index];
                    final imageBytes = _decodeImage(hall['imageUrl']);

                    return TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 600 + (index * 100)),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 30 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF1e2328),
                              const Color(0xFF161b22),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HallMoviesScreen(
                                    hallId: hall['id'],
                                    userId: widget.uid,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  // Cinema Image
                                  Hero(
                                    tag: 'cinema_${hall['id']}',
                                    child: Container(
                                      width: 100,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            const Color(0xFFFF6B6B).withOpacity(0.3),
                                            const Color(0xFF4ECDC4).withOpacity(0.3),
                                          ],
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: imageBytes != null
                                            ? Image.memory(
                                          imageBytes,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return _buildDefaultCinemaIcon();
                                          },
                                        )
                                            : _buildDefaultCinemaIcon(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),

                                  // Cinema Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          hall['name'],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on_outlined,
                                              color: Colors.white60,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                hall['location'],
                                                style: const TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),

                                        // Action button
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                                            ),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Text(
                                            'View Movies',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Arrow icon
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.white70,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 30),
          ),
        ],
      ),

      // Modern Drawer
      drawer: Drawer(
        backgroundColor: const Color(0xFF0D1117),
        child: Column(
          children: [
            // Drawer Header
            Container(
              height: 200,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1a1d29),
                    Color(0xFF0D1117),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Color(0xFFFF6B6B),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Welcome Back!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Enjoy your movie experience',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  _buildModernListTile(
                    icon: Icons.local_movies,
                    title: 'Movies',
                    subtitle: 'Browse all movies',
                    onTap: () => Navigator.pop(context),
                  ),
                  _buildModernListTile(
                    icon: Icons.person_outline,
                    title: 'Profile',
                    subtitle: 'Manage your account',
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
                _buildModernListTile(
                    icon: Icons.history,
                    title: 'Booking History',
                    subtitle: 'View past bookings',
                    onTap: () {
                      Navigator.pop(context); // Close the drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookingHistoryScreen(uid: widget.uid),
                        ),
                      );
                    },
                ),
                  const Divider(color: Colors.white10, height: 32),
                  _buildModernListTile(
                    icon: Icons.logout,
                    title: 'Logout',
                    subtitle: 'Sign out of account',
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultCinemaIcon() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF6B6B).withOpacity(0.3),
            const Color(0xFF4ECDC4).withOpacity(0.3),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.local_movies,
          color: Colors.white70,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildModernListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isDestructive ? Colors.red : const Color(0xFFFF6B6B))
                .withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isDestructive ? Colors.red : const Color(0xFFFF6B6B),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? Colors.red : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDestructive ? Colors.red.withOpacity(0.7) : Colors.white60,
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: isDestructive ? Colors.red.withOpacity(0.7) : Colors.white30,
          size: 16,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// Modern HallMoviesScreen with updated UI
class HallMoviesScreen extends StatefulWidget {
  final String hallId;
  final String userId;
  const HallMoviesScreen({super.key, required this.hallId, required this.userId});

  @override
  _HallMoviesScreenState createState() => _HallMoviesScreenState();
}

class _HallMoviesScreenState extends State<HallMoviesScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DateTime currentDate = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 45));
  String? selectedDate;
  String? selectedTime;
  String? selectedMovieId;
  String? selectedShowtimeId;
  List<Map<String, dynamic>> movieDetailsList = [];
  Future<List<Map<String, dynamic>>> _moviesFuture = Future.value([]);
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    _moviesFuture = _fetchMovies().catchError((e) {
      print('Error fetching movies: $e');
      return <Map<String, dynamic>>[];
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      backgroundColor: const Color(0xFF0D1117),
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 100.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1a1d29),
                    Color(0xFF0D1117),
                  ],
                ),
              ),
              child: const FlexibleSpaceBar(
                title: Text(
                  'Movies in Hall',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                centerTitle: false,
                titlePadding: EdgeInsets.only(left: 60, bottom: 16),
              ),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Movies Content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _moviesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 400,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Loading movies...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Container(
                      height: 200,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Container(
                      height: 300,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.movie_outlined, color: Colors.white30, size: 64),
                            SizedBox(height: 16),
                            Text(
                              'No upcoming movies available',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Check back later for updates',
                              style: TextStyle(color: Colors.white30),
                            ),
                          ],
                        ),
                      ),
                    );
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

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    itemCount: movieGroups.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      final movieName = movieGroups.keys.elementAt(index);
                      final movieList = movieGroups[movieName]!;
                      final availableDates = getAvailableDates(movieList);
                      final availableTimes = selectedDate != null ? getAvailableTimes(movieList) : [];

                      final movieDetail = movieDetailsList.isNotEmpty && index < movieDetailsList.length
                          ? movieDetailsList[index]
                          : movieList[0];
                      final imageBytes = _decodeImage(movieList[0]['imageUrl']);

                      return TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 600 + (index * 100)),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, 30 * (1 - value)),
                            child: Opacity(
                              opacity: value,
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF1e2328),
                                const Color(0xFF161b22),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Movie Header
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Movie Poster
                                    GestureDetector(
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
                                      child: Hero(
                                        tag: 'movie_${movieDetail['id']}',
                                        child: Container(
                                          width: 120,
                                          height: 160,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                const Color(0xFFFF6B6B).withOpacity(0.3),
                                                const Color(0xFF4ECDC4).withOpacity(0.3),
                                              ],
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(16),
                                            child: imageBytes != null
                                                ? Image.memory(
                                              imageBytes,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return _buildDefaultMovieIcon();
                                              },
                                            )
                                                : _buildDefaultMovieIcon(),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),

                                    // Movie Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            movieName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 22,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          if (movieDetail['rating'] != 'N/A')
                                            Row(
                                              children: [
                                                const Icon(Icons.star, color: Colors.amber, size: 16),
                                                const SizedBox(width: 4),
                                                Text(
                                                  movieDetail['rating'],
                                                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                                                ),
                                              ],
                                            ),
                                          if (movieDetail['duration'] != 'N/A')
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.access_time, color: Colors.white60, size: 16),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    movieDetail['duration'],
                                                    style: const TextStyle(color: Colors.white60, fontSize: 14),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                // Date Selection Section
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Select Date',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                if (availableDates.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: Text(
                                        'No upcoming dates available.',
                                        style: TextStyle(color: Colors.white54, fontSize: 16),
                                      ),
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: availableDates.map((date) {
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
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFFFF6B6B)
                                                : Colors.white.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isSelected
                                                  ? const Color(0xFFFF6B6B)
                                                  : Colors.white.withOpacity(0.3),
                                            ),
                                          ),
                                          child: Text(
                                            date['display']!,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isSelected ? Colors.white : Colors.white70,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),

                                // Time Selection Section
                                if (selectedDate != null) ...[
                                  const SizedBox(height: 24),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Select Time',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  if (availableTimes.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                        child: Text(
                                          'No upcoming showtimes available.',
                                          style: TextStyle(color: Colors.white54, fontSize: 16),
                                        ),
                                      ),
                                    )
                                  else
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: availableTimes.map((timeData) {
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
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? const Color(0xFF4ECDC4)
                                                  : Colors.white.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: isSelected
                                                    ? const Color(0xFF4ECDC4)
                                                    : Colors.white.withOpacity(0.3),
                                              ),
                                            ),
                                            child: Text(
                                              time,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isSelected ? Colors.white : Colors.white70,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                ],

                                // Proceed Button
                                if (selectedDate != null && selectedTime != null && selectedMovieId != null && selectedShowtimeId != null) ...[
                                  const SizedBox(height: 24),
                                  Container(
                                    width: double.infinity,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                                      ),
                                      borderRadius: BorderRadius.circular(28),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF6B6B).withOpacity(0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
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
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(28),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Book Seats',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(Icons.arrow_forward, color: Colors.white),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultMovieIcon() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF6B6B).withOpacity(0.3),
            const Color(0xFF4ECDC4).withOpacity(0.3),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.movie,
          color: Colors.white70,
          size: 40,
        ),
      ),
    );
  }
}