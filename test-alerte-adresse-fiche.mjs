/* Contrôle du 15/09/2026 : l'écran Gestion des droits doit signaler une fiche dont l'adresse ne
   correspond à personne alors qu'une connexion très proche existe (cas vécu : fiche saisie
   `prenom.duran`, compte Google `prenom.durand`), et le bouton doit corriger l'adresse.
   ⚠️ Noms et adresses de ce test VOLONTAIREMENT fictifs : le dépôt est public en entier, pas
   seulement docs/ — pas d'adresse de collègue ici.
   Firebase est BLOQUÉ : sans ça le test écrirait dans la vraie base de prod. */
import pkg from "/Users/mtabareau/node_modules/playwright-core/index.js";
const { chromium } = pkg;

const STORE_KEY = "newcomer_onboarding_v1";
const URL = "file:///Users/mtabareau/newcomer-onboarding/docs/index.html#/droits";

function data({ ficheEmail, logins }) {
  return {
    seq: 3,
    newcomers: [
      { id: 1, name: "Démo Onboarding", email: "demo@pennylane.com", demo: true, arrival_date: "2026-09-14" },
      { id: 2, name: "Camille Duran", email: ficheEmail, arrival_date: "2026-09-14" },
      { id: 3, name: "Sacha Bonnet", email: "sacha.bonnet@pennylane.com", arrival_date: "2026-09-14" },
    ],
    structure: { logins },
  };
}
const LOGINS_OK = {
  "camille.durand": { name: "Camille", email: "camille.durand@pennylane.com", last: "2026-09-15T08:00:00.000Z" },
  "sacha.bonnet":   { name: "Sacha",   email: "sacha.bonnet@pennylane.com",   last: "2026-09-15T08:00:00.000Z" },
};

const browser = await chromium.launch();
async function ouvrir(d) {
  const ctx = await browser.newContext();
  for (const p of ["**://*.gstatic.com/**", "**://*.firebasedatabase.app/**", "**://*.googleapis.com/**", "**://*.firebaseio.com/**"])
    await ctx.route(p, r => r.abort());
  const page = await ctx.newPage();
  page.on("dialog", d => d.accept());
  await page.addInitScript(([k, v]) => {
    localStorage.setItem(k, v);
    localStorage.setItem("newcomer_onboarding_user", "Test");
  }, [STORE_KEY, JSON.stringify(d)]);
  await page.goto(URL);
  await page.waitForTimeout(1000);
  return { ctx, page };
}
const alerteTxt = page => page.evaluate(() => {
  const c = [...document.querySelectorAll(".card")].find(e => /Adresse de fiche probablement fautive/.test(e.textContent));
  return c ? c.textContent.replace(/\s+/g, " ").trim() : "";
});

// 1. Cas fautif : l'alerte doit apparaître
let { ctx, page } = await ouvrir(data({ ficheEmail: "camille.duran@pennylane.com", logins: LOGINS_OK }));
console.log("1. fiche fautive → alerte :", (await alerteTxt(page)) ? "OUI" : "NON (régression)");
console.log("   texte :", (await alerteTxt(page)).slice(0, 200));

// 2. Le bouton corrige l'adresse de la fiche, et l'alerte disparaît
await page.click("button:has-text(\"Corriger l'adresse de la fiche\")");
await page.waitForTimeout(400);
const apres = await page.evaluate(k => {
  const d = JSON.parse(localStorage.getItem(k));
  return d.newcomers.find(n => n.id === 2).email;
}, STORE_KEY);
console.log("2. après clic → email de la fiche :", apres);
console.log("   alerte encore là :", (await alerteTxt(page)) ? "OUI (régression)" : "non");
await ctx.close();

// 3. Aucun faux positif quand tout est cohérent
({ ctx, page } = await ouvrir(data({ ficheEmail: "camille.durand@pennylane.com", logins: LOGINS_OK })));
console.log("3. adresses correctes → alerte :", (await alerteTxt(page)) ? "OUI (faux positif)" : "non");
await ctx.close();

// 4. Aucun faux positif sur une fiche créée d'avance, titulaire jamais connectée
({ ctx, page } = await ouvrir(data({ ficheEmail: "camille.durand@pennylane.com", logins: {} })));
console.log("4. fiche sans aucune connexion → alerte :", (await alerteTxt(page)) ? "OUI (faux positif)" : "non");
await ctx.close();

// 5. Deux homonymes réellement distincts (noms de famille différents) ne doivent pas s'apparier
({ ctx, page } = await ouvrir(data({
  ficheEmail: "camille.lefevre@pennylane.com",
  logins: { "camille.marchand": { name: "Camille Marchand", last: "2026-09-15T08:00:00.000Z" } },
})));
console.log("5. deux homonymes distincts → alerte :", (await alerteTxt(page)) ? "OUI (faux positif)" : "non");
await ctx.close();

await browser.close();
