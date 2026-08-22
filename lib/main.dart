import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'data/app_database.dart';
import 'data/database_provider.dart';
import 'data/knowledge_note_repository.dart';
import 'data/task_repository.dart';
import 'domain/knowledge_note.dart';
import 'domain/course_draft.dart';
import 'domain/news_item.dart';
import 'domain/planner_task.dart';
import 'services/flutter_notification_scheduler.dart';
import 'services/focus_flow_api_client.dart';
import 'services/focus_flow_client.dart';
import 'services/github_digest_client.dart';
import 'services/notification_scheduler.dart';
import 'services/course_reminder_preference_store.dart';
import 'services/course_schedule_parser.dart';
import 'services/course_image_ocr.dart';
import 'services/daily_planner.dart';
import 'services/app_config.dart';
import 'services/auth_controller.dart';
import 'services/auth_session_store.dart';
import 'services/device_token_registrar.dart';
import 'services/deep_link_handler.dart';
import 'services/supabase_rest_client.dart';
import 'services/sync_engine.dart';
import 'services/wechat_auth.dart';
import 'ui/account_page.dart';
import 'ui/add_task_dialog.dart';
import 'ui/schedule_history_view.dart';
import 'ui/window_class.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();
  final AppDatabase? database = (Platform.isAndroid || Platform.isWindows)
      ? await openAppDatabase()
      : null;
  final NotificationScheduler scheduler = Platform.isAndroid
      ? FlutterNotificationScheduler()
      : const NoopNotificationScheduler();
  await scheduler.initialize();
  const digestUrl = String.fromEnvironment('GITHUB_DIGEST_URL');
  final config = AppConfig.fromEnvironment();
  final FocusFlowClient? cloudClient = config.hasFocusFlowApi
      ? FocusFlowApiClient(baseUrl: config.focusFlowApiUrl!)
      : config.hasSupabase
          ? SupabaseRestClient(
              url: config.supabaseUrl!, anonKey: config.supabaseAnonKey!)
          : null;
  final authController = cloudClient == null
      ? null
      : AuthController(
          client: cloudClient,
          store: Platform.isWindows
              ? InMemoryAuthSessionStore()
              : SecureAuthSessionStore(),
          wechatAuth: Platform.isAndroid && config.wechatAppId != null
              ? MethodChannelWeChatAuth(appId: config.wechatAppId!)
              : null);
  await authController?.restore();
  final ownerUserId = authController?.session?.userId;
  runApp(FocusFlowApp(
      repository: database == null
          ? null
          : DriftTaskRepository(database, ownerUserId: ownerUserId),
      noteRepository: database == null
          ? null
          : DriftNoteRepository(database, ownerUserId: ownerUserId),
      newsClient: digestUrl.isEmpty
          ? null
          : GitHubDigestClient(endpoint: Uri.parse(digestUrl)),
      authController: authController,
      cloudClient: cloudClient,
      scheduler: scheduler,
      courseReminderPreferenceStore: Platform.isAndroid
          ? SecureCourseReminderPreferenceStore()
          : InMemoryCourseReminderPreferenceStore(),
      database: database));
}

DateTime _todayAt(int hour, [int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, minute);
}

List<PlannerTask> _demoTasks() => [
      PlannerTask(
          id: 'task-1',
          title: 'Deep work',
          startAt: _todayAt(9).toUtc(),
          endAt: _todayAt(10, 30).toUtc(),
          timeZoneId: 'Asia/Shanghai',
          reminderMinutes: 5),
      PlannerTask(
          id: 'task-2',
          title: 'Walk break',
          startAt: _todayAt(12, 30).toUtc(),
          endAt: _todayAt(13).toUtc(),
          timeZoneId: 'Asia/Shanghai'),
      PlannerTask(
          id: 'task-3',
          title: 'Review notes',
          startAt: _todayAt(18).toUtc(),
          endAt: _todayAt(18, 30).toUtc(),
          timeZoneId: 'Asia/Shanghai'),
    ];

class FocusFlowApp extends StatelessWidget {
  const FocusFlowApp(
      {super.key,
      this.repository,
      this.noteRepository,
      this.newsClient,
      this.authController,
      this.cloudClient,
      this.scheduler,
      this.courseReminderPreferenceStore,
      this.database});

  final TaskRepository? repository;
  final NoteRepository? noteRepository;
  final GitHubDigestClient? newsClient;
  final AuthController? authController;
  final FocusFlowClient? cloudClient;
  final NotificationScheduler? scheduler;
  final CourseReminderPreferenceStore? courseReminderPreferenceStore;
  final AppDatabase? database;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Focus Flow',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff157a6e),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff6f8f7),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: FocusFlowShell(
          repository: repository,
          noteRepository: noteRepository,
          newsClient: newsClient,
          authController: authController,
          cloudClient: cloudClient,
          scheduler: scheduler,
          courseReminderPreferenceStore: courseReminderPreferenceStore,
          database: database),
    );
  }
}

class FocusFlowShell extends StatefulWidget {
  const FocusFlowShell(
      {super.key,
      this.repository,
      this.noteRepository,
      this.newsClient,
      this.authController,
      this.cloudClient,
      this.scheduler,
      this.courseReminderPreferenceStore,
      this.database});

  final TaskRepository? repository;
  final NoteRepository? noteRepository;
  final GitHubDigestClient? newsClient;
  final AuthController? authController;
  final FocusFlowClient? cloudClient;
  final NotificationScheduler? scheduler;
  final CourseReminderPreferenceStore? courseReminderPreferenceStore;
  final AppDatabase? database;

  @override
  State<FocusFlowShell> createState() => _FocusFlowShellState();
}

class _FocusFlowShellState extends State<FocusFlowShell>
    with WidgetsBindingObserver {
  int selectedIndex = 0;
  late final TaskRepository repository = widget.repository ??
      InMemoryTaskRepository(seed: [
        PlannerTask(
            id: 'task-1',
            title: '深度工作：产品规格',
            startAt: _todayAt(9).toUtc(),
            endAt: _todayAt(10, 30).toUtc(),
            timeZoneId: 'Asia/Shanghai',
            reminderMinutes: 5),
        PlannerTask(
            id: 'task-2',
            title: '午间散步',
            startAt: _todayAt(12, 30).toUtc(),
            endAt: _todayAt(13).toUtc(),
            timeZoneId: 'Asia/Shanghai'),
        PlannerTask(
            id: 'task-3',
            title: '整理今日笔记',
            startAt: _todayAt(18).toUtc(),
            endAt: _todayAt(18, 30).toUtc(),
            timeZoneId: 'Asia/Shanghai'),
      ]);
  late final NoteRepository noteRepository = widget.noteRepository ??
      InMemoryNoteRepository(seed: [
        KnowledgeNote(
            id: 'note-1',
            title: '把复杂问题拆成可验证的假设',
            bodyMarkdown: '今天在设计资讯聚合时，先定义热点，再选择数据源。',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now()),
        KnowledgeNote(
            id: 'note-2',
            title: '阅读记录：Agent 工作流',
            bodyMarkdown: '工具调用的边界决定了系统的可靠性。',
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
            updatedAt: DateTime.now().subtract(const Duration(days: 1))),
      ]);
  late final NotificationScheduler scheduler =
      widget.scheduler ?? const NoopNotificationScheduler();
  late final CourseReminderPreferenceStore courseReminderPreferenceStore =
      widget.courseReminderPreferenceStore ??
          InMemoryCourseReminderPreferenceStore();
  final tasks = <PlannerTask>[];
  bool courseRemindersEnabled = true;
  late final Future<void> _courseReminderPreferenceReady;
  bool isLoading = true;
  final notes = <KnowledgeNote>[];
  DeviceTokenRegistrar? tokenRegistrar;
  int _authGeneration = 0;
  bool _isSyncing = false;
  Future<void> _notificationQueue = Future<void>.value();
  final DeepLinkHandler _deepLinkHandler = DeepLinkHandler();
  StreamSubscription<RemoteMessage>? _fcmForegroundSub;
  StreamSubscription<RemoteMessage>? _fcmOpenedSub;
  StreamSubscription<DeepLinkEvent>? _deepLinkSub;
  int _guestTaskCount = 0;
  int _guestNoteCount = 0;

  @override
  void initState() {
    super.initState();
    // Widget tests can construct the shell without calling main().
    tz_data.initializeTimeZones();
    _courseReminderPreferenceReady = _loadCourseReminderPreference();
    WidgetsBinding.instance.addObserver(this);
    widget.authController?.addListener(_onAuthChanged);
    if (widget.repository == null && widget.noteRepository == null) {
      tasks.addAll(_demoTasks());
      noteRepository.loadNotes().then((loaded) {
        if (mounted) {
          setState(() => notes
            ..clear()
            ..addAll(loaded));
        }
      });
      isLoading = false;
    } else {
      unawaited(_loadData(generation: _authGeneration));
    }
    _setupDeepLinks();
    unawaited(_setupFirebaseMessaging());
    if (widget.authController?.status == AuthStatus.signedIn) {
      unawaited(_ensureTokenRegistration(_authGeneration));
      unawaited(_refreshGuestDataCounts(_authGeneration));
    }
  }

  Future<void> _loadCourseReminderPreference() async {
    try {
      final enabled = await courseReminderPreferenceStore.load();
      if (mounted) setState(() => courseRemindersEnabled = enabled);
    } on Object {
      // A local storage failure must not prevent the planner from opening.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final pending = _deepLinkHandler.consumePending();
      if (pending != null) _navigateDeepLink(pending);
    }
  }

  void _setupDeepLinks() {
    final pending = _deepLinkHandler.consumePending();
    if (pending != null) _navigateDeepLink(pending);
    _deepLinkSub = _deepLinkHandler.events.listen(_navigateDeepLink);
  }

  Future<void> _setupFirebaseMessaging() async {
    if (!Platform.isAndroid) return;
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      _fcmForegroundSub =
          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      _fcmOpenedSub =
          FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) _handleNotificationTap(initialMessage);
    } on Object {
      // News and local planning remain available without Firebase setup.
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final deepLink = message.data['deep_link'];
    if (deepLink is String) _deepLinkHandler.handleUri(deepLink);
  }

  void _handleNotificationTap(RemoteMessage message) {
    final deepLink = message.data['deep_link'];
    if (deepLink is String) _deepLinkHandler.handleUri(deepLink);
  }

  void _navigateDeepLink(DeepLinkEvent event) {
    if (!mounted || event.route != DeepLinkRoute.newsDaily) return;
    setState(() => selectedIndex = 2);
  }

  Future<DeviceTokenSource> _detectPushSource() async {
    if (!Platform.isAndroid) return FirebaseDeviceTokenSource();
    try {
      await FirebaseMessaging.instance.getToken();
      return FirebaseDeviceTokenSource();
    } on Object {
      return HuaweiDeviceTokenSource();
    }
  }

  Future<void> _refreshGuestDataCounts(int generation) async {
    final database = widget.database;
    if (database == null) return;
    final guestTasks = await DriftTaskRepository(database).loadTasks();
    final guestNotes = await DriftNoteRepository(database).loadNotes();
    if (!mounted || generation != _authGeneration) return;
    setState(() {
      _guestTaskCount = guestTasks.length;
      _guestNoteCount = guestNotes.length;
    });
  }

  Future<void> _importGuestData() async {
    final currentOwner = widget.authController?.session?.userId;
    final database = widget.database;
    if (currentOwner == null || database == null) return;
    final guestTasks = await DriftTaskRepository(database).loadTasks();
    final guestNotes = await DriftNoteRepository(database).loadNotes();
    for (final task in guestTasks) {
      await repository.saveTask(task);
    }
    for (final note in guestNotes) {
      await noteRepository.saveNote(note);
    }
    await _loadData(generation: _authGeneration);
    await _refreshGuestDataCounts(_authGeneration);
  }

  Future<void> _loadData({required int generation}) async {
    final results = await Future.wait<Object>([
      repository.loadTasks(),
      noteRepository.loadNotes(),
    ]);
    if (!mounted || generation != _authGeneration) return;
    final loaded = results[0] as List<PlannerTask>;
    final loadedNotes = results[1] as List<KnowledgeNote>;
    setState(() {
      tasks
        ..clear()
        ..addAll(loaded);
      notes
        ..clear()
        ..addAll(loadedNotes);
      isLoading = false;
    });
    _notificationQueue =
        _notificationQueue.catchError((Object _) {}).then((_) async {
      if (generation != _authGeneration) return;
      await _courseReminderPreferenceReady;
      await scheduler.rescheduleAll(loaded.where(_shouldScheduleReminder));
    });
    await _notificationQueue;
  }

  @override
  void dispose() {
    widget.authController?.removeListener(_onAuthChanged);
    tokenRegistrar?.dispose();
    widget.authController?.dispose();
    widget.database?.close();
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkHandler.dispose();
    _deepLinkSub?.cancel();
    _fcmForegroundSub?.cancel();
    _fcmOpenedSub?.cancel();
    super.dispose();
  }

  void _onAuthChanged() {
    final controller = widget.authController;
    final ownerUserId = controller?.status == AuthStatus.signedIn
        ? controller?.session?.userId
        : null;
    final generation = ++_authGeneration;
    repository.setOwner(ownerUserId);
    noteRepository.setOwner(ownerUserId);
    if (!mounted) return;
    setState(() {
      tasks.clear();
      notes.clear();
      isLoading = true;
    });
    _notificationQueue = _notificationQueue
        .catchError((Object _) {})
        .then((_) => scheduler.cancelAll());
    unawaited(_loadData(generation: generation));
    if (ownerUserId != null) {
      unawaited(_ensureTokenRegistration(generation));
      unawaited(_refreshGuestDataCounts(generation));
    }
  }

  Future<void> _ensureTokenRegistration(int generation) async {
    final client = widget.cloudClient;
    if (client?.session == null || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }
    try {
      await Firebase.initializeApp();
      if (!mounted ||
          generation != _authGeneration ||
          widget.authController?.status != AuthStatus.signedIn) {
        return;
      }
      final source = await _detectPushSource();
      tokenRegistrar ??= DeviceTokenRegistrar(
        client: client!,
        source: source,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
      await tokenRegistrar!.start();
    } on Object {
      // Local features remain usable before a push provider is configured.
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final windowClass = windowClassFor(constraints.maxWidth);
        final isCompact = windowClass.usesBottomNavigation;
        final isWide = windowClass.supportsThreePanes;
        final content = _buildContent(isWide: isWide);

        if (isCompact) {
          return Scaffold(
            body: SafeArea(child: content),
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (value) =>
                  setState(() => selectedIndex = value),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.today_outlined),
                    selectedIcon: Icon(Icons.today),
                    label: '今日'),
                NavigationDestination(
                    icon: Icon(Icons.history_outlined),
                    selectedIcon: Icon(Icons.history),
                    label: '历史'),
                NavigationDestination(
                    icon: Icon(Icons.auto_awesome_outlined),
                    selectedIcon: Icon(Icons.auto_awesome),
                    label: 'AI 资讯'),
                NavigationDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book),
                    label: '知识库'),
                NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: '账号'),
              ],
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (value) =>
                      setState(() => selectedIndex = value),
                  labelType: isWide
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.only(top: 10, bottom: 26),
                    child: Icon(Icons.track_changes, size: 28),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                        icon: Icon(Icons.today_outlined),
                        selectedIcon: Icon(Icons.today),
                        label: Text('今日')),
                    NavigationRailDestination(
                        icon: Icon(Icons.history_outlined),
                        selectedIcon: Icon(Icons.history),
                        label: Text('历史')),
                    NavigationRailDestination(
                        icon: Icon(Icons.auto_awesome_outlined),
                        selectedIcon: Icon(Icons.auto_awesome),
                        label: Text('AI 资讯')),
                    NavigationRailDestination(
                        icon: Icon(Icons.menu_book_outlined),
                        selectedIcon: Icon(Icons.menu_book),
                        label: Text('知识库')),
                    NavigationRailDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: Text('账号')),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent({required bool isWide}) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    switch (selectedIndex) {
      case 1:
        return ScheduleHistoryView(tasks: tasks);
      case 2:
        return _NewsView(
            isWide: isWide,
            client: widget.newsClient,
            apiClient: widget.cloudClient);
      case 3:
        return _KnowledgeView(
            notes: notes, isWide: isWide, onAdd: _addNote, onEdit: _editNote);
      case 4:
        final controller = widget.authController;
        return controller == null
            ? const _CloudUnavailableView()
            : AccountPage(
                controller: controller,
                onSync: _syncNow,
                onSignOut: _signOut,
                onImportGuestData: _importGuestData,
                onCountGuestData: () async => GuestDataCount(
                    taskCount: _guestTaskCount, noteCount: _guestNoteCount),
              );
      default:
        return _TodayView(
          tasks: _todayTasks(),
          isWide: isWide,
          onToggle: _toggleTask,
          onAdd: _addTask,
          onEdit: _editTask,
          onDelete: _deleteTask,
          onMarkTodayIncomplete: _markTodayIncomplete,
          courseRemindersEnabled: courseRemindersEnabled,
          onCourseRemindersChanged: _setCourseRemindersEnabled,
          onImportCourses: _importCourses,
          onImportCourseScreenshot: _importCourseScreenshot,
          onGeneratePlan: _generateDailyPlan,
        );
    }
  }

  Future<void> _addTask() async {
    final task = await showDialog<PlannerTask>(
        context: context, builder: (context) => const AddTaskDialog());
    if (!mounted || task == null) return;
    setState(() {
      tasks.add(task);
      _sortTasks();
    });
    await repository.saveTask(task);
    await _scheduleReminder(task);
  }

  Future<void> _importCourses() async {
    final input = await showDialog<String>(
      context: context,
      builder: (context) => const _CourseImportDialog(),
    );
    if (!mounted || input == null || input.trim().isEmpty) return;
    try {
      final drafts = const CourseScheduleParser().parseJson(input);
      await _confirmAndImportCourses(drafts);
    } on FormatException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Object {
      if (mounted) _showMessage('课表导入失败，请检查格式。');
    }
  }

  Future<void> _importCourseScreenshot() async {
    try {
      final text = await CourseImageOcr().pickAndRecognize();
      if (!mounted || text == null || text.trim().isEmpty) return;
      final drafts = const CourseScheduleParser().parseText(text);
      await _confirmAndImportCourses(drafts);
    } on FormatException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Object {
      if (mounted) _showMessage('截图识别失败，请确认图片清晰后重试。');
    }
  }

  Future<void> _confirmAndImportCourses(List<CourseDraft> drafts) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _CourseDraftReviewDialog(drafts: drafts),
    );
    if (!mounted || confirmed != true) return;
    try {
      final today = DateTime.now();
      final nextMonday = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: today.weekday - 1));
      final imported = <PlannerTask>[];
      for (final draft in drafts) {
        final firstWeek = (draft.firstWeek ?? 1) - 1;
        final lastWeek = draft.lastWeek ?? 16;
        for (var week = firstWeek; week < lastWeek; week++) {
          final date = nextMonday.add(Duration(days: draft.weekday - 1 + week * 7));
          final start = DateTime.utc(date.year, date.month, date.day,
                  draft.startMinute ~/ 60, draft.startMinute % 60)
              .subtract(const Duration(hours: 8));
          final end = DateTime.utc(date.year, date.month, date.day,
                  draft.endMinute ~/ 60, draft.endMinute % 60)
              .subtract(const Duration(hours: 8));
          imported.add(PlannerTask(
            id: 'course-${date.toIso8601String()}-${draft.name}-${draft.startMinute}',
            title: draft.name,
            kind: ScheduleItemKind.course,
            location: draft.location,
            startAt: start,
            endAt: end,
            timeZoneId: 'Asia/Shanghai',
            reminderMinutes: 5,
            recurrence: TaskRecurrence.none,
          ));
        }
      }
      for (final task in imported) {
        await repository.saveTask(task);
      }
      await _scheduleImportedReminders(imported);
      await _loadData(generation: _authGeneration);
      if (mounted) _showMessage('已导入 ${drafts.length} 门课程，生成对应周次课表。');
    } on Object {
      if (mounted) _showMessage('课表保存失败，请稍后重试。');
    }
  }

  Future<void> _scheduleImportedReminders(Iterable<PlannerTask> imported) async {
    final reminders = imported.where(_shouldScheduleReminder).toList(growable: false);
    if (reminders.isEmpty) return;
    try {
      final granted = await scheduler.requestPermissions();
      if (!granted) {
        if (mounted) _showMessage('请在系统设置中允许通知，课程提醒才能显示。');
        return;
      }
      for (final task in reminders) {
        await scheduler.schedule(task);
      }
    } on Object {
      if (mounted) _showMessage('课程提醒创建失败，请检查通知权限。');
    }
  }

  Future<void> _generateDailyPlan() async {
    final generated = const DailyPlanner().generate(
      day: DateTime.now(),
      existing: tasks,
      targetMinutes: 120,
    );
    if (generated.isEmpty) {
      if (mounted) _showMessage('今天没有足够的连续空闲时间生成专注计划。');
      return;
    }
    final confirmed = await showDialog<List<PlannerTask>>(
      context: context,
      builder: (context) => _DailyPlanReviewDialog(drafts: generated),
    );
    if (!mounted || confirmed == null || confirmed.isEmpty) return;
    for (final task in confirmed) {
      await repository.saveTask(task);
      await _scheduleReminder(task);
    }
    await _loadData(generation: _authGeneration);
    if (mounted) _showMessage('已确认并加入 ${confirmed.length} 个今日专注时间段。');
  }

  Future<void> _editTask(PlannerTask task) async {
    final edited = await showDialog<PlannerTask>(
      context: context,
      builder: (context) => AddTaskDialog(original: task),
    );
    if (!mounted || edited == null) return;
    final index = tasks.indexWhere((candidate) => candidate.id == task.id);
    if (index < 0) return;
    setState(() {
      tasks[index] = edited;
      _sortTasks();
    });
    await repository.saveTask(edited);
    await scheduler.cancel(edited.id);
    await _scheduleReminder(edited);
  }

  Future<void> _deleteTask(PlannerTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这个安排？'),
        content: Text('“${task.title}”会从时间轴移除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await repository.deleteTask(task.id);
    await scheduler.cancel(task.id);
    if (!mounted) return;
    setState(() => tasks.removeWhere((candidate) => candidate.id == task.id));
  }

  Future<void> _toggleTask(PlannerTask task) async {
    final index = tasks.indexWhere((candidate) => candidate.id == task.id);
    if (index < 0) return;
    final updated = task.copyWith(
      status: task.isCompleted ? TaskStatus.planned : TaskStatus.completed,
    );
    setState(() => tasks[index] = updated);
    await repository.saveTask(updated);
    if (updated.isCompleted) {
      await scheduler.cancel(updated.id);
    } else {
      await _scheduleReminder(updated);
    }
  }

  Future<void> _markTodayIncomplete(PlannerTask task) async {
    final index = tasks.indexWhere((candidate) => candidate.id == task.id);
    if (index < 0) return;
    final updated = task.copyWith(status: TaskStatus.todayIncomplete);
    setState(() => tasks[index] = updated);
    await repository.saveTask(updated);
    await scheduler.cancel(updated.id);
  }

  Future<void> _setCourseRemindersEnabled(bool enabled) async {
    if (courseRemindersEnabled == enabled) return;
    setState(() => courseRemindersEnabled = enabled);
    try {
      await courseReminderPreferenceStore.save(enabled);
      final courses = tasks.where((task) =>
          task.kind == ScheduleItemKind.course && task.reminderEnabled);
      if (!enabled) {
        for (final task in courses) {
          await scheduler.cancel(task.id);
        }
        return;
      }

      final granted = await scheduler.requestPermissions();
      if (!granted) {
        await courseReminderPreferenceStore.save(false);
        if (mounted) {
          setState(() => courseRemindersEnabled = false);
          _showMessage('系统通知权限未开启，课程提醒仍保持关闭。');
        }
        return;
      }
      for (final task in courses.where(_shouldScheduleReminder)) {
        await scheduler.schedule(task);
      }
    } on Object {
      if (mounted) {
        setState(() => courseRemindersEnabled = !enabled);
        _showMessage('提醒设置保存失败，请稍后重试。');
      }
    }
  }

  Future<void> _scheduleReminder(PlannerTask task) async {
    if (!_shouldScheduleReminder(task)) {
      await scheduler.cancel(task.id);
      return;
    }
    try {
      final granted = await scheduler.requestPermissions();
      if (!granted) {
        if (mounted) _showMessage('请在系统设置中允许通知，提醒才能显示在手机屏幕上。');
        return;
      }
      await scheduler.schedule(task);
    } on Object {
      if (mounted) _showMessage('提醒创建失败，请检查通知和精确闹钟权限。');
    }
  }

  bool _shouldScheduleReminder(PlannerTask task) {
    if (!task.reminderEnabled || task.status != TaskStatus.planned) {
      return false;
    }
    return task.kind != ScheduleItemKind.course || courseRemindersEnabled;
  }

  List<PlannerTask> _todayTasks() {
    final location = tz.getLocation('Asia/Shanghai');
    final today = tz.TZDateTime.now(location);
    final result = tasks.where((task) {
      final start = tz.TZDateTime.from(task.startAt.toUtc(), location);
      return start.year == today.year &&
          start.month == today.month &&
          start.day == today.day;
    }).toList()
      ..sort((left, right) => left.startAt.compareTo(right.startAt));
    return result;
  }

  void _sortTasks() =>
      tasks.sort((left, right) => left.startAt.compareTo(right.startAt));

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addNote() async {
    final note = await _showNoteDialog();
    if (!mounted || note == null) return;
    setState(() => notes.insert(0, note));
    await noteRepository.saveNote(note);
  }

  Future<void> _editNote(KnowledgeNote original) async {
    final edited = await _showNoteDialog(original: original);
    if (!mounted || edited == null) return;
    final index = notes.indexOf(original);
    if (index < 0) return;
    setState(() => notes[index] = edited);
    await noteRepository.saveNote(edited);
  }

  Future<KnowledgeNote?> _showNoteDialog({KnowledgeNote? original}) async {
    return showDialog<KnowledgeNote>(
      context: context,
      builder: (context) => _NoteDialog(original: original),
    );
  }

  Future<SyncReport> _syncNow() async {
    final client = widget.cloudClient;
    if (client == null || client.session == null || _isSyncing) {
      return const SyncReport(pulled: 0, pushed: 0, conflicts: 0);
    }
    _isSyncing = true;
    try {
      final generation = _authGeneration;
      final report = await SyncEngine(
              client: client, tasks: repository, notes: noteRepository)
          .sync();
      await _loadData(generation: generation);
      return report;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _signOut() async {
    final registrar = tokenRegistrar;
    tokenRegistrar = null;
    if (registrar != null) {
      try {
        await registrar.revoke();
      } on Object {
        // Local sign-out must remain available while offline.
      }
    }
    await widget.authController?.signOut();
  }
}

class _CloudUnavailableView extends StatelessWidget {
  const _CloudUnavailableView();

  @override
  Widget build(BuildContext context) => const Center(
      child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('云同步尚未配置。请在构建时提供 SUPABASE_URL 和 SUPABASE_ANON_KEY。',
              textAlign: TextAlign.center)));
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({this.original});

  final KnowledgeNote? original;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController titleController;
  late final TextEditingController bodyController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.original?.title);
    bodyController = TextEditingController(text: widget.original?.bodyMarkdown);
  }

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.original == null ? '新建笔记' : '编辑笔记'),
      content: SizedBox(
        width: 480,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              key: const Key('note-title-field'),
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(labelText: '标题')),
          const SizedBox(height: 12),
          TextField(
              key: const Key('note-body-field'),
              controller: bodyController,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(labelText: '内容')),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            final title = titleController.text.trim();
            if (title.isEmpty) return;
            final now = DateTime.now();
            Navigator.pop(
              context,
              KnowledgeNote(
                id: widget.original?.id ?? const Uuid().v4(),
                title: title,
                bodyMarkdown: bodyController.text.trim(),
                createdAt: widget.original?.createdAt ?? now,
                updatedAt: now,
                version: (widget.original?.version ?? 0) + 1,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _CourseImportDialog extends StatefulWidget {
  const _CourseImportDialog();

  @override
  State<_CourseImportDialog> createState() => _CourseImportDialogState();
}

class _CourseImportDialogState extends State<_CourseImportDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导入课表'),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: controller,
          minLines: 8,
          maxLines: 14,
          decoration: const InputDecoration(
            labelText: '粘贴截图 OCR 结果或 JSON',
            hintText: '周一 高等数学 08:00-09:40 A203',
            alignLabelWithHint: true,
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('解析并导入'),
        ),
      ],
    );
  }
}

class _CourseDraftReviewDialog extends StatelessWidget {
  const _CourseDraftReviewDialog({required this.drafts});

  final List<CourseDraft> drafts;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    String clock(int minute) =>
        '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
    return AlertDialog(
      title: Text('确认导入 ${drafts.length} 门课程'),
      content: SizedBox(
        width: 520,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: drafts.length,
          itemBuilder: (context, index) {
            final draft = drafts[index];
            return ListTile(
              leading: const Icon(Icons.school_outlined),
              title: Text(draft.name),
              subtitle: Text(
                '${weekdays[draft.weekday - 1]} ${clock(draft.startMinute)}-${clock(draft.endMinute)}'
                '${draft.location.isEmpty ? '' : ' · ${draft.location}'}',
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认导入')),
      ],
    );
  }
}

class _DailyPlanReviewDialog extends StatefulWidget {
  const _DailyPlanReviewDialog({required this.drafts});

  final List<PlannerTask> drafts;

  @override
  State<_DailyPlanReviewDialog> createState() => _DailyPlanReviewDialogState();
}

class _DailyPlanReviewDialogState extends State<_DailyPlanReviewDialog> {
  late final List<PlannerTask> drafts = [...widget.drafts];

  bool get hasOverlap {
    final sorted = [...drafts]..sort((a, b) => a.startAt.compareTo(b.startAt));
    for (var index = 1; index < sorted.length; index++) {
      if (sorted[index].startAt.isBefore(sorted[index - 1].endAt)) return true;
    }
    return false;
  }

  Future<void> _editDraft(int index) async {
    final edited = await showDialog<PlannerTask>(
      context: context,
      builder: (context) => AddTaskDialog(original: drafts[index]),
    );
    if (!mounted || edited == null) return;
    setState(() => drafts[index] = edited);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('确认今日计划'),
      content: SizedBox(
        width: 560,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('这是草稿，确认前可以编辑或删除时间段。'),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: drafts.length,
              itemBuilder: (context, index) {
                final draft = drafts[index];
                return ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text(draft.title),
                  subtitle: Text(_formatDraftTime(draft)),
                  trailing: Wrap(children: [
                    IconButton(
                      tooltip: '编辑草稿',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editDraft(index),
                    ),
                    IconButton(
                      tooltip: '删除草稿',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => drafts.removeAt(index)),
                    ),
                  ]),
                );
              },
            ),
          ),
          if (hasOverlap)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('时间段存在重叠，请先编辑后再确认。',
                    style: TextStyle(color: Colors.red)),
              ),
            ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: drafts.isEmpty || hasOverlap
              ? null
              : () => Navigator.pop(context, [...drafts]),
          child: const Text('确认加入今日计划'),
        ),
      ],
    );
  }

  String _formatDraftTime(PlannerTask task) {
    final start = task.startAt.toLocal();
    final end = task.endAt.toLocal();
    String clock(DateTime value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '${clock(start)} - ${clock(end)}';
  }
}

class _TodayView extends StatelessWidget {
  const _TodayView(
      {required this.tasks,
      required this.isWide,
      required this.onToggle,
      required this.onAdd,
      required this.onEdit,
      required this.onDelete,
      required this.onMarkTodayIncomplete,
      required this.courseRemindersEnabled,
      required this.onCourseRemindersChanged,
      required this.onImportCourses,
      required this.onImportCourseScreenshot,
      required this.onGeneratePlan});

  final List<PlannerTask> tasks;
  final bool isWide;
  final ValueChanged<PlannerTask> onToggle;
  final VoidCallback onAdd;
  final ValueChanged<PlannerTask> onEdit;
  final ValueChanged<PlannerTask> onDelete;
  final ValueChanged<PlannerTask> onMarkTodayIncomplete;
  final bool courseRemindersEnabled;
  final ValueChanged<bool> onCourseRemindersChanged;
  final VoidCallback onImportCourses;
  final VoidCallback onImportCourseScreenshot;
  final VoidCallback onGeneratePlan;

  @override
  Widget build(BuildContext context) {
    final completed = tasks.where((task) => task.isCompleted).length;
    final now = DateTime.now();
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(isWide ? 42 : 24, 28, 24, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      '${weekdays[now.weekday - 1]}，${now.month} 月 ${now.day} 日',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: Colors.black54)),
                  const SizedBox(height: 6),
                  Text('把今天安排好',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ])),
            PopupMenuButton<String>(
              tooltip: '今日操作',
              onSelected: (value) {
                if (value == 'add') onAdd();
                if (value == 'import') onImportCourses();
                if (value == 'screenshot') onImportCourseScreenshot();
                if (value == 'plan') onGeneratePlan();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'add', child: Text('添加安排')),
                PopupMenuItem(value: 'screenshot', child: Text('从课表截图导入')),
                PopupMenuItem(value: 'import', child: Text('导入课表识别结果')),
                PopupMenuItem(value: 'plan', child: Text('生成今日计划')),
              ],
              icon: const Icon(Icons.add_circle_outline, size: 30),
            ),
          ]),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(
                child:
                    _ProgressPanel(completed: completed, total: tasks.length)),
            if (isWide) ...[
              const SizedBox(width: 16),
              Expanded(child: _FocusPanel(tasks: tasks))
            ],
          ]),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              key: const Key('course-reminders-switch'),
              value: courseRemindersEnabled,
              onChanged: onCourseRemindersChanged,
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('课程提醒'),
              subtitle: const Text('课程默认提前 5 分钟显示在系统通知中'),
            ),
          ),
          const SizedBox(height: 30),
          Text('今日时间轴',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            const _EmptyTodayState()
          else
            ...tasks.map((task) => _TaskTile(
                  task: task,
                  onToggle: () => onToggle(task),
                  onEdit: () => onEdit(task),
                  onDelete: () => onDelete(task),
                  onMarkTodayIncomplete: () => onMarkTodayIncomplete(task),
                )),
        ]),
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color(0xffdff3ed),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
                value: value,
                strokeWidth: 6,
                backgroundColor: Colors.white,
                color: const Color(0xff157a6e))),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$completed / $total 完成',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('保持专注，逐项推进',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.black54)),
        ])),
      ]),
    );
  }
}

class _FocusPanel extends StatelessWidget {
  const _FocusPanel({required this.tasks});

  final List<PlannerTask> tasks;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final upcoming = tasks
        .where((task) =>
            task.status == TaskStatus.planned && task.startAt.isAfter(now))
        .firstOrNull;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.notifications_none, color: Color(0xff157a6e)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(
                upcoming == null
                    ? '今天没有待开始的提醒'
                    : '下一项\n${_clockInZone(upcoming.startAt, upcoming.timeZoneId)} ${upcoming.title}',
                style: const TextStyle(height: 1.5))),
      ]),
    );
  }

  String _clockInZone(DateTime utcValue, String timeZoneId) {
    try {
      final local =
          tz.TZDateTime.from(utcValue.toUtc(), tz.getLocation(timeZoneId));
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    } on Exception {
      final local = utcValue.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onMarkTodayIncomplete,
  });

  final PlannerTask task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMarkTodayIncomplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading:
              Checkbox(value: task.isCompleted, onChanged: (_) => onToggle()),
          title: Text(task.title,
              style: TextStyle(
                  decoration:
                      task.isCompleted ? TextDecoration.lineThrough : null,
                  color: task.isCompleted
                      ? Colors.black45
                      : task.status == TaskStatus.todayIncomplete
                          ? const Color(0xffa85f00)
                          : null)),
          subtitle: Text(_subtitle()),
          trailing: PopupMenuButton<_TaskAction>(
            tooltip: '更多操作',
            onSelected: (action) {
              switch (action) {
                case _TaskAction.edit:
                  onEdit();
                case _TaskAction.incomplete:
                  onMarkTodayIncomplete();
                case _TaskAction.delete:
                  onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: _TaskAction.edit, child: Text('编辑')),
              if (task.status == TaskStatus.planned)
                const PopupMenuItem(
                    value: _TaskAction.incomplete, child: Text('标记为今日未完成')),
              const PopupMenuItem(value: _TaskAction.delete, child: Text('删除')),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    final kind = switch (task.kind) {
      ScheduleItemKind.course => '课程',
      ScheduleItemKind.task => '学习任务',
      ScheduleItemKind.timeBlock => '时间段',
    };
    final time =
        '${_clockInTimeZone(task.startAt, task.timeZoneId)} - ${_clockInTimeZone(task.endAt, task.timeZoneId)}';
    final location = task.location.trim();
    final status = task.status == TaskStatus.todayIncomplete ? ' · 今日未完成' : '';
    return '$kind · $time${location.isEmpty ? '' : ' · $location'}$status';
  }

  String _clockInTimeZone(DateTime utcValue, String timeZoneId) {
    try {
      final location = tz.getLocation(timeZoneId);
      return _clock(tz.TZDateTime.from(utcValue.toUtc(), location));
    } on Exception {
      return _clock(utcValue.toLocal());
    }
  }

  String _clock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

enum _TaskAction { edit, incomplete, delete }

class _EmptyTodayState extends StatelessWidget {
  const _EmptyTodayState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: const Column(
        children: [
          Icon(Icons.event_available, size: 46, color: Colors.black38),
          SizedBox(height: 10),
          Text('今天还没有安排'),
          SizedBox(height: 4),
          Text('点击右上角加号创建课程、学习任务或时间段。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _NewsView extends StatefulWidget {
  const _NewsView({required this.isWide, this.client, this.apiClient});

  final bool isWide;
  final GitHubDigestClient? client;
  final FocusFlowClient? apiClient;

  @override
  State<_NewsView> createState() => _NewsViewState();
}

class _NewsViewState extends State<_NewsView> {
  late Future<List<NewsItem>>? future = _fetch();

  Future<List<NewsItem>>? _fetch() =>
      widget.apiClient?.fetchDailyNews() ?? widget.client?.fetch();

  void _refresh() {
    if (widget.apiClient == null && widget.client == null) return;
    setState(() => future = _fetch());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.apiClient != null || widget.client != null) {
      return FutureBuilder<List<NewsItem>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return _digestError(context);
          final items = snapshot.data ?? const <NewsItem>[];
          if (items.isEmpty) return _digestEmpty(context);
          return _digestList(context, items.take(50).toList(growable: false));
        },
      );
    }
    return _digestEmpty(context);
  }

  Widget _digestList(BuildContext context, List<NewsItem> items) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(widget.isWide ? 42 : 24, 28, 24, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('每日资讯',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            if (widget.apiClient != null || widget.client != null)
              IconButton(
                tooltip: '刷新资讯',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
          ]),
          const SizedBox(height: 6),
          Text('${items.length} 条精选项目动态',
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 24),
          ...items.map((item) => _NewsItem(
              title: item.title,
              repo: item.repositoryFullName,
              meta: '★ ${item.stars}',
              url: item.sourceUrl,
              summary: item.summary)),
        ]),
      ),
    );
  }

  Widget _digestError(BuildContext context) =>
      _digestMessage('资讯暂时不可用，稍后重试。', Icons.cloud_off);
  Widget _digestEmpty(BuildContext context) =>
      _digestMessage('暂无可用资讯。', Icons.inbox_outlined);
  Widget _digestMessage(String message, IconData icon) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 36),
        const SizedBox(height: 12),
        Text(message)
      ]));
}

class _NewsItem extends StatelessWidget {
  const _NewsItem(
      {required this.title,
      required this.repo,
      required this.meta,
      required this.url,
      this.summary = ''});

  final String title;
  final String repo;
  final String meta;
  final String url;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.auto_awesome, color: Color(0xff157a6e)),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(repo, style: const TextStyle(color: Color(0xff157a6e))),
          const SizedBox(height: 6),
          if (summary.isNotEmpty)
            Text(summary, maxLines: 3, overflow: TextOverflow.ellipsis),
          if (summary.isNotEmpty) const SizedBox(height: 6),
          Text(meta, style: const TextStyle(color: Colors.black54)),
        ])),
        IconButton(
            tooltip: 'GitHub 链接',
            onPressed: () {},
            icon: const Icon(Icons.open_in_new, size: 20)),
      ]),
    );
  }
}

class _KnowledgeView extends StatefulWidget {
  const _KnowledgeView(
      {required this.notes,
      required this.isWide,
      required this.onAdd,
      required this.onEdit});

  final List<KnowledgeNote> notes;
  final bool isWide;
  final VoidCallback onAdd;
  final ValueChanged<KnowledgeNote> onEdit;

  @override
  State<_KnowledgeView> createState() => _KnowledgeViewState();
}

class _KnowledgeViewState extends State<_KnowledgeView> {
  final searchController = TextEditingController();
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final visibleNotes = widget.notes.where((note) {
      if (normalizedQuery.isEmpty) return true;
      return note.title.toLowerCase().contains(normalizedQuery) ||
          note.preview.toLowerCase().contains(normalizedQuery);
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(widget.isWide ? 42 : 24, 28, 24, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('知识库',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            IconButton(
                tooltip: '新建笔记',
                onPressed: widget.onAdd,
                icon: const Icon(Icons.note_add_outlined, size: 28)),
          ]),
          const SizedBox(height: 20),
          TextField(
            controller: searchController,
            onChanged: (value) => setState(() => query = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜索笔记',
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清除搜索',
                      onPressed: () {
                        searchController.clear();
                        setState(() => query = '');
                      },
                      icon: const Icon(Icons.close)),
            ),
          ),
          const SizedBox(height: 18),
          if (visibleNotes.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                    child: Text('没有找到相关笔记',
                        style: TextStyle(color: Colors.black54))))
          else
            ...visibleNotes.map((note) => ListTile(
                onTap: () => widget.onEdit(note),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                leading: const Icon(Icons.description_outlined),
                title: Text(note.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(note.preview,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Text(_updatedLabel(note.updatedAt),
                    style: const TextStyle(color: Colors.black45)))),
        ]),
      ),
    );
  }

  String _updatedLabel(DateTime value) {
    final now = DateTime.now();
    if (value.year == now.year &&
        value.month == now.month &&
        value.day == now.day) {
      return '今天';
    }
    return '${value.month}/${value.day}';
  }
}
