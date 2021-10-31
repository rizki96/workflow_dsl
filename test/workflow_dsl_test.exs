defmodule WorkflowDslTest do
  use ExUnit.Case
  doctest WorkflowDsl

  alias WorkflowDsl.Utils.Randomizer
  require Logger

  setup do
    bypass = Bypass.open(port: 1234)
    {:ok, bypass: bypass}
  end

  test "greets the world" do
    assert WorkflowDsl.hello() == :world
  end

  test "workflows object translate to command", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      # We don't care about `request_path` or `method` for this test.
      Plug.Conn.resp(conn, 200, "")
    end)

    for n <- 1..4 do
      rand = Randomizer.randomizer(8)
      output = "./examples/workflow#{n}.json"
        |> WorkflowDsl.JsonExprParser.process(:file)
        |> WorkflowDsl.Interpreter.process(rand)
      Logger.log(:debug, "workflow#{n}: #{inspect output}")
    end
  end

  test "expression for in parser" do
    input = "${keys(map)}"
    output = input |> WorkflowDsl.LoopExprParser.parse_for_in()
    Logger.log(:debug, "loop expression ${keys(map)}: #{inspect output}")
    input = "${list}"
    output = input |> WorkflowDsl.LoopExprParser.parse_for_in()
    Logger.log(:debug, "loop expression ${list}: #{inspect output}")
  end

  test "expression for math ops" do
    input = "${sum + map[key]}"
    output = input |> WorkflowDsl.MathExprParser.parse_math()
    Logger.log(:debug, "math expression #{input}: #{inspect output}")

    input = "${sum // map.key}"
    output = input |> WorkflowDsl.MathExprParser.parse_math()
    Logger.log(:debug, "math expression #{input}: #{inspect output}")

    input = "${\"foo\" + \"bar\"}"
    output = input |> WorkflowDsl.MathExprParser.parse_math()
    Logger.log(:debug, "math expression #{input}: #{inspect output}")

    input = "${\"\\value_of_string? of (a) \"+string(a)}"
    output = input |> WorkflowDsl.MathExprParser.parse_math()
    Logger.log(:debug, "math expression #{input}: #{inspect output}")

    input = "${(1.0 * (2 + -3.5)) * (-sum)}"
    output = input |> WorkflowDsl.MathExprParser.parse_math()
    Logger.log(:debug, "math expression #{input}: #{inspect output}")
  end

  test "expression for logical ops" do
    input = "${currentTime.body.dayOfTheWeek == \"Friday\"}"
    output = input |> WorkflowDsl.CondExprParser.parse_cond()
    Logger.log(:debug, "cond expression #{input}: #{inspect output}")

    input = "${len(\"test\") >= 5}"
    output = input |> WorkflowDsl.CondExprParser.parse_cond()
    Logger.log(:debug, "cond expression #{input}: #{inspect output}")

    input = "${len(test) >= 5}"
    output = input |> WorkflowDsl.CondExprParser.parse_cond()
    Logger.log(:debug, "cond expression #{input}: #{inspect output}")

    input = "${currentTime[body][dayOfTheWeek] == True}"
    output = input |> WorkflowDsl.CondExprParser.parse_cond()
    Logger.log(:debug, "cond expression #{input}: #{inspect output}")

    input = "${currentTime.body.dayOfTheWeek == \"Saturday\" OR currentTime.body.dayOfTheWeek == \"Sunday\"}"
    output = input |> WorkflowDsl.CondExprParser.parse_cond()
    Logger.log(:debug, "cond expression #{input}: #{inspect output}")
  end

  test "eval math expression" do
    input = "${(1.0 * (2 + -3.5)) * 4}"
    {:ok, [result], _, _, _, _} = input |> WorkflowDsl.MathExprParser.parse_math()
    rand = Randomizer.randomizer(8)
    output = WorkflowDsl.Lang.eval(rand, result)
    Logger.log(:debug, "result for math op #{input}: #{inspect output}")

    input = "${\"Friday\" + \"Saturday\"}"
    {:ok, [result], _, _, _, _} = input |> WorkflowDsl.MathExprParser.parse_math()
    rand = Randomizer.randomizer(8)
    output = WorkflowDsl.Lang.eval(rand, result)
    Logger.log(:debug, "result for math op #{input}: #{inspect output}")
  end
end
