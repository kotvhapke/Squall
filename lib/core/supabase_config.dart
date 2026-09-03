class SupabaseConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String livekitUrl = String.fromEnvironment('LIVEKIT_URL', defaultValue: 'wss://localhost:7880');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty &&
      supabaseUrl.startsWith('https://') && supabaseAnonKey.length > 20;
}