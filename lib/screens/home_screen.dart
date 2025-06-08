import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled3/services/listings_screen.dart';
import 'package:untitled3/screens/add_job_screen.dart';
import 'package:untitled3/screens/chat_list_screen.dart';
import 'package:untitled3/screens/profile_screen.dart' as profile;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  /// Zmienna przechowująca numer telefonu zalogowanego użytkownika.
  String? currentUserPhone;






  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    // Pobieramy numer telefonu z obiektu user, może być null jeśli użytkownik nie jest zalogowany
    currentUserPhone = user?.phoneNumber;

    final phoneNumber = FirebaseAuth.instance.currentUser?.phoneNumber;
    print("Aktualny numer telefonu użytkownika: $phoneNumber");

  }

  @override
  Widget build(BuildContext context) {
    // Przygotowujemy listę ekranów. Jeżeli currentUserPhone jest null,
    // to można np. przekazać pusty string lub przekierować do logowania.
    final List<Widget> screens = [
      const ListingsScreen(),
      AddJobScreen(),
      ChatListScreen(
        currentUserId: currentUserPhone ?? '',
      ),
      profile.ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.announcement),
            label: "Ogłoszenia",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: "Dodaj",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.email),
            label: "Wiadomości",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Konto",
          ),
        ],
      ),
    );
  }
}
