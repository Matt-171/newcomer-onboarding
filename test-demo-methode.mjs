/* Contrôle du 15/09/2026 : sur la fiche démo, l'onglet « Méthode OB (brouillon) » ne doit PAS
   être visible pour un observateur (ni un newcomer, ni un mentor, ni un TL), alors que la
   surcouche démo ouvre tous les autres access_*. Un admin doit le garder.
   Firebase est BLOQUÉ (réseau) : sans ça le test écrirait dans la vraie base de prod. */
import pkg from "/Users/mtabareau/node_modules/playwright-core/index.js";
const { chromium } = pkg;

const STORE_KEY = "newcomer_onboarding_v1";
const DATA = {
  seq: 2,
  newcomers: [
    { id: 1, name: "Démo Onboarding", email: "demo@pennylane.com", demo: true,
      arrival_date: "2026-09-14", role: "Consultant Fonctionnel Comptable" },
    { id: 2, name: "Vraie Fiche", email: "vraie.fiche@pennylane.com",
      arrival_date: "2026-09-14", role: "Consultant Fonctionnel Comptable" },
  ],
  structure: {},
};

const browser = await chromium.launch();
const results = [];
for (const role of ["observateur", "newcomer", "mentor", "tl", "admin"]) {
  const ctx = await browser.newContext();
  await ctx.route("**://*.gstatic.com/**", r => r.abort());
  await ctx.route("**://*.firebasedatabase.app/**", r => r.abort());
  await ctx.route("**://*.googleapis.com/**", r => r.abort());
  await ctx.route("**://*.firebaseio.com/**", r => r.abort());
  const page = await ctx.newPage();
  await page.addInitScript(([k, d, r]) => {
    localStorage.setItem(k, d);
    localStorage.setItem("newcomer_onboarding_user", "Test");
    if (r !== "admin") sessionStorage.setItem("local_role_view", r);
  }, [STORE_KEY, JSON.stringify(DATA), role]);
  await page.goto("file:///Users/mtabareau/newcomer-onboarding/docs/index.html#/newcomer/1/planning");
  await page.waitForTimeout(1200);
  const tabs = await page.$$eval(".tabbar a, .tabbar button, .tabbar div[onclick]",
    els => els.map(e => e.textContent.replace(/\s+/g, " ").trim()).filter(Boolean));
  const flat = tabs.join(" | ");
  results.push({ role, methode: /Méthode OB/.test(flat), nbOnglets: tabs.length, onglets: flat });
  await ctx.close();
}
console.log("Fiche DÉMO (id 1) :");
for (const r of results) {
  console.log(`  ${r.role.padEnd(12)} Méthode OB visible = ${r.methode ? "OUI" : "non"}  (${r.nbOnglets} onglets)`);
}
console.log("\nDétail observateur :\n  " + (results.find(r => r.role === "observateur") || {}).onglets);
console.log("\nDétail admin :\n  " + (results.find(r => r.role === "admin") || {}).onglets);
await browser.close();
