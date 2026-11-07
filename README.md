# Diário da Carteira — app

App Android (Flutter) do Diário da Carteira, no visual Grafite.

- **Versão 0.1:** Início, Extrato, lançar gastos e entradas, limites por categoria, importar e exportar backup do site.
- **Próximas:** sincronização com o Google Drive (mesmo arquivo do site), Planejar (contas, cartões, recebimentos) e Patrimônio.

## Como é compilado
Não precisa de computador. A cada envio para a branch `main`, o GitHub Actions:
1. gera as pastas `android/` e `web/` (`tool/preparar_android.sh`);
2. roda os testes;
3. gera o **APK** para instalar e testar, e o **AAB** para a Play Store (quando a chave de upload está nos segredos do repositório);
4. tira prints das telas.

Os arquivos ficam em **Actions → último "Compilar app" → Artifacts**.

### Segredos para a Play Store (Settings → Secrets and variables → Actions)
`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`.
