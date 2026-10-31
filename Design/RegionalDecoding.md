# Décodage régional — sources et limites

## MOBIB

Interprétation indépendante du format binaire, confrontée aux descriptions de
champs dans Metrodroid (révision b910c1806fd86aa545223baf1d21fc5afe68eee2).
Aucun fichier source Kotlin ni base complète de stations n'est intégré.

Sources de référence :
- https://github.com/metrodroid/metrodroid/blob/b910c1806fd86aa545223baf1d21fc5afe68eee2/src/commonMain/kotlin/au/id/micolous/metrodroid/transit/mobib/MobibTransaction.kt
- https://github.com/metrodroid/metrodroid/blob/b910c1806fd86aa545223baf1d21fc5afe68eee2/src/commonMain/kotlin/au/id/micolous/metrodroid/transit/mobib/MobibSubscription.kt
- https://github.com/metrodroid/metrodroid/blob/b910c1806fd86aa545223baf1d21fc5afe68eee2/src/commonMain/kotlin/au/id/micolous/metrodroid/transit/mobib/MobibLookup.kt
- https://github.com/metrodroid/metrodroid/blob/b910c1806fd86aa545223baf1d21fc5afe68eee2/src/commonMain/kotlin/au/id/micolous/metrodroid/transit/en1545/Calypso1545TransitData.kt

Lecture limitée à l'AID belge 315449432E494341D05600019101, avec contrôle du
réseau 056001 dans l'environnement (24 bits à l'offset 13).

Événement version 3, enregistrement de 48 octets : version 6 bits, jour 14 bits
(depuis le 01/01/1997), minute locale 11 bits, champ inconnu 31 bits, bitmap
5 bits. Ses champs optionnels sont : bloc inconnu 4 bits + arrêt bus 12 bits,
ligne 16 bits, deux blocs inconnus 16 bits, bloc mode 5 bits + lieu 17 bits +
inconnu 10 bits. Second bitmap 6 bits : transaction 24 bits, inconnu 16 bits,
transfert 8 bits, inconnu 16 bits, première date 14 bits + minute 11 bits,
inconnu 16 bits. Puis 21 bits de sens non établi. Les autres versions sont
laissées brutes. Les fichiers 2010 et 2017 sont examinés séparément, sans
attribuer à un événement le rôle d'une validation acceptée faute de champ
résultat établi. Les doublons binaires entre journaux sont regroupés.

Titre version 4, 48 octets : version 6 bits, inconnu 19 bits, produit 14 bits,
inconnu 50 bits, montant 16 bits, inconnu 6 bits, bitmap 5 bits. Champs : deux
inconnus 5 bits, date de vente 14 bits, durée 10 bits, inconnu 8 bits ; puis
24 bits inconnus. L'extension restante demeure brute. Produit 0x2803 : JUMP
10 voyages selon le référentiel ci-dessus. Son compteur est le bloc de 24 bits
correspondant à l'emplacement du titre dans 2069. Compteur absent ≠ zéro.
Le numéro d'une transaction n'est pas présenté comme nombre total de voyages.

Les dates et lieux ne sont pas corrigés d'après les souvenirs du porteur.
L'absence d'autres événements décodés ne signifie pas absence de trajets.

## Pass Pass

Le format commun Intercode permet une date de fin sans date de début : bitmap
de validité à 2 bits (bit 0 : début, bit 1 : fin). L'en-tête partiel est donc
conservé quand le modèle ZOU à deux dates ne s'applique pas. La suite de type
20 est parcourue pour lire la date de vente ; aucun prix nul n'est interprété
comme preuve de gratuité. Le nom commercial du tarif inconnu n'est pas inventé.

Associations limitées au réseau 250000 et au fournisseur événement 23 :
Ilévia ; lignes 100 = Métro 1, 101 = Métro 2, 102 = Tram.
Sources :
- https://github.com/metrodroid/metrodroid/blob/b910c1806fd86aa545223baf1d21fc5afe68eee2/src/commonMain/kotlin/au/id/micolous/metrodroid/transit/intercode/IntercodeLookupPassPass.kt
- https://github.com/metrodroid/metrodroid/blob/b910c1806fd86aa545223baf1d21fc5afe68eee2/data/passpass/lines.csv
- https://github.com/metrodroid/metrodroid/blob/b910c1806fd86aa545223baf1d21fc5afe68eee2/src/commonMain/kotlin/au/id/micolous/metrodroid/transit/intercode/IntercodeSubscription.kt

## Correspondances de lieux et informations du support

- MOBIB : clé (mode bus 15, ligne 54, arrêt 2931), soit 0x3C6CB73.
  La base publique `mdst/mobib.mdst` associe cette clé à TRINITE ; le fichier
  `data/mobib/mapping.csv` renvoie au stop GTFS 2960F. Trinité est situé à
  Ixelles (secteur Bailli–Trinité), pas à Forest. L'application présente donc
  cette association comme « à confirmer », et non comme preuve d'un arrêt
  de montée, compte tenu de l'ancienneté du dictionnaire et de l'incertitude
  des souvenirs. Une desserte partielle en 2024 est évoquée par le porteur,
  sans modifier les données encodées.
  Sources :
  https://github.com/metrodroid/metrodroid/blob/b910c1806fd86aa545223baf1d21fc5afe68eee2/mdst/mobib.mdst
  https://github.com/metrodroid/metrodroid/blob/b910c1806fd86aa545223baf1d21fc5afe68eee2/data/mobib/mapping.csv
  https://www.ixelles.be/site/741-Bailli-Trinite
- Pass Pass : réseau 250000, fournisseur 23, métro, code de lieu 4850 : Gare
  Lille-Flandres (clé de dictionnaire 0x1712F2). Les autres lieux inconnus ne
  sont pas extrapolés. Source :
  https://github.com/metrodroid/metrodroid/blob/b910c1806fd86aa545223baf1d21fc5afe68eee2/data/passpass/stations.csv
- Le code de personnalisation et l'échéance technique de l'environnement
  Intercode sont affichés sur la fiche régionale principale. La date de
  naissance reste dans une rubrique dépliable marquée `privacySensitive`.
  Le code commercial brut n'est pas transformé en un profil tarifaire sans
  référentiel. Source de structure :
  https://github.com/metrodroid/metrodroid/blob/b910c1806fd86aa545223baf1d21fc5afe68eee2/src/commonMain/kotlin/au/id/micolous/metrodroid/transit/intercode/IntercodeTransitData.kt

L'application affiche le compteur lu du titre JUMP 10. Elle ne calcule pas
un nombre de voyages consommés par soustraction : ce calcul ne prouve pas
l'existence d'autant de passages enregistrés. Les souvenirs du porteur ne
sont pas ajoutés comme des événements de la carte.
Les sept fichiers de journaux potentiels 2010, 2011, 2012, 2016,
2017, 2018 et 2040 sont récapitulés dans les outils développeur : seuls des
comptages d'enregistrements lus et non nuls sont affichés, sans prétendre qu'ils
sont tous des journaux de validations ni qu'ils couvrent toute la mémoire.

## Recherche large commune à toutes les cartes

Le mode « Recherche complète · applications et fichiers » est distinct de la
lecture ordinaire. Le même plan s'applique aux six réseaux : inventaire EF
FIRST/NEXT lorsqu'il est disponible, métadonnées d'applications, répertoire ISO,
30 SFI à la racine, chemins usuels absolus et relatifs, puis 255 adresses de
dossiers xx00. Les SFI d'un dossier ne sont ajoutés que si sa sélection réussit.
Les fichiers et AID découverts sont ajoutés au plan dans les limites existantes.

Cette exploration reste bornée : elle ne parcourt pas les 65536 identifiants de
fichiers possibles et ne contourne aucune règle d'accès. Une application non
autorisée dans la configuration CoreNFC est signalée, non sélectionnée. Les
PIN et les écritures ne font pas partie de ce mode. Le point de reprise conserve
l'inventaire, le dossier, la requête de métadonnées et l'enregistrement courant.

Depuis une fiche régionale, la nouvelle recherche reste liée à l'UID de la carte
et conserve l'ancien rapport. La loupe de la page principale donne aussi accès
à ce mode pour Navigo ; ces rapports avancés restent distincts de l'historique
Navigo ordinaire afin de ne pas créer une seconde fiche pour le même pass.

L'ouverture NFC est retentée au maximum deux fois uniquement si CoreNFC signale
que le système est occupé. Une annulation explicite n'est pas relancée.

## Identifiants découverts et validation des événements

Le bilan compte des identifiants uniques, pas les nombreuses re-sélections
nécessaires pour parcourir une application. Une sélection 9000 signifie ouverte,
6A82 signifie identifiant absent ; une sélection non tentée faute de configuration
CoreNFC est distinguée des refus de la carte. Les identifiants découverts par les
objets TLV de la carte sont ajoutés explicitement à Info.plist avant une nouvelle
lecture. Un bouton permet alors de ne lire que ce sous-ensemble, en conservant
les captures précédentes et en vérifiant l'UID.

Pour une application dont la disposition FID n'est pas connue, le SFI annoncé
dans chaque descripteur EF est lu aussi. Si FIRST/NEXT n'est pas pris en charge,
les SFI de la racine et les chemins conventionnels sont testés. Les refus de
classe ISO à l'inventaire font l'objet du même repli en classe Calypso que les
autres commandes de sélection en lecture seule.

Les champs EventResult et EventNotOKCounter d'Intercode restent des valeurs
brutes. Le champ résultat absent n'est pas traité comme une validation réussie.
Aucun code de refus propre à Pass Pass n'est inventé à partir d'une table d'un
autre transporteur. Le compteur de contrat de produit inconnu conserve son unité
indéterminée et n'est pas affiché comme solde ou nombre de voyages.

L'échéance technique MOBIB version 3 se lit à l'offset 42 sur 14 bits, après le
réseau et le champ inconnu de 5 bits ; les autres versions ne sont pas extrapolées.
Source : MobibTransitData.kt dans le même référentiel Metrodroid cité plus haut.

## Contrôle FIRST/NEXT des applications

Une opération distincte utilise SELECT APPLICATION par préfixe (P1=04), avec
P2=00 pour FIRST puis P2=02 pour NEXT. Quatre familles de noms autorisées sont
interrogées : A000000291, A000000404, 315449432E et 334D54522E. Le FCI est
analysé pour récupérer le nom réellement sélectionné, sans chercher des motifs
arbitraires dans des données utilisateur. Les noms déjà ouverts dans les scans
conservés sont distingués des nouveaux, dont les fichiers sont inventoriés.

La fin 6A82 est distinguée d'une répétition, d'une réponse sans FCI exploitable,
d'un refus, d'une commande non prise en charge et de la limite de 64 occurrences.
Après interruption, FIRST/NEXT est rejoué et l'ordre vérifié avant de reprendre.
Le bilan ne certifie que la liste correspondant au préfixe interrogé : une
application hors de ces familles ou non exposée reste hors de la preuve.

Source primaire :
https://github.com/eclipse-keypop/keypop-reader-java-api/blob/main/src/main/java/org/eclipse/keypop/reader/selection/CommonIsoCardSelector.java

Le bilan de couverture indépendant recoupe les en-têtes EF effectivement
énumérés avec les réponses READ RECORDS/READ BINARY. Les accès SFI sont limités
au même AID ; les chemins relatifs ne sont rattachés à un fichier que si la
réponse SELECT identifie le même en-tête. Un refus d'accès n'est pas compté comme
une lecture complète, et un repli binaire réussi n'est pas considéré comme une
lacune à cause du refus préalable de READ RECORDS.

Le bilan FIRST/NEXT est également recoupé avec les noms de DF déjà observés dans
les FCI. Une fin 6A82 n'est pas acceptée comme preuve si une application connue
manque, notamment lorsqu'un préfixe est refusé alors que des noms complets de
la même famille fonctionnent. Les noms de sélection et les noms réellement
renvoyés par les FCI sont conservés séparément pour ce contrôle.

La fiche n'affiche plus les commandes de lecture en plusieurs sections : une
action principale suit l'état de la carte (reprise, nouveaux identifiants,
actualisation), puis un menu unique regroupe les explorations avancées. Les
bilans de couverture et de familles sont repliés avec les limites de la lecture.

### Pass Pass : extension du titre à validité sans début (20 octobre)

Le format commun 0x20 du titre 25907 utilise tous les champs du préfixe,
mais seulement la date de fin (bitmap de validité 2). Les extensions présentes
sont zones, vente, paiement, valeur/débit et classe de véhicule (masque 412).
Le décodage atteint le bit 204 ; les 28 bits restants du record sont nuls.
Sont désormais conservés : classe voyageur, zones, terminal et agent de vente,
paiement/prix et couple valeur chargée/débit. Le prix nul n'établit pas la
 gratuité ; les paramètres 160/1 et le compteur associé 1432 n'établissent pas
un nombre de voyages ni une somme en euros. Le nom du produit reste inconnu.
Les champs techniques sont repliés dans la fiche du titre.

Référence de disposition des champs (réimplémentation indépendante) :
https://github.com/metrodroid/metrodroid/blob/b910c1806fd86aa545223baf1d21fc5afe68eee2/src/commonMain/kotlin/au/id/micolous/metrodroid/transit/intercode/IntercodeSubscription.kt

L'AID Pass Pass complété à 16 octets est accepté pour les lectures SFI de son
application billettique : les nouveaux fichiers sont décodés directement, sans
nécessiter un ancien scan sous l'alias court. Les chemins relatifs APP de cet
alias ne sont pas admis : leur FID estimé reste ambigu. Les tests vérifient les
six événements directement dans la nouvelle capture et qu'une lecture nulle
n'est jamais remplacée par une ancienne valeur non nulle.
