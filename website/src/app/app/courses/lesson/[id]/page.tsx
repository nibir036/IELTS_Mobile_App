import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { LessonPlayer } from '@/components/lesson-player';
import { MODULE_NAMES } from '@/lib/content/lang';
import type { LessonView, StepView } from '@/lib/content/lesson-view';
import { moduleContent, type ModuleContent } from '@/lib/server/content';
import { findLesson, lessonsOf, nextIn } from '@/lib/server/lessons';
import { getMe } from '@/lib/server/me';
import { writingPrompt } from '@/lib/server/writing';

export const metadata: Metadata = { title: 'Lesson' };

type Raw = Record<string, unknown>;
const list = (v: unknown): Raw[] => (Array.isArray(v) ? (v.filter((x) => x && typeof x === 'object') as Raw[]) : []);
const arr = (v: unknown): unknown[] => (Array.isArray(v) ? v : []);
const num = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? v : Number(v) || 0);

/** Where a lesson's "practice" item opens on the web (homeRouteFor). */
function practiceHref(target: string, args: Raw): string {
  const part = num(args.part);
  switch (target) {
    case 'cueCardVault':
      return '/app/speaking/cards';
    case 'listeningLibrary':
    case 'listeningMiniList':
    case 'listeningLanding':
      return '/app/listening';
    case 'myRecordings':
      return '/app/speaking/history';
    case 'readingBank':
    case 'readingPracticeTests':
    case 'readingLanding':
      return '/app/reading';
    case 'speakingPart13':
    case 'speakingQuestions':
      return part === 3 ? '/app/speaking/part3' : part === 2 ? '/app/speaking/cards' : '/app/speaking/part1';
    case 'speakingHub':
      return '/app/speaking';
    case 'vocabQuiz':
      return '/app/resources/vocab-quiz';
    case 'vocabVault':
      return '/app/resources/words';
    case 'writingSelector':
      return '/app/writing';
    case 'writingSampleAnswer':
      return '/app/writing/samples';
    default:
      return '';
  }
}

async function resolveStep(mc: ModuleContent, st: Raw): Promise<StepView> {
  const t = mc.text;
  switch (String(st.type)) {
    case 'choice':
      return {
        type: 'choice',
        title: t(st.title),
        prompt: t(st.prompt),
        passage: typeof st.passage === 'string' ? st.passage : '',
        options: arr(st.options).map((o) => ({ text: t(o), sub: o && typeof o === 'object' ? t((o as Raw).sub) : '' })),
        answer: num(st.answer),
        right: t(st.right),
        explain: t(st.explain),
        bars: list(st.bars).map((b) => ({ label: String(b.label ?? ''), value: num(b.value), text: String(b.text ?? '') })),
      };
    case 'roadmap':
      return { type: 'roadmap', title: t(st.title), items: arr(st.items).map(t), note: t(st.note) };
    case 'concepts':
      return {
        type: 'concepts',
        title: t(st.title),
        intro: t(st.intro),
        cards: list(st.cards).map((c) => ({ icon: String(c.icon ?? ''), title: t(c.title), body: t(c.body) })),
      };
    case 'contrast': {
      const ex = (e: unknown) => {
        const m = (e && typeof e === 'object' ? e : {}) as Raw;
        return { label: t(m.label), text: String(m.text ?? ''), mark: String(m.mark ?? '') };
      };
      return { type: 'contrast', title: t(st.title), intro: t(st.intro), weak: ex(st.weak), strong: ex(st.strong), tip: t(st.tip) };
    }
    case 'read': {
      const title = t(st.title);
      let blocks = mc.blocks(String(st.chapter ?? ''), num(st.from), num(st.to)) as unknown[][];
      // Don't repeat the card title when the slice starts with that heading.
      if (title && blocks.length && (blocks[0][0] === 'h' || blocks[0][0] === 'h2')) blocks = blocks.slice(1);
      return { type: 'read', title, blocks };
    }
    case 'practice': {
      const pid = String(st.promptId ?? '');
      const prompt = pid ? await writingPrompt(pid).catch(() => null) : null;
      return {
        type: 'practice',
        title: t(st.title),
        task: t(st.task),
        prompt: prompt?.prompt ?? '',
        items: list(st.items)
          .map((it) => {
            const action = String(it.action ?? '');
            const href = it.target
              ? practiceHref(String(it.target), (it.args ?? {}) as Raw)
              : action === 'write' && prompt
                ? `/app/writing/write/${encodeURIComponent(prompt.id)}`
                : '';
            return { text: t(it), minutes: num(it.minutes), href, action };
          })
          .filter((it) => it.href || it.action === 'plan' || it.action === 'check'),
        plan: arr(st.plan).map(t),
        tip: t(st.tip),
      };
    }
    case 'sampleFeedback':
      return {
        type: 'sampleFeedback',
        title: t(st.title),
        intro: t(st.intro),
        band: num(st.band),
        criteria: list(st.criteria).map((c) => ({ name: String(c.name ?? ''), band: num(c.band) })),
        good: arr(st.good).map(t),
        improve: arr(st.improve).map(t),
      };
    default:
      return { type: 'unknown' };
  }
}

/** One lesson (lesson_screen.dart): cover → steps → completion with XP. */
export default async function LessonPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const found = await findLesson(decodeURIComponent(id));
  if (!found) notFound();
  const { ref, course } = found;
  const [mc, me] = await Promise.all([moduleContent(ref.module), getMe()]);
  const l = ref.lesson;
  const t = mc.text;
  const steps = (await Promise.all(list(l.steps).map((s) => resolveStep(mc, s)))).filter((s) => s.type !== 'unknown');
  const titleRaw = l.title;
  const english =
    titleRaw && typeof titleRaw === 'object'
      ? (() => {
          const m = titleRaw as Raw;
          const part = num(m.part);
          return `${String(m.en ?? '')}${part > 1 ? ` · Part ${part}` : ''}`;
        })()
      : String(titleRaw ?? '');
  const learned = arr(l.learned).map(t).filter(Boolean);
  const nx = nextIn(ref.module, course, ref.id);
  const view: LessonView = {
    id: ref.id,
    module: ref.module,
    moduleName: MODULE_NAMES[ref.module] ?? ref.module,
    stageId: String(ref.stage.id ?? ''),
    stageIndex: ref.stageIndex,
    lessonIndex: ref.lessonIndex,
    stageLessons: ref.stageLessons,
    stageLessonIds: lessonsOf(ref.stage).map((x) => String(x.id)),
    title: t(l.title),
    english,
    intro: t(l.intro) || t(ref.stage.subtitle),
    greeting: t(l.greeting),
    minutes: num(l.minutes),
    xp: num(l.xp) > 0 ? num(l.xp) : 20,
    learned: learned.length ? learned : [...new Set(steps.map((s) => ('title' in s ? s.title : '')).filter(Boolean))],
    steps,
    next: nx
      ? {
          id: nx.id,
          title: t(nx.lesson.title),
          stageIndex: nx.stageIndex,
          lessonIndex: nx.lessonIndex,
          stageLessons: nx.stageLessons,
          minutes: num(nx.lesson.minutes),
          sameStage: String(nx.stage.id) === String(ref.stage.id),
        }
      : null,
    lang: mc.lang.code,
    langs: mc.langs,
    rtl: Boolean(mc.lang.rtl),
    firstName: me.user.name.trim().split(/\s+/)[0] ?? '',
  };
  return <LessonPlayer key={view.id} lesson={view} />;
}
