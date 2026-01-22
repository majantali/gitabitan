



## Load notation extracted in CSV format, and try to convert into
## another CSV file with notes / frquencies with the following
## columns:

## tstart  = time start
## tend    = time end
## fstart  = note at beginning
## fend    = note at end
## newnote = whether a "new note" or continuation (slur) or previous note

## We will indicate note as integer: 0 means "saa" of whatever scale
## is being used, and +i and -i as i semitones above or below.



fillByPrev <- function(x, which.pos = x < 0)
{
    for (i in seq_along(x)) {
        if (which.pos[[i]])
            x[[i]] <- x[[ i-1 ]]
    }
    x
}


## SLUR and SPARSHA notes: For now we will encode sparsha notes as
## 1/4 duration chords (simulataneous) and see how that
## sounds. For slurring we will use Legato and see how different
## synthesizers deal with that.

library(midiator) # only for key_indian map


## note2events() handles one row in the original notation, producing
## one row per distinct note.

## slur1 = TRUE means the first note is a slur. Others may or may not
## be slurs; this can only be determined by looking at the lyrics

note2events <- function(notes, start, slur1, lyrics, meed, NOTE_DURATION)
{
    ## str(notes)
    touchNotes <- startsWith(notes, "^")
    n <- sum(!touchNotes) # exclude sparsha notes from count
    if (n == 0L) return(NULL) # empty
    octave <- endsWith(notes, "'") - endsWith(notes, ".") # assume at most one octave either side
    x <- gsub("['^\\.]", "", notes)
    keys <- key_indian(x, octave) |> unname()
    keys[notes == "-"] <- -1L # special case: continue previous note (tie)
    if (anyNA(keys)) return(NULL) # not a valid note
    ## duration of individual notes; should be integer and add up to NOTE_DURATION
    touchKeys <- keys[touchNotes]
    keys <- keys[!touchNotes]
    d <- rep(NOTE_DURATION / n, n) # TODO: adjust for sparsha notes
    ## use this to calculate start and stop times for each note
    dstop <- start + cumsum(d)
    dstart <- c(start, dstop[-n])

    ## slur1 indicates initial slur|tie. Add further slurs based on
    ## lyrics --- only if noteCount matches.
    if (length(lyrics) == n) {
        wslur <- lyrics == "৹"
        wslur[[1]] <- wslur[[1]] || slur1
    }
    else wslur <- rep(slur1, n)

    if (any(touchNotes)) {
        ## assume they are either in first position or last position
        if (touchNotes[[1]]) { # first position
            dstart[1] <- dstart[1] + NOTE_DURATION / 4
            dstart <- c(start, dstart)
            dstop <- c(start + NOTE_DURATION / 4, dstop)
            keys <- c(touchKeys[[1]], keys)
            wslur <- c(slur1, wslur)
            meed <- rep(c(TRUE, FALSE), c(1, n)) | meed
        }
        else { # last position
            ## str(touchNotes)
            dstop[n] <- dstop[n] - NOTE_DURATION / 4
            dstart <- c(dstart, dstop[n])
            dstop <- c(dstop, dstop[n] + NOTE_DURATION / 4)
            keys <- c(keys, touchKeys[[1]])
            wslur <- c(wslur, TRUE)
            meed <- rep(c(FALSE, TRUE, FALSE), c(n-1, 1, 1)) | meed

        }
    }
    ## data.frame(keys, dstart, dstop, slur = wslur, lyrics = paste0(lyrics, collapse = "")) |> str()
    data.frame(keys, dstart, dstop, slur = wslur, meed = meed)
}



## We need to define a "duration" for a single note, which we may
## subdivide for multiple notes. This is just an arbitrary initial
## duration which we can multiply according to the tempo, and only
## needs to be such that fractions are still integers. 60 is a good
## initial choice as it is divisible by 1 to 6 --- but we may revisit
## this depending on how we want to handle "sparsha" notes.

## NOTE_DURATION <- 60L

notation2freq <- function(id = "00032", notation_file = sprintf("notation/%s.csv", id),
                          NOTE_DURATION = 60L,
                          RELEASE_OFFSET = 0L, # release offset when next note is slurred
                          file = sprintf("midi/%s.mid", id))
{
    if (!file.exists(notation_file)) return(invisible())
    notation <- read.csv(notation_file, 
                         colClasses = "character")

    ## 'notes' is a vector of notes (as split by strsplit(., "+", fixed = TRUE))

    ## We need to convert each row into a series of MIDI events. As a
    ## first crude approximation, these can consist of NoteOn and NoteOff
    ## (==NoteOn with 0 volume for simplicity) events. Each such event
    ## needs to specify a key, volume (0 for note off) and time. For now,
    ## we will count time incrementally (eventually we will record
    ## delta-times in the MIDI file after suitable reordering).

    ## We will produce a list for each row. The list will usually contain
    ## at least 2 elements for each note in the row (on and off).

    ## Add cumulative time in notation data. Also drop initial - (which
    ## indicate tie or slur).

    notation <- within(notation,
    {
        inmeed <- cumsum(meed == "BEGIN") - cumsum(meed == "END")
        start <- cumsum(NOTE_DURATION * (noteCount > 0))
        ## Is first note a slur? ("-" means tie, not cosidered here)
        ## --- other notes in a multi-note note can be slurs as well,
        ## but that is indicated in the lyrics.
        slur1 <- (note != "-") & startsWith(note, "-") # can we have - in the middle?
        note[slur1] <- gsub("-", "", note[slur1]) # drop the now reduntant hyphen
        ## Further slurs based on lyrics are added by note2events() in the call below
    })

    noteCodes <- 
        with(notation,
             mapply(note2events,
                    notes = strsplit(note, "+", fixed = TRUE),
                    start = start,
                    slur1 = slur1,
                    lyrics = strsplit(words, " ", fixed = TRUE),
                    meed = inmeed,
                    NOTE_DURATION = NOTE_DURATION)
             ) |> do.call(what = rbind)

    ## str(noteCodes)
    

    ## We now have entries like

    ##    keys dstart dstop  slur meed
    ## 1    64     60   120 FALSE    0
    ## 2    -1    120   180  TRUE    0
    ## 3    -1    180   240  TRUE    0
    ## 4    64    240   300 FALSE    0
    ## 5    -1    300   360 FALSE    0
    ## 6    64    360   420 FALSE    0
    ## 7    62    420   435 FALSE    1
    ## 8    64    435   480 FALSE    0

    ## which should be good enough. We could simplify slightly by
    ## combining the -1's with the previous note (as long as no meed
    ## activity is happening, should in principle should not happen in
    ## such cases, but who knows, so better to check).

    ## Or, just ignore because it could be handled downstream if needed. 

    noteCodes$keys <- fillByPrev(noteCodes$keys)

    ## Convert to desired format with
    
    ## tstart  = time start
    ## tend    = time end
    ## kstart  = key at beginning (to be converted to frequency later)
    ## kend    = key at end
    ## newnote = whether a "new note" or continuation (slur) or previous note

    ans <- 
        with(noteCodes, 
             data.frame(tstart = dstart, tend = dstop,
                        kstart = keys, kend = keys,
                        newnote = as.integer(!slur)))
    
    ## We still need to adjust 'kend' by changing it to the 'kstart'
    ## of the next note if 'meed == 1'
    if (noteCodes$meed[[nrow(noteCodes)]] == 1)
        stop("A 'meed' must end by last note; please check input data")
    wmeed <- which(noteCodes$meed == 1)
    ans$kend[wmeed] <- ans$kstart[wmeed + 1]
    ans
}




options(warn = 1)

if (FALSE)
{

    notation2freq("01177") |> head(30)

    notation2freq("01071") |> with(kend - kstart)

    ## notation2midi("00004", instrument = "viola",
    ##               maxvol = 120, speed = 1.2,
    ##               file = "output.mid")


    ## sanity check

    from_midi("output.mid") |> split_midi() |> str()

} else {

    for (i in 1:3000) {
        id <- sprintf("%05d", i)
        print(id)
        outfile <- sprintf("frequency-duration/%s.csv", id)
        try(notation2freq(id) |> write.csv(file = outfile))
    }

}
