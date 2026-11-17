// MARK: - TutorialView

import RSContent
import RSCore
import SwiftUI

/// The tutorial: three lessons loaded from content (RS-P3.2), played in
/// order; the first lesson is marked by content.
struct TutorialView: View {
    @State private var lessons: [TutorialLessonDef] = []
    @State private var loadError: String?

    var body: some View {
        Group {
            if let error = loadError {
                ContentUnavailableView(
                    "Tutorial unavailable", systemImage: "exclamationmark.triangle",
                    description: Text(error))
            } else {
                List {
                    ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                        Section {
                            ForEach(Array(lesson.steps.enumerated()), id: \.offset) { _, step in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(step)
                                        .font(.subheadline)
                                }
                            }
                        } header: {
                            HStack {
                                Text(lesson.title)
                                if lesson.isFirst {
                                    Text("Start here")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("How to Play")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if lessons.isEmpty, loadError == nil {
                do {
                    lessons = try ContentLoader().loadTutorial()
                } catch {
                    loadError = "\(error)"
                }
            }
        }
    }
}
