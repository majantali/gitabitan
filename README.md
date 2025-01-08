# gitabitan

Searchable Gitabitan + related resources

## Metadata sources

- `metadata.csv` from <http://www.gitabitan.net/>

- `notation-metadata.csv` from <https://rabindra-rachanabali.nltr.org> (notation pages)

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

