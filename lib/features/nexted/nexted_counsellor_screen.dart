import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:url_launcher/url_launcher.dart';

import '../../app/data/demo.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/api_client.dart';
import '../../app/services/nexted_api.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/mascot.dart';
import '../../app/widgets/motion.dart';
import 'widgets.dart';

/// nexted.app · AI Counsellor.
///
/// Chat that already knows the student's profile. The answer follows the
/// CMS-style formatting contract - clean `#` and `##` headings, short
/// paragraphs, plain bullets - rendered by [NextedAnswer]. Every message is
/// an AI action, so it counts against the daily cap the backend enforces.
class NextedCounsellorScreen extends StatefulWidget {
  const NextedCounsellorScreen({super.key});

  @override
  State<NextedCounsellorScreen> createState() => _NextedCounsellorScreenState();
}

class _NextedCounsellorScreenState extends State<NextedCounsellorScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  /// Keep the newest words in view while the answer is typed out. Turned off
  /// when the student scrolls up to read something, back on when they return
  /// to the bottom or send the next message.
  bool _follow = true;
  final List<_Msg> _messages = <_Msg>[];
  bool _sending = false;

  /// "The AI counsellor can make mistakes…" - sent by the AI service.
  String _disclaimer = '';

  /// Openers a student can tap instead of typing the first question.
  static const List<String> _starters = <String>[
    'Which countries suit my profile?',
    'What do I need for a UK student visa?',
    'How much will my first year cost?',
    'Is my IELTS band good enough?',
  ];

  /// The saved conversation is being fetched (the starters wait for it).
  bool _loadingThread = true;

  @override
  void initState() {
    super.initState();
    NextedUsage.I.refresh();
    _loadThread();
  }

  /// The conversation so far, from the server: it is kept per student, so it
  /// is still here after the app restarts and on the student's other devices.
  Future<void> _loadThread() async {
    if (!NextedApi.ready) {
      setState(() => _loadingThread = false);
      return;
    }
    try {
      final r = await NextedApi.get(NextedConfig.counsellorThread);
      if (!mounted) return;
      final saved = <_Msg>[
        for (final m in r.l('messages'))
          if (m.s('content').trim().isNotEmpty)
            _Msg(
              fromStudent: m.s('role') == 'student',
              text: m.s('content'),
              office: m.m('meta').m('office'),
              actions: m.m('meta').l('actions'),
            ),
      ];
      setState(() {
        // Anything typed while it was loading stays after the saved part.
        _messages.insertAll(0, saved);
        _loadingThread = false;
      });
      _jumpToBottom();
    } on ApiException {
      // An older server without saved chats, or offline: start empty.
      if (mounted) setState(() => _loadingThread = false);
    }
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  /// Clear the conversation (on the server too) and start again.
  Future<void> _newChat() async {
    if (_sending || _messages.isEmpty) return;
    final ok = await showAppDialog<bool>(
      context,
      Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            const Text('Start a new chat?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
            Text(
              'This conversation will be cleared. Your profile and documents stay as they are.',
              style: TextStyle(fontSize: 14, height: 1.45, color: ctx.tk.textMuted),
            ),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: OutlineButtonX(label: 'Cancel', height: 48, onTap: () => Navigator.of(ctx).pop(false)),
                ),
                Expanded(
                  child: PrimaryButton(label: 'New chat', height: 48, onTap: () => Navigator.of(ctx).pop(true)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await NextedApi.request('DELETE', NextedConfig.counsellorThread);
      if (!mounted) return;
      setState(_messages.clear);
    } on ApiException catch (e) {
      if (mounted) context.toast(e.message);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// While typing: keep the newest words in view, without animating every
  /// piece (that would stutter). Only follows if the student hasn't scrolled up.
  void _followTyping() {
    if (!_follow) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_follow || !_scroll.hasClients) return;
      final pos = _scroll.position;
      if (pos.pixels < pos.maxScrollExtent) pos.jumpTo(pos.maxScrollExtent);
    });
  }

  /// Scrolling up by hand stops the follow; coming back to the bottom
  /// starts it again.
  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is UserScrollNotification && n.direction == ScrollDirection.forward) {
      _follow = false;
    } else if (n is ScrollEndNotification && n.metrics.extentAfter < 60) {
      _follow = true;
    }
    return false;
  }

  void _toBottom() {
    if (!_follow) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    if (!NextedApi.ready) {
      context.toast('Connect the study-abroad server to use the AI counsellor.');
      return;
    }
    if (NextedUsage.I.exhausted) {
      context.toast(NextedUsage.limitMessage);
      return;
    }

    setState(() {
      _messages.add(_Msg(fromStudent: true, text: text));
      _input.clear();
      _sending = true;
    });
    // A new question: follow the answer again, wherever the page was.
    _follow = true;
    _toBottom();

    try {
      // The conversation before this message (the new one travels as
      // `message`, so it must not be in the history a second time).
      final earlier = _messages.sublist(0, _messages.length - 1).where((m) => !m.failed);
      final body = <String, dynamic>{
        'message': text,
        'history': <Map<String, dynamic>>[
          for (final m in earlier)
            <String, dynamic>{'role': m.fromStudent ? 'student' : 'counsellor', 'content': m.text},
        ],
      };

      // The answer is typed out as the model writes it (like ChatGPT): the
      // bubble appears with the first words and grows piece by piece.
      _Msg? live;
      Map<String, dynamic> r;
      try {
        r = await NextedApi.stream(
          NextedConfig.counsellorStream,
          body,
          onToken: (piece) {
            if (!mounted) return;
            setState(() {
              if (live == null) {
                live = _Msg(fromStudent: false, text: '', typing: true);
                _messages.add(live!);
              }
              live!.text += piece;
            });
            _followTyping();
          },
        );
      } on ApiException catch (e) {
        // An API server from before streaming: ask the ordinary way.
        if (e.status != 404 || live != null) rethrow;
        r = await NextedApi.post(NextedConfig.counsellor, body);
      }

      NextedUsage.I.apply(r);
      // The server's figure already includes this call; count locally only without one.
      if (r['usage'] is! Map) NextedUsage.I.countOne();
      if (!mounted) return;
      final reply = r.s('reply').isNotEmpty ? r.s('reply') : r.s('message');
      setState(() {
        final finalText = reply.isNotEmpty ? reply : (live?.text.trim() ?? '');
        final done = live ?? _Msg(fromStudent: false, text: '');
        done
          // The final text is the checked one (restrictions, invitation).
          ..text = finalText.isEmpty ? 'No answer came back.' : finalText
          ..typing = false
          // Fees, documents and anything the office must answer come with
          // the office's contact details.
          ..office = r.m('office')
          // Buttons the answer offers: Course matching, Scholarship finder...
          ..actions = r.l('actions');
        if (live == null) _messages.add(done);
        if (r.s('disclaimer').isNotEmpty) _disclaimer = r.s('disclaimer');
        _sending = false;
      });
      _toBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        // A reply that broke off part way stays, marked as cut short.
        for (final m in _messages) {
          if (m.typing) {
            m.typing = false;
            if (m.text.trim().isNotEmpty) m.text = '${m.text.trimRight()}\n\n(The answer was cut short.)';
          }
        }
        _messages.removeWhere((m) => !m.fromStudent && m.text.trim().isEmpty);
        _messages.add(_Msg(
          fromStudent: false,
          failed: true,
          text: NextedUsage.isLimit(e) ? NextedUsage.limitMessage : e.message,
        ));
        _sending = false;
      });
      if (NextedUsage.isLimit(e)) NextedUsage.I.refresh();
      _toBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: AppScreen(
      controller: _scroll,
      gap: 12,
      footer: Row(
        spacing: 10,
        children: [
          Expanded(
            child: AppTextField(
              hint: 'Ask your counsellor anything',
              controller: _input,
              maxLines: 1,
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconBox(
            icon: AppIcons.send,
            tooltip: 'Send',
            size: 56,
            radius: 20,
            iconSize: 20,
            onTap: _sending || _input.text.trim().isEmpty ? null : () => _send(),
          ),
        ],
      ),
      children: [
        TopBar(
          title: 'AI Counsellor',
          subtitle: 'Knows your profile',
          onBack: () => context.back(),
          actions: <Widget>[
            if (_messages.isNotEmpty)
              IconBox(
                icon: AppIcons.add,
                tooltip: 'New chat',
                onTap: _sending ? null : _newChat,
              ),
          ],
        ),

        if (!NextedConfig.hasApi) const NextedOfflineNotice(),
        const NextedQuotaBar(),

        if (_loadingThread && _messages.isEmpty)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_messages.isEmpty) ...[
          AppCard(
            radius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                const FloatY(amplitude: 3, child: Nexy(NexyPose.speaking, height: 84)),
                const Text(
                  'Ask about courses, countries, costs or visas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Text(
                  'Your profile is already with the counsellor, so answers are about '
                  'your own band, result and plans - no need to repeat them.',
                  style: TextStyle(fontSize: 13, height: 1.45, color: t.textMuted),
                ),
              ],
            ),
          ),
          SectionTitle('Start with', fontSize: 15),
          for (final s in _starters)
            AppCard(
              radius: 18,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              onTap: _sending ? null : () => _send(s),
              child: Row(
                spacing: 10,
                children: [
                  Icon(AppIcons.bulb, size: 17, color: t.textMuted),
                  Expanded(child: Text(s, style: const TextStyle(fontSize: 13.5))),
                ],
              ),
            ),
        ],

        for (final m in _messages) ...[
          _Bubble(message: m),
          if (m.actions.isNotEmpty) _ActionButtons(actions: m.actions),
          if (m.office.isNotEmpty) _OfficeCard(office: m.office),
        ],

        // "Thinking…" only until the first words arrive; then the bubble types.
        if (_sending && !_messages.any((m) => m.typing))
          Align(
            alignment: Alignment.centerLeft,
            child: AppCard(
              radius: 20,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 10,
                children: [
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  Text('Thinking…', style: TextStyle(fontSize: 13, color: t.textMuted)),
                ],
              ),
            ),
          ),

        if (_disclaimer.isNotEmpty && _messages.isNotEmpty)
          Text(
            _disclaimer,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, height: 1.4, color: t.textMuted),
          ),
      ],
      ),
    );
  }
}

class _Msg {
  _Msg({
    required this.fromStudent,
    required this.text,
    this.failed = false,
    this.typing = false,
    this.office = const <String, dynamic>{},
    this.actions = const <Map<String, dynamic>>[],
  });

  final bool fromStudent;
  String text;
  final bool failed;

  /// Still being written (streamed): shows the typing cursor.
  bool typing;

  /// The office's contact details ({name, address, phoneDisplay, telLink,
  /// mapsUrl}) when the answer is "talk to us".
  Map<String, dynamic> office;

  /// Buttons under the answer ({type, label}): course_finder,
  /// scholarship_finder, complete_profile. Call and Directions live on the
  /// office card instead.
  List<Map<String, dynamic>> actions;
}

/// Tappable buttons under an answer that open the screen it talks about.
class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.actions});

  final List<Map<String, dynamic>> actions;

  static const Map<String, (String, IconData)> _screens = <String, (String, IconData)>{
    'course_finder': (Routes.nextedCourses, AppIcons.school),
    'scholarship_finder': (Routes.nextedScholarships, AppIcons.medal),
    'complete_profile': (Routes.nextedProfile, AppIcons.person),
  };

  static const Map<String, String> _labels = <String, String>{
    'course_finder': 'Course matching',
    'scholarship_finder': 'Scholarship finder',
    'complete_profile': 'Complete my profile',
  };

  static const Map<String, String> _hints = <String, String>{
    'course_finder': 'Live search of universities, ranked for your profile',
    'scholarship_finder': 'Awards with an eligibility check for you',
    'complete_profile': 'Course matching and the Scholarship finder open once it is complete',
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final shown = [
      for (final a in actions)
        if (_screens.containsKey(a.s('type'))) a.s('type'),
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    // The same card as the office's Call / Directions one, so the two read
    // as one family: a title, a line, then the buttons.
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        child: AppCard(
          radius: 20,
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(
                shown.length == 1 ? _labels[shown.first]! : 'Take the next step',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              Text(
                shown.length == 1 ? _hints[shown.first]! : 'Open it right here in the app.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: t.textMuted),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in shown)
                    SoftButton(
                      label: shown.length == 1 ? 'Open' : _labels[type]!,
                      leading: _screens[type]!.$2,
                      height: 38,
                      onTap: () => context.push(_screens[type]!.$1),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A blinking block cursor at the end of a reply that is still being typed.
class _TypingCursor extends StatefulWidget {
  const _TypingCursor();

  @override
  State<_TypingCursor> createState() => _TypingCursorState();
}

class _TypingCursorState extends State<_TypingCursor> with SingleTickerProviderStateMixin {
  late final AnimationController _blink =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520))..repeat(reverse: true);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _blink, curve: Curves.easeInOut),
      child: Container(
        width: 8,
        height: 15,
        decoration: BoxDecoration(
          color: context.tk.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// The NextED office under an answer that needs a person: call or find us.
class _OfficeCard extends StatelessWidget {
  const _OfficeCard({required this.office});

  final Map<String, dynamic> office;

  Future<void> _launch(BuildContext context, String link) async {
    final uri = Uri.tryParse(link);
    // Phone, email, maps or a web page - nothing else.
    const allowed = <String>{'https', 'tel', 'mailto', 'geo'};
    if (uri == null || link.isEmpty || !allowed.contains(uri.scheme)) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) context.toast('Couldn’t open that');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        child: AppCard(
          radius: 20,
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(
                office.s('name').isEmpty ? 'NextED office' : office.s('name'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              if (office.s('address').isNotEmpty)
                Text(office.s('address'), style: TextStyle(fontSize: 12.5, height: 1.4, color: t.textMuted)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (office.s('telLink').isNotEmpty)
                    SoftButton(
                      label: office.s('phoneDisplay').isEmpty ? 'Call' : 'Call ${office.s('phoneDisplay')}',
                      leading: AppIcons.phone,
                      height: 38,
                      onTap: () => _launch(context, office.s('telLink')),
                    ),
                  if (office.s('mapsUrl').isNotEmpty)
                    SoftButton(
                      label: 'Directions',
                      leading: AppIcons.openExternal,
                      height: 38,
                      onTap: () => _launch(context, office.s('mapsUrl')),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final _Msg message;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final mine = message.fromStudent;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        child: AppCard(
          radius: 20,
          color: mine
              ? t.primary
              : message.failed
                  ? t.accentSoft
                  : null,
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 13),
          child: mine
              ? Text(
                  message.text,
                  style: TextStyle(fontSize: 13.5, height: 1.45, color: t.onPrimary),
                )
              : message.typing
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.text.trim().isNotEmpty) NextedAnswer(message.text),
                        const Padding(padding: EdgeInsets.only(top: 4), child: _TypingCursor()),
                      ],
                    )
                  : NextedAnswer(message.text),
        ),
      ),
    );
  }
}
