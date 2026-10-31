# Recto ZOU!

Image intégrée : `../metroreader/Assets.xcassets/ZouCard.imageset/zou-front.png`.

Référence : photographie officielle montrant le recto bleu tenu dans une main, https://zou.maregionsud.fr/public/media/headrest/2026-06/duplicata_header.png . Le verso est conservé dans ZouCardBack et n’est plus utilisé comme visuel principal.

Retouche réalisée avec l’outil intégré image_gen : remise à plat, suppression de la main et du fond ; puis bleu foncé uniforme à la demande du porteur ; enfin suppression d’un défaut d’alpha intérieur. Le résultat est une restauration/reconstitution graphique de référence, pas une photographie de la carte du porteur.

Consigne finale transmise à l’outil :

> Fix a defect in this exact image, do not redesign it. There is an accidental transparent/whitish blemish INSIDE the card in the upper right, around x=1230,y=220 on this approximately 1580x1000 canvas. Completely remove that blemish and ALL interior alpha holes. Every pixel INSIDE the rounded rectangular card must be fully opaque alpha=255. Only the area OUTSIDE the card may be transparent. The entire blue fill inside the card must be perfectly flat solid #0055A4 with NO noise, NO grain, NO gradients, NO light spots and NO shading. Preserve the thin light-blue outline letters, central white ZOU! logo with cyan stroke and orange dot, and bottom-right Région Sud text and crest in exactly their current position and form. The top right defect region should simply be the same fully opaque blue as the rest of the background. Do not add any white shapes or marks. Keep the same dimensions and rounded corners. Final clean flat printed card graphic.

Contrôle : résultat1580×995 ; minimum alpha253/255 dans la zone intérieure contrôlée, aucun trou transparent. La marge extérieure conserve la transparence. Le résultat est inspecté sur fond clair dans le simulateur avant livraison.
