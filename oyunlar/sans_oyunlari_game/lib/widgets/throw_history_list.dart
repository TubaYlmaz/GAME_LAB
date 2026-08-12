import 'package:flutter/material.dart';

import '../models/throw_history.dart';

class ThrowHistoryList extends StatelessWidget {
  const ThrowHistoryList({
    super.key,
    required this.entries,
    required this.mode,
  });

  final List<ThrowHistory> entries;
  final ChanceGameMode mode;

  @override
  Widget build(BuildContext context) {
    final modeEntries = entries.where((entry) => entry.mode == mode).toList();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF191827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF302E49)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Text(
              mode == ChanceGameMode.coin
                  ? 'YAZI - TURA GE\u00c7M\u0130\u015e\u0130'
                  : 'ZAR ATMA GE\u00c7M\u0130\u015e\u0130',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: .8,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF302E49)),
          Expanded(
            child: modeEntries.isEmpty
                ? const Center(
                    child: Text(
                      'Hen\u00fcz bir at\u0131\u015f yok.',
                      style: TextStyle(color: Color(0xFFA9A6BD)),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: modeEntries.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 18,
                      endIndent: 18,
                      color: Color(0xFF302E49),
                    ),
                    itemBuilder: (context, index) {
                      final entry = modeEntries[index];
                      final isCoin = entry.mode == ChanceGameMode.coin;
                      final time = TimeOfDay.fromDateTime(
                        entry.createdAt,
                      ).format(context);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCoin
                              ? const Color(0xFF6D5BD0)
                              : const Color(0xFFE35E45),
                          child: Icon(
                            isCoin
                                ? Icons.monetization_on_rounded
                                : Icons.casino_rounded,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          entry.resultLabel,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: isCoin
                            ? const Text('Para at\u0131\u015f\u0131')
                            : Text('Toplam: ${entry.diceTotal}'),
                        trailing: Text(
                          time,
                          style: const TextStyle(color: Color(0xFFA9A6BD)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
