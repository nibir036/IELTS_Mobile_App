# IELTS AI by nextED

Flutter app for IELTS preparation — Listening, Reading, Writing, Speaking,
full mock exams, resources and an in-app community.

## Current stage: design build (demo data)

The UI is a screen-for-screen build of the **IELTS Platform — Day & Night**
canvas (75 screens, rows A–H, each in Day and Night mode). The database / API
layer is disconnected: every screen reads from
`assets/demo/demo_data.json`.

```
lib/
  main.dart                 loads demo data, runs IeltsAiApp
  app/
    app.dart                MaterialApp, theme mode, route table
    routes.dart             Routes.* for every screen + ScreenCatalog (A1…H11)
    nav.dart                context.push / replace / resetTo / back / toast
    data/demo.dart          Demo.section('writing'), Demo.user, JSON helpers
    theme/                  Day/Night tokens (context.tk), ThemeData, controller
    widgets/                shared kit (cards, buttons, chips, progress…) + AppIcons
  features/
    shell/                  bottom-nav shell: Home · Practice · Mock · Community · Profile
    access/   (A1–A8)       splash, login, sign-up, OTP, reset, onboarding
    home/     (B1–B8)       dashboard, module hub, analytics, schedule, notifications, profile, search
    writing/  (C1–C13)
    speaking/ (D1–D10)
    reading/  (E1–E6)
    listening/(F1–F8)
    mock/     (G1–G11)
    resources/(H1–H11)      resources + community
    gallery/                Profile › Screen gallery: open any screen by its canvas code
```

Demo JSON top-level keys: `user`, `access`, `home`, `writing`, `speaking`,
`reading`, `listening`, `mock`, `resources` — shaped to become the seed data
in the database phase.

Theme: switch Day/Night on the splash screen or in Profile.

## Run

```
flutter pub get
flutter run
```
