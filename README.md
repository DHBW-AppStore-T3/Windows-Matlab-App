# Windows-Matlab-App

Windows 11 mit MATLAB R2024b im Browser, als KubeVirt-VM für den DHBW AppStore: eine VM pro Person
(`scope: user`), Zugang per noVNC.

## Wie es funktioniert

- `appstore.yaml` (App-Vertrag v2, `runtime: kubevirt-vm`) beschreibt die VM: Vorgabe 4 vCPU, 8 GiB RAM, 90 GiB
  Platte; im Wizard wählbar 2-8 vCPU und 4-16 GiB (`vm.bounds`), dazu Internet- und Pod-Netz-Zugang (`userChoices`).
- Jede VM klont das Golden-Image `windows11-matlab-golden` (MATLAB vorinstalliert), eine Cinder-PVC im Namespace
  `vm-poc`. Angelegt wird sie mit `scripts/migrate-golden-image.sh` im Repo `deployment` (vorher
  `scripts/install-cinder-csi.sh`).
- Dieses Repo baut kein Image. `.github/workflows/spec.yml` prüft `appstore.yaml` mit dem zentralen Vertragscheck aus
  `DHBW-AppStore-T3/app-registry` (`validate-spec.yml@v1`), bei Änderungen und wöchentlich.

## Versionen

- `v2.x`: KubeVirt-VM (seit 2026-10-25).
- `v1.x`: die frühere Pod-Variante mit Wine (Image unter `image/`, Arbeitsstand in `STATUS.md`); nur noch über ihre
  Git-Tags erreichbar.

Ablauf: Änderung per PR nach `main`, Tag `v2.x.y`, Version im AppStore einreichen und freigeben.
