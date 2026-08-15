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
import 'domain/news_item.dart';
import 'domain/planner_task.dart';
import 'services/flutter_notification_scheduler.dart';
import 'services/github_digest_client.dart';
import 'services/notification_scheduler.dart';
import 'services/app_config.dart';
import 'services/auth_controller.dart';
import 'services/auth_session_store.dart';
import 'services/device_token_registrar.dart';
import 'services/deep_link_handler.dart';
import 'services/supabase_rest_client.dart';
import 'services/sync_engine.dart';
import 'ui/account_page.dart';
import 'ui/add_task_dialog.dart';
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
  final cloudClient = config.hasSupabase
      ? SupabaseRestClient(
          url: config.supabaseUrl!, anonKey: config.supabaseAnonKey!)
      : null;
  final authController = cloudClient == null
      ? null
      : AuthController(
          client: cloudClient,
          store: Platform.isWindows
              ? InMemoryAuthSessionStore()
              : SecureAuthSessionStore());
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
      this.database});

  final TaskRepository? repository;
  final NoteRepository? noteRepository;
  final GitHubDigestClient? newsClient;
  final AuthController? authController;
  final SupabaseRestClient? cloudClient;
  final NotificationScheduler? scheduler;
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
      this.database});

  final TaskRepository? repository;
  final NoteRepository? noteRepository;
  final GitHubDigestClient? newsClient;
  final AuthController? authController;
  final SupabaseRestClient? cloudClient;
  final NotificationScheduler? scheduler;
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
  final tasks = <PlannerTask>[];
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
    setState(() => selectedIndex = 1);
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
      await scheduler.rescheduleAll(loaded.where((task) => !task.isCompleted));
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
        supabase: client!,
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
        return _NewsView(isWide: isWide, client: widget.newsClient);
      case 2:
        return _KnowledgeView(
            notes: notes, isWide: isWide, onAdd: _addNote, onEdit: _editNote);
      case 3:
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
          tasks: tasks,
          isWide: isWide,
          onToggle: _toggleTask,
          onAdd: _addTask,
        );
    }
  }

  Future<void> _addTask() async {
    final task = await showDialog<PlannerTask>(
        context: context, builder: (context) => const AddTaskDialog());
    if (!mounted || task == null) return;
    setState(() => tasks.add(task));
    await repository.saveTask(task);
    await scheduler.schedule(task);
  }

  Future<void> _toggleTask(PlannerTask task) async {
    final index = tasks.indexWhere((candidate) => candidate.id == task.id);
    if (index < 0) return;
    final updated = task.copyWith(isCompleted: !task.isCompleted);
    setState(() => tasks[index] = updated);
    await repository.saveTask(updated);
    if (updated.isCompleted) {
      await scheduler.cancel(updated.id);
    } else {
      await scheduler.schedule(updated);
    }
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

class _TodayView extends StatelessWidget {
  const _TodayView(
      {required this.tasks,
      required this.isWide,
      required this.onToggle,
      required this.onAdd});

  final List<PlannerTask> tasks;
  final bool isWide;
  final ValueChanged<PlannerTask> onToggle;
  final VoidCallback onAdd;

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
            IconButton(
                tooltip: '添加任务',
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle_outline, size: 30)),
          ]),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(
                child:
                    _ProgressPanel(completed: completed, total: tasks.length)),
            if (isWide) ...[
              const SizedBox(width: 16),
              const Expanded(child: _FocusPanel())
            ],
          ]),
          const SizedBox(height: 30),
          Text('今日时间轴',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...tasks.map(
              (task) => _TaskTile(task: task, onToggle: () => onToggle(task))),
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
  const _FocusPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: const Row(children: [
        Icon(Icons.notifications_none, color: Color(0xff157a6e)),
        SizedBox(width: 12),
        Expanded(
            child:
                Text('下一条提醒\n09:00 深度工作：产品规格', style: TextStyle(height: 1.5))),
      ]),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onToggle});

  final PlannerTask task;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onToggle,
          leading:
              Checkbox(value: task.isCompleted, onChanged: (_) => onToggle()),
          title: Text(task.title,
              style: TextStyle(
                  decoration:
                      task.isCompleted ? TextDecoration.lineThrough : null,
                  color: task.isCompleted ? Colors.black45 : null)),
          subtitle: Text(
              '${_clockInTimeZone(task.startAt, task.timeZoneId)} - ${_clockInTimeZone(task.endAt, task.timeZoneId)}'),
          trailing: const Icon(Icons.drag_handle, color: Colors.black26),
        ),
      ),
    );
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

class _NewsView extends StatefulWidget {
  const _NewsView({required this.isWide, this.client});

  final bool isWide;
  final GitHubDigestClient? client;

  @override
  State<_NewsView> createState() => _NewsViewState();
}

class _NewsViewState extends State<_NewsView> {
  late Future<List<NewsItem>>? future = widget.client?.fetch();

  @override
  Widget build(BuildContext context) {
    if (widget.client != null) {
      return FutureBuilder<List<NewsItem>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return _digestError(context);
          final items = snapshot.data ?? const <NewsItem>[];
          if (items.isEmpty) return _digestEmpty(context);
          return _digestList(context, items);
        },
      );
    }
    return _digestList(context, const [
      NewsItem(
          repositoryFullName: 'open-source/agent-patterns',
          title: '以更低成本构建可靠的 Agent 工作流',
          summary: '',
          sourceUrl: 'https://github.com/open-source/agent-patterns',
          tags: ['agent'],
          stars: 2400,
          forks: 0,
          score: 0),
      NewsItem(
          repositoryFullName: 'community/local-models',
          title: '本周值得关注的本地模型工具',
          summary: '',
          sourceUrl: 'https://github.com/community/local-models',
          tags: ['llm'],
          stars: 1800,
          forks: 0,
          score: 0),
    ]);
  }

  Widget _digestList(BuildContext context, List<NewsItem> items) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(widget.isWide ? 42 : 24, 28, 24, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AI 资讯',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('每日从 GitHub 精选项目动态',
              style: TextStyle(color: Colors.black54)),
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
