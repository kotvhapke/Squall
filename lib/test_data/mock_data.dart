import 'models.dart';

final testUsers = [
  SquallUser(id: 'u1', name: 'Cypher', status: UserStatus.online, isSpeaking: true),
  SquallUser(id: 'u2', name: 'NovaRaven', status: UserStatus.online),
  SquallUser(id: 'u3', name: 'FrostByte', status: UserStatus.idle, isSpeaking: true),
  SquallUser(id: 'u4', name: 'ShadowKnight', status: UserStatus.dnd),
  SquallUser(id: 'u5', name: 'PixelWitch', status: UserStatus.online),
  SquallUser(id: 'u6', name: 'BlitzOmega', status: UserStatus.online, isSpeaking: true),
  SquallUser(id: 'u7', name: 'EmberFang', status: UserStatus.offline),
  SquallUser(id: 'u8', name: 'VoidWalker', status: UserStatus.online),
  SquallUser(id: 'u9', name: 'StormCrafter', status: UserStatus.idle),
  SquallUser(id: 'u10', name: 'LunarEcho', status: UserStatus.online),
  SquallUser(id: 'me', name: 'You', status: UserStatus.online),
];

final testChannels = {
  's1': [
    SquallChannel(id: 'c1', serverId: 's1', name: 'welcome', topic: 'Read the rules!'),
    SquallChannel(id: 'c2', serverId: 's1', name: 'general-chat', topic: 'Anything goes'),
    SquallChannel(id: 'c3', serverId: 's1', name: 'looking-for-group', topic: 'Find your squad'),
    SquallChannel(
      id: 'c4', serverId: 's1', name: 'Team Voice',
      type: ChannelType.voice,
      voiceMembers: testUsers.where((u) => u.status != UserStatus.offline).take(5).toList(),
    ),
    SquallChannel(id: 'c5', serverId: 's1', name: 'AFK Lounge', type: ChannelType.voice),
  ],
  's2': [
    SquallChannel(id: 'c6', serverId: 's2', name: 'announcements'),
    SquallChannel(id: 'c7', serverId: 's2', name: 'strategy-discussion'),
    SquallChannel(id: 'c8', serverId: 's2', name: 'ranked-voice', type: ChannelType.voice),
  ],
  's3': [
    SquallChannel(id: 'c9', serverId: 's3', name: 'builds-showcase'),
    SquallChannel(id: 'c10', serverId: 's3', name: 'boss-fights'),
    SquallChannel(id: 'c11', serverId: 's3', name: 'guild-voice', type: ChannelType.voice),
  ],
  's4': [
    SquallChannel(id: 'c12', serverId: 's4', name: 'patching-news'),
    SquallChannel(id: 'c13', serverId: 's4', name: 'modding-corner'),
  ],
};

final testServers = [
  SquallServer(
    id: 's1',
    name: 'Apex Squad',
    icon: 'AS',
    channels: testChannels['s1']!,
    members: testUsers,
    isUnread: true,
  ),
  SquallServer(
    id: 's2',
    name: 'Dota Legends',
    icon: 'DL',
    channels: testChannels['s2']!,
    members: testUsers.take(8).toList(),
  ),
  SquallServer(
    id: 's3',
    name: 'Elder Realm',
    icon: 'ER',
    channels: testChannels['s3']!,
    members: testUsers.where((u) => u.status != UserStatus.offline).toList(),
  ),
  SquallServer(
    id: 's4',
    name: 'Fragment Hub',
    icon: 'FH',
    channels: testChannels['s4']!,
    members: testUsers.take(6).toList(),
  ),
];

final testMessages = [
  SquallMessage(id: 'm1', serverId: 's1', channelId: 'c2', author: testUsers[0], text: 'Anyone up for ranked?', timestamp: DateTime.now().subtract(const Duration(minutes: 15)), reactions: [
    SquallReaction(emoji: '🔥', userIds: ['u2', 'u5']),
    SquallReaction(emoji: '✅', userIds: ['u3']),
  ]),
  SquallMessage(id: 'm2', serverId: 's1', channelId: 'c2', author: testUsers[1], text: 'I\'m in! Just finished warmup.', timestamp: DateTime.now().subtract(const Duration(minutes: 14))),
  SquallMessage(id: 'm3', serverId: 's1', channelId: 'c2', author: testUsers[2], text: 'Give me 5 min, grabbing a drink', timestamp: DateTime.now().subtract(const Duration(minutes: 12))),
  SquallMessage(id: 'm4', serverId: 's1', channelId: 'c2', author: testUsers[4], text: 'New patch broke the meta again lol', timestamp: DateTime.now().subtract(const Duration(minutes: 5)), reactions: [
    SquallReaction(emoji: '😂', userIds: ['u1', 'u3', 'u6']),
  ]),
  SquallMessage(id: 'm5', serverId: 's1', channelId: 'c2', author: testUsers[0], text: 'True. But the new weapon is actually balanced.', timestamp: DateTime.now().subtract(const Duration(minutes: 3))),
  SquallMessage(id: 'm6', serverId: 's1', channelId: 'c2', author: testUsers[5], text: 'It\'s not. I\'ve seen the frame data.', timestamp: DateTime.now().subtract(const Duration(minutes: 1)), replyToId: 'm5'),
];

final testPartyFinder = [
  SquallParty(
    id: 'p1', game: 'Valorant', mode: GameMode.competitive, platform: Platform.pc,
    minRank: Rank.platinum, currentPlayers: 3, maxPlayers: 5,
    leader: testUsers[0], description: 'Need 2 for ranked push, mic required',
  ),
  SquallParty(
    id: 'p2', game: 'Apex Legends', mode: GameMode.pvp, platform: Platform.pc,
    minRank: Rank.gold, currentPlayers: 2, maxPlayers: 3,
    leader: testUsers[4], description: 'Casual BR, looking for 3rd',
  ),
  SquallParty(
    id: 'p3', game: 'Dota 2', mode: GameMode.competitive, platform: Platform.pc,
    minRank: Rank.legendary, currentPlayers: 4, maxPlayers: 5,
    leader: testUsers[1], description: 'Pos 1/2 needed, 6k+ MMR',
  ),
  SquallParty(
    id: 'p4', game: 'Fortnite', mode: GameMode.casual, platform: Platform.playstation,
    minRank: Rank.silver, currentPlayers: 1, maxPlayers: 4,
    leader: testUsers[3], description: 'Chill build battle',
  ),
  SquallParty(
    id: 'p5', game: 'Elden Ring', mode: GameMode.pve, platform: Platform.pc,
    minRank: Rank.gold, currentPlayers: 1, maxPlayers: 3,
    leader: testUsers[5], description: 'Need help with Malenia co-op',
  ),
];

final testDMs = [
  SquallDM(user: testUsers[0], lastMessage: testMessages[0], isUnread: true),
  SquallDM(user: testUsers[4], lastMessage: testMessages[3]),
  SquallDM(user: testUsers[1], lastMessage: testMessages[1], isUnread: true),
  SquallDM(user: testUsers[5], lastMessage: testMessages[5]),
  SquallDM(user: testUsers[2], lastMessage: testMessages[2]),
];