/// Widgets y utilidades compartidas.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'theme.dart';

/// Convierte el instante del partido a la zona horaria configurada en el
/// dispositivo donde corre la app.
DateTime localMatchTime(DateTime utc) => utc.toLocal();

String fmtDay(DateTime utc, [String locale = 'es']) {
  final d = localMatchTime(utc);
  final pattern = locale == 'en' ? 'EEEE, MMMM d' : "EEEE d 'de' MMMM";
  final s = DateFormat(pattern, locale).format(d);
  return s[0].toUpperCase() + s.substring(1);
}

String fmtDayShort(DateTime utc, [String locale = 'es']) =>
    DateFormat('EEE d MMM', locale).format(localMatchTime(utc));

String fmtTime(DateTime utc) => DateFormat('HH:mm').format(localMatchTime(utc));

String fmtLocalTimeZone(DateTime utc) {
  final offset = localMatchTime(utc).timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.inHours.abs().toString().padLeft(2, '0');
  final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  return 'UTC$sign$hours:$minutes';
}

/// Bandera con esquinas redondeadas y borde sutil.
class FlagImg extends StatelessWidget {
  final String code;
  final double size;
  final double radius;

  const FlagImg(this.code, {super.key, this.size = 34, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 3 / 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Wc.flagBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        image: DecorationImage(
          image: AssetImage('assets/flags/$code.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// Marcador de posición cuando la llave aún no tiene equipo.
class UnknownFlag extends StatelessWidget {
  final double size;
  const UnknownFlag({super.key, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 3 / 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Wc.surface,
        border: Border.all(color: Wc.line),
      ),
      child: Icon(Icons.help_outline, size: size * .42, color: Wc.textDim),
    );
  }
}

class GradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? borderColor;

  const GradientCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.gradient,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient ?? Wc.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? Wc.line),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Punto rojo pulsante para partidos en vivo.
class LivePulse extends StatefulWidget {
  const LivePulse({super.key});

  @override
  State<LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<LivePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: .35, end: 1.0).animate(_c),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: Wc.live, shape: BoxShape.circle),
      ),
    );
  }
}

class LiveBadge extends StatelessWidget {
  final String text;
  const LiveBadge({super.key, this.text = 'EN VIVO'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Wc.live.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Wc.live.withValues(alpha: .5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LivePulse(),
          const SizedBox(width: 5),
          Text(text, style: outfit(10.5, FontWeight.w800, color: Wc.live)),
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;

  const Pill(this.text, {super.key, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Wc.textDim;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(text, style: outfit(10.5, FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: Wc.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: outfit(16, FontWeight.w800))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Celda de equipo dentro de una tarjeta de partido.
class TeamCell extends StatelessWidget {
  final Team? team;
  final String placeholder;
  final String? displayName;
  final bool alignEnd;

  const TeamCell({
    super.key,
    required this.team,
    required this.placeholder,
    this.displayName,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = Text(
      team == null ? placeholder : displayName ?? team!.name,
      maxLines: 2,
      textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      overflow: TextOverflow.ellipsis,
      style: team != null
          ? outfit(13.5, FontWeight.w700)
          : outfit(11.5, FontWeight.w600, color: Wc.textDim),
    );
    final flag = team != null
        ? FlagImg(team!.flag, size: 36)
        : const UnknownFlag(size: 36);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [flag, const SizedBox(height: 6), name],
    );
  }
}
