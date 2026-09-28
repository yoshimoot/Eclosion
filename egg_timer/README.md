# Atelier Éclosion — fragment-v1

Prototype technique local sans nouvelle dépendance ni image générée. Matière et décor provisoires pour évaluer le volume et le mouvement d'un fragment.

## Lancer

Depuis egg_timer sur la branche de test :

```powershell
flutter pub get
flutter run -d chrome
```

Redémarrer l'application si le compteur Flutter initial est encore ouvert.

## Examiner

1. Choisir 9:16 ou 9:20. Sur petite fenêtre, les réglages sont sous l'aperçu.
2. Déplacer le curseur : intact → fissure → ouverture → chute → contact au sol.
3. Utiliser le ralenti et « Rejouer la chute » pour examiner les faces et la tranche.
4. Régler épaisseur et oscillation. Masquer l'œuf pour isoler le fragment.
5. Copier les réglages avant de recharger : pas de sauvegarde automatique.

Le curseur représente une expérience de six secondes, pas un minuteur produit.
La chute est construite, avec contact au sol mais sans rebond.
La scène artistique, le poussin et les commandes d'ajout/retrait de temps seront intégrés après validation.

## Vérifier

```powershell
flutter analyze
flutter test
```

Pour les retours : version fragment-v1, réglages copiés et défaut précis ; vidéo de 3–5 secondes uniquement pour un défaut de mouvement.
