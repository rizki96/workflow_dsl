defmodule WorkflowDsl.MathExprParser do
  import NimbleParsec

  # math_oper = +, -, *, /, %, //, (), <, >, <=, >=, ==, !=, .

  # nat    := 0..9 (min: 1) | vars | neg_vars | str | double | len | int | bool
  # factor := ( math_eq ) | nat
  # math_rem := factor % math_rem | factor
  # math_flr := math_rem // math_flr | math_rem
  # math_div := math_flr / math_div | math_flr
  # math_mul := math_div * math_mul | math_div
  # math_sub := math_mul - math_sub | math_mul
  # math_add := math_sub + math_add | math_sub

  vars =
    utf8_string([?a..?z, ?A..?Z, ?_], min: 1)
    |> optional(utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?., ?[, ?], ?"], min: 0))
    |> tag(:vars)

  defcombinatorp(:vars, vars)

  neg_vars =
    ignore(utf8_char([?-]))
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
      str_conv,
      str,
    ])
  )

  len =
    string("len")
    |> ignore(string("("))
    |> choice([
        parsec(:return_str),
        parsec(:vars)
      ])
    |> ignore(string(")"))
    |> tag(:len)

  int_conv =
    string("int")
    |> ignore(string("("))
    |> parsec(:vars)
    |> ignore(string(")"))
    |> tag(:int)

  defparsecp(:return_int,
    choice([
      len,
      int_conv
    ])
  )

  double_conv =
    string("double")
    |> ignore(string("("))
    |> parsec(:vars)
    |> ignore(string(")"))
    |> tag(:double)

  defparsecp(:return_double,
    choice([
      double_number,
      double_conv
    ])
  )

  bool_val = choice([
    string("true"),
    string("false"),
    string("True"),
    string("False"),
    string("1"),
    string("0")
  ])

  defparsecp(:return_bool,
    bool_val
  )

  nat = choice([
    parsec(:return_int),
    parsec(:return_double),
    parsec(:return_str),
    parsec(:neg_vars),
    parsec(:vars),
    #parsec(:return_bool),
    integer(min: 1) |> tag(:int),
  ])

  factor =
    choice(
      [
        ignore(ascii_char([?(]))
        |> ignore(optional(string(" ")))
        |> concat(parsec(:math_add))
        |> ignore(optional(string(" ")))
        |> ignore(ascii_char([?)])),
        nat
      ]
    )

  # Recursive definitions require using defparsec with the parsec combinator
  #
  # Note we use export_metadata: true for the generator functionality,
  # it is not required if you are only doing parsing.

  defcombinatorp :math_rem,
                  choice(
                  [
                    factor
                    |> ignore(optional(string(" ")))
                    |> ignore(ascii_char([?%]))
                    |> ignore(optional(string(" ")))
                    |> concat(parsec(:math_rem))
                    |> tag(:rem),
                    factor
                  ]
                 ),
                 #gen_weights: [1, 3],
                 export_metadata: true

  defcombinatorp :math_flr,
                  choice(
                  [
                    parsec(:math_rem)
                    |> ignore(optional(string(" ")))
                    |> ignore(string("//"))
                    |> ignore(optional(string(" ")))
                    |> concat(parsec(:math_flr))
                    |> tag(:flr),
                    parsec(:math_rem)
                  ]
                 ),
                 export_metadata: true

  defcombinatorp :math_div,
                  choice(
                  [
                    parsec(:math_flr)
                    |> ignore(optional(string(" ")))
                    |> ignore(ascii_char([?/]))
                    |> ignore(optional(string(" ")))
                    |> concat(parsec(:math_div))
                    |> tag(:div),
                    parsec(:math_flr)
                  ]
                 ),
                 export_metadata: true

  defcombinatorp :math_mul,
                  choice(
                  [
                    parsec(:math_div)
                    |> ignore(optional(string(" ")))
                    |> ignore(ascii_char([?*]))
                    |> ignore(optional(string(" ")))
                    |> concat(parsec(:math_mul))
                    |> tag(:mul),
                    parsec(:math_div)
                  ]),
                  export_metadata: true

  defcombinatorp :math_sub,
                  choice(
                  [
                    parsec(:math_mul)
                    |> ignore(optional(string(" ")))
                    |> ignore(ascii_char([?-]))
                    |> ignore(optional(string(" ")))
                    |> concat(parsec(:math_sub))
                    |> tag(:sub),
                    parsec(:math_mul)
                  ]),
                  export_metadata: true

  defcombinatorp :math_add,
                  choice(
                  [
                     parsec(:math_sub)
                     |> ignore(optional(string(" ")))
                     |> ignore(ascii_char([?+]))
                     |> ignore(optional(string(" ")))
                     |> concat(parsec(:math_add))
                     |> tag(:add),
                     parsec(:math_sub)
                  ]),
                  export_metadata: true

  defparsec :parse_math,
          ignore(string("${"))
          |> parsec(:math_add)
          |> ignore(string("}")),
          #debug: true,
          export_metadata: true

end
