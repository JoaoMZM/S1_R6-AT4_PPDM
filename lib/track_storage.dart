import 'dart:convert';

import 'package:s1_r6_at4_ppdm/track.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrackStorage {
  static const String _key = 'tracks_v1';

  static const List<Track> defaultTracks = [
    Track(
      id: '1',
      name: 'Música 01',
      assetPath: 'assets/audios/musica1.mp3',
    ),
    Track(
      id: '2',
      name: 'Música 02',
      assetPath: 'assets/audios/musica2.mp3',
    ),
    Track(
      id: '3',
      name: 'Música 03',
      assetPath: 'assets/audios/musica3.mp3',
    ),
    Track(
      id: '4',
      name: 'Música 04',
      assetPath: 'assets/audios/musica4.mp3',
    ),
    Track(
      id: '5',
      name: 'Música 05',
      assetPath: 'assets/audios/musica5.mp3',
    ),
  ];

  Future<List<Track>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);

    if (raw == null) {
      await save(defaultTracks);
      return List<Track>.from(defaultTracks);
    }

    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Track.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> save(List<Track> tracks) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(tracks.map((t) => t.toMap()).toList());
    await prefs.setString(_key, encoded);
  }

  /// Restaura as faixas padrão (útil depois de excluir todas).
  Future<List<Track>> reset() async {
    await save(defaultTracks);
    return List<Track>.from(defaultTracks);
  }
}
