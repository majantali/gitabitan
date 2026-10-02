
## Read song information from metadata.csv and create a sortable /
## searchable table (using DataTable)

## Use https://datatables.net/download/ to get CDN links

getSongInfo <- function(file = "metadata.csv")
{
    d <- read.csv(file,
                  quote = '"',
                  encoding = "utf-8") # is encoding useful?
    if (is.integer(d$id)) d$id <- sprintf("%05d", d$id)
    d
}

getMIDIList <- function(dir = "midi")
{
    f <- list.files(dir)
    f <- f[endsWith(f, ".mid")]
    f <- gsub(".mid", "", f)
    f
}


export2htmltable <- function(s, file = "", append = !(file == ""))
{
    ## file and append are used by cat(), supply a connection for more efficient writing (?)
    
    ## ncol <- ncol(s)
    ## colnames <- colnames(s) # for all, or select:
    colnames <-
        c("porjaay", "section", "number", "year",  "raag", "taal", "swaralipikar")
    bncolnames <-
        c("পর্যায়", "উপপর্যায়", "সংখ্যা", "রচনাকাল",  "রাগ", "তাল", "স্বরলিপিকার")
    URL <- "url"
    NAME <- "name"
    ## HREF <- sprintf("<a href='%s'>%s</a>", s[[URL]], s[[NAME]])
    ## OR use local text files (could further take name from first line)

    ## HREF <- sprintf("<a href='songs/%s.txt' target='_blank'>%s</a>", s[["id"]], s[[NAME]])

    HREF <- sprintf("<span class='songtitle' onclick='displaySong(\"%s\", \"%s\", %d, %s)'>%s</span>",
                    s[["id"]], s[["porjaay"]], s[["number"]], ifelse(s[["notationOK"]], "true", "false"), s[[NAME]])

    fwrite  <- function(...) cat(..., "\n", file = file, append = append, sep = "\n")
    fwrite0 <- function(...) cat(..., "\n", file = file, append = append, sep = "")
    
    fwrite("<!doctype html>",
           "<html lang='bn'>",
           "<head>",
           "<meta charset='utf-8' />",
           "<title>Gitabitan Song List</title>",
           "<meta name='viewport' content='width=device-width, initial-scale=1.0, user-scalable=yes' />",
           "<link href='https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/5.3.0/css/bootstrap.min.css' rel='stylesheet'>",
           "<link href='https://cdn.datatables.net/v/bs5/jq-3.7.0/dt-2.2.0/fh-4.0.1/datatables.min.css' rel='stylesheet'>",
           "<link rel='stylesheet' href='https://fonts.googleapis.com/css?family=Noto Serif' >",
           "<link rel='stylesheet' href='https://fonts.googleapis.com/css?family=Noto Sans' >",
           "<link rel='stylesheet' href='https://fonts.googleapis.com/earlyaccess/notosansbengali.css' >",
           "<style>",
           "  body { font-family: 'Noto Sans Bengali', 'Noto Serif'; padding-top: 10px; }",
           ## "  .modal-content { background: #e5e5e5; }",
           "  #audioslider {
    background-color: transparent;
  }
  #audioslider::-webkit-slider-runnable-track {
    background-color: #adb5bd;
    border: 1px solid #6c757d;
    height: 0.5rem;
    border-radius: 1rem;
  }
  #audioslider::-moz-range-track {
    background-color: #adb5bd;
    border: 1px solid #6c757d;
    height: 0.5rem;
    border-radius: 1rem;
  }
",
           "  #songarea { font-family: 'Noto Sans Bengali', 'Noto Serif'; white-space: pre; padding: 10px; }",
           "  .songtitle { color: rgb(100, 100, 255); cursor: pointer; }",
           "  #playbutton { cursor: pointer; font-size: 150%; }",
           "  .lyric-item { display: inline-block; margin: 0 2px; transition: color 0.1s ease, transform 0.1s ease; }",
           "  .lyric-past { color: #6c757d; opacity: 0.65; }",
           "  .lyric-current { color: #0d6efd; font-weight: bold; transform: scale(1.15); background-color: #e7f1ff; border-radius: 4px; padding: 0 4px; }",
           "  .lyric-future { color: #212529; }",
           "  .lyric-elongation { opacity: 0.5; font-size: 0.9em; }",
           "</style>",
           "</head>",
           "<body>",
           "<div class='container'>",
           "  <p class='float-end'>",
           "    <a href='https://github.com/majantali/gitabitan' target='_blank' rel='noopener noreferrer' aria-label='GitHub Project Page'>",
           "      <img src='octocat.svg' alt='GitHub' style='width: 32px; height: 32px;'>",
           "    </a>",
           "  </p>",
           "<h1>গীতবিতান</h1>")

    fwrite("
<div class='input-group'>
  <input type='text' class='form-control' id='searchinput' placeholder='Search' aria-label='Search'>
  <input type='text' class='form-control' id='search-bn' disabled readonly>
</div>
")
    
    fwrite("<table class='table table-striped table-bordered' id='songtable'>")
    ## table header
    fwrite("<thead>", "<tr>")
    fwrite0("    <th>", "প্রথম ছত্র", "</th>")
    for (n in bncolnames) fwrite0("    <th>", n, "</th>")
    fwrite("</tr>", "</thead>")
    fwrite("<tbody>")

    ## data
    for (i in seq_len(nrow(s)))
    {
        fwrite("<tr>")
        ## Write name as HREF
        fwrite0("<td>", HREF[i], "</td>")
        for (n in colnames) fwrite0("    <td>", s[[n]][i], "</td>")
        fwrite("</tr>")
    }

    fwrite("</tbody>")
    ## fwrite("<tfoot>", "<tr>")
    ## fwrite0("    <th>", "Search", "</th>")
    ## for (n in bncolnames) fwrite0("    <th>", "Search", "</th>")
    ## fwrite("</tr>", "</tfoot>")

    fwrite("</table>",
           "</div> <!-- container -->")
    fwrite("

<div class='modal fade' id='songModal' tabindex='-1' aria-labelledby='songModalLabel' aria-hidden='true'>
  <div class='modal-dialog modal-dialog-centered modal-dialog-scrollable modal-lg'>
    <div class='modal-content'>
      <div class='modal-header'>
        <h1 class='modal-title fs-5' id='songModalLabel'>Song</h1>
        <button type='button' class='btn-close' data-bs-dismiss='modal' aria-label='Close'></button>
      </div>
      <div class='modal-body'>
        <div id='songarea'>

Selected song goes here

        </div>
      </div>
      <div id='lyrics-container' class='px-3 py-2 bg-light border-top border-bottom text-center' style='min-height: 2.85rem; display: none;'>
        <div id='lyrics-window' style='font-size: 1.15rem; font-family: \"Noto Sans Bengali\", sans-serif; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;'>
          <span class='text-muted'>—</span>
        </div>
      </div>
      <div class='modal-footer justify-content-between flex-wrap gap-2'>
	<div id='noteogg' class='d-flex d-none align-items-center gap-2'>
	  <span id='playbutton' role='button' onclick='aplay()' title='Play/Pause'>⏯</span> <!-- OR  ▶ for both play and pause -->
	  <input type='range' id='audioslider' class='form-range' min='0' max='100' value='0' step='0.1' style='width: 170px;' disabled>
	  <span id='audiotime' class='small text-muted text-nowrap' style='font-variant-numeric: tabular-nums; min-width: 75px;'>0:00 / 0:00</span>
	</div>
	<div id='notation'>Notation: 
	    <a id='notecsv' href='' target='_blank'>[CSV]</a>&nbsp;<a id='notemidi' href=''>[MIDI]</a>
        </div>
        <button type='button' class='btn btn-primary' data-bs-dismiss='modal'>Close</button>
      </div>
    </div>
  </div>
</div>

<script src='https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/5.3.0/js/bootstrap.bundle.min.js'></script>
<script src='https://cdn.datatables.net/v/bs5/jq-3.7.0/dt-2.2.0/fh-4.0.1/datatables.min.js'></script>


<script type='text/javascript'
	src='https://majantali.github.io/assets/scripts/bninput.js'>
</script>

  
<script type='text/javascript'>

  var storedText;

  $(document).ready(function() {
      var search, songTable;
      songTable = $('#songtable').DataTable({
	  paging: false,
          fixedHeader: true,
	  layout: {
              topEnd: null
          },
	  // order: [[ 1, 'asc' ], [ 3, 'asc' ]]
	  order: [[ 0, 'asc' ]]
      });

      // search at most one per second
      search = DataTable.util.debounce(function (val) {
          songTable.search(val).draw();
      }, 1000);

      $('#searchinput').on( 'keyup', function () {
	  var bn = romanToBengali(this.value + ' ');
	  $('#search-bn').val(bn);
	  search( bn );
      } );

  } );

  var currentID;

  function done() {
      document.getElementById('songarea').textContent = storedText;
      $('#songModal').modal('show');
  }

  function displaySong(id, porjay, number, notation) {
      currentID = id;
      document.getElementById('songModalLabel').textContent = porjay + ' / ' + number;
      if (notation) {
          // console.log('Notation available');
	  document.getElementById('notation').style.display = 'inline';
	  // document.getElementById('noteogg').style.display = 'flex';
          document.getElementById('noteogg').classList.remove('d-none');
	  document.getElementById('lyrics-container').style.display = 'block';
	  document.getElementById('notecsv').href = 'https://github.com/majantali/gitabitan/blob/main/notation/' + id + '.csv';
	  document.getElementById('notemidi').href = 'midi/' + id + '.mid';
      }
      else {
          // console.log('Notation not available');
	  document.getElementById('notation').style.display = 'none';
	  // document.getElementById('noteogg').style.display = 'none';
          document.getElementById('noteogg').classList.add('d-none');
	  document.getElementById('lyrics-container').style.display = 'none';
      }

      if (window.resetAudioUI) {
          window.resetAudioUI();
      }

      var url = 'songs/' + id + '.txt';
      fetch(url)
	  .then(function(response) {
              response.text().then(function(text) {
		  storedText = text;
		  done();
              });
	  });
  }


</script>

<script type='module'>
  import {
      toggle_audio,
      stop_audio,
      seek_audio,
      get_total_duration,
      get_lyrics_window,
      set_playback_callback
  } from './freq2tune.js';

  let isDraggingSlider = false;
  const audioslider = document.getElementById('audioslider');
  const audiotime = document.getElementById('audiotime');
  const lyricsWindow = document.getElementById('lyrics-window');
  const playbutton = document.getElementById('playbutton');

  function formatTime(sec) {
      if (isNaN(sec) || sec < 0) sec = 0;
      const m = Math.floor(sec / 60);
      const s = Math.floor(sec % 60);
      return m + ':' + (s < 10 ? '0' : '') + s;
  }

  function renderLyricsWindow(tokens) {
      if (!lyricsWindow) return;
      if (!tokens || tokens.length === 0) {
          lyricsWindow.innerHTML = '<span class=\"text-muted\">—</span>';
          return;
      }
      const html = tokens.map(tok => {
          let cls = 'lyric-item';
          if (tok.isCurrent) cls += ' lyric-current';
          else if (tok.isPast) cls += ' lyric-past';
          else cls += ' lyric-future';
          if (tok.isElongation) cls += ' lyric-elongation';

          return `<span class=\"${cls}\">${tok.display}</span>`;
      }).join(' ');

      lyricsWindow.innerHTML = html;
  }

  window.resetAudioUI = function() {
      stop_audio();
      if (audioslider) {
          audioslider.value = 0;
          audioslider.disabled = true;
      }
      if (audiotime) {
          audiotime.textContent = '0:00 / 0:00';
      }
      if (lyricsWindow) {
          lyricsWindow.innerHTML = '<span class=\"text-muted\">—</span>';
      }
      // if (playbutton) {
      //     playbutton.textContent = '▶'; // OR just keep ⏯
      // }
  };

  set_playback_callback(({ currentTime, totalDuration, state, lyricsWindow: tokens }) => {
      if (totalDuration > 0 && audioslider) {
          audioslider.max = totalDuration;
          audioslider.disabled = false;
      }
      if (!isDraggingSlider && audioslider && audiotime) {
          audioslider.value = currentTime;
          audiotime.textContent = formatTime(currentTime) + ' / ' + formatTime(totalDuration);
      }
      renderLyricsWindow(tokens);
      // if (playbutton) {
      //     playbutton.textContent = (state === 'running') ? '⏸' : '▶'; // OR just keep ⏯
      // }
  });

  if (audioslider) {
      audioslider.addEventListener('input', function() {
          isDraggingSlider = true;
          const t = parseFloat(this.value);
          if (audiotime) {
              audiotime.textContent = formatTime(t) + ' / ' + formatTime(get_total_duration());
          }
          const tokens = get_lyrics_window(t);
          renderLyricsWindow(tokens);
      });

      audioslider.addEventListener('change', function() {
          isDraggingSlider = false;
          const t = parseFloat(this.value);
          seek_audio(t);
      });
  }

  window.aplay = function() {
      toggle_audio('./notation/' + currentID + '.csv', 'guitar', { AFREQ: 220 });
  };

  let savedScrollX = 0;
  $('#songModal').on('show.bs.modal', function () {
      savedScrollX = window.scrollX || window.pageXOffset || 0;
      if (savedScrollX > 0) {
          window.scrollTo(0, window.scrollY);
      }
  });

  $('#songModal').on('hidden.bs.modal', function () {
      if (savedScrollX > 0) {
          window.scrollTo(savedScrollX, window.scrollY);
      }
  });

  $('#songModal').on('hide.bs.modal', function () {
      stop_audio();
  });
</script>

")
    fwrite("</body>",
           "</html>")
}

s <- getSongInfo()
rownames(s) <- s$id

m <- read.csv("notation-metadata.csv")
m$id <- sprintf("%05d", m$id)

## "id","নাম","তাল","আবর্তন","tableWidth"

dtaal <- data.frame(s[m$id, c("name", "taal")], m = m$taal)

subset(dtaal, !(startsWith(m, taal) | startsWith(taal, m))) |>
    write.csv("taal-mismatch.csv")

s$notationOK <- s$id %in% getMIDIList()

str(s)

## FIXME remove file first
if (file.exists("index.html")) unlink("index.html")
export2htmltable(s, file = "index.html", append = TRUE)



