import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class PageDepannage extends StatefulWidget {
  const PageDepannage({super.key});

  @override
  State<PageDepannage> createState() => _PageDepannageState();
}

class _PageDepannageState extends State<PageDepannage> {
  LatLng? _userPosition;
  bool _loading = true;

  final dio = Dio();
  final cookieJar = CookieJar();
  List<dynamic> demandes = [];
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _initCookieJar();
    fetchDemandes();
    _determinePosition();
  }

  Future<void> _initCookieJar() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      dio.interceptors.add(CookieManager(cookieJar));
    }
    // Sur le web, NE PAS ajouter CookieManager !
  }

  Future<void> fetchDemandes() async {
    setState(() {
      _isFetching = true;
    });
    try {
      final response = await dio.get(
        'http://localhost:3000/demandes',
        options: Options(
          extra: {'withCredentials': true}, // <-- Important !
        ),
      );
      if (response.statusCode == 200) {
        setState(() {
          demandes = (response.data as List)
              .where(
                (d) =>
                    d['statut'] == 'en_attente' &&
                    d['type_demande'] == 'depanneur',
              )
              .toList();
        });
      } else {
        setState(() {
          demandes = [];
        });
      }
    } catch (e) {
      setState(() {
        demandes = [];
      });
    } finally {
      setState(() {
        _isFetching = false;
      });
    }
  }

  Future<void> _determinePosition() async {
    setState(() => _loading = true);
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      setState(() {
        _userPosition = null;
        _loading = false;
      });
      return;
    }
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _userPosition = LatLng(pos.latitude, pos.longitude);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _userPosition = null;
        _loading = false;
      });
    }
  }

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Accepter',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orange, width: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Refuser',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showClientInfo(
    int clientId,
    double lat,
    double lng,
    int demandeId,
  ) async {
    try {
      final response = await dio.get(
        'http://localhost:3000/users/$clientId',
        options: Options(
          extra: {'withCredentials': true}, // <-- Important !
        ),
      );
      if (response.statusCode == 200) {
        final client = response.data;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Infos du client'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nom : ${client['nom']}'),
                Text('Prénom : ${client['prenom']}'),
                Text('Téléphone : ${client['telephone']}'),
                Text('Position : ($lat, $lng)'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _accepterDemande(demandeId);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Accepter la demande'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de récupérer les infos du client'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  Future<void> _accepterDemande(int demandeId) async {
    try {
      // Récupérer l'id du dépanneur connecté
      final meResponse = await dio.get(
        'http://localhost:3000/users/me',
        options: Options(
          extra: {'withCredentials': true}, // <-- Important !
        ),
      );
      final depanneurId = meResponse.data['id'];
      final response = await dio.post(
        'http://localhost:3000/demandes/$demandeId/accepter',
        data: {'prestataire_id': depanneurId},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          extra: {'withCredentials': true}, // <-- Important !
        ),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Demande acceptée !')));
        fetchDemandes(); // Rafraîchir la liste
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.data['error'] ?? 'Erreur lors de l\'acceptation',
            ),
          ),
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
    final LatLng defaultPosition = LatLng(36.752778, 3.042222); // Alger
    final LatLng mapCenter = _userPosition ?? defaultPosition;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header amélioré (style client.dart)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              color: const Color(0xFFFFAB40),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      Navigator.of(context).maybePop();
                    },
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.location_on, color: Colors.white, size: 28),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Salut, Abderrahmane',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Alger, Algérie',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Titre sous le header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Text(
                'Demandes de dépannage',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            // Carte OpenStreetMap avec 4 coins arrondis et centrée
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 0),
                width: MediaQuery.of(context).size.width * 0.90,
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.orange,
                          ),
                        )
                      : FlutterMap(
                          options: MapOptions(center: mapCenter, zoom: 12),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                              subdomains: const ['a', 'b', 'c'],
                              userAgentPackageName: 'com.example.mecano',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: mapCenter,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.orange,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ),
            // Liste des courses scrollable sous la map
            Expanded(
              child: _isFetching
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.orange),
                    )
                  : demandes.isEmpty
                  ? const Center(child: Text('Aucune demande en attente'))
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: demandes.length,
                      itemBuilder: (context, index) {
                        final demande = demandes[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.assignment,
                            color: Colors.orange,
                          ),
                          title: Text('Demande #${demande['id']}'),
                          subtitle: Text(
                            'Client ID: ${demande['client_id']}\nPosition: (${demande['position_lat']}, ${demande['position_lng']})',
                          ),
                          trailing: Text(
                            demande['statut'],
                            style: const TextStyle(color: Colors.orange),
                          ),
                          onTap: () {
                            _showClientInfo(
                              demande['client_id'],
                              demande['position_lat'],
                              demande['position_lng'],
                              demande['id'],
                            );
                          },
                        );
                      },
                    ),
            ),

            // Barre de navigation en bas
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBottomButton(Icons.list_alt, 'Commandes'),
                  _buildBottomButton(Icons.bar_chart, 'Performance'),
                  _buildBottomButton(
                    Icons.account_balance_wallet,
                    'Portefeuille',
                  ),
                ],
              ),
            ),

            // Ajout d'un bouton de rafraîchissement manuel (optionnel)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: fetchDemandes,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Rafraîchir les demandes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.orange, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.orange,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
