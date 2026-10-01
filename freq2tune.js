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


// NOTE: 'instrument' is not really to be taken seriously, they are
// just proxies for the various waveforms available

let audioCtx;
let current_csv_loc;

export function toggle_audio(loc, instrument = 'guitar', options = {}) {
    // single button click to initiate play / pause / resume
    if (!audioCtx || loc !== current_csv_loc || audioCtx.state === 'closed') {
        current_csv_loc = loc;
        play_audio(loc, instrument, options);
    }
    else if (audioCtx.state === 'running') {
        audioCtx.suspend();
    }
    else if (audioCtx.state === 'suspended') {
        audioCtx.resume();
    }
}

export function stop_audio() {
    if (audioCtx) {
        audioCtx.close();
        audioCtx = null;
        current_csv_loc = null;
    }
}

export async function play_audio(loc, instrument = 'guitar', options = {}) {
    if (audioCtx) {
        audioCtx.close();
        audioCtx = null;
    }
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();

    let targetLoc = loc;
    if (typeof targetLoc === 'string') {
        // If passed a bare ID like "00032", resolve to notation path
        if (!targetLoc.includes('/') && !targetLoc.endsWith('.csv')) {
            targetLoc = `./notation/${targetLoc}.csv`;
        }
        // Redirect legacy freqmap or frequency-duration paths directly to notation folder
        targetLoc = targetLoc.replace(/\/(freqmap|frequency-duration)\//, '/notation/');
    }

    // Fetch the CSV file
    const response = await fetch(targetLoc);
    if (!response.ok) {
        console.error(`Failed to fetch file from ${targetLoc}: ${response.statusText}`);
        return;
    }
    const csvText = await response.text();
    
    // Parse the CSV
    const parsed = Papa.parse(csvText, {
        header: true,
        dynamicTyping: true,
        skipEmptyLines: true
    });
    
    let data = parsed.data;
    if (!data || data.length === 0) return;

    // If CSV is in notation format, convert directly to frequency-duration format
    if (data[0] && (data[0].note !== undefined || data[0].onote !== undefined)) {
        data = notation2freq(data, options);
    }

    if (!data || data.length === 0) return;
    
    // Ensure AudioContext is running
    if (audioCtx.state === 'suspended') {
        await audioCtx.resume();
    }
    
    const startTime = audioCtx.currentTime + 0.1; // Add small delay to prevent immediate glitch
    
    const masterGain = audioCtx.createGain();
    masterGain.connect(audioCtx.destination);
    masterGain.gain.value = 0.5; // Avoid clipping
    
    // Set up instrument timbre
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
    
    let lastTime = startTime;
    
    data.forEach((row, index) => {
        if (row.tstart === undefined || row.tend === undefined || row.fstart === undefined || row.fend === undefined) {
            return;
        }

        const tstart = row.tstart;
        const tend = row.tend;
        const fstart = row.fstart;
        const fend = row.fend;
        const newnote = row.newnote;
        
        const absoluteTstart = startTime + tstart;
        const absoluteTend = startTime + tend;
        
        // Frequency scheduling
        if (absoluteTend > absoluteTstart) {
            osc.frequency.setValueAtTime(fstart, absoluteTstart);
            osc.frequency.linearRampToValueAtTime(fend, absoluteTend);
        } else {
            osc.frequency.setValueAtTime(fend, absoluteTend);
        }
        
        // Amplitude scheduling
        if (newnote === 1) {
            envelope.gain.setValueAtTime(0, absoluteTstart);
            envelope.gain.linearRampToValueAtTime(1, absoluteTstart + 0.05); // 50ms attack
        } else if (index === 0) {
            envelope.gain.setValueAtTime(1, absoluteTstart);
        }
        
        // Determine if we need to release the note
        const isLast = index === data.length - 1;
        let release = false;
        
        if (isLast) {
            release = true;
        } else {
            const nextRow = data[index + 1];
            if (nextRow.newnote === 1) {
                release = true;
            } else if (nextRow.tstart > tend + 0.001) { // gap in time
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
        if (audioCtx && audioCtx.state !== 'closed') {
            audioCtx.close();
            audioCtx = null;
            current_csv_loc = null;
        }
    };

    osc.stop(lastTime + 0.1);
}
