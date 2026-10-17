# Jr. Bros — check-in app

Parents check their own kids in. You set the lines. Everyone sees the same thing.

- `index.html` — the page parents use. Check in, and see the benches once you've set them.
- `coach.html` — roster, lines, and money. Passcode protected.

Hosted free on GitHub Pages, with a free Supabase database behind it.

---

## Setup — about 10 minutes, once

### 1. Create the database

1. Go to **supabase.com** and sign up (free, no card).
2. **New project.** Pick any name and region close to you — `Canada (Central)` is a good choice.
   Save the database password it asks you to set; you won't need it for this app, but you'll want it later.
3. Wait for the project to finish building (a minute or two).
4. In the left sidebar: **SQL Editor** → **New query**.
5. Open `supabase-setup.sql` from this repo, copy the whole file, paste it in.
6. **Before running it**, find this line near the top and change the passcode to something only you know:

   ```sql
   insert into settings (key, value) values ('coach_code', 'bros2026')
   ```

7. Click **Run**. It should say success. This creates the tables, loads all 19 players, and locks
   down who can change what.

### 2. Connect the app

1. In Supabase: **Project Settings** (the gear) → **API**.
2. Copy the **Project URL** and the **anon / public** key.
3. Open `config.js` in this repo and paste both in:

   ```js
   SUPABASE_URL:      "https://abcdefgh.supabase.co",
   SUPABASE_ANON_KEY: "eyJhbGciOi...",
   ```

The anon key is *designed* to be public — it's safe in a public repo. Your coach passcode is **not**
in any file here; it lives in the database.

### 3. Put it on GitHub Pages

1. Create a new repository on GitHub.
2. Upload every file in this folder (drag them all into the web uploader — that works fine).
3. **Settings** → **Pages** → Source: **Deploy from a branch**, branch `main`, folder `/ (root)`.
4. Wait a minute. Your site appears at `https://yourname.github.io/reponame/`.

Send parents that link. Keep `https://yourname.github.io/reponame/coach.html` for yourself.

### 4. Put it on your phone

Open the link in Safari or Chrome, then **Add to Home Screen**. It gets the crest as its icon and
opens full screen like an app.

---

## How it works week to week

1. Parents open the link and tap **In** or **Out** next to their child. They can change it any time.
2. You open `coach.html`, enter your passcode, and look at the Check in tab to see who's coming.
3. Go to **Lines**. Only the checked-in skaters show up. Tap the chips to set jersey and position,
   or hit **Shuffle jerseys evenly** for a random split.
4. That's it — the benches appear on the parents' page straight away. Nothing to publish or send.

The page refreshes itself every 20 seconds while it's open, and whenever you switch back to it.

---

## What's protected and what isn't

The public key can read the roster, read and write check-ins, and read the lines. It **cannot**
change the roster, change the lines, mark anyone paid, or read your passcode — those all go through
database functions that check the passcode server-side.

Two things to be realistic about:

- **Anyone with the link can check in any child.** There are no parent logins. For a team where
  everyone knows each other this is usually fine. If someone starts messing with it, tell me and
  I'll add per-family codes.
- **The roster is on a public page.** Full names, as you asked for. `coach.html` carries a `noindex`
  tag, but the parent page is reachable by anyone who has or guesses the URL. If you'd rather it
  weren't indexed by Google, say so and I'll add the tag there too.

---

## Changing things later

| What | Where |
|---|---|
| Add or remove a player | Coach page → Roster |
| Mark someone paid | Coach page → Money |
| Change the per-child fee | Coach page → Money |
| Change the passcode | Supabase → SQL Editor: `update settings set value = 'newcode' where key = 'coach_code';` |
| Change the schedule | `config.js`, the `SESSIONS` list |
| Change team name or ice times | `config.js` |

## The money, for reference

18 sessions × $242.55 = **$4,365.90** for the season.

With 19 skaters that's **$229.78 each** to break even. At $220 you collect $4,180 — **$185.90 short**.
A 20th skater, or $230 each, closes it. The Money tab does this math live as the roster changes.
