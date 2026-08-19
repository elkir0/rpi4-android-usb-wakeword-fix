# Tutoriel complet — micro USB, Voice Match et wakeword sur Raspberry Pi 4

Ce guide correspond au correctif expérimental validé le **19 août 2026** sur
un Raspberry Pi 4 sous KonstaKANG LineageOS 23.2 / Android 16, build du
20 mai 2026.

## 1. Compatibilité et avertissements

La release binaire est strictement liée aux fichiers suivants :

| Élément | SHA-256 |
|---|---|
| APEX audio stock | `27b5332e841f50e6b3435b5b512c86981443764e54a517262976bc98f0b587f3` |
| APEX audio corrigé | `a8c735ede091b92770cb74162baaa826c69708a26d7fce0d59d62b082d989ccc` |
| Audio Policy USB stock | `29d18b8e3ca51dc1f6e54fd39886a60e2372a9e1f610ae9d285311e312b732d5` |
| Audio Policy USB corrigée | `bb1c738411bd04e612cd5b907fef7674e34b9f939456f4fc33430f9b2b8153a9` |

L'installateur vérifie ces empreintes avant toute modification et refuse un
fichier inconnu. Ne supprimez pas ce contrôle et ne renommez pas un APEX d'une
autre build pour le forcer.

État réel de la validation Pi 4 :

- micro HNHK mono ouvert à 48 kHz : validé ;
- reconnaissance Google de la phrase prononcée : validée ;
- capture HOTWORD USB mono pendant Voice Match : validée ;
- erreur stéréo `-22` et insertion de silence HAL : corrigées ;
- déclenchement final « Hey Google » après reboot : encore à confirmer.

## 2. Pourquoi trois couches sont nécessaires

### Politique USB mono/stéréo

Le micro HNHK n'expose qu'un canal. La politique Pi 4 stock annonce pourtant
`AUDIO_CHANNEL_IN_STEREO` pour `USB Device In`. Google demande une entrée mono,
puis l'ouverture ALSA échoue :

```text
openProxyForExternalDevice ... error=-22
```

Le fichier corrigé annonce les deux possibilités :

```text
AUDIO_CHANNEL_IN_MONO AUDIO_CHANNEL_IN_STEREO
```

La stéréo reste disponible pour les autres interfaces USB.

### Lecture ALSA synchrone

Le HAL Android 16 lit ALSA dans un thread de fond et alimente un `MonoPipe` non
bloquant. Sur les blocs HOTWORD de 240 frames, AudioFlinger peut lire avant le
remplissage et reçoit alors du silence :

```text
AHAL_StreamAlsa: transfer: incomplete data received, inserting 240 frames of silence
```

Le patch lit l'entrée directement avec `proxy_read_with_retries()` dans
`transfer()`. Le chemin de sortie reste asynchrone et inchangé.

### Routage persistant

Le build expose aussi un faux micro intégré sans signal utile. Le service
`usb_mic_runtime`, lancé après `sys.boot_completed=1`, préfère le micro USB
pour les presets MIC (1), VOICE_RECOGNITION (6) et HOTWORD (1999), rend le
micro intégré indisponible, règle le gain HNHK à 20/30 et active son AGC.

## 3. Prérequis

- Raspberry Pi 4 et build exacte décrite ci-dessus ;
- TWRP démarrable et déjà testé ;
- sauvegarde TWRP vérifiée de `/vendor` ;
- `/data` montable depuis TWRP ;
- MindTheGapps 16.0 ARM64, application Google et Gemini fonctionnels ;
- compte Google connecté et permissions micro accordées ;
- un seul périphérique d'entrée USB pendant le diagnostic ;
- ADB disponible pour les vérifications.

Le helper utilise des API Android internes et le domaine SELinux `u:r:su:s0`
présent sur cette build. Une autre version peut demander une adaptation.

## 4. Télécharger et vérifier

Télécharger depuis la page **Releases** :

- `install-rpi4-android-usb-wakeword-fix.zip` ;
- `rollback-rpi4-android-usb-wakeword-fix.zip` ;
- `SHA256SUMS`.

Sous macOS :

```sh
shasum -a 256 -c SHA256SUMS
```

Sous Linux :

```sh
sha256sum -c SHA256SUMS
```

Tous les fichiers présents doivent répondre `OK`.

## 5. Installation TWRP recommandée

### Préparer les fichiers

Depuis Android, remplacer `SERIAL` par la valeur donnée par `adb devices` :

```sh
adb -s SERIAL push install-rpi4-android-usb-wakeword-fix.zip /sdcard/Download/
adb -s SERIAL push rollback-rpi4-android-usb-wakeword-fix.zip /sdcard/Download/
adb -s SERIAL reboot recovery
```

Les ports ADB sans fil changent après un redémarrage. Refaire l'association ou
la connexion si nécessaire.

### Dans TWRP

1. Monter `/vendor` et `/data` si TWRP ne le fait pas automatiquement.
2. Créer puis vérifier une sauvegarde de `/vendor`.
3. Flasher **uniquement** `install-rpi4-android-usb-wakeword-fix.zip`.
4. Lire le résultat : il doit finir par `Installation et sauvegarde verifiees`.
5. Redémarrer vers System.

L'installateur :

- vérifie l'APEX et la politique stock ;
- sauvegarde l'APEX stock sous
  `/data/local/tmp/rpi4-usb-wakeword-backup/` ;
- installe l'APEX corrigé et la politique mono/stéréo ;
- installe le service, son script et le helper AudioSystem ;
- vérifie à nouveau chaque fichier avant de terminer.

Il est idempotent : une réinstallation est acceptée si les fichiers sont déjà
corrigés **et** si la sauvegarde stock exacte existe toujours.

## 6. Premier démarrage et langue française

Attendre la fin complète du démarrage et reconnecter ADB :

```sh
adb -s SERIAL root
adb -s SERIAL shell 'cmd locale set-device-locale fr-FR'
adb -s SERIAL shell 'cmd locale get-device-locale; cmd activity get-config | head -n 1'
```

Les résultats attendus contiennent `fr-FR` et `fr-rFR`. Cette commande passe
tout le système en français, pas seulement Google.

## 7. Contrôler l'installation après reboot

Ne lancez aucun script manuel avant cette étape : il faut d'abord vérifier que
l'automatisation de boot fonctionne seule.

```sh
adb -s SERIAL root
adb -s SERIAL shell sha256sum \
  /vendor/apex/com.android.hardware.audio.rpi.apex \
  /vendor/etc/usb_audio_policy_configuration.xml \
  /vendor/etc/init/usb-mic-runtime.rc \
  /vendor/bin/usb-mic-runtime.sh \
  /vendor/etc/usb-mic-route.apk
adb -s SERIAL shell getprop init.svc.usb_mic_runtime
adb -s SERIAL shell cat /data/local/tmp/usb-mic-runtime.log
```

Empreintes attendues pour l'APEX et la politique :

```text
a8c735ede091b92770cb74162baaa826c69708a26d7fce0d59d62b082d989ccc
bb1c738411bd04e612cd5b907fef7674e34b9f939456f4fc33430f9b2b8153a9
```

Le service est `oneshot` : `init.svc.usb_mic_runtime=stopped` est normal une
fois son travail terminé. Le journal doit montrer la carte ALSA trouvée, les
résultats `preferred USB result=0` et, si un modèle HOTWORD est déjà actif, une
entrée USB active.

## 8. Vérifier le canal mono et le routage

Identifier d'abord la carte du micro :

```sh
adb -s SERIAL shell 'cat /proc/asound/cards; cat /proc/asound/card*/stream0'
```

Puis inspecter Android :

```sh
adb -s SERIAL shell 'dumpsys media.audio_policy' | \
  sed -n '/Inputs (/,/Total Effects/p'
adb -s SERIAL shell 'dumpsys media.audio_flinger' | \
  grep -A40 'Input thread'
```

Pendant une capture, les critères sont :

- `AUDIO_DEVICE_IN_USB_DEVICE` ;
- 48 000 Hz ;
- `Channel count: 1` ou masque mono `0x10` ;
- `Frames read` augmente ;
- le niveau du signal monte quand on parle ;
- `readErrors=0` ;
- aucune erreur `openProxyForExternalDevice ... -22` ;
- aucune répétition de `incomplete data received`.

## 9. Test de reconnaissance Google

Le dépôt contient une petite application de diagnostic. Après sa compilation :

```sh
adb -s SERIAL install -r \
  diagnostics/speech-test/app/build/outputs/apk/debug/app-debug.apk
adb -s SERIAL shell am start -n \
  local.raspberry.speechtest/.MainActivity
```

Autoriser le micro puis dire « test microphone bonjour ». Le test validé a
renvoyé :

```text
resultCode=-1
Résultat : [test microphone bonjour]
```

Une reconnaissance réussie prouve que Google reçoit réellement le son ; la
simple présence d'une carte USB ne le prouve pas.

## 10. Entraîner Voice Match

Le micro HNHK testé ne supporte qu'une capture à la fois. Le listener HOTWORD
peut donc monopoliser le périphérique au moment de l'enrôlement. La procédure
doit être suivie précisément et contient un garde-fou important sur le PID.

Voir [`VOICE-MATCH-FR.md`](VOICE-MATCH-FR.md).

Résumé : ouvrir Voice Match, identifier **uniquement** le processus isolé
`u0_i...` dont la commande contient à la fois le paquet Google et `gsa.hot`, le
tuer juste avant de toucher « Réentraîner », terminer les phrases, puis lancer
`cmd voiceinteraction restart-detection`.

Ne jamais utiliser `pkill`, ne jamais arrêter tout le paquet Google et ne pas
tuer le processus `:interactor`.

## 11. Validation finale du wakeword

Après l'enrôlement puis après un reboot propre :

```sh
adb -s SERIAL shell 'cmd voiceinteraction restart-detection'
adb -s SERIAL shell 'dumpsys voiceinteraction' | \
  grep -E 'Hotword detection connection|mPerformingSoftwareHotwordDetection'
adb -s SERIAL shell logcat -c
```

Dire « Hey Google », attendre quelques secondes, puis :

```sh
adb -s SERIAL shell logcat -d | grep -E \
  'Fired hotword model|hotword score|Speaker Detected|speaker score|incomplete data received|read failed|openProxyForExternalDevice'
```

La validation complète exige simultanément :

- l'ouverture visible de l'Assistant/Gemini ;
- `Fired hotword model` dans les logs ;
- un score hotword et, si disponible, un score de locuteur ;
- aucune insertion de silence ni erreur de lecture.

Cette dernière validation reste à consigner pour la prerelease Pi 4 test1.

## 12. Vérifications silencieuses

Quand il n'est pas possible de parler, on peut tout de même contrôler :

```sh
adb -s SERIAL shell cat /data/local/tmp/usb-mic-runtime.log
adb -s SERIAL shell dumpsys voiceinteraction
adb -s SERIAL shell dumpsys media.audio_policy
adb -s SERIAL shell dumpsys media.audio_flinger
adb -s SERIAL shell ps -A -o USER,PID,PPID,ARGS | grep -i gsa.hot
```

Ces contrôles confirment le routage et l'état du détecteur, mais ne remplacent
pas un test parlé réel.

## 13. Retour arrière

Redémarrer dans TWRP et flasher :

```text
rollback-rpi4-android-usb-wakeword-fix.zip
```

Le ZIP vérifie d'abord la sauvegarde stock, puis :

- remet l'APEX stock ;
- remet la politique USB stock ;
- supprime `usb-mic-runtime.rc`, `usb-mic-runtime.sh` et le helper APK ;
- conserve la sauvegarde dans `/data`.

Si l'APEX actuel est corrigé mais que la sauvegarde exacte manque, le rollback
s'arrête sans effectuer de restauration partielle. Utiliser alors la
sauvegarde TWRP de `/vendor` ou l'OTA officiel correspondant.

Après redémarrage :

```sh
adb -s SERIAL root
adb -s SERIAL shell sha256sum \
  /vendor/apex/com.android.hardware.audio.rpi.apex \
  /vendor/etc/usb_audio_policy_configuration.xml
```

Les deux empreintes doivent être les valeurs stock du tableau initial.

## 14. Diagnostic rapide

| Symptôme | Cause probable | Contrôle/action |
|---|---|---|
| ZIP refuse l'APEX | build différente | ne pas forcer ; recompiler pour la source exacte |
| ZIP refuse l'Audio Policy | fichier déjà modifié ou build différente | restaurer `/vendor`, puis réévaluer le diff |
| `error=-22` | profil/canal incompatible | vérifier mono dans la politique et `stream0` |
| `Frames read=0` | flux non ouvert | vérifier Audio Policy, HAL et périphérique USB |
| reconnaissance OK, entraînement sourd | listener HOTWORD occupe l'unique flux | suivre `VOICE-MATCH-FR.md` |
| routage perdu après reboot | service tardif absent/en échec | lire `usb-mic-runtime.log` |
| HOTWORD inactif sans modèle | Voice Match non terminé | terminer l'enrôlement puis réarmer |
| boucle de démarrage | fichier `/vendor` incompatible | restaurer la sauvegarde TWRP |

## 15. Installation manuelle réservée au diagnostic

La méthode TWRP est recommandée. Une copie ADB manuelle exige `adb root`, un
`/vendor` remontable en écriture, les mêmes validations SHA-256 et une
sauvegarde stock hors du périphérique. Ne remplacez jamais l'APEX pendant
qu'Android fonctionne sans disposer d'un TWRP opérationnel.

Pour étudier ou adapter la source à une autre build, suivre
[`BUILD-FR.md`](BUILD-FR.md) au lieu de réutiliser le binaire test1.
