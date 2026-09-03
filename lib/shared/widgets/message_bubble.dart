import 'package:flutter/material.dart';
import 'package:squall/core/theme/app_colors.dart';
import 'package:squall/test_data/models.dart';
import 'package:squall/shared/widgets/squall_avatar.dart';

class MessageBubble extends StatelessWidget {
  final SquallMessage message;
  final SquallUser? replyToUser;
  final String? replyText;

  const MessageBubble({
    super.key,
    required this.message,
    this.replyToUser,
    this.replyText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.replyToId != null && replyText != null)
            _replyPreview(),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SquallAvatar(name: message.author.name, size: 36),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(message.author.name, style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                        )),
                        const SizedBox(width: 8),
                        Text(_timeAgo(message.timestamp), style: const TextStyle(
                          fontSize: 10, color: AppColors.textMuted,
                        )),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(message.text, style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary, height: 1.35,
                    )),
                    if (message.reactions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        children: message.reactions.map((r) => _reactionChip(r)).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _replyPreview() {
    return Container(
      margin: const EdgeInsets.only(left: 46, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.electricBlue.withValues(alpha: 0.4), width: 2)),
        color: AppColors.panelBgOpaque,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${replyToUser?.name ?? 'Unknown'} — ${replyText ?? ''}',
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _reactionChip(SquallReaction r) {
    final isMe = r.userIds.contains('me');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isMe ? AppColors.blue.withValues(alpha: 0.2) : AppColors.panelBgOpaque,
        borderRadius: BorderRadius.circular(10),
        border: isMe ? Border.all(color: AppColors.electricBlue.withValues(alpha: 0.3), width: 1) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(r.emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text('${r.count}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}