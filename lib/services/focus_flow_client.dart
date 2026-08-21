import '../domain/knowledge_note.dart';
import '../domain/planner_task.dart';
import 'supabase_rest_client.dart';

/// Backend-neutral contract used by the Flutter application.
///
/// SupabaseRestClient remains available as a migration adapter. New backend
/// implementations should satisfy this contract without leaking provider
/// details into authentication, sync, or UI code.
abstract interface class FocusFlowClient {
  SupabaseSession? get session;

  void setSession(SupabaseSession session);

  void clearSession();

  Future<SupabaseSession> signIn(
      {required String email, required String password});

  Future<SupabaseSession> signUp(
      {required String email, required String password});

  Future<SupabaseSession> signInWithWeChatCode(String code);

  Future<SupabaseSession> refreshSession();

  Future<void> signOut();

  Future<SyncWriteResult> syncNotes(Iterable<KnowledgeNote> notes,
      {Map<String, int> baseVersions = const {}});

  Future<SyncWriteResult> syncTasks(Iterable<PlannerTask> tasks,
      {Map<String, int> baseVersions = const {}});

  Future<List<Map<String, dynamic>>> fetchNotes();

  Future<List<Map<String, dynamic>>> fetchTasks();

  Future<void> registerDeviceToken(
      {required String platform,
      required String provider,
      required String token});

  Future<void> revokeDeviceToken(String token);

  Future<Map<String, dynamic>> exportMyData();

  Future<void> deleteMyAccount();
}
