import 'package:flutter/material.dart';
import 'package:squall/core/theme/storm_cloud/storm_front_scene.dart';

class StormCloudPreview extends StatefulWidget {
  const StormCloudPreview({super.key});

  @override
  State<StormCloudPreview> createState() => _StormCloudPreviewState();
}

class _StormCloudPreviewState extends State<StormCloudPreview> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF03050A),
      body: StormFrontScene(
        animation: _ctrl,
        child: _buildServerCards(),
      ),
    );
  }

  Widget _buildServerCards() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SERVERS', style: TextStyle(color: const Color(0xFF6B7E95), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                if (i == 3) return _actionCard('Create Server', Icons.add);
                if (i == 4) return _actionCard('Join', Icons.login);
                return _serverCard('S${i + 1}', 'Server ${i + 1}');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _serverCard(String letter, String name) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1729).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1A2744)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF1A2744), border: Border.all(color: const Color(0xFF2F80FF).withValues(alpha: 0.3))),
            alignment: Alignment.center,
            child: Text(letter, style: const TextStyle(color: Color(0xFF2F80FF), fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          Tooltip(message: name, child: Text(name, style: const TextStyle(color: Color(0xFF6B7E95), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }

  Widget _actionCard(String label, IconData icon) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1729).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2F80FF).withValues(alpha: 0.2)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 30, color: const Color(0xFF2F80FF).withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Color(0xFF2F80FF), fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}