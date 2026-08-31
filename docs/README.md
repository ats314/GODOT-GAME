# Documentation index

Routing by the question you arrived with. `../CLAUDE.md` is the entry point for agents;
this is the map of everything behind it.

## Project state

| Question | Document |
| --- | --- |
| What has been decided, and what is still open? | [DECISIONS.md](./DECISIONS.md) |
| What are we shipping, on what platforms, on what hardware? | [PLATFORM_TARGETS.md](./PLATFORM_TARGETS.md) |
| What game concepts were explored, and how were they scored? | [GAME_CONCEPT_DECISION.md](./GAME_CONCEPT_DECISION.md) |

**Read `DECISIONS.md` first.** No game concept is committed, and it records what was
already rejected so it does not get proposed again.

## Building and verifying

| Question | Document |
| --- | --- |
| Can I test a Godot game without a GPU, and what does that prove? | [TESTING.md](./TESTING.md) |
| How do I work effectively in a Codespace or cloud container? | [CODESPACES.md](./CODESPACES.md) |
| How do I write correct Godot 4.7 GDScript? | [../library/guides/](../library/guides/README.md) |

## Finding code and resources

| Question | Document |
| --- | --- |
| What does each vendored project teach, and what should I reuse? | [GODOT_CODE_SURVEY.md](./GODOT_CODE_SURVEY.md) |
| Does a free, licence-verified solution already exist for this? | [RESOURCES.md](./RESOURCES.md) |
| What is the exact API for a Godot class? | `grep -i 'thing' ../library/api/symbols.tsv` |
| Which vendored script implements this? | `grep -i 'thing' ../library/code/scripts.tsv` |
| What have we actually copied into this repo, and under what licence? | [../THIRD_PARTY_LICENSES.md](../THIRD_PARTY_LICENSES.md) |

## Generated files — do not hand-edit

| File | Regenerate with |
| --- | --- |
| `RESOURCES.md` | `python3 ../tools/build_resources_doc.py` (source: `../library/resources.json`) |
| `../library/api/*.tsv` | `python3 ../tools/build_api_index.py` |
| `../library/code/*.tsv` | `python3 ../tools/build_code_index.py` |

CI fails if the committed indexes do not match the tree, so regenerate and commit them
whenever you vendor something.

## Caveats worth knowing before you trust a document

- **`GODOT_CODE_SURVEY.md`** describes `third_party/` accurately, but its "reuse for our
  game" judgements were written for the abandoned ACCRETE concept and are stale.
- **`RESOURCES.md`** is a catalogue of what exists upstream, **not** a list of what is
  vendored. 39 of its entries are flagged unusable on licence grounds.
- **`GAME_CONCEPT_DECISION.md`** records a recommendation the owner rejected. It is
  history, not a plan; `DECISIONS.md` supersedes it.
- **`library/guides/`** is three files short of its intended set and has not had a
  cross-linking pass — see its own README.
