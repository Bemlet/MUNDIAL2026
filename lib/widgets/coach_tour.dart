/// Tour guiado de primera apertura: oscurece la pantalla, ilumina la pestaña
/// del paso actual y explica qué hace. Avanza con "Siguiente" (o tocando la
/// pantalla) y va cambiando de sección a medida que avanza.
library;

import 'package:flutter/material.dart';

import '../theme.dart';

class TourStep {
  final IconData icon;
  final String title;
  final String description;
  const TourStep({required this.icon, required this.title, required this.description});
}

class CoachTour extends StatelessWidget {
  final List<TourStep> steps;
  final int index;
  final int tabCount;
  final String nextLabel;
  final String skipLabel;
  final String stepLabel;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const CoachTour({
    super.key,
    required this.steps,
    required this.index,
    required this.tabCount,
    required this.nextLabel,
    required this.skipLabel,
    required this.stepLabel,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final bottomInset = media.padding.bottom;
    const navHeight = 68.0;

    final tabWidth = size.width / tabCount;
    final target = Rect.fromLTWH(
      index * tabWidth,
      size.height - bottomInset - navHeight,
      tabWidth,
      navHeight,
    );
    final step = steps[index];

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Scrim con "agujero" sobre la pestaña iluminada. Tocar = siguiente.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onNext,
              child: CustomPaint(painter: _SpotlightPainter(target)),
            ),
          ),
          // Borde dorado alrededor de la pestaña.
          Positioned(
            left: target.left + 4,
            top: target.top,
            width: target.width - 8,
            height: target.height,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Wc.gold, width: 2),
                ),
              ),
            ),
          ),
          // Tarjeta de explicación, justo encima de la barra.
          Positioned(
            left: 18,
            right: 18,
            bottom: navHeight + bottomInset + 16,
            child: _TooltipCard(
              icon: step.icon,
              title: step.title,
              description: step.description,
              stepLabel: stepLabel,
              actionLabel: nextLabel,
              skipLabel: skipLabel,
              onNext: onNext,
              onSkip: onSkip,
            ),
          ),
        ],
      ),
    );
  }
}

class _TooltipCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String stepLabel;
  final String actionLabel;
  final String skipLabel;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _TooltipCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.stepLabel,
    required this.actionLabel,
    required this.skipLabel,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
      decoration: BoxDecoration(
        gradient: Wc.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Wc.gold.withValues(alpha: .45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: Wc.goldHi, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: outfit(17, FontWeight.w900))),
              Text(
                stepLabel,
                style: outfit(11, FontWeight.w700, color: Wc.textDim),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: outfit(13.5, FontWeight.w500, color: Wc.textSoft, height: 1.35),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton(
                onPressed: onSkip,
                child: Text(
                  skipLabel,
                  style: outfit(13, FontWeight.w700, color: Wc.textDim),
                ),
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Wc.gold,
                  foregroundColor: Wc.onGold,
                ),
                onPressed: onNext,
                child: Text(actionLabel, style: outfit(13, FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect target;
  const _SpotlightPainter(this.target);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: .74);
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(
        RRect.fromRectAndRadius(target.inflate(2), const Radius.circular(16)),
      )
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) => oldDelegate.target != target;
}
