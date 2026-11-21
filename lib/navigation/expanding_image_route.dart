import 'package:flutter/material.dart';

/// Carries the selected tile's artwork into a persistent page background.
/// The destination controls arrive late, after there is room to read them.
class ExpandingImageRoute<T> extends PageRouteBuilder<T> {
  ExpandingImageRoute({
    required Rect origin,
    required Widget Function(double progress) imageBuilder,
    required Widget departureLabel,
    required Widget screen,
    bool reducedMotion = false,
    bool wide = false,
  }) : super(
         transitionDuration: reducedMotion
             ? Duration.zero
             : const Duration(milliseconds: 720),
         reverseTransitionDuration: reducedMotion
             ? Duration.zero
             : const Duration(milliseconds: 560),
         pageBuilder: (_, _, _) => screen,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           return LayoutBuilder(
             builder: (context, constraints) {
               return AnimatedBuilder(
                 animation: animation,
                 child: child,
                 builder: (context, child) {
                   final progress = Curves.easeInOutCubic.transform(
                     animation.value,
                   );
                   final rect = Rect.lerp(
                     origin,
                     Offset.zero & constraints.biggest,
                     progress,
                   )!;
                   final labelOpacity = (1 - animation.value / .25).clamp(
                     0.0,
                     1.0,
                   );
                   final contentOpacity = const Interval(
                     .55,
                     1,
                     curve: Curves.easeOut,
                   ).transform(animation.value);
                   return Stack(
                     fit: StackFit.expand,
                     children: [
                       Positioned.fromRect(
                         rect: rect,
                         child: IgnorePointer(
                           child: ExcludeSemantics(
                             child: ClipRRect(
                               key: const Key('expanding-image-surface'),
                               borderRadius: BorderRadius.circular(
                                 28 * (1 - progress),
                               ),
                               child: Stack(
                                 fit: StackFit.expand,
                                 children: [
                                   imageBuilder(progress),
                                   if (labelOpacity > 0)
                                     Positioned(
                                       left: wide ? 12 : 8,
                                       right: wide ? 12 : 8,
                                       bottom: 12,
                                       child: Opacity(
                                         opacity: labelOpacity,
                                         child: departureLabel,
                                       ),
                                     ),
                                 ],
                               ),
                             ),
                           ),
                         ),
                       ),
                       IgnorePointer(
                         ignoring:
                             animation.status != AnimationStatus.completed,
                         child: ExcludeSemantics(
                           excluding:
                               animation.status != AnimationStatus.completed,
                           child: Opacity(
                             opacity: contentOpacity,
                             child: child,
                           ),
                         ),
                       ),
                     ],
                   );
                 },
               );
             },
           );
         },
       );
}
