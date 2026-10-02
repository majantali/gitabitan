# gitabitan / গীতবিতান

This is a searchable copy Gitabitan along with related resources.

What you get:

* A list of all songs (first line) by Rabindranath Tagore along with metadata (such as পর্যায়, রচনাকাল, রাগ, তাল, etc.) in the form of a table.

* Search on first line and metadata (as displayed in the table).

* Full text of song (on click), along with links to notation (in CSV format) and MIDI when available.

* Synthesized version of notation (created in real time from CSV via Javascript)

## Metadata sources

- `metadata.csv` from <http://www.gitabitan.net/>

- `notation-metadata.csv` from <https://rabindra-rachanabali.nltr.org> (notation pages)

## Contributions welcome

The sources of the page are available on
[GitHub](https://github.com/majantali/gitabitan).  Corrections of
typos and other errors in the song text and notation are most welcome,
preferably through a pull request (alternatively, email
`<deepayan.sarkar@gmail.com>`). In particular, the notation follows
the standard practice of not repeating the _sthaayi_ explicitly, which
leads to artificial jumps in the synthesized audio. This can only be
fixed by editing the notation CSV files one at a time.

## Brief history

The project started with the collection of songs, notations (in
machine readable CSV format), and metadata. These form the primary
content.

The audio rendering of notation has gone through several phases. The
first attempt was to create MIDI files and render them into OGG via
`timidity`. This has two problems: storage of the OGG files, and more
importantly, MIDI is not suited to the nuances of Rabindrasangeet.

The second attempt (`generate-freq-csv.R`) converted the notation into
a different form based on a piecewise linear frequency-by-time
function. This was then rendered as simple sound signals generated
using the the
[OscillatorNode](https://developer.mozilla.org/en-US/docs/Web/API/OscillatorNode)
interface of the [Web Audio
API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API). This
code was written with AI assistance.

Subsequently, the `generate-freq-csv.R` script was translated to
Javascript (using AI) so that the sound synthesis could work directly
off the notation CSV file. This helps simplify the modify-test cycle;
edits to the CSV file can be directly tested.


## Editable Content

- Songs: `songs/<id>.md`

- Notation: `notation/<id>.csv`

## Derived content

- Listing: `index.html`

- MIDI files: `midi/<id>.mid` (converted from notation)

- Audio files: `ogg/<id>.ogg` (rendered from MIDI using timidity)

## Code

- `generate-listing.R`

## Debug info

- `taal-mismatch.csv` : metadata mismatch on taal

## Notes

Can use this for column-wise search, but that seems buggy.

```
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
```

## About

This project is the brainchild of [Soumendu Sundar
Mukherjee](https://github.com/soumendu041) and [Deepayan
Sarkar](https://github.com/deepayan), and builds on the excellent
resources from <http://www.gitabitan.net/> (song text and metadata)
and <https://rabindra-rachanabali.nltr.org> (notation).

