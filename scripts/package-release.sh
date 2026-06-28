#!/usr/bin/env bash
#
# Assemble the "lite" pre-compiled release bundle: a zip containing just what an
# operator needs to install the plugin into an existing Yamcs (no build required):
#
#     <name>/
#       external-webpage-<ver>-yamcs-<yamcsVer>.jar   the plugin (web bundle baked in)
#       external-webpage.yaml                         config template (edit label + url)
#       install.sh                                    flat-bundle-aware installer
#       INSTALL.md                                    quick instructions
#
# Output: dist/<name>.zip
#
# Requires the plugin jar to exist already (run 'mvn -pl plugin -am package' first,
# or rely on the committed jar in plugin/target/).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

JAR="$(ls -1 "$ROOT"/plugin/target/external-webpage-*-yamcs-*.jar 2>/dev/null \
  | grep -v -- '-sources\|-javadoc' | head -n1 || true)"
if [[ -z "$JAR" ]]; then
  echo "ERROR: no plugin jar in plugin/target/. Run 'mvn -pl plugin -am -DskipTests package' first." >&2
  exit 1
fi

NAME="$(basename "$JAR" .jar)"          # e.g. external-webpage-1.0.0-yamcs-5.13.0
BUNDLE="$NAME-bundle"                    # e.g. external-webpage-1.0.0-yamcs-5.13.0-bundle
STAGE="$ROOT/dist/$BUNDLE"

rm -rf "$STAGE"
mkdir -p "$STAGE"

cp "$JAR" "$STAGE/"
cp "$ROOT/config/external-webpage.yaml" "$STAGE/"
cp "$ROOT/install.sh" "$STAGE/"
chmod +x "$STAGE/install.sh"

cat > "$STAGE/INSTALL.md" <<EOF
# external-webpage plugin — pre-compiled bundle

This is a ready-to-install build of the Yamcs **external-webpage** plugin.
It is compiled for the Yamcs version named in the jar file:

    $NAME.jar

Install it into an existing Yamcs deployment (the directory containing bin/, etc/, lib/):

    ./install.sh /path/to/your/yamcs

Then:

  1. Edit \`<yamcs>/etc/external-webpage.yaml\` to set the sidebar \`label\` (name) and \`url\`.
  2. Grant the configured privilege (default \`web.ExternalPage\`) to a role, or sign in
     as a superuser. Without it, the sidebar item stays hidden.
  3. Restart Yamcs. Open an instance in yamcs-web; the item is at the bottom of the sidebar.

IMPORTANT: this jar is built for a specific Yamcs version (see the filename). If your
server runs a different version, use a matching release or rebuild from source.

Source and docs: https://github.com/Meridian-Space-Command/yamcs-web-plugin-webpage
EOF

( cd "$ROOT/dist" && rm -f "$BUNDLE.zip" && zip -r -q "$BUNDLE.zip" "$BUNDLE" )
echo "Created dist/$BUNDLE.zip"
( cd "$ROOT/dist" && unzip -l "$BUNDLE.zip" )
