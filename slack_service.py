import os
import requests

SLACK_TOKEN = os.environ.get("SLACK_BOT_TOKEN", "")
SLACK_CHANNEL_ID = os.environ.get("SLACK_CHANNEL_PROSERVICES", "")
SLACK_USERGROUP_CS = os.environ.get("SLACK_USERGROUP_CS_SERVICES", "")
SLACK_USERGROUP_OB = os.environ.get("SLACK_USERGROUP_OB", "")

BASE_URL = "https://slack.com/api"


def _headers():
    return {"Authorization": f"Bearer {SLACK_TOKEN}", "Content-Type": "application/json"}


def _check_config(*keys):
    missing = [k for k in keys if not os.environ.get(k)]
    if missing:
        return False, f"Variables d'env manquantes : {', '.join(missing)}"
    return True, None


def lookup_user_by_email(email):
    ok, err = _check_config("SLACK_BOT_TOKEN")
    if not ok:
        return None, err
    resp = requests.get(
        f"{BASE_URL}/users.lookupByEmail",
        headers=_headers(),
        params={"email": email},
        timeout=10
    )
    data = resp.json()
    if not data.get("ok"):
        return None, data.get("error", "Erreur inconnue")
    return data["user"]["id"], None


def invite_to_channel(slack_user_id):
    ok, err = _check_config("SLACK_BOT_TOKEN", "SLACK_CHANNEL_PROSERVICES")
    if not ok:
        return False, err
    resp = requests.post(
        f"{BASE_URL}/conversations.invite",
        headers=_headers(),
        json={"channel": SLACK_CHANNEL_ID, "users": slack_user_id},
        timeout=10
    )
    data = resp.json()
    if not data.get("ok") and data.get("error") != "already_in_channel":
        return False, data.get("error", "Erreur inconnue")
    return True, None


def _get_usergroup_members(usergroup_id):
    resp = requests.get(
        f"{BASE_URL}/usergroups.users.list",
        headers=_headers(),
        params={"usergroup": usergroup_id},
        timeout=10
    )
    data = resp.json()
    if not data.get("ok"):
        return None, data.get("error", "Erreur inconnue")
    return data.get("users", []), None


def add_to_usergroup(slack_user_id, usergroup_id, usergroup_name):
    ok, err = _check_config("SLACK_BOT_TOKEN")
    if not ok:
        return False, err
    if not usergroup_id:
        return False, f"ID du groupe {usergroup_name} non configuré"

    members, err = _get_usergroup_members(usergroup_id)
    if err:
        return False, err
    if slack_user_id in members:
        return True, None

    members.append(slack_user_id)
    resp = requests.post(
        f"{BASE_URL}/usergroups.users.update",
        headers=_headers(),
        json={"usergroup": usergroup_id, "users": ",".join(members)},
        timeout=10
    )
    data = resp.json()
    if not data.get("ok"):
        return False, data.get("error", "Erreur inconnue")
    return True, None


VINCENT_SLACK_ID = "U06CDV632UF"


def send_dm(user_id, message):
    ok, err = _check_config("SLACK_BOT_TOKEN")
    if not ok:
        return False, err
    # Ouvrir une conversation DM
    resp = requests.post(
        f"{BASE_URL}/conversations.open",
        headers=_headers(),
        json={"users": user_id},
        timeout=10
    )
    data = resp.json()
    if not data.get("ok"):
        return False, data.get("error", "Erreur inconnue")
    channel_id = data["channel"]["id"]
    # Envoyer le message
    resp2 = requests.post(
        f"{BASE_URL}/chat.postMessage",
        headers=_headers(),
        json={"channel": channel_id, "text": message},
        timeout=10
    )
    data2 = resp2.json()
    if not data2.get("ok"):
        return False, data2.get("error", "Erreur inconnue")
    return True, None


def send_swan_request(newcomer_name, newcomer_role):
    role_str = f" ({newcomer_role})" if newcomer_role else ""
    message = (
        f"Bonjour Vincent,\n\n"
        f"Pourrais-tu créer un accès au Dash SWAN pour {newcomer_name}{role_str} "
        f"qui vient de rejoindre l'équipe Professional Services ?\n\n"
        f"Merci !"
    )
    return send_dm(VINCENT_SLACK_ID, message)


def run_slack_tasks(newcomer_email):
    results = {}

    if not SLACK_TOKEN:
        err = "SLACK_BOT_TOKEN non configuré"
        return {
            "slack_channel": (False, err),
            "slack_group_cs": (False, err),
            "slack_group_ob": (False, err),
        }

    user_id, err = lookup_user_by_email(newcomer_email)
    if not user_id:
        err_msg = f"Utilisateur Slack introuvable pour {newcomer_email} : {err}"
        return {
            "slack_channel": (False, err_msg),
            "slack_group_cs": (False, err_msg),
            "slack_group_ob": (False, err_msg),
        }

    results["slack_channel"] = invite_to_channel(user_id)
    results["slack_group_cs"] = add_to_usergroup(user_id, SLACK_USERGROUP_CS, "@cs.services")
    results["slack_group_ob"] = add_to_usergroup(user_id, SLACK_USERGROUP_OB, "@ob")

    return results
