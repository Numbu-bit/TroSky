#!/usr/bin/env bash
# TroSky store-build entry point.
#
# Usage:
#   tool/build_store.sh aab [--env staging|prod]   # Android App Bundle (Play)
#   tool/build_store.sh apk [--env staging|prod]   # APK (sideload / test tracks)
#   tool/build_store.sh ios [--env staging|prod]   # iOS archive (macOS only)
#
# Defaults to --env prod. The script enforces every piece of the C1/C2
# release contract:
#
#   * Signing: the Gradle `verifyReleaseSigningReady` task runs before
#     the AAB/APK is packaged, so a missing key.properties fails the
#     build before an unsigned (or debug-signed) artefact can exist.
#   * applicationId: `-Pdemo=true` is rejected; demo builds use
#     `--flavour demo` or a separate script (not this one).
#   * Dart obfuscation + split-debug-info into
#     `apps/mobile/build/symbols/<version>+<build>/<platform>/` so a
#     prod crash can be mapped back later. Combined with R8's own
#     mapping.txt (preserved in the AAB), no crash needs source
#     access to symbolicate.
#
# The script never prints keystore passwords, access tokens, or env
# contents. Every secret stays in gitignored files that this script
# reads but does not echo.

set -euo pipefail

PLATFORM="${1:-}"
shift || true
ENV_NAME="prod"
while (($# > 0)); do
  case "$1" in
    --env)
      ENV_NAME="${2:?--env needs a value}"
      shift 2
      ;;
    --env=*)
      ENV_NAME="${1#--env=}"
      shift
      ;;
    *)
      echo "error: unknown argument '$1'" >&2
      exit 2
      ;;
  esac
done

case "$PLATFORM" in
  aab | apk | ios) ;;
  "")
    echo "usage: $0 <aab|apk|ios> [--env staging|prod]" >&2
    exit 2
    ;;
  *)
    echo "error: unknown platform '$PLATFORM'. Use aab, apk, or ios." >&2
    exit 2
    ;;
esac

case "$ENV_NAME" in
  prod | staging) ;;
  *)
    echo "error: --env must be 'prod' or 'staging' (got '$ENV_NAME')." >&2
    exit 2
    ;;
esac

# Locate the mobile app directory. The script tolerates being invoked
# from the frontend root, the mobile dir, or via an absolute path.
script_dir="$(cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd)"
mobile_dir="$(cd -- "$script_dir/.." >/dev/null 2>&1 && pwd)"
frontend_dir="$(cd -- "$mobile_dir/../.." >/dev/null 2>&1 && pwd)"

env_file="$frontend_dir/env/${ENV_NAME}.json"
if [[ ! -f "$env_file" ]]; then
  echo "error: env file not found at $env_file" >&2
  echo "       prod env must exist before shipping; see env/README.md." >&2
  exit 1
fi

# Reject TESTER_MENU=true in prod (C4 belt-and-braces). The dart runtime
# fail-loud is the primary guard; this is a second line.
if [[ "$ENV_NAME" == "prod" ]]; then
  if grep -Eq '"TESTER_MENU"\s*:\s*"?true"?' "$env_file"; then
    echo "error: $env_file enables TESTER_MENU; refusing to produce a prod build." >&2
    exit 1
  fi
fi

# Dart --obfuscate requires --split-debug-info and produces .symbols
# files. Lay them out per version so an in-store APK and a tester APK
# of the same code can be told apart on symbolication.
pubspec="$mobile_dir/pubspec.yaml"
version_line=$(grep -m1 '^version:' "$pubspec" || true)
if [[ -z "$version_line" ]]; then
  echo "error: no 'version:' in $pubspec" >&2
  exit 1
fi
version="${version_line#version:}"
version="${version// /}"
# version pattern: 0.1.0+1 -> "0.1.0+1"
symbols_root="$mobile_dir/build/symbols/${version}/${PLATFORM}"
mkdir -p "$symbols_root"

commit=$(git -C "$frontend_dir/.." rev-parse --short HEAD 2>/dev/null || echo unknown)
build_date=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "=> Target:   $PLATFORM"
echo "=> Env:      $ENV_NAME"
echo "=> Version:  $version"
echo "=> Commit:   $commit"
echo "=> Symbols:  $symbols_root"

# Flutter needs the project root as its cwd.
cd "$mobile_dir"

common_defines=(
  "--dart-define-from-file=$env_file"
  "--dart-define=GIT_COMMIT=$commit"
  "--dart-define=BUILD_DATE=$build_date"
)

common_flags=(
  "--release"
  "--obfuscate"
  "--split-debug-info=$symbols_root"
)

case "$PLATFORM" in
  aab)
    flutter build appbundle "${common_flags[@]}" "${common_defines[@]}"
    artefact="$mobile_dir/build/app/outputs/bundle/release/app-release.aab"
    ;;
  apk)
    flutter build apk "${common_flags[@]}" "${common_defines[@]}"
    artefact="$mobile_dir/build/app/outputs/flutter-apk/app-release.apk"
    ;;
  ios)
    if [[ "$(uname -s)" != "Darwin" ]]; then
      echo "error: iOS builds require macOS." >&2
      exit 1
    fi
    flutter build ios "${common_flags[@]}" "${common_defines[@]}"
    artefact="$mobile_dir/build/ios/iphoneos/Runner.app"
    ;;
esac

# Preserve the R8 mapping alongside the Dart symbols so the owner can
# upload both to Play and keep both in the password manager / artefact
# store. R8 writes mapping.txt per variant.
mapping_src="$mobile_dir/build/app/outputs/mapping/release/mapping.txt"
if [[ -f "$mapping_src" ]]; then
  cp "$mapping_src" "$symbols_root/r8-mapping.txt"
  echo "=> R8 mapping saved to $symbols_root/r8-mapping.txt"
fi

echo "=> Done.    $artefact"
echo "   Keep $symbols_root for symbolication. Upload mapping.txt to"
echo "   Play ('App bundle explorer → ReTrace mapping') as well."
