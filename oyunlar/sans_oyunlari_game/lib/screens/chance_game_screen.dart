import 'dart:async';

import 'package:flutter/material.dart';

import '../models/throw_history.dart';
import '../services/chance_game_socket_service.dart';
import '../widgets/coin_flip_component.dart';
import '../widgets/dice_roll_component.dart';
import '../widgets/throw_history_list.dart';

class ChanceGameScreen extends StatefulWidget {
  const ChanceGameScreen({super.key});

  @override
  State<ChanceGameScreen> createState() => _ChanceGameScreenState();
}

class _ChanceGameScreenState extends State<ChanceGameScreen>
    with SingleTickerProviderStateMixin {
  final _socketService = ChanceGameSocketService.instance;
  final List<ThrowHistory> _history = [];
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _socketService.connect();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) setState(() {});
      });
  }

  void _addCoinHistory(CoinSide side) {
    _record(
      ThrowHistory(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        mode: ChanceGameMode.coin,
        coinSide: side,
        createdAt: DateTime.now(),
      ),
    );
  }

  void _addDiceHistory(List<int> values) {
    _record(
      ThrowHistory(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        mode: ChanceGameMode.dice,
        diceValues: List.unmodifiable(values),
        createdAt: DateTime.now(),
      ),
    );
  }

  void _record(ThrowHistory entry) {
    setState(() => _history.insert(0, entry));
    unawaited(_socketService.recordAction(entry));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _socketService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = _tabController.index == 0
        ? ChanceGameMode.coin
        : ChanceGameMode.dice;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        centerTitle: true,
        titleSpacing: 70,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF3E8DC), Color(0xFFEAD8C7)],
            ),
            border: Border(
              bottom: BorderSide(color: Color(0xFFD2BBA9), width: 1),
            ),
          ),
        ),
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Zar & Yazı-Tura',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Hızlı ve rastgele bir sonuç oluştur',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF6F625A),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: Container(
              height: 52,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9F2).withValues(alpha: .72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBB29F)),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD97560), Color(0xFFC58B78)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x44C96F5B),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                labelColor: const Color(0xFFFFFAF5),
                unselectedLabelColor: const Color(0xFF6F625A),
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .4,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.monetization_on_rounded, size: 19),
                    text: 'YAZI - TURA',
                  ),
                  Tab(
                    icon: Icon(Icons.casino_rounded, size: 19),
                    text: 'ZAR ATMA',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF4EEE5), Color(0xFFEDE3D8)],
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 400),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF9F2),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFD8C5B5)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1F6F5548),
                                blurRadius: 18,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              Center(
                                child: CoinFlipComponent(
                                  onFlipCompleted: _addCoinHistory,
                                ),
                              ),
                              Center(
                                child: DiceRollComponent(
                                  onRollCompleted: _addDiceHistory,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 140,
                      child: ThrowHistoryList(entries: _history, mode: mode),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
