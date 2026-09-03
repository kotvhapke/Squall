import 'package:flutter/material.dart';
import 'package:squall/core/theme/app_colors.dart';
import 'package:squall/core/supabase_service.dart';

class ChannelListPanel extends StatefulWidget {
  final List<Map<String, dynamic>> channels;
  final Map<String, dynamic>? selectedChannel;
  final ValueChanged<Map<String, dynamic>> onChannelSelected;
  final int serverId;
  final void Function(Map<String, dynamic> channel)? onDeleteChannel;
  final VoidCallback? onReload;

  const ChannelListPanel({
    super.key,
    required this.channels,
    required this.selectedChannel,
    required this.onChannelSelected,
    required this.serverId,
    this.onDeleteChannel,
    this.onReload,
  });

  @override
  State<ChannelListPanel> createState() => _ChannelListPanelState();
}

class _ChannelListPanelState extends State<ChannelListPanel> {
  bool _textCollapsed = false;
  bool _voiceCollapsed = false;

  void _showCreateChannel(String type) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.darkBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: AppColors.border)),
      title: Text('Create ${type == 'text' ? 'Text' : 'Voice'} Channel', style: const TextStyle(color: AppColors.textPrimary)),
      content: Container(
        decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: TextField(controller: ctrl, autofocus: true, style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Channel name', hintStyle: TextStyle(color: AppColors.textMuted), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
        TextButton(onPressed: () async {
          final name = ctrl.text.trim();
          if (name.isEmpty) return;
          Navigator.pop(ctx);
          try {
            await SupabaseService.createChannel(widget.serverId, name, type);
            widget.onReload?.call();
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
          }
        }, child: const Text('Create', style: TextStyle(color: AppColors.electricBlue, fontWeight: FontWeight.w600))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final textChannels = widget.channels.where((c) => c['type'] == 'text').toList();
    final voiceChannels = widget.channels.where((c) => c['type'] == 'voice').toList();

    return ListView(padding: const EdgeInsets.symmetric(vertical: 4), children: [
      _sectionHeader('Text Channels', textChannels.length, _textCollapsed, () => setState(() => _textCollapsed = !_textCollapsed), () => _showCreateChannel('text')),
      if (!_textCollapsed)
        ...textChannels.isEmpty
            ? [Padding(padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4), child: Text('No text channels', style: TextStyle(fontSize: 11, color: AppColors.textMuted)))]
            : textChannels.map((c) => _channelTile(c)),
      const SizedBox(height: 8),
      _sectionHeader('Voice Channels', voiceChannels.length, _voiceCollapsed, () => setState(() => _voiceCollapsed = !_voiceCollapsed), () => _showCreateChannel('voice')),
      if (!_voiceCollapsed)
        ...voiceChannels.isEmpty
            ? [Padding(padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4), child: Text('No voice channels', style: TextStyle(fontSize: 11, color: AppColors.textMuted)))]
            : voiceChannels.map((c) => _channelTile(c)),
    ]);
  }

  Widget _sectionHeader(String name, int count, bool collapsed, VoidCallback onToggle, VoidCallback onAdd) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        GestureDetector(onTap: onToggle, child: Icon(collapsed ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_down, size: 14, color: AppColors.textMuted)),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onToggle,
          child: Text(name.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.8)),
        ),
        const Spacer(),
        GestureDetector(onTap: onAdd, child: Icon(Icons.add, size: 14, color: AppColors.textMuted)),
      ]),
    );
  }

  Widget _channelTile(Map<String, dynamic> ch) {
    final isSelected = widget.selectedChannel?['id'] == ch['id'];
    final isVoice = ch['type'] == 'voice';
    final icon = isVoice ? Icons.headphones : Icons.tag;
    final iconColor = isVoice ? AppColors.voiceActive : (isSelected ? AppColors.electricBlue : AppColors.channelText);
    final prefix = isVoice ? '' : '# ';
    return GestureDetector(
      onTap: () => widget.onChannelSelected(ch),
      onLongPress: widget.onDeleteChannel != null ? () => widget.onDeleteChannel!(ch) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: isSelected ? BoxDecoration(color: AppColors.panelBgOpaque, border: Border(left: BorderSide(color: AppColors.electricBlue, width: 2))) : null,
        child: Row(children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Expanded(child: Text('$prefix${ch['name'] ?? ''}', style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? AppColors.channelSelected : AppColors.channelText))),
          if (widget.onDeleteChannel != null)
            GestureDetector(onTap: () => widget.onDeleteChannel!(ch), child: Icon(Icons.close, size: 12, color: AppColors.textMuted)),
        ]),
      ),
    );
  }
}