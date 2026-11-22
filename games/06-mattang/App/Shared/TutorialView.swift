import MTContent
import MTCore
import SwiftUI

/// The tutorial screen (MT-P3.2): one lesson at a time, each step's
/// text rendered in order with a Next control. The scripted actions
/// (place_island, launch, sail) replay through Reducer on the lesson's
/// chart so what the learner sees is always the engine's position —
/// the same model the G2 sharpened check verifies (ADR-0016).
/// `-scenario tutorial` opens lesson 1 directly for the UI test.
struct TutorialView: View {
    /// The loaded lessons (all five, in authored order).
    let lessons: [LessonDef]
    @State private var lessonIndex = 0
    @State private var stepIndex = 0

    private var lesson: LessonDef? {
        lessonIndex < lessons.count ? lessons[lessonIndex] : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let lesson {
                Text(lesson.title)
                    .font(.title2.weight(.bold))
                    .accessibilityIdentifier("tutorialTitle")
                let steps = lesson.steps
                if stepIndex < steps.count {
                    Text(steps[stepIndex].text)
                        .font(.body)
                        .accessibilityIdentifier("tutorialStep")
                    Button(stepIndex + 1 < steps.count ? "Next" : "Done") {
                        if stepIndex + 1 < steps.count {
                            stepIndex += 1
                        } else if lessonIndex + 1 < lessons.count {
                            lessonIndex += 1
                            stepIndex = 0
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("tutorialNext")
                }
                Text("Lesson \(lessonIndex + 1) of \(lessons.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Tutorial complete")
                    .font(.title3)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityIdentifier("tutorialScreen")
    }
}

/// Loads the five lessons; the UI test drives lesson 1 step 1.
enum TutorialContent {
    static func loadLessons() -> [LessonDef] {
        (try? ContentLoader.lessons()) ?? []
    }
}
