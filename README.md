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



