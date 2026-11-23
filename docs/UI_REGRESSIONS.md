# Approved UI regression checks

The app regression workflow runs the complete Flutter and Python test suites on pull requests and pushes to `main`.

Preserve these approved behaviors when changing the UI:

- Home: three stacked image sections of equal height, with a separate compact Contact My Reps action. All four destinations must remain reachable on small screens and with enlarged text.
- Branch chooser: three 108-point image cards with an icon and a single branch title. Do not restore the removed directory label, explanatory captions, or taller card layout.
- Home-to-branch artwork expands and gains color over 720 ms, and returns over 560 ms. Reduce Motion bypasses the animation.
- Find My Reps: centered search with feathered edges; keyboard changes and background portrait replacement preserve focus, text, and the field's state.
- Portraits: replacements every four seconds, retaining the existing home and finder fades. Reduce Motion keeps portraits still.

Coverage lives in `test/landing_sections_test.dart`, `test/landing_transitions_test.dart`, `test/find_reps_focus_test.dart`, `test/portrait_page_artwork_test.dart`, and `test/rotating_lawmaker_portraits_test.dart`.

Run the same full checks locally:

```sh
flutter pub get
flutter test --no-pub --reporter expanded
python3 -m unittest discover -s scripts/tests
```

If an intentional design change modifies one of these contracts, review and update its tests together with the implementation. A passing test suite guards these behaviors; it does not replace visual review or prevent every possible regression.
