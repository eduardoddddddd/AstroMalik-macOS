# Corpus Consolidation Pipeline

This pipeline keeps research material out of production until it is cited and reviewed.
It downloads public-domain or publicly hosted sources, extracts text when local tools
are available, imports legacy Horaria/Lilly research material into staging, and creates a
semaphore report.

## Commands

```bash
python3 scripts/corpus_pipeline.py all
python3 scripts/corpus_pipeline.py smoke-test
```

Generated files live under `corpus_sources/raw`, `corpus_sources/text`,
`corpus_sources/staging`, and `corpus_sources/reports`. These directories are ignored
by Git because they contain large downloads, OCR output, and generated SQLite/CSV
artifacts.

## Semaphore Rules

- `green`: public or already verified traditional source, citation present, text present.
- `yellow`: useful candidate, indirect doctrine, inferred reference, modern source, or needs human mapping.
- `red`: no citation, no text, failed extraction, or blocked copyright/reuse status.

## Human Or External-Model Tasks

- Review generated candidate passages for the 29 primary direction seed keys.
- Keep Frawley, Dykes, Zoller, Barclay, or any modern copyrighted material out of green status unless legal excerpts and human approval are supplied.
- Decide whether Horaria doctrine is direct evidence for a target module or only supporting doctrine. Horaria itself now has a native Swift engine; this pipeline is only for corpus research and citation review.
- Translate and polish final Spanish text only after the citation and scope are locked.
- Promote entries from staging to production only with a reviewed citation trail.

## Notes

The current production database remains untouched. The staging database is generated at
`corpus_sources/staging/corpus_staging.sqlite`, and CSV exports are produced beside it
for model-assisted review.
