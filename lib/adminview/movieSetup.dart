import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Moviesetup extends StatefulWidget {
  const Moviesetup({super.key});

  @override
  State<Moviesetup> createState() => _MoviesetupState();
}

class _MoviesetupState extends State<Moviesetup> {
  final TextEditingController name = TextEditingController();
  final TextEditingController duration = TextEditingController();
  final TextEditingController cast = TextEditingController();
  final TextEditingController description = TextEditingController();
  final TextEditingController rating = TextEditingController();
  String? base64Image;
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<void> _addMovie() async {
    if (name.text.isNotEmpty && duration.text.isNotEmpty && cast.text.isNotEmpty &&
        description.text.isNotEmpty && rating.text.isNotEmpty && base64Image != null) {
      try {
        await _firestore.collection('movies').add({
          'name': name.text,
          'duration': duration.text,
          'cast': cast.text,
          'description': description.text,
          'rating': rating.text,
          'imageUrl': base64Image,
          'date': DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 45)).toIso8601String(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Movie added successfully!')),
        );
        name.clear();
        duration.clear();
        cast.clear();
        description.clear();
        rating.clear();
        setState(() => base64Image = null);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding movie: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select an image.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C2526),
      appBar: AppBar(
        title: const Text('Manage Movies', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFE50914),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: name,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter Movie Name',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF2A3438),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: duration,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter Duration (min)',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF2A3438),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: cast,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter Cast',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF2A3438),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: description,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter Description',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF2A3438),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: rating,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Enter Rating (e.g.,4.5)',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF2A3438),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _pickImage,
                child: const Text('Pick Movie Image'),
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
                onPressed: _addMovie,
                child: const Text('Add Movie'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}