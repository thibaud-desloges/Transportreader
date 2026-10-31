# ZOU! — lecteur régional et scan approfondi

Le globe de l’écran Scan ouvre le lecteur régional. Le parcours Navigo, ses
parseurs, ses références et son historique sont conservés.

## Périmètre du scan approfondi (rapport v4)

- Applications : AID initial choisi par iOS, puis A0000004040125092001 (identifiant relevé dans le fichier 2000/2004), 1TIC.ICA et 3MTR.ICA, sans doublon.
- Pour chaque application sélectionnable : les 30 SFI valides (01 à 1E), puis
  48 chemins Calypso connus. Le plan de base comprend donc 78 emplacements par application. GET DATA EF LIST (00 CA 00 C0) est aussi demandé dans le contexte de l’application et dans les dossiers 2000, 2100, 3100, 1000 et 8000 sélectionnables. Les fichiers supplémentaires déclarés par la carte sont ajoutés au parcours et au curseur de reprise.
- Les fichiers à enregistrements sont lus jusqu’au refus ou à 254 enregistrements.
- Une réponse de structure incompatible au premier READ RECORD déclenche un essai
  READ BINARY. Les fichiers binaires sont lus par blocs jusqu’au refus, fin de
  fichier ou plafond de 32 Kio. Les plafonds atteints sont notés dans le rapport.
- Les refus sont conservés, ainsi que les réponses brutes et leur application.
  Le lecteur corrige une longueur demandée par 6Cxx et suit les chaînes 61xx
  par GET RESPONSE (16 réponses supplémentaires maximum par commande).
- Aucune commande d’écriture, de rechargement, de PIN ou d’authentification.

Ce n’est pas une copie complète garantie de la puce : les fichiers protégés,
les AID inconnus, les chemins propriétaires inconnus et les limites iOS peuvent
laisser des données hors de portée. Une fin de parcours signifie seulement
que le plan a été exécuté. Les autres technologies que ISO 7816 ne sont pas
encore prises en charge par ce lecteur.

## Reprise et sauvegarde

Le lecteur fait une pause après environ 40 secondes d’échanges pour éviter
l’expiration normale de session. Le curseur mémorise application, fichier,
enregistrement ou position binaire. Une interruption pendant une commande
laisse cette commande à relire, sans perdre les réponses précédentes.

Le bouton Reprendre relance une session et exige le même identifiant NFC de
carte. Une carte à identifiant aléatoire peut nécessiter une nouvelle lecture.
Ce contrôle évite de fusionner accidentellement les captures de deux cartes.
Le dernier rapport et son curseur sont sauvegardés localement dans Documents/
regional-deep-scan.json, avec protection complète du fichier. Aucune transmission
automatique. Une nouvelle lecture remplace ce rapport. Le partage reste explicite.

## Ce qui est décodé

Le préfixe date/heure Intercode des événements SFI 08 de l’application
3MTR.ICA testée est interprété, ainsi que les périodes de validité des contrats
au format commun 20 ou 03 référencés par la liste des contrats. Les deux horodatages d’octobre du premier rapport ont été confirmés par le porteur. Pour septembre, la carte encode le 10 dans deux champs, alors que le porteur confirme un trajet le 13 à la même heure. Cet écart reste inexpliqué ; aucune correction silencieuse de date n’est appliquée. Les noms de stations, lignes et intitulés commerciaux des titres ne sont pas
encore décodés ; le choix ZOU! reste déclaratif, pas une reconnaissance automatique.
Aucun intitulé d’abonnement n’est inventé. Deux correspondances expérimentales de gares sont calibrées à partir des trajets d’octobre confirmés par le porteur ; elles sont limitées au réseau 250920, au prestataire 2 et au mode 5, sans transformation prétendue depuis les codes UIC.

Les erreurs de fichiers absents ne signifient pas que le pass est absent de la
carte : elles concernent les emplacements essayés. Les octets bruts et les
refus restent dans le rapport pour permettre une interprétation ultérieure.

## Vérification

Depuis le dépôt de l’app :

```sh
swiftc metroreader/RegionalEventHeader.swift Tests/RegionalEventHeader/main.swift -o /tmp/transportreader-event-tests
/tmp/transportreader-event-tests
swiftc metroreader/RegionalScanPlan.swift Tests/RegionalScanPlan/main.swift -o /tmp/transportreader-plan-tests
/tmp/transportreader-plan-tests
```

Les tests vérifient les dates, les valeurs invalides, les transitions d’heure,
la couverture et l’unicité du plan, et la sérialisation/reprise d’un curseur.
La compilation iPhone est vérifiée séparément. La collecte approfondie elle-même
reste à tester avec une carte physique ; le simulateur ne simule pas le NFC.

## Sources

- Cartes ZOU! : https://zou.maregionsud.fr/quelle-carte-zou-souhaitez-vous
- Calypso / Keyple : https://keyple.org/learn/user-guide/calypso-application/
- Emplacements Calypso utilisés comme références (pas un schéma ZOU! confirmé) :
  https://github.com/metrodroid/metrodroid/blob/master/src/commonMain/kotlin/au/id/micolous/metrodroid/card/calypso/CalypsoApplication.kt

Aucun code d’un autre projet n’a été copié. Le rapport personnel complet n’est
pas ajouté au dépôt.

## Contrats : analyse du scan approfondi

Le premier fichier de contrats (SFI 09, chemin 2000/2020) contient quatre
emplacements sans titre interprétable. Le second (SFI 06, chemin 2000/2030)
contient deux enregistrements non vides. La liste SFI 1E / 2000/2050 les désigne
par les pointeurs 5 et 6, avec structures 20 et 03. Le décodage du format commun
retrouve dans les deux enregistrements la période annuelle confirmée par le porteur.
Cela ne suffit pas à établir deux abonnements distincts ou les noms commerciaux.

Le nouveau décodeur utilise les références de la carte pour choisir le format,
contrôle les limites de lecture et les dates, fusionne les lectures identiques
par SFI et par chemin, et refuse de deviner si des copies diffèrent. Il n'utilise
ni les tarifs, ni les fournisseurs, ni les stations de la base Navigo.

Les références structurelles consultées :
https://github.com/metrodroid/metrodroid/blob/master/src/commonMain/kotlin/au/id/micolous/metrodroid/transit/intercode/IntercodeSubscription.kt
https://github.com/metrodroid/metrodroid/blob/master/src/commonMain/kotlin/au/id/micolous/metrodroid/transit/en1545/Calypso1545TransitData.kt

Tests supplémentaires (données synthétiques ; le rapport privé reste hors dépôt) :

```sh
swiftc metroreader/RegionalScanPlan.swift metroreader/RegionalCardCapture.swift metroreader/RegionalTicketingRecords.swift metroreader/RegionalContract.swift Tests/RegionalContract/main.swift -o /tmp/transportreader-contract-tests
/tmp/transportreader-contract-tests
```

On peut passer le chemin d'un rapport privé au binaire pour rejouer localement
le rapport étudié. Les tests couvrent les deux variantes de structure, les
pointeurs de contrats, les dates inversées, les données tronquées, les formats
incompatibles et les alias de fichier avec ou sans divergence.

## Étape suivante : événements, rôles des titres et recherche du bus

- Les trois événements SFI 08 décodés ont le code 51 : mode 5 (train),
  transition 1 (entrée), prestataire 2, pointeur de contrat 5.
- Deux codes de lieu distincts : 16008 et 13143. Les confirmations des trajets
  d’octobre permettent un premier rapprochement expérimental avec Les Arcs–Draguignan
  et Toulon. Ce rapprochement est affiché comme tel ; aucun référentiel public
  exhaustif ne reliant ces identifiants billettiques aux UIC n’a été trouvé.
- Le champ numéro de ligne est absent de ces événements : aucune ligne n’est
  inventée depuis les gares ou depuis le souvenir du voyageur.
- Le contrat 5, format 20, comporte une classe 2, un montant brut de 9000
  (interprétation 90 euros), et des données de vente. Le contrat 6, format 03,
  est différent ; son rôle routier est une hypothèse à vérifier.
- Les emplacements 5 et 6 proviennent de la liste des titres de la carte, après
  quatre emplacements dans la première banque. Ils ne sont pas des numéros
  d’abonnement. Le libellé principal devient « Titre utilisé pour le train »
  pour le titre référencé par les événements ferroviaires ; le numéro technique
  reste consultable dans les détails.

La version 4 du scan ajoute la sélection explicite de l’AID relevé dans le rapport
et l’exploration des listes de fichiers optionnelles. Une liste refusée ne bloque
pas le plan de base. L’ancien rapport reste décodable ; une nouvelle lecture est
nécessaire pour tester l’AID et les répertoires supplémentaires.

Référence primaire du format GET DATA EF LIST :
https://github.com/eclipse-keyple/keyple-card-calypso-java-lib/blob/main/src/main/java/org/eclipse/keyple/card/calypso/CommandGetDataEfList.java

Tests :

```sh
swiftc metroreader/RegionalScanPlan.swift metroreader/RegionalCardCapture.swift metroreader/RegionalTicketingRecords.swift metroreader/RegionalContract.swift metroreader/RegionalEventHeader.swift metroreader/RegionalEvent.swift metroreader/RegionalFileDirectory.swift Tests/RegionalEvent/main.swift -o /tmp/transportreader-full-event-tests
/tmp/transportreader-full-event-tests
```

Le test accepte un chemin de rapport privé pour vérifier les champs réels.
Il couvre aussi un événement synthétique de bus avec ligne 59, le rejet des
troncatures, le parsing des répertoires et la reprise avec fichiers découverts.

## Rapport v4 : répertoires effectivement lus et identifiants de borne

L’AID A0000004040125092001 sélectionne le dossier billettique 2000 ; 3MTR.ICA
sélectionne le MF de la même carte. Les lectures absolues des mêmes fichiers
renvoient les mêmes octets. Ce sont des chemins d’accès au même contenu, pas la
preuve de deux journaux indépendants de bus et de train.

La carte déclare quatre fichiers au MF, onze dans 2000, huit dans 2100 et deux
dans 1000. Les répertoires 3100 et 8000 testés ne sont pas sélectionnables.
Les huit fichiers 2100 ont été lus, y compris 4096 octets binaires dans 2112.
Les fichiers 2118, 211A, 211B, 211C et 2113 sont remplis de zéros ; 2115
contient seize copies d’un même motif (1013, FF à l’octet 10, reste à zéro),
qui ne permettent pas d’identifier deux voyages. Le fichier 2114 contient
un enregistrement de 32 octets qui n’est pas entièrement nul et dont la sémantique n’est pas établie. Il reste une piste de
recherche, pas un événement de bus identifié. Le rapport n’a atteint aucun
plafond de fichier.

Dans les événements de train, le bitmap A000114 ne déclare ni EventDevice
(bit 10), ni EventLocationGate (bit 9), ni EventEmployee (bit 17). Après les
120 bits interprétés, les 112 bits restants sont tous nuls. Le rapport ne
permet donc pas de distinguer les appareils physiques de validation ni de
prouver qu’une borne était mal réglée. La date encodée reste distincte de la
date réelle confirmée par le voyageur.

Le décodage regroupe maintenant les lectures SFI et les chemins absolus ou
relatifs de l’AID billettique. Cela corrige le cas où les données étaient
bien collectées par chemin mais n’apparaissaient pas dans l’écran des événements.
Les copies divergentes sont rejetées plutôt que fusionnées arbitrairement.

Le prix affiché dans le titre est son prix d’achat unique pour sa période de
validité. Le porteur confirme qu’il s’agit de l’abonnement annuel à 90 euros ;
aucun prix de trajet n’est inféré des événements.

## Comparaison avant / après une validation réelle

Au lancement d’une nouvelle lecture, le rapport précédent est sauvegardé dans
Documents/regional-previous-scan.json. Il est partagé séparément et comparé au
rapport courant si les identifiants de carte coïncident. Seules les lectures
par chemins absolus sont comparées ; ajout, modification et absence de relecture
sont distingués. Les alias identiques sont dédoublonnés. Une copie divergente
reste incertaine et n’est pas annoncée comme une modification de trajet.

Le prochain test informatif est une lecture avant et après une validation réelle
dans le car 59, au même niveau d’exploration. Le rapport v4 actuel sert de repère
historique, mais n’équivaut pas à un scan immédiatement avant ce prochain trajet.
Un nouveau scan sans modification de carte ne résout pas à lui seul la sémantique
des fichiers propriétaires.

```sh
swiftc metroreader/RegionalScanPlan.swift metroreader/RegionalCardCapture.swift metroreader/RegionalCaptureDifference.swift Tests/RegionalCaptureDifference/main.swift -o /tmp/transportreader-diff-tests
/tmp/transportreader-diff-tests
```

Le rapport privé courant est également copié localement dans captures-locales/
à la racine de l’espace de travail, exclu de Git. Lorsqu’un iPhone est connecté,
le rapport peut être récupéré directement dans le conteneur de TransportReader
avec devicectl ; l’export manuel reste possible.

## Version 5 : recherche étendue de dossiers et écran régional

Le lecteur n'attend pas un nouveau trajet pour poursuivre la recherche. Pour
l'application racine 3MTR.ICA, il teste maintenant les adresses de dossiers xx00
pour xx=01..FF, en commençant par les cinq dossiers connus. Le contexte initial
est aussi interrogé : 256 contextes au total. Pour les autres AID, les six
contextes connus sont conservés afin de ne pas répéter la recherche racine.

Chaque dossier sélectionnable est interrogé par GET DATA EF LIST ; les chemins
retournés sont ajoutés au plan et lus. Le curseur sauvegarde aussi l'index du
prochain dossier à tester. Une expiration ne force donc pas à recommencer les
255 essais. La recherche reste bornée : les adresses qui ne finissent pas par
00 ne sont pas toutes énumérées, et les restrictions de lecture sont conservées.
Aucune commande d'écriture ni essai de clé n'est ajouté.

L'écran ZOU! est maintenant organisé autour d'une carte, des titres et des
passages, avec filtres Tous / Train / Bus-car. Les octets et la comparaison des
rapports sont dans une feuille Diagnostic. Les dates restent affichées comme
« encodées » et le prix reste celui de l'achat du titre. Le parcours Navigo
ne dépend pas de cette nouvelle interface.

Un outil hors ligne reproductible est ajouté :

```sh
python3 tools/analyse_capture.py /chemin/rapport.json --date 2026-09-14 --date 2026-09-15
```

Il produit un inventaire des lectures absolues, distingue emplacements lus et
contenus distincts, cherche les motifs de dates Intercode et inspecte les bits
de présence des identifiants de borne. Les résultats sont des observations
binaires, pas une attribution automatique de trajets. L'analyse du rapport v4
est sauvegardée dans captures-locales/analyse-zou-v4.md, hors Git.

## Correctif de reprise NFC

La reprise ne doit pas dépendre de la libération différée d'une ancienne session
CoreNFC. L'ancien garde-fou `session == nil` pouvait ignorer une demande sans
message. Une fin de lecture libère désormais explicitement la référence de
session. La reprise crée une session neuve après une courte transition.

Un identifiant de génération distingue chaque exécution : une réponse APDU
arrivée après l'annulation n'est pas ajoutée au nouveau rapport et un ancien
rappel de fermeture ne termine pas une lecture suivante. Le curseur et les
octets déjà reçus restent sauvegardés. Les messages d'interruption gardent
maintenant l'erreur CoreNFC, utile pour diagnostiquer une nouvelle interruption.

```sh
swiftc metroreader/RegionalSessionLease.swift Tests/RegionalSessionLease/main.swift -o /tmp/transportreader-session-tests
/tmp/transportreader-session-tests
```

Le premier rapport v5 partiel confirme que l'exploration xx00 a découvert 2200
et 2300, en plus des dossiers déjà connus. Le dossier 3F00 est un autre accès
au MF. Les fichiers déclarés par 2200 et 2300 ont été lus ou ont laissé un
refus explicite ; leur interprétation reste à établir. Le rapport interrompu
est conservé dans captures-locales/zou-reprise-bloquee.json, hors Git.

### Correction du décodage après recherche étendue (19 octobre)
Le rapport local terminé contient 1427 échanges et confirme le rejet 6A82 de 1TIC.ICA. Les SFI lus sous 3MTR ne correspondent pas tous aux fichiers de DF2000 : ils ne doivent pas être fusionnés avec les chemins explicites de billetterie. Le décodeur privilégie désormais les chemins absolus et relatifs au bon AID ; les SFI restent un repli pour les anciens rapports. Les conflits entre chemins explicites restent bloquants. Rejeu réussi du rapport terminé : deux titres 5/6 et trois événements ferroviaires. Test de régression ajouté, compilation iPhone réussie et installation effectuée. L'indication NFC est mise à jour avant chaque tentative d'AID, y compris les identifiants absents. Aucun événement bus identifié dans ce rapport ; absence de motifs de dates Intercode pour les 14/15 septembre non concluante pour d'autres formats.

### Recherche complémentaire v6
Un bouton « Recherche complémentaire · applications et dossiers » conserve le rapport terminé et prépare un curseur reprenable, lié au même UID. Il demande GET DATA D0 (applications liées), 4F (AID courant), et CB 2F00 / 5C00 (répertoire ISO optionnel) dans les contextes accessibles. Un lecteur BER-TLV borné extrait seulement les objets AID 4F/84 des conteneurs connus/structurés ; les nouveaux AID annoncés sont ajoutés au parcours (maximum 16). Le fichier ISO 2F00 est également essayé par READ RECORD.
La recherche vérifie les SFI 1 à 30 à la racine de chaque application puis sous 2000, 2100, 2200, 2300 et 1000. Chaque changement de SFI contextualisé resélectionne explicitement l'application et le dossier ; les libellés du rapport incluent le dossier pour éviter toute fusion erronée. Les listes EF servent toujours à ajouter des chemins explicites. Il s'agit de nouvelles lectures publiques, pas d'authentification ni d'écriture. Les refus restent dans le rapport. Tests : TLV malformés, doublons, données primitives non interprétées comme des AID, parcours de 181 positions de base, reprise et compatibilité des anciens curseurs.
Les zones 2114/2314 contiennent les mêmes octets ; 2115/2315 contiennent chacune seize exemplaires identiques d'un modèle. Ce constat ne suffit pas à leur attribuer une fonction commerciale ou un historique de bus. Le format supplémentaire du second contrat (structure 03 après le tronc commun) reste non confirmé.

### Correction des autorisations NFC après découverte d'AID
Le rapport complémentaire (4081 échanges) s'arrête au curseur application=2 sur six avec « Missing required entitlement ». Les métadonnées 4F/D0 ont réellement révélé A0000004040225092001 (DF1000), A0000004044125092001 (DF2300), A000000291A00000019102 (DF2100), A000000291D25008009301 (DF2200). Ces quatre AID sont ajoutés à la liste ISO7816 de l'Info.plist. La reprise conserve son curseur exact, sans redémarrer les applications déjà lues.
Avant toute sélection par AID, le lecteur vérifie désormais la liste réellement embarquée dans Bundle.main. Un identifiant futur non déclaré est conservé dans undeclaredApplications et ignoré sans envoyer de SELECT interdit à CoreNFC ; il apparaît dans le diagnostic et le bilan indique la limite au lieu de prétendre que tout a été testé. Test de régression rejouant le rapport bloqué : les six AID sont autorisés, le curseur est conservé, aucune autorisation par simple préfixe. Le bouton de reprise a une zone de toucher élargie et un état d'ouverture immédiat ; réouverture NFC après 0,8 s et message d'attente de carte seulement après activation de la session. La fiabilité du toucher et de la reprise physique reste à vérifier avec le porteur.

### Bilan du rapport complémentaire terminé et lecture courante
Le rapport local terminé contient 9554 échanges, six AID traités et aucune limite de lecture atteinte. L'outil tools/audit_capture.py rapproche les descripteurs C0/C1 et les chemins explicites absolus/relatifs : 49/51 fichiers entièrement lus, 18858/18935 octets annoncés. Les deux refus sont MF/0003 (29 octets) et 2300/2302 (48 octets). Aucun contenu de lecture non nul supplémentaire par rapport au rapport v5 terminé. Le journal volumineux contient surtout des répétitions et des réponses nulles ; il ne mesure pas la mémoire physique de la carte. Les bus restent non identifiés ; aucune nouvelle lecture identique n'est demandée.
Le bouton de lecture courant utilise un curseur quick et cinq chemins absolus : 2000/2001, 2010, 2020, 2030, 2050 sur A0000004040125092001, sans découverte de dossiers/AID. Les recherches de diagnostic restent proposées séparément. Tests du parcours rapide et de sa sérialisation réussis ; rejeu du rapport final pour titres et événements réussi.

### Recherche bus sans dates et conditions PIN
Le décodage indépendant des réponses SELECT FILE (85/17, champs aux offsets Calypso) confirme readAccess=01 pour MF/0003 et 2300/2302 : accès PIN, pas preuve de chiffrement du contenu. Le porteur indique n'avoir jamais reçu de PIN. Les huit paires 211x/231x ont les mêmes références partagées non nulles : ce sont des données réellement partagées, pas des historiques distincts simplement similaires. Modèle RegionalFileHeader ajouté, testé sur les 51 en-têtes et exposé au diagnostic.
La recherche tools/hunt_intercode_events.py --any-date teste les structures à tous les décalages de bits des réponses et des fichiers binaires assemblés. Les codes bus isolés obtenus par décalage ne prouvent rien. Avec --bus-signals (mode bus/car et ligne 59, pointeur 6, ou fournisseur 29), aucun candidat n'est trouvé. Les recherches de dates alternatives comportent des faux positifs dans le tarif et les données binaires ; aucun événement supplémentaire confirmé.
Le fichier 2200/2203 de 500 octets présente, factuellement, un en-tête de 13 octets, un nombre 35 au dernier octet, puis 35 entrées de 8 octets dont les index valent 1 à 35 et dont les deux octets suivants valent toujours 0101 ; suivent 64 octets puis du remplissage nul. Sa fonction commerciale/cryptographique exacte n'est pas confirmée ; ce n'est pas présenté comme 35 voyages.

Un diagnostic PIN dédié conserve les échanges actuels, vérifie le même UID et ne parcourt que MF/0003 et 2300/2302. Il utilise la commande Calypso de consultation du compteur : INS20 P1/P2=00, aucune donnée de PIN, Le00. Classe94 pour l'application MF observée de type13/PrimeRev2, classe00 pour l'application 2300 observée de type23/Rev3. Aucun code PIN saisi, deviné, modifié ou réinitialisé. Les statuts 9000/63C2/63C1/6983 donnent respectivement 3/2/1/0 essais selon l'implémentation de référence ; 6D00 indique une fonction non prise en charge. Cette consultation ne constitue pas une ouverture d'accès. Les lectures publiques protégées sont retentées ensuite une fois, sans authentification. Tests : données de commande vides, classes, interprétation des statuts, curseur ciblé et reprise.
Sources primaires consultées :
- https://keyple-support.calypsonet.org/add-ons/tool/card-audit/ (modes d'accès)
- https://github.com/eclipse-keyple/keyple-card-calypso-java-lib/blob/main/src/main/java/org/eclipse/keyple/card/calypso/CommandSelectFile.java (positions des champs)
- https://github.com/eclipse-keypop/keypop-calypso-card-java-api/blob/main/src/main/java/org/eclipse/keypop/calypso/card/card/FileHeader.java (référence de données partagées)
- https://github.com/eclipse-keyple/keyple-card-calypso-java-lib/blob/main/src/main/java/org/eclipse/keyple/card/calypso/CommandVerifyPin.java (mode compteur sans PIN)
- https://github.com/eclipse-keyple/keyple-card-calypso-java-lib/blob/main/src/main/java/org/eclipse/keyple/card/calypso/CalypsoCardAdapter.java (classe94 Rev2, fonctionnalité PIN)
Aucun code de ces implémentations n'a été copié ; les modèles Swift utilisent les champs et commandes documentés.

### Résultat réel du diagnostic PIN
Le rapport local zou-diagnostic-pin.json termine les deux applications ciblées. Les consultations sans données de PIN répondent 9000 pour MF/3MTR (classe94) et pour 2300 (classe00), soit trois essais disponibles selon le mode compteur Calypso. Les READ RECORD suivants répondent toujours 6982 pour 0003 et 23002302, avec réponse vide. La consultation n'a donc pas authentifié ni ouvert l'accès. Aucun PIN n'a été présenté. Aucun contenu de fichier non nul supplémentaire par rapport au rapport complémentaire terminé précédent ; les contenus précédents sont tous présents. Aucune nouvelle validation de bus identifiée.

### Décodage enrichi du support et des contrats
RegionalEnvironment décode strictement le variant réellement observé de 2000/2001 : Intercode 2.1, réseau 250920, émetteur 12, échéance d'application au 31/08/2036, naissance BCD, personnalisation nominative (2), code commercial 1. Les bitmaps non pris en charge sont rejetés plutôt que décaler les champs. Aucun profil étudiant n'est nommé à partir du seul code 1. Test synthétique sans données personnelles et rejeu du rapport privé.
RegionalContract conserve désormais statut, priorité de la liste, série, masque de zones, appareil/agent/date de vente, code de paiement, référence liée éventuelle et présence de bits non interprétés. Contrat5 : statut1, priorité8, série8635, classe2, date de vente 08/07/2026, appareil67, agent12, paiement189, zones3F00. Contrat6 : statut13, priorité12, fournisseur29, tarif12200, structure03, validité annuelle commune ; les données complémentaires après le bit69 restent non interprétées. On ne force pas le format20 sur ce format03.
Une source primaire additionnelle publiée par APAM, le modèle de données BELL citant EN1545/Intercode (pages24 et45), donne le statut13 comme « non validable », pouvant correspondre à des droits tarifaires ou à des titres conservant une valeur résiduelle. Il s'agit d'un indice documenté, pas d'un dictionnaire ZOU ni d'une preuve que le contrat6 est le droit étudiant. L'app conserve ce droit et indique la réserve au lieu de le masquer ou le présenter comme un abonnement bus actif. Le rôle commercial exact demeure inconnu.
Source : https://www.apam.it/uploads/bandi/1467376217_A11_Draft_Card_Data_Model_BELL.pdf

RegionalEvent conserve les champs complémentaires reconnus, dont première validation, code résultat, véhicule, course, montant/unité et indicateurs complémentaires. Sur les trois événements réels, la première validation répète le même jour et la même heure que l'en-tête ; les 112 bits restants de chaque enregistrement sont tous nuls. Test réel ajouté. Cela exclut des données non nulles cachées dans la fin de ces trois enregistrements, pas un autre fichier/format.
UI : section Support et profil, détails enrichis des titres/droits et événements, inventaire des en-têtes avec tailles, modes d'accès et références partagées. Le bouton de diagnostic PIN reste présent après une lecture rapide sans dépendre d'avoir lu les fichiers protégés. Les originaux Navigo ne sont pas modifiés par ces décodeurs régionaux.
Aucune procédure publique spécifique ZOU de récupération d'un PIN de carte n'a été identifiée dans les recherches effectuées. Aucun code PIN n'a été essayé.

Hypothèse supplémentaire sur l'extension03, conservée hors du décodeur métier : les deux blocs de 16 bits après le tronc commun (positions69 et85) valent 8582 et13143 ; les 14 bits à101 correspondent au 08/07/2026 et les16 bits à115 valent67, comme la date et l'appareil de vente du contrat5. La correspondance avec le lieu13143/Toulon est une piste de droit lié à un trajet déclaré. Ces positions ne constituent pas un schéma confirmé ; elles ne sont donc pas nommées origine/destination/vente dans l'interface. tools/analyse_second_contract.py produit ce relevé d'hypothèses sans recherche réseau ni écriture sur carte. La fin du bloc vaut40 mais son rôle est inconnu.

Le porteur a confirmé avoir déclaré Marseille–Saint-Charles → Toulon comme trajet préférentiel, sur TER Marseille–Toulon–Nice ZOU!/Transdev. Une concordance expérimentale distincte du décodeur de contrats est exposée par RegionalPreferredJourneyHint : elle requiert le réseau250920, le contrat6 structure03/statut13/fournisseur29/tarif12200, les motifs8582/13143 aux positions69/85 et les concordances date/appareil de vente avec le contrat5. L'UI distingue le trajet et la ligne déclarés par le porteur des champs réellement décodés. 8582=Marseille n'est pas ajouté au référentiel des validations comme correspondance prouvée par un passage. Le code fournisseur29 n'est pas traduit arbitrairement en Transdev. La valeur40 en fin de contrat n'est pas appelée numéro de ligne. Le type03 pourrait être un droit tarifaire lié au trajet habituel : piste renforcée, fonction exacte non confirmée. Test du garde réseau, du droit et des concordances réussi.
Les champs justificatif de vente et mode autorisé du format20 sont aussi conservés ; sur le titre5 ils valent respectivement faux et0 (mode non précisé).

### Contexte d'encodage à distance et nouvelle piste ABT/CBT
Le porteur précise que la carte neuve a été reçue déjà encodée en juillet2026, après achat à distance. Le code d'équipement de vente67 n'est donc pas décrit comme une borne utilisée par le voyageur. L'UI clarifie ce champ et le fournisseur du contrat, sans assimiler29 à Transdev.
Source primaire nouvelle : Matawan explique explicitement la production d'une billettique hybride ABT/CBT en Région Sud (https://matawan-mobility.com/blog/interoperabilite-ou-en-est-on-ou-allons-nous/, 18/02/2025). Cela rend plausible la présence de droits/traces ferroviaires sur carte avec d'autres informations dans un compte ; ce n'est pas une preuve du stockage précis des validations de la ligne59. L'UI présente cette limite sous le filtre Bus/car et propose le lien source. Le trajet de référence peut être routier ou ferroviaire ; les CGV officielles décrivent son rôle (https://mmt.vsct.fr/sites/default/files/swt/CPAC/2026-05/CGV%20train%20zou.pdf), mais ne donnent pas le schéma des bits03.
La recherche de motifs est étendue à l'horloge invalide, aux pointeurs5et6 et à tous les codes/modes/transitions dans un second parcours. Aucun événement bus cohérent confirmé ; les concordances isolées hors des trois événements connus se trouvent dans les sous-chaînes de2200/2203. Le rapport privé piste-bus-hybride-et-reference.md documente cette recherche et distingue faits, hypothèses et éléments non vérifiés. Aucune capture privée n'a été envoyée à un service extérieur.

### Inventaire direct FIRST_EF / NEXT_EF

Ajout d’une lecture ciblée conservant la capture : inventaire séquentiel des EF des six applications connues (CLA94 pour les deux Rev2, CLA00 pour les autres), selon les commandes documentées par Keypop/Keyple. Reprise par rejeu des sélections déjà enregistrées, vérification de leur ordre, arrêt sur répétition, borne de 128 fichiers par application, refus/format inconnu consignés comme limites. Les adresses LID non présentes dans les en-têtes existants sont ajoutées au plan READ ; SFI local utilisé si LID absent. Aucun VERIFY PIN ni écriture. Ce parcours ne couvre que les DF sélectionnés et n’affirme pas une extraction complète de la puce.

Outil `tools/compare_capture_payloads.py` : compare les ensembles de réponses READ non nulles, avec empreintes SHA-256 abrégées, sans faire passer les alias répétés pour de nouveaux contenus. Les quatre captures étendues et la copie iPhone du 19 octobre ont les mêmes 17 contenus non nuls. Rapport de travail local : `../captures-locales/carte-des-champs-zou.md`.

### Résultat réel de l’inventaire direct du 19 octobre

Capture locale `zou-inventaire-direct.json` récupérée sur l’iPhone : 57 commandes de sélection, 51 descripteurs EF valides, six fins de liste 6A82. Répartition MF/2000/1000/2300/2100/2200 : 4/11/2/19/8/7. Aucune limite atteinte, aucun nouveau contenu READ non nul. Le résultat est maintenant affiché par application dans l’interface. Rejeu du rapport privé et test de reprise vérifiés par `Tests/RegionalDirectInventory/main.swift`.

Comparaison structurelle : 2217 et 2203 partagent les dix octets initiaux E00201250E0020250806. Dans 2203, la table commence à l’octet13 : 35 blocs de huit octets avec index16bits1..35, deux octets constants0101 puis quatre octets variables (35 valeurs distinctes). Complément64octets à293 puis143octets nuls à357. Le motif20250806 est compatible avec une date BCD sans que le rôle de date soit établi. Aucune de ces structures n’est présentée comme un historique ou une liste de transporteurs. Rapport local : `../captures-locales/resultat-inventaire-et-correspondances.md`.

### Noms lisibles et annotations locales

L’écran des titres présente le Pass ZOU! Études comme une désignation déclarée par le porteur lorsque la paire de droits attendue et le rapprochement du trajet sont présents ; le droit6 devient « Trajet de référence probable ». Aucun intitulé commercial n’est prétendu lu dans la puce.

Ajout de RegionalCodeLabels : dictionnaire local persistant via AppStorage, séparé du rapport brut. Le nom du tarif, du fournisseur, du transporteur, des lieux et des lignes peut être corrigé sans modifier les octets de la carte. Les annotations sont bornées au réseau et au type de champ ; lieux/lignes sont en plus bornés au transporteur et au mode, tarifs au fournisseur et à la structure. Les noms de lieu et de tarif sont repris dans les titres de l’interface. Effacer une annotation rétablit le décodage normal. Les noms ajoutés sont identifiés comme tels. Test pur Swift : sauvegarde/relecture, séparation des réseaux et champs, suppression et JSON invalide. Compilation iOS réussie ; interaction physique de l’alerte à vérifier sur téléphone.

### Sélecteur de région et fiche intégrée

Le globe de l’onglet Scan ouvre maintenant TransportRegionPicker (Île-de-France / Navigo, Région Sud / ZOU!). Le choix persiste et remplace le contenu de l’onglet. Le lecteur régional utilise une instance partagée ; démarrage automatique, double appui Scan et action rapide suivent la région sélectionnée. L’import Navigo remet le choix sur Île-de-France.

La fiche ZOU! présente une illustration de carte avec grand logo, lecture rapide, titres et passages. Paramètres du support, inventaire et commandes avancées sont regroupés dans « Informations et outils développeur », en bas de la fiche. Les détails des validations restent dépliables. Le logo utilisé provient de la page officielle ZOU! : https://zou.maregionsud.fr/public/media/logo/2026-04/zou-paca.svg_.png ; l’illustration de carte est créée en SwiftUI, sans prétendre reproduire exactement le support physique.

Dictionnaire fixe de gares du réseau250920 : 8582 Marseille–Saint-Charles,13143 Toulon,16008 Les Arcs–Draguignan, suivant les correspondances confirmées par le porteur. Pour les événements, garde transporteur2 / mode train5 conservée. Les noms reconnus prennent priorité sur les anciennes annotations et leur commande d’édition est masquée.

RegionalHistory enregistre les captures régionales terminées lorsque le réglage commun de conservation est activé. Elles sont affichées avec les scans Navigo, par date, dans l’historique principal ; consulter une archive ne remplace pas la lecture courante et n’autorise pas les commandes NFC depuis cette archive. Une capture courante existante est importée une seule fois, seulement avec ce réglage activé. L’effacement général inclut l’historique régional. Un fichier d’historique illisible est conservé et jamais écrasé silencieusement.

Validation : compilation iPhone et simulateur réussies ; contrôle visuel de la fiche principale dans le simulateur ; tests de persistance/opt-in/reprise/suppression/protection de fichier corrompu et dictionnaire de gares. Rejeu du décodeur d’événements sur la capture locale. Le simulateur ne valide pas la lecture NFC physique.

### Décodage AMC et scan harmonisé — 19 octobre 2026

Identification documentée du DF2200 : son AID A000000291D25008009301 est celui de l’AMC commune, d’après l’ADCET. Les SFI17/03 correspondent à Global Data / Predefined IDs selon la FAQ. Le fichier2203 est désormais interprété comme une table d’identifiants de services, et non une table de hachages ni un historique candidat : 35 entrées PIDXSector16bits / PIDXKeyRef16bits / PIDXValue32bits. Les 35 secteurs sont numérotés1..35 ; toutes les références de calcul valent0101. Le secteur4 est Transports publics,14 Mobilité,21 Transports privés. La présence de ces identifiants ne prouve aucune utilisation effective de ces services ni une validation bus.

En-tête observé : référence d’émetteur E002 aux octets0..1 (Gemalto dans le registre ADCET), version01 à2, périmètre250E00 à3..5, date BCD20250806 à6..9, référence de signature1A01 à10..11, nombre d’entrées35 à12. La date est présentée comme date inscrite dans les données AMC, sans l’assimiler à l’achat du Pass ni à la remise de la carte. Le complément64octets correspond au bloc de signature de la structure ; son authenticité n’a pas été vérifiée. Des essais locaux avec une ancienne clé publique publiée n’ont pas validé les messages reconstruits : aucun diagnostic d’invalidité de la carte n’en est tiré, le schéma signé exact et l’actualité de cette clé n’étant pas établis.

RegionalAMC utilise des lectures explicites absolues ou relatives à l’AID AMC exact, reconstitue le binaire en contrôlant les trous/conflits, valide le périmètre, la date, les limites, l’unicité des secteurs et le remplissage final. Les identifiants et leur rôle sont affichés dans Informations et outils développeur, avec valeurs marquées sensibles. Tests synthétiques et rejeu local sur le rapport d’inventaire réussis.

Sources primaires :
- https://www.adcet.org/amc/la-norme/faq/ (AID, SFI, références de champs)
- https://www.adcet.org/amc/les-registres/emetteurs-de-donnees-amc/ (E002 = Gemalto)
- https://www.adcet.org/documents/amc/231001-adcet-normeamc-autressupports-v1-2.pdf (annexe VII.1 : secteurs et structures AMC ; algorithmes publics, sans transposer le format non-Calypso au fichier de cette carte)

L’outil local tools/cross_reference_capture.py recherche à toutes les positions de bits les 35 identifiants AMC32bits, normaux et inversés, dans les autres fichiers : aucune recopie. Il retrouve les codes de gares dans les événements et le droit6 connus. Un motif8582 dans le droit5 chevauche les champs appareil/agent de vente : rejeté comme correspondance fortuite. Aucun nouveau passage bus établi, aucun identifiant de borne extrait. Les fichiers2114/2314 restent partiellement non interprétés ; la nature de leurs données n’est pas renommée sans schéma.

Interface : le symbole IDFM réemploie les deux tracés SVG du carré et du personnage déjà présents sur le visuel Navigo Nominatif du projet. Le visuel de carte ZOU! est maintenant celui de la page officielle « Enregistrer votre carte personnelle » : https://zou.maregionsud.fr/public/media/image/2026-07/carte_zou_mockup.png ; ce visuel comporte une personne et un numéro fictifs, pas les données du porteur. Le logo distinct reste disponible dans le sélecteur. EmptyScanView est partagé entre les deux réseaux : mêmes cible, bouton et animation ; ZOU! fixe son visuel d’exemple et masque l’import Navigo. Les valeurs par défaut et le catalogue d’exemples Navigo sont conservés.

### Recto corrigé et mesure radio courte

Le recto retenu par le porteur est le support bleu actuel, visible sur la photo officielle `duplicata_header.png`, pas le verso avec photo et QR. Asset restauré avec image_gen, puis fond bleu foncé uniformisé et défaut de détourage corrigé ; fichier et consigne dans `Design/ZOU-front-image.md`.

La piste selon laquelle le motif BCD initial de2114 représenterait le numéro imprimé est rejetée après réponse négative du porteur sur les six derniers chiffres proposés. Aucun nom métier n’est ajouté pour ce motif.

La fiche officielle2026 de la ligne59 identifie SUMA SANARY / SUMA GARDANNE comme transporteurs : https://storage.googleapis.com/is-wp-22-prod/uploads-prod/2026/01/ZOULER_Ligne59_TOULON_AIX_2026_05012026.pdf . Cette information externe n’est associée à aucun code de la carte faute de preuve. Les recherches publiques n’ont pas confirmé de seconde technologie de stockage sur ce support particulier.

Ajout de NFCMetadata optionnel au rapport : UID, AID initial, historicalBytes (TypeA), applicationData (TypeB), indicateur de codage propriétaire. Les descriptions viennent du SDK CoreNFC NFCISO7816Tag.h. Elles décrivent l’interface observée et n’excluent pas à elles seules une seconde interface physique.

Commande « Identifier l’interface NFC · lecture courte » dans les outils développeur : conserve la capture, sauvegarde la précédente, exige la même carte via le contrôle UID existant, enregistre les métadonnées de détection natives puis termine sans envoyer de READ ni d’APDU supplémentaire par le code de l’app. La sélection initiale peut être effectuée par iOS pour découvrir le tag. Aucun nouveau fichier de carte n’est parcouru. Tests de compatibilité des anciens rapports, persistance et curseur sans emplacement de lecture réussis. Il reste à recueillir cette mesure sur la carte physique.


### Comparaison de deux supports — 19 octobre 2026

Le rapport privé de l’ancienne carte a été récupéré séparément (27 échanges, lecture rapide uniquement). Il ne permet pas de comparer ses autres applications au plein inventaire de la carte actuelle. Un seul titre est référencé/décodé dans les deux banques publiques lues ; aucun second titre de référence n’y apparaît. Le voyage préférentiel imprimé sur cet ancien support est une information fournie par le titulaire.

Les six événements anciens sont ferroviaires, fournisseur 2, titre emplacement 1. Les lieux 8582, 13143 et 16008 correspondent au dictionnaire régional existant. Leur champ équipement est systématiquement égal au lieu : ne pas présenter ce champ comme une borne physique individuellement identifiée. Les six fins non interprétées sont identiques, 64 bits `1E02020000000000`, à partir du bit 168. Elles sont désormais préservées et affichables ; aucune signification métier ne leur est assignée. Les trois événements actuels ont une fin nulle de 112 bits.

Ancien titre : fournisseur 154, tarif 32671, structure 20, statut brut 3 ; le prix décodé vaut 5500 centimes et la vente le 1 septembre 2025. Confirmation du montant demandée au titulaire. La validité décodée (1 septembre 2024–31 août 2026) doit être corroborée avant d’en tirer des conclusions commerciales. Le fournisseur des événements (2) et celui des titres (154 ancien / 29 nouveau) sont des champs distincts.

Audit structurel indépendant : quatre fichiers cycliques sont annoncés dans les en-têtes sélectionnés de la carte actuelle. Les 14 emplacements sont tous entièrement lus : 2000/2010 contient trois événements et trois zéros ; 1000/1014 (un), 1000/1015 (trois) et 2300/230A (quatre) sont tous nuls. Les fichiers 2115/2315 sont linéaires et partagés, pas deux journaux indépendants. Ce constat ne prouve ni absence historique de bus ni absence d’une autre structure non cyclique/protégée.

Outils ajoutés : `tools/audit_event_storage.py` (types de fichiers, couverture des enregistrements, répétitions et conflits) et `tools/compare_event_layouts.py` (champs, offsets et suffixes des événements explicites). Test Swift `Tests/RegionalEventComparison/main.swift` exécuté avec les deux captures privées : six événements anciens et trois actuels, deux modèles de suffixes conservés, un titre ancien contre deux actuels.

Référence pour les types 1/2/4/8/9 : CNA ToolUtils, https://github.com/calypsonet/cna-tool-card-analyzer-app/blob/main/src/main/java/org/calypsonet/tool/calypso/common/ToolUtils.java . Le code officiel confirme aussi la lecture des enregistrements par SFI et numéro absolu ; notre lecteur emploie le même mode READ RECORD. Aucun essai de PIN ni écriture de carte dans cette analyse.


### Ancienne carte : inventaire direct et événement spécial

Rapport privé du 19 octobre : 94 échanges. Deux applications connues sélectionnables (MF et 2000) ; les quatre autres AID testés répondent 6A82. Ne pas généraliser cette absence à tous les identifiants possibles. L’inventaire annonce 15 EF, dont 14 entièrement lus (830/859 octets). Seul MF/0003, 29 octets, refuse la lecture avec 6982. Les quatre compteurs sans LID exploitable sont lus via les SFI 0A–0D dans 2000. `audit_capture.py` sait maintenant exploiter l’inventaire séquentiel en l’absence de GET DATA EF LIST et fusionner ces alias SFI sans double comptage ; la capture actuelle conserve son bilan 49/51 (18858/18935).

Nouvelle donnée dans 2000/2040, enregistrement 1 : date 30 avril 2026, 18:34, bitmap 02000518, EventResult 34 (22 hex), fournisseur 2, lieu 13143, équipement 13143, titre 1. Aucun EventCode : le mode et la nature ne doivent pas être inventés. Après ces champs, 126 bits tous nuls. Les deux autres emplacements du fichier sont nuls. Le titulaire confirme un trajet TER ce jour-là ; il propose un diagnostic de double validation, non confirmé.

La lecture standard demandait EventCode et écartait cet événement spécial : un chemin distinct `regionalSpecialEvents` conserve désormais les champs présents sans polluer le journal des passages. Une section « Autres événements enregistrés » les expose. La lecture rapide inclut désormais 2040 (six fichiers), pour ne plus perdre cet accès après une actualisation. Tests : code événement absent refusé pour les passages ordinaires ; événement spécial reconnu, données tronquées rejetées ; test de parcours rapide mis à jour et passé ; build iOS réussi et installé.

Piste documentaire : modèle public BELL, page PDF 34 / page imprimée 30, https://www.apam.it/uploads/bandi/1467376217_A11_Draft_Card_Data_Model_BELL.pdf : exemple EventResult 22 hex = abonnement venant d’expirer ; 1A/1B hex = seconde validation ignorée. Référentiel italien dérivé d’Intercode, PAS le dictionnaire ZOU : ne confirmer ni expiration ni double validation dans l’app. L’absence d’EventCode réduit encore la portée de cette correspondance, dont la table dépend du type de transaction.

Prix ancien : titulaire confirme 90 € payés et propose un mauvais encodage du montant réduit. Conserver séparément 55 € décodés et 90 € déclarés ; aucune preuve du tarif Solidarité. Une page officielle SNCF mentionne un ancien tarif réduit Études de 55 €, https://www.ter.sncf.com/sud-provence-alpes-cote-d-azur/tarifs-cartes/cartes-reduction/pass-zou-etudes : le montant seul ne distingue pas les produits ni ne prouve une erreur. Aucun nouveau scan demandé après cet inventaire.


### Historique par support et ajout Lignes d’Azur

Les rescans d’une même carte sont regroupés par UID en une seule entrée, conservant la date initiale et la dernière date de lecture. Les anciens rapports sont conservés dans `scans` et accessibles dans les outils de la carte. Migration automatique de l’ancien format UID+date ; copie exacte de secours `regional-history.json.before-card-grouping.json` créée avant écriture. Les UID distincts ne sont pas fusionnés. Aucun changement des parseurs ou de l’historique Navigo.

Test sur l’historique privé du téléphone : cinq entrées regroupées en trois cartes (deux lectures ZOU actuelle, deux ancienne ZOU, une Nice). Dates initiales conservées. Le scan Nice de 16:53 est reclassé grâce à l’émetteur du support, indépendamment de l’ancien libellé demandé ZOU. Le globe propose Île-de-France, Région Sud ZOU et Nice Lignes d’Azur ; visuels officiels locaux et profil de lecture partagé sans forcer le décodeur de titres ZOU sur Nice. Filtre tram, nom des transporteurs observés et titres partiels 191/99 visibles. Les autres lectures restent dans les outils ; une lecture interrompue n’efface pas la dernière capture complète affichée du même support.

Validation : tests `RegionalHistory` (opt-in, persistance, reprise, migration, sauvegarde, UID distincts, fixture privée cinq→trois) et `LignesAzur` (détection, événement, titres partiels, absence d’application des lieux SNCF et maintien des deux titres ZOU) passés. Builds iPhone/simulateur réussis ; écran Nice contrôlé visuellement. Sources des images et limites du décodage : Design/LignesAzur.md.


### Oùra, Pass Pass et MOBIB — premières lectures détectées

Trois supports identifiés explicitement par le titulaire, dans l’ordre chronologique de 17:11 : Oùra, Pass Pass, MOBIB Bruxelles. Les captures ne contenaient qu’un SELECT de l’application ZOU, refusé 6A82 ; aucune donnée de titre ni événement n’avait été lue. Ne pas interpréter cela comme une carte vide. Les correspondances UID→profil sont conservées exclusivement dans Documents/regional-card-profiles.json, non embarquées dans le code. Champ optionnel declaredRegion pour les nouvelles lectures et formats anciens compatibles. L’initialSelectedAID belge observé est aussi reconnu comme MOBIB.

Ajout des trois profils au globe et des visuels représentatifs (Design/RegionalCards.md). Le plan rapide sélectionne désormais l’application réellement détectée et les racines Calypso usuelles, et ne se limite plus au seul AID ZOU. Pour MOBIB, ajout de l’AID exact 315449432E494341D05600019101 à la configuration iOS et lecture des chemins relatifs et absolus publics ; pas de transposition du décodeur Intercode ZOU aux contenus belges. Repli de classe 00 vers 94 seulement si 6E00 et pour SELECT/READ/GET DATA, jamais pour authentification ni écriture.

Action visible « Lire les données complémentaires » : nouvelle lecture de l’inventaire séquentiel incluant l’AID natif, puis lecture des EF adressables. En cas d’inventaire non disponible dès le premier EF, essai des chemins publics usuels. Reprise persistée avec le même UID, arrêt borné, refus et réponses brutes conservés. Les fiches expliquent la lecture initiale et la lecture complémentaire, notamment Nice ; l’historique indique « Support détecté · lecture à compléter » si aucun fichier n’a été lu. Les données des trois nouveaux supports nécessitent une nouvelle présentation physique avec cette version.

Lignes d’Azur : événement ligne 1 présenté comme Tram 1, sans champ de renommage pour cette correspondance confirmée. Code transporteur 25 scoping réseau/mode conservé ; TER 2 distinct des émetteurs de titres.

Tests AdditionalRegions sur l’historique privé : trois supports, absence de contenu inventé, AID natifs autorisés dans tous les plans, curseurs de reprise et plans rapides 6/12 chemins validés. Régressions RegionalHistory et LignesAzur passées. Builds iPhone et simulateur réussis ; écran Pass Pass et consignes contrôlés dans le simulateur.


### Lecture accessible depuis les fiches de l’historique

Correction : les actions de lecture étaient masquées quand RegionalCardView recevait archivedCapture, alors que ces fiches affichaient les consignes de lecture. Les boutons de lecture rapide et complémentaire sont maintenant disponibles sur ces fiches, avec animation de lecture, affichage du nouveau rapport terminé et bouton de reprise visible après interruption. L’UID attendu de la fiche est transmis au lecteur et contrôlé avant toute exploration ; présenter un autre support ne remplace pas la carte ouverte. Les captures historiques restent conservées par RegionalHistory. La vue ne suit la capture fraîche que pour le même UID et une lecture terminée.


### Écran Scan prêt pour un nouveau support

Le dernier réseau reste dans AppStorage. Le lecteur régional distingue désormais le rapport sauvegardé de la présentation fraîche : aucune ancienne capture ni carte de l’historique n’est injectée automatiquement dans l’écran Scan au démarrage. Le choix d’un réseau (y compris le même) et le passage de l’app en arrière-plan réinitialisent uniquement cet affichage ; aucune donnée historique n’est effacée. La fin d’un nouveau scan affiche le résultat puis le regroupe par UID dans l’historique existant. Les fiches historiques restent consultables et permettent une nouvelle lecture liée à leur UID. Même réinitialisation du marqueur d’affichage Navigo, sans toucher à ses données ni à ses parseurs.


### Analyse des quatre compléments — disparition apparente des données

Rapports récupérés après rétablissement de la liaison iPhone. Lignes d’Azur contient les mêmes titres 191/99 et le même Tram 1 dans des lectures `READ DIRECTORY 2000 SFI xx`, ignorées jusque-là par ticketingRecords. Ces adresses sont maintenant reconnues en contexte 2000, sous les AID Calypso déjà autorisés. Aucun nouveau scan Nice nécessaire pour retrouver ces données.

Conservation des données utiles : RegionalHistory reconstruit une présentation avec `priorReads` calculés depuis ses snapshots, exclusivement du même UID. ticketingRecords consulte l’ancienne lecture seulement si le fichier ne possède aucune réponse de lecture dans la nouvelle. Un nouveau fichier relu explicitement à zéro remplace les anciens événements ; un conflit de réponses ne passe pas silencieusement. Ces sources sont uniquement en mémoire, exclues de CodingKeys : les rapports originaux et exports bruts ne sont pas mélangés. L’interface signale l’utilisation de données antérieures. L’écran Scan conserve son comportement nouveau scan demandé à chaque ouverture.

AMC : chemins relatifs 3203 sous l’AID AMC et chemin absolu 3200/3203 ajoutés au même décodeur borné, en plus de 2203. Décodage validé sur les captures : Nice date AMC 25 octobre 2024, Oùra 3 septembre 2021, Pass Pass 30 décembre 2019 ; chacune comporte 35 identifiants multiservices. Il ne s’agit ni de 35 trajets ni de 35 titres, et ces dates ne sont pas présentées comme dates d’achat/fabrication. Une section Informations du support expose ces faits, les détails restent dans les outils.

MOBIB : le journal APDU montre 19 EF annoncés dans l’application native, mais le lecteur employait à tort le décalage du FCP historique sous prétexte du nom 1TIC. Il sélectionnait répétitivement 0020 à la place de 2001, 2010, etc. Le décalage de l’application belge observée est celui du format récent ; les 19 identifiants deviennent distincts. Le préfixe AID ne force plus le mode ancien. Aucune donnée de billetterie MOBIB n’a donc encore été récupérée dans ce complément ; une nouvelle présentation reste nécessaire pour ces fichiers, sans authentification.

Oùra et Pass Pass : inventaire EF de la racine MF seulement, qui ne visite pas ses sous-dossiers. Les compléments incluent désormais également les six chemins de billetterie publics sous 2000. Les rapports actuels apportent les informations multiservices mais ne prouvent pas l’absence de titres. Il faut une nouvelle lecture de ces chemins pour étudier leur billetterie.

Tests ComplementaryReads sur l’historique privé : Nice 1 événement/2 titres récupérés via SFI de dossier ; trois AMC datées ; 19 LID MOBIB corrects ; conservation même support, exclusion d’un UID différent, absence de résurrection après lecture d’un événement nul, absence de priorReads dans les exports. Régression RegionalHistory passée. Builds iOS/simulateur validés.


### Reprise du 20 octobre 2026

Reprise après interruption de crédits : le build iPhone/simulateur de la correction des compléments était réussi, mais son installation n’était pas confirmée. Tests ComplementaryReads et RegionalHistory réexécutés avec succès sur les captures privées. Historique de l’iPhone récupéré et conservé séparément ; aucune nouvelle lecture après les quatre compléments du 19 octobre. Installation de la correction confirmée le 20 octobre, bundle fr.thibauddesloges.transportreader, séquence 2452 de la base d’installation actuelle. Prochaine acquisition utile : nouveaux compléments Oùra, Pass Pass et MOBIB pour les chemins corrigés ; Nice est récupérable depuis le rapport existant. Validations de bus ZOU non identifiées à ce stade.
