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
          extra: {'withCredentials': true}, // <-- Ajoute ceci !
        ),
      );
      if (response.statusCode == 200) {
        setState(() {
          demandes = (response.data as List)
              .where((d) => d['statut'] == 'en_attente')
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
                            // Action future : accepter/refuser
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

  Widget _buildDemande(
    BuildContext context, {
    String? avatarUrl,
    required String nom,
    required double note,
    required int nbAvis,
    required double distance,
    required String adresse,
    bool instant = false,
  }) {
    return GestureDetector(
      onTap: () => _showActionSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF1F1F1))),
          color: Colors.white,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              backgroundColor: Colors.orange,
              radius: 22,
              child: avatarUrl == null
                  ? Text(
                      nom[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            // Infos principales
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '~${distance.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (instant)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'À l\'instant',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    adresse,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.orange, size: 16),
                      Text(
                        '$note',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ' ($nbAvis)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Bouton options
            Icon(Icons.more_vert, color: Colors.grey[600]),
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
