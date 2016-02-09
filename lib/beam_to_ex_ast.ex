defmodule BeamToExAst do
    def convert(list) do
        {mod_name, rest} = Enum.reduce(list, {"", []}, &do_convert/2)
        case length(rest) do
            1 -> {:defmodule, [line: 1],
            [{:__aliases__, [counter: 0, line: 1], [mod_name]},
             [do: List.first(rest)]]}
            _ -> {:defmodule, [line: 1],
            [{:__aliases__, [counter: 0, line: 1], [mod_name]},
             [do: {:__block__, [], rest}]]}
            
        end
    end

    #_n is number of parameters
    #ln is the line number
    def do_convert({:attribute, _ln, :module, name}, {_, rest}) do
        {clean_module(name), rest}
    end

    def do_convert({:attribute, _, _, _}, acc) do
        acc
    end

    def do_convert({:function, _, :__info__, _, _}, acc) do
        acc
    end

    def do_convert({:function, ln, name, _n, body}, {mod_name, rest}) do
        case body do
            [{:clause, ln2, params, _guard, def_body}] ->
                {mod_name, [{:def,
                             [line: ln],
                             [{name,
                               [line: ln2],
                               convert_params(params)
                              },
                              def_body(def_body)
                             ]
                            } | rest]}
            _ -> IO.error(body)
        end
    end

    def do_convert({:eof, _ln}, acc) do
        acc
    end

    def def_body(items) do
        case length(items) do
            1 -> [do: convert_param(List.first(items))]
            _ -> [do: {:__block__, [], Enum.map(items, &convert_param/1)}]
        end
    end

    def get_caller(c_mod_call, ln, caller, params) do
        case String.match?(c_mod_call, ~r/^[A-Z]/) do
            true -> {{:., [line: ln],
                            [{:__aliases__, [counter: 0, line: ln],
                              [String.to_atom(c_mod_call)]},
                             clean_atom(caller)]},
                           [line: ln], convert_params(params)}
            false -> {{:., [line: ln],
                            [String.to_atom(c_mod_call), clean_atom(caller)]},
                           [line: ln], convert_params(params)}
        end
    end

    def def_caller({:remote, ln,{:atom, _, mod_call},
                    {:atom, _, caller}}, params) do
        case half_clean_atom(mod_call) do
            "Kernel" -> {caller, [line: ln],  convert_params(params)}
            c_mod_call -> get_caller(c_mod_call, ln, caller, params)
        end
    end

    def def_caller({:atom, ln, caller}, params) do
        {caller, [line: ln], convert_params(params)}
    end

    def convert_params(params) do
        Enum.map(params, &convert_param/1)
    end

    def convert_param({:call, _ln, caller, params}) do
        def_caller(caller, params)
    end

    def convert_param({:match, ln, m1, m2}) do
        {:=, [line: ln], [convert_param(m1), convert_param(m2)]}
    end

    def convert_param({:var, ln, var}) do
        {clean_var(var), [line: ln], nil}
    end

    def convert_param({:bin, _ln, elements}) do
        convert_bin(List.first(elements))
    end

    def convert_param({:string, _ln, s1}) do
        s1
    end

    def convert_param({:integer, _ln, i1}) do
        i1
    end

    def convert_param({:float, _ln, f1}) do
        f1
    end

    def convert_param({:atom, _ln, a1}) do
        a1
    end

    def convert_param({:cons, _ln, c1, c2}) do
        [convert_param(c1) | convert_param(c2)]
    end

    def convert_param({:tuple, ln, items}) do
        {:{}, [line: ln], Enum.map(items, &convert_param/1)}
    end

    def convert_param({:map, ln, items}) do
        {:%{}, [line: ln], Enum.map(items, &convert_param/1)}
    end

    def convert_param({:map_field_assoc, _ln, key, val}) do
        {convert_param(key), convert_param(val)}
    end

    def convert_param({:op, ln, op1, p1, p2}) do
        {clean_op(op1), [line: ln], [convert_param(p1), convert_param(p2)]}
    end

    def convert_param({nil, _ln}) do
        []
    end

    def convert_bin({:bin_element, ln, {:string, ln, str}, _, _}) do
        to_string(str)
    end

    def clean_op(op1) do
        s1 = Atom.to_string(op1)
        case s1 do
            "=:=" -> "==="
            "=/=" -> "!=="
            "/=" -> "!="
            "=<" -> "<="
            _ -> s1
        end
        |> String.to_atom
    end

    def clean_module(a1) do
        s1 = Atom.to_string(a1)
        s1 = String.replace(s1, "Elixir.", "")
        s1 = case String.match?(s1, ~r/^[A-Z]/) do
            true -> s1
            false -> Macro.camelize(s1)
        end
        String.to_atom(s1)
    end

    def clean_atom(a1) do
        s1 = Atom.to_string(a1)
        String.to_atom(String.replace(s1, "Elixir.", ""))
    end

    def half_clean_atom(a1) do
        s1 = Atom.to_string(a1)
        String.replace(s1, "Elixir.", "")
    end

    def clean_var(v1) do
        s1 = Atom.to_string(v1)
        String.to_atom(String.replace(s1, ~r/@\d+/, ""))
    end
end
