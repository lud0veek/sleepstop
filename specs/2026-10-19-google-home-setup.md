# Action « Éteindre les lumières » — configuration à faire de ton côté

État du code (19/10/2026) : tout est en place côté app, le vrai contrôleur Google Home est écrit mais **ne compile que quand le SDK est présent**. Sans lui, l'écran affiche « Indisponible dans cette version (SDK Google Home non inclus) ».

## 1. Télécharger le SDK Home APIs (5 min)
1. Connecte-toi sur https://developers.home.google.com avec ton compte Google (celui qui gère ta maison Google Home).
2. Page [Release notes](https://developers.home.google.com/apis/android/release-notes) → release **1.11** (ou plus récente) → lien « Android SDK: home.android.sdk_GHP_1_11 ».
3. Dézippe et copie les `.aar` (`play-services-home-*.aar`, `play-services-home-types-*.aar`, et tout autre AAR du zip) dans `android/app/libs/homeapis/`. Ils sont ignorés par git.
4. Lance `flutter build apk --debug` : la ligne `SleepStop: Home APIs SDK present` doit apparaître. Si Kotlin se plaint d'identifiants (noms exacts de `HomeDevice.id`, `moveToLevelWithOnOff`, etc.), envoie-moi la sortie : je les ajuste au SDK réel.

## 2. Projet Google Cloud + OAuth (15 min)
1. https://console.cloud.google.com → créer un projet « SleepStop » (ou réutiliser `sleepstop-eu`, le projet Firebase est aussi un projet Cloud).
2. **APIs et services → Écran de consentement OAuth** : type **Externe**, nom « SleepStop », e-mail d'assistance, **aucun scope** à ajouter, puis **Audience → Ajouter des utilisateurs test** : ton compte Google (et ceux des testeurs, max 100 tant que la Developer Console n'est pas ouverte).
3. **Identifiants → Créer → ID client OAuth → Android** :
   - nom du package : `com.sleepstop.sleep_stop`
   - empreinte SHA-1 : **trois clients ou trois empreintes** → clé debug (`keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android`), clé d'upload (`android/app/upload-keystore.jks`), et la clé de signature Play App Signing (Play Console → Configuration → Signature de l'application).
4. Rien à télécharger : la permission Google Home utilise l'identité du package + SHA-1.

## 3. Google Home Developer Console
Au 19/10/2026 la doc dit « pas encore disponible pour l'enregistrement ». Conséquence : l'action lumières fonctionne pour toi et jusqu'à 100 utilisateurs test déclarés dans l'écran de consentement ; la mise à disposition publique attendra l'ouverture de l'enregistrement. À surveiller sur la page [OAuth](https://developers.home.google.com/apis/android/oauth).

## 4. Test sur le Fold
1. Build debug installé, **Réglages → À l'endormissement → Quand je m'endors → Éteindre les lumières → Connecter Google Home** : l'écran Google de permission s'ouvre, choisis ta maison.
2. La liste pièces / appareils apparaît ; coche une pièce ou des lampes, choisis « 30 s ».
3. « Tester maintenant » : les lampes baissent puis s'éteignent, la notification « SleepStop éteint les lumières » propose **Annuler** → tout revient à l'état initial.
4. Révocation : app Google Home → Paramètres → Applications liées → SleepStop → retirer. Au retour dans l'écran, le statut doit passer à « Non connecté » et l'interrupteur se désactiver seul.
