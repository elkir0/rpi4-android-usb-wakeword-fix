# Recompiler l'APEX audio Pi 4 pour Android 16

## Base validée

- AOSP : `android-16.0.0_r4` ;
- manifeste local Raspberry Vanilla : branche `android-16.0` ;
- dépôt device : `raspberry-vanilla/android_device_brcm_rpi4` ;
- commit Pi 4 : `99ff5b226fdc9aef7cbec72736a58b959ba58619` ;
- cible lunch : `aosp_rpi4-bp4a-userdebug` ;
- module : `com.android.hardware.audio.rpi` ;
- build ID observé : `BP4A.251205.006`.

Le build de validation a terminé 9 044 actions en 1 h 54 sur une VM x86_64 à
6 vCPU et 12 Gio de RAM, avec beaucoup de swap pendant la génération Soong.
Pour un nouveau build, 24 à 32 Gio de RAM et au moins 250 Gio de SSD sont plus
confortables.

## Initialiser les sources

```sh
mkdir android-rpi4
cd android-rpi4
repo init -u https://android.googlesource.com/platform/manifest \
  -b android-16.0.0_r4
curl -o .repo/local_manifests/manifest_brcm_rpi.xml -L \
  https://raw.githubusercontent.com/raspberry-vanilla/android_local_manifest/android-16.0/manifest_brcm_rpi.xml \
  --create-dirs
repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune -j6
```

Le manifeste distant évolue. Épingler explicitement le dépôt device avant
d'appliquer le patch :

```sh
git -C device/brcm/rpi4 fetch origin \
  99ff5b226fdc9aef7cbec72736a58b959ba58619
git -C device/brcm/rpi4 checkout --detach \
  99ff5b226fdc9aef7cbec72736a58b959ba58619
git -C device/brcm/rpi4 rev-parse HEAD
```

La dernière commande doit afficher exactement le commit attendu.

## Vérifier et appliquer le patch

Depuis la racine AOSP :

```sh
git -C device/brcm/rpi4 apply --check \
  /chemin/rpi4-android-usb-wakeword-fix/patches/0002-audio-alsa-read-input-synchronously.patch
git -C device/brcm/rpi4 apply \
  /chemin/rpi4-android-usb-wakeword-fix/patches/0002-audio-alsa-read-input-synchronously.patch
git -C device/brcm/rpi4 diff --check
git -C device/brcm/rpi4 diff -- audio/alsa/StreamAlsa.cpp
```

Le patch ne doit modifier que `audio/alsa/StreamAlsa.cpp`. Il supprime le pipe
asynchrone pour l'entrée, utilise `proxy_read_with_retries()` dans
`transfer()` et conserve le thread asynchrone de sortie.

## Construire uniquement l'APEX

```sh
source build/envsetup.sh
lunch aosp_rpi4-bp4a-userdebug
OUT_DIR=out-audio-rpi4 m com.android.hardware.audio.rpi -j6
```

L'artefact se trouve normalement sous :

```text
out-audio-rpi4/target/product/rpi4/vendor/apex/com.android.hardware.audio.rpi.apex
```

Le build validé a produit :

```text
SHA-256 a8c735ede091b92770cb74162baaa826c69708a26d7fce0d59d62b082d989ccc
taille  16101376 octets
```

Une différence n'est pas automatiquement une erreur si l'environnement ou
les révisions diffèrent, mais elle rend le package binaire test1 incompatible.
Il faut alors auditer, signer et tester un nouvel artefact avec de nouvelles
gardes SHA-256.

## Vérifier l'APEX

Utiliser les outils hôte produits par AOSP, par exemple `apex-ls` et le
verifier APEX, puis comparer avec l'APEX stock de la build cible :

- nom de package ;
- clé publique APEX ;
- certificat de signature APK ;
- manifestes, fichiers `rc` et VINTF ;
- architecture ARM64 ;
- présence de `android.hardware.audio.service.rpi` et
  `libalsautilsv2-rpi.so`.

Le simple fait qu'un APEX porte le même nom ne garantit pas que le système
l'acceptera. Les identités de signature doivent être compatibles avec la
build cible.

## Construire un package expérimental

Copier l'APEX validé hors de Git, construire le helper, puis :

```sh
cd /chemin/rpi4-android-usb-wakeword-fix
gradle -p diagnostics/speech-test :app:assembleDebug --no-daemon
APEX_PATH=/chemin/com.android.hardware.audio.rpi.apex \
  ./scripts/build-release.sh
```

Le script refuse l'APEX si son hash n'est pas celui de test1. Pour porter le
correctif à une autre build, mettre à jour les constantes, documenter toutes
les nouvelles empreintes et publier une release distincte plutôt que de
réutiliser le même nom.
