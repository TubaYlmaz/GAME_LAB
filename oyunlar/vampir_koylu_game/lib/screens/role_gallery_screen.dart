import 'package:flutter/material.dart';

class RoleGalleryScreen extends StatelessWidget {
  const RoleGalleryScreen({super.key});

  static const _roles = [
    _RoleData(
      'VAMPİR',
      Icons.bloodtype_rounded,
      Color(0xFFC94B5F),
      'Geceleri diğer Vampirlerle aynı hedefte anlaş. Gündüz kimliğini gizle, oylamayı yönlendir ve Vampirler sayıca üstün olana kadar hayatta kal.',
    ),
    _RoleData(
      'DOKTOR',
      Icons.medical_services_rounded,
      Color(0xFF9DBA9A),
      'Her gece bir oyuncuyu Vampir saldırısından koru. Kendini de seçebilirsin; ancak kendini iki gece üst üste koruyamazsın.',
    ),
    _RoleData(
      'SERİ KATİL',
      Icons.visibility_off_rounded,
      Color(0xFFC28BB8),
      'Kimseyle takım olmadan tek başına hareket et. Her gece bir hedef seç, gündüz şüphe çekme ve oyunda kalan son tehdit olmaya çalış.',
    ),
    _RoleData(
      'KÖYLÜ',
      Icons.groups_rounded,
      Color(0xFFE0B568),
      'Gece saldırı yapamazsın. Gündüz konuşmaları dikkatle takip et, çelişkileri bul ve Vampirlerle Seri Katili oylamayla ortaya çıkar.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0E12),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(84, 28, 28, 28),
          child: Column(
            children: [
              const Text(
                'KARAKTER KARTLARI',
                style: TextStyle(
                  color: Color(0xFFFBE9E2),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Oyunda karşılaşabileceğin gizli roller',
                style: TextStyle(color: Color(0xFFD7BFC1), fontSize: 14),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth < 760 ? 2 : 4;
                    return GridView.builder(
                      itemCount: _roles.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 18,
                        childAspectRatio: columns == 4 ? .58 : .78,
                      ),
                      itemBuilder: (_, index) => _RoleCard(role: _roles[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final _RoleData role;
  const _RoleCard({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF251015),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: role.color, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .35),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'GİZLİ ROL',
            style: TextStyle(
              color: role.color.withValues(alpha: .85),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: role.color.withValues(alpha: .15),
              shape: BoxShape.circle,
            ),
            child: Icon(role.icon, color: role.color, size: 38),
          ),
          const SizedBox(height: 18),
          Text(
            role.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: role.color,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Divider(color: role.color.withValues(alpha: .35)),
          const SizedBox(height: 10),
          Text(
            role.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF0DEE0),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleData {
  final String name;
  final IconData icon;
  final Color color;
  final String description;
  const _RoleData(this.name, this.icon, this.color, this.description);
}
