import Papa from 'https://cdn.jsdelivr.net/npm/papaparse@5.4.1/+esm';


// NOTE: 'instrument' is not really to be taken seriously, they are
// just proxies for the various waveforms available

let audioCtx;
let current_csv_loc;

export function toggle_audio(loc, instrument) {
    // single button click to initiate play / pause / resume
    if (!audioCtx || loc != current_csv_loc) {
	current_csv_loc = loc;
	play_audio(loc, instrument);
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
    }
}

async function play_audio(loc, instrument = 'flute') {
    if (audioCtx) { audioCtx.close(); }
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();

    // Fetch the CSV file
    const response = await fetch(loc);
    const csvText = await response.text();
    
    // Parse the CSV
    const parsed = Papa.parse(csvText, {
        header: true,
        dynamicTyping: true,
        skipEmptyLines: true
    });
    
    const data = parsed.data;
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
    let type = 'sine';
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
        osc.frequency.setValueAtTime(fstart, absoluteTstart);
        osc.frequency.linearRampToValueAtTime(fend, absoluteTend);
        
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
            envelope.gain.setValueAtTime(1, releaseStart);
            envelope.gain.linearRampToValueAtTime(0, absoluteTend);
        }
        
        lastTime = Math.max(lastTime, absoluteTend);
    });
    
    osc.stop(lastTime + 0.1);
}
