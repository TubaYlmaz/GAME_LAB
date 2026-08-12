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
        title: const Text('\u015eans Oyunlar\u0131'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.monetization_on_rounded), text: 'YAZI - TURA'),
            Tab(icon: Icon(Icons.casino_rounded), text: 'ZAR ATMA'),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
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
    );
  }
}
