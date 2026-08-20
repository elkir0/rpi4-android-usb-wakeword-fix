# Raspberry Pi 4 Android USB wakeword fix

Correctif expérimental, sources et procédure reproductible pour utiliser un
microphone USB mono avec la reconnaissance Google, Voice Match et le wakeword
sur un Raspberry Pi 4 sous Android 16.

Ce dépôt décrit une méthode testée sur une machine réelle. Ce n'est ni une
version officielle KonstaKANG, ni un correctif universel pour tous les micros
USB ou toutes les builds Android.

## Configuration validée

- Raspberry Pi 4 Model B Rev 1.2 ;
- KonstaKANG LineageOS 23.2 / Android 16, build du 20 mai 2026 ;
- fingerprint `Raspberry/lineage_rpi4/rpi4:16/BP4A.251205.006/rpi4:user/release-keys` ;
- MindTheGapps 16.0 ARM64, application Google et Gemini ;
- microphone USB mono HNHK AI-Voice (`ffef:0f00`), S16_LE à 44,1/48 kHz.

La reconnaissance Google a renvoyé la phrase prononcée, le chemin HOTWORD a
capturé plus de 600 000 frames réelles pendant l'enrôlement et les erreurs HAL
ont disparu. La validation finale de la phrase « Hey Google » après
redémarrage reste à compléter : la première release est donc marquée
**expérimentale**.

## Les trois corrections nécessaires

| Couche | Problème observé | Correction |
|---|---|---|
| Audio Policy Pi 4 | Le profil `USB Device In` impose la stéréo alors que le HNHK est mono ; l'ouverture échoue avec `error=-22` | Publier mono **et** stéréo pour conserver la compatibilité |
| Audio HAL Android 16 | La course entre le lecteur ALSA et le `MonoPipe` remplace des blocs de 240 frames par du silence | Lire l'entrée ALSA synchroniquement ; sortie inchangée |
| Routage après boot | Android/Google sélectionne parfois le faux micro intégré et les préférences sont volatiles | Service tardif qui préfère l'USB pour MIC, VOICE_RECOGNITION et HOTWORD |

Le changement de politique est volontairement limité à :

```xml
channelMasks="AUDIO_CHANNEL_IN_MONO AUDIO_CHANNEL_IN_STEREO"
```

## Installation rapide

1. Télécharger les assets de la [dernière release](https://github.com/elkir0/rpi4-android-usb-wakeword-fix/releases).
2. Vérifier `SHA256SUMS`.
3. Faire dans TWRP une sauvegarde vérifiée de `/vendor`.
4. Flasher `install-rpi4-android-usb-wakeword-fix.zip`.
5. Redémarrer vers System, terminer Voice Match, puis vérifier le micro.

L'installateur refuse toute build dont les empreintes APEX ou Audio Policy ne
correspondent pas au système validé. Il sauvegarde l'APEX stock dans
`/data/local/tmp/rpi4-usb-wakeword-backup/` avant de le modifier.

Le tutoriel détaillé couvre les prérequis, l'installation, le français,
l'enrôlement Voice Match particulier, les contrôles silencieux, le diagnostic
et le retour arrière : [`docs/TUTORIEL-FR.md`](docs/TUTORIEL-FR.md).

L’application libre
[Raspberry Voice Setup](https://github.com/elkir0/rpi-android-voice-setup)
détecte les hashes connus, mesure réellement le micro USB et guide Voice Match.
Son compagnon ADB applique les garde-fous décrits dans ce dépôt. Les commandes
manuelles restent documentées ici : le correctif Pi 4 ne dépend pas de
l’application.

## Contenu du dépôt

```text
patches/                    patch source StreamAlsa Android 16
diagnostics/audio-policy/   service de routage USB persistant
diagnostics/speech-test/    source du helper AudioSystem et test Google
recovery/                   installateurs TWRP et politiques Pi 4
scripts/build-release.sh    construction et vérification des ZIP
docs/TUTORIEL-FR.md         installation et diagnostic complets
docs/BUILD-FR.md            reconstruction reproductible de l'APEX
docs/VOICE-MATCH-FR.md      procédure d'enrôlement à capture unique
docs/PROVENANCE-FR.md       commits, hashes et preuves de construction
```

Les APEX compilés, images Android, GApps, Widevine, enregistrements et clés de
signature sont exclus de l'historique Git. L'APEX corrigé est distribué
uniquement dans l'asset de release strictement lié à la build testée. Aucun
APEX KonstaKANG stock n'est redistribué.

## Construire les ZIP de release

Construire d'abord le helper :

```sh
cd diagnostics/speech-test
gradle :app:assembleDebug --no-daemon
cd ../..
```

Puis fournir l'APEX compatible :

```sh
APEX_PATH=/chemin/com.android.hardware.audio.rpi.apex \
  ./scripts/build-release.sh
```

Le script injecte dans chaque installateur les SHA-256 réels des payloads,
construit les deux ZIP TWRP et un bundle de release, teste toutes les archives
et écrit `dist/SHA256SUMS`.

## Recompiler l'APEX

Le build validé repose sur AOSP `android-16.0.0_r4`, le manifeste Raspberry
Vanilla `android-16.0`, le commit Pi 4
`99ff5b226fdc9aef7cbec72736a58b959ba58619` et la cible
`aosp_rpi4-bp4a-userdebug`. Voir [`docs/BUILD-FR.md`](docs/BUILD-FR.md).
Les empreintes et contrôles de provenance sont résumés dans
[`docs/PROVENANCE-FR.md`](docs/PROVENANCE-FR.md).

## Retour arrière

Le ZIP `rollback-rpi4-android-usb-wakeword-fix.zip` :

- restaure l'APEX stock sauvegardé par l'installateur ;
- restaure la politique USB stock ;
- retire le service et le helper de routage.

Si la sauvegarde locale manque, il refuse de remplacer un APEX corrigé. La
solution de secours reste la restauration TWRP de `/vendor` ou le reflash de
l'OTA officiel correspondant, obtenu depuis sa source officielle.

## Licence

Code, patch et documentation : Apache License 2.0. Voir [`LICENSE`](LICENSE) et
[`NOTICE`](NOTICE). Les marques et logiciels tiers restent la propriété de
leurs détenteurs.
