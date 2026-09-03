import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:squall/core/supabase_config.dart';

class SupabaseService {
  static final client = Supabase.instance.client;

  static String get userId => client.auth.currentUser!.id;

  // --- Profile ---
  static Future<Map<String, dynamic>?> getProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final response = await client.from('profiles').select().eq('id', user.id).single();
    return response as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> getProfileById(String id) async {
    final response = await client.from('profiles').select().eq('id', id).single();
    return response as Map<String, dynamic>?;
  }

  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final response = await client
        .from('profiles')
        .select('id, username, display_name, avatar_url, status')
        .ilike('username', '$query%')
        .limit(20);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> updateProfile({
    String? displayName,
    String? username,
    String? avatarUrl,
    String? status,
  }) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['display_name'] = displayName;
    if (username != null) data['username'] = username;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    if (status != null) data['status'] = status;
    await client.from('profiles').update(data).eq('id', userId);
  }

  // --- Servers ---
  static Future<List<Map<String, dynamic>>> getMyServers() async {
    final response = await client
        .from('server_members')
        .select('server:servers(*)')
        .eq('user_id', userId);
    return response.map((e) => Map<String, dynamic>.from(e['server'])).toList();
  }

  static Future<List<Map<String, dynamic>>> getChannels(int serverId) async {
    final response = await client
        .from('channels')
        .select()
        .eq('server_id', serverId)
        .order('position');
    return List<Map<String, dynamic>>.from(response);
  }

  // --- Messages ---
  static Future<List<Map<String, dynamic>>> getMessages(int channelId) async {
    final response = await client
        .from('messages')
        .select('*, author:profiles!author_id(id, username, display_name, avatar_url, status)')
        .eq('channel_id', channelId)
        .filter('deleted_at', 'is', null)
        .order('created_at');
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<Map<String, dynamic>?> sendMessage(int channelId, String content) async {
    final response = await client
        .from('messages')
        .insert({'channel_id': channelId, 'author_id': userId, 'content': content})
        .select('*, author:profiles!author_id(id, username, display_name, avatar_url, status)')
        .single();
    return response as Map<String, dynamic>?;
  }

  // --- Server RPCs ---
  static Future<int> createServer(String name) async {
    final response = await client.rpc('create_server', params: {'server_name': name});
    return response as int;
  }

  static Future<int> createChannel(int serverId, String name, String type, {String category = ''}) async {
    final response = await client.rpc('create_channel', params: {
      'target_server_id': serverId, 'channel_name': name, 'channel_type': type,
    });
    // Update category separately since RPC doesn't support it
    if (category.isNotEmpty) {
      final id = response is int ? response : (response as Map?)?['id'] ?? response;
      await client.from('channels').update({'category': category}).eq('id', id);
    }
    return response as int;
  }

  static Future<Map<String, dynamic>> createInvite(int serverId, int maxUses, DateTime? expiresAt) async {
    final response = await client.rpc('create_server_invite', params: {
      'target_server_id': serverId, 'max_uses_limit': maxUses, 'expire_at': expiresAt?.toIso8601String(),
    }).single();
    return Map<String, dynamic>.from(response);
  }

  static Future<int> joinServer(String code) async {
    final response = await client.rpc('join_server_by_invite', params: {'invite_code': code});
    return response as int;
  }

  static Future<void> deleteChannel(int channelId) async {
    await client.rpc('delete_channel', params: {'channel_id': channelId});
  }

  static Future<void> leaveServer(int serverId) async {
    await client.rpc('remove_member', params: {'target_server_id': serverId, 'target_user_id': userId});
  }

  // --- Direct Messages ---
  static Future<List<Map<String, dynamic>>> getMyConversations() async {
    final response = await client
        .from('direct_conversation_members')
        .select('conversation:direct_conversations!inner(id, created_at)')
        .eq('user_id', userId);
    final convIds = response.map((e) => e['conversation']['id'] as int).toList();
    if (convIds.isEmpty) return [];

    // Get last message per conversation
    final convs = <Map<String, dynamic>>[];
    for (final cid in convIds) {
      final members = await client
          .from('direct_conversation_members')
          .select('user_id, profile:profiles!user_id(id, username, display_name, avatar_url, status)')
          .eq('conversation_id', cid);
      final other = members.firstWhere(
        (m) => m['user_id'] != userId,
        orElse: () => members.first,
      );
      final lastMsg = await client
          .from('direct_messages')
          .select('content, created_at')
          .eq('conversation_id', cid)
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      convs.add({
        'conversation_id': cid,
        'other_user': other['profile'],
        'last_message': lastMsg,
      });
    }
    convs.sort((a, b) {
      final ta = a['last_message']?['created_at'] as String? ?? '';
      final tb = b['last_message']?['created_at'] as String? ?? '';
      return tb.compareTo(ta);
    });
    return convs;
  }

  static Future<int> createDirectConversation(String otherUserId) async {
    final response = await client.rpc('create_direct_conversation', params: {'other_user_id': otherUserId});
    return response as int;
  }

  static Future<List<Map<String, dynamic>>> getDirectMessages(int conversationId) async {
    final response = await client
        .from('direct_messages')
        .select('*, author:profiles!author_id(id, username, display_name, avatar_url, status)')
        .eq('conversation_id', conversationId)
        .filter('deleted_at', 'is', null)
        .order('created_at');
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<Map<String, dynamic>?> sendDirectMessage(int conversationId, String content) async {
    final response = await client
        .from('direct_messages')
        .insert({'conversation_id': conversationId, 'author_id': userId, 'content': content})
        .select('*, author:profiles!author_id(id, username, display_name, avatar_url, status)')
        .single();
    return response as Map<String, dynamic>?;
  }

  static Future<void> softDeleteDirectMessage(int messageId) async {
    await client.rpc('soft_delete_direct_message', params: {'message_id': messageId});
  }

  static RealtimeChannel subscribeDirectMessages(int conversationId, void Function(Map<String, dynamic> msg) onMessage) {
    final channel = client.channel('dm-$conversationId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'direct_messages',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: conversationId),
      callback: (payload) async {
        final newId = payload.newRecord['id'];
        final msg = await client
            .from('direct_messages')
            .select('*, author:profiles!author_id(id, username, display_name, avatar_url, status)')
            .eq('id', newId)
            .single();
        onMessage(Map<String, dynamic>.from(msg));
      },
    );
    channel.subscribe();
    return channel;
  }

  // --- Blocks ---
  static Future<bool> isBlocked(String otherUserId) async {
    final response = await client
        .from('blocks')
        .select('id')
        .or('blocker_id.eq.$userId,blocked_id.eq.$userId')
        .or('blocker_id.eq.$otherUserId,blocked_id.eq.$otherUserId')
        .maybeSingle();
    return response != null;
  }

  static Future<void> blockUser(String targetId) async {
    await client.from('blocks').insert({'blocker_id': userId, 'blocked_id': targetId});
  }

  static Future<void> unblockUser(String targetId) async {
    await client.from('blocks').delete().eq('blocker_id', userId).eq('blocked_id', targetId);
  }

  static Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final response = await client
        .from('blocks')
        .select('blocked:profiles!blocked_id(id, username, display_name, avatar_url, status)')
        .eq('blocker_id', userId);
    return response.map((e) => Map<String, dynamic>.from(e['blocked'])).toList();
  }

  // --- Realtime (server messages) ---
  static RealtimeChannel subscribeMessages(int channelId, void Function(Map<String, dynamic> message) onMessage) {
    final channel = client.channel('messages-$channelId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'channel_id', value: channelId),
      callback: (payload) async {
        final newId = payload.newRecord['id'];
        final msg = await client
            .from('messages')
            .select('*, author:profiles!author_id(id, username, display_name, avatar_url, status)')
            .eq('id', newId)
            .single();
        onMessage(Map<String, dynamic>.from(msg));
      },
    );
    channel.subscribe();
    return channel;
  }

  // --- Friends ---
  static Future<List<Map<String, dynamic>>> getFriends() async {
    final response = await client
        .from('friends')
        .select('friend_id');
    final ids = response.map((e) => e['friend_id'] as String).toList();
    if (ids.isEmpty) return [];
    return getUsersByIds(ids);
  }

  static Future<List<Map<String, dynamic>>> getUsersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final quoted = ids.map((id) => "'$id'").join(',');
    final response = await client
        .from('profiles')
        .select('id, username, display_name, avatar_url, status')
        .filter('id', 'in', '($quoted)');
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final response = await client
        .from('friend_requests')
        .select('*, sender:sender_id(id, username, display_name, avatar_url, status)')
        .or('sender_id.eq.$userId,receiver_id.eq.$userId')
        .eq('status', 'pending');
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> sendFriendRequest(String username) async {
    final user = await client
        .from('profiles')
        .select('id')
        .ilike('username', username)
        .limit(1)
        .maybeSingle();
    if (user == null) throw Exception('User not found');
    final targetId = user['id'] as String;
    if (targetId == userId) throw Exception('Cannot add yourself');
    final blocked = await isBlocked(targetId);
    if (blocked) throw Exception('Cannot send request');
    await client.from('friend_requests').insert({
      'sender_id': userId,
      'receiver_id': targetId,
    });
  }

  static Future<void> respondToRequest(int requestId, String status) async {
    await client.from('friend_requests').update({'status': status}).eq('id', requestId);
  }

  static Future<void> deleteServer(int serverId) async {
    await client.from('servers').delete().eq('id', serverId);
  }

  static Future<void> setServerVisibility(int serverId, String visibility) async {
    await client.from('servers').update({'visibility': visibility}).eq('id', serverId);
  }

  static Future<String?> uploadAvatar(Uint8List imageBytes, {String? userId}) async {
    final uid = userId ?? SupabaseService.userId;
    final fileName = '$uid/${DateTime.now().millisecondsSinceEpoch}.png';
    try {
      await client.storage.from('avatars').uploadBinary(fileName, imageBytes, fileOptions: const FileOptions(contentType: 'image/png', upsert: true));
      final url = client.storage.from('avatars').getPublicUrl(fileName);
      await client.from('profiles').update({'avatar_url': url}).eq('id', uid);
      return url;
    } catch (e) {
      debugPrint('uploadAvatar error: $e');
      return null;
    }
  }

  static Future<void> logout() async {
    await client.auth.signOut();
  }

  // --- Public Server Catalog (Discover) ---
  static Future<List<Map<String, dynamic>>> getPublicCatalog({String? category, String? search, int limit = 20, int offset = 0}) async {
    var query = client.from('public_server_catalog').select();
    if (category != null && category != 'all') {
      query = query.eq('category', category);
    }
    if (search != null && search.isNotEmpty) {
      query = query.ilike('name', '%$search%');
    }
    final response = await query.order('member_count', ascending: false).limit(limit).range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(response);
  }

  // --- Calls ---

  /// Finds an active (non-ended) call session for a room, or creates/reuses one idempotently.
  static Future<int> findOrCreateCallSession(String roomName, int? serverId, int? channelId, int? conversationId, String callType) async {
    // 1. Look for an existing active session first — ended_at IS NULL means active
    final existing = await client
        .from('calls')
        .select('id')
        .eq('room_name', roomName)
        .filter('ended_at', 'is', null)
        .limit(1)
        .maybeSingle();
    if (existing != null && existing['id'] != null) {
      return existing['id'] as int;
    }

    // 2. If there's an ended call with the same room_name, reuse it — reset ended_at
    final ended = await client
        .from('calls')
        .select('id')
        .eq('room_name', roomName)
        .limit(1)
        .maybeSingle();
    if (ended != null && ended['id'] != null) {
      await client.from('calls').update({'ended_at': null}).eq('id', ended['id'] as int);
      return ended['id'] as int;
    }

    // 3. Try to create new; handle race condition on unique room_name
    try {
      final response = await client.from('calls').insert({
        'room_name': roomName,
        'server_id': serverId,
        'channel_id': channelId,
        'conversation_id': conversationId,
      }).select('id').single();
      return response['id'] as int;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        final retry = await client
            .from('calls')
            .select('id')
            .eq('room_name', roomName)
            .filter('ended_at', 'is', null)
            .limit(1)
            .maybeSingle();
        if (retry != null && retry['id'] != null) return retry['id'] as int;
      }
      rethrow;
    }
  }

  static Future<int> createCallSession(String roomName, int? serverId, int? channelId, int? conversationId, String callType) async {
    return findOrCreateCallSession(roomName, serverId, channelId, conversationId, callType);
  }

  static Future<void> joinCall(int callId) async {
    // Idempotent: check if already a participant
    final existing = await client
        .from('call_participants')
        .select('user_id')
        .eq('call_id', callId)
        .eq('user_id', userId)
        .limit(1)
        .maybeSingle();
    if (existing != null) return;

    try {
      await client.from('call_participants').insert({
        'call_id': callId,
        'user_id': userId,
      });
    } on PostgrestException catch (e) {
      // 23505 means another request already added us — ignore
      if (e.code != '23505') rethrow;
    }
  }

  static Future<void> leaveCall(int callId) async {
    await client.from('call_participants').update({
      'left_at': DateTime.now().toIso8601String(),
    }).eq('call_id', callId).eq('user_id', userId);
  }

  static Future<void> endCallSession(int callId) async {
    await client.from('calls').update({
      'ended_at': DateTime.now().toIso8601String(),
    }).eq('id', callId);
  }

  static Future<Map<String, dynamic>> getLiveKitToken({int? callSessionId, int? voiceChannelId, String? roomName}) async {
    final params = <String, dynamic>{};
    if (callSessionId != null) params['call_session_id'] = callSessionId;
    if (voiceChannelId != null) params['voice_channel_id'] = voiceChannelId;
    if (roomName != null) params['room_name'] = roomName;
    final response = await client.functions.invoke('livekit-token', body: params);
    final data = response.data is Map ? Map<String, dynamic>.from(response.data) : <String, dynamic>{};
    if (data['token'] == null) {
      throw Exception(data['error'] ?? 'Unknown error from livekit-token');
    }
    return data;
  }

  static Future<List<Map<String, dynamic>>> getCallParticipants(int callId) async {
    final data = await client
        .from('call_participants')
        .select('*, profile:profiles!user_id(id, username, display_name, avatar_url, status)')
        .eq('call_id', callId)
        .filter('left_at', 'is', null);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> leaveVoiceChannel(int serverId, int channelId) async {
    final sid = await client.from('calls').select('id').eq('server_id', serverId).eq('channel_id', channelId).filter('ended_at', 'is', null).limit(1).maybeSingle();
    if (sid != null) {
      await client.from('calls').update({'ended_at': DateTime.now().toIso8601String()}).eq('id', sid['id'] as int);
    }
  }

  static Future<Map<String, dynamic>?> getActiveCallForChannel(int serverId, int channelId) async {
    final data = await client
        .from('calls')
        .select()
        .eq('server_id', serverId)
        .eq('channel_id', channelId)
        .filter('ended_at', 'is', null)
        .limit(1)
        .maybeSingle();
    return data;
  }

  // --- Party Finder ---

  static Future<List<Map<String, dynamic>>> searchParties({
    String? game, String? mode, String? platform, String? minRank,
    int limit = 20, int offset = 0,
  }) async {
    final response = await client.rpc('search_parties', params: {
      if (game != null && game.isNotEmpty) 'p_game': game,
      if (mode != null) 'p_mode': mode,
      if (platform != null) 'p_platform': platform,
      if (minRank != null) 'p_min_rank': minRank,
      'p_limit': limit,
      'p_offset': offset,
    });
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<Map<String, dynamic>> createParty({
    required String game,
    String? gameIcon,
    required String mode,
    required String platform,
    required String minRank,
    required int maxPlayers,
    String description = '',
  }) async {
    final response = await client.from('party_listings').insert({
      'game': game,
      'game_icon': gameIcon,
      'mode': mode,
      'platform': platform,
      'min_rank': minRank,
      'max_players': maxPlayers,
      'leader_id': userId,
      'description': description,
    }).select().single();
    return Map<String, dynamic>.from(response);
  }

  static Future<void> joinParty(int partyId) async {
    await client.rpc('join_party', params: {'party_id': partyId});
  }

  static Future<void> leaveParty(int partyId) async {
    await client.rpc('leave_party', params: {'party_id': partyId});
  }

  static Future<Map<String, dynamic>> getPartyWithMembers(int partyId) async {
    final response = await client.rpc('get_party_with_members', params: {'party_id': partyId});
    return Map<String, dynamic>.from(response);
  }

  static Future<void> cancelParty(int partyId) async {
    await client.from('party_listings').update({'status': 'cancelled'}).eq('id', partyId).eq('leader_id', userId);
  }
}

String get livekitUrl => SupabaseConfig.livekitUrl;