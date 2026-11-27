# DNA Console appearance preview

Open `DnaConsole` with `dna-console-human`, `dna-console-species` or
`dna-console-empty` in the standard TGUI preview. All use a 550×710 viewport.
All appearance modes share the upper "Внешность" tab. The human fixture selects
"Базовая ДНК"; the species fixture selects "Видовая ДНК" and includes a long DNA
string, long labels and a scrollable list of secondary features.

Appearance is on the left, Unique Identity / Features on the right, and the
buffers below. Clicking an appearance icon overlays its catalog on the Unique
panel. Close it with the cross or click the same appearance icon again.
The full-width strip above both panels restores pulse strength, duration,
accuracy and the 68%/95% deviation readouts using their original server fields.
Strength and duration are grouped at the left. "Облучить" sends
makeup_pulse_differences for both DNA strings, with the current subject/draft refs;
it is disabled when there are no differences or a pulse is running. The rotate
button in the target header sends rotate_appearance_target without changing DNA.
In game each differing symbol receives the same random impulse as an individual
DNA button after one shared duration; actual remaining differences drive colors.
The DNA switch uses existing set_view modes enzymes/features; pulse actions keep
their ui/uf types. Preview records these actions without simulating server state.

The DM console supplies `appearance` from its current human scanner occupant,
including species features, the existing preferences spritesheet and a cached
PNG portrait. Accessibility uses character creation's rules with the scanned
body's values. These browser fixtures supply synthetic values and PNGs. Without
appearance data, the frontend displays an unavailable-data message. Catalog
selection and color controls submit set_target_appearance with the subject and
draft references. In game, validated choices update only the isolated target DNA
and its rendered portrait. Controls without DNA blocks are omitted. The scanned
body and player preferences are not modified. These synthetic fixtures show one
different Identity triplet in green; matching triplets remain blue. Preview only
records actions and does not run the DM renderer. Colors use the existing TGUI hue
and saturation/value controls, with optional HEX entry. Apply resets the local selection.

All values and labels are synthetic. Embedded PNGs are cropped/composited frames
from existing repository assets at `1b430e59b4c2df1a80e531d18d63a23a73cb3f06`:

- `icons/mob/human/human.dmi`: `human_basic`.
- `icons/mob/human/bodyparts_greyscale.dmi`: `human_head_m`.
- `icons/mob/human/human_face.dmi`: hair and facial-hair states.
- `icons/mob/human/species/lizard/bodyparts.dmi`: lizard body parts.
- `icons/mob/human/species/lizard/lizard_misc.dmi`: horns, snouts and frills.

The thumbnails use a nearest-neighbor head crop; no external artwork or player
runtime data is included. These illustrative catalogs do not define gameplay
availability or faithfully reproduce the game's dynamic character renderer.
