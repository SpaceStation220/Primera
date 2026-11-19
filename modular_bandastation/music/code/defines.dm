#define INSTRUMENT_OUTPUT_GAIN 2
#define MUSIC_NOTES_MAX_CHARS 40000
#define MUSIC_NATIVE_FIELDS 32
#define MUSIC_NATIVE_FIELD_CHARS 1024
#define MUSIC_NATIVE_PAGE_CHARS (MUSIC_NATIVE_FIELDS * MUSIC_NATIVE_FIELD_CHARS)
#define MUSIC_DOCUMENT_MAX_BYTES 600000
#define MUSIC_NATIVE_MAX_CHARS 800000
#define INSTRUMENT_FILE_RETENTION_MARGIN 2
#define INSTRUMENT_FILE_OUTPUT_GAIN 3
#define INSTRUMENT_FALLOFF_DISTANCE 4
#define INSTRUMENT_FALLOFF_EXPONENT 3
/// Hearing and sustained-voice updates share one pass; note deadlines remain independent.
#define MUSIC_SPATIAL_UPDATE_INTERVAL (1 SECONDS)
/// Bounds shared by instrument uploads and physical concert disks.
#define MUSIC_UPLOAD_MAX_BYTES (10 * 1024 * 1024)
#define MUSIC_UPLOAD_MAX_DURATION (30 MINUTES)
/// Capacity of one round-local physical disk.
#define CONCERT_DISK_MAX_TRACKS 12
#define CONCERT_DISK_MAX_BYTES (50 * 1024 * 1024)
/// Bounded number of linked sound origins per concert player.
#define CONCERT_MAX_RECEIVERS 16
/// Concert volume stays constant within this Euclidean distance, inclusive.
#define CONCERT_STEREO_RADIUS 5
