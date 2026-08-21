class AppConfig {
  const AppConfig({
    this.supabaseUrl,
    this.supabaseAnonKey,
    this.wechatAppId,
    this.focusFlowApiUrl,
  });

  factory AppConfig.fromEnvironment() {
    const rawUrl = String.fromEnvironment('SUPABASE_URL');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    const wechatAppId = String.fromEnvironment(
      'WECHAT_APP_ID',
      defaultValue: 'wx64ba2d4d4d4fb15370',
    );
    const focusFlowApiUrl = String.fromEnvironment('FOCUS_FLOW_API_URL');
    return AppConfig(
      supabaseUrl: Uri.tryParse(rawUrl),
      supabaseAnonKey: anonKey.isEmpty ? null : anonKey,
      wechatAppId: wechatAppId.isEmpty ? null : wechatAppId,
      focusFlowApiUrl:
          focusFlowApiUrl.isEmpty ? null : Uri.tryParse(focusFlowApiUrl),
    );
  }

  final Uri? supabaseUrl;
  final String? supabaseAnonKey;
  final String? wechatAppId;
  final Uri? focusFlowApiUrl;

  bool get hasSupabase =>
      supabaseUrl != null &&
      supabaseAnonKey != null &&
      supabaseAnonKey!.isNotEmpty;

  bool get hasFocusFlowApi => focusFlowApiUrl != null;
}
