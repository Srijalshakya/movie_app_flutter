import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'movie_schedule.dart';

class HallSetup extends StatefulWidget {
  const HallSetup({super.key});

  @override
  State<HallSetup> createState() => _HallSetupState();
}

class _HallSetupState extends State<HallSetup> {
  final TextEditingController name = TextEditingController();
  final TextEditingController location = TextEditingController();
  final TextEditingController seatCapacity = TextEditingController();
  final TextEditingController pricePerSeat = TextEditingController();
  String? base64Image;
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<DateTime> _selectedDates = [];
  final List<String> _timeSlots = ['10:00 AM', '2:00 PM', '6:00 PM', '9:00 PM', '10:00 PM'];
  final List<bool> _isAvailable = List.filled(5, true);
  String? selectedMovieId;

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final compressed = await FlutterImageCompress.compressWithFile(
          pickedFile.path,
          quality: 70,
        );
        if (compressed != null) {
          final base64String = base64Encode(compressed);
          if (base64String.length > 500000) {
            final lowerQuality = await FlutterImageCompress.compressWithFile(
              pickedFile.path,
              quality: 30,
            );
            base64Image = lowerQuality != null ? base64Encode(lowerQuality) : base64String;
          } else {
            base64Image = base64String;
          }
          setState(() {});
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to compress image.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image selected.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _selectDate() async {
    final DateTime now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 45));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDates.isEmpty ? now : _selectedDates.last,
      firstDate: now,
      lastDate: now.add(const Duration(days: 7)),
    );
    if (picked != null && !_selectedDates.contains(picked)) {
      setState(() => _selectedDates.add(picked));
    }
  }

  Future<void> _addHall() async {
    if (name.text.isEmpty ||
        location.text.isEmpty ||
        seatCapacity.text.isEmpty ||
        pricePerSeat.text.isEmpty ||
        base64Image == null ||
        _selectedDates.isEmpty ||
        selectedMovieId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields, select an image, set dates, and choose a movie.')),
      );
      return;
    }

    int seats = 0; // Default to 0, will be updated after parsing
    double? price;
    try {
      seats = int.parse(seatCapacity.text);
      price = double.parse(pricePerSeat.text);
      if (seats <= 0 || price <= 0) {
        throw const FormatException('Seat capacity and price must be positive numbers.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid input: $e')),
      );
      return;
    }

    if (!_isAvailable.contains(true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one time slot must be available.')),
      );
      return;
    }

    try {
      final hallRef = await _firestore.collection('halls').add({
        'name': name.text,
        'location': location.text,
        'seatCapacity': seats,
        'pricePerSeat': price,
        'imageUrl': base64Image,
        'seats': List.generate(seats, (index) => {
          'id': index + 1,
          'name': _generateSeatName(index + 1, seats), // seats is now non-null
          'status': 'available',
          'price': price,
        }),
        'schedule': _selectedDates.map((date) => {
          'date': date.toIso8601String(),
          'timeSlots': Map.fromIterables(_timeSlots, _isAvailable),
        }).toList(),
      });

      final movieDoc = await _firestore.collection('movies').doc(selectedMovieId).get();
      if (movieDoc.exists) {
        final movieData = movieDoc.data() as Map<String, dynamic>;
        await hallRef.collection('movies').add({
          'name': movieData['name'],
          'showTime': _timeSlots.firstWhere((slot) => _isAvailable[_timeSlots.indexOf(slot)]),
          'date': _selectedDates.first.toIso8601String(),
          'imageUrl': movieData['imageUrl'],
          'price': price,
          'hallName': name.text,
          'expiresAt': _selectedDates.first.add(const Duration(days: 1)).toIso8601String(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hall and initial movie added successfully!')),
      );

      name.clear();
      location.clear();
      seatCapacity.clear();
      pricePerSeat.clear();
      setState(() {
        base64Image = null;
        _selectedDates.clear();
        _isAvailable.fillRange(0, _isAvailable.length, true);
        selectedMovieId = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding hall: $e')),
      );
    }
  }

  String _generateSeatName(int seatIndex, int totalSeats) {
    const rows = 'ABCDEFGHIJ';
    final rowIndex = (seatIndex - 1) ~/ 10;
    final colIndex = (seatIndex - 1) % 10 + 1;
    return rowIndex < rows.length ? '${rows[rowIndex]}$colIndex' : 'Z$colIndex';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C2526),
      appBar: AppBar(
        title: const Text('Manage Halls', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFE50914),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminMovieSchedule()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: name,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter Hall Name',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF2A3438),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: location,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter Location',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF2A3438),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: seatCapacity,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter Seat Capacity',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF2A3438),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: pricePerSeat,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter Price Per Seat',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF2A3438),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Pick Hall Image'),
            ),
            if (base64Image != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.memory(
                  base64Decode(base64Image!),
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _selectDate,
              child: const Text('Add Date for Schedule'),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0,
              children: _selectedDates.map((date) => Chip(
                label: Text(DateFormat('yyyy-MM-dd').format(date), style: const TextStyle(color: Colors.white)),
                onDeleted: () => setState(() => _selectedDates.remove(date)),
              )).toList(),
            ),
            const SizedBox(height: 20),
            const Text('Set Time Slots Availability', style: TextStyle(color: Colors.white70)),
            ...List.generate(_timeSlots.length, (index) => ListTile(
              title: Text(_timeSlots[index], style: const TextStyle(color: Colors.white)),
              trailing: Switch(
                value: _isAvailable[index],
                onChanged: (value) => setState(() => _isAvailable[index] = value),
                activeColor: Colors.red,
              ),
            )),
            const SizedBox(height: 20),
            FutureBuilder<QuerySnapshot>(
              future: _firestore.collection('movies').get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final movies = snapshot.data!.docs;
                return DropdownButton<String>(
                  hint: const Text('Select Movie', style: TextStyle(color: Colors.white54)),
                  value: selectedMovieId,
                  items: movies.map((movie) {
                    final movieData = movie.data() as Map<String, dynamic>;
                    return DropdownMenuItem<String>(
                      value: movie.id,
                      child: Text(movieData['name'], style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => selectedMovieId = value),
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: const Color(0xFF2A3438),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addHall,
              child: const Text('Add Hall'),
            ),
          ],
        ),
      ),
    );
  }
}