import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:squall/core/theme/app_colors.dart';
import 'package:squall/core/settings/settings_provider.dart';
import 'package:squall/core/translations.dart';
import 'package:squall/shared/widgets/squall_back_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final s = context.read<SettingsProvider>();
    final reduced = context.select<SettingsProvider, bool>((s) => s.reducedEffects);
    final volume = context.select<SettingsProvider, double>((s) => s.masterVolume);
    final mic = context.select<SettingsProvider, double>((s) => s.micSensitivity);
    final fog = context.select<SettingsProvider, double>((s) => s.fogIntensity);
    final arc = context.select<SettingsProvider, double>((s) => s.arcIntensity);
    final glowColor = context.select<SettingsProvider, String>((s) => s.glowColor);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _section('Voice & Audio'.t(context)),
                const SizedBox(height: 12),
                _sliderTile('Master Volume'.t(context), volume, '${volume.round()}%', (v) => s.setMasterVolume(v)),
                _sliderTile('Mic Sensitivity'.t(context), mic, '${mic.round()}%', (v) => s.setMicSensitivity(v)),
                _toggleTile('Push to Talk'.t(context), context.select<SettingsProvider, bool>((s) => s.pushToTalk), (v) => s.setPushToTalk(v)),
                _toggleTile('Voice Activity Detection'.t(context), context.select<SettingsProvider, bool>((s) => s.enableVoiceActivity), (v) => s.setEnableVoiceActivity(v)),
                const SizedBox(height: 24),
                _section('Appearance'.t(context)),
                const SizedBox(height: 12),
                _toggleTile('Reduced Effects'.t(context), reduced, (v) => s.setReducedEffects(v)),
                _toggleTile('Show Online Only'.t(context), context.select<SettingsProvider, bool>((s) => s.showOnlineOnly), (v) => s.setShowOnlineOnly(v)),
                const SizedBox(height: 16),
                _section('Background Effects'.t(context)),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Neon glow that appears and fades across the background',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ),
                _sliderTile('Fog Intensity'.t(context), fog, '${fog.round()}%', (v) => s.setFogIntensity(v)),
                _sliderTile('Arc Intensity'.t(context), arc, '${arc.round()}%', (v) => s.setArcIntensity(v)),
                _colorPickerTile(glowColor, (v) => s.setGlowColor(v)),
                const SizedBox(height: 16),
                _section('Language'.t(context)),
                const SizedBox(height: 8),
                _languageSelector(),
                const SizedBox(height: 24),
                _section('Notifications'.t(context)),
                const SizedBox(height: 12),
                _toggleTile('Sound on Notification'.t(context), context.select<SettingsProvider, bool>((s) => s.soundOnNotification), (v) => s.setSoundOnNotification(v)),
                const SizedBox(height: 24),
                _section('Account'.t(context)),
                const SizedBox(height: 12),
                _actionTile(Icons.logout, 'Sign Out'.t(context), AppColors.danger, onTap: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          SquallBackButton(onPressed: () => Navigator.pop(context)),
          const SizedBox(width: 4),
          Icon(Icons.settings_outlined, size: 22, color: AppColors.electricBlue),
          const SizedBox(width: 10),
          Text('Settings'.t(context), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.8));
  }

  Widget _languageSelector() {
    final settings = context.read<SettingsProvider>();
    final currentLocale = context.select<SettingsProvider, Locale>((s) => s.locale);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text('Language'.t(context), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Locale>(
                value: currentLocale,
                dropdownColor: AppColors.darkBlue,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                items: const [
                  DropdownMenuItem(value: Locale('en'), child: Text('English (default)')),
                  DropdownMenuItem(value: Locale('ru'), child: Text('Русский')),
                ],
                onChanged: (v) { if (v != null) settings.setLocale(v); },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sliderTile(String label, double value, String display, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.blue,
                inactiveTrackColor: AppColors.panelBgOpaque,
                thumbColor: AppColors.electricBlue,
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                overlayColor: AppColors.electricBlue.withValues(alpha: 0.12),
              ),
              child: Slider(value: value, onChanged: onChanged, min: 0, max: 100),
            ),
          ),
          SizedBox(width: 40, child: Text(display, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
        ],
      ),
    );
  }

  Widget _toggleTile(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.electricBlue,
            activeTrackColor: AppColors.blue.withValues(alpha: 0.4),
            inactiveTrackColor: AppColors.panelBgOpaque,
          ),
        ],
      ),
    );
  }

  Widget _colorPickerTile(String current, ValueChanged<String> onChanged) {
    final colors = [
      ('electricBlue', 'Electric Blue', const Color(0xFF00A8FF)),
      ('coldNeon', 'Cold Neon', const Color(0xFF36D6FF)),
      ('purple', 'Purple', const Color(0xFFA855F7)),
      ('green', 'Green', const Color(0xFF36D66E)),
      ('pink', 'Pink', const Color(0xFFFF4D8F)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text('Glow Color'.t(context), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Expanded(
            child: SizedBox(
              height: 38,
              child: ListView(
              scrollDirection: Axis.horizontal,
              children: colors.map((c) {
                final selected = c.$1 == current;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onChanged(c.$1),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: c.$3,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check, size: 18, color: Colors.white)
                          : null,
                    ),
                  ),
                );
              }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.panelBgOpaque,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 14, color: color)),
          const Spacer(),
          Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
        ],
      ),
      ),
    );
  }
}