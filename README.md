# quill_delta
The Superlist fork of the great [quill_delta Dart package](https://github.com/pulyaevskiy/quill-delta-dart).

## Why?
We're using [the Quill.js Delta format](https://quilljs.com/docs/delta/) on the client and the server to express documents and changes to documents.

This format makes it easier for us to do operational transformation on our documents, so that multiple users can make changes on the same document simultaneously.
The Dart package (which is a port of the original Quill Delta Javascript library) has made it neat to implement this functionality.

However, the `quill_delta` Dart package has not been updated for a while.
We had a couple of issues with it that needed fixing, namely:
1. The output of the `diff()` function did not match the output of the `diff` function in the original JS library - [see this PR for more context](https://github.com/pulyaevskiy/quill-delta-dart/pull/27).
2. The `diff()` function was "splitting emojis in half" sometimes. For example, `insert('🔵').diff(insert('🔴'))` returned a partial emoji which really freaked out our document editing experience.

Additionally, we're most likely to need some other functionality that is out of scope of the Quill.js Delta format in the future.

As such, we've forked the dart package so that we have better control on features & bugfixes that Superlist needs.
