import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AddJobScreen extends StatefulWidget {
  const AddJobScreen({super.key});

  @override
  State<AddJobScreen> createState() => _AddJobScreenState();
}

class _AddJobScreenState extends State<AddJobScreen> {
  final TextEditingController nameController = TextEditingController(); // Tytuł ogłoszenia
  final TextEditingController locationController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final User? user = FirebaseAuth.instance.currentUser;

  /// Pobiera numer telefonu użytkownika i formatuje go.
  /// Zwraca numer w formacie E.164 (np. "+48123456789") lub "Brak numeru".
  String getUserPhoneNumber() {
    if (user != null && user!.phoneNumber != null) {
      return user!.phoneNumber!.trim();
    }
    return "Brak numeru";
  }

  /// Pobiera aktualną lokalizację i zamienia ją na adres.
  Future<void> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Usługa lokalizacji jest wyłączona.")),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Brak uprawnień do lokalizacji.")),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Uprawnienia do lokalizacji są na stałe wyłączone.")),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address =
            "${place.street ?? ''} ${place.subThoroughfare ?? ''}, ${place.locality ?? ''}";
        setState(() {
          locationController.text = address;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lokalizacja pobrana: $address")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nie udało się pobrać adresu.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Błąd pobierania lokalizacji: $e")),
      );
    }
  }

  /// Otwiera DatePicker i ustawia wybraną datę w dateController.
  Future<void> pickDate(BuildContext context) async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selectedDate != null) {
      setState(() {
        dateController.text = DateFormat('yyyy-MM-dd').format(selectedDate);
      });
    }
  }

  /// Sprawdza połączenie z internetem.
  Future<bool> checkInternetConnection() async {
    ConnectivityResult connectivityResult =
    await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// Dodaje ogłoszenie do Firestore.
  /// Używamy ujednoliconych nazw pól: "title" dla tytułu ogłoszenia oraz "userPhone" i "userName" dla danych użytkownika.
  Future<void> addListing(BuildContext context) async {
    // Sprawdzenie połączenia z internetem.
    bool isConnected = await checkInternetConnection();
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Brak połączenia z internetem")),
      );
      return;
    }

    String title = nameController.text.trim(); // tytuł ogłoszenia
    String location = locationController.text.trim();
    String date = dateController.text.trim();
    String priceText = priceController.text.trim();
    String description = descriptionController.text.trim();
    String userPhone = getUserPhoneNumber();

    if (title.isEmpty ||
        location.isEmpty ||
        date.isEmpty ||
        priceText.isEmpty ||
        description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wszystkie pola muszą być wypełnione!")),
      );
      return;
    }

    if (title.length > 40) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nazwa (tytuł ogłoszenia) może mieć maksymalnie 40 znaków!")),
      );
      return;
    }

    if (location.length > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lokalizacja może mieć maksymalnie 50 znaków!")),
      );
      return;
    }

    if (description.length > 150) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Opis może mieć maksymalnie 150 znaków!")),
      );
      return;
    }

    int? price = int.tryParse(priceText);
    if (price == null || price <= 0 || price >= 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Cena musi być liczbą całkowitą większą niż 0 i mniejszą niż 10 000!")),
      );
      return;
    }

    // Pobieramy dane użytkownika z kolekcji "users" na podstawie uid.
    // Zakładamy, że w kolekcji "users" pola to: "phone" oraz "name".
    String userName = "Unknown";
    String userId = "";
    if (user != null) {
      userId = user!.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
      userName = userData?['name'] ?? "Unknown";
    }

    try {
      // Dodajemy ogłoszenie do kolekcji "listings".
      // Używamy spójnych nazw pól: "title" dla tytułu ogłoszenia,
      // "userPhone" oraz "userName" dla danych użytkownika.
      await FirebaseFirestore.instance.collection('listings').add({
        'title': title,
        'location': location,
        'date': date,
        'price': price,
        'description': description,
        'userPhone': userPhone,
        'userName': userName,
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ogłoszenie dodane!")),
      );

      // Czyszczenie pól formularza.
      nameController.clear();
      locationController.clear();
      dateController.clear();
      priceController.clear();
      descriptionController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Błąd: $e")),
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    dateController.dispose();
    priceController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dodaj ogłoszenie")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Pole tytułu ogłoszenia
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Nazwa (tytuł ogłoszenia)",
                  labelStyle: TextStyle(fontSize: 16),
                ),
                maxLength: 40,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: locationController,
                decoration: InputDecoration(
                  labelText: "Lokalizacja",
                  hintText: "Ulica, dzielnica, miasto",
                  labelStyle: const TextStyle(fontSize: 16),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.location_pin, color: Colors.red, size: 24),
                    onPressed: getCurrentLocation,
                  ),
                ),
                maxLength: 50,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dateController,
                decoration: InputDecoration(
                  labelText: "Data (yyyy-MM-dd)",
                  labelStyle: const TextStyle(fontSize: 16),
                  suffixIcon: GestureDetector(
                    onTap: () => pickDate(context),
                    child: Container(
                      padding: const EdgeInsets.only(right: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.calendar_today, color: Colors.blue, size: 24),
                          SizedBox(width: 4),
                          Text("Wybierz datę", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: "Cena (PLN)",
                  labelStyle: TextStyle(fontSize: 16),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: "Opis pracy",
                  labelStyle: TextStyle(fontSize: 16),
                ),
                maxLines: 4,
                maxLength: 150,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => addListing(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: const Text("Dodaj ogłoszenie"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
