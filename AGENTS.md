# ryC0 workflow

- The project's GitHub repository is https://github.com/Sami-Wali/ryC0.
- The user wants completed changes committed and pushed to this repository after appropriate validation, with a pull request for review.
- Use `origin` for this repository and `codex/` branches for new work. Keep the original project's `upstream` remote for reference.
- Base published branches on `origin/main`; do not import unrelated upstream Git history. Preserve the original code's attribution and licenses in the source.
- Keep build outputs and the local `.device-run` staging project out of commits.
- Build Nightly releases on the user's Mac, never on GitHub-hosted Actions runners. Keep the old build workflow disabled.
- Local hooks run `node Scripts/nightly.mjs publish` after commits and successful local merges. This builds an isolated source snapshot, pushes the source branch, and uploads the IPA as a GitHub prerelease. Verify the release completes; retry that command if a build fails.
