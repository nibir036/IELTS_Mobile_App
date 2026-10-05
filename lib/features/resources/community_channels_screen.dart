import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../shell/main_shell.dart';
import 'widgets.dart';

/// Community rooms and direct chats aren't live yet: the tab and the room
/// screen show a blurred "Coming soon" wall until this is true.
const bool kCommunityLive = false;
const String kCommunitySoonTitle = 'Community is on its way';
const String kCommunitySoonMessage =
    'Speaking rooms and chats with other IELTS students are coming in a future update.';

/// Room screen stand-in while [kCommunityLive] is false (links from
/// notifications or elsewhere land here).
class CommunitySoonScreen extends StatelessWidget {
  const CommunitySoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      backgroundColor: t.bg,
      body: ComingSoonWall(
        title: kCommunitySoonTitle,
        message: kCommunitySoonMessage,
        onBack: () => context.back(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// H3 · Community Channels (bottom-nav tab 3). In-app rooms + direct chats.
class CommunityChannelsScreen extends StatefulWidget {
  const CommunityChannelsScreen({super.key});

  @override
  State<CommunityChannelsScreen> createState() =>
      _CommunityChannelsScreenState();
}

class _CommunityChannelsScreenState extends State<CommunityChannelsScreen> {
  int _tab = 0;

  Future<void> _newRoom() async {
    final room = await showAppSheet<Map<String, dynamic>>(context, const _NewRoomSheet());
    if (!mounted || room == null) return;
    setState(() => _tab = 0);
    context.toast('Room “${room.s('name')}” created');
    _open(room.s('id'), room.s('name'));
  }

  /// A user room row: preview = newest message, else its description.
  Map<String, dynamic> _myRoomRow(Store store, Map<String, dynamic> room) {
    final sent = store.kvList(ResKeys.sent(room.s('id')));
    var preview = room.s('description').isEmpty
        ? '${room.s('topic')} · created by you'
        : room.s('description');
    if (sent.isNotEmpty) {
      final last = sent.last;
      final type = last.s('type');
      final text = type == 'voice'
          ? 'Voice message'
          : (type == 'image' ? 'Photo' : last.s('text'));
      preview = last.b('mine') ? 'You: $text' : text;
    }
    return <String, dynamic>{...room, 'preview': preview, 'mineRoom': true};
  }

  void _open(String id, String name) {
    markRoomRead(id);
    context.push(
      Routes.speakingRoomChat,
      args: <String, dynamic>{'roomId': id, 'title': name},
    );
  }

  /// DM rows show the newest message (seeded or sent) as their preview.
  Map<String, dynamic> _dmRow(Store store, Map<String, dynamic> dm) {
    final msgs = <Map<String, dynamic>>[
      ...dm.l('messages'),
      ...store.kvList(ResKeys.sent(dm.s('id'))),
    ];
    final last = msgs.isEmpty ? null : msgs.last;
    var preview = dm.s('preview');
    if (last != null) {
      final type = last.s('type');
      final text = type == 'voice'
          ? 'Voice message'
          : (type == 'image' ? 'Photo' : last.s('text'));
      preview = last.b('mine') ? 'You: $text' : text;
    }
    return <String, dynamic>{...dm, 'preview': preview};
  }

  @override
  Widget build(BuildContext context) {
    final content = _content(context);
    if (kCommunityLive) return content;
    return ComingSoonWall(
      title: kCommunitySoonTitle,
      message: kCommunitySoonMessage,
      bottomInset: MainShell.navClearance - 40,
      child: content,
    );
  }

  Widget _content(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final c = Demo.section('resources').m('community');
    final live = c.m('live');
    final dms = [for (final d in communityDms(store)) _dmRow(store, d)];
    final mine = [for (final r in communityMyRooms(store)) _myRoomRow(store, r)];
    final rooms = _tab == 0 ? <Map<String, dynamic>>[...mine, ...c.l('rooms')] : dms;
    var directCount = 0;
    for (final d in dms) {
      directCount += roomUnread(store, d);
    }

    return AppScreen(
      gap: 12,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, MainShell.navClearance),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Community',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.8,
                ),
              ),
            ),
            IconBox(
              icon: AppIcons.add,
              tooltip: 'New room',
              onTap: _newRoom,
            ),
          ],
        ),
        ResSegments(
          labels: <String>[
            'Rooms',
            directCount > 0 ? 'Direct · $directCount' : 'Direct',
          ],
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        HeroCard(
          radius: 24,
          padding: const EdgeInsets.all(16),
          onTap: () => _open(live.s('roomId'), ''),
          child: Row(
            spacing: 12,
            children: [
              AvatarStack(people: live.l('avatars'), borderColor: t.heroDark),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      live.s('title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: t.heroText,
                      ),
                    ),
                    Text(
                      live.s('subtitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: t.heroMuted,
                      ),
                    ),
                  ],
                ),
              ),
              PrimaryButton(
                label: 'Join',
                height: 40,
                fontSize: 13,
                expand: false,
                onTap: () => _open(live.s('roomId'), ''),
              ),
            ],
          ),
        ),
        AppCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _tab == 0 ? 'Your rooms' : 'Direct messages',
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                    ),
                    Text(
                      _tab == 0
                          ? '${c.i('roomsCount') + mine.length}'
                          : '${rooms.length}',
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                  ],
                ),
              ),
              if (_tab == 1 && rooms.isEmpty)
                EmptyState(
                  card: false,
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 16),
                  title: 'No direct messages yet',
                  message: 'Join a room and practise with a partner - your chats will appear here.',
                  icon: AppIcons.chat,
                  actionLabel: 'Browse rooms',
                  onAction: () => setState(() => _tab = 0),
                ),
              for (final r in rooms)
                _RoomRow(
                  data: r,
                  unread: roomUnread(store, r),
                  onTap: () => _open(r.s('id'), r.s('name')),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({
    required this.data,
    required this.unread,
    required this.onTap,
  });

  final Map<String, dynamic> data;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final tone = data.s('tone');
    Widget? trailing;
    if (data.b('live')) {
      trailing = Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: t.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 5,
          children: [
            Dot(
              size: 6,
              color: t.isNight ? ResPalette.ink : ResPalette.rose,
            ),
            Text(
              'Live',
              style: TextStyle(fontSize: 11, color: t.onPrimary),
            ),
          ],
        ),
      );
    } else if (data.b('mineRoom')) {
      trailing = const Tag('Yours', height: 24);
    } else if (unread > 0) {
      trailing = CountBadge(unread);
    }
    return ListRow(
      divider: true,
      padding: const EdgeInsets.symmetric(vertical: 10),
      onTap: onTap,
      leading: LetterBadge(
        data.s('letter'),
        size: 46,
        radius: 16,
        fontSize: 15,
        bg: toneBg(t, tone),
        fg: toneFg(t, tone),
      ),
      title: data.s('name'),
      subtitle: data.s('preview'),
      titleSize: 15,
      trailing: trailing,
    );
  }
}

/// "New room" sheet: name, topic chips, short description, validation.
/// Pops with the created room map.
class _NewRoomSheet extends StatefulWidget {
  const _NewRoomSheet();

  @override
  State<_NewRoomSheet> createState() => _NewRoomSheetState();
}

class _NewRoomSheetState extends State<_NewRoomSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _desc = TextEditingController();
  String? _topic;
  String? _error;

  static const int _maxName = 40;
  static const int _maxDesc = 140;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  String? _validate() {
    final name = _name.text.trim();
    if (name.length < 3) return 'Give the room a name (at least 3 characters).';
    if (name.length > _maxName) return 'Keep the name under $_maxName characters.';
    final lower = name.toLowerCase();
    final taken = <String>[
      for (final r in Demo.section('resources').m('community').l('rooms')) r.s('name'),
      for (final r in communityMyRooms(Store.I)) r.s('name'),
    ].any((n) => n.toLowerCase() == lower);
    if (taken) return 'A room with this name already exists.';
    if (_topic == null) return 'Pick a topic for the room.';
    if (_desc.text.trim().length > _maxDesc) {
      return 'Keep the description under $_maxDesc characters.';
    }
    return null;
  }

  void _create() {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final room = createMyRoom(
      name: _name.text,
      topic: _topic!,
      description: _desc.text,
    );
    Navigator.of(context).pop(room);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'New room',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            'Start a study room for your group. Only you can delete it.',
            style: TextStyle(fontSize: 13, color: t.textMuted),
          ),
          AppTextField(
            controller: _name,
            label: 'Room name',
            hint: 'e.g. Task 2 essay swap',
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          Text('Topic', style: TextStyle(fontSize: 13, color: t.textMuted)),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final topic in kRoomTopics)
                ChipPill(
                  label: topic,
                  selected: _topic == topic,
                  onTap: () => setState(() {
                    _topic = topic;
                    _error = null;
                  }),
                ),
            ],
          ),
          AppTextField(
            controller: _desc,
            label: 'Short description (optional)',
            hint: 'What will you practise here?',
            maxLines: 3,
            onChanged: (_) => setState(() => _error = null),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_desc.text.trim().length}/$_maxDesc',
              style: TextStyle(
                fontSize: 12,
                color: _desc.text.trim().length > _maxDesc ? t.dangerText : t.textMuted,
              ),
            ),
          ),
          if (_error != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: t.dangerSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _error!,
                style: TextStyle(fontSize: 13, color: t.dangerText),
              ),
            ),
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: OutlineButtonX(
                  label: 'Cancel',
                  height: 52,
                  radius: 18,
                  fontSize: 15,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: PrimaryButton(
                  label: 'Create room',
                  height: 52,
                  radius: 18,
                  fontSize: 15,
                  onTap: _create,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
