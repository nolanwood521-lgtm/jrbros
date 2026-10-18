/* ============================================================
   Jr. Bros — shared helpers for index.html and coach.html
   ============================================================ */
(function(){
"use strict";

var C = window.JRBROS || {};
var API = (C.SUPABASE_URL || "").replace(/\/+$/, "") + "/rest/v1";

var JB = window.JB = {};

JB.config = C;
JB.configured = function(){
  return /^https:\/\/.+\.supabase\.co$/.test(C.SUPABASE_URL || "") &&
         (C.SUPABASE_ANON_KEY || "").length > 20;
};

function headers(extra){
  var h = {
    "apikey": C.SUPABASE_ANON_KEY,
    "Authorization": "Bearer " + C.SUPABASE_ANON_KEY,
    "Content-Type": "application/json"
  };
  for(var k in (extra || {})) h[k] = extra[k];
  return h;
}

/* GET rows from a table. `qs` is a PostgREST query string. */
JB.select = function(table, qs){
  return fetch(API + "/" + table + "?" + (qs || "select=*"), { headers: headers() })
    .then(function(r){
      if(!r.ok) return r.text().then(function(t){ throw new Error(t || r.status); });
      return r.json();
    });
};

/* Insert-or-update a check-in. Used by parents; no passcode needed. */
JB.upsertCheckin = function(session, playerId, status){
  return fetch(API + "/checkins", {
    method: "POST",
    headers: headers({ "Prefer": "resolution=merge-duplicates,return=minimal" }),
    body: JSON.stringify({
      session: session, player_id: playerId, status: status,
      updated_at: new Date().toISOString()
    })
  }).then(function(r){
    if(!r.ok) return r.text().then(function(t){ throw new Error(t || r.status); });
  });
};

/* Clear a check-in, putting the child back to "not answered". */
JB.clearCheckin = function(session, playerId){
  return fetch(API + "/checkins?session=eq." + encodeURIComponent(session) +
                      "&player_id=eq." + encodeURIComponent(playerId), {
    method: "DELETE",
    headers: headers({ "Prefer": "return=minimal" })
  }).then(function(r){
    if(!r.ok) return r.text().then(function(t){ throw new Error(t || r.status); });
  });
};

/* Call a coach function. The passcode is checked inside the database. */
JB.rpc = function(fn, args){
  return fetch(API + "/rpc/" + fn, {
    method: "POST", headers: headers(), body: JSON.stringify(args || {})
  }).then(function(r){
    return r.text().then(function(t){
      if(!r.ok) throw new Error(t || ("HTTP " + r.status));
      try{ return t ? JSON.parse(t) : null; }catch(e){ return t; }
    });
  });
};

/* ---------- dates ---------- */

JB.todayISO = function(){
  var d = new Date(), m = d.getMonth() + 1, day = d.getDate();
  return d.getFullYear() + "-" + (m < 10 ? "0" : "") + m + "-" + (day < 10 ? "0" : "") + day;
};
JB.fmt = function(iso, long){
  var p = String(iso).split("-");
  var d = new Date(+p[0], +p[1] - 1, +p[2]);
  return d.toLocaleDateString("en-CA", long
    ? { weekday:"long", month:"long", day:"numeric" }
    : { weekday:"short", month:"short", day:"numeric" });
};
JB.nextSession = function(){
  var t = JB.todayISO(), s = C.SESSIONS || [];
  for(var i = 0; i < s.length; i++){ if(s[i] >= t) return s[i]; }
  return null;
};
JB.money = function(n){
  return "$" + Number(n).toLocaleString("en-CA",{minimumFractionDigits:2,maximumFractionDigits:2});
};
JB.money0 = function(n){ return "$" + Math.round(n).toLocaleString("en-CA"); };

JB.el = function(id){ return document.getElementById(id); };

/* ---------- shared chrome ---------- */

JB.header = function(kicker, title){
  return '<header>' +
      '<div class="crest" role="img" aria-label="Jr. Bros crest"></div>' +
      '<div class="brandtext">' +
        '<div class="kicker">' + kicker + '</div>' +
        '<h1>' + title + '</h1>' +
      '</div>' +
    '</header>';
};

JB.setupBanner = function(){
  return '<div class="banner"><b>Not connected yet.</b> Open <code>config.js</code> and paste in ' +
    'your Supabase project URL and anon key. Until then nothing can be saved or shared. ' +
    'See <code>README.md</code> for the five-minute setup.</div>';
};

/* Friendly wording for the errors that actually come up. */
JB.explain = function(err){
  var m = String(err && err.message || err || "");
  if(/bad passcode/i.test(m)) return "That passcode wasn't right.";
  if(/Failed to fetch|NetworkError|load failed/i.test(m))
    return "Couldn't reach the database — check your connection.";
  if(/JWT|apikey|401|403/i.test(m)) return "The anon key in config.js looks wrong.";
  if(/does not exist|42P01|PGRST205/i.test(m))
    return "Tables are missing — run supabase-setup.sql in Supabase first.";
  return m.slice(0, 160) || "Something went wrong.";
};

})();
