# Déploiement sur PythonAnywhere (gratuit, sans CB)

## 1. Créer le compte
- Va sur https://www.pythonanywhere.com/registration/register/beginner/
- Crée un compte **Beginner** (gratuit, pas de CB)
- Note ton username (ex: `Matt171`) → ton app sera sur `Matt171.pythonanywhere.com`

## 2. Récupérer le code depuis GitHub
- Dans le dashboard PythonAnywhere → onglet **Consoles** → ouvre une **Bash console**
- Tape :
```bash
git clone https://github.com/Matt-171/newcomer-onboarding.git
cd newcomer-onboarding
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

## 3. Créer la Web App
- Onglet **Web** → **Add a new web app** → **Next**
- Choisis **Manual configuration** (PAS Flask) → **Python 3.10** → **Next**

## 4. Configurer le virtualenv
- Dans la page Web, section **Virtualenv**, entre :
```
/home/TON_USERNAME/newcomer-onboarding/.venv
```
(remplace TON_USERNAME par ton vrai username)

## 5. Configurer le fichier WSGI
- Section **Code**, clique sur le lien du fichier WSGI (ex: `/var/www/ton_username_pythonanywhere_com_wsgi.py`)
- **Efface tout** et colle ce qui suit (remplace TON_USERNAME) :

```python
import sys
import os

project_home = '/home/TON_USERNAME/newcomer-onboarding'
if project_home not in sys.path:
    sys.path.insert(0, project_home)

# Variables d'environnement Slack
os.environ['SLACK_BOT_TOKEN'] = 'xoxb-ton-token-ici'
os.environ['SLACK_CHANNEL_PROSERVICES'] = 'C0AQ8GY9J58'

from app import app as application
```

- **Save** (bouton en haut à droite)

## 6. Lancer
- Retourne sur l'onglet **Web** → bouton vert **Reload**
- Ouvre `https://TON_USERNAME.pythonanywhere.com`

## Pour mettre à jour plus tard (après un push GitHub)
Dans la Bash console :
```bash
cd ~/newcomer-onboarding
git pull
.venv/bin/pip install -r requirements.txt   # seulement si requirements a changé
```
Puis onglet **Web** → **Reload**
