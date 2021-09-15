import 'package:flutter/material.dart';

import '../../../../extensions.dart';

class AnimatedMoneyBalanceText extends StatelessWidget {
  const AnimatedMoneyBalanceText({
    Key? key,
    required this.moneyBalance,
    this.textStyle,
  }) : super(key: key);

  final int moneyBalance;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(
          child: child,
          scale: CurveTween(curve: Curves.easeInOut).animate(animation),
        );
      },
      child: Text(
        context.formatMoneyBalance(moneyBalance),
        key: ValueKey(context.formatMoneyBalance(moneyBalance)),
        style: textStyle,
      ),
    );
  }
}
