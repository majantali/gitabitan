

## Load notation extracted in CSV format, and try to convert into MIDI
## using the midiator package.

## To install, run
## remotes::install_github("majantali/midiator")

library(midiator)


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

## slur1 = TRUE means the first note is a slur. Others may or may not
## be slurs; this can only be determined by looking at the lyrics

note2events <- function(notes, start, slur1, lyrics, NOTE_DURATION)
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
            dstart <- c(start, dstart)
            dstop <- c(start + NOTE_DURATION / 4, dstop)
            keys <- c(touchKeys[[1]], keys)
            wslur <- c(slur1, wslur)
        }
        else { # last position
            ## str(touchNotes)
            dstart <- c(dstart, dstop[n] - NOTE_DURATION / 4)
            dstop <- c(dstop, dstop[n])
            keys <- c(keys, touchKeys[[1]])
            wslur <- c(wslur, TRUE)
        }
    }
    ## data.frame(keys, dstart, dstop, slur = wslur, lyrics = paste0(lyrics, collapse = "")) |> str()
    data.frame(keys, dstart, dstop, slur = wslur)
}



note2drums <- function(notes, start, NOTE_DURATION)
{
    ## For now, we will only use the following in channel 10 (can do more using metadata?):
    ##   di (key = D3 == 50)
    ##   na (key = C#3 == 49)

    ## We actually need to know history which we don't have
    ## here. Instead, we will add a di for _every_ note, and add an
    ## overlapping na in the _previous_ time slot every time we
    ## encounter a |

    if (length(notes) > 1L || !(notes %in% c("|", "⌶", "⌶⌶"))) { # usual note
        dstop <- start + NOTE_DURATION
        dstart <- start
        keys <- 50L
    }
    else if (start > NOTE_DURATION) {
        dstop <- start
        dstart <- start - NOTE_DURATION
        keys <- 49L
    }
    else return(NULL) # empty

    data.frame(keys, dstart, dstop, slur = FALSE)
}



## We need to define a "duration" for a single note, which we may
## subdivide for multiple notes. This is just an arbitrary initial
## duration which we can multiply according to the tempo, and only
## needs to be such that fractions are still integers. 60 is a good
## initial choice as it is divisible by 1 to 6 --- but we may revisit
## this depending on how we want to handle "sparsha" notes.

## NOTE_DURATION <- 60L

notation2midi <- function(id = "00052", notation_file = sprintf("notation/%s.csv", id),
                          speed = 1,
                          maxvol = 100,
                          instrument = "sitar",
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
                    NOTE_DURATION = NOTE_DURATION)
             ) |> do.call(what = rbind)

    ## str(noteCodes)
    
    ## convert to long format - manually

    noteCodesLong <-
        with(noteCodes,
             data.frame(key = rep(keys, each = 2),
                        time =  as.vector(rbind(dstart, dstop)),
                        volume = c(maxvol, 0),
                        ## record whether _next_ note is slur; to offset release of current note 
                        slur = rep(slur, each = 2) |> tail(-2) |> c(FALSE, FALSE)))

    ## We now have entries like
    ## 
    ## key time volume
    ##  70  600    100
    ##  70  660      0   <- drop
    ##  -1  720    100   <- drop
    ##  -1  780      0   <- replace by 70 780 0
    ##  65  780    100
    ##  65  810      0

    ## so a simple algorithm could be:
    ##
    ## w = key == -1 && volume > 0
    ## change key[w+1] to key[w-1]
    ## drop rows w-1 and w
    ##
    ## However, this fails when there are consecutive ties (-1 -1 -1 -1 ...)
    ##
    ## The code below deals with this case as well

    wtie <- which(noteCodesLong$key < 0)[c(TRUE, FALSE)]
    if (length(wtie)) {
        noteCodesLong$key <- fillByPrev(noteCodesLong$key)
        noteCodesLong$key[wtie + 1] <- noteCodesLong$key[wtie - 1]
        noteCodesLong <- noteCodesLong[-c(wtie-1, wtie), ]
    }

    ## Next, add mandatory columns giving event type (NoteOn) and
    ## channel (0). Add a release offset for slur notes.

    release_id <- noteCodesLong$volume == 0

    noteCodesLong <- within(noteCodesLong,
    {
        desc <- "NoteOn"
        channel <- 0

        ## experimental: offset NoteOff (volume = 0) events by a few
        ## ticks so that there is a slight overlap with the next note
        ## (only for slur notes)
        if (RELEASE_OFFSET) {
            time[release_id] <- time[release_id] +
                RELEASE_OFFSET * ifelse(slur[release_id], 1, 0)
        }

        rm(slur) # legato done separately
    })

    ## to manage slurs, we find a list of times where slurs go on and
    ## off, and then interleave corresponding 'legato' control
    ## codes.

    slurCodes <- with(noteCodes,
                      data.frame(time = dstart, slur = slur)
                      |> unique() |>
                      sort_by(~ time))
    ## keep only changes
    slurChangeLocs <- diff(c(2, slurCodes$slur)) != 0
    slurCodes <- slurCodes[slurChangeLocs, ] |>
        within(
        {
            channel <- 0
            desc <- "ControlChange"
            key <- 68 # 68 = controller_code("Legato"), 65 = controller_code("Portamento")
            volume <- 127 * slur
            time <- time - 1L
        })
    ## meed with portamento controls? No idea how this works
    ## portCodes <- ... TODO

    ## Combine. Need to make sure that at a given time, the slur on /
    ## off happens before the NoteOn events. We also ensure that
    ## NoteOn events (volume > 0) happen before NoteOff (volume = 0),
    ## even if they happen simultaneously (though that should not
    ## matter).

    noteCodesLong <-
        ## noteCodesLong |>
        rbind(noteCodesLong,
              ## portCodes[names(noteCodesLong)],     ## TODO
              slurCodes[names(noteCodesLong)]) |>
        sort_by(~ time + desc + I(-volume)) |>
        within(timestamp <- c(0, diff(time)))
    
    ## print(head(noteCodesLong, 30))
    
    rawTrack <- 
        with(noteCodesLong,
        {
            inc_status <- c(TRUE, tail(desc, -1) != head(desc, -1))
            mapply(midi_event,
                   timestamp = timestamp,
                   type = desc,
                   channel = channel,
                   what = key,
                   value = volume,
                   include.status = inc_status,
                   SIMPLIFY = FALSE) |> unlist()
        })

    rawInstrument <-
        midi_event(timestamp = 0, 
                   type = "ProgramChange",
                   channel = 0,
                   value = program_code(instrument),
                   include.status = TRUE)

    ## any general customizations to start off
    initSettings <- raw(0)
    ##     as.raw(c(0, 0xb0, 126, 0)) # PolyMode Off ? 
    
    rawMidi <-
        encode_midi(list(c(rawInstrument, initSettings, rawTrack)),
                    speed = as.integer(speed * NOTE_DURATION))

    writeBin(rawMidi, con = file)
    ## invisible(rawMidi)

    invisible(noteCodesLong)
}




options(warn = 1)

if (FALSE)
{

    ## foo <- 

    ## notation2midi("00052", instrument = "violin",
    ##               maxvol = 120, speed = 1.2,
    ##               file = "output.mid")


    notation2midi("01177", instrument = "violin",
                  maxvol = 120, speed = 0.8)

    ## notation2midi("00004", instrument = "viola",
    ##               maxvol = 120, speed = 1.2,
    ##               file = "output.mid")


    ## sanity check

    from_midi("output.mid") |> split_midi() |> str()

} else {

    for (i in 1:3000) {
        id <- sprintf("%05d", i)
        print(id)
        try(notation2midi(id, instrument = "violin",
                          RELEASE_OFFSET = 10L,
                          maxvol = 120, speed = 1.25))
    }

}
