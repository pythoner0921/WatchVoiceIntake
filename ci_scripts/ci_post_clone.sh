#!/bin/sh
set -e

# Xcode Cloud clones the raw repo and looks for WatchVoiceIntake.xcodeproj
# immediately — it doesn't know this project uses XcodeGen (.xcodeproj is
# gitignored on purpose, generated fresh from project.yml, same reasoning
# as the GitHub Actions workflows). This is Xcode Cloud's documented hook
# for exactly this: any ci_scripts/ci_post_clone.sh runs automatically
# right after clone, before the project is resolved/built.
brew install xcodegen

cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate
