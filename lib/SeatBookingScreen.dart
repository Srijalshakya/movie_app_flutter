import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:khalti_flutter/khalti_flutter.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SeatSelectionScreen extends StatefulWidget {
  final String hallId;
  final String movieId;
  final String movieName;
  final double price;
  final String userId;
  final String showtimeId;

  const SeatSelectionScreen({
    Key? key,
    required this.hallId,
    required this.movieId,
    required this.movieName,
    required this.price,
    required this.userId,
    required this.showtimeId,
  }) : super(key: key);

  @override
  _SeatSelectionScreenState createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> seats = [];
  List<String> selectedSeatNames = [];
  bool isLoading = true;
  bool isProcessing = false;
  String? hallName;
  StreamSubscription<DocumentSnapshot>? _subscription;
  int columnsPerRow = 10;

  @override
  void initState() {
    super.initState();
    _subscribeToHallData();
  }

  void _subscribeToHallData() {
    _subscription = _firestore
        .collection('halls')
        .doc(widget.hallId)
        .snapshots()
        .listen((hallDoc) async {
      if (hallDoc.exists) {
        final hallData = hallDoc.data() ?? {};
        hallName = hallData['name']?.toString() ?? 'Unknown Hall';
        final seatList = List<Map<String, dynamic>>.from(hallData['seats'] ?? []);

        if (seatList.isNotEmpty) {
          final showtimeDoc = await _firestore
              .collection('halls')
              .doc(widget.hallId)
              .collection('showtimes')
              .doc(widget.showtimeId)
              .get();
          final showtimeSeats = showtimeDoc.exists
              ? List<Map<String, dynamic>>.from(showtimeDoc.data()?['seats'] ?? [])
              : [];

          final maxColumns = seatList.fold<int>(0, (max, seat) {
            final name = seat['name']?.toString() ?? '';
            if (RegExp(r'^[A-Z][0-9]+$').hasMatch(name)) {
              final colNum = int.tryParse(name.substring(1)) ?? 0;
              return colNum > max ? colNum : max;
            }
            return max;
          });
          columnsPerRow = maxColumns > 0 ? maxColumns : 10;

          setState(() {
            seats = seatList.asMap().entries.map((entry) {
              final index = entry.key;
              final seat = entry.value;
              final generatedName = _generateSeatName(index);
              final seatName = seat['name']?.toString();
              final isValidSeatName = seatName != null && RegExp(r'^[A-P][0-9]+$').hasMatch(seatName);
              final finalName = isValidSeatName ? seatName! : generatedName;

              final showtimeSeat = showtimeSeats.firstWhere(
                    (s) => s['name'] == finalName,
                orElse: () => {'status': 'available'},
              );

              return {
                'id': seat['id']?.toString() ?? 'seat_$finalName',
                'name': finalName,
                'status': showtimeSeat['status']?.toString() ?? 'available',
              };
            }).toList();
            isLoading = false;
            selectedSeatNames.removeWhere((name) => seats.any((seat) => seat['name'] == name && seat['status'] != 'available'));
            print('Seats loaded: ${seats.map((s) => s['name']).toList()}');
          });
        } else {
          setState(() {
            seats = [];
            isLoading = false;
            selectedSeatNames.clear();
            print('No seats found for hall ${widget.hallId}');
          });
        }
      } else {
        setState(() {
          seats = [];
          isLoading = false;
          selectedSeatNames.clear();
          print('Hall ${widget.hallId} does not exist');
        });
      }
    }, onError: (e) {
      print('Error fetching hall data: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching hall data: $e')),
        );
      }
    });
  }

  String _generateSeatName(int index) {
    final row = String.fromCharCode(65 + (index ~/ columnsPerRow));
    final col = (index % columnsPerRow) + 1;
    return '$row$col';
  }

  Future<String> getUserName(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        final name = userData['name']?.toString() ?? userData['displayName']?.toString() ?? 'Guest';
        print('Fetched user name from Firestore: $name');
        return name;
      }
      final displayName = FirebaseAuth.instance.currentUser?.displayName ?? 'Guest';
      print('Fetched user name from Firebase Auth: $displayName');
      return displayName;
    } catch (e) {
      print('Error fetching user name: $e');
      return 'Guest';
    }
  }

  Future<String> saveOrderToFirestore(List<String> seatNames, double totalPrice, String uid, String? ticketUrl) async {
    try {
      final orderRef = await _firestore.collection('bookings').add({
        'userId': uid,
        'hallId': widget.hallId,
        'movieId': widget.movieId,
        'movieName': widget.movieName,
        'showtimeId': widget.showtimeId,
        'seatNames': seatNames,
        'totalPrice': totalPrice,
        'bookingTime': DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 45)).toIso8601String(),
        'status': 'confirmed',
      });
      print('Order saved to Firestore with ID: ${orderRef.id}, Seats: $seatNames, Quantity: ${seatNames.length}');
      return orderRef.id;
    } catch (e) {
      print('Error saving order to Firestore: $e');
      throw Exception('Failed to save booking: $e');
    }
  }

  Future<void> updateSeatStatus(List<String> seatNames) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final showtimeRef = _firestore
            .collection('halls')
            .doc(widget.hallId)
            .collection('showtimes')
            .doc(widget.showtimeId);
        final showtimeDoc = await transaction.get(showtimeRef);

        List<Map<String, dynamic>> currentSeats = [];
        if (showtimeDoc.exists) {
          currentSeats = List<Map<String, dynamic>>.from(showtimeDoc.data()?['seats'] ?? []);
        } else {
          final hallDoc = await _firestore.collection('halls').doc(widget.hallId).get();
          final hallSeats = List<Map<String, dynamic>>.from(hallDoc.data()?['seats'] ?? []);
          currentSeats = hallSeats.map((seat) => {
            'id': seat['id'],
            'name': seat['name'],
            'status': 'available',
          }).toList();
        }

        for (var seatName in seatNames) {
          final seat = currentSeats.firstWhere((s) => s['name'] == seatName, orElse: () => {});
          if (seat.isEmpty || seat['status'] != 'available') {
            throw Exception('Seat $seatName is no longer available.');
          }
        }

        final updatedSeats = currentSeats.map((seat) {
          if (seatNames.contains(seat['name'])) {
            return {
              'id': seat['id'],
              'name': seat['name'],
              'status': 'sold',
              'price': widget.price,
            };
          }
          return seat;
        }).toList();

        transaction.set(showtimeRef, {'seats': updatedSeats});
      });
      print('Seat statuses updated for showtime ${widget.showtimeId}: $seatNames');
      setState(() {
        selectedSeatNames.clear();
      });
    } catch (e) {
      print('Error updating seat status: $e');
      throw Exception('Failed to update seat status: $e');
    }
  }

  Future<Map<String, dynamic>> generateMovieTicketPDF({
    required String movieName,
    required String hallName,
    required String personName,
    required int quantity,
    required double price,
    required List<String> seatNames,
  }) async {
    try {
      print('Generating PDF with: movieName=$movieName, hallName=$hallName, personName=$personName, quantity=$quantity, seatNames=$seatNames');
      if (seatNames.isEmpty) {
        throw Exception('No seats provided for PDF generation');
      }
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(color: Color(0xFFE50914)),
                SizedBox(width: 16),
                Text('Generating ticket...'),
              ],
            ),
          ),
        );
      }

      final pdf = pw.Document(compress: true);
      final qrData = 'Movie: $movieName, Hall: $hallName, Name: $personName, Seats: ${seatNames.join(", ")}, Tickets: $quantity, Total: NPR ${price.toStringAsFixed(2)}';
      if (qrData.length > 2953) {
        throw Exception('QR data too long for encoding.');
      }
      final qrImage = await QrPainter(
        data: qrData,
        version: QrVersions.auto,
        gapless: false,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      ).toImageData(300);
      if (qrImage == null) {
        throw Exception('Failed to generate QR code.');
      }
      final qrMemoryImage = pw.MemoryImage(qrImage.buffer.asUint8List());

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(
                      '🎟 Movie Ticket',
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text('Movie name: $movieName', style: const pw.TextStyle(fontSize: 16)),
                  pw.Text('Hall name: $hallName', style: const pw.TextStyle(fontSize: 16)),
                  pw.Text('Name: $personName', style: const pw.TextStyle(fontSize: 16)),
                  pw.Text('Booked Seats: ${seatNames.join(", ")}', style: const pw.TextStyle(fontSize: 16)),
                  pw.Text('Number of Tickets: $quantity', style: const pw.TextStyle(fontSize: 16)),
                  pw.Text('Total Price: NPR ${price.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 16)),
                  pw.SizedBox(height: 20),
                  pw.Center(child: pw.Image(qrMemoryImage, width: 150, height: 150)),
                ],
              ),
            );
          },
        ),
      );

      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final fileName = '${widget.userId}_${DateTime.now().millisecondsSinceEpoch}_ticket.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
        print('Failed to open local PDF: ${result.message}');
      }

      String? downloadUrl;
      try {
        final ref = FirebaseStorage.instance.ref().child('tickets/$fileName');
        final uploadTask = await ref.putData(bytes);
        downloadUrl = await uploadTask.ref.getDownloadURL();
        print('Ticket uploaded to Firebase Storage: $downloadUrl');
      } catch (e) {
        print('Error uploading PDF to Firebase Storage: $e');
      }

      if (mounted) {
        Navigator.of(context).pop();
      }

      return {
        'filePath': file.path,
        'downloadUrl': downloadUrl,
      };
    } catch (e) {
      print('Error generating PDF: $e');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating ticket: $e')),
        );
      }
      return {
        'filePath': null,
        'downloadUrl': null,
      };
    }
  }

  Future<void> bookTickets(double totalPrice, List<String> seatNames, String uid) async {
    if (!_formKey.currentState!.validate()) {
      print('Form validation failed');
      setState(() => isProcessing = false);
      return;
    }

    if (seatNames.isEmpty) {
      print('No seats selected');
      setState(() => isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one seat.')),
      );
      return;
    }

    // Create a deep copy of seatNames to prevent state mutations
    final bookedSeatNames = List<String>.from(seatNames);
    final quantity = bookedSeatNames.length;
    print('Booking tickets: totalPrice=$totalPrice, seatNames=$bookedSeatNames, quantity=$quantity, uid=$uid');
    setState(() => isProcessing = true);

    try {
      await KhaltiScope.of(context).pay(
        config: PaymentConfig(
          amount: (totalPrice * 100).toInt(),
          productIdentity: 'movie-tickets-${widget.userId}_${DateTime.now().millisecondsSinceEpoch}',
          productName: '${widget.movieName} Tickets',
        ),
        preferences: [
          PaymentPreference.khalti,
          PaymentPreference.connectIPS,
          PaymentPreference.eBanking,
          PaymentPreference.mobileBanking,
        ],
        onSuccess: (success) async {
          print('Payment Success: $success');
          try {
            await updateSeatStatus(bookedSeatNames);
            print('Seat statuses updated for seats: $bookedSeatNames');

            final personName = await getUserName(uid);
            print('Fetched user name: $personName, Quantity: $quantity, Seats: ${bookedSeatNames.join(", ")}');

            bool pdfOpened = false;
            String? localFilePath;
            String? downloadUrl;
            try {
              final pdfResult = await generateMovieTicketPDF(
                movieName: widget.movieName,
                hallName: hallName ?? 'Unknown Hall',
                personName: personName,
                quantity: quantity,
                price: totalPrice,
                seatNames: bookedSeatNames,
              );
              localFilePath = pdfResult['filePath'];
              downloadUrl = pdfResult['downloadUrl'];
              pdfOpened = localFilePath != null;
              print('PDF generation completed. Local path: $localFilePath, URL: $downloadUrl');
            } catch (e) {
              print('PDF generation failed, proceeding with booking: $e');
            }

            final orderId = await saveOrderToFirestore(bookedSeatNames, totalPrice, uid, downloadUrl);
            print('Booking saved with orderId: $orderId');

            if (mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Text('Booking Confirmed'),
                  content: Text(
                    'Your movie tickets for "${widget.movieName}" have been booked successfully!\n'
                        'Booked Seats: ${bookedSeatNames.join(", ")}\n'
                        'Number of Tickets: $quantity\n'
                        'Total Price: NPR ${totalPrice.toStringAsFixed(2)}\n'
                        '${pdfOpened ? "Ticket generated and opened." : "Ticket generation failed, but booking is confirmed. You can try downloading the ticket later."}',
                  ),
                  actions: [
                    if (localFilePath != null || downloadUrl != null)
                      TextButton(
                        onPressed: () async {
                          try {
                            if (localFilePath != null) {
                              final result = await OpenFile.open(localFilePath);
                              if (result.type == ResultType.done) return;
                              print('Failed to open local PDF: ${result.message}');
                            }
                            if (downloadUrl != null) {
                              final url = Uri.parse(downloadUrl);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Could not open ticket URL.')),
                                  );
                                }
                              }
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Ticket not available. Please try again later.')),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error opening ticket: $e')),
                              );
                            }
                          }
                        },
                        child: const Text('Download Ticket'),
                      ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        try {
                          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                        } catch (e) {
                          print('Navigation error: $e');
                          if (mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                      },
                      child: const Text('Return to Homepage'),
                    ),
                  ],
                ),
              );
            }
          } catch (e) {
            print('Error processing booking: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    e.toString().contains('no longer available')
                        ? 'Some selected seats are no longer available. Please choose different seats.'
                        : 'Error processing booking: $e',
                  ),
                ),
              );
            }
          }
        },
        onFailure: (failure) {
          print('Payment Failed: $failure');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment failed. Please try again.')),
            );
          }
        },
        onCancel: () {
          print('Payment Cancelled');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment cancelled')),
            );
          }
        },
      );
    } catch (e) {
      print('Error initiating payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error opening payment. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  Color _getSeatColor(String status, bool isSelected) {
    if (isSelected) return Colors.yellow;
    if (status == 'sold') return Colors.red;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueGrey, Colors.black],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: const Center(child: Text('Please login to book tickets.', style: TextStyle(color: Colors.white, fontSize: 18))),
        ),
      );
    }

    final seatCount = seats.length;
    final isSmallHall = seatCount >= 50 && seatCount <= 60;
    final isLargeHall = seatCount > 100;

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: Text(
          'Book Seats - ${widget.movieName}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        backgroundColor: const Color(0xFFE50914),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : seats.isEmpty
          ? const Center(child: Text('No seats available.', style: TextStyle(color: Colors.white54, fontSize: 18)))
          : Padding(
        padding: EdgeInsets.all(isSmallHall ? 12.0 : 8.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15.0),
                color: Colors.grey[800],
                child: const Text(
                  'SCREEN',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columnsPerRow,
                    childAspectRatio: isSmallHall ? 1.5 : (isLargeHall ? 1.2 : 1.5),
                    crossAxisSpacing: isSmallHall ? 6 : 4,
                    mainAxisSpacing: isSmallHall ? 6 : 4,
                  ),
                  itemCount: seats.length,
                  itemBuilder: (context, index) {
                    final seat = seats[index];
                    final isSelected = selectedSeatNames.contains(seat['name']);
                    return GestureDetector(
                      onTap: seat['status'] == 'available'
                          ? () {
                        setState(() {
                          if (isSelected) {
                            selectedSeatNames.remove(seat['name']);
                          } else {
                            selectedSeatNames.add(seat['name']);
                          }
                          print('Selected seats updated: $selectedSeatNames');
                        });
                      }
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _getSeatColor(seat['status'], isSelected),
                          borderRadius: BorderRadius.circular(isSmallHall ? 8 : 6),
                          border: Border.all(color: Colors.black54),
                        ),
                        child: Center(
                          child: Text(
                            seat['name'],
                            style: TextStyle(fontSize: isSmallHall ? 16 : 14, color: Colors.black87),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegend(Colors.white, 'Available'),
                  const SizedBox(width: 15),
                  _buildLegend(Colors.yellow, 'Selected'),
                  const SizedBox(width: 15),
                  _buildLegend(Colors.red, 'Sold'),
                ],
              ),
              const SizedBox(height: 25),
              if (selectedSeatNames.isNotEmpty)
                Column(
                  children: [
                    Text(
                      'Your Seats: ${selectedSeatNames.join(", ")}',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    Text(
                      'Number of Tickets: ${selectedSeatNames.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    Text(
                      'Total Price: NPR ${(selectedSeatNames.length * widget.price).toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: isProcessing
                          ? null
                          : () => bookTickets(
                        selectedSeatNames.length * widget.price,
                        selectedSeatNames,
                        widget.userId,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE50914),
                        minimumSize: const Size(double.infinity, 55),
                      ),
                      child: isProcessing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Book Tickets', style: TextStyle(fontSize: 20, color: Colors.white)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 25,
          height: 25,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.black54),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
      ],
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
