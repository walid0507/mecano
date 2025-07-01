import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:geolocator/geolocator.dart';

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

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Position actuelle simulée (Alger)
  final double _currentLat = 36.7538;
  final double _currentLng = 3.0588;

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
    ), // Icône corrigée
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

  final dio = Dio();
  PersistCookieJar? cookieJar;

  @override
  void initState() {
    super.initState();
    _initCookieJar();
  }

  Future<void> _initCookieJar() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      cookieJar = PersistCookieJar();
      dio.interceptors.add(CookieManager(cookieJar!));
    }
    // Sur le web, NE PAS ajouter CookieManager !
  }

  Future<void> envoyerDemande() async {
    try {
      // Récupérer la position GPS du client
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      // Récupérer l'id du client
      final meResponse = await dio.get(
        'http://localhost:3000/users/me',
        options: Options(extra: {'withCredentials': true}),
      );

      final clientId = meResponse.data['id'];
      final response = await dio.post(
        'http://localhost:3000/demandes',
        data: {
          'client_id': clientId,
          'type_demande': 'depanneur',
          'position_lat': position.latitude,
          'position_lng': position.longitude,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          extra: {'withCredentials': true}, // <-- Important !
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
            Icons.car_repair, // Icône de véhicule pour dépanneur
            color: depanneur.disponible ? Colors.green : Colors.red,
            size: 36,
          ),
        ),
      );
    }).toList();
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
                    'Dépanneurs proches',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nouvelle carte Google Maps stylée
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

            // Liste des dépanneurs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // Remplacement de la liste par un bouton
                  Center(
                    child: ElevatedButton(
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

            const SizedBox(height: 100), // Espace pour le bouton flottant
          ],
        ),
      ),

      // Enlever le bouton d'assistance rapide
      // floatingActionButton: SizedBox(
      //   width: 160,
      //   height: 60,
      //   child: FloatingActionButton.extended(
      //     onPressed: _showAssistanceDialog,
      //     backgroundColor: Colors.red[600],
      //     foregroundColor: Colors.white,
      //     icon: const Icon(Icons.emergency, size: 28, color: Colors.white),
      //     label: const Text(
      //       'ASSISTANCE\nRAPIDE',
      //       style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
      //       textAlign: TextAlign.center,
      //     ),
      //   ),
      // ),
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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

  void _showAssistanceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Assistance Rapide',
            style: TextStyle(
              color: Colors.red[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sélectionnez le type de problème:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                width: double.maxFinite,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: typesProblemes.length,
                  itemBuilder: (context, index) {
                    TypeProbleme type = typesProblemes[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        _envoyerDemandeAssistance(type);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: type.couleur.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: type.couleur),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(type.icone, size: 32, color: type.couleur),
                            const SizedBox(height: 8),
                            Text(
                              type.nom,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: type.couleur,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
          ],
        );
      },
    );
  }

  void _envoyerDemandeAssistance(TypeProbleme typeProbleme) {
    // Simulation d'envoi de la demande d'assistance
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Demande envoyée'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Votre demande d\'assistance a été envoyée avec succès!',
              ),
              const SizedBox(height: 16),
              const Text(
                'Détails:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Type: ${typeProbleme.nom}'),
              const Text('• Position: Alger Centre'),
              Text(
                '• Heure: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Un dépanneur va vous contacter dans les 5 minutes.',
                  style: TextStyle(color: Colors.blue[800]),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
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
          content: const Text('Voulez-vous appeler ce dépanneur?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Ici vous pourriez intégrer un appel téléphonique
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
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

void main() {
  runApp(MyApp());
}
