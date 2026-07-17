// lib/screens/host_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'game_screen.dart';

class HostScreen extends StatefulWidget {
  final String gameMode;
  final String category;
  final int impostorCount;
  final dynamic socket;
  final String hostName;
  final String? existingRoomCode; 

  const HostScreen({
    super.key,
    required this.gameMode,
    required this.category,
    required this.impostorCount,
    required this.socket,
    required this.hostName,
    this.existingRoomCode,
  });

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  final List<String> joinedPlayers = [];
  List<String> returnedPlayers = []; 
  bool isEveryoneBack = false;       

  // 🎯 LOBİ İÇİ GÜNCEL STATE KORUYUCULARI
  late String currentMod;
  late String currentCategory;
  late TextEditingController _impostorCountController;

  List<String> _kategoriler = ['Rastgele'];
  late String roomCode;
  bool isActualHost = false; 

  @override
  void initState() {
    super.initState();
    
    // Eğer oylamadan dönüldüyse default'a düşmesin diye mevcut state'i koru kanka!
    currentMod = widget.gameMode;
    currentCategory = widget.category;
    _impostorCountController = TextEditingController(text: widget.impostorCount.toString());

    if (widget.existingRoomCode != null) {
      roomCode = widget.existingRoomCode!;
    } else {
      roomCode = _generateRandomRoomCode();
    }
    
    _kategorileriYukle();
    _registerRoomOnServer();
    _checkHostStatus(); 
  }

  Future<void> _kategorileriYukle() async {
    try {
      final String response = await rootBundle.loadString('dictionary.json');
      final Map<String, dynamic> data = json.decode(response);
      if (!mounted) return;
      setState(() {
        _kategoriler = ['Rastgele', ...data.keys.toList()];
      });
    } catch (e) {
      debugPrint("Sözlük yükleme hatası: $e");
    }
  }

  void _pushSettingsToServer() {
    if (widget.socket != null && isActualHost) {
      widget.socket.emit('update_room_settings', {
        'roomCode': roomCode,
        'gameMode': currentMod,
        'category': currentCategory,
        'impostorCount': int.tryParse(_impostorCountController.text) ?? 1,
      });
    }
  }

  String _generateRandomRoomCode() {
    const chars = 'ABCDEFGHJKLMNOPQRSTUVWXYZ23456789';
    Random random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  void _registerRoomOnServer() {
    if (widget.socket != null) {
      widget.socket.emit('create_room', {
        'roomCode': roomCode,
        'hostName': widget.hostName,
        'gameMode': currentMod,
        'category': currentCategory,
        'impostorCount': int.tryParse(_impostorCountController.text) ?? 1,
      });

      widget.socket.on('room_updated', (data) {
        if (!mounted) return;
        var incomingPlayers = data['players'];
        if (incomingPlayers is List) {
          setState(() {
            joinedPlayers.clear();
            joinedPlayers.addAll(incomingPlayers.map((e) => e.toString()));
          });
        }
      });

      widget.socket.on('lobby_return_status', (data) {
        if (!mounted) return;
        setState(() {
          returnedPlayers = List<String>.from(data['returnedPlayers'] ?? []);
          isEveryoneBack = data['isEveryoneBack'] ?? false;
        });
      });

      // Dinamik ayar değişimlerini lobi içinde anlık eşitle kanka
      widget.socket.on('room_settings_changed', (data) {
        if (!mounted) return;
        setState(() {
          currentMod = data['gameMode'] ?? currentMod;
          currentCategory = data['category'] ?? currentCategory;
          _impostorCountController.text = (data['impostorCount'] ?? 1).toString();
        });
      });

      widget.socket.on('game_started', (data) {
        if (!mounted) return;

        String secretWord = data['secretWord'] ?? '';
        String impWord = data['impostorWord'] ?? '';

        var impostorData = data['impostor'];
        List<String> impostors = [];
        if (impostorData is List) {
          impostors = impostorData.map((e) => e.toString()).toList();
        } else {
          impostors = [impostorData.toString()];
        }

        bool isMeImpostor = impostors.contains(widget.hostName);

        // 🎯 DÜZELTME: Eğer mod Klasik ise ve oyuncu Impostor ise kelime yerine direkt "IMPOSTOR" basıyoruz!
        String nihaiKelime = isMeImpostor 
            ? (currentMod == 'Klasik' ? 'IMPOSTOR' : impWord) 
            : secretWord;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameScreen(
              playerName: widget.hostName,
              secretWord: nihaiKelime,
              isImpostor: isMeImpostor,
              socket: widget.socket,
              roomCode: roomCode,
              players: joinedPlayers.isNotEmpty ? joinedPlayers : [widget.hostName],
            ),
          ),
        );
      });
      
      widget.socket.emit('player_returned_to_lobby', {
        'roomCode': roomCode,
        'playerName': widget.hostName,
      });
    }
  }

  void _checkHostStatus() {
    if (widget.socket != null) {
      widget.socket.emit('check_host', {
        'roomCode': roomCode,
        'playerName': widget.hostName,
      });

      widget.socket.on('host_verification', (data) {
        if (!mounted) return;
        setState(() {
          isActualHost = data['isHost'] ?? false;
        });
      });
    }
  }

  @override
  void dispose() {
    _impostorCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!joinedPlayers.contains(widget.hostName)) {
      joinedPlayers.insert(0, widget.hostName);
    }

    bool canStart = isEveryoneBack || joinedPlayers.length <= 1;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E1E38), Color(0xFF13132B), Color(0xFF0B0B1A)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: const Color(0xFF181832).withValues(alpha: 0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: const BorderSide(color: Color(0xFF2E2E5C), width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      children: [
                        const Text(
                          'ÖĞRENCİLER İÇİN ODA KODU',
                          style: TextStyle(color: Color(0xFF8E8EAF), fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          roomCode,
                          style: const TextStyle(color: Color(0xFF00D2FF), fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: 5),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // 🎯 GÜNCELLEME: İSTEDİĞİN ŞIK AÇILIR-KAPANIR ÇEKMECE PANELİ (SADECE HOST)
                if (isActualHost) ...[
                  Card(
                    color: const Color(0xFF141430),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      leading: const Icon(Icons.settings_suggest_rounded, color: Color(0xFF00D2FF)),
                      title: const Text(
                        "OYUN AYARLARINI DÜZENLE",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                      ),
                      collapsedIconColor: Colors.white54,
                      iconColor: const Color(0xFF00D2FF),
                      backgroundColor: const Color(0xFF141430),
                      collapsedBackgroundColor: const Color(0xFF141430),
                      // 🎯 DÜZELTME: 'border' parametresi silindi, shape mühürleri çakıldı![cite: 8]
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFF2E2E5C), width: 1),
                      ),
                      collapsedShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFF2E2E5C), width: 1),
                      ),
                      childrenPadding: const EdgeInsets.all(16),
                      children: [
                        // Mod Seçimi
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text("Klasik")),
                                selected: currentMod == 'Klasik',
                                selectedColor: Colors.redAccent,
                                labelStyle: TextStyle(color: currentMod == 'Klasik' ? Colors.white : Colors.grey, fontWeight: FontWeight.bold),
                                onSelected: (val) {
                                  if (val) {
                                    setState(() { currentMod = 'Klasik'; });
                                    _pushSettingsToServer();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text("Yakın Kelime")),
                                selected: currentMod == 'Yakin Kelime',
                                selectedColor: Colors.redAccent,
                                labelStyle: TextStyle(color: currentMod == 'Yakin Kelime' ? Colors.white : Colors.grey, fontWeight: FontWeight.bold),
                                onSelected: (val) {
                                  if (val) {
                                    setState(() { currentMod = 'Yakin Kelime'; });
                                    _pushSettingsToServer();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Kategori Dropdown Seçimi
                        DropdownButtonFormField<String>(
                          value: _kategoriler.contains(currentCategory) ? currentCategory : 'Rastgele',
                          dropdownColor: const Color(0xFF1A1A2E),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Kelime Kategorisi',
                            labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF0B0B1A),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.redAccent)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white10)),
                          ),
                          items: _kategoriler.map((String kat) {
                            return DropdownMenuItem<String>(value: kat, child: Text(kat));
                          }).toList(),
                          onChanged: (String? yeniKat) {
                            if (yeniKat != null) {
                              setState(() { currentCategory = yeniKat; });
                              _pushSettingsToServer();
                            }
                          },
                        ),
                        const SizedBox(height: 14),

                        // İmpostor Sayısı Ayarı
                        TextField(
                          controller: _impostorCountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'İmpostor Sayısı',
                            labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF0B0B1A),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.redAccent)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white10)),
                          ),
                          onChanged: (val) {
                            _pushSettingsToServer();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Katılan Oyuncular', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Chip(
                      label: Text('${joinedPlayers.length} Oyuncu'),
                      backgroundColor: const Color(0xFF2E2E5C),
                      side: const BorderSide(color: Color(0xFF00D2FF), width: 1),
                      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: joinedPlayers.isEmpty
                      ? const Center(child: Text('Oyuncuların gelmesi bekleniyor...', style: TextStyle(color: Color(0xFF8E8EAF), fontSize: 14)))
                      : ListView.builder(
                          itemCount: joinedPlayers.length,
                          itemBuilder: (context, index) {
                            bool isReturned = returnedPlayers.contains(joinedPlayers[index]);
                            return Card(
                              color: const Color(0xFF101026),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF2E2E5C), width: 1)),
                              child: ListTile(
                                leading: const Icon(Icons.person, color: Color(0xFF8E8EAF), size: 20),
                                title: Text(joinedPlayers[index], style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                                trailing: isReturned
                                    ? const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 22)
                                    : const Icon(Icons.hourglass_empty_rounded, color: Colors.amberAccent, size: 18),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 15),

                isActualHost
                    ? ElevatedButton(
                        onPressed: !canStart
                            ? null
                            : () async {
                                if (joinedPlayers.length < 2) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Oyunu başlatmak için en az 2 oyuncu olmalıdır!')),
                                  );
                                  return;
                                }

                                final url = Uri.parse('${AppConfig.serverUrl}/api/start-game');
                                try {
                                  await http.post(
                                    url,
                                    headers: {'Content-Type': 'application/json'},
                                    body: jsonEncode({
                                      'roomCode': roomCode,
                                      'players': joinedPlayers,
                                      'gameMode': currentMod, 
                                      'category': currentCategory,
                                      'impostorCount': int.tryParse(_impostorCountController.text) ?? 1,
                                    }),
                                  );
                                } catch (e) {
                                  debugPrint("Bağlantı hatası: $e");
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: !canStart ? Colors.grey.shade800 : const Color(0xFF00D2FF),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          !canStart ? 'OYUNCULARIN ODALARA DÖNMESİ BEKLENİYOR... ⏳' : 'OYUNU BAŞLAT',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: !canStart ? Colors.white30 : const Color(0xFF0B0B1A),
                            letterSpacing: 1,
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(color: const Color(0xFF1E1E38), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2E2E5C))),
                        child: const Center(
                          child: Text('HOSTUN OYUNU BAŞLATMASI BEKLENİYOR... ⏳', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white60)),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}