import 'package:flutter/material.dart';

class KzRulesButton extends StatelessWidget {
  const KzRulesButton({super.key});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => showKzRules(context),
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x66171B2E),
          border: Border.all(color: Colors.white38),
        ),
        child: const Icon(Icons.info_outline, color: Colors.white70, size: 24),
      ),
    ),
  );
}

Future<void> showKzRules(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF293655), Color(0xFF302C4D)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF8FA5D9), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x77434F82),
              blurRadius: 32,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF496FCE), Color(0xFF8B55C7)],
                ),
              ),
              child: Row(
                children: [
                  const Text('🔔', style: TextStyle(fontSize: 38)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KART & ZİL NASIL OYNANIR?',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text('Temel kurallar ve puanlama'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(18, 18, 18, 24),
                  child: Column(
                    children: [
                      _RuleCard(
                        icon: '🎯',
                        title: 'AMAÇ',
                        text: 'Aynı renk veya aynı sayıdaki kartları biriktir. En yüksek el puanını yap ve canlarını koru.',
                      ),
                      _RuleCard(
                        icon: '🃏',
                        title: 'SIRAN GELİNCE',
                        text: 'Kapalı desteden ya da açık alandan bir kart al. Beş karttan birini açık alana bırak; elinde yine dört kart kalsın.',
                      ),
                      _RuleCard(
                        icon: '🔔',
                        title: 'ZİL KURALI',
                        text: 'Zile yalnızca sıranın başında, kart almadan önce basabilirsin. Elin kilitlenir ve diğer oyuncular birer son hamle yapar.',
                      ),
                      _ScoringGuide(),
                      _RuleCard(
                        icon: '❤️',
                        title: 'CAN, TUR VE KAZANMA',
                        text: 'Herkes 3 canla başlar. Turun en düşük puanı 1 can kaybeder; bu kişi zile bastıysa 2 can kaybeder. Canı biten elenir, son kalan oyuncu kazanır.',
                      ),
                      _RuleCard(
                        icon: '🤝',
                        title: 'TAKIM MODU',
                        text: 'Çift oyuncu sayısıyla oynanır ve takımlar rastgele kurulur. Takım puanları toplanır; düşük takım 1 can, zile basan oyuncunun takımı düşükse 2 can kaybeder. Eşitlikte can kaybı olmaz.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('ANLADIM'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC53D),
                    foregroundColor: const Color(0xFF293655),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final String icon, title, text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.white12)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFFFC53D),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(height: 1.35)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ScoringGuide extends StatelessWidget {
  const _ScoringGuide();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.white12)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('✨', style: TextStyle(fontSize: 28)),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PUAN NASIL HESAPLANIR?',
                    style: TextStyle(
                      color: Color(0xFFFFD166),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Renk toplamı ve sayı toplamı ayrı hesaplanır. Büyük olan sonuç el puanındır.',
                    style: TextStyle(height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            const colorExample = _ScoreExample(
              title: 'ÖRNEK 1 · AYNI RENK',
              cards: [
                _GuideCardData('blue', 4),
                _GuideCardData('blue', 8),
                _GuideCardData('red', 4),
                _GuideCardData('green', 2),
              ],
              colorCalculation: 'Mavi: 4 + 8 = 12',
              numberCalculation: 'Dörtler: 4 + 4 = 8',
              result: 'PUAN: 12',
            );
            const numberExample = _ScoreExample(
              title: 'ÖRNEK 2 · AYNI SAYI',
              cards: [
                _GuideCardData('blue', 3),
                _GuideCardData('blue', 7),
                _GuideCardData('red', 7),
                _GuideCardData('yellow', 2),
              ],
              colorCalculation: 'Mavi: 3 + 7 = 10',
              numberCalculation: 'Yediler: 7 + 7 = 14',
              result: 'PUAN: 14',
            );
            if (constraints.maxWidth < 520) {
              return const Column(
                children: [colorExample, SizedBox(height: 12), numberExample],
              );
            }
            return const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: colorExample),
                SizedBox(width: 12),
                Expanded(child: numberExample),
              ],
            );
          },
        ),
        SizedBox(height: 10),
        _TipLine(
          icon: '💡',
          text: 'Tek kalan bir kart da kendi değeri kadar grup sayılır.',
        ),
        SizedBox(height: 6),
        _TipLine(
          icon: '🏆',
          text: 'Tur sonunda puanı en düşük olan oyuncu can kaybeder.',
        ),
      ],
    ),
  );
}

class _GuideCardData {
  const _GuideCardData(this.color, this.number);
  final String color;
  final int number;
}

class _ScoreExample extends StatelessWidget {
  const _ScoreExample({
    required this.title,
    required this.cards,
    required this.colorCalculation,
    required this.numberCalculation,
    required this.result,
  });

  final String title;
  final List<_GuideCardData> cards;
  final String colorCalculation;
  final String numberCalculation;
  final String result;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0x66202640),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFBCEAE7),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: cards.map((card) => _GuideCard(data: card)).toList(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _CalculationChip(
              icon: Icons.palette_outlined,
              text: colorCalculation,
              color: const Color(0xFF65C6C4),
            ),
            _CalculationChip(
              icon: Icons.numbers,
              text: numberCalculation,
              color: const Color(0xFFE58BC1),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFFFC53D),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            result,
            style: const TextStyle(
              color: Color(0xFF202640),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.data});
  final _GuideCardData data;

  Color get color => switch (data.color) {
    'red' => const Color(0xFFE85B62),
    'yellow' => const Color(0xFFF5C542),
    'green' => const Color(0xFF36AD78),
    _ => const Color(0xFF4E73DF),
  };

  @override
  Widget build(BuildContext context) => Container(
    width: 43,
    height: 59,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: Colors.white70, width: 1.5),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
    ),
    child: Text(
      '${data.number}',
      style: TextStyle(
        color: data.color == 'yellow' ? Colors.black : Colors.white,
        fontSize: 21,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _CalculationChip extends StatelessWidget {
  const _CalculationChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: .7)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _TipLine extends StatelessWidget {
  const _TipLine({required this.icon, required this.text});
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(icon),
      const SizedBox(width: 7),
      Expanded(child: Text(text, style: const TextStyle(height: 1.3))),
    ],
  );
}
