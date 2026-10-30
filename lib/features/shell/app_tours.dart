import '../../app/services/nexted_api.dart';
import '../../app/widgets/app_tour.dart';
import '../../app/widgets/mascot.dart';

// The two first-time tours, step by step (engine: app/widgets/app_tour.dart).
// Each `target` is a TourTarget id placed on that screen; "tap" steps are
// the student tapping the real tab, so they end up on the page the next
// step talks about.

/// The IELTS side (MainShell), shown once the first time it opens.
List<TourStep> ieltsTour() => <TourStep>[
      const TourStep(
        title: 'Welcome to nextED',
        body: 'I’m Nexy, your IELTS coach. Let me show you around - it takes a minute, '
            'and you tap through it yourself.',
        pose: NexyPose.wave,
        button: 'Show me',
      ),
      const TourStep(
        target: 'home.hero',
        title: 'Your band starts here',
        body: 'Set your target band and exam date, then build a study plan that fits the days you have left.',
        radius: 32,
      ),
      const TourStep(
        target: 'home.tools',
        title: 'Quick wins, any time',
        body: 'Vocab quizzes, linking words and pronunciation drills. Five minutes here still moves your band.',
        pose: NexyPose.thumbs,
      ),
      const TourStep(
        target: 'nav.practice',
        title: 'Now let’s practise',
        body: 'Tap Practice to see every module.',
        action: TourAction.tap,
        radius: 30,
        pad: 2,
      ),
      const TourStep(
        target: 'practice.modules',
        title: 'Pick a skill',
        body: 'Listening, Reading, Writing and Speaking - full tests, short drills and instant AI band scores with feedback.',
        pose: NexyPose.reading,
      ),
      const TourStep(
        target: 'nav.mock',
        title: 'Full mock tests',
        body: 'Tap Mock. This is where you sit the whole exam.',
        action: TourAction.tap,
        radius: 30,
        pad: 2,
      ),
      const TourStep(
        target: 'mock.new',
        title: 'The real exam, at home',
        body: 'Tap + to start a full computer-based mock with real timing. Your band comes back for every section.',
        pose: NexyPose.grad,
      ),
      const TourStep(
        target: 'nav.profile',
        title: 'Your profile',
        body: 'Tap Profile. Your plan, reminders and settings live here.',
        action: TourAction.tap,
        radius: 30,
        pad: 2,
      ),
      const TourStep(
        target: 'profile.plan',
        title: 'Go Pro when you’re ready',
        body: 'See what Pro unlocks and pick a pass that fits your exam date.',
        radius: 20,
      ),
      const TourStep(
        target: 'profile.tour',
        title: 'See this again',
        body: 'Replay this tour any time from App tour.',
        radius: 20,
      ),
      TourStep(
        target: 'switch.abroad',
        title: 'Study abroad, one tap away',
        body: 'Courses, scholarships and a counsellor who knows your band. Tap this whenever you’re ready.',
        pose: NexyPose.grad,
        radius: 28,
        when: () => NextedAccess.I.enabled,
      ),
      const TourStep(
        target: 'nav.home',
        title: 'Back to Home',
        body: 'Tap Home to finish.',
        action: TourAction.tap,
        radius: 30,
        pad: 2,
      ),
      const TourStep(
        title: 'You’re all set',
        body: 'Start with your study plan. I’ll remind you every day, and every practice gets you closer to your band.',
        pose: NexyPose.thumbs,
        button: 'Let’s go',
      ),
    ];

/// The study-abroad side (NextedShell), shown once the first time it opens.
List<TourStep> abroadTour() => const <TourStep>[
      TourStep(
        title: 'Your study abroad journey',
        body: 'From choosing a country to boarding the plane, nextED is with you at every step. '
            'Here’s a quick look.',
        pose: NexyPose.grad,
        button: 'Show me',
      ),
      TourStep(
        target: 'abroad.hero',
        title: 'Your file at a glance',
        body: 'Complete your profile once. The counsellor, course matching and scholarships all work from it.',
        radius: 30,
      ),
      TourStep(
        target: 'abroad.match',
        title: 'Find where you fit',
        body: 'Ask the AI counsellor, get courses ranked for you, and see the scholarships you can win.',
        pose: NexyPose.thumbs,
      ),
      TourStep(
        target: 'abroad.nav.guidance',
        title: 'The whole road',
        body: 'Tap Guidance.',
        action: TourAction.tap,
        radius: 30,
        pad: 2,
      ),
      TourStep(
        target: 'guidance.first',
        title: 'Eight steps to campus',
        body: 'Everything in the order it happens, and what to do at each step.',
        pose: NexyPose.reading,
      ),
      TourStep(
        target: 'abroad.nav.documents',
        title: 'Your documents',
        body: 'Tap Documents.',
        action: TourAction.tap,
        radius: 30,
        pad: 2,
      ),
      TourStep(
        target: 'documents.upload',
        title: 'Upload once',
        body: 'Passport, transcripts and certificates - PDF, JPG or PNG up to 10 MB. Your counsellor sees '
            'them straight away, and you can replace any file later.',
        radius: 30,
      ),
      TourStep(
        target: 'abroad.nav.counsellor',
        title: 'Your counsellor, any time',
        body: 'Tap here to ask about countries, costs and visas. It already knows your profile.',
        radius: 30,
        pad: 2,
      ),
      TourStep(
        target: 'abroad.nav.profile',
        title: 'Your profile',
        body: 'Tap Profile.',
        action: TourAction.tap,
        radius: 30,
        pad: 2,
      ),
      TourStep(
        target: 'abroad.profile.save',
        title: 'The more you add, the better',
        body: 'Fields marked * power course matching and scholarships. Save when you’re done.',
        pose: NexyPose.writing,
        radius: 30,
      ),
      TourStep(
        target: 'abroad.nav.home',
        title: 'Back to Home',
        body: 'Tap Home.',
        action: TourAction.tap,
        radius: 30,
        pad: 2,
      ),
      TourStep(
        target: 'switch.ielts',
        title: 'Need a higher band?',
        body: 'Jump back to IELTS practice from here. A better band opens more universities.',
        pose: NexyPose.reading,
        radius: 28,
      ),
      TourStep(
        title: 'You’re ready',
        body: 'Start with your profile. It takes five minutes and unlocks everything else.',
        pose: NexyPose.thumbs,
        button: 'Let’s go',
      ),
    ];
