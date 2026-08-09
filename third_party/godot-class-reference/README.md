# Godot 4.7.1 class reference (vendored XML)

The engine's own API documentation source, taken from the `4.7.1-stable` tag of
[godotengine/godot](https://github.com/godotengine/godot) — the exact build our CI
downloads. Because it ships *with* the engine, it is authoritative for our target
version in a way that a web search or a model's memory is not.

`classes/` holds one XML file per class, 1078 of them, flattened from three upstream
locations (`doc/classes/`, `modules/*/doc_classes/`, `platform/*/doc_classes/`). There
are no name collisions, so the flat layout is safe and makes lookup one hop.

## Using it

Read a class you can already name:

```bash
less third_party/godot-class-reference/classes/GPUParticles2D.xml
```

Search across every class — usually faster via the generated tables in `library/api/`:

```bash
grep -P '^GPUParticles2D\t' library/api/symbols.tsv      # every member of one class
grep -i 'pitch_scale' library/api/symbols.tsv            # which class has this?
grep -P '\tsignal\t' library/api/symbols.tsv | grep -i body   # find a signal by topic
```

Regenerate those tables after re-vendoring: `python3 tools/build_api_index.py`.

## Re-vendoring a newer engine version

```bash
git init godot-ref && cd godot-ref
git remote add origin https://github.com/godotengine/godot
git config core.sparseCheckout true
git sparse-checkout set --no-cone 'doc/classes' 'modules/*/doc_classes' \
    'platform/*/doc_classes' 'LICENSE.txt' 'COPYRIGHT.txt' 'AUTHORS.md'
git fetch --depth 1 --filter=blob:none origin refs/tags/<VERSION>-stable
git checkout FETCH_HEAD
```

Then copy every `doc_classes` XML into `classes/`, update the commit and tag recorded in
`THIRD_PARTY_LICENSES.md`, and rerun `tools/build_api_index.py`.

## Licence

MIT — see `LICENSE.txt`, `COPYRIGHT.txt`, `AUTHORS.md` in this directory.
