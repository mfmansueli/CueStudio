#!/usr/bin/env node
// Registers Cue's iPhone app with Firebase App Check in the server's project, through the Firebase CLI's login (no gcloud needed):
//   1. turns on the App Check API in the project;
//   2. puts Cue's Apple team id on the iOS app (App Attest needs it);
//   3. registers App Attest, the provider a real iPhone uses (TestFlight and App Store builds), with one-hour tokens;
//   4. registers the debug token Debug builds use (the lab's, when its file is there), never printing it.
// Run from server/: node scripts/register-app-check.js [debug-token-file]. Safe to run again: each step only sets what it sets.
"use strict";
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const project = "cuestudio-app";
const bundleID = "com.cuestudioteleprompter";
const teamID = "X5392U638Q";

function firebaseToolsLib() {
  const bin = fs.realpathSync(execFileSync("which", ["firebase"]).toString().trim());
  let dir = path.dirname(bin);
  for (let i = 0; i < 6; i++, dir = path.dirname(dir)) {
    for (const candidate of [dir, path.join(dir, "libexec", "lib", "node_modules", "firebase-tools"), path.join(dir, "lib", "node_modules", "firebase-tools")]) {
      try {
        if (JSON.parse(fs.readFileSync(path.join(candidate, "package.json"), "utf8")).name === "firebase-tools") return path.join(candidate, "lib");
      } catch {}
    }
  }
  throw new Error(`firebase-tools not found next to ${bin}`);
}

async function main() {
  const lib = firebaseToolsLib();
  const account = require(path.join(lib, "auth")).getGlobalDefaultAccount();
  if (!account) throw new Error("Not logged in: run `firebase login` with an owner of " + project);
  await require(path.join(lib, "requireAuth")).requireAuth({ user: account.user, tokens: account.tokens });
  const { Client } = require(path.join(lib, "apiv2"));
  const call = async (origin, method, url, body) => {
    const client = new Client({ urlPrefix: origin, auth: true });
    const reply = await client.request({ method, path: url, body, headers: { "x-goog-user-project": project }, resolveOnHTTPError: true });
    if (reply.status >= 300) throw new Error(`${method} ${url}: ${reply.status} ${JSON.stringify(reply.body).slice(0, 300)}`);
    return reply.body;
  };
  const firebase = (method, url, body) => call("https://firebase.googleapis.com", method, url, body);
  const appCheck = (method, url, body) => call("https://firebaseappcheck.googleapis.com", method, url, body);

  await call("https://serviceusage.googleapis.com", "POST", `/v1/projects/${project}/services/firebaseappcheck.googleapis.com:enable`, {});
  console.log("✔ App Check API on");

  const apps = (await firebase("GET", `/v1beta1/projects/${project}/iosApps`)).apps || [];
  const app = apps.find((candidate) => candidate.bundleId === bundleID);
  if (!app) throw new Error(`No iOS app with bundle ${bundleID} in ${project}`);
  if (app.teamId !== teamID) {
    await firebase("PATCH", `/v1beta1/projects/${project}/iosApps/${app.appId}?updateMask=teamId`, { teamId: teamID });
  }
  console.log(`✔ Team id on the iOS app (${bundleID})`);

  await appCheck("PATCH", `/v1/projects/${project}/apps/${app.appId}/appAttestConfig?updateMask=tokenTtl`, { tokenTtl: "3600s" });
  console.log("✔ App Attest registered (TestFlight and App Store builds)");

  const tokenFile = process.argv[2];
  if (!tokenFile || !fs.existsSync(tokenFile)) {
    console.log("• No debug token file: Debug builds print their own in the Xcode console; register it in Firebase › App Check › Apps › Manage debug tokens.");
    return;
  }
  const token = fs.readFileSync(tokenFile, "utf8").trim();
  const existing = (await appCheck("GET", `/v1/projects/${project}/apps/${app.appId}/debugTokens`)).debugTokens || [];
  if (existing.some((entry) => entry.displayName === "Ultra lab iPhones (Debug)")) {
    console.log("✔ Debug token already registered");
    return;
  }
  await appCheck("POST", `/v1/projects/${project}/apps/${app.appId}/debugTokens`, { displayName: "Ultra lab iPhones (Debug)", token });
  console.log("✔ Debug token registered (the lab's, already on the iPhones)");
}

main().catch((error) => {
  console.error("✖ " + error.message);
  process.exit(1);
});
