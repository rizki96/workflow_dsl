defmodule WorkflowDsl.ListMapExprParser do
  import NimbleParsec

  vars =
    utf8_string([?a..?z, ?A..?Z, ?_], min: 1)
    |> optional(utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_], min: 0))
    |> tag(:vars)

  defcombinatorp(:vars, vars)

  str =
    ignore(utf8_char([?"]))
    |> utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?,, ?-, ?+, ?*, ?/, ?%, ?=, ?&, ?\s, ?^, ?:, ?<, ?>, ?(, ?), ?;, ?', ?{, ?}, ?#, ?@, ??, ?!, ?~, ?`, ?|, ?\\,], min: 0)
    |> ignore(utf8_char([?"]))
    |> tag(:str)

  defcombinatorp(:str, str)

  nat = choice([
    parsec(:str),
    parsec(:vars),
    integer(min: 1) |> tag(:int),
  ])

  factor =
    choice(
      [
        ignore(ascii_char([?(]))
        |> ignore(optional(string(" ")))
        |> concat(parsec(:str_add))
        |> ignore(optional(string(" ")))
        |> ignore(ascii_char([?)])),
        nat
      ]
    )

  defcombinatorp :str_add,
                  choice(
                  [
                     factor
                     |> ignore(optional(string(" ")))
                     |> ignore(ascii_char([?+]))
                     |> ignore(optional(string(" ")))
                     |> concat(parsec(:str_add))
                     |> tag(:add),
                     factor
                  ]),
                  export_metadata: true

  defparsec(:parse_list_map, choice(
    [
      parsec(:vars)
      |> times(
        ignore(utf8_char([?.]))
        |> parsec(:vars),
        min: 1
      ),
      parsec(:vars)
      |> times(
        ignore(utf8_char([?[]))
        |> parsec(:vars)
        |> ignore(utf8_char([?]])),
        min: 1
      ),
      parsec(:vars)
      |> times(
        ignore(utf8_char([?[]))
        |> parsec(:str)
        |> ignore(utf8_char([?]])),
        min: 1
      ),
      parsec(:vars)
      |> times(
        ignore(utf8_char([?[]))
        |> parsec(:str_add)
        |> ignore(utf8_char([?]])),
        min: 1
      ),
      parsec(:vars),
    ]
  ), debug: true)

end
