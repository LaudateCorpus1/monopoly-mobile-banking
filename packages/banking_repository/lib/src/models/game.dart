import 'package:kt_dart/kt.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:user_repository/user_repository.dart';

import '../../banking_repository.dart';
import 'player.dart';

class Game extends Equatable {
  const Game({
    required this.id,
    required this.players,
    required this.transactionHistory,
    required this.startingCapital,
    required this.enableFreeParking,
    required this.freeParkingMoney,
    required this.salary,
  });

  /// The unique id of the game.
  final String id;

  /// The players connected to this game, sorted by balance.
  final KtList<Player> players;

  /// The transaction history of this game, sorted by timestamp.
  final KtList<Transaction> transactionHistory;

  /// How much money every player gets when the game starts.
  final int startingCapital;

  /// Whether the free Payout variation is used:
  ///
  /// How it works:
  /// 1. Anytime someone pays a fee or tax (Jail, Income, Luxury, etc.), put the money in the middle of the board.
  /// 2. When someone lands on Free Parking, they get that money. If there is no money, they receive $100.
  final bool enableFreeParking;

  /// If [enableFreeParking] is true:
  /// The amount of money which is currently in the middle of the playing field.
  final int freeParkingMoney;

  /// The amount of money a player gets when going over the GO field.
  final int salary;

  @override
  List<Object> get props =>
      [id, players, transactionHistory, enableFreeParking, freeParkingMoney];

  //todo: make this configurable! create a form when the game is created!
  static Game newOne() {
    return const Game(
      id: '',
      players: KtList<Player>.empty(),
      transactionHistory: KtList<Transaction>.empty(),
      startingCapital: 1500,
      enableFreeParking: false,
      freeParkingMoney: 0,
      salary: 200,
    );
  }

  static Game fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data()!;

    final _players =
        ((List<Map<String, dynamic>>.from(data['players'] as List<dynamic>))
                .map(Player.fromJson)
                .toList()
                  ..sort((a, b) => b.balance.compareTo(a.balance)))
            .toImmutableList();

    final _transactionHistory = ((List<Map<String, dynamic>>.from(
                data['transactionHistory'] as List<dynamic>))
            .map(Transaction.fromJson)
            .toList()
              ..sort((a, b) => b.timestamp.compareTo(a.timestamp)))
        .toImmutableList();

    return Game(
      id: snap.id,
      players: _players,
      transactionHistory: _transactionHistory,
      startingCapital: data['startingCapital'] as int,
      enableFreeParking: data['enableFreeParking'] as bool,
      freeParkingMoney: data['freeParkingMoney'] as int,
      salary: data['salary'] as int,
    );
  }

  Map<String, Object> toDocument() {
    return {
      'players': players.isEmpty()
          ? <Player>[]
          : players.map((player) => player.toJson()).asList(),
      'transactionHistory': transactionHistory.isEmpty()
          ? <Transaction>[]
          : transactionHistory
              .map((transaction) => transaction.toJson())
              .asList(),
      'startingCapital': startingCapital,
      'enableFreeParking': enableFreeParking,
      'freeParkingMoney': freeParkingMoney,
      'salary': salary,
    };
  }

  Game copyWith({
    KtList<Player>? players,
    KtList<Transaction>? transactionHistory,
    int? startingCapital,
    int? freeParkingMoney,
  }) {
    return Game(
      id: id,
      players: players ?? this.players,
      transactionHistory: transactionHistory ?? this.transactionHistory,
      startingCapital: startingCapital ?? this.startingCapital,
      freeParkingMoney: freeParkingMoney ?? this.freeParkingMoney,
      enableFreeParking: enableFreeParking,
      salary: salary,
    );
  }

  /// Whether the user was already connected to this game.
  bool containsUser(String userId) {
    return players.indexOfFirst((player) => player.userId == userId) != -1;
  }

  /// Returns the player with the given id.
  Player getPlayer(String userId) {
    assert(containsUser(userId));

    return players[players.indexOfFirst((player) => player.userId == userId)];
  }

  /// Returns all players except of the one with the given id, sorted by balance.
  List<Player> otherPlayers(String userId) {
    return players.asList().where((player) => player.userId != userId).toList();
  }

  /// Returns a new instance which represents the game after the transaction.
  ///
  /// Use custom constructors for the transaction object:
  /// For example Transaction.fromBank(...) or Transaction.toPlayer(...).
  Game makeTransaction(Transaction transaction) {
    // Create new/updated players list:
    final _players = players.toMutableList().asList();
    var _freeParkingMoney = freeParkingMoney;

    switch (transaction.type) {
      case TransactionType.fromBank:
        assert(transaction.toUser != null);
        // Add money to the players balance:
        final playerIndex = _players
            .indexWhere((player) => player.userId == transaction.toUser!.id);
        _players[playerIndex] =
            _players[playerIndex].addMoney(transaction.amount);
        break;
      case TransactionType.toBank:
        assert(transaction.fromUser != null);
        // Subtract money from the players balance:
        final playerIndex = _players
            .indexWhere((player) => player.userId == transaction.fromUser!.id);
        _players[playerIndex] =
            _players[playerIndex].subtractMoney(transaction.amount);
        break;
      case TransactionType.toPlayer:
        assert(transaction.fromUser != null);
        assert(transaction.toUser != null);
        // Subtract money from the 'from player's balance:
        final fromPlayerIndex = _players
            .indexWhere((player) => player.userId == transaction.fromUser!.id);
        _players[fromPlayerIndex] =
            _players[fromPlayerIndex].subtractMoney(transaction.amount);
        // Add money to the 'to player's balance:
        final toPlayerIndex = _players
            .indexWhere((player) => player.userId == transaction.toUser!.id);
        _players[toPlayerIndex] =
            _players[toPlayerIndex].addMoney(transaction.amount);
        break;
      case TransactionType.toFreeParking:
        assert(transaction.fromUser != null);
        // Subtract money from the players balance:
        final playerIndex = _players
            .indexWhere((player) => player.userId == transaction.fromUser!.id);
        _players[playerIndex] =
            _players[playerIndex].subtractMoney(transaction.amount);
        // Add money to free parking:
        _freeParkingMoney += transaction.amount;
        break;
      case TransactionType.fromFreeParking:
        assert(transaction.toUser != null);
        // Add money to the players balance:
        final playerIndex = _players
            .indexWhere((player) => player.userId == transaction.toUser!.id);
        _players[playerIndex] =
            _players[playerIndex].addMoney(freeParkingMoney);
        // Set free parking money to 0:
        _freeParkingMoney = 0;
        break;
      case TransactionType.fromSalary:
        assert(transaction.toUser != null);
        // Add money to the players balance:
        final playerIndex = _players
            .indexWhere((player) => player.userId == transaction.toUser!.id);
        _players[playerIndex] = _players[playerIndex].addMoney(salary);
        break;
    }

    // Create new/updated transactions list:
    final _transactionHistory = transactionHistory.toMutableList().asList()
      ..add(transaction);

    return copyWith(
      players: _players.toImmutableList(),
      transactionHistory: _transactionHistory.toImmutableList(),
      freeParkingMoney: _freeParkingMoney,
    );
  }

  /// Returns a new instance which represents the the game after the player was added and his start balance was set.
  Game addPlayer(User user) {
    final _players = players.toMutableList();

    if (!containsUser(user.id)) {
      _players.add(
          Player(userId: user.id, name: user.name, balance: startingCapital));
    }

    return copyWith(players: _players.toList());
  }
}
