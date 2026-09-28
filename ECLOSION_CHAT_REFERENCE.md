# ECLOSION — REFERENCE PERMANENTE POUR CHAT

## 1. Projet

Éclosion est un prototype Flutter destiné au visuel interactif d’un minuteur MorphoTime.

Application cible :
- Flutter
- Android à terme
- développement et validation rapide actuellement via Chrome

Dossier Flutter :
egg_timer/

Référence visuelle principale :
reference/Planche Eclosion.png

Cette planche est la référence visuelle pour :
- la chronologie de l’éclosion ;
- la morphologie générale de l’œuf ;
- l’évolution des fissures ;
- la fragmentation ;
- l’apparition du poussin ;
- l’ambiance finale de la scène.

Elle ne doit jamais être modifiée par une itération de développement.

---

## 2. Objectif final

Créer une animation interactive 2.5D d’éclosion convaincante, continue et physiquement cohérente.

Le résultat final doit associer :

1. la qualité visuelle de la planche de référence ;
2. une mécanique de fissuration et fragmentation crédible ;
3. une évolution temporelle continue ;
4. une interaction adaptée à un minuteur ;
5. une implémentation Flutter robuste et réutilisable.

Principe central :

Le spectateur doit voir une coquille qui se fissure et se sépare réellement.

Il ne doit jamais avoir l’impression de voir :
- une image remplacée par une autre ;
- un fragment qui apparaît ;
- un patch superposé ;
- un crossfade entre deux états.

---

## 3. Chronologie

La planche suit approximativement les états :

100 %
→ 75 %
→ 50 %
→ 25 %
→ 5 %
→ 00:01
→ 00:00

00:00 correspond au moment où le poussin a éclos.

Les derniers mouvements secondaires de coquille peuvent continuer brièvement après 00:00.

La rupture finale peut être rapide mais doit rester physiquement continue.

Rapide ne signifie pas :
remplacement brutal d’un état par un autre.

---

## 4. Mouvement de l’œuf

Deux phénomènes doivent rester distincts.

### Mouvement général

Il représente le poussin qui bouge ou change de position à l’intérieur.

Il doit être :
- doux ;
- inertiel ;
- irrégulier ;
- vivant ;
- ponctué de pauses.

Le crescendo vers l’éclosion vient surtout de l’augmentation de la fréquence et de la variété des mouvements.

Il ne doit pas principalement venir d’une augmentation excessive de leur amplitude.

### Pression locale

Elle représente une pression ciblée du poussin contre la coquille.

Elle peut être :
- plus courte ;
- plus localisée ;
- plus franche ;
- excentrée par rapport au futur fragment.

Cette pression provoque :
- extension de fissure ;
- ouverture locale ;
- rupture d’attaches ;
- pivot de plaques.

---

## 5. Morphologie des fissures

Référence stricte : Planche Eclosion.png.

Les fissures doivent être :

- fines au départ ;
- irrégulières ;
- anguleuses mais organiques ;
- asymétriques ;
- composées de segments courts et moyens ;
- enrichies de ramifications secondaires ;
- accompagnées de quelques branches mortes ;
- non répétitives ;
- non géométriques.

Éviter :
- étoile régulière ;
- zigzag répétitif ;
- polygone propre ;
- traits décoratifs indépendants de la matière.

Principe fondamental :

La fissure doit créer le futur bord du fragment.

La continuité recherchée est :

fissure
→ ouverture
→ deux bords de matière
→ tranche
→ fragment.

La géométrie du fragment ne doit pas remplacer une géométrie de fissure différente.

---

## 6. Coquille et fragmentation

La coquille est cassante, pas élastique.

Éviter :
- flexion caoutchouteuse ;
- étirement ;
- grand retour élastique.

La logique physique est :

résistance
→ fissuration
→ rupture locale
→ nouvelle résistance
→ rupture suivante.

Une plaque reste reliée par plusieurs attaches.

Lorsque les attaches cèdent successivement :
- certaines parties s’ouvrent ;
- d’autres restent raccordées ;
- le pivot évolue ;
- la mobilité augmente.

La pression étant excentrée, un bord peut commencer à se soulever avant l’autre.

---

## 7. Fragment 2.5D

Un fragment doit représenter la même matière avant et après son détachement.

Il possède :
- une face extérieure ;
- une face intérieure si elle devient visible ;
- une tranche cassée ;
- une orientation ;
- un éclairage dépendant de cette orientation.

La face du fragment ne doit jamais apparaître artificiellement.

Avant changement d’orientation réel, son aspect doit rester pratiquement identique à celui de la coquille environnante.

La tranche ne devient visible que lorsque :
- la cassure est suffisamment ouverte ;
- l’orientation permet réellement de voir l’épaisseur.

Ne jamais afficher une bordure uniforme autour du fragment.

---

## 8. Paramètres actuellement validés

Épaisseur :
2.5

Oscillation :
1.5

Ces valeurs sont gelées sauf décision explicite contraire.

Sont également considérés comme acquis et à préserver autant que possible :

- mouvement général actuel de l’œuf ;
- pression interne excentrée ;
- principe des attaches successives ;
- pivot asymétrique ;
- rotation du fragment ;
- éclairage dépendant de l’orientation ;
- chute du fragment globalement crédible.

---

## 9. Dette connue

À traiter plus tard, séparément :

- rebond final du fragment légèrement trop important pour une coquille légère ;
- trou / intérieur de l’œuf à perfectionner ;
- multi-fragments ;
- rendu artistique final de la matière ;
- décor final ;
- poussin final ;
- éclosion complète.

Ces éléments ne doivent pas être mélangés à une itération consacrée à un autre problème.

---

## 10. Règle d’itération

Une itération = un problème visuel principal.

Avant de modifier plusieurs systèmes, identifier d’abord le défaut dominant.

Les éléments déjà validés sont gelés.

Si une correction dégrade un élément validé, il s’agit d’une régression.

Après deux corrections successives sans amélioration claire :
ne pas continuer à empiler des ajustements.

Revenir au diagnostic de la cause ou à l’architecture.

---

## 11. Méthode de travail Chat / Codex

CHAT sert principalement à :
- analyser les vidéos ;
- comparer au visuel de référence ;
- identifier le défaut prioritaire ;
- déterminer ce qui doit rester gelé ;
- définir les critères visuels d’acceptation ;
- produire un prompt Codex précis.

CODEX sert principalement à :
- lire le dépôt actuel ;
- identifier la cause technique ;
- modifier le code ;
- effectuer le formatage ;
- lancer l’analyse Flutter ;
- exécuter les tests ;
- rendre compte des modifications.

Le test visuel final reste effectué dans Chrome puis analysé dans Chat.

Boucle normale :

vidéo actuelle
→ analyse Chat
→ un défaut prioritaire
→ prompt Codex court
→ diagnostic et correction
→ format / analyse / tests
→ validation Chrome
→ nouvelle vidéo
→ analyse Chat.

---

## 12. Prompts Codex

Ne pas répéter tout le cahier des charges à chaque itération.

Les règles permanentes appartiennent à :
AGENTS.md

L’état technique courant appartient à :
PROGRESS.md

Le prompt Codex d’une nouvelle itération doit principalement contenir :

- objectif unique ;
- symptôme observé ;
- éléments gelés si nécessaire ;
- critères d’acceptation ;
- éventuelle zone du code déjà identifiée.

Si la cause technique est incertaine :
demander d’abord à Codex de diagnostiquer.

Si la cause est suffisamment connue :
Codex peut diagnostiquer brièvement puis corriger dans la même tâche.

---

## 13. Validation visuelle

Une compilation réussie ne suffit jamais à valider une animation.

Pour valider une correction, examiner selon le besoin :

- frames avant/après une transition ;
- progression lente ;
- vidéo complète ;
- cohérence spatiale ;
- continuité des formes ;
- continuité du mouvement ;
- cohérence de l’éclairage ;
- absence de patch ;
- absence de remplacement brutal d’état.

La qualité visuelle et la continuité physique priment sur une simple réussite technique des tests.

---

## 14. Principe de décision

Lorsque plusieurs solutions techniques sont possibles :

préférer celle qui produit une continuité physique réelle et une architecture réutilisable.

Éviter les artifices destinés uniquement à masquer un défaut à quelques frames.

Le prototype doit progressivement constituer une base propre pour l’éclosion complète et le futur multi-fragments.
