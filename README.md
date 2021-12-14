# workflow_dsl
Domain specific language based on [`Google Cloud Workflows`](https://cloud.google.com/workflows/docs/reference/syntax)

![workflow_dsl_demo](https://user-images.githubusercontent.com/822394/146069349-a3f237c2-b8c2-4d5c-ba69-32ccdaa7b7ec.gif)
    
# Install
- install erlang >= 22.x and elixir >= 1.12
- in your project file mix.exs, add
    ```
    defp deps do
    [
        {:workflow_dsl, git: "https://github.com/rizki96/workflow_dsl.git"},
    ]
    ```
- mix deps.get
- mix compile

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
