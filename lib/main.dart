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
import 'services/supabase_rest_client.dart';
import 'services/sync_engine.dart';
import 'services/deep_link_handler.dart';
import 'ui/account_page.dart';
import 'ui/add_task_dialog.dart';
import 'ui/window_class.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();
  final AppDatabase? database =
      (Platform.isAndroid || Platform.isIOS || Platform.isWindows) ? await openAppDatabase() : null;
  final NotificationScheduler scheduler = Platform.isAndroid || Platform.isIOS
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
          timeZoneId: 'Asia/Tokyo',
          reminderMinutes: 15),
      PlannerTask(
          id: 'task-2',
          title: 'Walk break',
          startAt: _todayAt(12, 30).toUtc(),
          endAt: _todayAt(13).toUtc(),
          timeZoneId: 'Asia/Tokyo'),
      PlannerTask(
          id: 'task-3',
          title: 'Review notes',
          startAt: _todayAt(18).toUtc(),
          endAt: _todayAt(18, 30).toUtc(),
          timeZoneId: 'Asia/Tokyo'),
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

  void _setupFirebaseMessaging() {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      final messaging = FirebaseMessaging.instance;
      _fcmForegroundSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      messaging.getInitialMessage().then((message) {
        if (message != null) _handleNotificationTap(message);
      });
      if (Platform.isIOS) {
        messaging.requestPermission(alert: true, badge: true, sound: true, provisional: false);
      }
    } on Object {}
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    if (data['deep_link'] is String) _deepLinkHandler.handleUri(data['deep_link'] as String);
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    if (data['deep_link'] is String) _deepLinkHandler.handleUri(data['deep_link'] as String);
  }

  void _navigateDeepLink(DeepLinkEvent event) {
    if (!mounted) return;
    if (event.route == DeepLinkRoute.newsDaily) setState(() => selectedIndex = 1);
  }

  Future<DeviceTokenSource> _detectPushSource() async {
    if (Platform.isAndroid) {
      try {
        final hasGms = await FirebaseMessaging.instance.getToken().then((_) => true).catchError((_) => false);
        if (!hasGms) return HuaweiDeviceTokenSource();
      } on Object { return HuaweiDeviceTokenSource(); }
    }
    return FirebaseDeviceTokenSource();
  }

  Future<void> _importGuestData() async {
    final currentOwner = widget.authController?.session?.userId;
    if (currentOwner == null) return;
    final origOwner = repository.ownerUserId;
    try {
      repository.setOwner(null);
      noteRepository.setOwner(null);
      final guestTasks = await repository.loadTasks(includeDeleted: false);
      final guestNotes = await noteRepository.loadNotes(includeDeleted: false);
      repository.setOwner(currentOwner);
      noteRepository.setOwner(currentOwner);
      for (final task in guestTasks) { await repository.saveTask(task); }
      for (final note in guestNotes) { await noteRepository.saveNote(note); }
      await _loadData(generation: _authGeneration);
      _guestTaskCount = 0;
      _guestNoteCount = 0;
      if (mounted) setState(() {});
    } on Object {
      repository.setOwner(origOwner);
      noteRepository.setOwner(origOwner);
      rethrow;
    }
  }

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

class _FocusFlowShellState extends State<FocusFlowShell> with WidgetsBindingObserver {
  int selectedIndex = 0;
  late final TaskRepository repository = widget.repository ??
      InMemoryTaskRepository(seed: [
        PlannerTask(
            id: 'task-1',
            title: '濞ｅ崬瀹冲銉ょ稊閿涙矮楠囬崫浣筋潐閺?,
            startAt: _todayAt(9).toUtc(),
            endAt: _todayAt(10, 30).toUtc(),
            timeZoneId: 'Asia/Tokyo',
            reminderMinutes: 15),
        PlannerTask(
            id: 'task-2',
            title: '閸楀牓妫块弫锝嗩劄',
            startAt: _todayAt(12, 30).toUtc(),
            endAt: _todayAt(13).toUtc(),
            timeZoneId: 'Asia/Tokyo'),
        PlannerTask(
            id: 'task-3',
            title: '閺佸鎮婃禒濠冩）缁楁棁顔?,
            startAt: _todayAt(18).toUtc(),
            endAt: _todayAt(18, 30).toUtc(),
            timeZoneId: 'Asia/Tokyo'),
      ]);
  late final NoteRepository noteRepository = widget.noteRepository ??
      InMemoryNoteRepository(seed: [
        KnowledgeNote(
            id: 'note-1',
            title: '閹跺﹤顦查弶鍌炴６妫版ɑ濯堕幋鎰讲妤犲矁鐦夐惃鍕海鐠?,
            bodyMarkdown: '娴犲﹤銇夐崷銊啎鐠伮ょカ鐠侇垵浠涢崥鍫熸閿涘苯鍘涚€规矮绠熼悜顓犲仯閿涘苯鍟€闁瀚ㄩ弫鐗堝祦濠ф劑鈧?,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now()),
        KnowledgeNote(
            id: 'note-2',
            title: '闂冨懓顕扮拋鏉跨秿閿涙gent 瀹搞儰缍斿ù?,
            bodyMarkdown: '瀹搞儱鍙跨拫鍐暏閻ㄥ嫯绔熼悾灞藉枀鐎规矮绨＄化鑽ょ埠閻ㄥ嫬褰查棃鐘斥偓褋鈧?,
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
    if (widget.authController?.status == AuthStatus.signedIn) {
    _setupDeepLinks();
    _setupFirebaseMessaging();
    unawaited(_ensureTokenRegistration(_authGeneration));
    }
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
                    label: '娴犲﹥妫?),
                NavigationDestination(
                    icon: Icon(Icons.auto_awesome_outlined),
                    selectedIcon: Icon(Icons.auto_awesome),
                    label: 'AI 鐠у嫯顔?),
                NavigationDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book),
                    label: '閻儴鐦戞惔?),
                NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: '鐠愶箑褰?),
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
                        label: Text('娴犲﹥妫?)),
                    NavigationRailDestination(
                        icon: Icon(Icons.auto_awesome_outlined),
                        selectedIcon: Icon(Icons.auto_awesome),
                        label: Text('AI 鐠у嫯顔?)),
                    NavigationRailDestination(
                        icon: Icon(Icons.menu_book_outlined),
                        selectedIcon: Icon(Icons.menu_book),
                        label: Text('閻儴鐦戞惔?)),
                    NavigationRailDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: Text('鐠愶箑褰?)),
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
                onCountGuestData: () async => GuestDataCount(taskCount: _guestTaskCount, noteCount: _guestNoteCount),
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
    if (client == null || client.session == null || _isSyncing) return;
    _isSyncing = true;
    try {
      final generation = _authGeneration;
      final report = await SyncEngine(
              client: client, tasks: repository, notes: noteRepository)
          .sync();
      
      return SyncReport(
          pulled: report.pulled,
          pushed: report.pushed,
          conflicts: report.conflicts);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Sync failed: ')));
      }
      return const SyncReport(pulled: 0, pushed: 0, conflicts: 0);
    } finally {
      _isSyncing = false;
    }
  }}

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
          child: Text('娴滄垵鎮撳銉ョ毣閺堫亪鍘ょ純顔衡偓鍌濐嚞閸︺劍鐎鐑樻閹绘劒绶?SUPABASE_URL 閸?SUPABASE_ANON_KEY閵?,
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
    WidgetsBinding.instance.addObserver(this);
    titleController = TextEditingController(text: widget.original?.title);
    bodyController = TextEditingController(text: widget.original?.bodyMarkdown);
  }

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkHandler.dispose();
    _deepLinkSub?.cancel();
    _fcmForegroundSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.original == null ? '閺傛澘缂撶粭鏃囶唶' : '缂傛牞绶粭鏃囶唶'),
      content: SizedBox(
        width: 480,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              key: const Key('note-title-field'),
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(labelText: '閺嶅洭顣?)),
          const SizedBox(height: 12),
          TextField(
              key: const Key('note-body-field'),
              controller: bodyController,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(labelText: '閸愬懎顔?)),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('閸欐牗绉?)),
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
          child: const Text('娣囨繂鐡?),
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
    const weekdays = ['閸涖劋绔?, '閸涖劋绨?, '閸涖劋绗?, '閸涖劌娲?, '閸涖劋绨?, '閸涖劌鍙?, '閸涖劍妫?];
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
                      '${weekdays[now.weekday - 1]}閿?{now.month} 閺?${now.day} 閺?,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: Colors.black54)),
                  const SizedBox(height: 6),
                  Text('閹跺﹣绮栨径鈺佺暔閹烘帒銈?,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ])),
            IconButton(
                tooltip: '濞ｈ濮炴禒璇插',
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
          Text('娴犲﹥妫╅弮鍫曟？鏉?,
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
          Text('$completed / $total 鐎瑰本鍨?,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('娣囨繃瀵旀稉鎾存暈閿涘矂鈧劙銆嶉幒銊ㄧ箻',
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
                Text('娑撳绔撮弶鈩冨絹闁辨妰n09:00 濞ｅ崬瀹冲銉ょ稊閿涙矮楠囬崫浣筋潐閺?, style: TextStyle(height: 1.5))),
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
          title: '娴犮儲娲挎担搴㈠灇閺堫剚鐎鍝勫讲闂堢姷娈?Agent 瀹搞儰缍斿ù?,
          summary: '',
          sourceUrl: 'https://github.com/open-source/agent-patterns',
          tags: ['agent'],
          stars: 2400,
          forks: 0,
          score: 0),
      NewsItem(
          repositoryFullName: 'community/local-models',
          title: '閺堫剙鎳嗛崐鐓庣繁閸忚櫕鏁為惃鍕拱閸︾増膩閸ㄥ浼愰崗?,
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
          Text('AI 鐠у嫯顔?,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('濮ｅ繑妫╂禒?GitHub 缁箖鈧銆嶉惄顔煎З閹?,
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 24),
          ...items.map((item) => _NewsItem(
              title: item.title,
              repo: item.repositoryFullName,
              meta: '閳?${item.stars}',
              url: item.sourceUrl,
              summary: item.summary)),
        ]),
      ),
    );
  }

  Widget _digestError(BuildContext context) =>
      _digestMessage('鐠у嫯顔嗛弳鍌涙娑撳秴褰查悽顭掔礉缁嬪秴鎮楅柌宥堢槸閵?, Icons.cloud_off);
  Widget _digestEmpty(BuildContext context) =>
      _digestMessage('閺嗗倹妫ら崣顖滄暏鐠у嫯顔嗛妴?, Icons.inbox_outlined);
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
            tooltip: 'GitHub 闁剧偓甯?,
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
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkHandler.dispose();
    _deepLinkSub?.cancel();
    _fcmForegroundSub?.cancel();
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
            Text('閻儴鐦戞惔?,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            IconButton(
                tooltip: '閺傛澘缂撶粭鏃囶唶',
                onPressed: widget.onAdd,
                icon: const Icon(Icons.note_add_outlined, size: 28)),
          ]),
          const SizedBox(height: 20),
          TextField(
            controller: searchController,
            onChanged: (value) => setState(() => query = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '閹兼粎鍌ㄧ粭鏃囶唶',
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '濞撳懘娅庨幖婊呭偍',
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
                    child: Text('濞屸剝婀侀幍鎯у煂閻╃鍙х粭鏃囶唶',
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
      return '娴犲﹤銇?;
    }
    return '${value.month}/${value.day}';
  }
}
