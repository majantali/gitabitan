
## Read song information from metadata.csv and create a sortable /
## searchable table (using DataTable)

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
    HREF <- sprintf("<a href='songs/%s.txt' target='_blank'>%s</a>", s[["id"]], s[[NAME]])

    fwrite  <- function(...) cat(..., "\n", file = file, append = append, sep = "\n")
    fwrite0 <- function(...) cat(..., "\n", file = file, append = append, sep = "")
    
    fwrite("<html>",
           "<head>",
           "<meta charset='utf-8' />",
           "<title>Gitabitan Song List</title>",
           "<meta name='viewport' content='width=device-width, initial-scale=1.0, user-scalable=yes' />",
           "<link rel='stylesheet' href='https://stackpath.bootstrapcdn.com/bootstrap/4.4.1/css/bootstrap.min.css' integrity='sha384-Vkoo8x4CGsO3+Hhxv8T/Q5PaXtkKtu6ug5TOeNV6gBiFeWPGFN9MuhOf23Q9Ifjh' crossorigin='anonymous' >",
           "<link rel='stylesheet' href='https://cdn.datatables.net/1.11.3/css/dataTables.bootstrap4.min.css' >",
           "<link rel='stylesheet' href='https://fonts.googleapis.com/css?family=Noto Serif' >",
           "<link rel='stylesheet' href='https://fonts.googleapis.com/css?family=Noto Sans' >",
           "<link rel='stylesheet' href='https://fonts.googleapis.com/earlyaccess/notosansbengali.css' >",
           "<style>",
           "  body { font-family: 'Noto Sans Bengali', 'Noto Serif'; padding-top: 10px; }",
           "</style>",
           "</head>",
           "<body>",
           "<div class='container'>",
           "<h1>গীতবিতান</h1>")
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
    fwrite("</div>")
    fwrite("

<script src='https://code.jquery.com/jquery-3.4.1.min.js'
	integrity='sha256-CSXorXvZcTkaix6Yvo6HppcZGetbYMGWSFlBw8HfCJo='
	crossorigin='anonymous'>
</script>

<script src='https://cdn.datatables.net/1.11.3/js/jquery.dataTables.min.js'
	crossorigin='anonymous'>
</script>

<script src='https://cdn.datatables.net/1.11.3/js/dataTables.bootstrap4.min.js'
	crossorigin='anonymous'>
</script>

<script src='https://stackpath.bootstrapcdn.com/bootstrap/4.4.1/js/bootstrap.min.js'
	integrity='sha384-wfSDF2E50Y2D1uUdj0O3uMBJnjuUD4Ih7YwaYd1iqfktj0Uod8GCExl3Og8ifwB6'
	crossorigin='anonymous'>
</script>

<script type='text/javascript'>

$(document).ready(function() {
    $('#songtable').DataTable({
	'paging': false,

         initComplete: function () {
           this.api()
             .columns()
             .every(function () {
                let column = this;
                let title = column.footer().textContent;
 
                // Create input element
                let input = document.createElement('input');
                input.placeholder = title;
                input.style.width = column.header().style.width;
                input.style.minWidth = '75px';
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



