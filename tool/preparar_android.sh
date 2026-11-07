#!/usr/bin/env bash
# Gera as pastas de plataforma (android/ e web/) que o Flutter precisa e aplica
# os ajustes do app. Roda no GitHub Actions antes de compilar.
set -euo pipefail

if [ ! -d android ]; then
  flutter create --platforms=android,web --org br.julio1021 --project-name carteira --no-pub .
  rm -f test/widget_test.dart
fi

MANIFEST=android/app/src/main/AndroidManifest.xml
# nome que aparece embaixo do ícone
sed -i 's/android:label="carteira"/android:label="Carteira"/' "$MANIFEST"
# internet (para a sincronização com o Drive)
grep -q 'android.permission.INTERNET' "$MANIFEST" || \
  sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$MANIFEST"

# web: título, cor e nome do app instalado
sed -i 's#<title>carteira</title>#<title>Diário da Carteira</title>#' web/index.html || true
if [ -f web/manifest.json ]; then
  python3 - <<'PY'
import json
p = 'web/manifest.json'
m = json.load(open(p))
m.update({"name": "Diário da Carteira", "short_name": "Carteira", "background_color": "#101119", "theme_color": "#101119"})
json.dump(m, open(p, 'w'), ensure_ascii=False, indent=2)
PY
fi

# assinatura de release, quando os segredos existem (para a Play Store)
GRADLE=android/app/build.gradle.kts
[ -f "$GRADLE" ] || GRADLE=android/app/build.gradle
if [ -n "${KEYSTORE_BASE64:-}" ]; then
  echo "$KEYSTORE_BASE64" | base64 -d > android/app/upload.jks
  cat > android/key.properties <<EOF
storePassword=${KEYSTORE_PASSWORD}
keyPassword=${KEY_PASSWORD}
keyAlias=${KEY_ALIAS}
storeFile=upload.jks
EOF
  python3 tool/assinar_gradle.py "$GRADLE"
  echo "Assinatura de release configurada."
else
  echo "Sem chave de upload: o APK sai assinado com a chave de teste."
fi
