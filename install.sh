#!/usr/bin/env bash
#
# Install the external-webpage plugin into an existing Yamcs deployment.
#
# Usage:
#   ./install.sh [--build] <YAMCS_HOME>
#
#   <YAMCS_HOME>   Path to a Yamcs installation (the directory containing bin/, etc/, lib/).
#   --build        Run the Maven build first (requires JDK 17+ and network access for
#                  Maven + Node downloads). Omit if you have already run `mvn package`.
#
# What it does:
#   * copies the plugin jar into <YAMCS_HOME>/lib/   (auto-loaded from the classpath)
#   * copies config/external-webpage.yaml into <YAMCS_HOME>/etc/   (if not already present)
#
# Before (or after) installing, edit the config file to set the sidebar 'label' (name)
# and 'url'. Then assign the configured privilege (default 'web.ExternalPage') to a role
# (or rely on superuser access) and restart Yamcs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BUILD=0
YAMCS_HOME=""

for arg in "$@"; do
  case "$arg" in
    --build) BUILD=1 ;;
    -h|--help)
      sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) YAMCS_HOME="$arg" ;;
  esac
done

if [[ -z "$YAMCS_HOME" ]]; then
  echo "ERROR: missing <YAMCS_HOME> argument." >&2
  echo "Usage: ./install.sh [--build] <YAMCS_HOME>" >&2
  exit 1
fi

if [[ ! -d "$YAMCS_HOME/lib" || ! -d "$YAMCS_HOME/etc" ]]; then
  echo "ERROR: '$YAMCS_HOME' does not look like a Yamcs home (missing lib/ or etc/)." >&2
  exit 1
fi

if [[ "$BUILD" -eq 1 ]]; then
  echo ">> Building plugin (mvn -pl plugin -am package)..."
  (cd "$SCRIPT_DIR" && mvn -q -pl plugin -am -DskipTests package)
fi

JAR="$(ls -1 "$SCRIPT_DIR"/plugin/target/external-webpage-*.jar 2>/dev/null | grep -v -- '-sources\|-javadoc' | head -n1 || true)"
if [[ -z "$JAR" ]]; then
  echo "ERROR: plugin jar not found under plugin/target/. Run with --build, or run 'mvn package' first." >&2
  exit 1
fi

echo ">> Installing plugin jar:"
echo "     $JAR"
echo "   -> $YAMCS_HOME/lib/"
# Remove older versions of this plugin to avoid duplicate-jar conflicts.
rm -f "$YAMCS_HOME"/lib/external-webpage-*.jar
cp "$JAR" "$YAMCS_HOME/lib/"

CONFIG_DST="$YAMCS_HOME/etc/external-webpage.yaml"
if [[ -e "$CONFIG_DST" ]]; then
  echo ">> Config already exists, leaving it untouched: $CONFIG_DST"
else
  echo ">> Installing config: $CONFIG_DST"
  cp "$SCRIPT_DIR/config/external-webpage.yaml" "$CONFIG_DST"
fi

cat <<EOF

Done. Next steps:
  1. Edit $CONFIG_DST to set the sidebar 'label' (name) and 'url'.
  2. Grant the configured system privilege (default 'web.ExternalPage') to a role in
     your security config, or sign in as a superuser. Without it, the item stays hidden.
  3. Restart Yamcs. Open an instance in yamcs-web and look for the item in the
     left sidebar.
EOF
