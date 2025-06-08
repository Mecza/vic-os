import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled3/screens/home_screen.dart';

class UserNameScreen extends StatefulWidget {
  const UserNameScreen({Key? key}) : super(key: key);

  @override
  State<UserNameScreen> createState() => _UserNameScreenState();
}

class _UserNameScreenState extends State<UserNameScreen> {
  final TextEditingController nameController = TextEditingController();
  bool isLoading = false;


  final double ratingAverage = 5.0;

  Future<void> saveDataAndNavigate() async {
    setState(() {
      isLoading = true;
    });

    final String name = nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proszę wprowadzić imię')),
      );
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Pobieramy aktualnie zalogowanego użytkownika
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Błąd: użytkownik nie jest zalogowany.')),
      );
      setState(() {
        isLoading = false;
      });
      return;
    }

    final String uid = currentUser.uid;
    final String? phone = currentUser.phoneNumber;

    try {
      // Zapis danych do kolekcji "users" w Firestore z polem ratingAverage
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'phone': phone ?? '', // jeżeli phone jest null, zapisujemy pusty string
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'ratingAverage': ratingAverage, // wartość 5.0 lub inna przekazana wartość
      });

      // Po udanym zapisie przechodzimy do ekranu HomeScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (error) {
      // W przypadku błędu wyświetlamy komunikat
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd zapisu: $error')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, // Wyśrodkowanie pionowe
              children: [
                const Text(
                  "Podaj swoje imię",
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    fillColor: Colors.grey.withOpacity(0.25),
                    filled: true,
                    hintText: "Imię",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: saveDataAndNavigate,
                  child: const Text(
                    "Dalej",
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

