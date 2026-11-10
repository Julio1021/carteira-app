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

# tela de abertura do sistema na mesma cor da animação do app (claro/escuro)
RES=android/app/src/main/res
fundo() {
  mkdir -p "$RES/$1"
  cat > "$RES/$1/launch_background.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item><color android:color="$2"/></item>
</layer-list>
EOF
}
fundo drawable "#F4F5F9"; fundo drawable-v21 "#F4F5F9"
fundo drawable-night "#101119"; fundo drawable-night-v21 "#101119"
splash31() {
  mkdir -p "$RES/$1"
  cat > "$RES/$1/styles.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="$2">
        <item name="android:windowBackground">@drawable/launch_background</item>
        <item name="android:windowSplashScreenBackground">$3</item>
    </style>
    <style name="NormalTheme" parent="$2">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
EOF
}
splash31 values-v31 "@android:style/Theme.Light.NoTitleBar" "#F4F5F9"
splash31 values-night-v31 "@android:style/Theme.Black.NoTitleBar" "#101119"

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
# chave fixa guardada criptografada no repositório; a senha fica no segredo CHAVE_SENHA
if [ -z "${KEYSTORE_BASE64:-}" ] && [ -n "${CHAVE_SENHA:-}" ] && [ -f android_chave/upload.jks.enc ]; then
  openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -in android_chave/upload.jks.enc -out android/app/upload.jks -pass env:CHAVE_SENHA
  KEYSTORE_BASE64=arquivo
  KEYSTORE_PASSWORD="$CHAVE_SENHA"; KEY_PASSWORD="$CHAVE_SENHA"; KEY_ALIAS=carteira
fi
if [ -n "${KEYSTORE_BASE64:-}" ]; then
  [ "$KEYSTORE_BASE64" = arquivo ] || echo "$KEYSTORE_BASE64" | base64 -d > android/app/upload.jks
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
