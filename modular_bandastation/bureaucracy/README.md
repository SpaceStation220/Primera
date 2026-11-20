# Paged Books

Adapted from ss220club/BandaStation PR #1586 by msw7007 (KageIIte):
https://github.com/ss220club/BandaStation/pull/1586

Paper has two owned page datums. Existing raw paper lists are the active side's
compatibility view, captured before switching, copying or serializing. Stacks
contain real sheets; each sheet remains its own UI host, retaining Primera's
writer permissions and signal cleanup. Photos use the original picture PNG as
bounded inline data, never icon2html or an external URL.

Books contain up to 40 pages (20 sheets). Binding preserves blank sides, text,
photos and stamps. A saved document is capped at 512 KiB; oversized/blank input
is returned instead of consumed. Each photo is capped at 128 KiB Base64.

Archive format: `{format: "ss220-book", version: 1, pages: [{text, photo, stamps}]}`.
Text is HTML-encoded at rest; the frontend still sanitizes decoded markup. The
reader's position is not saved. Copy/scan preserves page boundaries. Legacy
encoded text, including text that happens to be JSON without this format tag,
loads as one page. Unsupported recognized versions are rejected atomically.

Deploy fork schema revision **1.5** before uploading multi-page books; see
`SQL/bandastation/database_changelog.md`. No other service or package is required.
The SQL expansion preserves old rows. Their conversion is lazy on read, with
new-format persistence on the next upload; there is no startup-wide table rewrite.
