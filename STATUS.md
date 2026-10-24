# STATUS (Loop-Arbeitsstand, nach jedem Schritt aktualisieren)

Ziel: Windows-Matlab-App (Wine + MATLAB + Desktop) als Pod-App, E2E auf Staging.
Fertig erst wenn alle 5 Punkte erfüllt: (i) MATLAB läuft unter Wine im Pod, (ii) CI/CD + app-registry,
(iii) Staging-Rollout mit /claude-in-chrome + eigenem Testuser, (iv) Deployment läuft, Testuser bedient MATLAB,
(v) vCPU/RAM im Frontend pro Deployment einstellbar, NUR für diese App (Opt-in resourceBounds).

## Fakten
- Repo: DHBW-AppStore-T3/Windows-Matlab-App (lokal /Users/I751109/Documents/coding-projects/DHBW-AppStore/Windows-Matlab-App), Branch dev (+ main).
- Ursache mpm.exe-Abbruch: Wine 11.0 `GetProcessGroupAffinity` ist Stub -> MathWorks computeNumberOfCores wirft. Fix: Patch image/patches/0001-*.patch, Wine wird im Dockerfile gebaut (Stage wine-build).
- Image: ghcr.io/dhbw-appstore-t3/apps/windows-matlab (öffentlich, ohne MATLAB). Build: Workflow "Build image (pod runtime)".
- Sandbox-Pod: Namespace wm-poc, Pod wm (Test, SPÄTER LÖSCHEN). Manifest: scratchpad/wm-test.yaml (Autostart), wm-dev.yaml (sleep infinity).
  Kubeconfig: /Users/I751109/Documents/coding-projects/DHBW-AppStore/k8s-credentials/kubeconfig-ma_wwi_24sea_appstore_g3.yaml
- Lizenz: Online (MathWorks-SSO), Studierende aktivieren selbst. Kein Download-Schritt für Nutzer, alles automatisch.
- Node: 4 vCPU / 16 GiB, ein Node.
- Resource-Feature NUR für diese App (Opt-in `resourceBounds` in appstore.yaml), nicht für Jupyter/pgAdmin.
- Repos Backend/Worker/Frontend/Deployment: Branch dev, PRs auf dev (nie direkt main). Commit-Trailer: Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>

## Erledigt
- Repo angelegt, Wine-Desktop (Xvfb/openbox/noVNC) läuft im Pod mit Plattform-Sicherheitskontext.
- Ursache gefunden, Patch + Multi-Stage-Dockerfile gepusht (Run 40031812224 baut Wine).

- (v) Resource-Feature gebaut: PRs offen backend#21 (spec.py resourceBounds + apply_resource_overrides + /runtime.resources), worker#16 (spec.py identisch), frontend#40 (ResourcePicker im Variablen-Schritt). Lokal getestet (backend 950 Tests grün, frontend 1389 grün). TODO: CI grün abwarten + mergen (Reihenfolge backend, worker, frontend).
- Lokale Test-Infra: colima läuft, Postgres-Container `pgtest` Port 55433; backend .venv via poetry (Python 3.14); frontend npm ci erledigt.

- (i) TEILWEISE: Wine-Build (digest sha256:456d9352...be447, ghcr windows-matlab) mit Patch OK, `mpm.exe --help` läuft im Pod. MATLAB-Install läuft im Sandbox-Pod (wm-poc/wm, Log /home/wine/user/install.log, nohup wine mpm.exe install R2024b MATLAB). NÄCHSTES: Install-Ende abwarten, dann `wine C:\MATLAB\bin\matlab.exe -batch "disp(version)"` / -desktop per noVNC (Port-Forward 8080) prüfen.
- (ii) lokal vorbereitet, NICHT committet: appstore.yaml (Tag :dev statt Digest!), .hadolint.yaml, .github/workflows/ci.yml (ruft app-registry app-ci.yml, ersetzt image.yml), VNC-Passwort in start.sh. Danach: commit+push dev, CI abwarten, Digest in appstore.yaml, Tag v1.0.0, app-registry PR apps/windows-matlab-app.yaml.
- PRs: backend#21 (+Fix pip-audit setuptools/filelock), worker#16 (black), frontend#40, deployment#119 (APP_MAX 4 CPU/8Gi). CI prüfen, mergen: backend, worker, deployment, frontend.

- (i) ERREICHT bis Aktivierung: mpm.exe installiert MATLAB R2024b (4.6G) unter gepatchtem Wine; matlab -batch -> "License checkout failed" (erwartet); matlab -desktop zeigt MathWorks Product Activation (Login) im Desktop. Nötig: WINEDLLOVERRIDES msvcp140/vcruntime140=n,b (in Dockerfile ENV, noch nicht gebaut/deployed). Voller Funktionstest (MATLAB-Fenster nach Login) nur mit Lizenz-Account möglich.
- app-registry PR #3 (Validator resourceBounds, Limits 4000m/8192Mi, apps/windows-matlab-app.yaml) -> muss gemergt sein, bevor Windows-Matlab-App CI grün wird (CI zieht Validator von main).

- BLOCKIERT (Stand 2026-10-24 ~01:10): Das Mergen der vier grünen PRs (backend#21, worker#16, deployment#119, frontend#40, alle CI grün) wurde vom Auto-Mode-Classifier abgelehnt ("Merge Without Review"). NICHT umgehen (auch kein --auto). Der Nutzer muss die PRs mergen oder eine Permission-Regel erlauben. Ohne Merge kennt Staging `resourceBounds` nicht -> App-Version kann dort nicht eingereicht werden (extra=forbid) -> Schritte iii/iv/v-Staging blockiert.
- app-registry PR #3 ist gemergt (Validator + Eintrag). Windows-Matlab-App: main=dev gepusht, CI-Run 40042632753 baut das Image (ca. 35 min, danach Digest in appstore.yaml, Tag v1.0.0).

- BLOCKIERT 2: app-registry app-ci.yml referenziert `trivy-action@0.28.0` (existiert nicht, Tag ist v0.28.0) -> Build-Job der App-CI bricht beim Setup ab. Fix-PR: app-registry#4 (fix/trivy-action-tag). Muss gemergt werden (Merge-Permission fehlt, s.o.). Danach CI-Run der Windows-Matlab-App neu starten: `gh workflow run ci.yml -R DHBW-AppStore-T3/Windows-Matlab-App --ref dev` (hadolint + validate sind bereits grün).

## Offen (Reihenfolge)
1. Build-Run 40031812224 abwarten, Digest holen, Sandbox-Pod mit neuem Image: läuft mpm.exe? MATLAB installieren (R2024b, Produkt MATLAB), matlab.exe startet bis Aktivierungsdialog? (i)
2. appstore.yaml (scope user, storage <=20Gi, egress internet, resources default 2 vCPU/4Gi, resourceBounds), Digest eintragen, Tag v1.0.0, app-registry PR (apps/windows-matlab-app.yaml + CI caller), deployment seed description, Frontend-Icon. (ii)
3. Backend/Worker/Frontend: resourceBounds in spec.py (extra=forbid -> Feld ergänzen, in Backend UND Worker identisch, test_shared_files!), Override in userInputVar.resources, Validierung gegen Bounds/APP_MAX_*, Wizard-UI, Tests. APP_MAX_* in deployment/k8s anheben (cpu 4? mem 8Gi, storage 20Gi). (v)
4. Staging: App registrieren (POST /apps), Version einreichen, Admin-Freigabe, Testuser anlegen (Keycloak staging), Deployment per Browser (/claude-in-chrome). (iii, iv)
5. Aufräumen: wm-poc Namespace löschen, Loop beenden (ScheduleWakeup stop / CronDelete).

## Log
- 2026-10-24: Loop gestartet (30 min).
