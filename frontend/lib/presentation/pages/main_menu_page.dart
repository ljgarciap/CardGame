import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'marketplace_page.dart';
import 'profile_page.dart';

class MainMenuPage extends StatelessWidget {
  const MainMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A237E), // Deep Blue
              Color(0xFF311B92), // Deep Purple
              Color(0xFF000000), // Black
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const FaIcon(FontAwesomeIcons.solidUser, color: Colors.white54),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const ProfilePage()),
                    );
                  },
                ),
              ),
              Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Logo/Title Area
              Column(
                children: [
                  const FaIcon(
                    FontAwesomeIcons.shieldHalved,
                    size: 80,
                    color: Colors.white,
                  ).animate().scale(delay: 200.ms).fadeIn(),
                  const SizedBox(height: 20),
                  Text(
                    'ANTIGRAVITY',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: Colors.white.withOpacity(0.9),
                      shadows: [
                        Shadow(
                          color: Colors.purple.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                  ).animate().slideY(begin: 0.5).fadeIn(),
                  Text(
                    'CARD STUDIO',
                    style: TextStyle(
                      fontSize: 16,
                      letterSpacing: 4,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ).animate().fadeIn(delay: 500.ms),
                ],
              ),
              const Spacer(),
              // Buttons Area
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    _MenuButton(
                      label: 'MARKETPLACE',
                      icon: FontAwesomeIcons.shop,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const MarketplacePage()),
                        );
                      },
                      isPrimary: true,
                    ).animate().slideX(begin: -0.2).fadeIn(delay: 600.ms),
                    const SizedBox(height: 20),
                    _MenuButton(
                      label: 'MULTIPLAYER',
                      icon: FontAwesomeIcons.users,
                      onPressed: () {},
                    ).animate().slideX(begin: 0.2).fadeIn(delay: 700.ms),
                    const SizedBox(height: 20),
                    _MenuButton(
                      label: 'SETTINGS',
                      icon: FontAwesomeIcons.gear,
                      onPressed: () {},
                    ).animate().slideX(begin: -0.2).fadeIn(delay: 800.ms),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              Text(
                'v1.0.0 Alpha',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _MenuButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: isPrimary
            ? const LinearGradient(
                colors: [Color(0xFF7B1FA2), Color(0xFF4527A0)],
              )
            : null,
        color: isPrimary ? null : Colors.white.withOpacity(0.05),
        border: Border.all(
          color: isPrimary ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                FaIcon(
                  icon,
                  size: 20,
                  color: Colors.white.withOpacity(0.8),
                ),
                const SizedBox(width: 20),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
