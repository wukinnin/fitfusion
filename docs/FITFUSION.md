**Overview**
- A mobile game for Android.
- A fitness-centered game that gamifies fitness activities.
- Aesthetically High Fantasy-inspired
- Motion Detection using the camera.
- Body is the controller similar to the Xbox Kinect. 
- Game is 2D rendered AR overlays.

---

*---START OF FORMAL PROJECT DETAIL---*

# General Objective:

This study aims to analyze, design, and develop "FitFusion", A platform for immersive fitness realities enhancing engagement through augmented gamification in digital workouts, to promote a meaningful exercise participation. 

# Specific Objectives:

Specifically, the study aims to:

1. Assess the current state of digital workout solutions, particularly:
    1. User engagement
    2. Interaction, and
    3. Retention.
2. Utilize mobile platforms to design interactive and immersive game-centric functionality, including:
    1. Motion-detection as an input data, and
    2. Augmented reality for game rendering.
3. Implement gamification elements to promote platform engagement, such as:
    1. Competitive Leaderboards
    2. Player Statistics
    3. Achievements

# Scope and Limitations

## Scope of the Study

The study focuses on the analysis, design, and development of Fitfusion: A digital platform that incorporates augmented reality (AR) and motion-tracking with interactive gamification elements, to promote meaningful exercise participation.

The scope of the study encompasses the implementation of core functionalities within a mobile-based platform, such as input data from motion detection, immersive game design fronted by AR, tied with gamified elements such as leaderboards, player statistics, and achievements. 

Central to the design of FitFusion is to create a unique solution utilizing smartphones, to primarily use in tandem; performance-sensitive camera-based motion detection as an input source, and visually engaging AR game design feedback to render output.

With all this, the platform will then tie in gamification elements promoting fitness. Competitive elements include ranked leaderboards, game achievements, and player statistics.

## Limitations of the Study

While FitFusion is designed to offer a unique digital platform for exercise enhancing measures in general, the study is limited in a few key areas.

The study is conducted within a specific group of users in mind, primarily the student populace from the University of Cebu Lapu-Lapu and Mandaue. As such, findings may not fully represent the general population in terms of age, physical ability, or access to advanced mobile technology.

The study is limited especially in regards to system design and development. This is largely due to time constraints and technical ability. Compromises and omissions have been made to account for these limitations.

Technical ability and time limits game rendering to 2D AR renders only. 3D rendering is omitted as the current project's limitations.

Complex multiplayer, including both online and local forms are omitted. As such, FitFusion is strictly a single-player game experience. Only a selected amount of workouts are available to perform at a time, so a session of gameplay is limited to only one specific type of exercise at any given moment.

Any sort of complex personalization will be omitted. This would include setting gender, height/weight parameters, BMI, physical build, etc. The system is disregarding such metrics with the platform.

Naturally, performance may vary depending on device compatibility, sensor accuracy, and physical environment, especially for features involving AR interaction and motion tracking. External factors such as lighting, movement, form, precision, and user connectivity are beyond the scope of this study and may affect the overall experience and results.

*---END OF FORMAL PROJECT DETAIL---*

---

*---START OF AUTHOR ANNOTATIONS--*

# Objectives Breakdown:

- "Immersive" in this context overall, means the fact that you have to immerse yourself to exercise in order to play the game.
- "Augmented Gamification" is how we render the game elements, like hud, sprites, etc.

# Game design at GAMEPLAY.md

---

# Development:

**Platform & Language**
- **Flutter** (Dart) — the app framework. Builds and deploys to Android to Linux machine.

**Game Layer**
- **Flame** — 2D game engine that runs inside Flutter. Handles the game loop, sprites, health bars, boss components, and all game logic.

**Motion Input**
- **Google ML Kit Pose Detection** — runs on-device. Reads the camera feed and returns 33 body landmark positions per frame.
- **camera** (Flutter package) — gives access to the phone's camera and streams frames into ML Kit.

**Backend & Auth**
- **Firebase** — the entire backend.
- **Firebase Auth** — handles identity. Google Sign-In is the only provider.
- **Google Sign-In** — the actual OAuth flow users interact with.
- **Cloud Firestore** — Stores leaderboard entries, achievements, and user session statistics.
- **FlutterFire** — the bridge layer that connects your Flutter app to Firebase.

**Dev Environment**
- **Windsurf** — primary code editor for vibe-coding.
- **Git + GitHub** — version control. Repo at https://www.github.com/wukinnin/fitfusion
- **Fedora Linux 43** — host OS on Thinkpad T470.
- **Android SDK (cmd-line tools)** (command-line tools, API 35 / Android 14) — compiles and deploys APKs.
- **OpenJDK 21**
- **Gradle 8**
- **ADB** (Android Debug Bridge) — physical and wireless connection to the Tecno Spark Go 30c.

*---END OF AUTHOR ANNOTATIONS--*

---
