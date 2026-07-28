import 'dart:math';
import 'package:flutter/material.dart';

class NightActionDialog extends StatefulWidget {
  final String
  myRole; // 'Vampir 🧛', 'Doktor 🩺', 'Seri Katil 🔪', 'Köylü 🧑‍🌾'
  final List<Map<String, dynamic>>
  alivePlayers; // Yaşayan oyuncular [{id, name}]
  final Function(String targetId) onActionSubmitted;

  const NightActionDialog({
    Key? key,
    required this.myRole,
    required this.alivePlayers,
    required this.onActionSubmitted,
  }) : super(key: key);

  @override
  State<NightActionDialog> createState() => _NightActionDialogState();
}

class _NightActionDialogState extends State<NightActionDialog> {
  String? selectedPlayerId;

  // Köylüler için 4 seçenekli matematik sorusu değişkenleri
  late int num1;
  late int num2;
  late int correctAnswer;
  List<int> mathOptions = [];
  int? selectedVillagerOption;

  bool isSubmitted = false;
  String? errorMessage;

  // --- DEĞİŞTİRİLEN KISIM BAŞLANGICI ---
  // Rol tespit fonksiyonları daha güvenli ve kesin hale getirildi
  bool get isVampire {
    final r = widget.myRole.toLowerCase();
    return r.contains('vampir') || r.contains('vampire');
  }

  bool get isDoctor {
    final r = widget.myRole.toLowerCase();
    return r.contains('doktor') || r.contains('doctor');
  }

  bool get isSerialKiller {
    final r = widget.myRole.toLowerCase();
    return r.contains('seri') || r.contains('katil') || r.contains('killer');
  }

  // Eğer oyuncu Vampir, Doktor veya Seri Katil değilse Köylüdür
  bool get isVillager {
    return !isVampire && !isDoctor && !isSerialKiller;
  }
  // --- DEĞİŞTİRİLEN KISIM BİTİŞİ ---

  @override
  void initState() {
    super.initState();
    if (isVillager) {
      _generateMathQuestion();
    }
  }

  void _generateMathQuestion() {
    final random = Random();
    num1 = random.nextInt(30) + 10;
    num2 = random.nextInt(30) + 5;
    correctAnswer = num1 + num2;

    Set<int> optionsSet = {correctAnswer};
    while (optionsSet.length < 4) {
      int wrong = correctAnswer + (random.nextInt(15) - 7);
      if (wrong != correctAnswer && wrong > 0) {
        optionsSet.add(wrong);
      }
    }
    mathOptions = optionsSet.toList()..shuffle();
  }

  void _handleConfirm() {
    if (isSubmitted) return;

    if (isVillager) {
      if (selectedVillagerOption == null) {
        setState(() {
          errorMessage = "Lütfen şıklardan birini seçin!";
        });
        return;
      }
      if (selectedVillagerOption != correctAnswer) {
        setState(() {
          errorMessage = "Hatalı seçim! Doğrusunu bulmak için tekrar deneyin.";
        });
        return;
      }
      setState(() {
        isSubmitted = true;
        errorMessage = null;
      });
      widget.onActionSubmitted("math_solved");
    } else {
      if (selectedPlayerId == null) {
        setState(() {
          errorMessage = "Lütfen bir hedef oyuncu seçin!";
        });
        return;
      }
      setState(() {
        isSubmitted = true;
        errorMessage = null;
      });
      widget.onActionSubmitted(selectedPlayerId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161528),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.redAccent.withOpacity(0.8),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "GECE EYLEMİ",
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 14,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildRoleHeader(),
            const Divider(color: Colors.white24, height: 24),
            _buildRoleActionBody(),
            if (errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                errorMessage!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isSubmitted ? null : _handleConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                disabledBackgroundColor: Colors.grey.shade800,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: const Size(double.infinity, 44),
              ),
              child: Text(
                isSubmitted ? "SEÇİMİN ALINDI... ⏳" : "KARARIMI ONAYLA",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- DEĞİŞTİRİLEN KISIM BAŞLANGICI ---
  Widget _buildRoleHeader() {
    String title = "Köylü";
    String emoji = "🧑‍🌾";
    String description = "Dikkat çekmemek için geceyi çalışarak geçir!";

    if (isVampire) {
      title = "Vampir";
      emoji = "🧛";
      description =
          "Bu gece avlayacağın kişiyi seç! (Tüm vampirler aynı kişiyi seçmelidir)";
    } else if (isDoctor) {
      title = "Doktor";
      emoji = "🩺";
      description =
          "Bu gece kimi korumak istersin? (Vampir saldırısını engeller, Seri Katil engellenemez! Birden fazla doktorsanız aynı kişiyi seçmelisiniz)";
    } else if (isSerialKiller) {
      title = "Seri Katil";
      emoji = "🔪";
      description =
          "Bu gece kurbanını belirle! (Doktor koruması Seri Katil saldırısını engelleyemez!)";
    }

    return Column(
      children: [
        Text(
          "$title $emoji",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
  // --- DEĞİŞTİRİLEN KISIM BİTİŞİ ---

  Widget _buildRoleActionBody() {
    // Köylü Seçenekleri (Alt Alta Satır Satır Yapı)
    if (isVillager) {
      return Column(
        children: [
          Text(
            "$num1 + $num2 = ?",
            style: const TextStyle(
              color: Colors.amberAccent,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...mathOptions.map((option) {
            final isSelected = selectedVillagerOption == option;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected
                        ? (option == correctAnswer
                              ? Colors.green.shade700
                              : Colors.red.shade700)
                        : Colors.black38,
                    side: BorderSide(
                      color: isSelected ? Colors.redAccent : Colors.white24,
                      width: isSelected ? 2 : 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: isSubmitted
                      ? null
                      : () {
                          setState(() {
                            selectedVillagerOption = option;
                            if (option == correctAnswer) {
                              errorMessage = null;
                            } else {
                              errorMessage =
                                  "Yanlış cevap! Doğrusunu bulmak için tekrar deneyin.";
                            }
                          });
                        },
                  child: Text(
                    "$option",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      );
    }

    // Vampir / Doktor / Seri Katil Seçenekleri (Alt Alta İnce Liste)
    return SizedBox(
      height: 180,
      child: widget.alivePlayers.isEmpty
          ? const Center(
              child: Text(
                "Seçilebilecek oyuncu bulunamadı.",
                style: TextStyle(color: Colors.white54),
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              itemCount: widget.alivePlayers.length,
              itemBuilder: (context, index) {
                final player = widget.alivePlayers[index];
                final String pId = (player['id'] ?? player['name']).toString();
                final String pName = (player['name'] ?? 'Oyuncu').toString();
                final isSelected = selectedPlayerId == pId;

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.redAccent.withOpacity(0.25)
                        : Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.redAccent : Colors.white10,
                      width: 1.5,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 0,
                    ),
                    title: Text(
                      pName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.redAccent,
                            size: 20,
                          )
                        : const Icon(
                            Icons.circle_outlined,
                            color: Colors.white24,
                            size: 20,
                          ),
                    onTap: () {
                      if (!isSubmitted) {
                        setState(() {
                          selectedPlayerId = pId;
                          errorMessage = null;
                        });
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
