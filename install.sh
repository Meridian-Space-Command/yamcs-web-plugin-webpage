#!/usr/bin/env bash
#
# Install the external-webpage plugin into an existing Yamcs deployment.
#
# This is a force install: it OVERWRITES the plugin jar in <YAMCS_HOME>/lib/ and the
# config <YAMCS_HOME>/etc/external-webpage.yaml (no backup is kept). You are asked to
# confirm first, unless you pass -y.
#
# Usage:
#   ./install.sh [-y] [--build] <YAMCS_HOME>
#
#   <YAMCS_HOME>   Path to a Yamcs installation (the dir containing bin/, etc/, lib/).
#   -y, --yes      Skip the confirmation prompt (non-interactive).
#   --build        Build the plugin with Maven first (source checkout only; needs JDK 17+).
#   -h, --help     Show this help.
#
# Configure pages by editing external-webpage.yaml (a 'pages:' list) -- ideally in this
# bundle BEFORE installing, since install overwrites <YAMCS_HOME>/etc/external-webpage.yaml.
# Then restart Yamcs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./install.sh [-y] [--build] <YAMCS_HOME>

  <YAMCS_HOME>   Path to a Yamcs installation (the dir containing bin/, etc/, lib/).
  -y, --yes      Skip the confirmation prompt (non-interactive).
  --build        Build the plugin with Maven first (source checkout only; needs JDK 17+).
  -h, --help     Show this help.

Force install: overwrites the plugin jar in <YAMCS_HOME>/lib/ and the config
<YAMCS_HOME>/etc/external-webpage.yaml (no backup). Edit external-webpage.yaml
(a 'pages:' list) in this bundle before installing, then restart Yamcs.
EOF
}

BUILD=0
ASSUME_YES=0
YAMCS_HOME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) ASSUME_YES=1; shift ;;
    --build) BUILD=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "ERROR: unknown option '$1'" >&2; usage >&2; exit 1 ;;
    *) YAMCS_HOME="$1"; shift ;;
  esac
done

if [[ -z "$YAMCS_HOME" ]]; then
  echo "ERROR: missing <YAMCS_HOME> argument." >&2
  usage >&2
  exit 1
fi

if [[ ! -d "$YAMCS_HOME/lib" || ! -d "$YAMCS_HOME/etc" ]]; then
  echo "ERROR: '$YAMCS_HOME' does not look like a Yamcs home (missing lib/ or etc/)." >&2
  exit 1
fi

if [[ "$BUILD" -eq 1 ]]; then
  if [[ ! -f "$SCRIPT_DIR/plugin/pom.xml" ]]; then
    echo "ERROR: --build can only be used from a source checkout (plugin/pom.xml not found)." >&2
    exit 1
  fi
  echo ">> Building plugin (mvn -pl plugin -am package)..."
  (cd "$SCRIPT_DIR" && mvn -q -pl plugin -am -DskipTests package)
fi

# Find the jar. Works both in a source checkout (plugin/target/) and inside a flat
# pre-compiled release bundle (jar sitting next to this script).
JAR="$(ls -1 \
  "$SCRIPT_DIR"/external-webpage-*.jar \
  "$SCRIPT_DIR"/plugin/target/external-webpage-*.jar \
  2>/dev/null | grep -v -- '-sources\|-javadoc' | head -n1 || true)"
if [[ -z "$JAR" ]]; then
  echo "ERROR: plugin jar not found (looked next to this script and in plugin/target/)." >&2
  echo "       In a source checkout, run with --build or 'mvn -pl plugin -am package' first." >&2
  exit 1
fi

# Find the config template (flat bundle, then source checkout).
CONFIG_SRC=""
for c in "$SCRIPT_DIR/external-webpage.yaml" "$SCRIPT_DIR/config/external-webpage.yaml"; do
  if [[ -f "$c" ]]; then CONFIG_SRC="$c"; break; fi
done

CONFIG_DST="$YAMCS_HOME/etc/external-webpage.yaml"

# Confirm before overwriting (unless -y).
if [[ "$ASSUME_YES" -ne 1 ]]; then
  echo "WARNING: this will OVERWRITE the following in '$YAMCS_HOME' (no backup):"
  echo "    lib/$(basename "$JAR")  (and any other external-webpage-*.jar)"
  [[ -e "$CONFIG_DST" ]] && echo "    etc/external-webpage.yaml  (existing config will be replaced)"
  printf "Proceed? [y/N] "
  read -r answer || answer=""
  case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

echo ">> Installing plugin jar:"
echo "     $JAR"
echo "   -> $YAMCS_HOME/lib/"
rm -f "$YAMCS_HOME"/lib/external-webpage-*.jar
cp -f "$JAR" "$YAMCS_HOME/lib/"

if [[ -n "$CONFIG_SRC" ]]; then
  echo ">> Installing config (overwrite): $CONFIG_DST"
  cp -f "$CONFIG_SRC" "$CONFIG_DST"
else
  echo ">> WARNING: config template not found; create $CONFIG_DST manually (a 'pages:' list)."
fi

cat <<EOF

Done. Next steps:
  1. Edit $CONFIG_DST -- a 'pages:' list (label + url per page; optional privilege/icon).
  2. For gated pages, grant the configured privilege to a role, or use "*" for all users.
  3. Restart Yamcs. Open an instance in yamcs-web; the items are in the left sidebar.
EOF
