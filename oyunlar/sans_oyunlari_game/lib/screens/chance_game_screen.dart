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
              colors: [Color(0xFF211D36), Color(0xFF151322)],
            ),
            border: Border(
              bottom: BorderSide(color: Color(0xFF423A68), width: 1),
            ),
          ),
        ),
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Şans Oyunları',
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
              'Yazı-tura veya zar • Seçim senin',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFFAAA4C0),
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
                color: const Color(0xFF0D0C18).withValues(alpha: .72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF3D365D)),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7458E8), Color(0xFF4C8EF7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x557C4DFF),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFFAAA4C0),
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
              colors: [Color(0xFF141225), Color(0xFF0D0D18)],
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
                      flex: 3,
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
                    const SizedBox(height: 18),
                    Expanded(
                      flex: 2,
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
