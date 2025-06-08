import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:untitled3/screens/chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum SortOption {
  publication,
  event,
  price,
}

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  _ListingsScreenState createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  // Domyślnie sortowanie wg daty publikacji
  SortOption sortOption = SortOption.publication;
  String locationFilter = "";

  // Pobranie danych aktualnego użytkownika z FirebaseAuth
  final User? currentUser = FirebaseAuth.instance.currentUser;
  late final String currentUserPhone;
  late final String currentUserUid;

  @override
  void initState() {
    super.initState();
    currentUserPhone = currentUser?.phoneNumber ?? "";
    currentUserUid = currentUser?.uid ?? "";
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
    // Tymczasowe zmienne lokalne do przechowywania wyborów w oknie filtra.
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
                      title:
                      const Text("Sortuj wg daty rozpoczęcia wydarzenia"),
                      value: SortOption.event,
                      groupValue: tempSortOption,
                      onChanged: (SortOption? value) {
                        setModalState(() {
                          tempSortOption = value!;
                        });
                      },
                    ),
                    RadioListTile<SortOption>(
                      title:
                      const Text("Sortuj po cenie (od najwyższej)"),
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
            icon: const Icon(
              Icons.filter_list,
              size: 30.0,
            ),
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
                currentUserPhone: currentUserPhone,
                currentUserUid: currentUserUid,
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
  final String currentUserPhone;
  final String currentUserUid;
  const ListingCard({
    Key? key,
    required this.data,
    required this.currentUserPhone,
    required this.currentUserUid,
  }) : super(key: key);

  @override
  _ListingCardState createState() => _ListingCardState();
}

class _ListingCardState extends State<ListingCard> {
  bool _showPhoneNumber = false;

  /// Formatuje numer do postaci xxx-xxx-xxx (zakładamy, że numer ma 9 cyfr)
  String _formatPhoneNumber(String phone) {
    if (phone.length == 9) {
      return '${phone.substring(0, 3)}-${phone.substring(3, 6)}-${phone.substring(6, 9)}';
    } else {
      return phone;
    }
  }

  /// Generuje chatId na podstawie dwóch identyfikatorów (UID lub, gdy UID nie są dostępne – numery telefonu)
  String generateChatId(String id1, String id2) {
    if (id1.compareTo(id2) < 0) {
      return '$id1-$id2';
    } else {
      return '$id2-$id1';
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

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final String phoneNumber = data['userPhone'] ?? '';
    final String listingUserUid = data['userId'] ?? '';
    double price = double.tryParse(data['price'].toString()) ?? 0.0;
    bool isOwnListing = (phoneNumber == widget.currentUserPhone) ||
        (listingUserUid == widget.currentUserUid);

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
            // Tytuł ogłoszenia
            Text(
              data['title'] ?? 'Brak nazwy',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            // Jeśli ogłoszenie należy do aktualnego użytkownika – wyświetlamy informację
            if (isOwnListing)
              Padding(
                padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                child: Text(
                  "Ogłoszenie wystawione przez Ciebie",
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.blueGrey[700],
                      fontStyle: FontStyle.italic),
                ),
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
            if (phoneNumber.isNotEmpty)
              isOwnListing
              // Własne ogłoszenie – nie pokazujemy opcji kontaktu
                  ? Center(
                child: Text(
                  "To jest Twoje ogłoszenie",
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              )
                  : _showPhoneNumber
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                    onTap: () async {
                      // Wybieramy identyfikator: jeśli UID jest dostępne, używamy go, w przeciwnym razie numer telefonu
                      String currentIdentifier = widget.currentUserUid.isNotEmpty
                          ? widget.currentUserUid
                          : widget.currentUserPhone;
                      String listingIdentifier = listingUserUid.isNotEmpty
                          ? listingUserUid
                          : phoneNumber;
                      String chatId =
                      generateChatId(currentIdentifier, listingIdentifier);

                      // Sprawdzenie, czy dokument chatu istnieje; jeśli nie – utworzenie nowej rozmowy
                      DocumentReference chatRef = FirebaseFirestore.instance
                          .collection('chats')
                          .doc(chatId);
                      DocumentSnapshot chatSnapshot = await chatRef.get();
                      if (!chatSnapshot.exists) {
                        await chatRef.set({
                          'chatId': chatId,
                          'participants': [widget.currentUserPhone, phoneNumber],
                          'timestamp': FieldValue.serverTimestamp(),
                        });
                      }

                      // Nawigacja do ekranu chatu
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
                          data['userName'] ?? 'chat',
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
