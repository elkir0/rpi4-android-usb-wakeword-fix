# Application compagnon USB Voice Match

## Objectif

Créer une application Android qui guide l'installation et le diagnostic du
micro USB, de Voice Match et du wakeword sur les builds Android Raspberry Pi.
Elle doit rendre visibles les étapes techniques sans prétendre qu'une
application Android ordinaire possède les privilèges système nécessaires.

La base réutilisable existe déjà dans `diagnostics/speech-test/` : elle sait
lancer une reconnaissance Google réelle et contient le helper de routage
`RouteMic` utilisé après le démarrage.

## Limite de sécurité importante

Une application non privilégiée ne peut pas :

- remplacer un APEX sous `/vendor` ;
- modifier la politique audio de `/vendor` ;
- exécuter `dumpsys` complet ou `cmd voiceinteraction` ;
- tuer le processus isolé du détecteur HOTWORD d'une autre application.

Le produit doit donc proposer deux modes clairement séparés :

1. **Mode Android sans privilèges** : guide, test AudioRecord, vumètre, liens
   profonds vers les réglages Google et affichage des résultats accessibles ;
2. **Mode compagnon ADB/root** : petit outil côté ordinateur qui exécute les
   contrôles privilégiés après validation explicite de chaque cible.

Une évolution Shizuku peut être étudiée, mais elle ne doit pas être requise
pour le premier prototype.

## Parcours utilisateur

```text
PRÉREQUIS
  -> LANGUE
  -> MICRO ALSA/ANDROID
  -> ROUTAGE USB
  -> TEST DE RECONNAISSANCE
  -> PRÉPARATION VOICE MATCH
  -> ENRÔLEMENT
  -> RÉARMEMENT HOTWORD
  -> TEST « HEY GOOGLE »
  -> RAPPORT EXPORTABLE
```

Chaque écran doit afficher un état `OK`, `À FAIRE` ou `ERREUR`, les preuves
mesurées et l'action suivante. Aucune étape ne doit être déclarée réussie sur
la seule présence du périphérique USB.

## MVP Android

- afficher la locale système et ouvrir le sélecteur de langue ;
- lancer l'intent officiel des réglages Assistant :
  `com.google.android.googlequicksearchbox.action.ASSISTANT_SETTINGS` ;
- tester `AudioRecord` en mono 48 kHz puis afficher un vumètre ;
- lancer une reconnaissance `fr-FR` et afficher le texte reconnu ;
- expliquer le conflit de capture exclusive pendant Voice Match ;
- afficher une procédure pas à pas pour les phrases d'enrôlement ;
- exporter un rapport texte ne contenant aucune donnée audio ni identifiant de
  compte Google.

## Compagnon ADB/root

Le compagnon doit automatiser uniquement des opérations déterministes :

- vérifier le modèle, le fingerprint, la version Android et les hashes connus ;
- vérifier `AUDIO_DEVICE_IN_USB_DEVICE`, le canal mono et les frames lues ;
- régler la locale avec `cmd locale set-device-locale` ;
- ouvrir l'écran Voice Match ;
- trouver le listener avec `ps -A -o USER,PID,PPID,ARGS` ;
- accepter un PID seulement si l'utilisateur commence par `u0_i` **et** si la
  commande contient `com.google.android.googlequicksearchbox` et `gsa.hot` ;
- demander confirmation avant `kill -9 PID_ISOLE` ;
- exécuter `cmd voiceinteraction restart-detection` après l'enrôlement ;
- vérifier `mPerformingSoftwareHotwordDetection=true` et l'entrée HOTWORD USB ;
- collecter uniquement les lignes de log utiles au diagnostic.

Le compagnon ne doit jamais utiliser `pkill`, tuer `:interactor`, arrêter tout
le paquet Google, ni modifier `/vendor` sans hash de compatibilité et rollback.

## Détection du problème Pi4 mono/stéréo

Le diagnostic doit comparer :

- `/proc/asound/cardN/stream0` ;
- le profil `USB Device In` de `usb_audio_policy_configuration.xml` ;
- le canal réellement négocié dans `dumpsys media.audio_flinger` ;
- les erreurs `openProxyForExternalDevice ... error=-22`.

Si le matériel est mono mais qu'Android force la stéréo, le rapport doit
indiquer explicitement « profil USB incompatible » au lieu de conclure à un
micro silencieux.

## Critères d'acceptation

Le parcours complet est validé seulement si :

- une reconnaissance vocale renvoie la phrase prononcée ;
- `Frames read` augmente et le niveau du signal réagit à la voix ;
- aucune erreur `incomplete data received`, `read failed` ou
  `openProxyForExternalDevice ... -22` n'est présente ;
- le listener HOTWORD est actif sur le micro USB ;
- « Hey Google » ouvre réellement l'Assistant après un redémarrage à froid.

## Découpage proposé

1. étendre l'application `speech-test` avec vumètre et écran de diagnostic ;
2. créer un script compagnon ADB idempotent et journalisé ;
3. ajouter le parcours Voice Match guidé avec garde-fou PID ;
4. générer un rapport partageable pour les tickets KonstaKANG ;
5. tester Pi4 et Pi5, puis documenter les différences de politique audio.
