# Development workflow

Read `.agent/development.md` first when resuming work. It is the current feature tracker and handoff. Read only the relevant API/source files next; use `.agent/verification.md` for historical evidence when needed, not as the default starting point.

`.agent/` is deliberately untracked. It holds working notes for whoever is developing the package, not documentation, so it lives in the working copy and a fresh clone will not have it. Keep it updated anyway: it is how the next session resumes without re-deriving state.

## Preserve agreed behavior

- Bare React Native, no Expo Modules or runtime dependency on reference glass libraries.
- Public native iOS APIs and standard Android counterparts; merging is opt-in and defaults to false.
- Preserve the user-accepted action-cluster material tint, native touch response, and icons inside stretching glass. Do not reintroduce custom highlight or movement systems during unrelated work.
- Older-iOS device testing is deferred by the user; retain availability guards and fallbacks.
- MIT licensing and metadata are already present from the recorded September 18 decision. Do not change the license or publish without explicit authorization.

## Keep work efficient

- Use the tracker IDs and work in bounded batches of related features. Define API, native ownership, fallback behavior, and acceptance checks before editing.
- Reuse relevant existing research, source patterns, build directories, and test evidence. Verify new or uncertain platform API assumptions using official documentation; do not repeat settled research without a reason.
- Batch independent reads/searches and keep output limited to relevant files, errors, and summaries. Do not reread full logs or the repository on every continuation.
- User preference: finish the batch's shared API, iOS code, Android code, integration example, documentation, and test code before executing tests or native builds. Then run the shared checks and build/exercise both platforms. Fix verification failures and rerun affected checks only; an unchanged passing result does not justify repetition.
- Run broader regression and standalone packed-consumer checks when shared infrastructure changes or a release candidate needs verification. Do not reinstall consumers or repack after every small edit.
- Documentation-only work needs link/state consistency checks, not native builds or application tests.
- Inspect actual executed tests and exit status. Distinguish implementation, automated verification, and user acceptance; never infer one from another or extend old evidence to changed code.
- Update tracker rows as work advances. At each batch handoff, record changed behavior, evidence, remaining gaps, and the exact next action. Keep this compact; link logs/results rather than copying them.
- Record durable decisions in the tracker and public behavior in the relevant API docs. Avoid duplicate roadmaps and repeated chronological narratives.
- Do not ask the user to approve routine development steps already authorized. Respect tool permissions and any explicit denial.

## Local build facts

- Open `example/ios/LiquidGlassLab.xcworkspace`, scheme `LiquidGlassLab`; preserve signing configuration.
- Metro uses 8093. Android direct Gradle builds also set `reactNativeDevServerPort=8093`.
- Preserve existing device/build caches where possible. Discover live device IDs when needed; do not assume a phone is unlocked.
