# Entraîner Voice Match avec un microphone USB à capture unique

## Pourquoi l'écran peut sembler sourd

La reconnaissance Google normale et l'enrôlement Voice Match ne suivent pas
exactement le même cycle. Sur le HNHK testé, un seul flux ALSA peut être ouvert
à la fois. Le processus isolé du listener HOTWORD peut déjà occuper ce flux au
moment où l'écran d'entraînement veut l'utiliser.

La manipulation ci-dessous libère uniquement ce listener. Google le recrée
ensuite. Elle ne remplace pas le correctif APEX ou la politique mono.

## 1. Aligner la langue

```sh
adb -s SERIAL root
adb -s SERIAL shell 'cmd locale set-device-locale fr-FR'
adb -s SERIAL shell 'cmd locale get-device-locale; cmd activity get-config | head -n 1'
```

Attendre `fr-FR` et `fr-rFR`. Vérifier également que la langue de l'Assistant
est bien le français voulu.

## 2. Vérifier que HOTWORD utilise l'USB

```sh
adb -s SERIAL shell 'dumpsys voiceinteraction' | \
  grep -E 'Hotword detection connection|mPerformingSoftwareHotwordDetection'
adb -s SERIAL shell 'dumpsys media.audio_policy' | \
  sed -n '/Inputs (/,/Total Effects/p'
```

Si un modèle existe déjà, on attend `mPerformingSoftwareHotwordDetection=true`
et une entrée source 1999 sur `AUDIO_DEVICE_IN_USB_DEVICE` en mono.

## 3. Ouvrir l'écran Voice Match

```sh
adb -s SERIAL shell am start -a \
  com.google.android.googlequicksearchbox.action.ASSISTANT_SETTINGS
```

Dans l'interface : **Hey Google et Voice Match** puis **Réentraîner l'empreinte
vocale Voice Match**. Rester juste avant le lancement effectif des phrases.

## 4. Identifier le seul processus autorisé

Dans un terminal :

```sh
adb -s SERIAL shell \
  "ps -A -o USER,PID,PPID,ARGS | grep -i 'gsa.hot' | grep -v grep"
```

Exemple observé :

```text
u0_i9004  5063  608  com.google.android.googlequicksearchbox:...:gsa.hot
```

Avant toute action, vérifier **les trois** conditions :

1. l'utilisateur commence par `u0_i` ;
2. la commande contient `com.google.android.googlequicksearchbox` ;
3. la commande contient `gsa.hot`.

S'il y a zéro ou plusieurs lignes ambiguës, s'arrêter et ne rien tuer.

## 5. Libérer le flux puis entraîner immédiatement

Juste avant de toucher le bouton de réentraînement :

```sh
adb -s SERIAL shell kill -9 PID_ISOLE
```

Toucher immédiatement **Réentraîner**, puis prononcer les phrases affichées.

Interdictions :

- pas de `pkill` ;
- pas de `am force-stop` sur l'application Google ;
- ne pas tuer `:interactor` ;
- ne pas tuer un PID qui ne satisfait pas exactement les trois gardes.

## 6. Observer la capture depuis un second terminal

Pendant que l'écran écoute :

```sh
adb -s SERIAL shell 'dumpsys media.audio_flinger' | \
  grep -A40 'Input thread'
```

Les preuves utiles sont :

- `Standby: no` ;
- 48 000 Hz et un canal ;
- `AUDIO_DEVICE_IN_USB_DEVICE` ;
- `Frames read` augmente ;
- le signal varie lorsque l'on parle ;
- `readErrors=0` ;
- aucune insertion de silence.

Sur le Pi 4 testé, cette méthode a permis de lire plus de 600 000 frames
réelles pendant l'enrôlement.

## 7. Réarmer le listener

Une fois revenu à l'écran Voice Match :

```sh
adb -s SERIAL shell 'cmd voiceinteraction restart-detection'
adb -s SERIAL shell 'dumpsys voiceinteraction' | \
  grep -E 'Hotword detection connection|mPerformingSoftwareHotwordDetection'
adb -s SERIAL shell 'dumpsys media.audio_policy' | \
  sed -n '/Inputs (/,/Total Effects/p'
```

Google doit avoir recréé le processus isolé et HOTWORD doit revenir sur le
micro USB.

## 8. Tester réellement

```sh
adb -s SERIAL shell logcat -c
# Dire « Hey Google », attendre, puis :
adb -s SERIAL shell logcat -d | grep -E \
  'Fired hotword model|hotword score|Speaker Detected|speaker score|incomplete data received|read failed'
```

Un état interne actif n'est pas une validation suffisante : l'Assistant doit
s'ouvrir en réponse à la phrase. Refaire ce test après un redémarrage à froid.

## Messages `SODA EnrollmentManager disabled`

Des lignes mentionnant SODA ou l'absence d'application d'enrôlement pour
`fr_FR` peuvent apparaître dans les logs Google. Elles ne prouvent pas à elles
seules que le micro est silencieux. La preuve décisive reste l'augmentation des
frames et du niveau dans AudioFlinger pendant l'écran d'entraînement.
