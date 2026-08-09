class AppConfig {
  const AppConfig({this.supabaseUrl, this.supabaseAnonKey});

  factory AppConfig.fromEnvironment() {
    const rawUrl = String.fromEnvironment('SUPABASE_URL');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    return AppConfig(
      supabaseUrl: Uri.tryParse(rawUrl),
      supabaseAnonKey: anonKey.isEmpty ? null : anonKey,
    );
  }

  final Uri? supabaseUrl;
  final String? supabaseAnonKey;

  bool get hasSupabase =>
      supabaseUrl != null &&
      supabaseAnonKey != null &&
      supabaseAnonKey!.isNotEmpty;
}
