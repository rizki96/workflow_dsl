defmodule WorkflowDsl.CondExprParser do
  import NimbleParsec

  #logical_oper = # in, and, or
  #negation_oper # not
  #num_comparison_oper # >, <, >=, <=, ==, !=, ()

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

  bool_vals =
    choice([
      string("true"),
      string("false"),
      string("True"),
      string("False"),
      #string("1"),
      #string("0")
    ])
    |> tag(:bool)

  defparsecp(:bool_vals,
    bool_vals
  )

  negation_conv =
    string("not")
    |> ignore(string("("))
    |> parsec(:vars)
    |> ignore(string(")"))
    |> tag(:not)

  defparsecp(:return_bool,
    choice([
      bool_vals,
      negation_conv
    ])
  )

  nat = choice([
    parsec(:return_int),
    parsec(:return_double),
    parsec(:return_str),
    parsec(:return_bool),
    parsec(:neg_vars),
    parsec(:vars),
    integer(min: 1) |> tag(:int),
  ])

  factor =
    choice(
      [
        ignore(ascii_char([?(]))
        |> ignore(optional(string(" ")))
        |> concat(parsec(:cond_and))
        |> ignore(optional(string(" ")))
        |> ignore(ascii_char([?)])),
        ignore(choice([
          string("NOT"),
          string("not")
          ]))
        |> ignore(ascii_char([?(]))
        |> ignore(optional(string(" ")))
        |> concat(parsec(:cond_and))
        |> ignore(optional(string(" ")))
        |> ignore(ascii_char([?)]))
        |> tag(:not),
        nat
      ]
    )

  defcombinatorp :cond_gt,
                  choice(
                  [
                    factor
                     |> ignore(optional(string(" ")))
                     |> ignore(ascii_char([?>]))
                     |> ignore(optional(string(" ")))
                     |> concat(parsec(:cond_gt))
                     |> tag(:gt),
                    factor
                  ]),
                  export_metadata: true

  defcombinatorp :cond_gte,
                  choice(
                  [
                     parsec(:cond_gt)
                     |> ignore(optional(string(" ")))
                     |> ignore(string(">="))
                     |> ignore(optional(string(" ")))
                     |> concat(parsec(:cond_gte))
                     |> tag(:gte),
                     parsec(:cond_gt)
                  ]),
                  export_metadata: true

  defcombinatorp :cond_lt,
                  choice(
                  [
                     parsec(:cond_gte)
                     |> ignore(optional(string(" ")))
                     |> ignore(ascii_char([?<]))
                     |> ignore(optional(string(" ")))
                     |> concat(parsec(:cond_lt))
                     |> tag(:lt),
                     parsec(:cond_gte)
                  ]),
                  export_metadata: true

  defcombinatorp :cond_lte,
                  choice(
                  [
                     parsec(:cond_lt)
                     |> ignore(optional(string(" ")))
                     |> ignore(string("<="))
                     |> ignore(optional(string(" ")))
                     |> concat(parsec(:cond_lte))
                     |> tag(:lte),
                     parsec(:cond_lt)
                  ]),
                  export_metadata: true

  defcombinatorp :cond_neq,
                  choice(
                  [
                     parsec(:cond_lte)
                     |> ignore(optional(string(" ")))
                     |> ignore(string("!="))
                     |> ignore(optional(string(" ")))
                     |> concat(parsec(:cond_neq))
                     |> tag(:neq),
                     parsec(:cond_lte)
                  ]),
                  export_metadata: true

  defcombinatorp :cond_eq,
                  choice(
                  [
                     parsec(:cond_neq)
                     |> ignore(optional(string(" ")))
                     |> ignore(string("=="))
                     |> ignore(optional(string(" ")))
                     |> concat(parsec(:cond_eq))
                     |> tag(:eq),
                     parsec(:cond_neq)
                  ]),
                  export_metadata: true

  defcombinatorp :cond_in,
                  choice(
                  [
                     parsec(:cond_eq)
                     |> ignore(optional(string(" ")))
                     |> ignore(choice([
                      string("IN"),
                      string("in")
                      ]))
                     |> ignore(optional(string(" ")))
                     |> concat(parsec(:cond_in))
                     |> tag(:in),
                     parsec(:cond_eq)
                  ]),
                  export_metadata: true

  defcombinatorp :cond_or,
                  choice(
                  [
                     parsec(:cond_in)
                     |> ignore(optional(string(" ")))
                     |> ignore(choice([
                       string("OR"),
                       string("or")
                       ]))
                     |> ignore(optional(string(" ")))
                     |> concat(parsec(:cond_or))
                     |> tag(:or),
                     parsec(:cond_in)
                  ]),
                  export_metadata: true

  defcombinatorp :cond_and,
                  choice(
                  [
                     parsec(:cond_or)
                     |> ignore(optional(string(" ")))
                     |> ignore(choice([
                      string("AND"),
                      string("and")
                      ]))
                     |> ignore(optional(string(" ")))
                     |> concat(parsec(:cond_and))
                     |> tag(:and),
                     parsec(:cond_or)
                  ]),
                  export_metadata: true

  defparsec :parse_cond,
          ignore(string("${"))
          |> parsec(:cond_and)
          |> ignore(string("}")),
          #debug: true,
          export_metadata: true

end
