# Eclosion — état courant

## Validé

Acquis explicitement validés, à préserver :
- Mouvement général doux de l'œuf ; oscillation `1.5` et épaisseur `2.5`.
- Pression interne excentrée, principe des attaches successives et pivot asymétrique.
- Continuité du même fragment, rotation, éclairage dépendant de l'orientation et chute globalement crédible. La continuité matérielle au passage de la coquille à la plaque reste le défaut prioritaire ci-dessous.

## Défaut prioritaire actuel

Validation utilisateur du 30 septembre 2026 : la géométrie diagnostique de la lèvre fixe, d'épaisseur 2.5 suivant la normale locale, est bien placée à `.600` et `.620`. Son intégration au rendu normal reprend cette même géométrie ; son aspect matériel éclairé reste à contrôler visuellement.

Continuité matérielle entre fissure, ouverture locale, plaque encore attachée et fragment libre : éliminer toute impression de patch ou de surface qui apparaît.

## Gelé pour l'itération actuelle

- Mouvement général, oscillation, épaisseur, pression excentrée, principe des attaches, pivot, rotation, éclairage et chute ; n'y toucher que si la correction prioritaire l'exige directement.
- Rebond final, perfectionnement du trou intérieur, rendu artistique et multi-fragments reportés.
- L'atelier reste un diagnostic à fragment unique, avec progression déterministe, lecture/pause, ralenti, rejeu et aperçus 9:16 / 9:20 ; ce n'est pas encore le timer produit.

## Prochaine étape

Diagnostiquer la continuité de géométrie, de matière et d'ordre de peinture au début du soulèvement et aux ruptures d'attaches, puis corriger ce seul défaut sans artifice visuel. Après modification Dart, appliquer les vérifications d'AGENTS.md ; la validation visuelle utilisateur reste distincte, en lecture normale et ralentie sur les deux formats portrait.

Les dernières corrections de transition ne sont pas encore validées visuellement. L'historique ne consigne aucune exécution Dart/Flutter pour ces corrections ; cette réorganisation documentaire n'en exécute pas et ne vaut pas validation du rendu.

## Dette connue / à traiter plus tard

- Rebond final légèrement trop marqué pour une coquille légère.
- Trou intérieur à perfectionner.
- Multi-fragments pas encore commencé ; réseau complet de fissures à développer.
- Décor, matière et œuf provisoires ; éléments artistiques séparés et poussin validé à intégrer.
- Compte à rebours produit et interactions +5/−5 absents ; intégrer l'éclosion à `00:00` et formaliser la visibilité du poussin avant zéro.
- Réglages d'affichage non persistants après rechargement.

## Multi-fragments et variabilité future

Décision d'architecture future, à prendre en compte sans l'implémenter maintenant. La priorité reste d'obtenir un fragment unique visuellement et physiquement correct ; cette décision ne vaut pas validation du rendu actuel.

Le futur système devra permettre qu'une nouvelle utilisation du timer ne produise pas toujours exactement la même coquille cassée.

### Architecture à prévoir

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
