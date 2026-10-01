import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:s1_r6_at4_ppdm/track.dart';
import 'package:s1_r6_at4_ppdm/track_storage.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  final AudioPlayer _player = AudioPlayer();
  final  _storage = TrackStorage();

  List<Track> _tracks = [];
  bool _loading = true;
  int? _currentIndex;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    // Observa o ciclo de vida do app (equivalente ao useEffect do React).
    WidgetsBinding.instance.addObserver(this);
    _listenToPlayer();
    _loadTracks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  /// Pausa a reprodução quando o app sai de foco (usuário foi para a tela inicial).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _player.pause();
    }
  }

  void _listenToPlayer() {
    _positionSub = _player.positionStream.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });

    _durationSub = _player.durationStream.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration ?? Duration.zero);
    });

    _stateSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final completed = state.processingState == ProcessingState.completed;
      setState(() => _isPlaying = state.playing && !completed);
      if (completed) {
        _onTrackCompleted();
      }
    });
  }

  Future<void> _loadTracks() async {
    final tracks = await _storage.load();
    if (!mounted) return;
    setState(() {
      _tracks = tracks;
      _loading = false;
    });
  }

  Future<void> _playTrack(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    final track = _tracks[index];

    setState(() {
      _currentIndex = index;
      _position = Duration.zero;
      _duration = Duration.zero;
    });

    try {
      await _player.setAsset(track.assetPath);
      unawaited(_player.play());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível tocar "${track.name}". '
              'Verifique se o arquivo existe em ${track.assetPath}.'),
        ),
      );
    }
  }

  Future<void> _onTrackCompleted() async {
    final current = _currentIndex;
    if (current != null && current + 1 < _tracks.length) {
      await _playTrack(current + 1);
    } else {
      await _player.pause();
      await _player.seek(Duration.zero);
    }
  }

  Future<void> _togglePlayPause() async {
    if (_tracks.isEmpty) return;

    if (_currentIndex == null) {
      await _playTrack(0);
      return;
    }

    if (_isPlaying) {
      await _player.pause();
      return;
    }

    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    unawaited(_player.play());
  }

  Future<void> _playNext() async {
    final current = _currentIndex;
    if (current == null) {
      await _playTrack(0);
    } else if (current + 1 < _tracks.length) {
      await _playTrack(current + 1);
    }
  }

  Future<void> _playPrevious() async {
    final current = _currentIndex;
    if (current == null) return;

    if (_position.inSeconds > 3 || current == 0) {
      await _player.seek(Duration.zero);
    } else {
      await _playTrack(current - 1);
    }
  }

  Future<void> _seek(double milliseconds) async {
    await _player.seek(Duration(milliseconds: milliseconds.round()));
  }

  Future<void> _deleteTrack(int index) async {
    final removed = _tracks[index];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir faixa'),
        content: Text('Deseja excluir "${removed.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final current = _currentIndex;
    if (current != null) {
      if (current == index) {
        await _player.stop();
        _currentIndex = null;
        _position = Duration.zero;
        _duration = Duration.zero;
      } else if (index < current) {
        _currentIndex = current - 1;
      }
    }

    final updated = List<Track>.from(_tracks)..removeAt(index);
    await _storage.save(updated);

    if (!mounted) return;
    setState(() => _tracks = updated);
  }

  Future<void> _resetTracks() async {
    await _player.stop();
    final restored = await _storage.reset();
    if (!mounted) return;
    setState(() {
      _tracks = restored;
      _currentIndex = null;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Player'),
        actions: [
          IconButton(
            tooltip: 'Restaurar faixas',
            icon: const Icon(Icons.restore),
            onPressed: _resetTracks,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: _buildTrackList()),
                _buildPlayerPanel(),
              ],
            ),
    );
  }

  Widget _buildTrackList() {
    if (_tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_off, size: 64),
            const SizedBox(height: 12),
            const Text('Nenhuma faixa na lista'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _resetTracks,
              icon: const Icon(Icons.restore),
              label: const Text('Restaurar faixas'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _tracks.length,
      itemBuilder: (context, index) {
        final track = _tracks[index];
        final isCurrent = index == _currentIndex;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(
                isCurrent && _isPlaying ? Icons.equalizer : Icons.music_note,
              ),
            ),
            title: Text(
              track.name,
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(isCurrent ? 'Tocando agora' : 'Faixa local'),
            selected: isCurrent,
            onTap: () => _playTrack(index),
            trailing: IconButton(
              tooltip: 'Excluir',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteTrack(index),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerPanel() {
    final current = _currentIndex;
    final title = current != null && current < _tracks.length
        ? _tracks[current].name
        : 'Selecione uma faixa';

    final maxMs = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds.toDouble()
        : 1.0;
    final valueMs = _position.inMilliseconds.toDouble().clamp(0.0, maxMs);

    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(_formatDuration(_position)),
                  Expanded(
                    child: Slider(
                      min: 0,
                      max: maxMs,
                      value: valueMs,
                      onChanged: current == null ? null : _seek,
                    ),
                  ),
                  Text(_formatDuration(_duration)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(Icons.skip_previous),
                    onPressed: current == null ? null : _playPrevious,
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    iconSize: 40,
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: _tracks.isEmpty ? null : _togglePlayPause,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(Icons.skip_next),
                    onPressed: _tracks.isEmpty ? null : _playNext,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
