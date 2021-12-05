# workflow_dsl
Domain specific language based on [`Google Cloud Workflow`](https://cloud.google.com/workflows/docs/reference/syntax)

[![asciicast](https://asciinema.org/a/HGeSZaQTh7t2EgLD8ONrDpTMp.svg)](https://asciinema.org/a/HGeSZaQTh7t2EgLD8ONrDpTMp)

# Install
    - install erlang >= 22.x and elixir >= 1.12
    - mix deps.get
    - mix test

# Command line
    - mix wf_run <json workflow file path / URL> [--verbose]

# Features
    - [x] JSON input format
    - [x] assign
    - [x] for in
    - [x] for range
    - [x] switch, condition
    - [x] steps (for in, for range, switch)
    - [x] return
    - [x] call, args, result, body
    - [x] next
    - [ ] try, except
    - [ ] subworkflows
    - [ ] YAML input format
    - [ ] error messages

# License
    LGPL-2.1
