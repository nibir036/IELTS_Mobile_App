import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/services/ai_service.dart';
import '../../app/services/audio_clip.dart';
import '../../app/services/voice_recorder.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'room_chat_bubbles.dart';
import 'room_chat_parts.dart';
import 'widgets.dart';

/// H4 · Speaking Room Chat — in-app community room with a working composer:
/// text, voice notes, images and an AI speaking partner. Opens the content
/// room, a DM thread or one of the user's own rooms (`{'roomId': id}`).
class SpeakingRoomChatScreen extends StatefulWidget {
  const SpeakingRoomChatScreen({super.key});

  @override
  State<SpeakingRoomChatScreen> createState() => _SpeakingRoomChatScreenState();
}

class _SpeakingRoomChatScreenState extends State<SpeakingRoomChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late final Map<String, dynamic> _room =
      Demo.section('resources').m('speakingRoom');

  bool _joinedSession = false;
  String? _playingId;
  double _playProgress = 0;
  Timer? _playTimer;

  /// Snapshot of the user's own room (kept while the screen closes after a
  /// delete so it doesn't flash the content room).
  Map<String, dynamic>? _myRoomSnap;

  // Voice notes.
  VoiceRecorder? _rec;
  bool _recording = false;
  bool _recBusy = false;
  Timer? _recTimer;
  AudioClip? _clip;
  String? _clipId;
  final Set<String> _expired = <String>{};

  // Image picking.
  bool _picking = false;

  // AI speaking partner.
  bool _ai = false;
  bool _aiBusy = false;
  String _aiTopic = '';
  List<String> _aiQuestions = <String>[];
  int _aiNext = 0;
  int _aiStart = 0;

  static const int _maxImageBytes = 400 * 1024;

  /// Room (or DM) id from route args; defaults to the content room.
  String get _roomId {
    final id = context.routeArgs['roomId'];
    return id is String && id.isNotEmpty ? id : _room.s('id');
  }

  /// The user's DM thread for [_roomId], if it is a DM.
  Map<String, dynamic>? _dm(Store store) {
    for (final d in communityDms(store)) {
      if (d.s('id') == _roomId) return d;
    }
    return null;
  }

  /// The user's own room for [_roomId], if it is one.
  Map<String, dynamic>? _myRoom(Store store) {
    final r = communityMyRoom(store, _roomId);
    if (r != null) _myRoomSnap = r;
    return r ?? _myRoomSnap;
  }

  /// Chat items in display order (oldest first). Types: text, voice, image,
  /// system, session, typing. Content messages first (the user's seeded
  /// replies slot in after the message named by `afterId`), then the session
  /// card, then the user's own newer messages.
  List<Map<String, dynamic>> _items(Store store) {
    final dm = _dm(store);
    final mine = dm == null ? _myRoom(store) : null;
    final sent = store.kvList(ResKeys.sent(_roomId));
    final List<Map<String, dynamic>> content;
    if (dm != null) {
      content = dm.l('messages');
    } else if (mine != null) {
      final desc = mine.s('description');
      content = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'welcome',
          'type': 'system',
          'text': 'Welcome to ${mine.s('name')} · ${mine.s('topic')}. '
              '${desc.isEmpty ? 'Share a message, a voice note or an image to get started.' : desc}',
        },
      ];
    } else {
      content = _room.l('messages');
    }
    final ids = <String>{for (final m in content) m.s('id')};
    final out = <Map<String, dynamic>>[];
    for (final m in content) {
      out.add(m);
      for (final x in sent) {
        if (x.s('afterId') == m.s('id')) out.add(x);
      }
    }
    if (dm == null && mine == null) {
      out.add(<String, dynamic>{'id': 'session', 'type': 'session'});
    }
    for (final x in sent) {
      if (!ids.contains(x.s('afterId'))) out.add(x);
    }
    if (_aiBusy) out.add(<String, dynamic>{'id': 'typing', 'type': 'typing'});
    return out;
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    _recTimer?.cancel();
    _rec?.dispose(); // stops a recording in progress
    _clip?.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _now() {
    final now = TimeOfDay.now();
    final h = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final m = now.minute.toString().padLeft(2, '0');
    final p = now.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// Persists one of the user's own messages in this room.
  void _post(Map<String, dynamic> fields) {
    final me = Store.I.current;
    Store.I.kvListAdd(ResKeys.sent(_roomId), <String, dynamic>{
      'id': Store.newId('msg'),
      'authorName': me?.name ?? 'You',
      'initials': me?.initials ?? '',
      'mine': true,
      'time': _now(),
      'createdAt': DateTime.now().toIso8601String(),
      ...fields,
    });
    _scrollToEnd();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _post(<String, dynamic>{'type': 'text', 'text': text});
    _input.clear();
    if (_ai) _partnerRespond(text);
  }

  // ── voice notes ───────────────────────────────────────────────────────────

  Future<void> _toggleVoice() async {
    if (_recBusy) return;
    if (_recording) {
      await _stopAndSendVoice();
      return;
    }
    _recBusy = true;
    final rec = _rec ??= VoiceRecorder();
    final ok = await rec.start();
    _recBusy = false;
    if (!mounted) return;
    if (!ok) {
      context.toast(
        'Microphone is blocked. Allow microphone access for IELTS AI in your '
        'browser or phone settings to send voice notes.',
      );
      return;
    }
    _stopPlayback();
    setState(() => _recording = true);
    _recTimer?.cancel();
    _recTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _stopAndSendVoice() async {
    if (_recBusy) return;
    _recBusy = true;
    _recTimer?.cancel();
    final r = await _rec?.stop();
    _recBusy = false;
    if (!mounted) return;
    setState(() => _recording = false);
    if (r == null) {
      context.toast('Could not save the voice note. Please try again.');
      return;
    }
    if (r.durationMs < 700) {
      context.toast('Hold on a little longer — that voice note was too short');
      return;
    }
    kSessionVoicePaths.add(r.path);
    _post(<String, dynamic>{
      'type': 'voice',
      'path': r.path,
      'durationMs': r.durationMs,
      'durationSeconds': r.durationSec,
      'duration': clockFromMs(r.durationMs),
    });
  }

  Future<void> _cancelVoice() async {
    if (_recBusy) return;
    _recBusy = true;
    _recTimer?.cancel();
    await _rec?.cancel();
    _recBusy = false;
    if (!mounted) return;
    setState(() => _recording = false);
    context.toast('Voice note discarded');
  }

  void _stopPlayback() {
    _playTimer?.cancel();
    _clip?.pause();
    if (_playingId != null) setState(() => _playingId = null);
  }

  Future<void> _toggleMyVoice(Map<String, dynamic> m) async {
    final id = m.s('id');
    if (_expired.contains(id) || voiceNoteExpired(m)) {
      setState(() => _expired.add(id));
      context.toast('This voice note has expired and can no longer be played');
      return;
    }
    final existing = _clip;
    if (_clipId == id && existing != null && existing.loaded) {
      existing.toggle();
      return;
    }
    _playTimer?.cancel();
    final clip = _clip ??= AudioClip();
    clip.pause();
    setState(() {
      _playingId = null;
      _clipId = id;
    });
    final ok = await clip.loadRecording(m.s('path'));
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _expired.add(id);
        _clipId = null;
      });
      context.toast('This voice note has expired and can no longer be played');
      return;
    }
    clip.play();
  }

  // ── images ────────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    if (_picking) return;
    _picking = true;
    XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 70,
      );
    } catch (_) {
      file = null;
      if (mounted) context.toast('Could not open your photos. Check the app’s photo permission.');
    }
    if (file == null || !mounted) {
      _picking = false;
      return;
    }
    final bytes = await file.readAsBytes();
    _picking = false;
    if (!mounted) return;
    if (bytes.length > _maxImageBytes) {
      final kb = (bytes.length / 1024).round();
      context.toast('That image is too large ($kb KB). Please choose one under 400 KB.');
      return;
    }
    _post(<String, dynamic>{
      'type': 'image',
      'imageBase64': base64Encode(bytes),
      'bytes': bytes.length,
    });
  }

  // ── AI speaking partner ───────────────────────────────────────────────────

  /// Keyword for Part 3 questions: the session topic ("Part 3 · Environment"
  /// → "Environment") for the content room, the room topic for own rooms.
  String _partnerKeyword() {
    final mine = _myRoom(Store.I);
    if (mine != null) {
      final topic = mine.s('topic');
      return topic == 'General' ? '' : topic;
    }
    final title = _room.m('session').s('title');
    final i = title.lastIndexOf('·');
    return i >= 0 ? title.substring(i + 1).trim() : title;
  }

  String _nextQuestion() {
    if (_aiQuestions.isEmpty) return 'What would you like to talk about next?';
    final q = _aiQuestions[_aiNext % _aiQuestions.length];
    _aiNext++;
    return q;
  }

  void _postPartner(String text, {required bool offline}) {
    Store.I.kvListAdd(ResKeys.sent(_roomId), <String, dynamic>{
      'id': Store.newId('msg'),
      'type': 'text',
      'ai': true,
      'mine': false,
      'authorName': offline ? 'AI partner (offline demo)' : 'AI partner',
      'initials': 'AI',
      'tone': 'lilac',
      'time': _now(),
      'createdAt': DateTime.now().toIso8601String(),
      'text': text,
    });
    _scrollToEnd();
  }

  void _toggleAi() {
    if (_ai) {
      setState(() {
        _ai = false;
        _aiBusy = false;
      });
      context.toast('AI speaking partner is off');
      return;
    }
    final (topic, questions) = partnerQuestionsFor(_roomId, _partnerKeyword());
    setState(() {
      _ai = true;
      _aiTopic = topic;
      _aiQuestions = questions;
      _aiNext = 0;
      _aiStart = Store.I.kvList(ResKeys.sent(_roomId)).length;
    });
    _postPartner(
      'Hi! I’m your AI speaking partner. Answer in 3–5 sentences, as you would '
      'in Speaking Part 3, and I’ll give you quick feedback.\n\n${_nextQuestion()}',
      offline: !AiService.available,
    );
  }

  /// Conversation since the partner was switched on, for the API.
  List<Map<String, String>> _partnerHistory() {
    final sent = Store.I.kvList(ResKeys.sent(_roomId));
    final from = _aiStart < 0 ? 0 : (_aiStart > sent.length ? sent.length : _aiStart);
    final out = <Map<String, String>>[];
    for (final m in sent.sublist(from)) {
      if (m.s('type') != 'text') continue;
      final text = m.s('text');
      if (text.isEmpty) continue;
      out.add(<String, String>{
        'role': m.b('ai') ? 'partner' : 'student',
        'content': text,
      });
    }
    return out.length > 12 ? out.sublist(out.length - 12) : out;
  }

  Future<void> _partnerRespond(String answer) async {
    if (_aiBusy) return;
    setState(() => _aiBusy = true);
    _scrollToEnd();
    final res = await AiService.partnerReply(
      history: _partnerHistory(),
      topic: _aiTopic.isEmpty ? null : _aiTopic,
      questions: _aiQuestions,
    );
    if (!mounted) return;
    if (!_ai) {
      setState(() => _aiBusy = false);
      return;
    }
    final fallbackQuestion = _nextQuestion();
    var text = '';
    var offline = true;
    if (res != null) {
      final feedback = res.s('feedback');
      final suggestion = res.s('suggestion');
      final question = res.s('question').isEmpty ? fallbackQuestion : res.s('question');
      text = <String>[
        if (feedback.isNotEmpty) feedback,
        if (suggestion.isNotEmpty) 'Try: “$suggestion”.',
        question,
      ].join('\n\n');
      offline = false;
    }
    if (text.trim().isEmpty) {
      text = offlinePartnerReply(answer, fallbackQuestion);
      offline = true;
    }
    setState(() => _aiBusy = false);
    _postPartner(text, offline: offline);
  }

  // ── simulated playback of other people's voice messages ──────────────────

  void _togglePlay(Map<String, dynamic> m) {
    final id = m.s('id');
    _playTimer?.cancel();
    _clip?.pause();
    if (_playingId == id) {
      setState(() => _playingId = null);
      return;
    }
    final total = m.i('durationSeconds') <= 0 ? 10 : m.i('durationSeconds');
    setState(() {
      _playingId = id;
      _playProgress = 0;
    });
    const tick = Duration(milliseconds: 200);
    _playTimer = Timer.periodic(tick, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _playProgress += 0.2 / total;
        if (_playProgress >= 1) {
          _playProgress = 0;
          _playingId = null;
          timer.cancel();
        }
      });
    });
  }

  // ── menus ─────────────────────────────────────────────────────────────────

  Future<void> _showActions(Map<String, dynamic> m, Offset at) async {
    final t = context.tk;
    final size = MediaQuery.of(context).size;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, size.width - at.dx, size.height - at.dy),
      color: t.surface,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      items: <PopupMenuEntry<String>>[
        _menuItem('reply', AppIcons.arrowBack, 'Reply', t.text, null),
        _menuItem('copy', AppIcons.doc, 'Copy text', t.text, null),
        const PopupMenuDivider(height: 5),
        _menuItem('report', AppIcons.flag, 'Report message', t.dangerText, t.dangerSoft),
      ],
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'reply':
        final name = m.b('mine') ? 'You' : m.s('authorName').split(' ').first;
        _input.text = '@$name ';
        _input.selection = TextSelection.collapsed(offset: _input.text.length);
      case 'copy':
        final type = m.s('type');
        final text = type == 'voice'
            ? 'Voice message (${m.s('duration')})'
            : (type == 'image' ? 'Photo' : m.s('text'));
        await Clipboard.setData(ClipboardData(text: text));
        if (!mounted) return;
        context.toast('Copied');
      case 'report':
        context.toast('Reported. A moderator will review this message.');
    }
  }

  Future<void> _roomMenu(Map<String, dynamic> room, Offset at) async {
    final t = context.tk;
    final size = MediaQuery.of(context).size;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, size.width - at.dx, size.height - at.dy),
      color: t.surface,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      items: <PopupMenuEntry<String>>[
        _menuItem('info', AppIcons.info, 'Room details', t.text, null),
        const PopupMenuDivider(height: 5),
        _menuItem('delete', AppIcons.delete, 'Delete room', t.dangerText, t.dangerSoft),
      ],
    );
    if (!mounted || choice == null) return;
    if (choice == 'info') {
      await showRoomDetails(context, room);
      return;
    }
    final confirmed = await confirmDeleteRoom(context, room);
    if (!mounted || confirmed != true) return;
    final id = room.s('id');
    context.toast('Room deleted');
    context.back();
    deleteMyRoom(id);
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label,
    Color fg,
    Color? bg,
  ) {
    return PopupMenuItem<String>(
      value: value,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        height: 42,
        width: 178,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          spacing: 10,
          children: [
            Icon(icon, size: 18, color: fg),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bg == null ? FontWeight.w400 : FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  Widget _message(Map<String, dynamic> m) {
    final type = m.s('type');
    if (type == 'session') {
      return SessionCard(
        data: _room.m('session'),
        joined: _joinedSession,
        onJoin: () {
          setState(() => _joinedSession = !_joinedSession);
          context.toast(_joinedSession
              ? 'You joined ${_room.m('session').s('title')}'
              : 'You left the session');
        },
      );
    }
    if (type == 'system') return ChatSystemLine(text: m.s('text'));
    if (type == 'typing') return const PartnerTyping();
    final Widget bubble;
    if (m.b('mine') && type == 'voice') {
      final id = m.s('id');
      bubble = MyVoiceBubble(
        data: m,
        clip: _clipId == id ? _clip : null,
        expired: _expired.contains(id) || voiceNoteExpired(m),
        onTap: () => _toggleMyVoice(m),
      );
    } else if (m.b('mine') && type == 'image') {
      bubble = MyImageBubble(data: m);
    } else if (m.b('mine')) {
      bubble = MyTextBubble(data: m);
    } else {
      bubble = OtherBubble(
        data: m,
        playing: _playingId == m.s('id'),
        progress: _playingId == m.s('id') ? _playProgress : 0,
        onPlay: () => _togglePlay(m),
      );
    }
    return GestureDetector(
      onLongPressStart: (d) => _showActions(m, d.globalPosition),
      child: bubble,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final args = context.routeArgs;
    final store = context.store;
    final dm = _dm(store);
    final mine = dm == null ? _myRoom(store) : null;
    final argTitle = args['title'];
    final title = mine != null
        ? mine.s('name')
        : (argTitle is String && argTitle.isNotEmpty ? argTitle : _room.s('title'));
    final reversed = _items(store).reversed.toList();
    final chipBg = t.isNight ? t.surface : t.raised;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            spacing: 12,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  spacing: 10,
                  children: [
                    IconBox(
                      icon: AppIcons.back,
                      tooltip: 'Back',
                      iconSize: 18,
                      onTap: () => context.back(),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 5,
                            children: [
                              const Dot(size: 7, color: ResPalette.onlineGreen),
                              Flexible(
                                child: Text(
                                  dm != null
                                      ? 'Direct message'
                                      : (mine != null
                                          ? '${mine.s('topic')} · your room'
                                          : '${_room.i('onlineCount')} learners online'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: t.isNight
                                        ? t.textMuted
                                        : ResPalette.onlineTextDay,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (mine != null)
                      Builder(
                        builder: (bctx) => IconBox(
                          icon: AppIcons.moreVert,
                          tooltip: 'Room options',
                          onTap: () {
                            final box = bctx.findRenderObject() as RenderBox?;
                            final at = box == null
                                ? const Offset(300, 80)
                                : box.localToGlobal(Offset(0, box.size.height));
                            _roomMenu(mine, at);
                          },
                        ),
                      )
                    else
                      IconBox(
                        icon: AppIcons.headsetMic,
                        tooltip: 'Voice room',
                        onTap: () => context.toast('Joining voice room…'),
                      ),
                  ],
                ),
              ),
              // Messages (reverse list keeps the newest at the bottom)
              Expanded(
                child: ListView.separated(
                  controller: _scroll,
                  reverse: true,
                  padding: EdgeInsets.zero,
                  itemCount: reversed.length + 1,
                  separatorBuilder: (ctx, index) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == reversed.length) {
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: t.isNight ? t.surface : const Color(0xFFEDE3E9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _room.s('dayLabel'),
                            style: TextStyle(fontSize: 12, color: t.textMuted),
                          ),
                        ),
                      );
                    }
                    return _message(reversed[i]);
                  },
                ),
              ),
              // Quick actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: 6,
                    children: [
                      for (final a in _room.ls('quickActions'))
                        if (a == 'Voice')
                          SoftButton(
                            label: _recording ? 'Stop & send' : 'Voice',
                            height: 34,
                            fontSize: 13,
                            bg: _recording ? t.primary : chipBg,
                            fg: _recording ? t.onPrimary : null,
                            leading: _recording ? AppIcons.stop : AppIcons.mic,
                            onTap: _toggleVoice,
                          )
                        else if (a == 'Image')
                          SoftButton(
                            label: 'Image',
                            height: 34,
                            fontSize: 13,
                            bg: chipBg,
                            leading: AppIcons.attach,
                            onTap: _recording ? null : _pickImage,
                          )
                        else
                          SoftButton(
                            label: _ai ? 'AI partner · on' : a,
                            height: 34,
                            fontSize: 13,
                            bg: _ai ? t.primary : chipBg,
                            fg: _ai ? t.onPrimary : null,
                            leading: AppIcons.sparkle,
                            onTap: _toggleAi,
                          ),
                    ],
                  ),
                ),
              ),
              // Composer (or the recording bar while a voice note records)
              if (_recording && _rec != null)
                VoiceRecordingBar(
                  elapsed: _rec!.elapsed,
                  level: _rec!.level,
                  onCancel: _cancelVoice,
                  onSend: _stopAndSendVoice,
                )
              else
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Container(
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: chipBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextField(
                          controller: _input,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          style: TextStyle(fontSize: 15, color: t.text),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: _ai ? 'Answer the AI partner…' : 'Message the room',
                            hintStyle: TextStyle(fontSize: 15, color: t.textMuted),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    IconBox(
                      icon: AppIcons.send,
                      tooltip: 'Send',
                      size: 54,
                      radius: 20,
                      bg: t.primary,
                      fg: t.onPrimary,
                      onTap: _send,
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
