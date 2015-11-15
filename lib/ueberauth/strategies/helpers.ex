defmodule Ueberauth.Strategy.Helpers do
  @moduledoc """
  Provides helper methods for use within your strategy. These helpers are provided as a convenience for accessing the options passed to the specific pipelined strategy, considering the pipelined options and falling back to defaults.
  """
  import Plug.Conn
  alias Ueberauth.Failure
  alias Ueberauth.Failure.Error

  @doc """
  Provides the name of the strategy or provider name. This is defined in your configuration as the provider name.
  """
  @spec strategy_name(Plug.t) :: String.t
  def strategy_name(conn), do: from_private(conn, :strategy_name)

  @doc """
  The strategy module that is being used for the request.
  """
  @spec strategy(Plug.t) :: Module.t
  def strategy(conn), do: from_private(conn, :strategy)

  @doc """
  The request path for the strategy to hit. Requests to this path will trigger the `request_phase` of the strategy.
  """
  @spec request_path(Plug.t) :: String.t
  def request_path(conn), do: from_private(conn, :request_path)

  @doc """
  The callback path for the requests strategy. When a client hits this path, the callback phase will be triggered for the strategy.
  """
  @spec callback_path(Plug.t) :: String.t
  def callback_path(conn), do: from_private(conn, :callback_path)

  @doc """
  The full url (based on the current requests host, scheme) for the request phase for the requests strategy.

  The options will be encoded as query params.
  """
  @spec request_url(Plug.t) :: String.t
  def request_url(conn, opts \\ []), do: full_url(conn, request_path(conn), opts)

  @doc """
  The full url (based on the current requests host, scheme) for the callback phase for the requests strategy.

  The options will be encoded as query params.
  """
  @spec callback_url(Plug.t) :: String.t
  def callback_url(conn, opts \\ []), do: full_url(conn, callback_path(conn), opts)

  @doc """
  The configured allowed callback http methods. This will use any supplied options from the configuration, but fallback to the default options
  """
  @spec allowed_callback_methods(Plug.t) :: list(String.t)
  def allowed_callback_methods(conn), do: from_private(conn, :callback_methods)

  @doc """
  Is the current request http method one of the allowed callback methods?
  """
  @spec allowed_callback_method?(Plug.t) :: boolean
  def allowed_callback_method?(%{method: method} = conn) do
    conn
    |> allowed_callback_methods
    |> Enum.member?(to_string(method) |> String.upcase)
  end

  @doc """
  The full list of options passed to the strategy in the configuration.
  """
  @spec options(Plug.t) :: Keyword.t
  def options(conn), do: from_private(conn, :options)

  @doc """
  A helper for constructing error entries on failure.

  The `message_key` is intended for use by machines for translations etc.
  The message is a human readable error message.

  #### Example

      error("something_bad", "Something really bad happened")
  """
  @spec error(String.t, String.t) :: Error.t
  def error(key, message), do: struct(Error, message_key: key, message: message)

  @doc """
  Sets a failure onto the connection containing a List of errors.

  During your callback phase, this should be called to 'fail' the authentication request and include a collection of errors outlining what the problem is.

  Note this changes the conn object and should be part of your returned connection of the `callback_phase!`.
  """
  @spec error(Plug.Conn.t, list(Error.t)) :: Plug.Conn
  def set_errors!(conn, errors) do
    failure = struct(
      Failure,
      provider: strategy_name(conn),
      strategy: strategy(conn),
      errors: map_errors(errors)
    )

    Plug.Conn.assign(conn, :ueberauth_failure, failure)
  end

  @doc """
  Redirects to a url and halts the plug pipeline.
  """
  @spec redirect!(Plug.Conn.t, String.t) :: Plug.Conn.t
  def redirect!(conn, url) do
    html = Plug.HTML.html_escape(url)
    body = "<html><body>You are being <a href=\"#{html}\">redirected</a>.</body></html>"

    conn
    |> put_resp_header("location", url)
    |> send_resp(conn.status || 302, body)
    |> halt
  end

  @doc false
  defp from_private(conn, key) do
    opts = conn.private[:ueberauth_request_options]
    if opts, do: opts[key], else: nil
  end

  @doc false
  defp full_url(conn, path, opts \\ []) do
    %URI{
      host: conn.host,
      scheme: to_string(conn.scheme),
      port: conn.port,
      path: path,
      query: URI.encode_query(opts)
    }
    |> to_string
  end

  @doc false
  defp map_errors(nil), do: []
  @doc false
  defp map_errors([]), do: []
  @doc false
  defp map_errors(%Error{} = error), do: [error]
  @doc false
  defp map_errors(errors), do: Enum.map(errors, &p_error/1)

  @doc false
  defp p_error(%Error{} = error), do: error
  @doc false
  defp p_error(%{} = error), do: struct(Error, error)
  @doc false
  defp p_error(error) when is_list(error), do: struct(Error, error)
end