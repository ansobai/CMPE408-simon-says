import 'package:flutter/material.dart';

void main() {
  runApp(const NeuralRecallApp());
}

class NeuralRecallApp extends StatelessWidget {
  const NeuralRecallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: NeuralRecallHomeScreen(),
    );
  }
}

class NeuralRecallHomeScreen extends StatelessWidget {
  const NeuralRecallHomeScreen({super.key});

  static const Color cyan = Color(0xFF08E4FF);
  static const Color bgTop = Color(0xFF07090F);
  static const Color bgBottom = Color(0xFF020309);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBottom,
      bottomNavigationBar: const _BottomDock(),
      body: Stack(
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
              child: Column(
                children: const [
                  _TopBar(),
                  SizedBox(height: 52),
                  _HeroSection(),
                  SizedBox(height: 50),
                  _StreakPanel(),
                  SizedBox(height: 44),
                  _ModeCard(
                    title: 'Focus Mode',
                    subtitle: '4 Tiles | Relaxed Speed',
                    icon: Icons.filter_none_rounded,
                    gradient: [Color(0xFF2D2E33), Color(0xFF22242A)],
                    iconColor: Color(0xFF24D7EE),
                    borderColor: Color(0x333A3D45),
                  ),
                  SizedBox(height: 24),
                  _ModeCard(
                    title: 'Overdrive Mode',
                    subtitle: '9 Tiles | Rapid Sequence',
                    icon: Icons.bolt_rounded,
                    gradient: [Color(0xFF160A31), Color(0xFF110826)],
                    iconColor: Color(0xFF8D71E9),
                    borderColor: Color(0x66583CA1),
                  ),
                  SizedBox(height: 52),
                  _StatusRow(),
                  SizedBox(height: 28),
                  _VersionTag(),
                  SizedBox(height: 68),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            NeuralRecallHomeScreen.bgTop,
            NeuralRecallHomeScreen.bgBottom,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 120,
            left: -90,
            child: _blurCircle(250, const Color(0x3308E4FF)),
          ),
          Positioned(
            top: 460,
            right: -100,
            child: _blurCircle(260, const Color(0x221A1455)),
          ),
          Positioned(
            bottom: 120,
            left: -100,
            child: _blurCircle(260, const Color(0x201D0D4A)),
          ),
        ],
      ),
    );
  }

  Widget _blurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 60, spreadRadius: 22)],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.memory_rounded,
          size: 30,
          color: NeuralRecallHomeScreen.cyan,
        ),
        const SizedBox(width: 10),
        Text(
          'NEURAL RECALL',
          style: TextStyle(
            color: NeuralRecallHomeScreen.cyan,
            fontSize: 38 * 0.34,
            fontStyle: FontStyle.italic,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w800,
            shadows: [
              Shadow(
                color: NeuralRecallHomeScreen.cyan.withValues(alpha: 0.45),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const Spacer(),
        Icon(
          Icons.settings_rounded,
          color: Colors.white.withValues(alpha: 0.22),
          size: 34,
        ),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -8,
          right: 80,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF9A89EE).withValues(alpha: 0.9),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9A89EE).withValues(alpha: 0.48),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: NeuralRecallHomeScreen.cyan.withValues(alpha: 0.38),
                    blurRadius: 34,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.psychology_alt_rounded,
                size: 92,
                color: NeuralRecallHomeScreen.cyan,
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'NEURAL\nRECALL',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: NeuralRecallHomeScreen.cyan,
                fontSize: 72 * 0.34,
                height: 1.02,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                shadows: [
                  BoxShadow(
                    color: NeuralRecallHomeScreen.cyan.withValues(alpha: 0.65),
                    blurRadius: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StreakPanel extends StatelessWidget {
  const _StreakPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.black.withValues(alpha: 0.13),
        border: Border.all(
          color: NeuralRecallHomeScreen.cyan.withValues(alpha: 0.23),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            'BEST STREAK',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              letterSpacing: 3.6,
              fontSize: 12 * 1.18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '24',
                style: TextStyle(
                  color: NeuralRecallHomeScreen.cyan,
                  fontSize: 66 * 0.34,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    BoxShadow(
                      color: NeuralRecallHomeScreen.cyan.withValues(alpha: 0.6),
                      blurRadius: 16,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'NODES',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 16 * 1.12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.iconColor,
    required this.borderColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final Color iconColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 24 * 0.34 * 2.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13 * 1.28,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, color: iconColor, size: 34),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.info_rounded,
          size: 32,
          color: Colors.white.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 58),
        Icon(
          Icons.equalizer_rounded,
          size: 36,
          color: Colors.white.withValues(alpha: 0.8),
        ),
      ],
    );
  }
}

class _VersionTag extends StatelessWidget {
  const _VersionTag();

  @override
  Widget build(BuildContext context) {
    return Text(
      'SYSTEM ACTIVE V2.0.4',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.2),
        fontSize: 13 * 1.08,
        letterSpacing: 2,
      ),
    );
  }
}

class _BottomDock extends StatelessWidget {
  const _BottomDock();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 98,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: const Color(0xFF090D14).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(
          color: NeuralRecallHomeScreen.cyan.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _DockIcon(icon: Icons.grid_view_rounded, selected: true),
          _DockIcon(icon: Icons.bar_chart_rounded),
          _DockIcon(icon: Icons.settings_rounded),
        ],
      ),
    );
  }
}

class _DockIcon extends StatelessWidget {
  const _DockIcon({required this.icon, this.selected = false});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final Color tint = selected
        ? NeuralRecallHomeScreen.cyan
        : Colors.white.withValues(alpha: 0.22);

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: selected
            ? NeuralRecallHomeScreen.cyan.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: NeuralRecallHomeScreen.cyan.withValues(alpha: 0.38),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Icon(icon, color: tint, size: 32),
    );
  }
}
