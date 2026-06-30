#!/usr/bin/env bash
#
# Install the external-webpage plugin into an existing Yamcs deployment.
#
# Usage:
#   ./install.sh [--build] <YAMCS_HOME>
#
#   <YAMCS_HOME>   Path to a Yamcs installation (the dir containing bin/, etc/, lib/).
#   --build        Build the plugin with Maven first (source checkout only; needs JDK 17+).
#   -h, --help     Show this help.
#
# What it does (force install -- always overwrites, so re-running is deterministic):
#   * copies the plugin jar into <YAMCS_HOME>/lib/   (auto-loaded from the classpath)
#   * copies external-webpage.yaml into <YAMCS_HOME>/etc/, backing up any existing copy
#     to external-webpage.yaml.bak
#
# Configure pages by editing external-webpage.yaml (a 'pages:' list) -- ideally in this
# bundle BEFORE installing, since install overwrites <YAMCS_HOME>/etc/external-webpage.yaml.
# Then restart Yamcs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() { sed -n '3,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

BUILD=0
YAMCS_HOME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
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

echo ">> Installing plugin jar:"
echo "     $JAR"
echo "   -> $YAMCS_HOME/lib/"
# Force: remove any previous version of this plugin, then copy.
rm -f "$YAMCS_HOME"/lib/external-webpage-*.jar
cp -f "$JAR" "$YAMCS_HOME/lib/"

CONFIG_DST="$YAMCS_HOME/etc/external-webpage.yaml"
if [[ -n "$CONFIG_SRC" ]]; then
  if [[ -e "$CONFIG_DST" ]]; then
    cp -f "$CONFIG_DST" "$CONFIG_DST.bak"
    echo ">> Backed up existing config -> $CONFIG_DST.bak"
  fi
  echo ">> Installing config (overwrite): $CONFIG_DST"
  cp -f "$CONFIG_SRC" "$CONFIG_DST"
else
  echo ">> WARNING: config template not found; create $CONFIG_DST manually (a 'pages:' list)."
fi

cat <<EOF

Done. Next steps:
  1. Edit $CONFIG_DST -- a 'pages:' list (label + url per page; optional privilege/icon).
     (If you had a config, your previous one is at $CONFIG_DST.bak.)
  2. For gated pages, grant the configured privilege to a role, or use "*" for all users.
  3. Restart Yamcs. Open an instance in yamcs-web; the items are in the left sidebar.
EOF
