import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled3/screens/chat_screen.dart';
import '../screens/user_profile_screen.dart';

enum SortOption {
  publication,
  event,
  price,
}

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({Key? key}) : super(key: key);

  @override
  _ListingsScreenState createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  SortOption sortOption = SortOption.publication;
  String locationFilter = "";
  final User? currentUser = FirebaseAuth.instance.currentUser;
  late final String currentUserPhone;

  @override
  void initState() {
    super.initState();
    currentUserPhone = currentUser?.phoneNumber ?? "";
    // Sprawdzamy, czy użytkownik jest uwierzytelniony – reguły wymagają request.auth != null
    if (FirebaseAuth.instance.currentUser != null) {
      archiveExpiredListings();
    } else {
      print("Użytkownik nie jest uwierzytelniony – archiwizacja nie zostanie wykonana.");
    }
  }

  /// Funkcja archiwizująca ogłoszenia, których data (bez części czasowej)
  /// jest wcześniejsza niż dzisiejsza.
  /// Operacje zapisu do kolekcji "archive" oraz usunięcia z kolekcji "listings"
  /// są wykonywane w jednym batched write – dzięki temu, jeśli zapis do archive się nie powiedzie,
  /// żaden dokument nie zostanie usunięty.
  Future<void> archiveExpiredListings() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final listingsSnapshot =
    await FirebaseFirestore.instance.collection('listings').get();

    WriteBatch batch = FirebaseFirestore.instance.batch();
    int docsToArchive = 0;

    for (var doc in listingsSnapshot.docs) {
      final data = doc.data();
      DateTime listingDate;

      // Obsługa daty zapisanej jako Timestamp lub String
      if (data['date'] is Timestamp) {
        listingDate = (data['date'] as Timestamp).toDate();
      } else {
        try {
          listingDate = DateTime.parse(data['date']);
        } catch (e) {
          print("Błąd parsowania daty dla dokumentu ${doc.id}: $e");
          continue;
        }
      }

      // Ustalamy tylko część daty (rok, miesiąc, dzień)
      final listingDateOnly =
      DateTime(listingDate.year, listingDate.month, listingDate.day);

      // Jeśli ogłoszenie jest nieaktywne (data wcześniejsza niż dzisiejsza)
      if (listingDateOnly.isBefore(today)) {
        DocumentReference archiveRef =
        FirebaseFirestore.instance.collection('archive').doc(doc.id);
        DocumentReference listingRef =
        FirebaseFirestore.instance.collection('listings').doc(doc.id);

        // Dodajemy operację zapisu do archive oraz usunięcia z listings do batcha
        batch.set(archiveRef, data);
        batch.delete(listingRef);
        docsToArchive++;
      }
    }

    if (docsToArchive > 0) {
      try {
        await batch.commit();
        print("Pomyślnie zarchiwizowano $docsToArchive dokumentów.");
      } catch (e) {
        print("Błąd przy commitowaniu batcha: $e");
      }
    } else {
      print("Brak dokumentów do archiwizacji.");
    }
  }

  Stream<List<QueryDocumentSnapshot>> getListingsStream() {
    Query query = FirebaseFirestore.instance.collection('listings');

    switch (sortOption) {
      case SortOption.publication:
        query = query.orderBy('timestamp', descending: true);
        break;
      case SortOption.event:
        query = query.orderBy('date', descending: false);
        break;
      case SortOption.price:
        query = query.orderBy('price', descending: true);
        break;
    }

    return query.snapshots().map((snapshot) => snapshot.docs);
  }

  void _openFilterMenu() {
    SortOption tempSortOption = sortOption;
    String tempLocationFilter = locationFilter;
    TextEditingController locationController =
    TextEditingController(text: tempLocationFilter);

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Filtruj ogłoszenia",
                      style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    RadioListTile<SortOption>(
                      title: const Text("Sortuj od najnowszych"),
                      value: SortOption.publication,
                      groupValue: tempSortOption,
                      onChanged: (SortOption? value) {
                        setModalState(() {
                          tempSortOption = value!;
                        });
                      },
                    ),
                    RadioListTile<SortOption>(
                      title: const Text(
                          "Sortuj wg daty rozpoczęcia wydarzenia"),
                      value: SortOption.event,
                      groupValue: tempSortOption,
                      onChanged: (SortOption? value) {
                        setModalState(() {
                          tempSortOption = value!;
                        });
                      },
                    ),
                    RadioListTile<SortOption>(
                      title: const Text("Sortuj po cenie (od najwyższej)"),
                      value: SortOption.price,
                      groupValue: tempSortOption,
                      onChanged: (SortOption? value) {
                        setModalState(() {
                          tempSortOption = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: "Filtruj po lokalizacji",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          tempLocationFilter = value.trim().toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempSortOption = SortOption.publication;
                              tempLocationFilter = "";
                              locationController.text = "";
                            });
                            setState(() {
                              sortOption = SortOption.publication;
                              locationFilter = "";
                            });
                            Navigator.pop(context);
                          },
                          child: const Text("Resetuj filtry"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              sortOption = tempSortOption;
                              locationFilter = tempLocationFilter;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text("Zastosuj filtry"),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lista Ogłoszeń"),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, size: 30.0),
            onPressed: _openFilterMenu,
          ),
        ],
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot>>(
        stream: getListingsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Brak dostępnych ogłoszeń."));
          }

          List<QueryDocumentSnapshot> listings = snapshot.data!;
          if (locationFilter.isNotEmpty) {
            listings = listings.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              String location =
              (data['location'] ?? '').toString().toLowerCase();
              return location.contains(locationFilter);
            }).toList();
          }

          return ListView.builder(
            itemCount: listings.length,
            itemBuilder: (context, index) {
              var data = listings[index].data() as Map<String, dynamic>;
              return ListingCard(
                data: data,
                documentId: listings[index].id,
                currentUserPhone: currentUserPhone,
              );
            },
          );
        },
      ),
    );
  }
}

class ListingCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String documentId;
  final String currentUserPhone;

  const ListingCard({
    Key? key,
    required this.data,
    required this.documentId,
    required this.currentUserPhone,
  }) : super(key: key);

  @override
  _ListingCardState createState() => _ListingCardState();
}

class _ListingCardState extends State<ListingCard> {
  bool _showPhoneNumber = false;

  /// Normalizuje numer telefonu do formatu E.164
  String normalizePhoneNumber(String phone) {
    phone = phone.trim();
    if (phone.startsWith('+')) return phone;
    if (phone.length == 9) return '+48$phone';
    return phone;
  }

  /// Formatuje numer do postaci xxx-xxx-xxx (po usunięciu prefiksu kraju)
  String _formatPhoneNumber(String phone) {
    String normalized = normalizePhoneNumber(phone);
    if (normalized.startsWith('+48')) {
      normalized = normalized.substring(3);
    }
    if (normalized.length == 9) {
      return '${normalized.substring(0, 3)}-${normalized.substring(3, 6)}-${normalized.substring(6, 9)}';
    } else {
      return phone;
    }
  }

  /// Generuje chatId na podstawie dwóch znormalizowanych numerów
  String generateChatId(String phone1, String phone2) {
    String norm1 = normalizePhoneNumber(phone1);
    String norm2 = normalizePhoneNumber(phone2);
    if (norm1.compareTo(norm2) < 0) {
      return '$norm1-$norm2';
    } else {
      return '$norm2-$norm1';
    }
  }

  void _callUser(String phoneNumber) async {
    final Uri url = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      debugPrint("❌ Nie udało się otworzyć aplikacji telefonicznej.");
    }
  }

  /// Funkcja wysyłająca ocenę – zapisuje głos w podkolekcji "ratings"
  /// oraz aktualizuje średnią ocenę i liczbę głosów w głównym dokumencie ogłoszenia.
  Future<void> _submitRating(int ratingValue) async {
    try {
      await FirebaseFirestore.instance
          .collection('listings')
          .doc(widget.documentId)
          .collection('ratings')
          .doc(widget.currentUserPhone)
          .set({
        'user': widget.currentUserPhone,
        'value': ratingValue,
        'timestamp': FieldValue.serverTimestamp(),
      });
      final ratingsSnapshot = await FirebaseFirestore.instance
          .collection('listings')
          .doc(widget.documentId)
          .collection('ratings')
          .get();
      int votesCount = ratingsSnapshot.docs.length;
      double totalRating = 0;
      for (var doc in ratingsSnapshot.docs) {
        totalRating += (doc.data()['value'] ?? 0);
      }
      double averageRating = votesCount > 0 ? totalRating / votesCount : 0.0;
      await FirebaseFirestore.instance
          .collection('listings')
          .doc(widget.documentId)
          .update({
        'averageRating': averageRating,
        'votesCount': votesCount,
      });
    } catch (e) {
      debugPrint("Error submitting rating: $e");
    }
  }

  /// Buduje widget gwiazdek na podstawie średniej oceny.
  Widget _buildRatingStars(double average, int votesCount) {
    int fullStars = average.floor();
    bool hasHalfStar = (average - fullStars) >= 0.5;
    return Row(
      children: [
        for (int i = 1; i <= 5; i++)
          GestureDetector(
            onTap: () {
              _submitRating(i);
            },
            child: Icon(
              i <= fullStars
                  ? Icons.star
                  : (i == fullStars + 1 && hasHalfStar
                  ? Icons.star_half
                  : Icons.star_border),
              color: Colors.amber,
              size: 24,
            ),
          ),
        const SizedBox(width: 8),
        Text("($votesCount)"),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final String phoneNumber = data['userPhone'] ?? '';
    double price = double.tryParse(data['price'].toString()) ?? 0.0;
    bool isOwnListing = (normalizePhoneNumber(phoneNumber) ==
        normalizePhoneNumber(widget.currentUserPhone));

    String displayName;
    if (isOwnListing) {
      displayName = 'TY';
    } else if (data.containsKey('userName') &&
        (data['userName'] as String).trim().isNotEmpty) {
      displayName = data['userName'];
    } else {
      displayName = 'Brak nazwy';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['title'] ?? 'Brak nazwy',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "📍 Lokalizacja: ${data['location'] ?? 'Brak lokalizacji'}",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              "📅 Data: ${data['date'] ?? 'Brak daty'}",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              "💰 Cena: ${price.toInt()} PLN",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "📜 Opis: ${data['description'] ?? 'Brak opisu'}",
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            // System oceniania – pobieramy dane z podkolekcji "ratings"
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('listings')
                  .doc(widget.documentId)
                  .collection('ratings')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox();
                }
                if (!snapshot.hasData) {
                  return const SizedBox();
                }
                final ratingsDocs = snapshot.data!.docs;
                int votesCount = ratingsDocs.length;
                double totalRating = 0;
                for (var doc in ratingsDocs) {
                  var ratingValue = doc['value'] ?? 0;
                  totalRating += ratingValue;
                }
                double averageRating =
                votesCount > 0 ? totalRating / votesCount : 0.0;
                return _buildRatingStars(averageRating, votesCount);
              },
            ),
            const SizedBox(height: 8),
            // Przycisk profilu użytkownika
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(uid: data['userId']),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: data['profile'] != null &&
                            (data['profile'] as String).isNotEmpty
                            ? NetworkImage(data['profile'])
                            : null,
                        child: (data['profile'] == null ||
                            (data['profile'] as String).isEmpty)
                            ? const Icon(Icons.person, size: 16)
                            : null,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "Profil",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (phoneNumber.isNotEmpty)
              _showPhoneNumber
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!isOwnListing)
                    InkWell(
                      onTap: () => _callUser(phoneNumber),
                      child: Text(
                        _formatPhoneNumber(phoneNumber),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  InkWell(
                    onTap: () {
                      String chatId = generateChatId(
                          widget.currentUserPhone, phoneNumber);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chatId: chatId,
                            currentUserPhone: widget.currentUserPhone,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.message, color: Colors.green),
                      ],
                    ),
                  ),
                ],
              )
                  : Center(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showPhoneNumber = true;
                    });
                  },
                  child: const Text("Kontakt"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
