import Papa from 'https://cdn.jsdelivr.net/npm/papaparse@5.4.1/+esm';

// Indian swara mapping to semitone index
// 1 = Sa (Middle C = 60), 2 = Komal Re, 3 = Shuddh Re, etc.
const NOTE_MAP_INDIAN = {
    's': 1, 'R': 2, 'r': 3, 'G': 4, 'g': 5, 'm': 6, 'M': 7,
    'p': 8, 'D': 9, 'd': 10, 'N': 11, 'n': 12
};

/**
 * Calculates MIDI key for an Indian musical note.
 * Sa (s) of octave 0 is mapped to 60 (Middle C).
 * Octaves: Taar saptak (') = +1 (+12 semitones), Mandra saptak (.) = -1 (-12 semitones).
 */
export function keyIndian(note, octave = 0, offset = 0) {
    const val = NOTE_MAP_INDIAN[note];
    if (val === undefined) return null;
    return 60 + (val - 1) + 12 * octave + offset;
}

/**
 * Processes a single row in the notation (notes separated by '+'),
 * generating note events with keys, timing, slur, and meed flags.
 */
function note2events(notes, start, slur1, lyrics, meed, NOTE_DURATION) {
    const touchNotes = notes.map(n => n.startsWith('^'));
    const n = touchNotes.filter(t => !t).length; // exclude sparsha notes from count
    if (n === 0) return null; // empty

    const octaves = [];
    const cleanNotes = [];
    const keys = [];

    for (let i = 0; i < notes.length; i++) {
        const noteStr = notes[i];
        // octave: ends with ' is +1, ends with . is -1
        const oct = (noteStr.endsWith("'") ? 1 : 0) - (noteStr.endsWith(".") ? 1 : 0);
        octaves.push(oct);
        const clean = noteStr.replace(/['^\.]/g, '');
        cleanNotes.push(clean);

        if (noteStr === '-') {
            keys.push(-1); // special case: continue previous note (tie)
        } else {
            const k = keyIndian(clean, oct);
            if (k === null) return null; // not a valid note
            keys.push(k);
        }
    }

    const touchKeys = keys.filter((_, i) => touchNotes[i]);
    const mainKeys = keys.filter((_, i) => !touchNotes[i]);

    // Duration of individual notes; should add up to NOTE_DURATION
    const step = NOTE_DURATION / n;
    const dstart = [];
    const dstop = [];
    for (let i = 0; i < n; i++) {
        dstart.push(start + i * step);
        dstop.push(start + (i + 1) * step);
    }

    // slur1 indicates initial slur/tie. Add further slurs based on lyrics
    let wslur;
    if (lyrics.length === n) {
        wslur = lyrics.map(l => l === '৹');
        wslur[0] = Boolean(wslur[0] || slur1);
    } else {
        wslur = Array(n).fill(Boolean(slur1));
    }

    let resKeys = [...mainKeys];
    let resDstart = [...dstart];
    let resDstop = [...dstop];
    let resWslur = [...wslur];
    let resMeed;

    const anyTouch = touchNotes.some(Boolean);
    const isActiveMeed = (meed === 1 || meed === true);

    if (anyTouch) {
        // Sparsha note: allocate 1/4 duration
        if (touchNotes[0]) {
            // First position touch note
            resDstart[0] += NOTE_DURATION / 4;
            resDstart.unshift(start);
            resDstop.unshift(start + NOTE_DURATION / 4);
            resKeys.unshift(touchKeys[0]);
            resWslur.unshift(Boolean(slur1));
            const meedVec = [true, ...Array(n).fill(false)];
            resMeed = meedVec.map(m => Boolean(m || (meed !== 0)));
        } else {
            // Last position touch note
            resDstop[n - 1] -= NOTE_DURATION / 4;
            const touchStart = resDstop[n - 1];
            const touchStop = touchStart + NOTE_DURATION / 4;
            resDstart.push(touchStart);
            resDstop.push(touchStop);
            resKeys.push(touchKeys[0]);
            resWslur.push(true);
            const meedVec = [...Array(n - 1).fill(false), true, false];
            resMeed = meedVec.map(m => Boolean(m || (meed !== 0)));
        }
    } else {
        resMeed = Array(n).fill(isActiveMeed);
    }

    const rows = [];
    for (let i = 0; i < resKeys.length; i++) {
        rows.push({
            keys: resKeys[i],
            dstart: resDstart[i],
            dstop: resDstop[i],
            slur: resWslur[i],
            meed: resMeed[i] ? 1 : 0
        });
    }
    return rows;
}

/**
 * Converts notation CSV rows into note events with key numbers.
 * Replicates notation2keys from generate-freq-csv.R.
 */
export function notation2keys(notationRows, NOTE_DURATION = 60) {
    let inmeed = 0;
    let currStart = 0;
    const annotated = [];

    for (let i = 0; i < notationRows.length; i++) {
        const row = notationRows[i];
        const meedStr = row.meed || '';
        if (meedStr === 'BEGIN') inmeed++;
        else if (meedStr === 'END') inmeed--;

        const noteCountVal = parseInt(row.noteCount, 10);
        if (!isNaN(noteCountVal) && noteCountVal > 0) {
            currStart += NOTE_DURATION;
        }

        const noteStr = (row.note !== undefined && row.note !== null ? String(row.note) : '').trim();
        const slur1 = (noteStr !== '-') && noteStr.startsWith('-');
        const cleanNote = slur1 ? noteStr.replace(/-/g, '') : noteStr;

        annotated.push({
            note: cleanNote,
            words: (row.words !== undefined && row.words !== null) ? String(row.words) : '',
            start: currStart,
            slur1: slur1,
            inmeed: inmeed
        });
    }

    const allEvents = [];
    for (let i = 0; i < annotated.length; i++) {
        const ann = annotated[i];
        if (!ann.note) continue;
        const notes = ann.note.split('+');
        const trimmedWords = ann.words.trim();
        const lyrics = trimmedWords ? trimmedWords.split(' ') : [];
        const evs = note2events(notes, ann.start, ann.slur1, lyrics, ann.inmeed, NOTE_DURATION);
        if (evs) {
            allEvents.push(...evs);
        }
    }

    if (allEvents.length === 0) return [];

    // fillByPrev: continue previous note key when key is -1
    for (let i = 0; i < allEvents.length; i++) {
        if (allEvents[i].keys < 0) {
            if (i > 0) {
                allEvents[i].keys = allEvents[i - 1].keys;
            }
        }
    }

    const ans = [];
    for (let i = 0; i < allEvents.length; i++) {
        const ev = allEvents[i];
        ans.push({
            tstart: ev.dstart,
            tend: ev.dstop,
            kstart: ev.keys,
            kend: ev.keys,
            newnote: ev.slur ? 0 : 1,
            meed: ev.meed
        });
    }

    // meed adjustment: kend of current note becomes kstart of next note
    if (ans.length > 0 && ans[ans.length - 1].meed === 1) {
        ans[ans.length - 1].meed = 0;
    }

    for (let i = 0; i < ans.length - 1; i++) {
        if (ans[i].meed === 1) {
            ans[i].kend = ans[i + 1].kstart;
        }
    }

    for (let i = 0; i < ans.length; i++) {
        delete ans[i].meed;
    }
    return ans;
}

/**
 * Converts key events to frequency-duration events, including continuous
 * pitch ramp transitions for slurs. Replicates notation2freq from generate-freq-csv.R.
 */
export function keys2freq(keyRows, options = {}) {
    if (!keyRows || keyRows.length === 0) return [];

    const AFREQ = options.AFREQ ?? 440; // frequency of A=57
    const L = options.L ?? 0.4;         // tempo: duration in seconds of one note
    const A = options.A ?? (0.025 * L); // slur ascent duration
    const digits = options.digits ?? 2; // rounding for frequencies

    let tmin = Infinity;
    for (let i = 0; i < keyRows.length; i++) {
        if (keyRows[i].tstart < tmin) tmin = keyRows[i].tstart;
    }

    const freqs = [];
    for (let i = 0; i < keyRows.length; i++) {
        const r = keyRows[i];
        const ts = L * (r.tstart - tmin) / 60;
        const te = L * (r.tend - tmin) / 60;
        const fs = AFREQ * Math.pow(2, (r.kstart - 57) / 12);
        const fe = AFREQ * Math.pow(2, (r.kend - 57) / 12);

        freqs.push({
            tstart: parseFloat(ts.toFixed(6)),
            tend: parseFloat(te.toFixed(6)),
            fstart: parseFloat(fs.toFixed(digits)),
            fend: parseFloat(fe.toFixed(digits)),
            newnote: r.newnote
        });
    }

    // Continuous slur transitions: insert linear frequency ramp before rows with newnote === 0
    const newSegments = [];
    for (let i = 1; i < freqs.length; i++) {
        if (freqs[i].newnote === 0) {
            const segTs = parseFloat((freqs[i].tstart - 3 * A).toFixed(6));
            const segTe = parseFloat(freqs[i].tstart.toFixed(6));
            const segFs = freqs[i - 1].fend;
            const segFe = freqs[i].fstart;

            newSegments.push({
                tstart: segTs,
                tend: segTe,
                fstart: segFs,
                fend: segFe,
                newnote: 0
            });

            freqs[i - 1].tend = parseFloat((freqs[i - 1].tend - 3 * A).toFixed(6));
        }
    }

    const combined = [...freqs, ...newSegments];
    combined.sort((a, b) => a.tstart - b.tstart);
    return combined;
}

/**
 * Directly converts parsed notation rows to frequency-duration events.
 */
export function notation2freq(notationRows, options = {}) {
    const NOTE_DURATION = options.NOTE_DURATION ?? 60;
    const keys = notation2keys(notationRows, NOTE_DURATION);
    return keys2freq(keys, options);
}

/**
 * Extracts timestamped lyrics from notation rows based on note timing.
 * Returns an array of tokens: [{ tstart, tend, text }]
 */
export function extractTimedLyrics(notationRows, options = {}) {
    const NOTE_DURATION = options.NOTE_DURATION ?? 60;
    const L = options.L ?? 0.4;
    let currStart = 0;
    let tmin = null;
    const rawTokens = [];

    for (let i = 0; i < notationRows.length; i++) {
        const row = notationRows[i];
        const noteCountVal = parseInt(row.noteCount, 10);
        if (!isNaN(noteCountVal) && noteCountVal > 0) {
            currStart += NOTE_DURATION;
        }

        const noteStr = (row.note !== undefined && row.note !== null ? String(row.note) : '').trim();
        if (!noteStr || noteStr === '|' || noteStr.startsWith('⌶')) continue;

        if (tmin === null) {
            tmin = currStart;
        }

        const wordsStr = (row.words !== undefined && row.words !== null) ? String(row.words).trim() : '';
        if (!wordsStr) continue;

        const cleanNote = (noteStr !== '-' && noteStr.startsWith('-')) ? noteStr.replace(/-/g, '') : noteStr;
        const notes = cleanNote.split('+');
        const touchNotes = notes.map(n => n.startsWith('^'));
        const n = touchNotes.filter(t => !t).length || 1;
        const step = NOTE_DURATION / n;

        const words = wordsStr.split(/\s+/);
        if (words.length === n) {
            for (let j = 0; j < n; j++) {
                rawTokens.push({
                    dstart: currStart + j * step,
                    dstop: currStart + (j + 1) * step,
                    text: words[j]
                });
            }
        } else {
            rawTokens.push({
                dstart: currStart,
                dstop: currStart + NOTE_DURATION,
                text: wordsStr
            });
        }
    }

    if (tmin === null) tmin = 0;

    return rawTokens.map(tok => ({
        tstart: parseFloat((L * (tok.dstart - tmin) / 60).toFixed(3)),
        tend: parseFloat((L * (tok.dstop - tmin) / 60).toFixed(3)),
        text: tok.text
    }));
}


// --- Audio playback, Seeking & Lyrics Window Engine ---

let audioCtx = null;
let current_csv_loc = null;
let current_instrument = 'guitar';
let current_options = {};
let current_parsed_data = null;     // frequency-duration rows
let current_timed_lyrics = [];      // [{ tstart, tend, text }]
let current_total_duration = 0;     // seconds
let current_seek_offset = 0;        // seconds
let playback_start_time = 0;        // audioCtx.currentTime when oscillator started
let update_timer_id = null;
let current_osc = null;
let current_master_gain = null;
let playback_callback = null;

/**
 * Register a callback to receive real-time playback updates.
 * Callback signature: fn({ currentTime, totalDuration, state, lyricsWindow })
 */
export function set_playback_callback(callback) {
    playback_callback = callback;
}

export function get_current_time() {
    if (!audioCtx || audioCtx.state !== 'running' || !current_osc) {
        return current_seek_offset;
    }
    const elapsed = audioCtx.currentTime - playback_start_time;
    return Math.min(current_total_duration, current_seek_offset + elapsed);
}

export function get_total_duration() {
    return current_total_duration;
}

export function get_timed_lyrics() {
    return current_timed_lyrics;
}

/**
 * Returns lyrics tokens within a window around currentTime.
 * Default window: 3.5 seconds before, 4.5 seconds after.
 */
export function get_lyrics_window(currentTime, preSeconds = 3.5, postSeconds = 4.5) {
    if (!current_timed_lyrics || current_timed_lyrics.length === 0) return [];

    const windowStart = currentTime - preSeconds;
    const windowEnd = currentTime + postSeconds;

    return current_timed_lyrics
        .filter(t => t.tend >= windowStart && t.tstart <= windowEnd)
        .map(t => {
            const isCurrent = (currentTime >= t.tstart && currentTime < t.tend);
            const isPast = (t.tend <= currentTime);
            const isElongation = (t.text === '৹');
            return {
                text: t.text,
                display: t.text,
                tstart: t.tstart,
                tend: t.tend,
                isCurrent,
                isPast,
                isFuture: !isCurrent && !isPast,
                isElongation
            };
        });
}

function notify_callback(state) {
    if (!playback_callback) return;
    const curTime = get_current_time();
    playback_callback({
        currentTime: curTime,
        totalDuration: current_total_duration,
        state: state,
        lyricsWindow: get_lyrics_window(curTime)
    });
}

function stop_active_oscillator() {
    if (update_timer_id) {
        clearInterval(update_timer_id);
        update_timer_id = null;
    }
    if (current_osc) {
        try {
            current_osc.onended = null;
            current_osc.stop();
        } catch (e) {}
        current_osc = null;
    }
}

/**
 * Slices note events from targetTime onward, shifting timings so they schedule relative to targetTime.
 */
function slice_notes_for_seek(data, targetTime) {
    const scheduled = [];
    for (let i = 0; i < data.length; i++) {
        const row = data[i];
        if (row.tend <= targetTime) continue;

        let fstart = row.fstart;
        let fend = row.fend;
        let tstart = row.tstart;
        let tend = row.tend;
        let newnote = row.newnote;

        if (tstart < targetTime) {
            // Note straddles seek point: interpolate frequency and clamp start
            const duration = tend - tstart;
            if (duration > 0) {
                const fraction = (targetTime - tstart) / duration;
                fstart = fstart + fraction * (fend - fstart);
            }
            tstart = targetTime;
            newnote = 1; // start immediate attack for straddling note
        }

        const scheduledTstart = tstart - targetTime;
        const scheduledTend = tend - targetTime;

        scheduled.push({
            scheduledTstart,
            scheduledTend,
            fstart,
            fend,
            newnote
        });
    }
    return scheduled;
}

/**
 * Starts oscillator playback from offsetTime.
 */
async function start_oscillator_at(offsetTime, instrument = current_instrument) {
    stop_active_oscillator();

    if (!audioCtx || audioCtx.state === 'closed') {
        audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (audioCtx.state === 'suspended') {
        await audioCtx.resume();
    }

    if (!current_parsed_data || current_parsed_data.length === 0) return;

    const notesToSchedule = slice_notes_for_seek(current_parsed_data, offsetTime);
    if (notesToSchedule.length === 0) {
        current_seek_offset = 0;
        notify_callback('stopped');
        return;
    }

    const startTime = audioCtx.currentTime + 0.05; // 50ms buffer to prevent audio glitch
    playback_start_time = audioCtx.currentTime;
    current_seek_offset = offsetTime;

    const masterGain = audioCtx.createGain();
    masterGain.connect(audioCtx.destination);
    masterGain.gain.value = 0.5;
    current_master_gain = masterGain;

    let type = 'triangle';
    if (instrument === 'flute') type = 'sine';
    if (instrument === 'guitar') type = 'triangle';
    if (instrument === 'violin') type = 'sawtooth';
    if (instrument === 'vocal') type = 'square';

    const osc = audioCtx.createOscillator();
    osc.type = type;

    const envelope = audioCtx.createGain();
    envelope.gain.value = 0;

    osc.connect(envelope);
    envelope.connect(masterGain);

    osc.start(startTime);
    current_osc = osc;

    let lastTime = startTime;

    notesToSchedule.forEach((row, index) => {
        const absoluteTstart = startTime + row.scheduledTstart;
        const absoluteTend = startTime + row.scheduledTend;

        // Frequency scheduling
        if (absoluteTend > absoluteTstart) {
            osc.frequency.setValueAtTime(row.fstart, absoluteTstart);
            osc.frequency.linearRampToValueAtTime(row.fend, absoluteTend);
        } else {
            osc.frequency.setValueAtTime(row.fend, absoluteTend);
        }

        // Amplitude scheduling
        if (row.newnote === 1) {
            envelope.gain.setValueAtTime(0, absoluteTstart);
            envelope.gain.linearRampToValueAtTime(1, absoluteTstart + 0.05); // 50ms attack
        } else if (index === 0) {
            envelope.gain.setValueAtTime(1, absoluteTstart);
        }

        // Release scheduling
        const isLast = index === notesToSchedule.length - 1;
        let release = false;

        if (isLast) {
            release = true;
        } else {
            const nextRow = notesToSchedule[index + 1];
            if (nextRow.newnote === 1) {
                release = true;
            } else if (nextRow.scheduledTstart > row.scheduledTend + 0.001) {
                release = true;
            }
        }

        if (release) {
            const releaseStart = Math.max(absoluteTstart + 0.05, absoluteTend - 0.05);
            if (releaseStart < absoluteTend) {
                envelope.gain.setValueAtTime(1, releaseStart);
                envelope.gain.linearRampToValueAtTime(0, absoluteTend);
            }
        }

        lastTime = Math.max(lastTime, absoluteTend);
    });

    osc.onended = () => {
        stop_active_oscillator();
        current_seek_offset = 0;
        notify_callback('ended');
    };

    osc.stop(lastTime + 0.1);

    // Start UI update interval (every 50ms)
    update_timer_id = setInterval(() => {
        const cur = get_current_time();
        if (cur >= current_total_duration) {
            stop_active_oscillator();
            current_seek_offset = 0;
            notify_callback('ended');
        } else {
            notify_callback('running');
        }
    }, 50);

    notify_callback('running');
}

/**
 * Loads CSV (if not already loaded) and starts playback from options.seekTime or 0.
 */
export async function play_audio(loc, instrument = 'guitar', options = {}) {
    let targetLoc = loc;
    if (typeof targetLoc === 'string') {
        if (!targetLoc.includes('/') && !targetLoc.endsWith('.csv')) {
            targetLoc = `./notation/${targetLoc}.csv`;
        }
        targetLoc = targetLoc.replace(/\/(freqmap|frequency-duration)\//, '/notation/');
    }

    current_instrument = instrument;
    current_options = options;

    // Fetch and parse CSV if new location or not yet loaded
    if (targetLoc !== current_csv_loc || !current_parsed_data) {
        stop_active_oscillator();

        const response = await fetch(targetLoc, { cache: "no-store" });
        if (!response.ok) {
            console.error(`Failed to fetch file from ${targetLoc}: ${response.statusText}`);
            return;
        }
        const csvText = await response.text();

        const parsed = Papa.parse(csvText, {
            header: true,
            dynamicTyping: true,
            skipEmptyLines: true
        });

        let data = parsed.data;
        if (!data || data.length === 0) return;

        if (data[0] && (data[0].note !== undefined || data[0].onote !== undefined)) {
            current_parsed_data = notation2freq(data, options);
            current_timed_lyrics = extractTimedLyrics(data, options);
        } else {
            current_parsed_data = data;
            current_timed_lyrics = [];
        }

        current_csv_loc = targetLoc;
        current_total_duration = current_parsed_data.length > 0 ? current_parsed_data[current_parsed_data.length - 1].tend : 0;
        current_seek_offset = 0;
    }

    const startFrom = (options.seekTime !== undefined) ? options.seekTime : current_seek_offset;
    await start_oscillator_at(startFrom, instrument);
}

/**
 * Pauses playback while retaining the current position.
 */
export function pause_audio() {
    if (!audioCtx) return;
    const curTime = get_current_time();
    current_seek_offset = curTime;
    stop_active_oscillator();
    if (audioCtx.state === 'running') {
        audioCtx.suspend();
    }
    notify_callback('suspended');
}

/**
 * Resumes playback from the current position.
 */
export async function resume_audio() {
    if (!current_parsed_data || current_parsed_data.length === 0) {
        if (current_csv_loc) {
            await play_audio(current_csv_loc, current_instrument, current_options);
        }
        return;
    }
    await start_oscillator_at(current_seek_offset, current_instrument);
}

/**
 * Seeks playback to a specific timestamp in seconds.
 */
export async function seek_audio(targetTime) {
    if (!current_parsed_data || current_parsed_data.length === 0) return;
    targetTime = Math.max(0, Math.min(targetTime, current_total_duration));
    current_seek_offset = targetTime;

    const isRunning = (audioCtx && audioCtx.state === 'running' && current_osc);
    if (isRunning) {
        await start_oscillator_at(targetTime, current_instrument);
    } else {
        notify_callback((audioCtx && audioCtx.state === 'suspended') ? 'suspended' : 'stopped');
    }
}

/**
 * Toggles playback between play, pause, and resume.
 */
export async function toggle_audio(loc, instrument = 'guitar', options = {}) {
    if (!audioCtx || loc !== current_csv_loc || !current_parsed_data) {
	// console.log("Playing " + loc + " after " + current_csv_loc);
        await play_audio(loc, instrument, options);
    }
    else if (audioCtx.state === 'running' && current_osc) {
	// console.log("Pausing" + current_csv_loc);
        pause_audio();
    }
    else {
	// console.log("Resuming" + current_csv_loc);
        await resume_audio();
    }
}

/**
 * Completely stops playback and cleans up AudioContext.
 */
export function stop_audio() {
    stop_active_oscillator();
    if (audioCtx) {
        audioCtx.close().catch(() => {});
        audioCtx = null;
    }
    current_seek_offset = 0;
    notify_callback('stopped');
}
