# Contributing

Thanks for contributing.

## Development Principles
- Keep changes reproducible and distribution-agnostic where possible.
- Prefer minimal, testable changes.
- Document kernel-version assumptions explicitly.
- Do not commit binaries, private keys, or firmware blobs that cannot be legally redistributed.

## Pull Request Expectations
- Include a clear problem statement and expected behavior.
- Include exact validation commands and outputs.
- Update `README.md` and relevant `docs/*.md` when behavior changes.
- Keep scripts POSIX/Bash-compatible and shellcheck-clean where practical.

## Commit Guidance
- Use focused commits with descriptive subjects.
- Example: `mt7927: fix btusb build path for kernel 6.17`.

## Safety Notice
This repository contains low-level system modifications.
Contributors should assume users run this at their own risk.
