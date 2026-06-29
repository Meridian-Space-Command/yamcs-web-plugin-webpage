#!/usr/bin/env bash
#
# Install the external-webpage plugin into an existing Yamcs deployment.
#
# Usage:
#   ./install.sh [options] <YAMCS_HOME>
#
#   <YAMCS_HOME>        Path to a Yamcs installation (the dir containing bin/, etc/, lib/).
#
# Options:
#   --label "<text>"   Set the sidebar name in the config (replaces the placeholder).
#   --url "<url>"      Set the embedded page URL in the config.
#   --privilege "<p>"  Set the system privilege required to see the item.
#   --build            Build the plugin with Maven first (source checkout only; needs JDK 17+).
#   -h, --help         Show this help.
#
# What it does:
#   * copies the plugin jar into <YAMCS_HOME>/lib/   (auto-loaded from the classpath)
#   * installs external-webpage.yaml into <YAMCS_HOME>/etc/ (if not already present)
#   * if --label/--url/--privilege are given, writes those values into the config
#
# Examples:
#   ./install.sh /opt/yamcs
#   ./install.sh --label "ESTRACK" --url "https://estracknow.esa.int/" /opt/yamcs
#
# After installing, grant the privilege (default 'web.ExternalPage') to a role or sign in
# as a superuser, then restart Yamcs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() { sed -n '3,27p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

BUILD=0
YAMCS_HOME=""
LABEL=""
URL=""
PRIVILEGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build) BUILD=1; shift ;;
    --label) LABEL="${2:-}"; shift 2 ;;
    --label=*) LABEL="${1#*=}"; shift ;;
    --url) URL="${2:-}"; shift 2 ;;
    --url=*) URL="${1#*=}"; shift ;;
    --privilege) PRIVILEGE="${2:-}"; shift 2 ;;
    --privilege=*) PRIVILEGE="${1#*=}"; shift ;;
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

# Set a top-level scalar key in a YAML file: 'key: "value"'. The value is written as a
# double-quoted YAML scalar so YAML-special values (e.g. '*', URLs, anything with ':' or
# leading symbols) are safe. Escapes \ and " for YAML, then &, |, \ for the sed replacement.
# Writes via a temp file for macOS/Linux portability.
set_yaml_value() {
  local file="$1" key="$2" value="$3" yaml esc tmp
  yaml=$(printf '%s' "$value" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')   # YAML-escape \ and "
  esc=$(printf '"%s"' "$yaml" | sed -e 's/[&|\\]/\\&/g')               # sed-escape & | \
  tmp=$(mktemp)
  sed "s|^${key}:.*|${key}: ${esc}|" "$file" > "$tmp" && mv "$tmp" "$file"
}

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

# Find the config template the same way (flat bundle, then source checkout).
CONFIG_SRC=""
for c in "$SCRIPT_DIR/external-webpage.yaml" "$SCRIPT_DIR/config/external-webpage.yaml"; do
  if [[ -f "$c" ]]; then CONFIG_SRC="$c"; break; fi
done

echo ">> Installing plugin jar:"
echo "     $JAR"
echo "   -> $YAMCS_HOME/lib/"
# Remove older versions of this plugin to avoid duplicate-jar conflicts.
rm -f "$YAMCS_HOME"/lib/external-webpage-*.jar
cp "$JAR" "$YAMCS_HOME/lib/"

CONFIG_DST="$YAMCS_HOME/etc/external-webpage.yaml"
if [[ -e "$CONFIG_DST" ]]; then
  echo ">> Config already exists, keeping: $CONFIG_DST"
elif [[ -n "$CONFIG_SRC" ]]; then
  echo ">> Installing config: $CONFIG_DST"
  cp "$CONFIG_SRC" "$CONFIG_DST"
else
  echo ">> WARNING: config template not found; create $CONFIG_DST manually (label + url)."
fi

# Apply any provided overrides to the installed config.
if [[ -e "$CONFIG_DST" ]]; then
  if [[ -n "$LABEL" ]];     then set_yaml_value "$CONFIG_DST" label "$LABEL";         echo ">> set label:     $LABEL"; fi
  if [[ -n "$URL" ]];       then set_yaml_value "$CONFIG_DST" url "$URL";             echo ">> set url:       $URL"; fi
  if [[ -n "$PRIVILEGE" ]]; then set_yaml_value "$CONFIG_DST" privilege "$PRIVILEGE"; echo ">> set privilege: $PRIVILEGE"; fi
fi

cat <<EOF

Done. Next steps:
  1. Review $CONFIG_DST (set 'label' and 'url' if you did not pass --label/--url).
  2. Grant the configured system privilege (default 'web.ExternalPage') to a role in
     your security config, or sign in as a superuser. Without it, the item stays hidden.
  3. Restart Yamcs. Open an instance in yamcs-web and look for the item in the
     left sidebar.
EOF
