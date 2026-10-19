# Sürüm çıkarma ve imzalama (filo sahibi için)

## Yeni sürüm

1. `hunters_hq.py` içinde `VERSION = "1.0.1"` değerini güncelle ve commit et.
2. `git tag v1.0.1`, ardından `git push origin main --tags`.
3. GitHub Actions → **Release** iş akışı kurulum dosyasını derler. SignPath bağlıysa iki imza isteği gönderir:
   önce `HuntersHQ.exe`, sonra kurulum dosyası. SignPath'ten gelen e-postalardaki **Approve** düğmesiyle ikisini de onayla.
4. Sürüm GitHub Releases sayfasında yayınlanır. Web sitesindeki dosyayı da güncellemek için:
   ```
   gh release download v1.0.1 -R onurklc012/hunters-hq-desktop -D C:\HuntersHQ\website\site\download --clobber
   C:\HuntersHQ\website\yayinla.cmd
   ```
   (`deploy.ps1`, `.exe` dosyasını sitenin GitHub kopyasına koymaz.)

## SignPath kurulumu (başvuru onaylandıktan sonra, bir kez)

SignPath'te:
- Proje slug'ı `hunters-hq-desktop` olmalı. **Trusted build system** olarak *GitHub.com* bağlanmalı.
- Artifact configuration `app` = `.signpath/artifact-configurations/app.xml` içeriği.
- Artifact configuration `installer` = `.signpath/artifact-configurations/installer.xml` içeriği.
- Signing policy `release-signing` (release certificate), approver = sen. Mümkünse "require GitHub-hosted runners" seçeneğini aç.
- Bir CI kullanıcısı için API token oluştur (submitter yetkisiyle).

GitHub deposunda (Settings → Secrets and variables → Actions):
- **Variable** `SIGNPATH_ORGANIZATION_ID` = SignPath organizasyon kimliği.
- **Secret** `SIGNPATH_API_TOKEN` = yukarıdaki token.

Bu ikisi tanımlanana kadar iş akışı imzasız sürüm çıkarır.

Zorunlu: GitHub ve SignPath hesaplarında iki adımlı doğrulama (2FA) açık olmalı.

## Kendi sertifikanla yerel imzalama (SignPath dışında)

Sertifika Windows deposundaysa (örneğin Certum SimplySign) şunları çalıştır:
`$env:HQ_SIGN_THUMBPRINT = '<parmak izi>'` ve ardından `build.ps1`. `sign.ps1` uygulamayı, kurulum dosyasını ve
kaldırıcıyı imzalar.

## Sunucu PC'de derleme

`C:\HuntersHQ\scripts\desktop\member-app\build.ps1` çıktıyı `C:\HuntersHQ\data\member-app\` klasörüne yazar.
Başka yerde çalışırsa çıktı `.\out\` klasörüne gider.
