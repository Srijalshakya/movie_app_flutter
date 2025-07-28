import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:khalti_flutter/khalti_flutter.dart';
import 'package:movie_app/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return KhaltiScope(
      publicKey: 'test_public_key_5c5fa086bb704a54b1efd924a2acb036',
      builder: (context, navigatorKey) {
        return MaterialApp(
          title: 'Movie Booking App',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          navigatorKey: navigatorKey,
          supportedLocales: const [
            Locale('en', 'US'), // English
            Locale('ne', 'NP'), // Nepali
          ],
          localizationsDelegates: const [
            KhaltiLocalizations.delegate,
          ],
          initialRoute: '/login',
          routes: {
            '/login': (context) => const LoginScreen(),
            // Add other routes here as needed
          },
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
              child: child ?? const SizedBox(),
            );
          },
        );
      },
    );
  }
}