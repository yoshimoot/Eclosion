# Eclosion — état courant

## Validé

Acquis explicitement validés, à préserver :
- Mouvement général doux de l'œuf ; oscillation `1.5` et épaisseur `2.5`.
- Pression interne excentrée, principe des attaches successives et pivot asymétrique.
- Continuité du même fragment, rotation, éclairage dépendant de l'orientation et chute globalement crédible.
- Correction CanvasKit validée : après opérations booléennes, réapplication explicite de `PathFillType.evenOdd` pour préserver correctement les trous/occlusions et supprimer la grande zone grise artificielle.
- Lèvre fixe validée : géométrie, exposition, épaisseur `2.5`, occlusions et matériau actuel à préserver.
- Cavité intérieure validée structurellement le 5 octobre 2026 : une seule surface intérieure globale de l'œuf, indépendante des fragments ; les ouvertures ne font que révéler cette surface. Le polish artistique de matière/éclairage reste différé.
- Refactor du fragment unique vers une définition générique `_FragmentSpec` validé visuellement le 5 octobre 2026 : aucune régression notable sur la fissure, l'ouverture, le soulèvement, la lèvre fixe, la cavité, la rotation, la chute ou les occlusions. La `seed` est présente comme métadonnée de reproductibilité mais ne modifie encore aucun rendu.
- Agrégation mono→liste validée visuellement le 5 octobre 2026 : les frames de fragments sont désormais préparées en liste et les apertures sont agrégées pour calculer la coquille fixe, sans changement visuel du fragment de référence.
- Introduction du cluster partagé validée visuellement le 5 octobre 2026 avec un seul fragment : les arêtes primaires et les impulsions de pression sont centralisées sans régression du rendu de référence.
- Premier voisin à arête réellement partagée validé visuellement le 5 octobre 2026 : continuité de la fissure commune, absence de double bord/patch et maintien crédible de la plaque voisine pendant le détachement du fragment principal.
- Couplage pression commune → flexion/dommage → pivot du voisin validé visuellement comme amélioration le 5 octobre 2026.
- Détachement complet du voisin validé visuellement le 5 octobre 2026 : dernière charnière rompue par dommage cumulé du cluster, transition continue pivot → libération → chute, trajectoire distincte et conservation correcte de la silhouette jusqu'au sol après généralisation du moteur.
- Tri d'occlusion dynamique validé visuellement le 5 octobre 2026 : l'ordre de peinture dépend désormais de la profondeur 3D courante des fragments et non de leur ordre dans la liste.
- Modèle de pression interne clarifié le 5 octobre 2026 : les événements représentent des efforts du poussin (appuis locaux puis effort plus large tête/corps sur la zone fragilisée). Un même effort peut affecter plusieurs plaques et produire des détachements simultanés ou quasi simultanés.

## Défaut prioritaire actuel

Le fragment unique et l'ouverture sont désormais sur une base structurelle cohérente : continuité fissure → ouverture → tranche → fragment, clip evenOdd corrigé, lèvre fixe intégrée et cavité intérieure globale indépendante des fragments.

Le tri d'occlusion inter-fragments par profondeur 3D courante est validé visuellement. Les fragments 2 et 3 ont été redessinés pour former un cluster plus naturel tout en conservant leurs arêtes réellement partagées. Leur départ en vol suit maintenant la normale locale complète 3D de la coquille, puis la gravité domine, et la transition attache → vol ne comporte plus de snap artificiel à 0,001.

La dernière vidéo a montré un défaut plus précis : malgré des trajectoires latérales devenues distinctes, les fragments 2 et 3 tendaient encore vers des orientations de chute trop semblables. La rotation du vol couplé a donc été reprise : chaque plaque conserve désormais l'angle et la vitesse angulaire acquis au moment de la rupture de sa dernière attache, puis cette vitesse est amortie progressivement. La pression du poussin ne continue plus à piloter leur rotation après libération, et la hauteur d'atterrissage est calculée avec leur orientation réelle d'arrivée.

Avant de poursuivre cette validation de mouvement, les fragments 2 et 3 ont été redessinés une seconde fois le 6 octobre 2026 pour mieux raconter la mécanique du poussin : fragment 2 plus compact et immédiatement adjacent à l'ouverture principale, fragment 3 comme prolongement gauche/bas de la même zone de contrainte. Leurs arêtes réellement partagées sont préservées et leurs centres mécaniques ont été recentrés sur ces nouvelles formes. Aucun timing, attache, pression ou loi de vol n'a été modifié dans cette passe. Les 6 tests ciblés « Vol couple » passent toujours après ce redraw. La suite complète reste à 22 tests passés / 5 échecs connus ; aucun nouvel échec ciblé n'est introduit.

## Gelé pour l'itération actuelle

- Mouvement général, oscillation, épaisseur, pression excentrée, principe des attaches, pivot, éclairage et chute ; préserver ces acquis. Pour l'itération actuelle, la priorité est uniquement la validation visuelle de la nouvelle forme/position des fragments 2 et 3 ; ne pas retoucher encore leur mécanique.
- Rebond final, polish artistique de la cavité et rendu artistique global reportés.
- Le multi-fragments peut désormais commencer sur la base du `_FragmentSpec` validé ; ne pas introduire encore d'aléatoire libre.
- L'atelier reste un diagnostic à fragment unique, avec progression déterministe, lecture/pause, ralenti, rejeu et aperçus 9:16 / 9:20 ; ce n'est pas encore le timer produit.

## Prochaine étape

Valider d'abord sous Chrome la nouvelle géométrie du cluster avant toute autre correction de mouvement. Le fragment 2 doit lire comme une petite plaque satellite immédiatement créée par la pression près de l'ouverture principale ; le fragment 3 doit lire comme une plaque secondaire issue de la même propagation vers la gauche et légèrement vers le bas. Vérifier que les trois morceaux forment visuellement une seule zone de rupture cohérente avec le trajet du contact interne du poussin, sans impression de trous placés à la main. Si cette géométrie est validée, reprendre ensuite la validation de la rotation inertielle déjà implémentée.

La future variabilité restera pilotée par une seed unique par éclosion ; aucune géométrie ni aucun timing ne doit être randomisé frame par frame.

Après toute prochaine modification Dart, appliquer les vérifications d'AGENTS.md ; la validation visuelle utilisateur reste distincte dans Chrome.

## Dette connue / à traiter plus tard

- Rebond final légèrement trop marqué pour une coquille légère.
- Polish artistique de la cavité intérieure à reprendre plus tard : contraste, teinte, ombres internes et apport de lumière selon l'ensemble des ouvertures.
- Le cluster partagé, l'arête commune, le couplage pression → flexion/dommage/pivot, le détachement complet du voisin, la continuité de forme post-libération et le tri d'occlusion inter-fragments par profondeur 3D courante sont validés visuellement. La phase tardive utilise maintenant une trajectoire continue de contact du poussin et un couple de rotation spatial ; cette extension reste à valider.
- Décor, matière et œuf provisoires ; éléments artistiques séparés et poussin validé à intégrer.
- Compte à rebours produit et interactions +5/−5 absents ; intégrer l'éclosion à `00:00` et formaliser la visibilité du poussin avant zéro.
- Réglages d'affichage non persistants après rechargement.

## Multi-fragments et variabilité future

Décision d'architecture future, à prendre en compte sans l'implémenter maintenant. La priorité reste d'obtenir un fragment unique visuellement et physiquement correct ; cette décision ne vaut pas validation du rendu actuel.

Le futur système devra permettre qu'une nouvelle utilisation du timer ne produise pas toujours exactement la même coquille cassée.

### Architecture à prévoir

- Les fragments appartiennent à un **cluster de fracture commun** : ils ne sont pas générés comme des trous indépendants.
- Une arête entre deux fragments voisins est une seule cassure géométrique, référencée par les deux fragments.
- Les impulsions de pression sont définies au niveau du cluster ; elles propagent l'endommagement dans le réseau puis libèrent les attaches successivement.
- Le détachement d'une plaque peut redistribuer la contrainte et modifier la mobilité de ses voisines.
- Multi-fragments et fragmentation procédurale contrôlée.
- Génération déterministe à partir d'une seed créée au début d'une nouvelle éclosion et conservée pendant toute l'éclosion.
- Aucune génération aléatoire de géométrie frame par frame.
- Variations contraintes du réseau de fissures, de la forme et de la taille des fragments, des ramifications, des positions et de l'ordre de rupture des attaches, des pivots, ainsi que de petites variations de trajectoire et de timing.
- Une même seed doit permettre de reproduire exactement une éclosion pour le debug et les tests.

### Contraintes visuelles et physiques

- Conserver le langage visuel de `reference/Planche Eclosion.png`.
- Fissures irrégulières, organiques, asymétriques et non répétitives.
- La fissure doit toujours devenir réellement le bord du futur fragment.
- Préserver la continuité physique fissure → ouverture → tranche → fragment.
- Éviter un aléatoire libre pouvant produire des géométries incohérentes.

### Performance

- Cible finale Android.
- Générer et préparer la géométrie d'une éclosion une seule fois, puis la réutiliser pendant l'animation.
- Mutualiser autant que possible textures, matériaux et ressources ; éviter les allocations inutiles à chaque frame.
- Valider ultérieurement les performances sur appareil Android réel.
- Objectif de conception : animation fluide à 60 fps sur un appareil Android milieu de gamme, à confirmer par mesures réelles.

### Ordre de développement

1. Obtenir un fragment unique visuellement et physiquement correct.
2. Rendre l'architecture `Fragment` générique.
3. Passer à quelques fragments.
4. Construire l'éclosion multi-fragments.
5. Mesurer et optimiser sur Android.
6. Introduire la génération procédurale déterministe par seed.
