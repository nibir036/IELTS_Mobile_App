import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/services/api_client.dart';
import '../../app/services/nexted_api.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';
import '../../app/widgets/app_tour.dart';
import 'nexted_shell.dart';

/// nexted.app · student profile.
///
/// The profile the course match and the scholarship eligibility verdict are
/// built from, so the fields here are the ones those rules compare against
/// (nationality, level, result, IELTS band). It reads and writes the shared
/// backend, which is the same record a counsellor sees on the web.
///
/// One account behind both halves of the app: the name is the account's name
/// (editing it here renames the IELTS AI account too), the phone is the login
/// number (shown, not edited), and the IELTS band comes from the IELTS side -
/// the latest full mock test, else the target band - until the student types
/// their own (a real exam score, say).
class NextedProfileScreen extends StatefulWidget {
  const NextedProfileScreen({super.key, this.embedded = false});

  /// Shown as a tab of the study-abroad shell: no back arrow, and the save
  /// button sits above the bottom nav.
  final bool embedded;

  @override
  State<NextedProfileScreen> createState() => _NextedProfileScreenState();
}

class _NextedProfileScreenState extends State<NextedProfileScreen> {
  /// key → label, in the order they are shown.
  static const List<(String, String, String)> _fields = <(String, String, String)>[
    ('fullName', 'Full name', 'As written in your passport'),
    ('email', 'Email', 'you@example.com'),
    ('phone', 'Phone', '01XXXXXXXXX'),
    ('nationality', 'Nationality', 'Bangladeshi'),
    // Several UK universities close an intake by district rather than by
    // country, so without this a course can only come back "uncertain".
    ('homeDistrict', 'Home district', 'Sylhet · Dhaka · Chattogram …'),
    ('highestLevel', 'Highest education', 'HSC · Bachelor · Master'),
    // What they want to ENROL in - the AI searches at this level.
    ('studyLevel', 'Level you want to study', 'Pick one'),
    ('result', 'Result / GPA', 'e.g. 4.50 or 3.2/4'),
    ('ieltsBand', 'IELTS band', 'e.g. 6.5, or "not yet"'),
    // What the AI searches courses and scholarships on when nothing is typed.
    ('subject', 'Subject you want to study', 'e.g. Nursing · Data Science · MBA'),
    ('preferredCountry', 'Preferred country', 'UK · Canada · Australia …'),
    ('preferredIntake', 'Preferred intake', 'e.g. September 2027'),
    // Asked for every level of study; universities and scholarships weigh it.
    ('hasPublication', 'Do you have any published research?', 'Pick one'),
  ];

  /// Choices for 'studyLevel' - fixed words, so the AI reads them reliably.
  static const List<String> _studyLevels = <String>[
    'Foundation',
    'Diploma',
    'Bachelors',
    'Masters',
    'MBA',
    'PhD',
  ];

  final Map<String, TextEditingController> _c = <String, TextEditingController>{};
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  /// Where the IELTS band shown came from: 'you', 'mock', 'target' or ''.
  String _bandSource = '';

  /// The band as loaded, so an untouched field stays automatic on save.
  String _loadedBand = '';

  @override
  void initState() {
    super.initState();
    for (final f in _fields) {
      _c[f.$1] = TextEditingController();
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (!NextedApi.ready) {
      // No server yet: start from what the IELTS account already knows.
      final acc = Store.I.current;
      _c['fullName']?.text = acc?.name ?? '';
      _c['phone']?.text = acc?.phoneDisplay ?? '';
      final mock = Store.I.latest(skill: 'mock', kind: 'mock');
      if (mock?.band != null) {
        _c['ieltsBand']?.text = Store.formatBand(mock!.band);
        _bandSource = 'mock';
      } else if (acc?.targetBand != null) {
        _c['ieltsBand']?.text = Store.formatBand(acc!.targetBand);
        _bandSource = 'target';
      }
      _loadedBand = _c['ieltsBand']?.text ?? '';
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final r = await NextedApi.get(NextedConfig.profile);
      final p = r.m('profile').isEmpty ? r : r.m('profile');
      if (!mounted) return;
      for (final f in _fields) {
        _c[f.$1]?.text = p.s(f.$1);
      }
      _bandSource = r.s('ieltsBandSource');
      _loadedBand = p.s('ieltsBand');
      setState(() {
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!NextedApi.ready) {
      context.toast('Connect the study-abroad server to save your profile.');
      return;
    }
    setState(() => _saving = true);
    try {
      // The phone is the login number: never sent from here.
      final body = <String, dynamic>{
        for (final f in _fields)
          if (f.$1 != 'phone') f.$1: _c[f.$1]?.text.trim() ?? '',
      };
      final r = await NextedApi.patch(NextedConfig.profile, body);
      if (!mounted) return;
      final p = r.m('profile').isEmpty ? r : r.m('profile');
      // Same account on the IELTS side: show the new name there straight away.
      final name = p.s('fullName').trim();
      if (name.isNotEmpty && name != Store.I.current?.name) {
        Store.I.updateProfile(<String, dynamic>{}, name: name);
      }
      _c['ieltsBand']?.text = p.s('ieltsBand');
      setState(() {
        _bandSource = r.s('ieltsBandSource');
        _loadedBand = p.s('ieltsBand');
        _saving = false;
        _dirty = false;
      });
      context.toast('Profile saved');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;

    return AppScreen(
      gap: 13,
      padding: EdgeInsets.fromLTRB(20, widget.embedded ? 16 : 12, 20, 24),
      // In the study-abroad shell the button sits above the bottom nav.
      footerPadding: EdgeInsets.fromLTRB(20, 8, 20, widget.embedded ? 104 : 16),
      footer: TourTarget(
        id: 'abroad.profile.save',
        child: PrimaryButton(
          label: _saving ? 'Saving…' : 'Save profile',
          enabled: !_saving && !_loading,
          onTap: _save,
        ),
      ),
      children: [
        TopBar(
          title: 'Student profile',
          subtitle: 'Your counsellor sees the same details',
          showBack: !widget.embedded,
          onBack: () => context.back(),
        ),

        if (!NextedConfig.hasApi)
          const NextedOfflineNotice(
            message: 'Not connected to the study-abroad server yet, so nothing is saved. '
                'Build with --dart-define=NEXTED_API_BASE_URL=… to store this profile.',
          ),

        if (_error != null)
          EmptyState(
            title: 'Couldn’t load your profile',
            message: _error,
            icon: AppIcons.person,
            actionLabel: 'Try again',
            onAction: () {
              setState(() {
                _error = null;
                _loading = true;
              });
              _load();
            },
          )
        else if (_loading)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else ...[
          AppCard(
            radius: 22,
            color: t.surfaceAlt,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Icon(AppIcons.info, size: 20, color: t.textMuted),
                Expanded(
                  child: Text(
                    'Course matching and scholarship eligibility are decided from these '
                    'details, so the fuller they are, the better the results. Some '
                    'universities open or close an intake by district, which is why we ask '
                    'where you are from.',
                    style: TextStyle(fontSize: 12.5, height: 1.4, color: t.textSoft),
                  ),
                ),
              ],
            ),
          ),
          AppCard(
            radius: 18,
            color: t.surfaceAlt,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Text(
              'Fields marked * are needed for Course matching and the Scholarship finder.',
              style: TextStyle(fontSize: 12, height: 1.4, color: t.textSoft),
            ),
          ),
          for (final f in _fields)
            if (f.$1 == 'studyLevel')
              _levelPicker(t, f.$2)
            else if (f.$1 == 'hasPublication')
              _choicePicker(
                t,
                'hasPublication',
                f.$2,
                const <String>['Yes', 'No'],
                note: 'A paper in a journal or at a conference, at any level of study.',
              )
            else if (f.$1 == 'phone')
              _accountRow(t, NextedProfileRules.isRequired('phone') ? '${f.$2} *' : f.$2, _c['phone']!.text,
                  'Your login number. Change it in your Profile if you get a new one.')
            else ...[
            AppTextField(
              // One field per key, so a note appearing above it can never
              // hand its state to a neighbouring field.
              key: ValueKey<String>('nexted-field-${f.$1}'),
              label: NextedProfileRules.isRequired(f.$1) ? '${f.$2} *' : f.$2,
              hint: f.$3,
              controller: _c[f.$1],
              keyboardType: f.$1 == 'email'
                  ? TextInputType.emailAddress
                  : f.$1 == 'phone'
                      ? TextInputType.phone
                      : f.$1 == 'result'
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
              onChanged: (_) {
                if (f.$1 == 'ieltsBand') {
                  setState(() => _dirty = true);
                } else if (!_dirty) {
                  setState(() => _dirty = true);
                }
              },
            ),
            if (f.$1 == 'fullName')
              _note(t, 'The same name as your nextED account. Changing it here changes it everywhere in the app.'),
            if (f.$1 == 'ieltsBand' && _bandNote() != null) _note(t, _bandNote()!),
            ],
          if (_dirty)
            Text(
              'Unsaved changes',
              style: TextStyle(fontSize: 12, color: t.textMuted),
            ),
          // In the study-abroad tabs: the first-time tour, again.
          if (widget.embedded)
            Center(
              child: SoftButton(
                label: 'Replay the app tour',
                leading: AppIcons.compass,
                onTap: () => NextedShell.of(context)?.replayTour(),
              ),
            ),
        ],
      ],
    );
  }

  /// Where the IELTS band came from, in words (null when there is nothing to say).
  String? _bandNote() {
    final typed = _c['ieltsBand']?.text.trim() ?? '';
    final edited = typed != _loadedBand.trim();
    if (edited) {
      return typed.isEmpty
          ? 'Left empty, it will follow your IELTS AI band again.'
          : 'Your own band. It stays as you typed it.';
    }
    return switch (_bandSource) {
      'mock' => 'From your latest mock test in IELTS AI. Type your real exam score to replace it.',
      'target' => 'Your target band from IELTS AI. Take a mock test or type your real score.',
      'you' => 'Entered by you. Clear it to use your IELTS AI band instead.',
      _ => null,
    };
  }

  Widget _note(AppTokens t, String text) => Padding(
        padding: const EdgeInsets.only(left: 4, top: 2),
        child: Text(text, style: TextStyle(fontSize: 12, height: 1.4, color: t.textMuted)),
      );

  /// A field that belongs to the account and isn't edited here (the phone).
  Widget _accountRow(AppTokens t, String label, String value, String note) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: t.textSoft)),
        Container(
          height: 56,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: t.surfaceAlt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.border),
          ),
          child: Row(
            spacing: 10,
            children: [
              Expanded(
                child: Text(
                  value.isEmpty ? '–' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, color: t.textSoft),
                ),
              ),
              Icon(AppIcons.lock, size: 18, color: t.textMuted),
            ],
          ),
        ),
        _note(t, note),
      ],
    );
  }

  /// Bachelors / Masters / PhD ... as tap-to-pick chips.
  /// A required one-of-a-few answer as chips (stored as the chip's word).
  Widget _choicePicker(AppTokens t, String key, String label, List<String> options, {String? note}) {
    final c = _c[key]!;
    final current = c.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text('$label *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: t.textSoft)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              ChoiceChip(
                label: Text(o),
                selected: current.toLowerCase() == o.toLowerCase(),
                showCheckmark: false,
                selectedColor: t.primary,
                labelStyle: TextStyle(
                  fontSize: 13,
                  color: current.toLowerCase() == o.toLowerCase() ? t.onPrimary : t.text,
                ),
                backgroundColor: t.surface,
                side: BorderSide(color: t.border),
                shape: const StadiumBorder(),
                onSelected: (_) => setState(() {
                  c.text = o;
                  _dirty = true;
                }),
              ),
          ],
        ),
        if (note != null) Text(note, style: TextStyle(fontSize: 12, height: 1.4, color: t.textMuted)),
      ],
    );
  }

  Widget _levelPicker(AppTokens t, String label) {
    final c = _c['studyLevel']!;
    final current = c.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text('$label *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: t.textSoft)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final level in <String>{..._studyLevels, if (current.isNotEmpty) current})
              ChoiceChip(
                label: Text(level),
                selected: current.toLowerCase() == level.toLowerCase(),
                showCheckmark: false,
                selectedColor: t.primary,
                labelStyle: TextStyle(
                  fontSize: 13,
                  color: current.toLowerCase() == level.toLowerCase() ? t.onPrimary : t.text,
                ),
                backgroundColor: t.surface,
                side: BorderSide(color: t.border),
                shape: const StadiumBorder(),
                onSelected: (_) => setState(() {
                  c.text = level;
                  _dirty = true;
                }),
              ),
          ],
        ),
      ],
    );
  }
}
