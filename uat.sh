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

# Los simuladores se buscan POR NOMBRE. Antes iban dos UDID escritos a mano y
# dejaron de existir al reinstalar Xcode: el script fallaba sin decir por que.
device_id() {
  xcrun simctl list devices available \
    | sed -n "s/^ *$1 (\([0-9A-F-]*\)) (.*/\1/p" | head -1
}

A=${UAT_DEVICE_A:-$(device_id "iPhone 18 Pro")}
B=${UAT_DEVICE_B:-$(device_id "iPhone 18 Pro Max")}

for pair in "A:${UAT_DEVICE_A:-iPhone 18 Pro}:$A" "B:${UAT_DEVICE_B:-iPhone 18 Pro Max}:$B"; do
  if [ -z "${pair##*:}" ]; then
    echo "No encuentro el simulador ${pair#*:}. Creálo en Xcode o exporta UAT_DEVICE_A / UAT_DEVICE_B."
    exit 1
  fi
done
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

API=${FRIENDS_API:-$HOME/Code/friends-api}

if ! curl -sf -o /dev/null --max-time 2 http://localhost:3000/up; then
  echo "⚠︎  El backend no responde en localhost:3000."
  echo "   En otra pestaña: cd $API && bin/rails server"
else
  # Un servidor que lleva corriendo desde antes de una migracion no ve las
  # columnas nuevas y responde 500 a cosas que en el codigo estan bien. Ya nos
  # ha costado dos rondas de UAT: mejor avisar aqui.
  if [ -d "$API" ] && ! (cd "$API" && bin/rails db:abort_if_pending_migrations >/dev/null 2>&1); then
    echo "⚠︎  Hay migraciones sin aplicar en $API."
    echo "   cd $API && bin/rails db:migrate  y REINICIA el servidor."
  else
    # /up solo dice que Puma esta vivo. Para saber si el PROCESO esta al dia hay
    # que pedirle algo que toque los modelos: un servidor arrancado antes de una
    # migracion responde 500 aunque la base ya este migrada.
    TOKEN=$(curl -sf --max-time 3 -X POST http://localhost:3000/api/v1/auth/dev_session \
      -H 'Content-Type: application/json' -d '{"handle":"u_dev"}' \
      | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
    if [ -z "$TOKEN" ]; then
      echo "⚠︎  El backend responde en /up pero no emite sesiones. Reinicialo."
    else
      CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
        http://localhost:3000/api/v1/matches -H "Authorization: Bearer $TOKEN")
      if [ "$CODE" != "200" ]; then
        echo "⚠︎  /api/v1/matches devuelve $CODE: el servidor esta desfasado."
        echo "   Es un proceso arrancado antes de la ultima migracion. REINICIALO:"
        echo "   Ctrl-C y  bin/rails server   (en $API)"
      fi
    fi
  fi
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
