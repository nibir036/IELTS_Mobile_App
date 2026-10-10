/// Every screen in the canvas has a route here. Codes (A1 … H11) match the
/// artboard names on the "IELTS Platform - Day & Night" canvas.
///
/// Navigate with `context.push(Routes.x)` (see nav.dart).
class Routes {
  Routes._();

  // Shell (bottom navigation). Tabs: 0 Home · 1 Practice · 2 Mock · 3 Community · 4 Profile
  static const home = '/home';
  static const gallery = '/gallery';

  // A · Access & Onboarding
  static const splash = '/'; // A1
  static const login = '/login'; // A2
  static const signup = '/signup'; // A3
  static const otp = '/otp'; // A4
  static const resetPassword = '/reset-password'; // A5
  static const targetBand = '/onboarding/target-band'; // A6
  static const micPermission = '/onboarding/mic-permission'; // A8

  // B · Home & Account
  static const dashboard = '/home/dashboard'; // B1 (tab 0)
  static const dashboardEmpty = '/home/first-time'; // B2
  static const moduleHub = '/home/modules'; // B3 (tab 1)
  static const analytics = '/home/analytics'; // B4
  static const schedule = '/home/schedule'; // B5
  static const notifications = '/home/notifications'; // B6
  static const profile = '/home/profile'; // B7 (tab 4)
  static const search = '/search'; // B8

  // C · Writing
  static const writingSelector = '/writing'; // C1
  static const writingTask1Editor = '/writing/task1'; // C2
  static const writingEditor = '/writing/task2'; // C3
  static const writingLineReview = '/writing/line-review'; // C4
  static const writingBandReport = '/writing/band-report'; // C5
  static const writingRewriter = '/writing/rewriter'; // C6
  static const sentenceBuilder = '/writing/sentence-builder'; // C7
  static const masterclass = '/writing/masterclass'; // C8
  static const essayHistory = '/writing/history'; // C9
  static const writingTemplate = '/writing/template'; // C10
  static const ideasTopics = '/writing/ideas'; // C11
  static const writingFeedbackLoading = '/writing/feedback-loading'; // C12
  static const writingSampleAnswer = '/writing/sample-answer'; // C13

  // D · Speaking
  static const speakingHub = '/speaking'; // D1
  static const speakingPart13 = '/speaking/part-1-3'; // D2
  static const cueCard = '/speaking/cue-card'; // D3
  static const speakingRecording = '/speaking/recording'; // D4
  static const speakingTranscript = '/speaking/transcript'; // D5
  static const speakingEvaluation = '/speaking/evaluation'; // D6
  static const pronunciation = '/speaking/pronunciation'; // D7
  static const cueCardVault = '/speaking/vault'; // D8
  static const uploadFailed = '/speaking/upload-failed'; // D9
  static const myRecordings = '/speaking/recordings'; // D10
  static const speakingLibrary = '/speaking/library'; // D11
  static const speakingSamples = '/speaking/samples'; // D12

  // E · Reading
  static const readingLibrary = '/reading/library'; // E1
  static const readingPassage = '/reading/passage'; // E2
  static const readingQuestions = '/reading/questions'; // E3
  static const readingSolution = '/reading/solution'; // E4
  static const readingLanding = '/reading'; // E5
  static const readingLesson = '/reading/lesson'; // E6

  // F · Listening
  static const listeningLibrary = '/listening/library'; // F1
  static const listeningPlayer = '/listening/player'; // F2
  static const listeningAnswerSheet = '/listening/answer-sheet'; // F3
  static const listeningTranscript = '/listening/transcript'; // F4
  static const listeningLanding = '/listening'; // F5
  static const listeningLesson = '/listening/lesson'; // F6
  static const listeningMiniList = '/listening/mini-practice'; // F7
  static const listeningResults = '/listening/results'; // F8

  // G · Full Mock Exam
  static const mockLibrary = '/mock'; // G1 (tab 2)
  static const mockSystemCheck = '/mock/system-check'; // G2
  static const mockListening = '/mock/listening'; // G3
  static const mockTransition = '/mock/transition'; // G4
  static const mockEnvironment = '/mock/reading'; // G5
  static const mockWriting = '/mock/writing'; // G6
  static const mockSpeaking = '/mock/speaking'; // G7
  static const mockScoring = '/mock/scoring'; // G8
  static const mockResults = '/mock/results'; // G9
  static const improvementPlan = '/mock/improvement-plan'; // G10
  static const mockExitWarning = '/mock/exit-warning'; // G11

  // H · Resources & Community
  static const resourcesHub = '/resources'; // H1
  static const vocabVault = '/resources/vault'; // H2
  static const community = '/community'; // H3 (tab 3)
  static const speakingRoomChat = '/community/room'; // H4
  static const vocabQuiz = '/resources/quiz'; // H5
  static const vocabQuizScore = '/resources/quiz-score'; // H6
  static const academicWords = '/resources/academic-words'; // H7
  static const irregularVerbs = '/resources/irregular-verbs'; // H8
  static const scoringCriteria = '/resources/scoring-criteria'; // H10
  static const articleTips = '/resources/article'; // H11

  // Extra screens (not on the canvas; built in Phase 3)
  static const phrasalVerbs = '/resources/phrasal-verbs';
  static const idioms = '/resources/idioms';
  static const topicVocab = '/resources/topic-vocabulary';
  static const vocabGuide = '/resources/vocab-lessons';
  static const listeningGuide = '/listening/guide';
  static const writingTests = '/writing/tests'; // Writing Test 1–10
  static const speakingTests = '/speaking/tests'; // Speaking Test 1–10
  static const writingQuestions = '/writing/questions'; // {'task': 1|2}
  static const speakingQuestions = '/speaking/questions'; // {'part': 1|2|3}
  static const certificates = '/home/certificates';
  static const notificationSettings = '/home/notification-settings';
  static const legal = '/legal'; // args {'doc': 'terms' | 'privacy'}

  // Phase 4
  static const mockAnswers = '/mock/answers'; // args {'attemptId': …}
  static const plans = '/home/plans';

  // Personal study plan
  static const studyPlan = '/home/study-plan';
  static const studyPlanSetup = '/home/study-plan/setup'; // args {'edit': true} to change the current plan
  static const studyPlanPreview = '/home/study-plan/preview'; // args {'inputs': {...}}
  static const studyPlanQuickCheck = '/home/study-plan/quick-check'; // args {'modules': [...]}

  // Reading question bank
  static const readingBank = '/reading/bank'; // question types + short tests
  static const readingType = '/reading/bank/type'; // args {'type': 'headings'}
  static const readingTypeLesson = '/reading/bank/lesson'; // args {'type': …}
  static const readingPracticeTests = '/reading/bank/tests';
  static const readingGuide = '/reading/guide'; // args {'chapter': id} (none = contents)
  static const writingGuide = '/writing/guide'; // args {'chapter': id} (none = contents)

  // Bite-sized courses (stages → lessons → steps)
  static const course = '/course'; // args {'module': 'writing'}
  static const writingCourse = '/course/writing';
  static const speakingCourse = '/course/speaking';
  static const readingCourse = '/course/reading';
  static const listeningCourse = '/course/listening';
  static const grammarCourse = '/course/grammar';
  static const vocabCourse = '/course/vocab';
  static const lesson = '/course/lesson'; // args {'lesson': id}
  static const speakingGuide = '/speaking/guide'; // args {'chapter': id} (none = contents)
  static const grammarGuide = '/resources/grammar'; // args {'chapter': id} (none = contents)

  /// Routes that open the bottom-nav shell on a given tab.
  static const tabRoutes = <String, int>{
    home: 0,
    dashboard: 0,
    moduleHub: 1,
    mockLibrary: 2,
    community: 3,
    profile: 4,
  };
}

/// One entry of the in-app screen gallery (Profile › Screen gallery).
class ScreenSpec {
  const ScreenSpec(this.code, this.title, this.route);
  final String code;
  final String title;
  final String route;
}

class ScreenCatalog {
  ScreenCatalog._();

  static const rows = <String, String>{
    'A': 'Access & Onboarding',
    'B': 'Home & Account',
    'C': 'Writing',
    'D': 'Speaking',
    'E': 'Reading',
    'F': 'Listening',
    'G': 'Full Mock Exam',
    'H': 'Resources & Community',
  };

  static const all = <ScreenSpec>[
    ScreenSpec('A1', 'Splash & Welcome', Routes.splash),
    ScreenSpec('A2', 'Login', Routes.login),
    ScreenSpec('A3', 'Sign Up', Routes.signup),
    ScreenSpec('A4', 'OTP Verification', Routes.otp),
    ScreenSpec('A5', 'Forgot / Reset Password', Routes.resetPassword),
    ScreenSpec('A6', 'Target Band Setup', Routes.targetBand),
    ScreenSpec('A8', 'Microphone Permission', Routes.micPermission),
    ScreenSpec('B1', 'Main Student Dashboard', Routes.dashboard),
    ScreenSpec('B2', 'Dashboard - First-Time Empty State', Routes.dashboardEmpty),
    ScreenSpec('B3', 'Course & Module Hub', Routes.moduleHub),
    ScreenSpec('B4', 'Study Analytics', Routes.analytics),
    ScreenSpec('B5', 'Schedule & Deadlines', Routes.schedule),
    ScreenSpec('B6', 'Notifications & Activity', Routes.notifications),
    ScreenSpec('B7', 'Profile & Settings', Routes.profile),
    ScreenSpec('B8', 'Search', Routes.search),
    ScreenSpec('C1', 'Writing Task Selector', Routes.writingSelector),
    ScreenSpec('C2', 'Writing Task 1 Prompt & Editor', Routes.writingTask1Editor),
    ScreenSpec('C3', 'Task Prompt & Editor', Routes.writingEditor),
    ScreenSpec('C4', 'Live AI Line-by-Line Review', Routes.writingLineReview),
    ScreenSpec('C5', 'Writing Band Score Report', Routes.writingBandReport),
    ScreenSpec('C6', 'AI Essay Rewriter & Band Comparison', Routes.writingRewriter),
    ScreenSpec('C7', 'Sentence Builder Drill', Routes.sentenceBuilder),
    ScreenSpec('C8', 'Paragraph Structuring Masterclass', Routes.masterclass),
    ScreenSpec('C9', 'Saved Essay History', Routes.essayHistory),
    ScreenSpec('C10', 'Writing Template', Routes.writingTemplate),
    ScreenSpec('C11', 'IELTS Ideas & Topics Library', Routes.ideasTopics),
    ScreenSpec('C12', 'Writing AI Feedback Loading', Routes.writingFeedbackLoading),
    ScreenSpec('C13', 'Writing Sample Answer', Routes.writingSampleAnswer),
    ScreenSpec('D1', 'Speaking Hub & Mode Selection', Routes.speakingHub),
    ScreenSpec('D2', 'Speaking Part 1 & 3 Flow', Routes.speakingPart13),
    ScreenSpec('D3', 'Part 2 Cue Card Prompt', Routes.cueCard),
    ScreenSpec('D4', 'Live Audio Recording', Routes.speakingRecording),
    ScreenSpec('D5', 'Live Transcription & Error Highlight', Routes.speakingTranscript),
    ScreenSpec('D6', 'Speaking Evaluation & Band Report', Routes.speakingEvaluation),
    ScreenSpec('D7', 'Pronunciation & Intonation Trainer', Routes.pronunciation),
    ScreenSpec('D8', 'Cue Card Practice Vault', Routes.cueCardVault),
    ScreenSpec('D9', 'Offline / Upload Failed', Routes.uploadFailed),
    ScreenSpec('D10', 'Speaking My Recordings', Routes.myRecordings),
    ScreenSpec('D11', 'Speaking Question Bank & Vocabulary', Routes.speakingLibrary),
    ScreenSpec('D12', 'Speaking Sample Answers', Routes.speakingSamples),
    ScreenSpec('E1', 'Reading Test Library', Routes.readingLibrary),
    ScreenSpec('E2', 'Reading Passage View', Routes.readingPassage),
    ScreenSpec('E3', 'Reading Question Panel', Routes.readingQuestions),
    ScreenSpec('E4', 'Reading AI Solution & Paragraph Locator', Routes.readingSolution),
    ScreenSpec('E5', 'Reading Section Landing', Routes.readingLanding),
    ScreenSpec('E6', 'Reading Lesson & Exercise', Routes.readingLesson),
    ScreenSpec('F1', 'Listening Test Library', Routes.listeningLibrary),
    ScreenSpec('F2', 'Listening Audio Player', Routes.listeningPlayer),
    ScreenSpec('F3', 'Listening Interactive Answer Sheet', Routes.listeningAnswerSheet),
    ScreenSpec('F4', 'Listening Transcript & Audio Sync', Routes.listeningTranscript),
    ScreenSpec('F5', 'Listening Section Landing', Routes.listeningLanding),
    ScreenSpec('F6', 'Listening Bite-size Lesson', Routes.listeningLesson),
    ScreenSpec('F7', 'Listening Mini Practice List', Routes.listeningMiniList),
    ScreenSpec('F8', 'Listening Practice Results', Routes.listeningResults),
    ScreenSpec('G1', 'Mock Test Library & History', Routes.mockLibrary),
    ScreenSpec('G2', 'Mock Exam Instructions & System Check', Routes.mockSystemCheck),
    ScreenSpec('G3', 'Mock - Listening Section', Routes.mockListening),
    ScreenSpec('G4', 'Mock - Section Transition', Routes.mockTransition),
    ScreenSpec('G5', 'Full Simulation Test Environment', Routes.mockEnvironment),
    ScreenSpec('G6', 'Mock - Writing Section', Routes.mockWriting),
    ScreenSpec('G7', 'Mock - Speaking Section', Routes.mockSpeaking),
    ScreenSpec('G8', 'Mock - Scoring in Progress', Routes.mockScoring),
    ScreenSpec('G9', 'Final Mock Summary & Band Card', Routes.mockResults),
    ScreenSpec('G10', 'AI Actionable Improvement Plan', Routes.improvementPlan),
    ScreenSpec('G11', 'Mock Exit Confirm & Timer Warning', Routes.mockExitWarning),
    ScreenSpec('H1', 'Resources Hub', Routes.resourcesHub),
    ScreenSpec('H2', 'Grammar & Vocab Vault', Routes.vocabVault),
    ScreenSpec('H3', 'Community Channels', Routes.community),
    ScreenSpec('H4', 'Speaking Room Chat', Routes.speakingRoomChat),
    ScreenSpec('H5', 'Vocabulary Quiz - Question', Routes.vocabQuiz),
    ScreenSpec('H6', 'Vocabulary Quiz - Round Score', Routes.vocabQuizScore),
    ScreenSpec('H7', 'Academic Words Mastery', Routes.academicWords),
    ScreenSpec('H8', 'Irregular Verbs', Routes.irregularVerbs),
    ScreenSpec('H10', 'Scoring Criteria', Routes.scoringCriteria),
    ScreenSpec('H11', 'Article / Tips Page', Routes.articleTips),
  ];
}
