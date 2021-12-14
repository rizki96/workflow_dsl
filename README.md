# workflow_dsl
Domain specific language based on [`Google Cloud Workflows`](https://cloud.google.com/workflows/docs/reference/syntax)

![workflow_dsl](https://user-images.githubusercontent.com/822394/144881919-77998e36-c4f9-40b2-ba69-5455a382b887.gif)
    
# Install
- install erlang >= 22.x and elixir >= 1.12
- in file mix.exs add below to `defp deps do`
    `[
        {:workflow_dsl, git: "https://github.com/rizki96/workflow_dsl.git"},
    ]`
- mix deps.get
- mix test

# Command line
- mix wf.run <json workflow file path / URL> [--verbose]

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
- [ ] try, retry, except
- [ ] subworkflows
- [ ] YAML input format
- [ ] error messages

# License
    LGPL-2.1
