import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminMovieSchedule extends StatefulWidget {
  const AdminMovieSchedule({super.key});

  @override
  _AdminMovieScheduleState createState() => _AdminMovieScheduleState();
}

class _AdminMovieScheduleState extends State<AdminMovieSchedule> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? selectedHallId;
  String? selectedMovieId;
  final List<DateTime> _selectedDates = [];
  final List<String> _timeSlots = ['10:00 AM', '2:00 PM', '6:00 PM', '9:00 PM', '10:00 PM'];
  final List<bool> _isAvailable = List.filled(5, true);

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

  Future<void> _addMovieToHall() async {
    if (selectedHallId == null || selectedMovieId == null || _selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a hall, movie, and dates.')),
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
      final hallDoc = await _firestore.collection('halls').doc(selectedHallId).get();
      final movieDoc = await _firestore.collection('movies').doc(selectedMovieId).get();
      if (hallDoc.exists && movieDoc.exists) {
        final hallData = hallDoc.data() as Map<String, dynamic>;
        final movieData = movieDoc.data() as Map<String, dynamic>;
        for (var date in _selectedDates) {
          await _firestore.collection('halls').doc(selectedHallId).collection('movies').add({
            'name': movieData['name'],
            'showTime': _timeSlots.firstWhere((slot) => _isAvailable[_timeSlots.indexOf(slot)]),
            'date': date.toIso8601String(),
            'imageUrl': movieData['imageUrl'],
            'price': hallData['pricePerSeat'],
            'hallName': hallData['name'],
            'expiresAt': date.add(const Duration(days: 1)).toIso8601String(),
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Movie scheduled successfully!')),
        );
        setState(() {
          _selectedDates.clear();
          _isAvailable.fillRange(0, _isAvailable.length, true);
          selectedMovieId = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scheduling movie: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C2526),
      appBar: AppBar(
        title: const Text('Schedule Movies', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFE50914),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            FutureBuilder<QuerySnapshot>(
              future: _firestore.collection('halls').get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final halls = snapshot.data!.docs;
                return DropdownButton<String>(
                  hint: const Text('Select Hall', style: TextStyle(color: Colors.white54)),
                  value: selectedHallId,
                  items: halls.map((hall) {
                    final hallData = hall.data() as Map<String, dynamic>;
                    return DropdownMenuItem<String>(
                      value: hall.id,
                      child: Text(hallData['name'], style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => selectedHallId = value),
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: const Color(0xFF2A3438),
                );
              },
            ),
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
            ElevatedButton(
              onPressed: _addMovieToHall,
              child: const Text('Schedule Movie'),
            ),
          ],
        ),
      ),
    );
  }
}