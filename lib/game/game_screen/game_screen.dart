import 'package:banking_repository/banking_repository.dart';
import 'package:fleasy/fleasy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../authentication/cubit/auth_cubit.dart';
import '../../extensions.dart';
import '../../shared_widgets.dart';
import 'views/game_view.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthCubit>().state.user;
    assert(user.currentGameId != null);

    return EasyStreamBuilder<Game?>(
      stream: context.bankingRepository().streamGame(user.currentGameId!),
      loadingIndicator: const Center(child: CircularProgressIndicator()),
      dataBuilder: (context, game) {
        if (game == null) {
          context.bankingRepository().leaveGame();
          throw ('User was disconnected from any game, because the current one does not exist anymore.');
        } else {
          return BasicScaffold(
            appBar: AppBar(
              title: Text('Game #${game.id}'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Leave game',
                  onPressed: () => context.bankingRepository().leaveGame(),
                )
              ],
            ),
            applyPadding: false,
            body: GameView(game: game),
          );
        }
      },
    );
  }
}
