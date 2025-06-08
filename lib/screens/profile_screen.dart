import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
// Import ekranu ustawień
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  /// Pobiera numer telefonu użytkownika – teraz zwraca numer w formacie, w jakim jest zapisany w Firestore.
  String getUserPhoneNumber() {
    if (user != null && user!.phoneNumber != null) {
      // Zakładamy, że numer jest zapisany z prefiksem (np. "+48123456789")
      return user!.phoneNumber!.trim();
    }
    return "Brak numeru";
  }

  /// Sprawdza połączenie z internetem
  Future<bool> checkInternetConnection() async {
    ConnectivityResult connectivityResult =
    await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// Usuwa ogłoszenie z Firestore
  void deleteListing(String listingId, BuildContext context) async {
    bool isConnected = await checkInternetConnection();
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Brak połączenia z internetem")),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('listings')
          .doc(listingId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ogłoszenie zostało usunięte.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Błąd podczas usuwania: $e")),
      );
    }
  }

  /// Otwiera okno edycji ogłoszenia
  void editListing(
      BuildContext context, String listingId, Map<String, dynamic> data) {
    TextEditingController titleController =
    TextEditingController(text: data['title']);
    TextEditingController locationController =
    TextEditingController(text: data['location']);
    TextEditingController dateController =
    TextEditingController(text: data['date']);
    TextEditingController priceController =
    TextEditingController(text: data['price'].toString());
    TextEditingController descriptionController =
    TextEditingController(text: data['description']);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Edytuj ogłoszenie"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: "Nazwa"),
                ),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: "Lokalizacja"),
                ),
                TextField(
                  controller: dateController,
                  decoration:
                  const InputDecoration(labelText: "Data (yyyy-MM-dd)"),
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: "Cena (PLN)"),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: "Opis pracy"),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Anuluj"),
            ),
            TextButton(
              onPressed: () async {
                bool isConnected = await checkInternetConnection();
                if (!isConnected) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Brak połączenia z internetem")),
                  );
                  return;
                }

                int? price = int.tryParse(priceController.text.trim());
                if (price == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Cena musi być liczbą!")),
                  );
                  return;
                }

                try {
                  await FirebaseFirestore.instance
                      .collection('listings')
                      .doc(listingId)
                      .update({
                    'title': titleController.text.trim(),
                    'location': locationController.text.trim(),
                    'date': dateController.text.trim(),
                    'price': price,
                    'description': descriptionController.text.trim(),
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Zmiany zapisane!")),
                  );
                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Błąd: $e")),
                  );
                }
              },
              child: const Text("Zapisz zmiany",
                  style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );
  }

  /// Buduje statyczny widok oceniania użytkownika w skali 5 gwiazdek.
  /// Średnia ocena wyświetlana jest jako gwiazdki, a obok pokazana jest ilość głosów.
  /// Użytkownik nie ma możliwości głosowania.
  Widget _buildUserRatingStars(double average, int votesCount) {
    int fullStars = average.floor();
    bool hasHalfStar = (average - fullStars) >= 0.5;
    return Row(
      children: [
        for (int i = 1; i <= 5; i++)
          Icon(
            i <= fullStars
                ? Icons.star
                : (i == fullStars + 1 && hasHalfStar
                ? Icons.star_half
                : Icons.star_border),
            color: Colors.amber,
            size: 24,
          ),
        const SizedBox(width: 8),
        Text("($votesCount)"),
      ],
    );
  }

  /// Widget wyświetlający aktywne ogłoszenia użytkownika.
  Widget _buildListings(String userPhone) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('listings')
          .where('userPhone', isEqualTo: userPhone)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(
              child: Text("Wystąpił błąd podczas ładowania ogłoszeń."));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Brak aktywnych zleceń."));
        }

        final listings = snapshot.data!.docs;
        return ListView.builder(
          itemCount: listings.length,
          itemBuilder: (context, index) {
            var data = listings[index].data() as Map<String, dynamic>;
            String listingId = listings[index].id;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                title: Text(
                  data['title'] ?? 'Brak nazwy',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("📍 Lokalizacja: ${data['location'] ?? 'Brak'}"),
                    Text("📅 Data: ${data['date'] ?? 'Brak'}"),
                    Text("💰 Cena: ${data['price'] ?? 'Brak'} PLN"),
                    Text("📜 Opis: ${data['description'] ?? 'Brak'}"),
                  ],
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () async {
                        bool isConnected = await checkInternetConnection();
                        if (!isConnected) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Brak połączenia z internetem"),
                            ),
                          );
                          return;
                        }
                        editListing(context, listingId, data);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        bool isConnected = await checkInternetConnection();
                        if (!isConnected) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Brak połączenia z internetem"),
                            ),
                          );
                          return;
                        }
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text("Usuń ogłoszenie"),
                              content: const Text(
                                  "Czy na pewno chcesz usunąć to ogłoszenie?"),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(),
                                  child: const Text("Anuluj"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    deleteListing(listingId, context);
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text("Usuń",
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  // Zakładam, że masz kolekcję "opinions", gdzie jest pole "reviewedUserId"
  // wskazujące na użytkownika, o którym jest opinia.




  /// Widget wyświetlający opinie o użytkowniku.
  /// Widget wyświetlający opinie o użytkowniku.
  Widget _buildOpinions() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text("Wystąpił błąd podczas ładowania opinii."));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;

        if (data == null || data['reviews'] == null) {
          return const Center(child: Text("Brak opinii."));
        }

        final reviewsRaw = data['reviews'];

        List<Map<String, dynamic>> reviews = [];

        if (reviewsRaw is Map) {
          reviews = reviewsRaw.entries.map((entry) {
            final value = entry.value as Map<String, dynamic>;
            return {
              'authorUid': entry.key,
              'text': value['text'],
              'timestamp': value['timestamp'],
            };
          }).toList();
        }

        if (reviews.isEmpty) {
          return const Center(child: Text("Brak opinii."));
        }

        return ListView.builder(
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            final review = reviews[index];
            final authorUid = review['authorUid'] ?? 'Nieznany';
            final comment = review['text'] ?? 'Brak komentarza';
            final timestamp = review['timestamp'];

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                title: Text("Autor: $authorUid"),
                subtitle: Text(comment),
                trailing: timestamp != null
                    ? Text(
                  (timestamp as Timestamp)
                      .toDate()
                      .toLocal()
                      .toString()
                      .split('.')[0],
                  style: const TextStyle(fontSize: 12),
                )
                    : const Text("Brak daty"),
              ),
            );
          },
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    // Jeśli użytkownik nie jest zalogowany, wyświetl komunikat.
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Nie jesteś zalogowany.")),
      );
    }

    // Pobieramy numer telefonu do filtrowania ogłoszeń.
    String userPhone = getUserPhoneNumber();

    return DefaultTabController(
      length: 2,
      // Domyślnie index: 0 -> zakładka "Ogłoszenia"
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Profil"),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --------------------------------
// 1. Wyświetlamy dane użytkownika i gwiazdki oceny
// --------------------------------
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("Błąd ładowania danych użytkownika."),
                  );
                }
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                String name = data?['name'] ?? 'Użytkownik';
                double ratingAverage = (data?['ratingAverage'] is int)
                    ? (data?['ratingAverage'] as int).toDouble()
                    : (data?['ratingAverage'] ?? 5.0);
                int votesCount = data?['votesCount'] ?? 0;

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hi, $name",
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      // Wyświetlamy jedynie gwiazdki oceny
                      _buildUserRatingStars(ratingAverage, votesCount),
                    ],
                  ),
                );
              },
            ),

// --------------------------------
// 2. Pasek zakładek (TabBar)
// --------------------------------
            const TabBar(
              // Dostosuj styl np. do swojego brandingu
              labelColor: Colors.blue, // kolor aktywnej zakładki
              unselectedLabelColor: Colors.grey, // kolor nieaktywnej zakładki
              tabs: [
                Tab(text: "Ogłoszenia"),
                Tab(text: "Opinie"),
              ],
            ),

// --------------------------------
// 3. W zależności od zakładki, pokaż ListView ogłoszeń lub opinii
// --------------------------------
            Expanded(
              child: TabBarView(
                children: [
                  // zakładka nr 1
                  _buildListings(userPhone),
                  // zakładka nr 2
                  _buildOpinions(),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }
}
