import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:socket_io_client/socket_io_client.dart' as IO;

// Modèle pour un dépanneur
class Depanneur {
  final String nom;
  final double latitude;
  final double longitude;
  final String specialite;
  final double note;
  final String telephone;
  final double distance;
  final bool disponible;

  Depanneur({
    required this.nom,
    required this.latitude,
    required this.longitude,
    required this.specialite,
    required this.note,
    required this.telephone,
    required this.distance,
    required this.disponible,
  });
}

// Modèle pour les types de problèmes
class TypeProbleme {
  final String nom;
  final IconData icone;
  final Color couleur;

  TypeProbleme({required this.nom, required this.icone, required this.couleur});
}

class CMecano extends StatefulWidget {
  @override
  _CMecanoState createState() => _CMecanoState();
}

class _CMecanoState extends State<CMecano> {
  // Position actuelle simulée (Alger)
  final double _currentLat = 36.7538;
  final double _currentLng = 3.0588;

  // Dio et gestion des cookies
  final dio = Dio();
  PersistCookieJar? cookieJar;

  IO.Socket? socket;
  int? userId; // L'id du client connecté
  bool demandeAcceptee = false;
  Map<String, dynamic>? mecanicienInfos;

  @override
  void initState() {
    super.initState();
    _initCookieJar();
    _initSocket();
  }

  Future<void> _initCookieJar() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      cookieJar = PersistCookieJar();
      dio.interceptors.add(CookieManager(cookieJar!));
    }
    // Sur le web, NE PAS ajouter CookieManager !
  }

  @override
  void dispose() {
    socket?.dispose();
    super.dispose();
  }

  void _initSocket() async {
    final meResponse = await dio.get(
      'http://localhost:3000/users/me',
      options: Options(extra: {'withCredentials': true}),
    );
    userId = meResponse.data['id'];
    print('Mon userId : $userId');

    socket = IO.io(
      'http://localhost:3000',
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .enableAutoConnect()
        .build(),
    );

    socket!.onConnect((_) {
      print('Connecté au serveur Socket.io');
      if (userId != null) {
        socket!.emit('subscribe', userId);
        print('Subscribed to user_$userId');
      }
    });

    socket!.on('demande_acceptee', (data) {
      print('Demande acceptée reçue : $data');
      if (!mounted) return;
      setState(() {
        demandeAcceptee = true;
        mecanicienInfos = data['mecanicien'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Votre demande a été acceptée !')),
      );
    });

    socket!.onDisconnect((_) => print('Déconnecté de Socket.io'));
  }

  // Liste des dépanneurs proches (données simulées)
  List<Depanneur> depanneurs = [
    Depanneur(
      nom: "Garage El Madania",
      latitude: 36.7580,
      longitude: 3.0620,
      specialite: "Mécanique générale",
      note: 4.5,
      telephone: "+213 555 123 456",
      distance: 1.2,
      disponible: true,
    ),
    Depanneur(
      nom: "Auto Service Kouba",
      latitude: 36.7480,
      longitude: 3.0550,
      specialite: "Électricité auto",
      note: 4.2,
      telephone: "+213 555 789 012",
      distance: 0.8,
      disponible: true,
    ),
    Depanneur(
      nom: "Dépannage Express",
      latitude: 36.7600,
      longitude: 3.0480,
      specialite: "Dépannage 24h/24",
      note: 4.8,
      telephone: "+213 555 345 678",
      distance: 1.5,
      disponible: false,
    ),
    Depanneur(
      nom: "Garage Central",
      latitude: 36.7520,
      longitude: 3.0640,
      specialite: "Carrosserie",
      note: 4.0,
      telephone: "+213 555 901 234",
      distance: 2.1,
      disponible: true,
    ),
  ];

  // Types de problèmes disponibles (icône corrigée)
  List<TypeProbleme> typesProblemes = [
    TypeProbleme(
      nom: "Panne moteur",
      icone: Icons.settings,
      couleur: Colors.red,
    ),
    TypeProbleme(
      nom: "Batterie",
      icone: Icons.battery_alert,
      couleur: Colors.orange,
    ),
    TypeProbleme(
      nom: "Pneu crevé",
      icone: Icons.circle,
      couleur: Colors.blue,
    ),
    TypeProbleme(
      nom: "Accident",
      icone: Icons.car_crash,
      couleur: Colors.purple,
    ),
    TypeProbleme(
      nom: "Panne essence",
      icone: Icons.local_gas_station,
      couleur: Colors.green,
    ),
    TypeProbleme(
      nom: "Problème électrique",
      icone: Icons.electrical_services,
      couleur: Colors.yellow[700]!,
    ),
  ];

  // Centre de la carte (Alger)
  final LatLng _center = LatLng(36.7538, 3.0588);

  // Génère les marqueurs pour les dépanneurs (flutter_map)
  List<Marker> get _depanneurMarkers {
    return depanneurs.map((depanneur) {
      return Marker(
        point: LatLng(depanneur.latitude, depanneur.longitude),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showDepanneurDetails(depanneur),
          child: Icon(
            Icons.car_repair,
            color: depanneur.disponible ? Colors.green : Colors.red,
            size: 36,
          ),
        ),
      );
    }).toList();
  }

  // Fonction de réservation réelle
  Future<void> envoyerDemande() async {
    try {
      // Récupérer la position GPS du client
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      // Récupérer l'id du client via /users/me
      final meResponse = await dio.get(
        'http://localhost:3000/users/me',
        options: Options(
          extra: {'withCredentials': true},
        ),
      );
      final clientId = meResponse.data['id'];
      final response = await dio.post(
        'http://localhost:3000/demandes',
        data: {
          'client_id': clientId,
          'type_demande': 'mecanicien',
          'position_lat': position.latitude,
          'position_lng': position.longitude,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          extra: {'withCredentials': true},
        ),
      );
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Demande envoyée, en cours de traitement…')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'envoi de la demande')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 152, 0),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.directions_car, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Ph DEALER',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section localisation
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color.fromARGB(255, 255, 152, 0), Colors.orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.location_on, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Votre position',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        Text(
                          'Alger Centre, Algérie',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.gps_fixed, color: Colors.white),
                ],
              ),
            ),

            // Carte des dépanneurs
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mécaniciens proches',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Carte
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: FlutterMap(
                        options: MapOptions(center: _center, zoom: 13.0),
                        children: [
                          TileLayer(
                            urlTemplate:
                                "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                            subdomains: ['a', 'b', 'c'],
                          ),
                          MarkerLayer(markers: _depanneurMarkers),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bouton de réservation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: demandeAcceptee
                        ? mecanicienInfos != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Demande acceptée',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Mécanicien : ${mecanicienInfos!['nom']} ${mecanicienInfos!['prenom']}'),
                                  Text('Téléphone : ${mecanicienInfos!['telephone']}'),
                                  Text('Position : ${mecanicienInfos!['position_lat']}, ${mecanicienInfos!['position_lng']}'),
                                ],
                              )
                            : const Text('Demande acceptée')
                        : ElevatedButton(
                            onPressed: envoyerDemande,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 255, 152, 0),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 18,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: const Text('Réserver maintenant'),
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  void _showDepanneurDetails(Depanneur depanneur) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(depanneur.nom),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Spécialité: ${depanneur.specialite}'),
              const SizedBox(height: 8),
              Text('Note: ⭐ ${depanneur.note}/5'),
              const SizedBox(height: 8),
              Text('Distance: ${depanneur.distance} km'),
              const SizedBox(height: 8),
              Text('Téléphone: ${depanneur.telephone}'),
              const SizedBox(height: 8),
              Text(
                'Statut: ${depanneur.disponible ? "Disponible" : "Occupé"}',
                style: TextStyle(
                  color: depanneur.disponible ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
            if (depanneur.disponible)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _contactDepanneur(depanneur);
                },
                child: const Text('Contacter'),
              ),
          ],
        );
      },
    );
  }

  void _contactDepanneur(Depanneur depanneur) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Contacter ${depanneur.nom}'),
          content: const Text('Voulez-vous appeler ce mécanicien?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Appel vers ${depanneur.telephone}')),
                );
              },
              child: const Text('Appeler'),
            ),
          ],
        );
      },
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Assistance Auto',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.white,
      ),
      home: CMecano(),
      debugShowCheckedModeBanner: false,
    );
  }
}

void main() {
  runApp(MyApp());
}
