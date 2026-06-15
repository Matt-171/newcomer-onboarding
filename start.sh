#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

# Charger .env si présent
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Créer le venv si absent
if [ ! -d .venv ]; then
  echo "Création du virtualenv..."
  python3 -m venv .venv
fi

# Installer les dépendances si nécessaire
if ! .venv/bin/python -c "import flask, requests" 2>/dev/null; then
  echo "Installation des dépendances..."
  .venv/bin/pip install flask requests --quiet
fi

echo "Démarrage sur http://localhost:8081"
open "http://localhost:8081" 2>/dev/null || true
.venv/bin/python app.py
