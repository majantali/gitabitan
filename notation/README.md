# Explanation of columns

* misc: Any additional notes above notation like

* onote: Original notation cell. In bengali, with ^ for
       superscript, aakar dropped.

* note: Processed note in roman, separated by +, preceded
      by ^ for superscript, followed by ' for upper octave
      and . for lower octave

* meed: Indicates beginning / end of meed

* words: Lyrics. ৹ -s are surrounded by space

* noteCount: Computed count of notes (excluding superscript
           notes) separated by +. Should ideally match number
           of distinct syllables (including ৹) in lyrics,
           separated by space.

* slurOK: Whether slur / tie indications in note and word column
        are consistent. Basically, this flags cases where the
        lyrics cell starts with ৹ but the note does _not_ start
        with -.

* countOK: Flags cases where note counts and (crude) syllable
         counts don't match, so that the latter can be manually
         edited if necessary.

