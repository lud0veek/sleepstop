# SleepStop — Revue de publication & checklist Google Play

Revue réalisée le 18 octobre 2026 sur le commit `0890cf6` (branche `main`).
État vérifié : `flutter analyze` sans erreur, `flutter test` 6/6 OK, AAB signé avec la clé d'upload (certificat valide jusqu'en 2054).

---

## 0. État au 18/10/2026 (après corrections)

| Bloquant | État |
|---|---|
| 1.1 targetSdk 36 | ✅ Corrigé dans `build.gradle.kts` |
| 1.2 AAB 127 Mo | ✅ `keepDebugSymbols` retiré, `debugSymbolLevel = SYMBOL_TABLE` |
| 1.3 Firestore / admin | ✅ Règles verrouillées et déployées ; console admin en Google Sign-In ; fallback hors-ligne VIP supprimé. **3 actions manuelles restantes, voir 1.3.** |
| 1.4 Compte Play | ⏳ Nouveau compte personnel « vdc.dev » créé le 18/10/2026 (ancien compte fermé pour inactivité). Vérification d'identité en cours. Test fermé 12 testeurs / 14 jours obligatoire avant la production. |

## 1. Bloquants à corriger AVANT le premier upload

### 1.1 targetSdk 35 → 36 (refus d'upload probable)
Depuis le 31 août 2026, Google Play exige `targetSdk = 36` (Android 16) pour toute **nouvelle** application.
Le projet force `targetSdk = 35` dans [android/app/build.gradle.kts](android/app/build.gradle.kts:35) alors que Flutter 3.41 propose 36 par défaut.

Correction :
```kotlin
targetSdk = 36          // ou : targetSdk = flutter.targetSdkVersion
```
Vérifier ensuite l'affichage bord-à-bord (edge-to-edge est imposé en API 36) : l'app est déjà full-black, mais tester la barre de navigation sur un écran avec gesture bar.

### 1.2 AAB de 127 Mo (libflutter.so non strippé)
Le bundle contient trois `libflutter.so` de ~147 Mo chacun : la ligne `keepDebugSymbols += "**/*.so"` empêche le stripping. Un utilisateur téléchargerait ~150 Mo pour une app qui devrait faire ~25 Mo.

Correction dans `build.gradle.kts` : supprimer le bloc `packaging { jniLibs { keepDebugSymbols ... } }` et ajouter dans `buildTypes.release` :
```kotlin
ndk { debugSymbolLevel = "SYMBOL_TABLE" }
```
Play Console reçoit alors les symboles natifs séparément (plus d'avertissement "symboles de débogage manquants") et les APK livrés restent légers.

### 1.3 Sécurité Firestore + console admin : Pro gratuit pour n'importe qui
Chaîne complète, vérifiée :
1. Le dépôt GitHub `lud0veek/sleepstop` est **public** et `docs/admin.html` est hébergé publiquement. Il contient en clair `ADMIN_PIN = "2026"` et `VIP_SALT = "SLEEPSTOP_LUDO_2026_VIP"` (lignes 783-784). Le même sel est dans l'APK ([billing_service.dart:247](lib/services/billing_service.dart:247)).
2. Les règles Firestore autorisent **tout le monde** à créer, modifier et supprimer les documents `vip_codes/*` (aucune authentification). Idem : n'importe qui peut écraser `stats/global`.
3. Même si Firestore était verrouillé, le fallback hors-ligne de `verifyAndRedeemVipCode` accepte tout code dont la signature est valide (mode avion = déblocage Pro).

Conséquence : n'importe qui peut générer un code VIP valide, l'activer, ou supprimer tous tes codes et tes statistiques.

Ce qui a été fait (déployé sur `sleepstop-eu`) :
- `firestore.rules` : lectures des stats/événements et CRUD des codes VIP réservés aux admins (`/admins/{uid}` existe) ; l'app anonyme ne peut que lire **un** code par son ID et incrémenter `usesCount` de exactement +1 ; compteurs limités à une liste de clés ; `delete` interdit partout.
- `docs/admin.html` : PIN supprimé, connexion Google (Firebase Auth), chaque appel Firestore porte le jeton de l'admin. Une app web Firebase « SleepStop Admin Console » a été créée pour ça.
- `billing_service.dart` : sans réseau ou sans document Firestore actif, le code VIP est refusé.
- Vérifié en anonyme après déploiement : liste/création/suppression de codes → 403, lecture des stats → 403, écriture télémétrie sur clé autorisée → 200.

**À faire par toi dans la Firebase Console (5 min) :**
1. Authentication → Sign-in method → activer **Google**.
2. Authentication → Settings → Authorized domains → ajouter `sleepstop.eu` (pour que la connexion marche aussi sur le domaine custom).
3. Ouvrir https://sleepstop-eu.web.app/admin, cliquer « Se connecter avec Google » : la page affiche ton UID et dit « non autorisé ». Firestore → collection `admins` → créer un document dont l'ID est cet UID (contenu libre, ex. `{ "role": "owner" }`). Recharger : la console s'ouvre.

Reste optionnel : rotation du sel VIP (invalide les codes déjà distribués ; sans intérêt maintenant que Firestore est le vrai gardien), App Check (Play Integrity) pour bloquer les écritures télémétrie hors app, TTL sur `events`.

### 1.4 Accès production : compte développeur personnel ?
Si ton compte Play a été créé après novembre 2023 en tant que **personne physique**, la production est verrouillée tant qu'un **test fermé avec ≥ 12 testeurs pendant 14 jours continus** n'a pas été réalisé. Dans ce cas, « publier aujourd'hui » = lancer le test fermé aujourd'hui, production dans ~2 semaines. Un compte organisation n'a pas cette contrainte.

---

## 2. À corriger avant la production (pas bloquant pour le test interne)

État au 18/10/2026 (build 1.0.0+2) : **2.1, 2.3, 2.4 et 2.5 corrigés** (compteur d'essai persistant, localisation limitée à Android ≤ 11 avec `neverForLocation`, feuille explicative des permissions au premier démarrage, notifications/tuile/raisons d'historique traduites FR/NL/DE/ES). Restent 2.2, 2.6 à 2.10.

| # | Sujet | Fichier | Détail |
|---|-------|---------|--------|
| 2.1 | Contournement de l'essai gratuit | [dashboard_tab.dart:41](lib/ui/dashboard_tab.dart:41) | Les 5 nuits d'essai = `logs.length`. Supprimer l'historique remet l'essai à zéro. Persister un compteur `trialNightsUsed` dans `SleepSettings`, incrémenté à chaque session détectée. |
| 2.2 | « Fermeture des apps » inopérante sur Android 14+ | [MainActivity.kt:314](android/app/src/main/kotlin/com/sleepstop/sleep_stop/MainActivity.kt:314) | `killBackgroundProcesses` ne tue plus les autres apps depuis l'API 34. Le retour à l'accueil + pause MediaSession fonctionne ; reformuler la promesse marketing ("met en pause et quitte le plein écran") plutôt que "tue les processus". |
| 2.3 | Localisation Android 12+ inutile | [AndroidManifest.xml:11](android/app/src/main/AndroidManifest.xml:11), [ble_heart_rate_service.dart:243](lib/services/ble_heart_rate_service.dart:243) | Ajouter `android:maxSdkVersion="30"` sur `ACCESS_FINE/COARSE_LOCATION`, `android:usesPermissionFlags="neverForLocation"` sur `BLUETOOTH_SCAN`, et `androidUsesFineLocation: false`. Moins de permissions sensibles = moins de friction en review et à l'installation. |
| 2.4 | Permissions demandées toutes d'un coup au lancement | [home_screen.dart:36](lib/ui/home_screen.dart:36) | BLE + notifications + exemption batterie + listener dès la première ouverture. Demander au premier « Démarrer la veille » avec un écran explicatif (Google Play évalue le contexte des demandes, surtout `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`). |
| 2.5 | Textes non traduits | `sleep_session_provider.dart`, `notification_service.dart`, `foreground_task_service.dart`, `SleepStopTileService.kt` | Statuts (`Monitoring...`, `Fading audio...`), notification matin, bouton `Stop Session` en anglais ; tuile en français quelle que soit la langue. Passer par `AppStrings` et des ressources `strings.xml` localisées. |
| 2.6 | Incohérence « 100 % local / zéro cloud » | `README.md`, `docs/index.html` | La télémétrie (activée par défaut) envoie des événements horodatés à Firestore. Formuler « aucune donnée biométrique ni personnelle » plutôt que « zéro cloud ». Le formulaire Data Safety doit déclarer « Interactions avec l'app » et « Diagnostics ». |
| 2.7 | FAQ site : « service d'Accessibilité » | [docs/index.html:1321](docs/index.html:1321) | L'app n'utilise pas d'AccessibilityService (et ne doit pas en ajouter : déclaration lourde chez Google). Remplacer par « accès aux notifications / contrôle des sessions média ». |
| 2.8 | Télémétrie opt-out par défaut | [sleep_settings.dart:101](lib/models/sleep_settings.dart:101) | Anonyme, donc défendable, mais un écran de consentement au premier lancement (ou défaut désactivé) évite tout débat RGPD/ePrivacy. |
| 2.9 | Boutons de test visibles en prod | [dashboard_tab.dart:572](lib/ui/dashboard_tab.dart:572), [dashboard_tab.dart:1093](lib/ui/dashboard_tab.dart:1093) | « Simuler montre » et « Tester le fondu » : acceptables comme fonctionnalités, mais les étiqueter clairement « Mode démo » pour ne pas dérouter un testeur Google. |
| 2.10 | Historique sans limite | `session_logs_provider.dart` | Les logs (avec timeline BPM) s'accumulent dans SharedPreferences. Plafonner à ~365 entrées. |

---

## 3. Versioning (règles pro)

- **Source unique** : `version: X.Y.Z+N` dans [pubspec.yaml](pubspec.yaml:4). `X.Y.Z` = `versionName` (visible utilisateur), `N` = `versionCode` (entier, strictement croissant, jamais réutilisé, même pour un upload refusé).
- Convention : 1.0.0+1 (jamais uploadé), **1.0.0+2 = premier upload test interne**, 1.0.0+3 (correctifs test fermé), 1.0.0+4 (production). Patch = 1.0.1, nouvelles fonctionnalités = 1.1.0.
- À chaque build de release : commit, puis tag git `v1.0.0+3`, puis build. Ne jamais builder depuis un arbre non commité.
- Tenir un `CHANGELOG.md` ; les notes de version Play (500 caractères, par langue FR/NL/DE/ES/EN) en sont extraites.
- Commande de build reproductible :
```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols/1.0.0+1
```
Archiver `build/symbols/<version>` (nécessaire pour désobfusquer les stack traces Play Console).

---

## 4. Keystore et signature

- `upload-keystore.jks` et `key.properties` sont bien ignorés par git (vérifié : non trackés). Le certificat est valide jusqu'en 2054 (Google exige ≥ 2033).
- **Sauvegarde immédiate** hors machine : le `.jks` + les deux mots de passe + l'alias dans un gestionnaire de mots de passe, plus une copie chiffrée (clé USB / cloud chiffré). La perte de l'upload key se récupère via le support Google, mais c'est long.
- À l'upload : accepter **Play App Signing** (Google détient la clé de signature finale, toi la clé d'upload). Garder le `.jks` actuel comme upload key.

---

## 5. Play Console : ordre des opérations

### 5.1 Avant l'upload (aujourd'hui)
1. Corriger 1.1 et 1.2, rebuild, vérifier que l'AAB fait < 40 Mo.
2. Créer l'application : nom « SleepStop », langue par défaut Français (Belgique), app gratuite avec achats intégrés, catégorie **Santé et remise en forme**.
3. **Configuration > Accès à l'application** : indiquer que l'essai couvre 5 nuits et fournir un **code VIP** aux réviseurs Google pour tester Pro sans payer.
4. **Monétisation > Produits intégrés** : créer `sleepstop_lifetime_pro`, non consommable, 9,99 € (vérifier le prix par pays, TVA incluse). Le produit doit être **actif** sinon `queryProductDetails` renvoie vide.
5. **Monétisation > Programme de test de licence** : ajouter ton compte Google et ceux des testeurs pour acheter sans débit réel.

### 5.2 Fiche Play Store (contenu principal)
- Icône 512×512 ✅ (`store_assets/icon_512x512.png`), bannière 1024×500 ✅ (versions FR/NL/DE/ES/EN).
- **Screenshots : manquants.** Minimum 2 téléphone (recommandé 4 à 8, 1080×1920 ou plus, format 16:9 à 9:16). Tablette 7" et 10" recommandées (sinon l'app est marquée « non optimisée tablette »). Captures à faire : dashboard idle, session montre en cours (BPM live), fondu phone mode, historique avec sparkline, sélecteur d'apps, écran Pro.
- Titre (30), description courte (80), description longue (4000) : à fournir en FR, NL, DE, ES, EN. Réutiliser les slogans des bannières.
- URL de politique de confidentialité : `https://sleepstop.eu/privacy` (tant que le DNS propage, utiliser `https://sleepstop-eu.web.app/privacy`, puis mettre à jour).
- E-mail de contact développeur visible publiquement : prévoir une adresse dédiée (ex. support@sleepstop.eu) plutôt que le Gmail personnel.

### 5.3 Contenu de l'application (déclarations obligatoires)
| Déclaration | Réponse attendue pour SleepStop |
|---|---|
| Politique de confidentialité | URL ci-dessus |
| Annonces | Non |
| Accès à l'application | Instructions + code VIP |
| Classification du contenu (IARC) | Questionnaire « Utilitaire / Santé » → Tout public |
| Public cible | 18 ans et plus (ou 13+) ; **pas** d'enfants |
| Actualités | Non |
| Application de suivi des contacts COVID | Non |
| **Sécurité des données** | Collecte : « Interactions avec l'app » et « Diagnostics » (anonymes, non partagées, chiffrées en transit, opt-out dans l'app, pas de suppression sur demande car non identifiables). **Aucune donnée de santé collectée** (traitée sur l'appareil uniquement). |
| Fonctionnalités gouvernementales / financières | Non |
| **Applications de santé** | Oui : fonctionnalité « Suivi du sommeil » / « Fréquence cardiaque » traitée localement. Obligatoire depuis 2024 pour toute app lisant des données de santé. |
| **Autorisations de service de premier plan** | Déclarer `connectedDevice` (lecture BLE continue) et `specialUse` (surveillance mouvement + fondu audio écran éteint). Une **vidéo de démonstration** (lien YouTube non répertorié) montrant la notification persistante est exigée. |
| Autorisations sensibles | `BIND_NOTIFICATION_LISTENER_SERVICE` : justifier « détection de la session média active pour la mettre en pause ». Après 2.3, plus de déclaration Localisation nécessaire. |

### 5.4 Pistes de test
1. **Test interne** (aujourd'hui) : jusqu'à 100 testeurs par e-mail, disponible en quelques minutes. Vérifie l'achat réel avec un compte de test de licence, la restauration, le code VIP, une vraie nuit en mode montre et une en mode téléphone.
2. **Test fermé** : obligatoire 14 jours / 12 testeurs si compte personnel récent (voir 1.4). Sinon, 3 à 5 jours avec quelques proches suffisent.
3. **Production** : première soumission → review manuelle (quelques heures à 7 jours, souvent plus long pour les apps santé + foreground service + notification listener). Déployer à 100 % ensuite, pas besoin de rollout progressif pour une v1.

---

## 6. Ce qui est bon et n'a pas besoin de changer
- Architecture Riverpod claire, services isolés, parseur BLE 0x2A37 testé (UINT8/UINT16/R-R).
- Manifest conforme : pas de `QUERY_ALL_PACKAGES`, `<queries>` ciblées, `BLUETOOTH_*` legacy limitées à l'API 30, services non exportés sauf ceux qui doivent l'être.
- Billing : `in_app_purchase_android 0.5.0` → Play Billing Library 8.0 (exigence 2026 respectée), `completePurchase` appelé, restauration gérée, fallback debug limité à `kDebugMode`.
- 16 KB page size : Flutter 3.41 et aucun plugin avec code natif propre → OK.
- Secrets de signature hors git, `.gitignore` correct.
