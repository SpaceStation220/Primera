#define INSTRUMENT_OUTPUT_GAIN 2
#define MUSIC_NOTES_MAX_CHARS 40000
#define MUSIC_NATIVE_FIELDS 32
#define MUSIC_NATIVE_FIELD_CHARS 1024
#define MUSIC_NATIVE_PAGE_CHARS (MUSIC_NATIVE_FIELDS * MUSIC_NATIVE_FIELD_CHARS)
#define MUSIC_DOCUMENT_MAX_BYTES 600000
#define MUSIC_NATIVE_MAX_CHARS 800000
/// Start silent OGG downloads before the listener reaches the audible boundary.
#define INSTRUMENT_FILE_PRELOAD_MARGIN 5
#define INSTRUMENT_FILE_OUTPUT_GAIN 3
#define INSTRUMENT_FALLOFF_DISTANCE 4
#define INSTRUMENT_FALLOFF_EXPONENT 3
/// Local audibility is refreshed independently of note scheduling and envelopes.
#define MUSIC_SPATIAL_UPDATE_INTERVAL (1 SECONDS)
/// Bound the fixed initial audience wait and startup error notifications.
#define MUSIC_START_AUDIENCE_WAIT (5 SECONDS)
#define MUSIC_START_LEAD (0.5 SECONDS)
/// Release sampled MIDI voices instead of cutting the waveform at note-off.
#define MUSIC_MIDI_RELEASE (0.1 SECONDS)
/// Bounds shared by instrument uploads and physical concert disks.
#define MUSIC_UPLOAD_MAX_BYTES (3 * 1024 * 1024)
#define MUSIC_UPLOAD_MAX_DURATION (30 MINUTES)
/// Capacity of one round-local physical disk.
#define CONCERT_DISK_MAX_TRACKS 12
#define CONCERT_DISK_MAX_BYTES (50 * 1024 * 1024)
/// Bounded number of linked sound origins per concert player.
#define CONCERT_MAX_RECEIVERS 16
/// Concert volume stays constant within this Euclidean distance, inclusive.
#define CONCERT_STEREO_RADIUS 5
