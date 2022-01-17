defmodule WorkflowDsl.Smtp do

  require Logger
  alias WorkflowDsl.Lang
  alias WorkflowDsl.Storages

  def send(params) do
    Logger.log(:debug, "execute :send, params: #{inspect params}")

    func = Storages.get_last_function_by(%{"module" => __MODULE__, "name" => :send})
    parameters = Enum.map(params, fn [k,v] ->
      {k, Lang.eval(func.session, v)}
    end)
    |> Enum.into(%{})

    context = create_context(parameters)

    email = create_email(parameters)

    Mailman.deliver(email, context)

  end

  defp create_context(parameters) do
    relay =
      with true <- Map.has_key?(parameters, "relay") do
        parameters["relay"]
      else
        _ -> ""
      end

    username =
      with true <- Map.has_key?(parameters, "username") do
        parameters["username"]
      else
        _ -> ""
      end

    password =
      with true <- Map.has_key?(parameters, "password") do
        parameters["password"]
      else
        _ -> ""
      end

    port =
      with true <- Map.has_key?(parameters, "port") do
        parameters["port"]
      else
        _ -> 0
      end

    tls =
      with true <- Map.has_key?(parameters, "tls") do
        String.to_existing_atom(parameters["tls"])
      else
        _ -> :always
      end

    %Mailman.Context{
      config: %Mailman.SmtpConfig{
          relay: relay,
          username: username,
          password: password,
          port: port,
          tls: tls,
          auth: :always,
      },
      composer: %Mailman.EexComposeConfig{}
    }
  end

  defp create_email(parameters) do
    subject =
      with true <- Map.has_key?(parameters, "subject") do
        parameters["subject"]
      else
        _ -> ""
      end

    from =
      with true <- Map.has_key?(parameters, "from") do
        parameters["from"]
      else
        _ -> ""
      end

    to =
      with true <- Map.has_key?(parameters, "to") do
        parameters["to"]
      else
        _ -> []
      end

    cc =
      with true <- Map.has_key?(parameters, "cc") do
        parameters["cc"]
      else
        _ -> []
      end

    bcc =
      with true <- Map.has_key?(parameters, "bcc") do
        parameters["bcc"]
      else
        _ -> []
      end

    text =
      with true <- Map.has_key?(parameters, "text") do
        parameters["text"]
      else
        _ -> ""
      end

    html =
      with true <- Map.has_key?(parameters, "html") do
        parameters["html"]
      else
        _ -> ""
      end

    %Mailman.Email{
      subject: subject,
      from: from,
      to: to,
      cc: cc,
      bcc: bcc,
      text: text,
      html: html
    }
  end
end
