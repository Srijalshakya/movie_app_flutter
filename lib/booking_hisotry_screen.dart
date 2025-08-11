import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingHistoryScreen extends StatefulWidget {
  final String uid;
  const BookingHistoryScreen({super.key, required this.uid});

  @override
  _BookingHistoryScreenState createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchBookingHistory() async {
    try {
      final snapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: widget.uid)
          .orderBy('bookingTime', descending: true)
          .get();

      final bookings = await Future.wait(snapshot.docs.map((doc) async {
        final data = doc.data();
        final hallId = data['hallId']?.toString() ?? '';
        final showtimeId = data['showtimeId']?.toString() ?? '';

        String hallName = 'Unknown Hall';
        try {
          final hallDoc = await _firestore.collection('halls').doc(hallId).get();
          hallName = hallDoc.data()?['name']?.toString() ?? 'Unknown Hall';
        } catch (e) {
          print('Error fetching hall name for hallId $hallId: $e');
        }

        Map<String, dynamic> showtimeDetails = {'date': 'Unknown', 'time': 'Unknown'};
        try {
          final movieDoc = await _firestore
              .collection('halls')
              .doc(hallId)
              .collection('movies')
              .doc(showtimeId)
              .get();
          if (movieDoc.exists) {
            final movieData = movieDoc.data();
            final dateStr = movieData?['date']?.toString();
            final showTime = movieData?['showTime']?.toString();
            if (dateStr != null && showTime != null) {
              try {
                final date = DateTime.parse(dateStr).toUtc().add(const Duration(hours: 5, minutes: 45));
                final formattedDate = DateFormat('MMM dd, yyyy').format(date);
                final timeParts = showTime.split(':');
                if (timeParts.isNotEmpty) {
                  final hourStr = timeParts[0].trim();
                  final minuteStr = timeParts.length > 1 ? timeParts[1].replaceAll(RegExp(r'[^0-9]'), '') : '0';
                  final isAm = showTime.toLowerCase().contains('am');
                  final isPm = showTime.toLowerCase().contains('pm');
                  int hour = int.parse(hourStr);
                  final minute = int.parse(minuteStr);
                  if (isPm && hour != 12) {
                    hour += 12;
                  } else if (isAm && hour == 12) {
                    hour = 0;
                  }
                  final formattedTime = DateFormat('hh:mm a').format(DateTime(0, 1, 1, hour, minute));
                  showtimeDetails = {'date': formattedDate, 'time': formattedTime};
                }
              } catch (e) {
                print('Error parsing date or showTime for showtimeId $showtimeId: $e');
              }
            }
          }
        } catch (e) {
          print('Error fetching showtime details for showtimeId $showtimeId: $e');
        }

        return {
          'id': doc.id,
          'movieName': data['movieName']?.toString() ?? 'Unknown Movie',
          'hallName': hallName,
          'seatNames': List<String>.from(data['seatNames'] ?? []),
          'totalPrice': (data['totalPrice'] is double ? data['totalPrice'] : double.tryParse(data['totalPrice']?.toString() ?? '0.0')) ?? 0.0,
          'bookingTime': data['bookingTime'] != null ? DateTime.parse(data['bookingTime']).toLocal() : DateTime.now(),
          'date': showtimeDetails['date'],
          'time': showtimeDetails['time'],
        };
      }).toList());

      return bookings;
    } catch (e) {
      print('Error fetching booking history: $e');
      return [];
    }
  }

  Future<void> _downloadTicket(String? ticketUrl, String bookingId) async {
    if (ticketUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket not available for this booking.')),
      );
      return;
    }

    try {
      final url = Uri.parse(ticketUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open ticket URL.')),
        );
      }
    } catch (e) {
      print('Error downloading ticket for booking $bookingId: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading ticket: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
        title: const Text(
          'Booking History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchBookingHistory(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading booking history...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
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
              );
            }

            final bookings = snapshot.data ?? [];
            if (bookings.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, color: Colors.white30, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'No booking history available',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your past bookings will appear here',
                      style: TextStyle(color: Colors.white30),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: bookings.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final booking = bookings[index];
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  booking['movieName'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                              if (booking['ticketUrl'] != null)
                                GestureDetector(
                                  onTap: () => _downloadTicket(booking['ticketUrl'], booking['id']),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Download Ticket',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, color: Colors.white60, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  booking['hallName'],
                                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.event_seat, color: Colors.white60, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Seats: ${booking['seatNames'].join(", ")}',
                                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.white60, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Date: ${booking['date']}',
                                style: const TextStyle(color: Colors.white60, fontSize: 14),
                              ),
                            ],

                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.access_time, color: Colors.white60, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Time: ${booking['time']}',
                                style: const TextStyle(color: Colors.white60, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.attach_money, color: Colors.white60, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Total: NPR ${booking['totalPrice'].toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white60, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.schedule, color: Colors.white60, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Booked: ${DateFormat('MMM dd, yyyy HH:mm').format(booking['bookingTime'])}',
                                style: const TextStyle(color: Colors.white60, fontSize: 14),
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
      ),
    );
  }
}