#!/bin/bash
# Levanta la app en dos simuladores, cada uno con una cuenta distinta, que es
# lo que hace falta para probar a mano un match, un chat o un bloqueo.
#
#   ./uat.sh            compila y lanza los dos
#   ./uat.sh --no-build usa lo ya compilado (mas rapido)
#
# Las cuentas salen del atajo de desarrollo: el simulador B recibe
# DEV_HANDLE=u_dev2 y entra como "Dev 2" en vez de como "Dev".
set -euo pipefail
cd "$(dirname "$0")"

A=${UAT_DEVICE_A:-B8481770-B392-44DF-A33C-C0F0CED158C1}   # iPhone 18 Pro
B=${UAT_DEVICE_B:-DFA0633B-1749-42D6-9739-6DCB3431CF56}   # iPhone 18 Pro Max
BUNDLE=cl.toolazy.friends
DD=${UAT_DERIVED_DATA:-/tmp/friends-dd}
APP="$DD/Build/Products/Debug-iphonesimulator/Friends.app"

if [ "${1:-}" != "--no-build" ]; then
  echo "▸ Generando el proyecto y compilando…"
  xcodegen generate >/dev/null
  xcodebuild build -project Friends.xcodeproj -scheme Friends -sdk iphonesimulator \
    -destination "id=$A" -derivedDataPath "$DD" >/dev/null
fi

[ -d "$APP" ] || { echo "No encuentro $APP. Corre ./uat.sh sin --no-build."; exit 1; }

if ! curl -sf -o /dev/null --max-time 2 http://localhost:3000/up; then
  echo "⚠︎  El backend no responde en localhost:3000."
  echo "   En otra pestaña: cd ~/Code/friends-api && bin/rails server"
fi

for D in "$A" "$B"; do
  xcrun simctl bootstatus "$D" -b >/dev/null 2>&1 || xcrun simctl boot "$D" >/dev/null 2>&1 || true
done
for D in "$A" "$B"; do
  xcrun simctl bootstatus "$D" -b >/dev/null 2>&1 || true
  xcrun simctl install "$D" "$APP"
  xcrun simctl terminate "$D" "$BUNDLE" >/dev/null 2>&1 || true
done

xcrun simctl launch "$A" "$BUNDLE" >/dev/null
SIMCTL_CHILD_DEV_HANDLE=u_dev2 xcrun simctl launch "$B" "$BUNDLE" >/dev/null
# Simulator.app vive dentro de Xcode, no en /Applications.
open -a "$(xcode-select -p)/Applications/Simulator.app" 2>/dev/null || open -a Simulator 2>/dev/null || true

echo
echo "  A  $(xcrun simctl list devices | grep "$A" | sed 's/ (.*//;s/^ *//')  →  u_dev   (Dev)"
echo "  B  $(xcrun simctl list devices | grep "$B" | sed 's/ (.*//;s/^ *//')  →  u_dev2  (Dev 2)"
echo
echo "En cada uno, el boton naranja de la puerta dice con que cuenta entra."
echo "Para verlos lado a lado: en Simulator, Window › Arrange in Front."
