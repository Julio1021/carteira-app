"""Troca a assinatura de teste pela chave de upload no build.gradle(.kts) gerado pelo Flutter."""
import re
import sys

p = sys.argv[1]
s = open(p, encoding="utf-8").read()
kts = p.endswith(".kts")

if "key.properties" in s:
    sys.exit(0)

if kts:
    cabecalho = (
        'import java.util.Properties\n'
        'import java.io.FileInputStream\n\n'
        'val keystoreProperties = Properties()\n'
        'val keystorePropertiesFile = rootProject.file("key.properties")\n'
        'if (keystorePropertiesFile.exists()) { keystoreProperties.load(FileInputStream(keystorePropertiesFile)) }\n\n'
    )
    configs = (
        '    signingConfigs {\n'
        '        create("release") {\n'
        '            keyAlias = keystoreProperties["keyAlias"] as String\n'
        '            keyPassword = keystoreProperties["keyPassword"] as String\n'
        '            storeFile = file(keystoreProperties["storeFile"] as String)\n'
        '            storePassword = keystoreProperties["storePassword"] as String\n'
        '        }\n'
        '    }\n\n'
        '    buildTypes {'
    )
    s = re.sub(r'^(plugins\s*\{)', cabecalho + r'\1', s, count=1, flags=re.M)
    s = s.replace('    buildTypes {', configs, 1)
    s = s.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("release")')
else:
    cabecalho = (
        'def keystoreProperties = new Properties()\n'
        'def keystorePropertiesFile = rootProject.file("key.properties")\n'
        'if (keystorePropertiesFile.exists()) { keystoreProperties.load(new FileInputStream(keystorePropertiesFile)) }\n\n'
    )
    configs = (
        '    signingConfigs {\n'
        '        release {\n'
        '            keyAlias keystoreProperties["keyAlias"]\n'
        '            keyPassword keystoreProperties["keyPassword"]\n'
        '            storeFile file(keystoreProperties["storeFile"])\n'
        '            storePassword keystoreProperties["storePassword"]\n'
        '        }\n'
        '    }\n\n'
        '    buildTypes {'
    )
    s = s.replace('android {', cabecalho + 'android {', 1)
    s = s.replace('    buildTypes {', configs, 1)
    s = s.replace('signingConfig = signingConfigs.debug', 'signingConfig = signingConfigs.release')
    s = s.replace('signingConfig signingConfigs.debug', 'signingConfig signingConfigs.release')

open(p, "w", encoding="utf-8").write(s)
print("build.gradle ajustado para a chave de upload")
