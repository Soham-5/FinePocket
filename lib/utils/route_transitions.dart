import 'package:flutter/material.dart';

Route createSlideRoute(Widget page, {Offset beginOffset = const Offset(1.0, 0.0)}) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = Curves.easeInOut;
      final tween = Tween(begin: beginOffset, end: Offset.zero).chain(CurveTween(curve: curve));
      final offsetAnimation = animation.drive(tween);

      return SlideTransition(
        position: offsetAnimation,
        child: child,
      );
    },
  );
}
