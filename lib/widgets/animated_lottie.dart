import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AnimatedLottie extends StatelessWidget {
  final String asset;
  final double? width;
  final double? height;
  final bool repeat;
  final bool animate;
  final BoxFit fit;

  const AnimatedLottie({
    super.key,
    required this.asset,
    this.width,
    this.height,
    this.repeat = true,
    this.animate = true,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Lottie.asset(
        asset,
        fit: fit,
        repeat: repeat,
        animate: animate,
      ),
    );
  }
}

