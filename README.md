# Swiss Rowing calendar as an iCal feed

Every day, GitHub reads the [Swiss Rowing Eventkalender](https://www.swissrowing.ch/de/eventkalender),
builds `docs/swissrowing.ics` with the R script `build_ics.R`, and publishes it at a fixed URL
that Teamup (or any calendar app) can subscribe to.

## Setup (one time, about 10 minutes, all in the browser)

### 1. Create the repository
- On github.com click **New** (green button) → name it `swissrowing-ics`.
- Choose **Public** (GitHub Pages is free for public repositories).
- Tick **Add a README file** → **Create repository**.

### 2. Upload the R script
- In the repository: **Add file → Upload files**.
- Drag in `build_ics.R` (and this `README.md`, which replaces the default one).
- Click **Commit changes**.

### 3. Add the schedule file
- **Add file → Create new file**.
- As the file name, type exactly: `.github/workflows/update-calendar.yml`
  (the slashes create the folders automatically).
- Paste the contents of `update-calendar.yml` → **Commit changes**.

### 4. Run it once by hand
- Open the **Actions** tab → **Update Swiss Rowing calendar** → **Run workflow** → **Run workflow**.
- After 2–4 minutes it should show a green check, and a `docs` folder with
  `swissrowing.ics` appears in the repository.
- If it shows a red cross, click on the run and open the failed step to see the error.

### 5. Turn on GitHub Pages
- **Settings → Pages**.
- Source: **Deploy from a branch**. Branch: **main**, folder: **/docs** → **Save**.
- After a minute or two the file is online at:

  `https://<your-github-username>.github.io/swissrowing-ics/swissrowing.ics`

  Open that address in the browser to check it.

### 6. Subscribe in Teamup
- In Teamup: **Settings → Calendars → New → iCalendar feed**.
- Paste the URL from step 5. Done.

## How it works
- `build_ics.R` collects all event links on the overview page, opens each event page,
  reads *Event Start*, *Event Ende*, *Ort*, *Veranstalter* and *Kategorie Event*,
  and writes all-day events.
- `.github/workflows/update-calendar.yml` runs the script daily (04:17 UTC) and saves the
  file only when events actually changed.

## Good to know
- The feed contains what Swiss Rowing currently lists, i.e. upcoming events.
  Events that drop off the website also disappear from the feed.
- Teamup refreshes iCal feeds on its own schedule (typically every few hours).
- GitHub pauses scheduled runs if a repository has had no commits for 60 days.
  If that happens, GitHub sends an email; one click on **Enable workflow** in the Actions tab restarts it.
- If Swiss Rowing changes the layout of their website, the script stops with an error
  instead of publishing an empty calendar, and the last good file stays online.
