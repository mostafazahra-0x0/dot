pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia

// Mawaqit prayer-times service for Caelestia.
// Port of the Noctalia `ycf/mawaqit` plugin fetcher (service.luau):
// monthly Aladhan calendar fetch with single-day fallback, disk cache,
// next-prayer countdown, Hijri date, prayer notifications and azan playback.
//
// Configuration lives in ~/.config/caelestia/mawaqit.json (see mawaqit.json.example).
// External edits are picked up by polling (see configPollTimer).
Singleton {
    id: root

    // ── Config (overridden by mawaqit.json) ──────────────────────────────
    property string city: "London"
    property string country: "UK"
    property string method: "3"
    property string school: "0"
    property int hijriDayOffset: 0
    property string fajrAngle: ""
    property string ishaAngle: ""
    property bool twelveHourFormat: false
    property bool showNotifications: true
    property bool playAzan: false
    property string azanPath: ""
    property bool tune: false
    property int tuneFajr: 0
    property int tuneDhuhr: 0
    property int tuneAsr: 0
    property int tuneMaghrib: 0
    property int tuneIsha: 0
    // Font overrides for the card. Empty = follow the Caelestia theme font.
    // arabicFontFamily falls back to fontFamily, then to the theme font.
    property string fontFamily: ""
    property string arabicFontFamily: ""
    // Collapsed header-only mode for the card (frees sidebar space for
    // notifications). Display-only: never triggers a refetch.
    property bool collapsed: false

    // ── State ────────────────────────────────────────────────────────────
    property list<var> prayers: []
    property string sunriseTime: ""
    property string imsakTime: ""
    property string hijriDate: ""
    property string hijriDateAr: ""
    property string gregorianDate: ""
    property int hijriDay: 0
    property int hijriMonth: 0
    property int hijriYear: 0
    property bool isJumuah: false
    property int tomorrowFajr: -1
    property string error: ""
    property bool loading: true
    property bool azanPlaying: false

    // ── Derived countdown state (updated every second) ───────────────────
    property string nextName: ""
    property string nextTime: ""
    property int nextInSec: -1
    property bool nextIsNow: false
    property string currentName: ""
    readonly property string countdown: formatCountdown(nextInSec)

    readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/caelestia/mawaqit.json"
    readonly property string cachePath: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/caelestia/mawaqit-calendar.json"

    property string _loadedDate: ""
    property string _lastNotified: ""
    property string _lastAzanPlayed: ""
    property bool _fetchPending: false
    property int _retryCount: 0
    property int _retryAt: 0
    property bool _tomorrowFetched: false
    // Bumped on every config apply; in-flight fetches that started before a
    // config change discard their result and refetch instead of showing
    // times for the old location.
    property int _gen: 0

    // Noctalia parity: the five daily prayers (Sunrise is display-only).
    readonly property list<string> prayerNames: ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
    readonly property var prayerArabic: ({
        Fajr: "الفجر",
        Dhuhr: "الظهر",
        Jumuah: "الجمعة",
        Asr: "العصر",
        Maghrib: "المغرب",
        Isha: "العشاء"
    })
    readonly property list<int> retryDelays: [5, 10, 15, 30, 60]

    // ── Helpers ──────────────────────────────────────────────────────────
    function todayStr(): string {
        return Qt.formatDate(new Date(), "yyyy-MM-dd");
    }

    function nowSeconds(): int {
        const d = new Date();
        return d.getHours() * 3600 + d.getMinutes() * 60 + d.getSeconds();
    }

    function parseTime(str: string): int {
        if (!str)
            return -1;
        const m = str.match(/(\d+):(\d+)/);
        if (!m)
            return -1;
        return parseInt(m[1], 10) * 3600 + parseInt(m[2], 10) * 60;
    }

    function formatDisplayTime(clean: string): string {
        if (!root.twelveHourFormat)
            return clean;
        const m = clean.match(/(\d+):(\d+)/);
        if (!m)
            return clean;
        const h = parseInt(m[1], 10);
        const period = h < 12 ? "AM" : "PM";
        let dh = h % 12;
        if (dh === 0)
            dh = 12;
        return dh + ":" + m[2] + " " + period;
    }

    function formatAdjustedTime(secs: int): string {
        const tod = ((secs % 86400) + 86400) % 86400;
        const h = Math.floor(tod / 3600);
        const m = Math.floor((tod % 3600) / 60);
        return formatDisplayTime((h < 10 ? "0" + h : "" + h) + ":" + (m < 10 ? "0" + m : "" + m));
    }

    function formatCountdown(secs: int): string {
        if (secs == null || secs < 0)
            return "--:--";
        if (secs <= 60)
            return qsTr("now");
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        const s = secs % 60;
        if (h > 0)
            return h + ":" + (m < 10 ? "0" + m : "" + m) + ":" + (s < 10 ? "0" + s : "" + s);
        return m + ":" + (s < 10 ? "0" + s : "" + s);
    }

    function displayLabel(name: string): string {
        if (name === "Dhuhr" && root.isJumuah)
            return "Jumu'ah";
        return name;
    }

    function applyTune(name: string, secs: int): int {
        if (!root.tune)
            return secs;
        if (name === "Fajr")
            return secs + root.tuneFajr * 60;
        if (name === "Dhuhr")
            return secs + root.tuneDhuhr * 60;
        if (name === "Asr")
            return secs + root.tuneAsr * 60;
        if (name === "Maghrib")
            return secs + root.tuneMaghrib * 60;
        if (name === "Isha")
            return secs + root.tuneIsha * 60;
        return secs;
    }

    function validAngle(v: string): string {
        const a = parseFloat(v);
        if (isFinite(a) && a > 0 && a < 90)
            return String(a);
        return "";
    }

    function dateParam(offsetDays: int): string {
        const d = new Date();
        d.setDate(d.getDate() + offsetDays);
        const dd = d.getDate() < 10 ? "0" + d.getDate() : "" + d.getDate();
        const mm = (d.getMonth() + 1) < 10 ? "0" + (d.getMonth() + 1) : "" + (d.getMonth() + 1);
        return dd + "-" + mm + "-" + d.getFullYear();
    }

    function buildUrl(offsetDays: int): string {
        let url = "https://api.aladhan.com/v1/timingsByCity/" + dateParam(offsetDays) + "?city=" + encodeURIComponent(root.city) + "&country=" + encodeURIComponent(root.country) + "&method=" + root.method + "&school=" + root.school;
        if (root.method === "99") {
            const fa = validAngle(root.fajrAngle);
            const ia = validAngle(root.ishaAngle);
            url += "&methodSettings=" + encodeURIComponent((fa || "null") + ",null," + (ia || "null"));
        }
        return url;
    }

    function buildCalendarUrl(): string {
        const d = new Date();
        const mm = (d.getMonth() + 1) < 10 ? "0" + (d.getMonth() + 1) : "" + (d.getMonth() + 1);
        let url = "https://api.aladhan.com/v1/calendarByCity/" + d.getFullYear() + "/" + mm + "?city=" + encodeURIComponent(root.city) + "&country=" + encodeURIComponent(root.country) + "&method=" + root.method + "&school=" + root.school;
        if (root.method === "99") {
            const fa = validAngle(root.fajrAngle);
            const ia = validAngle(root.ishaAngle);
            url += "&methodSettings=" + encodeURIComponent((fa || "null") + ",null," + (ia || "null"));
        }
        return url;
    }

    function toArabicNumerals(n: int): string {
        const digits = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"];
        return String(n).replace(/\d/g, d => digits[parseInt(d, 10)]);
    }

    // ── Config ───────────────────────────────────────────────────────────
    // Key covering every setting that affects fetched or displayed times.
    function fetchKey(): string {
        return [root.city, root.country, root.method, root.school, validAngle(root.fajrAngle), validAngle(root.ishaAngle), root.hijriDayOffset, root.twelveHourFormat, root.tune, root.tuneFajr, root.tuneDhuhr, root.tuneAsr, root.tuneMaghrib, root.tuneIsha].join("\0");
    }

    // Applies a config object. Returns true when fetch-affecting settings
    // changed (caller should refresh). Bumps the fetch generation so an
    // in-flight request for the old location is discarded and retried.
    function applyConfig(obj: var): bool {
        if (obj == null || typeof obj !== "object")
            return false;
        const oldKey = fetchKey();
        if (typeof obj.city === "string" && obj.city !== "")
            root.city = obj.city;
        if (typeof obj.country === "string" && obj.country !== "")
            root.country = obj.country;
        if (obj.method !== undefined)
            root.method = String(obj.method);
        if (obj.school !== undefined)
            root.school = String(obj.school);
        if (obj.hijriDayOffset !== undefined)
            root.hijriDayOffset = parseInt(obj.hijriDayOffset, 10) || 0;
        // Empty strings mean "unset" for these optional keys (never clobber
        // a live value with one).
        if (typeof obj.fajrAngle === "string" && obj.fajrAngle !== "")
            root.fajrAngle = obj.fajrAngle;
        if (typeof obj.ishaAngle === "string" && obj.ishaAngle !== "")
            root.ishaAngle = obj.ishaAngle;
        if (obj.twelveHourFormat !== undefined)
            root.twelveHourFormat = !!obj.twelveHourFormat;
        if (obj.showNotifications !== undefined)
            root.showNotifications = !!obj.showNotifications;
        if (obj.playAzan !== undefined)
            root.playAzan = !!obj.playAzan;
        if (typeof obj.azanPath === "string" && obj.azanPath !== "")
            root.azanPath = obj.azanPath;
        if (obj.tune !== undefined)
            root.tune = !!obj.tune;
        if (obj.tuneFajr !== undefined)
            root.tuneFajr = parseInt(obj.tuneFajr, 10) || 0;
        if (obj.tuneDhuhr !== undefined)
            root.tuneDhuhr = parseInt(obj.tuneDhuhr, 10) || 0;
        if (obj.tuneAsr !== undefined)
            root.tuneAsr = parseInt(obj.tuneAsr, 10) || 0;
        if (obj.tuneMaghrib !== undefined)
            root.tuneMaghrib = parseInt(obj.tuneMaghrib, 10) || 0;
        if (obj.tuneIsha !== undefined)
            root.tuneIsha = parseInt(obj.tuneIsha, 10) || 0;
        if (typeof obj.fontFamily === "string" && obj.fontFamily !== "")
            root.fontFamily = obj.fontFamily;
        if (typeof obj.arabicFontFamily === "string" && obj.arabicFontFamily !== "")
            root.arabicFontFamily = obj.arabicFontFamily;
        if (obj.collapsed !== undefined)
            root.collapsed = !!obj.collapsed;
        if (fetchKey() !== oldKey) {
            root._gen++;
            return true;
        }
        return false;
    }

    function currentConfig(): var {
        return {
            city: root.city,
            country: root.country,
            method: root.method,
            school: root.school,
            hijriDayOffset: root.hijriDayOffset,
            fajrAngle: root.fajrAngle,
            ishaAngle: root.ishaAngle,
            twelveHourFormat: root.twelveHourFormat,
            showNotifications: root.showNotifications,
            playAzan: root.playAzan,
            azanPath: root.azanPath,
            tune: root.tune,
            tuneFajr: root.tuneFajr,
            tuneDhuhr: root.tuneDhuhr,
            tuneAsr: root.tuneAsr,
            tuneMaghrib: root.tuneMaghrib,
            tuneIsha: root.tuneIsha,
            fontFamily: root.fontFamily,
            arabicFontFamily: root.arabicFontFamily,
            collapsed: root.collapsed
        };
    }

    // Persists current settings (used by the settings UI for write-through
    // edits). The file poller ignores the write since the text is unchanged.
    function saveConfig(): void {
        try {
            const t = JSON.stringify(currentConfig(), null, 4) + "\n";
            root._lastConfigText = t;
            configWriter.setText(t);
        } catch (e) {
            console.warn("[mawaqit] failed to save config: " + e);
        }
    }

    function scheduleSave(): void {
        if (root._suspendSave)
            return;
        saveDebounce.restart();
    }

    // ── Fetch ────────────────────────────────────────────────────────────
    function refresh(): void {
        // A pending fetch plus the generation guard cover this: the
        // in-flight request is discarded and retried with the new config.
        if (root._fetchPending)
            return;
        root._loadedDate = "";
        root._retryCount = 0;
        root._retryAt = 0;
        root._tomorrowFetched = false;
        root.prayers = [];
        fetchTimes(false);
    }

    function scheduleRetry(): void {
        if (root._retryCount >= root.retryDelays.length) {
            console.warn("[mawaqit] retry limit reached");
            return;
        }
        const delay = root.retryDelays[root._retryCount];
        root._retryCount++;
        root._retryAt = Math.floor(Date.now() / 1000) + delay;
        console.log("[mawaqit] retry " + root._retryCount + " in " + delay + "s");
    }

    function processPrayerData(data: var): bool {
        if (!data || data.code !== 200) {
            root.error = "API error: " + (data && data.status ? data.status : "unknown");
            return false;
        }
        let entry = data.data;
        if (entry && entry.timings === undefined) {
            const today = dateParam(0);
            for (const candidate of entry) {
                if (candidate.date && candidate.date.gregorian && candidate.date.gregorian.date === today) {
                    entry = candidate;
                    break;
                }
            }
            if (entry.timings === undefined)
                entry = entry[0];
        }
        const timings = entry && entry.timings;
        if (!timings) {
            root.error = "Parse error: no timings in response";
            return false;
        }

        const list = [];
        for (const name of root.prayerNames) {
            const raw = timings[name];
            if (!raw)
                continue;
            const m = String(raw).match(/(\d+:\d+)/);
            const clean = m ? m[1] : String(raw);
            let secs = parseTime(clean);
            if (secs < 0)
                continue;
            secs = applyTune(name, secs);
            list.push({
                name: name,
                time: formatAdjustedTime(secs),
                seconds: secs
            });
        }

        const imsakRaw = timings["Imsak"];
        const imsakM = imsakRaw ? String(imsakRaw).match(/(\d+:\d+)/) : null;
        const imsakClean = imsakM ? imsakM[1] : "";
        const sunriseRaw = timings["Sunrise"];
        const sunriseM = sunriseRaw ? String(sunriseRaw).match(/(\d+:\d+)/) : null;

        let hDay = 0, hMonth = 0, hYear = 0, hStr = "", hAr = "";
        const hijri = entry.date && entry.date.hijri;
        if (hijri) {
            hDay = Math.max(1, Math.min(30, (parseInt(hijri.day, 10) || 0) + root.hijriDayOffset));
            hMonth = (hijri.month && hijri.month.number) || 0;
            hYear = parseInt(hijri.year, 10) || 0;
            const monthEn = (hijri.month && hijri.month.en) || "";
            const monthAr = (hijri.month && hijri.month.ar) || "";
            hStr = hDay + " " + monthEn + " " + hYear + " AH";
            hAr = toArabicNumerals(hDay) + " " + monthAr + " " + toArabicNumerals(hYear);
        }

        root.prayers = list;
        root.sunriseTime = sunriseM ? formatDisplayTime(sunriseM[1]) : "";
        // Imsak is only relevant during Ramadan (month 9), like the Noctalia plugin.
        root.imsakTime = (hMonth === 9 && imsakClean !== "") ? formatDisplayTime(imsakClean) : "";
        root.hijriDate = hStr;
        root.hijriDateAr = hAr;
        root.gregorianDate = (entry.date && entry.date.readable) || "";
        root.hijriDay = hDay;
        root.hijriMonth = hMonth;
        root.hijriYear = hYear;
        root.isJumuah = new Date().getDay() === 5;
        root.error = "";
        root.loading = false;

        const fetchedDate = todayStr();
        if (root._loadedDate !== fetchedDate) {
            root._lastNotified = "";
            root._lastAzanPlayed = "";
        }
        root._loadedDate = fetchedDate;
        root._retryCount = 0;
        root._retryAt = 0;

        console.log("[mawaqit] loaded " + list.length + " prayers for " + root.city + ", " + root.country);
        updateCountdown();
        return true;
    }

    function fetchTimes(fallback: bool): void {
        if (root._fetchPending)
            return;
        root._fetchPending = true;
        root.loading = true;
        const url = fallback ? buildUrl(0) : buildCalendarUrl();
        const gen = root._gen;
        console.log("[mawaqit] fetching " + url);
        Requests.get(url, text => {
            root._fetchPending = false;
            if (gen !== root._gen) {
                root.fetchTimes(false);
                return;
            }
            let data = null;
            try {
                data = JSON.parse(text);
            } catch (e) {
                console.warn("[mawaqit] parse error: " + e);
            }
            if (!data) {
                handleFetchFailure("Parse error", fallback);
                return;
            }
            if (processPrayerData(data)) {
                if (!fallback)
                    saveCalendarCache(text);
            } else {
                handleFetchFailure("", fallback);
            }
        }, err => {
            root._fetchPending = false;
            if (gen !== root._gen) {
                root.fetchTimes(false);
                return;
            }
            console.warn("[mawaqit] request failed: " + err);
            handleFetchFailure("Network error", fallback);
        });
    }

    function handleFetchFailure(msg: string, fallback: bool): void {
        if (msg !== "")
            root.error = msg;
        if (!fallback) {
            console.log("[mawaqit] calendar request failed, falling back to single-day request");
            fetchTimes(true);
        } else {
            root.loading = false;
            scheduleRetry();
        }
    }

    function fetchTomorrowFajr(): void {
        Requests.get(buildUrl(1), text => {
            let data = null;
            try {
                data = JSON.parse(text);
            } catch (e) {
                return;
            }
            if (!data || data.code !== 200)
                return;
            const timings = data.data && data.data.timings;
            if (!timings || !timings["Fajr"])
                return;
            const m = String(timings["Fajr"]).match(/(\d+:\d+)/);
            if (!m)
                return;
            const secs = applyTune("Fajr", parseTime(m[1]));
            if (secs >= 0)
                root.tomorrowFajr = secs;
        }, () => {});
    }

    // ── Countdown ────────────────────────────────────────────────────────
    function updateCountdown(): void {
        if (root.prayers.length === 0) {
            root.nextName = "";
            root.nextTime = "";
            root.nextInSec = -1;
            root.nextIsNow = false;
            root.currentName = "";
            return;
        }
        const now = nowSeconds();
        let currentIdx = -1;
        for (let i = 0; i < root.prayers.length; i++) {
            if (now >= root.prayers[i].seconds)
                currentIdx = i;
        }
        root.currentName = currentIdx >= 0 ? root.prayers[currentIdx].name : "";

        let nextIdx = -1;
        let toNext = -1;
        if (currentIdx === -1) {
            nextIdx = 0;
            toNext = root.prayers[0].seconds - now;
        } else if (currentIdx === root.prayers.length - 1) {
            if (root.tomorrowFajr >= 0) {
                nextIdx = 0;
                toNext = (86400 - now) + root.tomorrowFajr;
            } else {
                nextIdx = -1;
                toNext = -1;
            }
        } else {
            nextIdx = currentIdx + 1;
            toNext = root.prayers[nextIdx].seconds - now;
        }

        // "now" window: first 5 minutes of a prayer, or <=60s before next.
        const elapsed = currentIdx >= 0 ? now - root.prayers[currentIdx].seconds : -1;
        if (currentIdx >= 0 && elapsed >= 0 && elapsed < 300) {
            root.nextName = root.prayers[currentIdx].name;
            root.nextTime = root.prayers[currentIdx].time;
            root.nextInSec = 0;
            root.nextIsNow = true;
            return;
        }
        if (nextIdx >= 0 && toNext >= 0 && toNext <= 60) {
            root.nextName = root.prayers[nextIdx].name;
            root.nextTime = root.prayers[nextIdx].time;
            root.nextInSec = toNext;
            root.nextIsNow = true;
            return;
        }
        if (nextIdx >= 0) {
            root.nextName = root.prayers[nextIdx].name;
            root.nextTime = root.prayers[nextIdx].time;
            root.nextInSec = toNext;
            root.nextIsNow = false;
        } else {
            root.nextName = "";
            root.nextTime = "";
            root.nextInSec = -1;
            root.nextIsNow = false;
        }
    }

    function checkPrayerEvents(): void {
        if (root.prayers.length === 0)
            return;
        const now = nowSeconds();
        for (const p of root.prayers) {
            if (now >= p.seconds && now < p.seconds + 30) {
                const key = todayStr() + "_" + p.name;
                const title = displayLabel(p.name);
                if (root.showNotifications && root._lastNotified !== key) {
                    root._lastNotified = key;
                    const ar = root.prayerArabic[p.name] || title;
                    Toaster.toast(title + " — " + p.time, "حان الآن موعد صلاة " + ar, "mosque");
                }
                if (root.playAzan && root._lastAzanPlayed !== key) {
                    root._lastAzanPlayed = key;
                    startAzan();
                }
            }
        }
    }

    // ── Azan playback (paplay or pw-cat, like the Noctalia plugin) ──────
    function resolvedAzanPath(): string {
        if (root.azanPath !== "")
            return root.azanPath.replace(/^~(?=\/|$)/, Quickshell.env("HOME"));
        return Quickshell.env("HOME") + "/.config/caelestia/mawaqit-azan.mp3";
    }

    function startAzan(): void {
        if (root.azanPlaying)
            return;
        const path = resolvedAzanPath();
        root.azanPlaying = true;
        // Try paplay first, fall back to pw-cat. Quickshell.execDetached
        // does not report missing binaries, so chain them in one shell line.
        Quickshell.execDetached(["sh", "-c", "paplay " + quoted(path) + " 2>/dev/null || pw-cat -p " + quoted(path) + " 2>/dev/null"]);
        // Best-effort reset: longest azan tracks are ~5 min.
        azanResetTimer.restart();
    }

    function quoted(s: string): string {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function stopAzan(): void {
        root.azanPlaying = false;
        azanResetTimer.stop();
        Quickshell.execDetached(["sh", "-c", "pkill -f 'paplay.*" + resolvedAzanPath().replace(/([.*+?()[\]^$|\\{}])/g, "\\$1") + "' 2>/dev/null; pkill -f 'pw-cat.*" + resolvedAzanPath().replace(/([.*+?()[\]^$|\\{}])/g, "\\$1") + "' 2>/dev/null || true"]);
    }

    function previewAzan(): void {
        root.azanPlaying = false;
        startAzan();
    }

    // ── Wiring ───────────────────────────────────────────────────────────
    // Fetch-affecting keys refetch (debounced); every persisted key
    // schedules a config write so UI edits are saved to mawaqit.json.
    onCityChanged: {
        refreshDebounced();
        scheduleSave();
    }
    onCountryChanged: {
        refreshDebounced();
        scheduleSave();
    }
    onMethodChanged: {
        refreshDebounced();
        scheduleSave();
    }
    onSchoolChanged: {
        refreshDebounced();
        scheduleSave();
    }
    onHijriDayOffsetChanged: {
        refreshDebounced();
        scheduleSave();
    }
    onFajrAngleChanged: {
        refreshDebounced();
        scheduleSave();
    }
    onIshaAngleChanged: {
        refreshDebounced();
        scheduleSave();
    }
    onTwelveHourFormatChanged: {
        refreshDebounced();
        scheduleSave();
    }
    onTuneChanged: {
        refreshDebounced();
        scheduleSave();
    }
    onTuneFajrChanged: {
        refreshDebounced();
        scheduleSave();
    }
    onTuneDhuhrChanged: {
        refreshDebounced();
        scheduleSave();
    }
    onTuneAsrChanged: {
        refreshDebounced();
        scheduleSave();
    }
    onTuneMaghribChanged: {
        refreshDebounced();
        scheduleSave();
    }
    onTuneIshaChanged: {
        refreshDebounced();
        scheduleSave();
    }
    onShowNotificationsChanged: scheduleSave()
    onPlayAzanChanged: scheduleSave()
    onAzanPathChanged: scheduleSave()
    onFontFamilyChanged: scheduleSave()
    onArabicFontFamilyChanged: scheduleSave()
    onCollapsedChanged: scheduleSave()

    function refreshDebounced(): void {
        refreshDebounce.restart();
    }

    Timer {
        id: refreshDebounce
        interval: 800
        onTriggered: root.refresh()
    }

    Timer {
        id: tick
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.updateCountdown();
            root.checkPrayerEvents();
            const today = root.todayStr();
            if (root._loadedDate !== today) {
                root._tomorrowFetched = false;
                root.fetchTimes(false);
            } else if (!root._tomorrowFetched) {
                root._tomorrowFetched = true;
                root.fetchTomorrowFajr();
            }
            if (root._retryAt > 0 && Math.floor(Date.now() / 1000) >= root._retryAt) {
                root._retryAt = 0;
                root.fetchTimes(false);
            }
        }
    }

    Timer {
        id: azanResetTimer
        interval: 360000
        onTriggered: root.azanPlaying = false
    }

    property string _lastConfigText: ""
    property bool _suspendSave: false

    Timer {
        id: saveDebounce
        interval: 2000
        onTriggered: root.saveConfig()
    }

    FileView {
        id: configWriter
        path: root.configPath
        printErrors: false
    }

    function loadConfigText(t: string): void {
        // Ignore our own writes (poll compares text, loader checks here).
        if (t === root._lastConfigText && root._lastConfigText !== "")
            return;
        root._lastConfigText = t;
        root._suspendSave = true;
        let changed = false;
        try {
            changed = root.applyConfig(JSON.parse(t));
        } catch (e) {
            console.warn("[mawaqit] invalid config json: " + e);
        }
        root._suspendSave = false;
        // Re-fetch only when fetch-affecting settings changed.
        if (changed)
            root.refresh();
    }

    FileView {
        id: configFile
        path: root.configPath
        printErrors: false
        onLoaded: root.loadConfigText(text())
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                console.log("[mawaqit] no config file, using defaults (city=" + root.city + ")");
            } else {
                console.warn("[mawaqit] config load failed: " + err);
            }
        }
    }

    // The QML FileView wrapper does not expose file watching, so poll the
    // config for external edits (hot-reload without a shell restart).
    Process {
        id: configPollProc
        command: ["cat", root.configPath]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text !== root._lastConfigText)
                    root.loadConfigText(text);
            }
        }
    }

    Timer {
        id: configPollTimer
        interval: 30000
        running: true
        repeat: true
        onTriggered: configPollProc.running = true
    }

    // ── Disk cache (same-month + same-location only) ───────────────────
    function cacheKey(): string {
        const d = new Date();
        return [root.city, root.country, root.method, root.school, validAngle(root.fajrAngle), validAngle(root.ishaAngle), d.getFullYear(), d.getMonth() + 1].join("\0");
    }

    function saveCalendarCache(rawText: string): void {
        try {
            cacheStorage.setText(JSON.stringify({
                version: 1,
                key: cacheKey(),
                calendar: JSON.parse(rawText)
            }));
        } catch (e) {
            console.warn("[mawaqit] failed to write calendar cache: " + e);
        }
    }

    FileView {
        id: cacheStorage
        path: root.cachePath
        printErrors: false
        onLoaded: {
            try {
                const cached = JSON.parse(text());
                if (cached && cached.version === 1 && cached.key === cacheKey() && cached.calendar) {
                    if (root.processPrayerData(cached.calendar))
                        console.log("[mawaqit] loaded prayer times from disk cache");
                } else if (cached && cached.code === 200 && cached.data) {
                    // Legacy unwrapped cache: only trust it if it holds today.
                    const arr = cached.data;
                    if (Array.isArray(arr) && arr.some(e => e.date && e.date.gregorian && e.date.gregorian.date === dateParam(0))) {
                        if (root.processPrayerData(cached))
                            console.log("[mawaqit] loaded prayer times from legacy disk cache");
                    }
                }
            } catch (e) {
                console.warn("[mawaqit] invalid cache: " + e);
            }
        }
        onLoadFailed: () => {}
    }

    Component.onCompleted: {
        console.log("[mawaqit] city=" + root.city + " country=" + root.country + " method=" + root.method);
        root.fetchTimes(false);
    }
}
