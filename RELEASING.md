# Releasing

How Crib Maze for Mac gets from a commit to a free download on [GitHub releases](https://github.com/robotpony/warped-cards/releases). The script is `scripts/release.sh`; this is the checklist around it.

## What ships

- **Crib Maze** (`ca.robotpony.cribmaze`), the release target: no records, no beta tools. It's a free demo, posted as a pre-release while the version is below 1.0.
- Noddy Yookerspiel, the beta, isn't posted. Testers build it, or get it through TestFlight once the iOS version exists.
- One zip per version, `Crib-Maze-<version>-mac.zip`, signed with the Developer ID certificate (team 7J49PFSP65), notarized by Apple and stapled, so it opens without warnings on macOS 26 or later.

## One-time setup

1. Developer ID Application certificate in the login keychain. Check with `security find-identity -v -p codesigning`. (Done.)
2. GitHub CLI signed in: `gh auth status`. (Done.)
3. A notary profile in the keychain. Make an app-specific password at account.apple.com, then run this yourself; it asks for the password, so it never lands in a file or a log:

   ```sh
   xcrun notarytool store-credentials warped-cards-notary --apple-id <your Apple ID> --team-id 7J49PFSP65
   ```

## Each release

1. Playtest the build you mean to ship (`scripts/debug.sh release`). The first release waits on the first human playtest ([playtests/plan.md](cribbage/minigames/playtests/plan.md)).
2. Bump `MARKETING_VERSION` in `swift/App/project.yml` and write the version's section at the top of `CHANGELOG.md`, for players, in on-screen names. The script refuses to run if the two disagree. The release notes are `scripts/release-intro.md` (what the game is; keep it current) followed by that section.
3. Check the docs say what the build does: `README.md` (games table, test count), `rules.md` (rules version), `PLAN.md`.
4. Run `scripts/check.sh`, then commit.
5. `scripts/release.sh build`: archives, signs, notarizes (a few minutes), staples and zips into `.build-release/`. Open the stapled app from there once.
6. `scripts/release.sh publish`: tags the commit that was built as `v<version>`, pushes the tag and posts the zip and notes. This step is public; Bruce says go first.

If notarizing fails, `xcrun notarytool log <submission id> --keychain-profile warped-cards-notary` says why.
