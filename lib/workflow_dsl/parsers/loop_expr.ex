defmodule WorkflowDsl.LoopExprParser do
  import NimbleParsec

  for_in_expr =
    ignore(string("${"))
    |> parsec(:return_list)
    |> ignore(string("}"))

  defparsec(:parse_for_in, for_in_expr)

  vars =
    utf8_string([?a..?z, ?A..?Z, ?_], min: 1)
    |> optional(utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?., ?[, ?], ?"], min: 0))
    |> tag(:vars)

  keys =
    string("keys")
    |> ignore(string("("))
    |> parsec(:vars)
    |> ignore(string(")"))
    |> tag(:list)

  defcombinatorp(:vars, vars)

  defcombinatorp(:return_list,
    choice([
      keys,
      vars
    ])
  )

  neg_vars =
    ignore(utf8_string([?-], min: 1))
    |> parsec(:vars)
    |> tag(:neg_vars)

  defcombinatorp(:neg_vars, neg_vars)

  double_number =
    utf8_string([?0..?9, ?., ?-], min: 2)
    |> tag(:double)

  defcombinatorp(:double_number, double_number)

  str =
    ignore(utf8_char([?"]))
    |> utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?., ?,, ?-, ?+, ?*, ?/, ?%, ?[, ?], ?=, ?&, ?\s, ?^, ?:, ?<, ?>, ?(, ?), ?;, ?', ?{, ?}, ?#, ?@, ??, ?!, ?~, ?`, ?|, ?\\,], min: 0)
    |> ignore(utf8_char([?"]))
    |> tag(:str)

  str_conv =
    string("string")
    |> ignore(string("("))
    |> parsec(:vars)
    |> ignore(string(")"))
    |> tag(:str)

  defparsecp(:return_str,
    choice([
      str,
      str_conv
    ])
  )

  len =
    string("len")
    |> ignore(string("("))
    |> parsec(:return_str)
    |> ignore(string(")"))
    |> tag(:int)

  int =
    string("int")
    |> ignore(string("("))
    |> parsec(:vars)
    |> ignore(string(")"))
    |> tag(:int)

  defparsecp(:return_int,
    choice([
      len,
      int
    ])
  )

  min_max =
    optional(ignore(ascii_char([?"])))
    |> choice([
      integer(min: 1) |> tag(:int),
      parsec(:return_int),
      parsec(:double_number),
      ignore(string("${"))
      |> parsec(:neg_vars)
      |> ignore(string("}")),
      ignore(string("${"))
      |> parsec(:vars)
      |> ignore(string("}"))
    ])
    |> optional(ignore(ascii_char([?"])))

  defcombinatorp(:min_max, min_max)

  for_range_expr =
    ignore(string("["))
    |> parsec(:min_max)
    |> tag(:min)
    |> ignore(string(","))
    |> parsec(:min_max)
    |> tag(:max)
    |> ignore(string("]"))

  defparsec(:parse_for_range, for_range_expr)
end
