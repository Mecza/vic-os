import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class UserProfileScreen extends StatelessWidget {
  final String uid;

  const UserProfileScreen({Key? key, required this.uid}) : super(key: key);

  // Normalizuje numer telefonu – jeśli ma 9 cyfr, dodaje prefiks +48.
  String normalizePhoneNumber(String phone) {
    phone = phone.trim();
    if (phone.startsWith('+')) return phone;
    if (phone.length == 9) return '+48$phone';
    return phone;
  }

  // Generuje chatId na podstawie dwóch numerów telefonów.
  String generateChatId(String phone1, String phone2) {
    String norm1 = normalizePhoneNumber(phone1);
    String norm2 = normalizePhoneNumber(phone2);
    if (norm1.compareTo(norm2) < 0) {
      return '$norm1-$norm2';
    } else {
      return '$norm2-$norm1';
    }
  }

  // Buduje system gwiazdek na podstawie średniej oceny.
  Widget _buildStarRating(double rating) {
    int fullStars = rating.floor();
    bool hasHalfStar = (rating - fullStars) >= 0.5;
    int emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0);

    List<Widget> stars = [];
    for (int i = 0; i < fullStars; i++) {
      stars.add(const Icon(Icons.star, color: Colors.amber, size: 30));
    }
    if (hasHalfStar) {
      stars.add(const Icon(Icons.star_half, color: Colors.amber, size: 30));
    }
    for (int i = 0; i < emptyStars; i++) {
      stars.add(const Icon(Icons.star_border, color: Colors.amber, size: 30));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: stars,
    );
  }

  // Funkcja zapisująca ocenę użytkownika przy użyciu pola "ratings".
  Future<void> _submitUserRating(BuildContext context, int rating) async {
    final currentUserPhone = FirebaseAuth.instance.currentUser?.phoneNumber;
    if (currentUserPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nie jesteś zalogowany")),
      );
      return;
    }
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) {
          throw Exception("Użytkownik nie istnieje");
        }

        // Pobieramy aktualną mapę ocen lub inicjujemy pustą, jeśli jej nie ma.
        Map<String, dynamic> ratings = {};
        final data = userSnapshot.data() as Map<String, dynamic>;
        if (data.containsKey('ratings')) {
          ratings = Map<String, dynamic>.from(data['ratings']);
        }

        // Dodajemy lub aktualizujemy ocenę użytkownika (numer telefonu jako klucz).
        ratings[currentUserPhone] = rating;

        // Obliczamy liczbę głosów oraz sumę ocen.
        int votesCount = ratings.length;
        int totalRating = ratings.values.fold(0, (sum, element) => sum + (element is int ? element : 0));
        double averageRating = votesCount > 0 ? totalRating / votesCount : 0.0;

        // Aktualizujemy dokument użytkownika.
        transaction.update(userRef, {
          'ratings': ratings,
          'votesCount': votesCount,
          'ratingAverage': averageRating,
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ocena zapisana!"))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Błąd: ${e.toString()}"))
      );
    }
  }

  // Funkcja zapisująca opinię użytkownika.
  Future<void> _submitUserReview(BuildContext context, String reviewText) async {
    final currentUserPhone = FirebaseAuth.instance.currentUser?.phoneNumber;
    if (currentUserPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nie jesteś zalogowany")),
      );
      return;
    }
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) {
          throw Exception("Użytkownik nie istnieje");
        }
        Map<String, dynamic> reviews = {};
        final data = userSnapshot.data() as Map<String, dynamic>;
        if (data.containsKey('reviews')) {
          reviews = Map<String, dynamic>.from(data['reviews']);
        }
        // Dodajemy lub aktualizujemy opinię – kluczem jest numer telefonu oceniającego.
        reviews[currentUserPhone] = {
          'text': reviewText,
          'timestamp': FieldValue.serverTimestamp(),
        };
        transaction.update(userRef, {'reviews': reviews});
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Opinia zapisana!"))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Błąd: ${e.toString()}"))
      );
    }
  }

  // Dialog umożliwiający wybór oceny w skali 5 gwiazdek.
  Future<void> _showRatingDialog(BuildContext context) async {
    int selectedRating = 0;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text("Oceń użytkownika"),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                int starIndex = index + 1;
                return IconButton(
                  icon: Icon(
                    starIndex <= selectedRating
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber,
                    size: 30,
                  ),
                  onPressed: () {
                    setState(() {
                      selectedRating = starIndex;
                    });
                  },
                );
              }),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text("Anuluj"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedRating > 0) {
                    Navigator.of(context).pop();
                    _submitUserRating(context, selectedRating);
                  }
                },
                child: const Text("Zatwierdź"),
              ),
            ],
          );
        });
      },
    );
  }

  // Dialog umożliwiający dodanie lub edycję opinii.
  Future<void> _showReviewDialog(BuildContext context, String? currentReview) async {
    final TextEditingController controller = TextEditingController(text: currentReview);
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Dodaj opinię"),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: "Napisz swoją opinię...",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Anuluj"),
            ),
            ElevatedButton(
              onPressed: () {
                final reviewText = controller.text.trim();
                if (reviewText.isNotEmpty) {
                  Navigator.of(context).pop();
                  _submitUserReview(context, reviewText);
                }
              },
              child: const Text("Zatwierdź"),
            ),
          ],
        );
      },
    );
  }

  // Buduje zawartość zakładki Opinie.
  Widget _buildReviewsTab(BuildContext context, Map<String, dynamic> userData) {
    final currentUserPhone = FirebaseAuth.instance.currentUser?.phoneNumber;
    Map<String, dynamic> reviews = {};
    if (userData.containsKey('reviews')) {
      reviews = Map<String, dynamic>.from(userData['reviews']);
    }
    // Sprawdzamy, czy aktualny użytkownik już dodał opinię.
    String? currentUserReview;
    if (currentUserPhone != null && reviews.containsKey(currentUserPhone)) {
      final reviewData = reviews[currentUserPhone];
      if (reviewData is Map && reviewData.containsKey('text')) {
        currentUserReview = reviewData['text'];
      } else if (reviewData is String) {
        currentUserReview = reviewData;
      }
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Przycisk dodania/edycji opinii.
            ElevatedButton(
              onPressed: () {
                _showReviewDialog(context, currentUserReview);
              },
              child: Text(currentUserReview == null ? "Dodaj opinię" : "Edytuj opinię"),
            ),
            const SizedBox(height: 16),
            // Lista opinii.
            reviews.isEmpty
                ? const Text("Brak opinii")
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                String reviewerPhone = reviews.keys.elementAt(index);
                String reviewText;
                var reviewData = reviews[reviewerPhone];
                if (reviewData is Map && reviewData.containsKey('text')) {
                  reviewText = reviewData['text'];
                } else if (reviewData is String) {
                  reviewText = reviewData;
                } else {
                  reviewText = "";
                }
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(reviewerPhone + (currentUserPhone == reviewerPhone ? " (Ty)" : "")),
                    subtitle: Text(reviewText),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Używamy StreamBuildera, aby nasłuchiwać zmian w dokumencie użytkownika.
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        // Ekran ładowania.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Błąd: ${snapshot.error}')),
          );
        } else if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('Użytkownik nie został znaleziony')),
          );
        } else {
          final userData = snapshot.data!.data()!;
          final userName = userData['name'] as String? ?? 'Brak imienia';
          final ratingAverage = (userData['ratingAverage'] ?? 0).toDouble();
          // Pobieramy numer telefonu użytkownika, który jest oceniany.
          final targetUserPhone = userData['phone'] as String? ?? '';

          // Widget nagłówka profilu.
          Widget profileHeader = Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Icon(
                  Icons.person,
                  size: 100,
                ),
                const SizedBox(height: 16),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ocena: ${ratingAverage.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                _buildStarRating(ratingAverage),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _showRatingDialog(context),
                  child: const Text("Oceń"),
                ),
              ],
            ),
          );

          // Numer telefonu aktualnie zalogowanego użytkownika.
          final currentUserPhone = FirebaseAuth.instance.currentUser?.phoneNumber;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Profil użytkownika'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.chat),
                  onPressed: () {
                    if (currentUserPhone != null && targetUserPhone.isNotEmpty) {
                      String chatId =
                      generateChatId(currentUserPhone, targetUserPhone);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chatId: chatId,
                            currentUserPhone: currentUserPhone,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Brak numeru telefonu do chatu")),
                      );
                    }
                  },
                ),
              ],
            ),
            body: DefaultTabController(
              length: 2, // 2 zakładki: Ogłoszenia i Opinie.
              child: Column(
                children: [
                  // Nagłówek profilu.
                  profileHeader,
                  // Pasek zakładek umieszczony pod nagłówkiem.
                  TabBar(
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    indicatorColor: Colors.blue,
                    tabs: const [
                      Tab(text: 'Ogłoszenia'),
                      Tab(text: 'Opinie'),
                    ],
                  ),
                  // Zawartość zakładek.
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Zakładka: Ogłoszenia użytkownika.
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('listings')
                              .where('userId', isEqualTo: uid)
                              .orderBy('timestamp', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return const Center(child: Text("Brak ogłoszeń"));
                            }
                            final listings = snapshot.data!.docs;
                            return ListView.builder(
                              itemCount: listings.length,
                              itemBuilder: (context, index) {
                                final data = listings[index].data() as Map<String, dynamic>;
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 16),
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    title: Text(data['title'] ?? 'Brak tytułu'),
                                    subtitle: Text(data['location'] ?? 'Brak lokalizacji'),
                                    trailing: Text("${data['price'] ?? 0} PLN"),
                                    onTap: () {
                                      // Możesz dodać nawigację do szczegółów ogłoszenia.
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        // Zakładka: Opinie użytkownika.
                        _buildReviewsTab(context, userData),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}
