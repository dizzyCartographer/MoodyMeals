import SwiftUI

// COOK MODE — full-screen, distraction-free: ingredients within reach up
// top, one step at a time below, big enough to read from across the
// counter. Screen stays awake while it's open.
//
// Standalone in this pass — the CookModeActivity Live Activity scaffolding
// (Dynamic Island / lock screen) models a fixed prep/chop/sizzle/eat
// countdown toward a shared eat time, a different shape from an arbitrary
// per-recipe step list, and isn't wired to this screen.

struct CookModeView: View {
    @Environment(\.dismiss) private var dismiss
    let recipe: LibraryRecipe

    @State private var stepIndex = 0

    private var steps: [String] {
        recipe.steps.isEmpty
            ? ["no steps on file — check the ingredients above and go by feel"]
            : recipe.steps
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if !recipe.items.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(recipe.items) { item in
                                Text(item.amountText.isEmpty
                                     ? item.name : "\(item.name) \(item.amountText)")
                                    .font(.callout)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Palette.pink.tint, in: Capsule())
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 4)
                }

                Spacer()

                VStack(spacing: 12) {
                    Text("Step \(stepIndex + 1) of \(steps.count)")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(steps[stepIndex])
                        .font(.title2.weight(.medium))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Spacer()

                HStack(spacing: 16) {
                    Button {
                        stepIndex = max(0, stepIndex - 1)
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(stepIndex == 0)

                    Button {
                        if stepIndex < steps.count - 1 { stepIndex += 1 } else { dismiss() }
                    } label: {
                        Label(stepIndex < steps.count - 1 ? "Next" : "Done",
                              systemImage: stepIndex < steps.count - 1
                                ? "chevron.right" : "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.pink.color)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding(.top)
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}
