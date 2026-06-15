import os
import requests

MODJO_API_KEY = os.environ.get("MODJO_API_KEY", "")
MODJO_BASE_URL = "https://api.modjo.ai/v1"
PROFESSIONAL_SERVICES_TEAM_ID = 3


def _headers():
    return {"x-api-key": MODJO_API_KEY}


def check_user_in_professional_services(email):
    if not MODJO_API_KEY:
        return False, "MODJO_API_KEY non configuré"

    page = 1
    while True:
        resp = requests.get(
            f"{MODJO_BASE_URL}/users",
            headers=_headers(),
            params={"perPage": 100, "page": page},
            timeout=10
        )
        if resp.status_code != 200:
            return False, f"Erreur API Modjo ({resp.status_code})"

        data = resp.json()
        users = data.get("values", [])

        for user in users:
            if user.get("email", "").lower() == email.lower():
                if PROFESSIONAL_SERVICES_TEAM_ID in user.get("teamIds", []):
                    return True, None
                else:
                    return False, f"Utilisateur trouvé mais pas dans l'équipe Professional Services"

        pagination = data.get("pagination", {})
        if page >= pagination.get("lastPage", 1):
            break
        page += 1

    return False, f"Utilisateur introuvable dans Modjo pour l'email {email}"
