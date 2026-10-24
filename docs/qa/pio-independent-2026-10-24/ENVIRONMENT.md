# Local environment

Read directly on 2026-10-24:

- Xcode 27.1, build 27A9275.
- macOS 27.0.1, build 26A434.
- Native test results and simulator destinations are recorded by the integration worker in native/ logs. A sandboxed `simctl list` cannot access CoreSimulator; that access failure is not a failed app test or proof that the simulator is unavailable. Authorized native test invocations use the existing isolated review setup.
- No physical iPhone recording or Apple Sandbox purchase is claimed.
