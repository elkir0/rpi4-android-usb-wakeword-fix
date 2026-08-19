# Provenance du correctif Pi 4 test1

## Sources

| Élément | Valeur |
|---|---|
| Tag AOSP | `android-16.0.0_r4` |
| Manifeste Raspberry Vanilla | branche `android-16.0` |
| Commit `device/brcm/rpi4` | `99ff5b226fdc9aef7cbec72736a58b959ba58619` |
| Patch publié | `26e189da2c32ebe205c4970c5bfe1fa1dd0131d26a14c566d3266a78936858a6` |
| `StreamAlsa.cpp` corrigé | `299151c6482d0324a0b68fd5799923881f0869a32e54ff782f4016bfbecf7156` |
| Diff appliqué | `94222adcd9c3bac5f8b048156b1d37fb6746c8d104d7dd07b3ed18ddc07c6267` |
| Manifeste résolu final | `519803f94a8886b735efdf23e4598502aee1e11f89af099039df983b7e98aee6` |

Les fichiers de preuve et les journaux de compilation sont conservés dans
l'environnement de développement d'origine. Ils ne sont pas recopiés ici afin
de ne pas publier plus d'un mégaoctet de logs bruts.

## Construction

- hôte : VM Ubuntu 22.04 x86_64 dédiée sur Proxmox ;
- 6 vCPU, 12 Gio de RAM et swap temporaire pendant Soong ;
- cible `aosp_rpi4-bp4a-userdebug` ;
- module `com.android.hardware.audio.rpi` ;
- résultat `9044/9044` ;
- durée `01:54:09` ;
- verification APEX hôte réussie.

## Artefact

| Propriété | Valeur |
|---|---|
| Taille | `16101376` octets |
| SHA-256 | `a8c735ede091b92770cb74162baaa826c69708a26d7fce0d59d62b082d989ccc` |

L'APEX contient notamment `android.hardware.audio.service.rpi`, le service
d'effets audio, ses manifestes `rc`/VINTF et `libalsautilsv2-rpi.so`. La clé
publique APEX et le certificat ont été comparés à ceux de l'APEX stock de la
build testée.

## Validation matérielle

Après installation sur le Pi 4 réel :

- AudioFlinger a ouvert une entrée USB mono à 48 kHz ;
- la reconnaissance Google a renvoyé `test microphone bonjour` ;
- l'enrôlement Voice Match a reçu plus de 600 000 frames réelles ;
- aucune erreur `openProxyForExternalDevice ... -22` ni insertion de silence
  n'a été observée sur le chemin corrigé.

Le déclenchement final « Hey Google » après reboot n'était pas encore consigné
au moment de publier test1 ; cette limite est répétée dans les notes de release.
