import 'package:flutter/material.dart';

enum UserStatus { online, idle, dnd, offline }

enum ChannelType { text, voice }

enum Platform { pc, playstation, xbox, nintendo, mobile }

enum GameMode { pvp, pve, casual, competitive }

enum Rank { bronze, silver, gold, platinum, diamond, legendary }

extension UserStatusColor on UserStatus {
  Color get color {
    switch (this) {
      case UserStatus.online:
        return const Color(0xFF36D66E);
      case UserStatus.idle:
        return const Color(0xFFFFB836);
      case UserStatus.dnd:
        return const Color(0xFFE84A4A);
      case UserStatus.offline:
        return const Color(0xFF3D4F65);
    }
  }
}

class SquallUser {
  final String id;
  final String name;
  final String avatarUrl;
  final UserStatus status;
  final bool isSpeaking;

  SquallUser({
    required this.id,
    required this.name,
    this.avatarUrl = '',
    this.status = UserStatus.online,
    this.isSpeaking = false,
  });
}

class SquallMessage {
  final String id;
  final String serverId;
  final String channelId;
  final SquallUser author;
  final String text;
  final DateTime timestamp;
  final List<SquallReaction> reactions;
  final String? replyToId;

  SquallMessage({
    required this.id,
    required this.serverId,
    required this.channelId,
    required this.author,
    required this.text,
    required this.timestamp,
    this.reactions = const [],
    this.replyToId,
  });
}

class SquallReaction {
  final String emoji;
  final List<String> userIds;

  SquallReaction({required this.emoji, required this.userIds});

  int get count => userIds.length;
}

class SquallChannel {
  final String id;
  final String serverId;
  final String name;
  final ChannelType type;
  final String? topic;
  final List<SquallUser>? voiceMembers;

  SquallChannel({
    required this.id,
    required this.serverId,
    required this.name,
    this.type = ChannelType.text,
    this.topic,
    this.voiceMembers,
  });
}

class SquallServer {
  final String id;
  final String name;
  final String? icon;
  final List<SquallChannel> channels;
  final List<SquallUser> members;
  final bool isUnread;

  SquallServer({
    required this.id,
    required this.name,
    this.icon,
    required this.channels,
    required this.members,
    this.isUnread = false,
  });
}

class SquallParty {
  final String id;
  final String game;
  final String? gameIcon;
  final GameMode mode;
  final Platform platform;
  final Rank minRank;
  final int currentPlayers;
  final int maxPlayers;
  final SquallUser leader;
  final String description;

  SquallParty({
    required this.id,
    required this.game,
    this.gameIcon,
    required this.mode,
    required this.platform,
    required this.minRank,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.leader,
    this.description = '',
  });

  int get slotsLeft => maxPlayers - currentPlayers;
}

class SquallDM {
  final SquallUser user;
  final SquallMessage? lastMessage;
  final bool isUnread;

  SquallDM({
    required this.user,
    this.lastMessage,
    this.isUnread = false,
  });
}