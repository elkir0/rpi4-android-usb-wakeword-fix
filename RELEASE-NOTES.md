# v0.1.0-test1

Première prerelease expérimentale du correctif USB/HOTWORD pour Raspberry Pi 4
sur KonstaKANG LineageOS 23.2 / Android 16, build du 20 mai 2026.

## Compatibilité exacte

- build ID `BP4A.251205.006` ;
- APEX stock SHA-256 :
  `27b5332e841f50e6b3435b5b512c86981443764e54a517262976bc98f0b587f3` ;
- APEX corrigé SHA-256 :
  `a8c735ede091b92770cb74162baaa826c69708a26d7fce0d59d62b082d989ccc` ;
- politique USB stock SHA-256 :
  `29d18b8e3ca51dc1f6e54fd39886a60e2372a9e1f610ae9d285311e312b732d5` ;
- politique USB corrigée SHA-256 :
  `bb1c738411bd04e612cd5b907fef7674e34b9f939456f4fc33430f9b2b8153a9`.

## Assets

- `install-rpi4-android-usb-wakeword-fix.zip` : APEX, politique mono/stéréo,
  routage tardif et helper ;
- `rollback-rpi4-android-usb-wakeword-fix.zip` : retour complet à partir de la
  sauvegarde créée lors de l'installation ;
- `rpi4-android-usb-wakeword-fix-lineageos23.2-20260520-test1.zip` : bundle
  contenant les ZIP TWRP, le guide de compatibilité, la licence et les hashes ;
- `SHA256SUMS` : empreintes de tous les assets.

| Asset | SHA-256 |
|---|---|
| `install-rpi4-android-usb-wakeword-fix.zip` | `e45af37711ac3a3a01af5a3dd68a87d15b6c18203572f584e6303229efa6a23f` |
| `rollback-rpi4-android-usb-wakeword-fix.zip` | `097699b38765a3273dcbc593e048d9a9c9e2ef1357e9e5f4ecab0883f4081894` |
| `rpi4-android-usb-wakeword-fix-lineageos23.2-20260520-test1.zip` | `4c73c10a8d7c0a37580ac389d2024e1d06f980fd30e178dab46d8881c6b05524` |

## Niveau de validation

- ouverture du micro mono à 48 kHz : OK ;
- reconnaissance Google réelle : `test microphone bonjour` reconnu ;
- entrée HOTWORD USB mono et frames réelles pendant Voice Match : OK ;
- aucune erreur `openProxyForExternalDevice ... -22` ou
  `incomplete data received` pendant les tests corrigés ;
- phrase finale « Hey Google » après reboot : validation encore en attente.

Ne contournez jamais les gardes SHA-256. Faites une sauvegarde TWRP de
`/vendor` avant le test. Aucun APEX stock n'est présent dans les assets.
