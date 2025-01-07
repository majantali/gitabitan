
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

    HREF <- sprintf("<span class='songtitle' onclick='displaySong(\"%s\")'>%s</span>", s[["id"]], s[[NAME]])

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
           "  #songarea { font-family: 'Noto Sans Bengali', 'Noto Serif'; white-space: 'pre'; }",
           "  .songtitle { color: rgb(100, 100, 255); cursor: pointer; }",
           "</style>",
           "</head>",
           "<body>",
           "<div class='container'>",
           "<h1>গীতবিতান</h1>")

    fwrite("

<ul class='nav nav-tabs' id='myTab' role='tablist'>
  <li class='nav-item' role='presentation'>
    <button class='nav-link active' id='songlist-tab' data-bs-toggle='tab' data-bs-target='#songlist' type='button' role='tab' aria-controls='songlist' aria-selected='true'>TOC</button>
  </li>
  <li class='nav-item' role='presentation'>
    <button class='nav-link' id='display-tab' data-bs-toggle='tab' data-bs-target='#display' type='button' role='tab' aria-controls='display' aria-selected='false'>Display</button>
  </li>
</ul>
<div class='tab-content' id='myTabContent'>
  <div class='tab-pane fade' id='display' role='tabpanel' aria-labelledby='display-tab'>
    <div id='songarea'>
    </div>
  </div>
  <div class='tab-pane fade show active' id='songlist' role='tabpanel' aria-labelledby='songlist-tab'>

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
    fwrite("<tfoot>", "<tr>")
    fwrite0("    <th>", "Search", "</th>")
    for (n in bncolnames) fwrite0("    <th>", "Search", "</th>")
    fwrite("</tr>", "</tfoot>")

    fwrite("</table>")
    fwrite("


  </div>
</div>  <!-- complete tab containing table of contents -->

</div> <!-- container -->

<script src='https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/5.3.0/js/bootstrap.bundle.min.js'></script>
<script src='https://cdn.datatables.net/v/bs5/jq-3.7.0/dt-2.2.0/fh-4.0.1/datatables.min.js'></script>

<script type='text/javascript'>

$(document).ready(function() {
    $('#songtable').DataTable({
	 paging: false,
         fixedHeader: true,

         initComplete: function () { // column-wise search
           this.api()
             .columns()
             .every(function () {
                let column = this;
                let title = column.footer().textContent;
 
                // Create input element
                let input = document.createElement('input');
                input.placeholder = title;
                // input.style.width = column.header().style.width;
                // input.style.minWidth = '75px';
                input.style.width = '75px';
                column.footer().replaceChildren(input);
 
                // Event listener for user input
                input.addEventListener('keyup', () => {
                    if (column.search() !== this.value) {
                        column.search(input.value).draw();
                    }
                });
             });
         },

	'order': [[ 1, 'asc' ], [ 3, 'asc' ]]
    });
    $('#songtable tfoot tr').appendTo('#songtable thead');
} );


var storedText;

function done() {
    document.getElementById('songarea').textContent = storedText;
    var dtab = document.getElementById('display-tab');
    bootstrap.Tab.getInstance(dtab).show()
}

function displaySong(id) {
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


str(s)

## FIXME remove file first
if (file.exists("index.html")) unlink("index.html")
export2htmltable(s, file = "index.html", append = TRUE)



