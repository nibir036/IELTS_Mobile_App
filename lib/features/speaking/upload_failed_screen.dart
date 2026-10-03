import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'speaking_ai.dart';
import 'widgets.dart';

/// D9 · Offline / upload failed. Shows the recording waiting in kv
/// ([kPendingUploadKey]). Retry re-runs upload → transcribe → evaluate for a
/// real queued session (`job`), or simulates it for the seeded demo row, then
/// saves the attempt and opens its band report; "Keep practising offline" leaves it
/// queued and opens My recordings.
class UploadFailedScreen extends StatefulWidget {
  const UploadFailedScreen({super.key});

  @override
  State<UploadFailedScreen> createState() => _UploadFailedScreenState();
}

class _UploadFailedScreenState extends State<UploadFailedScreen> {
  late final Map<String, dynamic> _data = speakingData().m('upload');
  late final Map<String, dynamic>? _pending = _readPending();
  late double _progress = (_pending ?? <String, dynamic>{}).d('progress');
  late final Attempt? _lastUploaded = Store.I
      .attemptsFor(skill: Skill.speaking)
      .where((a) => a.kind != 'pronunciation')
      .firstOrNull;
  late final List<String> _status = [
    if (_pending != null) 'waiting',
    if (_lastUploaded != null) 'uploaded',
  ];
  bool _uploading = false;
  String? _stageLabel;
  Timer? _timer;
  Timer? _navTimer;

  static Map<String, dynamic>? _readPending() {
    final v = Store.I.kv<Map>(kPendingUploadKey);
    return v?.cast<String, dynamic>();
  }

  void _savePending() {
    final pending = _pending;
    if (pending == null) return;
    final a = Attempt.fromJson(pending.m('attempt'));
    Store.I.setKv(kPendingUploadKey, null);
    Store.I.addAttempt(a);
    context.replace(Routes.speakingEvaluation, args: {'attemptId': a.id});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _navTimer?.cancel();
    super.dispose();
  }

  /// Real retry: re-runs upload → transcribe → evaluate from the queued job.
  Future<void> _retryJob(Map<String, dynamic> jobJson) async {
    setState(() {
      _uploading = true;
      _progress = 0;
    });
    final job = SpeakingJob.fromJson(jobJson);
    final out = await processSpeaking(
      job,
      queueOnUploadFail: false,
      onStage: (stage, progress) {
        if (!mounted) return;
        setState(() {
          _stageLabel = stage;
          _progress = progress;
        });
      },
    );
    if (!mounted) return;
    if (out.pending) {
      setState(() {
        _uploading = false;
        _stageLabel = null;
        _progress = 0;
      });
      context.toast('Still offline — try again when you’re connected');
      return;
    }
    Store.I.setKv(kPendingUploadKey, null);
    final a = out.attempt;
    setState(() {
      _progress = 1;
      for (var i = 0; i < _status.length; i++) {
        _status[i] = 'uploaded';
      }
    });
    if (out.audioMissing) {
      context.toast('Recording no longer on this phone — scored offline (demo)');
    } else if (a != null && a.data.s('source') != 'ai') {
      context.toast(offlineScoreReason('Uploaded · scored offline (demo)'));
    } else {
      context.toast('Upload complete');
    }
    if (a == null) return;
    context.replace(Routes.speakingEvaluation, args: {'attemptId': a.id});
  }

  void _retry() {
    final pending = _pending;
    if (_uploading || pending == null) return;
    final job = pending.m('job');
    if (job.isNotEmpty) {
      _retryJob(job);
      return;
    }
    setState(() => _uploading = true);
    _timer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) return;
      setState(() {
        _progress += 0.02;
        if (_progress >= 1) {
          _progress = 1;
          for (var i = 0; i < _status.length; i++) {
            _status[i] = 'uploaded';
          }
        }
      });
      if (_progress >= 1) {
        timer.cancel();
        context.toast('Upload complete');
        _navTimer = Timer(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          _savePending();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final pending = _pending;
    if (pending == null) {
      return AppScreen(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        gap: 16,
        children: [
          Row(
            children: [
              IconBox(
                icon: AppIcons.back,
                size: 56,
                radius: 20,
                iconSize: 20,
                tooltip: 'Back',
                onTap: () => context.back(),
              ),
            ],
          ),
          EmptyState(
            icon: AppIcons.upload,
            title: 'Nothing waiting to upload',
            message: 'Recordings saved while you are offline appear here until they upload.',
            actionLabel: 'Open my recordings',
            onAction: () => context.replace(Routes.myRecordings),
          ),
        ],
      );
    }
    final last = _lastUploaded;
    final queue = <Map<String, dynamic>>[
      <String, dynamic>{
        'title': pending.s('title'),
        'meta': '${_durationWords(pending.i('spokenSec'))} · recorded ${pending.s('recordedAt')}',
      },
      if (last != null)
        <String, dynamic>{
          'title': last.title,
          'meta': '${_durationWords(spokenSecOf(last))} · ${Store.relativeDay(last.createdAt)}',
        },
    ];
    final total = pending.d('sizeMb');
    final uploaded = total * _progress;
    final done = _progress >= 1;

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      gap: 16,
      footerPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          PrimaryButton(
            label: done
                ? 'Uploaded'
                : (_uploading ? (_stageLabel ?? 'Uploading…') : 'Retry upload now'),
            leading: done ? AppIcons.check : AppIcons.upload,
            radius: 999,
            onTap: _retry,
          ),
          SoftButton(
            label: 'Keep practising offline',
            height: 52,
            fontSize: 15,
            expand: true,
            bg: t.raised,
            onTap: () => context.replace(Routes.myRecordings),
          ),
        ],
      ),
      children: [
        Row(
          children: [
            IconBox(
              icon: AppIcons.back,
              size: 56,
              radius: 20,
              iconSize: 20,
              tooltip: 'Back',
              onTap: () => context.back(),
            ),
            Expanded(
              child: Text(
                pending.s('title'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 56),
          ],
        ),
        _OfflineBanner(uploading: _uploading, done: done),
        HeroCard(
          radius: 32,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        Text(
                          'Saved on this phone',
                          style: TextStyle(fontSize: 12, color: t.heroMuted),
                        ),
                        Text(
                          pending.s('cardTitle'),
                          style: TextStyle(fontSize: 22, height: 1.2, color: t.heroText),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    clockShort(pending.i('spokenSec')),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: t.heroText,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              BarWave(
                heights: _data.ld('wave'),
                color: t.isNight ? t.heroMuted : t.heroText,
                height: 34,
                barWidth: 3,
                gap: 2,
              ),
              ProgressBar(value: _progress, height: 6, onHero: true),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Uploaded ${(_progress * 100).round()}% · '
                      '${uploaded.toStringAsFixed(1)} of ${total.toStringAsFixed(1)} MB',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: t.heroMuted),
                    ),
                  ),
                  Text(
                    _data.b('autoRetry') ? 'Auto-retry on' : 'Auto-retry off',
                    style: TextStyle(fontSize: 12, color: t.heroMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        AppCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Upload queue',
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ),
              for (var i = 0; i < queue.length; i++)
                ListRow(
                  divider: true,
                  title: queue[i].s('title'),
                  subtitle: queue[i].s('meta'),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: t.surfaceAlt2,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(AppIcons.mic, size: 18, color: t.text),
                  ),
                  trailing: (i < _status.length && _status[i] == 'waiting')
                      ? Container(
                          height: 26,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: t.alert),
                          ),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              _uploading ? 'Uploading' : 'Waiting',
                              style: TextStyle(fontSize: 11, color: t.alert),
                            ),
                          ),
                        )
                      : Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: t.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(AppIcons.check, size: 14, color: t.onPrimary),
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "2 min 4 s" / "38 s".
String _durationWords(int sec) =>
    sec >= 60 ? '${sec ~/ 60} min ${sec % 60} s' : '$sec s';

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.uploading, required this.done});

  final bool uploading;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final title = done
        ? 'Back online'
        : (uploading ? 'Reconnecting…' : 'You’re offline');
    final sub = done
        ? 'Upload finished. Opening your report.'
        : 'Upload paused. Nothing has been lost.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.isNight ? t.dangerSoft : t.alert.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: t.isNight ? const Color(0xFF5C2A20) : t.border,
        ),
      ),
      child: Row(
        spacing: 12,
        children: [
          Icon(done ? AppIcons.checkCircleOutline : AppIcons.cloudOff, size: 22, color: t.alert),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: t.isNight ? const Color(0xFFFFB3A1) : t.alert,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 12,
                    color: t.isNight ? const Color(0xFFC9A097) : t.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
