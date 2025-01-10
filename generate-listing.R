
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
    
    fwrite("<html>",
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
           "  #songarea { font-family: 'Noto Sans Bengali', 'Noto Serif'; white-space: pre; padding: 10px; }",
           "  .songtitle { color: rgb(100, 100, 255); cursor: pointer; }",
           "</style>",
           "</head>",
           "<body>",
           "<div class='container'>",
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

    fwrite("</table>")
    fwrite("

<div class='modal fade' id='songModal' tabindex='-1' aria-labelledby='songModalLabel' aria-hidden='true'>
  <div class='modal-dialog modal-dialog-scrollable modal-lg'>
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
      <div class='modal-footer'>
	<audio id='noteogg' class='me-auto' controls src=''></audio>
	<div id='notation'>Notation: 
	    <a id='notecsv' href='' target='_blank'>[CSV]</a>&nbsp;<a id='notemidi' href=''>[MIDI]</a>
        </div>
        <button type='button' class='btn btn-primary' data-bs-dismiss='modal'>Close</button>
      </div>
    </div>
  </div>
</div>



</div> <!-- container -->

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

  function done() {
      document.getElementById('songarea').textContent = storedText;
      $('#songModal').modal('show');
  }

  function displaySong(id, porjay, number, notation) {
      document.getElementById('songModalLabel').textContent = porjay + ' / ' + number;
      if (notation) {
	  document.getElementById('notation').style.display = 'inline';
	  document.getElementById('noteogg').style.display = 'block';
	  document.getElementById('notecsv').href = 'https://github.com/majantali/gitabitan/blob/main/notation/' + id + '.csv';
	  document.getElementById('notemidi').href = 'midi/' + id + '.mid';
	  document.getElementById('noteogg').src = 'https://nlplab.isid.ac.in/gitabitan/ogg/' + id + '.ogg';
      }
      else {
	  document.getElementById('notation').style.display = 'none';
	  document.getElementById('noteogg').style.display = 'none';
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



