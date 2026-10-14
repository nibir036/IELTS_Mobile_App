// App routes (lib/app/routes.dart) and home.json `target` keys
// (lib/features/home/widgets.dart › homeRouteFor) → website pages. Stored
// links (tasks, notifications, the "resume" card) hold app routes, so the
// web opens the matching page. '' = no web page for it.

type Args = Record<string, unknown> | null | undefined;

const s = (v: unknown) => (v == null ? '' : String(v));
const enc = (v: unknown) => encodeURIComponent(s(v));

/** The web page for an app route + args. */
export function appHref(route: string, args?: Args): string {
  const a = (args ?? {}) as Record<string, unknown>;
  const id = (k: string) => s(a[k]);
  const guide = (m: string) => (id('chapter') ? `/app/guides/${m}/${enc(a.chapter)}` : `/app/guides/${m}`);
  switch (route) {
    case '/home':
    case '/home/dashboard':
    case '/home/first-time':
      return '/app';
    case '/home/modules':
      return '/app/practice';
    case '/home/analytics':
      return '/app/analytics';
    case '/home/schedule':
      return '/app/schedule';
    case '/home/notifications':
      return '/app/notifications';
    case '/home/notification-settings':
      return '/app/notifications/settings';
    case '/home/profile':
      return '/app/profile';
    case '/search':
      return '/app/search';
    case '/home/certificates':
      return '/app/certificates';
    case '/home/plans':
      return '/app/upgrade';
    case '/home/devices':
      return '/app/profile/devices';
    case '/home/study-plan':
    case '/home/study-plan/preview':
      return '/app/plan';
    case '/home/study-plan/setup':
      return '/app/plan/setup';
    case '/home/study-plan/quick-check':
      return '/app/plan/quick-check';
    case '/onboarding/target-band':
      return '/app/onboarding/target-band';
    case '/legal':
      return id('doc') === 'privacy' ? '/privacy' : '/terms';

    // Writing
    case '/writing':
      return '/app/writing';
    case '/writing/task1':
      return id('promptId') ? `/app/writing/write/${enc(a.promptId)}` : '/app/writing/questions/1';
    case '/writing/task2':
      return id('promptId') ? `/app/writing/write/${enc(a.promptId)}` : '/app/writing/questions/2';
    case '/writing/questions':
      return `/app/writing/questions/${Number(a.task) === 1 ? 1 : 2}`;
    case '/writing/band-report':
    case '/writing/line-review':
    case '/writing/feedback-loading':
      return id('attemptId') ? `/app/writing/result/${enc(a.attemptId)}` : '/app/writing/history';
    case '/writing/rewriter':
      return id('attemptId') ? `/app/writing/rewrite/${enc(a.attemptId)}` : '/app/writing/history';
    case '/writing/sentence-builder':
      return id('set') ? `/app/writing/sentence-builder?set=${enc(a.set)}` : '/app/writing/sentence-builder';
    case '/writing/masterclass':
      return '/app/writing/lessons';
    case '/writing/history':
      return '/app/writing/history';
    case '/writing/template':
      return '/app/writing/templates';
    case '/writing/ideas':
      return '/app/writing/ideas';
    case '/writing/sample-answer':
      return id('promptId') ? `/app/writing/samples/${enc(a.promptId)}` : '/app/writing/samples';
    case '/writing/tests':
      return '/app/writing/tests';
    case '/writing/guide':
      return guide('writing');

    // Speaking
    case '/speaking':
    case '/speaking/library':
      return '/app/speaking';
    case '/speaking/part-1-3':
      if (Number(a.part) === 3) return id('part3TopicId') || id('topicId') ? `/app/speaking/session/3/${enc(a.part3TopicId ?? a.topicId)}` : '/app/speaking/part3';
      return id('topicId') ? `/app/speaking/session/1/${enc(a.topicId)}` : '/app/speaking/part1';
    case '/speaking/cue-card':
      return id('cardId') ? `/app/speaking/cue/${enc(a.cardId)}` : '/app/speaking/cards';
    case '/speaking/evaluation':
    case '/speaking/transcript':
      return id('attemptId') ? `/app/speaking/result/${enc(a.attemptId)}` : '/app/speaking/history';
    case '/speaking/pronunciation':
      return '/app/speaking/pronunciation';
    case '/speaking/vault':
      return '/app/speaking/cards';
    case '/speaking/recordings':
      return '/app/speaking/history';
    case '/speaking/samples':
    case '/speaking/questions': {
      const part = Number(a.part);
      if (part === 2) return id('cardId') ? `/app/speaking/cue/${enc(a.cardId)}` : '/app/speaking/cards';
      return part === 3 ? '/app/speaking/part3' : '/app/speaking/part1';
    }
    case '/speaking/tests':
      return '/app/speaking/tests';
    case '/speaking/guide':
      return guide('speaking');

    // Reading
    case '/reading':
    case '/reading/library':
    case '/reading/lesson':
    case '/reading/bank':
    case '/reading/bank/tests':
      return '/app/reading';
    case '/reading/passage':
    case '/reading/questions':
      return id('testId') ? `/app/reading/do/${enc(a.testId)}` : id('passageId') ? `/app/reading/do/${enc(a.passageId)}` : '/app/reading';
    case '/reading/solution':
      return id('attemptId') ? `/app/reading/result/${enc(a.attemptId)}` : '/app/reading/history';
    case '/reading/bank/type':
    case '/reading/bank/lesson':
      return id('type') ? `/app/reading/type/${enc(a.type)}` : '/app/reading';
    case '/reading/guide':
      return guide('reading');

    // Listening
    case '/listening':
    case '/listening/library':
    case '/listening/mini-practice':
    case '/listening/lesson':
      return '/app/listening';
    case '/listening/player':
    case '/listening/transcript':
      return id('setId') ? `/app/listening/set/${enc(a.setId)}` : '/app/listening';
    case '/listening/answer-sheet':
      return id('testId') ? `/app/listening/test/${enc(a.testId)}` : id('setId') ? `/app/listening/set/${enc(a.setId)}` : '/app/listening';
    case '/listening/results':
      return id('attemptId') ? `/app/listening/result/${enc(a.attemptId)}` : '/app/listening/history';
    case '/listening/guide':
      return guide('listening');

    // Mock tests
    case '/mock':
      return '/app/mocks';
    case '/mock/system-check':
      return id('mockId') ? `/app/mocks/${enc(a.mockId)}` : '/app/mocks';
    case '/mock/results':
    case '/mock/improvement-plan':
    case '/mock/answers':
      return id('attemptId') ? `/app/mocks/result/${enc(a.attemptId)}` : '/app/mocks';

    // Resources
    case '/resources':
      return '/app/resources';
    case '/resources/vault':
      return '/app/resources/words?saved=1';
    case '/resources/quiz':
    case '/resources/quiz-score':
      return '/app/resources/vocab-quiz';
    case '/resources/academic-words':
      return '/app/resources/words?tab=academic';
    case '/resources/irregular-verbs':
      return '/app/resources/words?tab=irregular';
    case '/resources/phrasal-verbs':
      return '/app/resources/words?tab=phrasal';
    case '/resources/idioms':
      return '/app/resources/words?tab=idioms';
    case '/resources/topic-vocabulary':
      return '/app/resources/words?tab=topics';
    case '/resources/scoring-criteria':
      return '/app/resources/scoring';
    case '/resources/article':
      return id('articleId') ? `/app/resources/article/${enc(a.articleId)}` : id('series') ? `/app/resources/tips/${enc(a.series)}` : '/app/resources/tips';
    case '/resources/vocab-lessons':
      return guide('vocab');
    case '/resources/grammar':
      return guide('grammar');

    // Community
    case '/community':
    case '/community/room':
      return '/app/community';

    // Courses
    case '/course':
      return id('module') ? `/app/courses/${enc(a.module)}` : '/app/courses';
    case '/course/lesson':
      return id('lesson') ? `/app/courses/lesson/${enc(a.lesson)}` : '/app/courses';
    default:
      if (route.startsWith('/course/')) return `/app/courses/${encodeURIComponent(route.slice('/course/'.length))}`;
      return '';
  }
}

/** home.json `target` key → app route (homeRouteFor). */
const TARGETS: Record<string, string> = {
  readingPassage: '/reading/passage',
  readingSolution: '/reading/solution',
  readingLanding: '/reading',
  readingLesson: '/reading/lesson',
  listeningLanding: '/listening',
  listeningResults: '/listening/results',
  listeningLesson: '/listening/lesson',
  writingSelector: '/writing',
  writingGuide: '/writing/guide',
  writingCourse: '/course/writing',
  speakingCourse: '/course/speaking',
  readingCourse: '/course/reading',
  listeningCourse: '/course/listening',
  grammarCourse: '/course/grammar',
  vocabCourse: '/course/vocab',
  readingGuide: '/reading/guide',
  speakingGuide: '/speaking/guide',
  grammarGuide: '/resources/grammar',
  writingTask1Editor: '/writing/task1',
  writingEditor: '/writing/task2',
  writingBandReport: '/writing/band-report',
  writingTemplate: '/writing/template',
  sentenceBuilder: '/writing/sentence-builder',
  masterclass: '/writing/masterclass',
  speakingHub: '/speaking',
  speakingEvaluation: '/speaking/evaluation',
  pronunciation: '/speaking/pronunciation',
  myRecordings: '/speaking/recordings',
  mockResults: '/mock/results',
  mockSystemCheck: '/mock/system-check',
  diagnosticTest: '/home/study-plan/setup',
  diagnostic: '/home/study-plan/setup',
  studyPlanSetup: '/home/study-plan/setup',
  vocabVault: '/resources/vault',
  vocabQuiz: '/resources/quiz',
  articleTips: '/resources/article',
  scoringCriteria: '/resources/scoring-criteria',
  speakingRoomChat: '/community/room',
  resourcesHub: '/resources',
  targetBand: '/onboarding/target-band',
  micPermission: '/onboarding/mic-permission',
  mockLibrary: '/mock',
  schedule: '/home/schedule',
  analytics: '/home/analytics',
  notifications: '/home/notifications',
  listeningLibrary: '/listening/library',
  listeningMiniList: '/listening/mini-practice',
  readingLibrary: '/reading/library',
  readingBank: '/reading/bank',
  readingPracticeTests: '/reading/bank/tests',
  cueCardVault: '/speaking/vault',
  speakingPart13: '/speaking/part-1-3',
  academicWords: '/resources/academic-words',
  irregularVerbs: '/resources/irregular-verbs',
  phrasalVerbs: '/resources/phrasal-verbs',
  idioms: '/resources/idioms',
  topicVocab: '/resources/topic-vocabulary',
  vocabGuide: '/resources/vocab-lessons',
  listeningGuide: '/listening/guide',
  writingTests: '/writing/tests',
  speakingTests: '/speaking/tests',
  writingQuestions: '/writing/questions',
  speakingQuestions: '/speaking/questions',
  ideasTopics: '/writing/ideas',
  writingSampleAnswer: '/writing/sample-answer',
  certificates: '/home/certificates',
  plans: '/home/plans',
};

export function targetRoute(key: string): string {
  return TARGETS[key] ?? '';
}

/** The web page for a home.json `target` key ('' when there is none). */
export function targetHref(key: string): string {
  const r = targetRoute(key);
  return r ? appHref(r) : '';
}

/** The app route of a skill's landing screen (skillLandingRoute) - stored in new tasks. */
export function skillLandingRoute(skill: string): string {
  switch (skill) {
    case 'listening':
      return '/listening';
    case 'reading':
      return '/reading';
    case 'writing':
      return '/writing';
    case 'speaking':
      return '/speaking';
    case 'mock':
      return '/mock/system-check';
    case 'vocab':
      return '/resources/vault';
    default:
      return '';
  }
}
