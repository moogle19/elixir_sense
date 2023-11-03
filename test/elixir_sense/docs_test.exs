defmodule ElixirSense.DocsTest do
  use ExUnit.Case, async: true

  test "when no docs do not return Built-in type" do
    buffer = """
    hkjnjknjk
    """

    refute ElixirSense.docs(buffer, 1, 2)
  end

  test "when empty buffer" do
    assert nil == ElixirSense.docs("", 1, 1)
  end

  describe "module docs" do
    test "module with @moduledoc false" do
      %{
        docs: [doc]
      } = ElixirSense.docs("ElixirSenseExample.ModuleWithDocFalse", 1, 22)

      assert doc == %{
               module: ElixirSenseExample.ModuleWithDocFalse,
               metadata: %{hidden: true},
               docs: "",
               kind: :module
             }
    end

    test "module with no @moduledoc" do
      %{
        docs: [doc]
      } = ElixirSense.docs("ElixirSenseExample.ModuleWithNoDocs", 1, 22)

      assert doc == %{
               module: ElixirSenseExample.ModuleWithNoDocs,
               metadata: %{},
               docs: "",
               kind: :module
             }
    end

    test "retrieve documentation from modules" do
      buffer = """
      defmodule MyModule do
        use GenServer
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 2, 8)

      assert doc.module == GenServer
      assert doc.metadata == %{}
      assert doc.kind == :module

      assert doc.docs =~ """
             A behaviour module for implementing the server of a client-server relation.\
             """
    end

    test "retrieve documentation from metadata modules" do
      buffer = """
      defmodule MyLocalModule do
        @moduledoc "Some example doc"
        @moduledoc since: "1.2.3"

        @callback some() :: :ok
      end

      defmodule MyModule do
        @behaviour MyLocalModule
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 9, 15)

      assert doc == %{module: MyLocalModule, metadata: %{}, docs: "", kind: :module}

      # TODO doc and metadata
    end

    test "retrieve documentation from metadata modules on __MODULE__" do
      buffer = """
      defmodule MyLocalModule do
        @moduledoc "Some example doc"
        @moduledoc since: "1.2.3"

        def self() do
          __MODULE__
        end
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 6, 6)

      assert doc == %{module: MyLocalModule, metadata: %{}, docs: "", kind: :module}

      # TODO doc and metadata
    end

    @tag requires_elixir_1_14: true
    test "retrieve documentation from metadata modules on __MODULE__ submodule" do
      buffer = """
      defmodule MyLocalModule do
        defmodule Sub do
          @moduledoc "Some example doc"
          @moduledoc since: "1.2.3"
        end

        def self() do
          __MODULE__.Sub
        end
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 8, 17)

      assert doc == %{module: MyLocalModule.Sub, metadata: %{}, docs: "", kind: :module}

      # TODO doc and metadata
    end

    test "retrieve documentation from metadata modules with @moduledoc false" do
      buffer = """
      defmodule MyLocalModule do
        @moduledoc false

        @callback some() :: :ok
      end

      defmodule MyModule do
        @behaviour MyLocalModule
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 8, 15)

      assert doc == %{module: MyLocalModule, metadata: %{}, docs: "", kind: :module}

      # TODO mark as hidden
    end

    test "retrieve documentation from erlang modules" do
      buffer = """
      defmodule MyModule do
        alias :erlang, as: Erl
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 2, 13)

      assert doc.module == :erlang
      assert doc.kind == :module

      if ExUnitConfig.erlang_eep48_supported() do
        assert doc.docs =~ """
               By convention,\
               """

        assert %{name: "erlang", otp_doc_vsn: {1, 0, 0}} = doc.metadata
      end
    end

    test "retrieve documentation from modules in 1.2 alias syntax" do
      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.ModuleWithDocs
        alias ElixirSenseExample.{Some, ModuleWithDocs}
      end
      """

      %{
        docs: docs_1
      } = ElixirSense.docs(buffer, 2, 30)

      %{
        docs: docs_2
      } = ElixirSense.docs(buffer, 2, 38)

      assert docs_1 == docs_2
    end

    test "existing module with no docs" do
      buffer = """
      defmodule MyModule do
        raise BadStructError, "Error"
      end
      """

      %{docs: [doc]} = ElixirSense.docs(buffer, 2, 11)

      assert doc == %{module: BadStructError, metadata: %{}, docs: "", kind: :module}
    end

    test "not existing module docs" do
      buffer = """
      defmodule MyModule do
        raise NotExistingError, "Error"
      end
      """

      refute ElixirSense.docs(buffer, 2, 11)
    end
  end

  describe "functions and macros" do
    test "retrieve documentation from Kernel macro" do
      buffer = """
      defmodule MyModule do

      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 1, 2)

      assert %{
               args: ["alias", "do_block"],
               function: :defmodule,
               module: Kernel,
               metadata: %{},
               specs: [],
               kind: :macro
             } = doc

      assert doc.module == Kernel
      assert doc.function == :defmodule

      assert doc.docs =~ """
             Defines a module given by name with the given contents.
             """
    end

    test "retrieve documentation from Kernel.SpecialForm macro" do
      buffer = """
      defmodule MyModule do
        import List
         ^
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 2, 4)

      assert %{
               args: ["module", "opts"],
               function: :import,
               module: Kernel.SpecialForms,
               metadata: %{},
               specs: [],
               kind: :macro
             } = doc

      assert doc.docs =~ """
             Imports functions and macros\
             """
    end

    test "function with @doc false" do
      %{
        docs: [doc]
      } = ElixirSense.docs("ElixirSenseExample.ModuleWithDocs.some_fun_doc_false(1)", 1, 40)

      assert doc == %{
               module: ElixirSenseExample.ModuleWithDocs,
               metadata: %{hidden: true, defaults: 1},
               docs: "",
               kind: :function,
               args: ["a", "b \\\\ nil"],
               arity: 2,
               function: :some_fun_doc_false,
               specs: []
             }
    end

    test "function no @doc" do
      %{
        docs: [doc]
      } = ElixirSense.docs("ElixirSenseExample.ModuleWithDocs.some_fun_no_doc(1)", 1, 40)

      assert doc == %{
               docs: "",
               kind: :function,
               metadata: %{defaults: 1},
               module: ElixirSenseExample.ModuleWithDocs,
               args: ["a", "b \\\\ nil"],
               arity: 2,
               function: :some_fun_no_doc,
               specs: []
             }
    end

    test "retrieve function documentation" do
      buffer = """
      defmodule MyModule do
        def func(list) do
          List.flatten(list)
        end
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 3, 12)

      assert %{
               args: ["list"],
               function: :flatten,
               module: List,
               metadata: %{},
               specs: ["@spec flatten(deep_list) :: list() when deep_list: [any() | deep_list]"],
               kind: :function
             } = doc

      assert doc.docs =~ """
             Flattens the given `list` of nested lists.
             """
    end

    test "retrieve metadata function documentation" do
      buffer = """
      defmodule MyLocalModule do
        @doc "Sample doc"
        @doc since: "1.2.3"
        @spec flatten(list()) :: list()
        def flatten(list) do
          []
        end
      end

      defmodule MyModule do
        def func(list) do
          MyLocalModule.flatten(list)
        end
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 12, 20)

      assert doc == %{
               args: ["list"],
               function: :flatten,
               arity: 1,
               module: MyLocalModule,
               metadata: %{},
               specs: ["@spec flatten(list()) :: list()"],
               docs: "",
               kind: :function
             }

      #  TODO docs and metadata
    end

    test "retrieve local private metadata function documentation" do
      buffer = """
      defmodule MyLocalModule do
        @doc "Sample doc"
        @doc since: "1.2.3"
        @spec flatten(list()) :: list()
        defp flatten(list) do
          []
        end

        def func(list) do
          flatten(list)
        end
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 10, 7)

      assert doc == %{
               args: ["list"],
               arity: 1,
               function: :flatten,
               module: MyLocalModule,
               metadata: %{},
               specs: ["@spec flatten(list()) :: list()"],
               docs: "",
               kind: :function
             }

      #  TODO docs and metadata
    end

    test "retrieve metadata function documentation - fallback to callback in metadata" do
      buffer = """
      defmodule MyBehaviour do
        @doc "Sample doc"
        @doc since: "1.2.3"
        @callback flatten(list()) :: list()
      end

      defmodule MyLocalModule do
        @behaviour MyBehaviour

        @impl true
        def flatten(list) do
          []
        end
      end

      defmodule MyModule do
        def func(list) do
          MyLocalModule.flatten(list)
        end
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 18, 20)

      assert doc == %{
               args: ["list"],
               arity: 1,
               function: :flatten,
               kind: :function,
               metadata: %{implementing: MyBehaviour},
               module: MyLocalModule,
               specs: ["@callback flatten(list()) :: list()"],
               docs: ""
             }

      # TODO hidden: true in metadata
      # TODO docs and metadata
    end

    test "retrieve metadata function documentation - fallback to callback in metadata no @impl" do
      buffer = """
      defmodule MyBehaviour do
        @doc "Sample doc"
        @doc since: "1.2.3"
        @callback flatten(list()) :: list()
      end

      defmodule MyLocalModule do
        @behaviour MyBehaviour

        def flatten(list) do
          []
        end
      end

      defmodule MyModule do
        def func(list) do
          MyLocalModule.flatten(list)
        end
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 17, 20)

      assert doc == %{
               args: ["list"],
               arity: 1,
               function: :flatten,
               kind: :function,
               metadata: %{implementing: MyBehaviour},
               module: MyLocalModule,
               specs: ["@callback flatten(list()) :: list()"],
               docs: ""
             }

      #  TODO docs and metadata
    end

    test "retrieve metadata function documentation - fallback to protocol function in metadata" do
      buffer = """
      defprotocol BB do
        @doc "asdf"
        @spec go(t) :: integer()
        def go(t)
      end

      defimpl BB, for: String do
        def go(t), do: ""
      end

      defmodule MyModule do
        def func(list) do
          BB.String.go(list)
        end
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 13, 16)

      assert doc == %{
               args: ["t"],
               function: :go,
               arity: 1,
               kind: :function,
               metadata: %{implementing: BB},
               module: BB.String,
               specs: ["@callback go(t) :: integer()"],
               docs: ""
             }

      #  TODO docs and metadata
    end

    test "retrieve documentation of local macro" do
      buffer = """
      defmodule MyModule do
        defmacrop some(var), do: Macro.expand(var, __CALLER__)

        defmacro other do
          some(1)
        end
      end
      """

      assert %{
               docs: [_doc]
             } = ElixirSense.docs(buffer, 5, 6)
    end

    test "find definition of local macro on definition" do
      buffer = """
      defmodule MyModule do
        defmacrop some(var), do: Macro.expand(var, __CALLER__)

        defmacro other do
          some(1)
        end
      end
      """

      assert %{
               docs: [_doc]
             } = ElixirSense.docs(buffer, 2, 14)
    end

    test "does not find definition of local macro if it's defined after the cursor" do
      buffer = """
      defmodule MyModule do
        defmacro other do
          some(1)
        end

        defmacrop some(var), do: Macro.expand(var, __CALLER__)
      end
      """

      assert ElixirSense.docs(buffer, 3, 6) == nil
    end

    test "find definition of local function even if it's defined after the cursor" do
      buffer = """
      defmodule MyModule do
        def other do
          some(1)
        end

        defp some(var), do: :ok
      end
      """

      assert %{
               docs: [_doc]
             } = ElixirSense.docs(buffer, 3, 6)
    end

    test "retrieve metadata macro documentation - fallback to macrocallback in metadata" do
      buffer = """
      defmodule MyBehaviour do
        @doc "Sample doc"
        @doc since: "1.2.3"
        @macrocallback flatten(list()) :: list()
      end

      defmodule MyLocalModule do
        @behaviour MyBehaviour

        @impl true
        defmacro flatten(list) do
          []
        end
      end

      defmodule MyModule do
        require MyLocalModule
        def func(list) do
          MyLocalModule.flatten(list)
        end
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 19, 20)

      assert doc == %{
               args: ["list"],
               arity: 1,
               function: :flatten,
               kind: :macro,
               metadata: %{implementing: MyBehaviour},
               module: MyLocalModule,
               specs: ["@macrocallback flatten(list()) :: list()"],
               docs: ""
             }

      #  TODO docs and metadata
    end

    test "retrieve metadata function documentation - fallback to callback" do
      buffer = """
      defmodule MyLocalModule do
        @behaviour ElixirSenseExample.BehaviourWithMeta

        @impl true
        def flatten(list) do
          []
        end
      end

      defmodule MyModule do
        def func(list) do
          MyLocalModule.flatten(list)
        end
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 12, 20)

      assert doc == %{
               args: ["list"],
               function: :flatten,
               arity: 1,
               kind: :function,
               metadata: %{
                 implementing: ElixirSenseExample.BehaviourWithMeta,
                 since: "1.2.3"
               },
               module: MyLocalModule,
               specs: ["@callback flatten(list()) :: list()"],
               docs: "Sample doc"
             }

      # TODO hidden: true in metadata
    end

    test "retrieve metadata function documentation - fallback to callback no @impl" do
      buffer = """
      defmodule MyLocalModule do
        @behaviour ElixirSenseExample.BehaviourWithMeta

        def flatten(list) do
          []
        end
      end

      defmodule MyModule do
        def func(list) do
          MyLocalModule.flatten(list)
        end
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 11, 20)

      assert doc == %{
               args: ["list"],
               function: :flatten,
               arity: 1,
               kind: :function,
               metadata: %{
                 implementing: ElixirSenseExample.BehaviourWithMeta,
                 since: "1.2.3"
               },
               module: MyLocalModule,
               specs: ["@callback flatten(list()) :: list()"],
               docs: "Sample doc"
             }
    end

    test "retrieve metadata function documentation - fallback to erlang callback" do
      buffer = """
      defmodule MyLocalModule do
        @behaviour :gen_statem

        @impl true
        def init(list) do
          []
        end
      end

      defmodule MyModule do
        def func(list) do
          MyLocalModule.init(list)
        end
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 12, 20)

      assert %{
               args: ["list"],
               function: :init,
               module: MyLocalModule,
               kind: :function
             } = doc

      if ExUnitConfig.erlang_eep48_supported() do
        assert doc.docs =~
                 "this function is called by"

        assert %{since: "OTP 19.0", implementing: :gen_statem} = doc.metadata
      end
    end

    test "retrieve metadata macro documentation - fallback to macrocallback" do
      buffer = """
      defmodule MyLocalModule do
        @behaviour ElixirSenseExample.BehaviourWithMeta

        @impl true
        defmacro bar(list) do
          []
        end
      end

      defmodule MyModule do
        require MyLocalModule
        def func(list) do
          MyLocalModule.bar(list)
        end
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 13, 20)

      # assert actual_subject == "MyLocalModule.bar"
      assert doc == %{
               args: ["list"],
               arity: 1,
               function: :bar,
               module: MyLocalModule,
               metadata: %{since: "1.2.3", implementing: ElixirSenseExample.BehaviourWithMeta},
               specs: ["@macrocallback bar(integer()) :: Macro.t()"],
               docs: "Docs for bar",
               kind: :macro
             }
    end

    test "retrieve local private metadata function documentation on __MODULE__ call" do
      buffer = """
      defmodule MyLocalModule do
        @doc "Sample doc"
        @doc since: "1.2.3"
        @spec flatten(list()) :: list()
        def flatten(list) do
          []
        end

        def func(list) do
          __MODULE__.flatten(list)
        end
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 10, 17)

      assert doc == %{
               args: ["list"],
               arity: 1,
               function: :flatten,
               module: MyLocalModule,
               metadata: %{},
               specs: ["@spec flatten(list()) :: list()"],
               docs: "",
               kind: :function
             }

      #  TODO docs and metadata
    end

    @tag requires_elixir_1_14: true
    test "retrieve local private metadata function documentation on __MODULE__ submodule call" do
      buffer = """
      defmodule MyLocalModule do
        defmodule Sub do
          @doc "Sample doc"
          @doc since: "1.2.3"
          @spec flatten(list()) :: list()
          def flatten(list) do
            []
          end
        end

        def func(list) do
          __MODULE__.Sub.flatten(list)
        end
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 12, 20)

      assert doc == %{
               args: ["list"],
               function: :flatten,
               arity: 1,
               kind: :function,
               metadata: %{},
               module: MyLocalModule.Sub,
               specs: ["@spec flatten(list()) :: list()"],
               docs: ""
             }

      #  TODO docs and metadata
    end

    test "does not retrieve remote private metadata function documentation" do
      buffer = """
      defmodule MyLocalModule do
        @doc "Sample doc"
        @doc since: "1.2.3"
        @spec flatten(list()) :: list()
        defp flatten(list) do
          []
        end
      end

      defmodule MyModule do
        def func(list) do
          MyLocalModule.flatten(list)
        end
      end
      """

      assert nil == ElixirSense.docs(buffer, 12, 20)
    end

    test "retrieve metadata function documentation with @doc false" do
      buffer = """
      defmodule MyLocalModule do
        @doc false
        @spec flatten(list()) :: list()
        def flatten(list) do
          []
        end
      end

      defmodule MyModule do
        def func(list) do
          MyLocalModule.flatten(list)
        end
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 11, 20)

      assert doc == %{
               args: ["list"],
               arity: 1,
               function: :flatten,
               kind: :function,
               metadata: %{},
               module: MyLocalModule,
               specs: ["@spec flatten(list()) :: list()"],
               docs: ""
             }

      #  TODO mark as hidden in metadata
    end

    test "retrieve function documentation on @attr call" do
      buffer = """
      defmodule MyModule do
        @attr List
        @attr.flatten(list)
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 3, 12)

      assert %{
               args: ["list"],
               function: :flatten,
               module: List,
               metadata: %{},
               specs: ["@spec flatten(deep_list) :: list() when deep_list: [any() | deep_list]"],
               kind: :function
             } = doc

      assert doc.docs =~ """
             Flattens the given `list` of nested lists.
             """
    end

    test "retrieve erlang function documentation" do
      buffer = """
      defmodule MyModule do
        def func(list) do
          :lists.flatten(list)
        end
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 3, 12)

      assert %{
               args: ["deepList"],
               function: :flatten,
               module: :lists,
               kind: :function
             } = doc

      if ExUnitConfig.erlang_eep48_supported() do
        assert doc.docs =~ """
               Returns a flattened version of `DeepList`\\.
               """

        assert %{signature: _} = doc.metadata
      end
    end

    @tag requires_otp_23: true
    test "retrieve fallback erlang builtin function documentation" do
      buffer = """
      defmodule MyModule do
        def func(list) do
          :erlang.or(a, b)
          :erlang.orelse(a, b)
        end
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 3, 14)

      assert %{
               arity: 2,
               function: :or,
               module: :erlang,
               specs: ["@spec boolean() or boolean() :: boolean()"],
               docs: "",
               kind: :function
             } = doc

      if String.to_integer(System.otp_release()) < 25 do
        assert doc.args == ["boolean", "boolean"]
        assert doc.metadata == %{}
      else
        assert doc.args == ["term", "term"]
        assert doc.metadata == %{hidden: true}
      end

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 4, 14)

      assert %{
               args: ["term", "term"],
               arity: 2,
               function: :orelse,
               module: :erlang,
               metadata: %{builtin: true},
               specs: [],
               docs: "",
               kind: :function
             } = doc
    end

    test "retrieve macro documentation" do
      buffer = """
      defmodule MyModule do
        require ElixirSenseExample.BehaviourWithMacrocallback.Impl, as: Macros
        Macros.some({})
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 3, 12)

      assert doc == %{
               args: ["var"],
               function: :some,
               arity: 1,
               module: ElixirSenseExample.BehaviourWithMacrocallback.Impl,
               metadata: %{},
               specs: [
                 "@spec some(integer()) :: Macro.t()\n@spec some(b) :: Macro.t() when b: float()"
               ],
               docs: "some macro\n",
               kind: :macro
             }
    end

    @tag requires_elixir_1_14: true
    test "retrieve function documentation with __MODULE__ submodule call" do
      buffer = """
      defmodule Inspect do
        def func(list) do
          __MODULE__.Algebra.string(list)
        end
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 3, 26)

      assert %{
               args: ["string"],
               function: :string,
               module: Inspect.Algebra,
               metadata: %{since: "1.6.0"},
               specs: ["@spec string(String.t()) :: doc_string()"],
               kind: :function
             } = doc

      assert doc.docs =~ "Creates a document"
    end

    test "retrieve function documentation from aliased modules" do
      buffer = """
      defmodule MyModule do
        alias List, as: MyList
        MyList.flatten([])
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 3, 12)

      assert %{
               args: ["list"],
               function: :flatten,
               module: List,
               metadata: %{},
               specs: ["@spec flatten(deep_list) :: list() when deep_list: [any() | deep_list]"],
               kind: :function
             } = doc

      assert doc.docs =~ """
             Flattens the given `list` of nested lists.
             """
    end

    test "retrieve function documentation from imported modules" do
      buffer = """
      defmodule MyModule do
        import Mix.Generator
        create_file("a", "b")
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 3, 5)

      assert %{
               args: ["path", "contents", "opts \\\\ []"],
               function: :create_file,
               module: Mix.Generator,
               metadata: %{defaults: 1},
               specs: ["@spec create_file(Path.t(), iodata(), keyword()) :: boolean()"],
               kind: :function
             } = doc

      assert doc.docs =~ "Creates a file with the given contents"
    end

    test "find built-in functions" do
      # module_info is defined by default for every elixir and erlang module
      # __info__ is defined for every elixir module
      # behaviour_info is defined for every behaviour and every protocol
      buffer = """
      defmodule MyModule do
        ElixirSenseExample.ModuleWithFunctions.module_info()
        #                                      ^
        ElixirSenseExample.ModuleWithFunctions.module_info(:exports)
        #                                      ^
        ElixirSenseExample.ModuleWithFunctions.__info__(:macros)
        #                                      ^
        ElixirSenseExample.ExampleBehaviour.behaviour_info(:callbacks)
        #                                      ^
      end
      """

      assert %{
               docs: [doc]
             } = ElixirSense.docs(buffer, 2, 42)

      assert doc == %{
               args: [],
               function: :module_info,
               module: ElixirSenseExample.ModuleWithFunctions,
               arity: 0,
               metadata: %{builtin: true},
               specs: [
                 "@spec module_info :: [{:module | :attributes | :compile | :exports | :md5 | :native, term}]"
               ],
               docs: "",
               kind: :function
             }

      assert %{
               docs: [doc]
             } = ElixirSense.docs(buffer, 4, 42)

      assert doc == %{
               args: ["key"],
               arity: 1,
               function: :module_info,
               module: ElixirSenseExample.ModuleWithFunctions,
               metadata: %{builtin: true},
               specs: [
                 "@spec module_info(:module) :: atom",
                 "@spec module_info(:attributes | :compile) :: [{atom, term}]",
                 "@spec module_info(:md5) :: binary",
                 "@spec module_info(:exports | :functions | :nifs) :: [{atom, non_neg_integer}]",
                 "@spec module_info(:native) :: boolean"
               ],
               docs: "",
               kind: :function
             }

      assert %{docs: [%{function: :__info__}]} =
               ElixirSense.docs(buffer, 6, 42)

      assert %{docs: [%{function: :behaviour_info}]} =
               ElixirSense.docs(buffer, 8, 42)
    end

    test "built-in functions cannot be called locally" do
      # module_info is defined by default for every elixir and erlang module
      # __info__ is defined for every elixir module
      # behaviour_info is defined for every behaviour and every protocol
      buffer = """
      defmodule MyModule do
        import GenServer
        @ callback cb() :: term
        module_info()
        #^
        __info__(:macros)
        #^
        behaviour_info(:callbacks)
        #^
      end
      """

      refute ElixirSense.docs(buffer, 4, 5)

      refute ElixirSense.docs(buffer, 6, 5)

      refute ElixirSense.docs(buffer, 8, 5)
    end

    test "retrieve function documentation from behaviour if available" do
      buffer = """
      defmodule MyModule do
        import ElixirSenseExample.ExampleBehaviourWithDocCallbackNoImpl
        foo()
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 3, 5)

      assert doc == %{
               args: [],
               function: :foo,
               arity: 0,
               module: ElixirSenseExample.ExampleBehaviourWithDocCallbackNoImpl,
               metadata: %{implementing: ElixirSenseExample.ExampleBehaviourWithDoc},
               specs: ["@callback foo() :: :ok"],
               docs: "Docs for foo",
               kind: :function
             }
    end

    test "retrieve function documentation from behaviour even if @doc is set to false vie @impl" do
      buffer = """
      defmodule MyModule do
        import ElixirSenseExample.ExampleBehaviourWithDocCallbackImpl
        baz(1)
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 3, 5)

      assert doc == %{
               args: ["a"],
               function: :baz,
               arity: 1,
               module: ElixirSenseExample.ExampleBehaviourWithDocCallbackImpl,
               specs: ["@callback baz(integer()) :: :ok"],
               metadata: %{implementing: ElixirSenseExample.ExampleBehaviourWithDoc, hidden: true},
               docs: "Docs for baz",
               kind: :function
             }
    end

    test "retrieve function documentation from behaviour when callback has @doc false" do
      buffer = """
      defmodule MyModule do
        import ElixirSenseExample.ExampleBehaviourWithNoDocCallbackImpl
        foo()
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 3, 5)

      assert doc == %{
               args: [],
               function: :foo,
               arity: 0,
               module: ElixirSenseExample.ExampleBehaviourWithNoDocCallbackImpl,
               metadata: %{
                 implementing: ElixirSenseExample.ExampleBehaviourWithNoDoc,
                 hidden: true
               },
               specs: ["@callback foo() :: :ok"],
               docs: "",
               kind: :function
             }
    end

    test "retrieve macro documentation from behaviour if available" do
      buffer = """
      defmodule MyModule do
        import ElixirSenseExample.ExampleBehaviourWithDocCallbackNoImpl
        bar(1)
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 3, 5)

      assert doc == %{
               args: ["b"],
               arity: 1,
               function: :bar,
               module: ElixirSenseExample.ExampleBehaviourWithDocCallbackNoImpl,
               metadata: %{implementing: ElixirSenseExample.ExampleBehaviourWithDoc},
               specs: ["@macrocallback bar(integer()) :: Macro.t()"],
               docs: "Docs for bar",
               kind: :macro
             }
    end

    @tag requires_otp_25: true
    test "retrieve erlang behaviour implementation" do
      buffer = """
      :file_server.init(a)
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 1, 16)

      assert %{
               args: ["args"],
               function: :init,
               module: :file_server,
               specs: ["@callback init(args :: term())" <> _],
               metadata: %{implementing: :gen_server},
               kind: :function
             } = doc

      assert doc.docs =~ "Whenever a `gen_server` process is started"
    end

    test "do not crash for erlang behaviour callbacks" do
      buffer = """
      defmodule MyModule do
        import ElixirSenseExample.ExampleBehaviourWithDocCallbackErlang
        init(:ok)
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 3, 5)

      assert %{
               args: ["_"],
               function: :init,
               module: ElixirSenseExample.ExampleBehaviourWithDocCallbackErlang
             } = doc

      if ExUnitConfig.erlang_eep48_supported() do
        assert doc.docs =~ "called by the new process"
        assert %{since: "OTP 19.0", implementing: :gen_statem} = doc.metadata
      else
        assert doc.docs == ""
        assert doc.metadata == %{}
      end
    end
  end

  describe "types" do
    test "type with @typedoc false" do
      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.ModuleWithDocs, as: Remote
        @type my_list :: Remote.some_type_doc_false
        #                           ^
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 3, 31)

      assert doc == %{
               args: [],
               arity: 0,
               docs: "",
               kind: :type,
               metadata: %{hidden: true},
               module: ElixirSenseExample.ModuleWithDocs,
               spec: "@type some_type_doc_false() :: integer()",
               type: :some_type_doc_false
             }
    end

    test "type no @typedoc" do
      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.ModuleWithDocs, as: Remote
        @type my_list :: Remote.some_type_no_doc
        #                           ^
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 3, 31)

      assert doc == %{
               args: [],
               arity: 0,
               docs: "",
               kind: :type,
               metadata: %{},
               module: ElixirSenseExample.ModuleWithDocs,
               spec: "@type some_type_no_doc() :: integer()",
               type: :some_type_no_doc
             }
    end

    test "retrieve type documentation" do
      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.ModuleWithTypespecs.Remote
        @type my_list :: Remote.remote_t
        #                           ^
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 3, 31)

      assert doc == %{
               args: [],
               arity: 0,
               docs: "Remote type",
               kind: :type,
               metadata: %{},
               module: ElixirSenseExample.ModuleWithTypespecs.Remote,
               spec: "@type remote_t() :: atom()",
               type: :remote_t
             }
    end

    test "retrieve metadata type documentation" do
      buffer = """
      defmodule MyLocalModule do
        @typedoc "My example type"
        @typedoc since: "1.2.3"
        @type some(a) :: {a}
      end

      defmodule MyModule do
        @type my_list :: MyLocalModule.some(:a)
        #                               ^
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 8, 35)

      assert doc == %{
               args: ["a"],
               type: :some,
               arity: 1,
               module: MyLocalModule,
               metadata: %{},
               spec: "@type some(a) :: {a}",
               docs: "",
               kind: :type
             }

      # TODO docs and metadata
    end

    test "retrieve local private metadata type documentation" do
      buffer = """
      defmodule MyLocalModule do
        @typedoc "My example type"
        @typedoc since: "1.2.3"
        @typep some(a) :: {a}

        @type my_list :: some(:a)
        #                  ^
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 6, 22)

      assert doc == %{
               args: ["a"],
               type: :some,
               arity: 1,
               module: MyLocalModule,
               spec: "@typep some(a) :: {a}",
               metadata: %{},
               docs: "",
               kind: :type
             }

      # TODO docs and metadata
    end

    test "retrieve local metadata type documentation even if it's defined after cursor" do
      buffer = """
      defmodule MyModule do
        @type remote_list_t :: [my_t]
        #                         ^

        @typep my_t :: integer
      end
      """

      assert %{docs: [_]} =
               ElixirSense.docs(buffer, 2, 29)
    end

    test "does not retrieve remote private metadata type documentation" do
      buffer = """
      defmodule MyLocalModule do
        @typedoc "My example type"
        @typedoc since: "1.2.3"
        @typep some(a) :: {a}
      end

      defmodule MyModule do
        @type my_list :: MyLocalModule.some(:a)
        #                               ^
      end
      """

      assert nil == ElixirSense.docs(buffer, 8, 35)
    end

    test "does not reveal details for opaque metadata type" do
      buffer = """
      defmodule MyLocalModule do
        @typedoc "My example type"
        @typedoc since: "1.2.3"
        @opaque some(a) :: {a}
      end

      defmodule MyModule do
        @type my_list :: MyLocalModule.some(:a)
        #                               ^
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 8, 35)

      assert doc == %{
               args: ["a"],
               type: :some,
               arity: 1,
               module: MyLocalModule,
               spec: "@opaque some(a)",
               metadata: %{},
               docs: "",
               kind: :type
             }

      # TODO docs and metadata
    end

    test "retrieve metadata type documentation with @typedoc false" do
      buffer = """
      defmodule MyLocalModule do
        @typedoc false
        @type some(a) :: {a}
      end

      defmodule MyModule do
        @type my_list :: MyLocalModule.some(:a)
        #                               ^
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 7, 35)

      assert doc == %{
               args: ["a"],
               type: :some,
               arity: 1,
               module: MyLocalModule,
               spec: "@type some(a) :: {a}",
               metadata: %{},
               docs: "",
               kind: :type
             }

      # TODO mark as hidden
    end

    test "does not reveal opaque type details" do
      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.CallbackOpaque
        @type my_list :: CallbackOpaque.t(integer)
        #                               ^
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 3, 35)

      assert doc == %{
               args: ["x"],
               type: :t,
               arity: 1,
               module: ElixirSenseExample.CallbackOpaque,
               spec: "@opaque t(x)",
               metadata: %{opaque: true},
               docs: "Opaque type\n",
               kind: :type
             }
    end

    test "retrieve erlang type documentation" do
      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.ModuleWithTypespecs.Remote
        @type my_list :: :erlang.time_unit
        #                           ^
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 3, 31)

      assert %{
               args: [],
               type: :time_unit,
               module: :erlang,
               spec: "@type time_unit() ::\n  pos_integer()" <> _,
               kind: :type
             } = doc

      if ExUnitConfig.erlang_eep48_supported() do
        assert doc.docs =~ """
               Supported time unit representations:
               """

        assert %{signature: _} = doc.metadata
      end
    end

    test "retrieve builtin type documentation" do
      buffer = """
      defmodule MyModule do
        @type options :: keyword
        #                   ^
        @type options1 :: keyword(integer)
        #                   ^
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 2, 23)

      assert doc == %{
               args: [],
               type: :keyword,
               arity: 0,
               module: nil,
               spec: "@type keyword() :: [{atom(), any()}]",
               metadata: %{builtin: true},
               docs: "A keyword list",
               kind: :type
             }

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 4, 23)

      assert doc == %{
               args: ["t"],
               type: :keyword,
               arity: 1,
               module: nil,
               metadata: %{builtin: true},
               spec: "@type keyword(t()) :: [{atom(), t()}]",
               docs: "A keyword list with values of type `t`",
               kind: :type
             }
    end

    test "retrieve basic type documentation" do
      buffer = """
      defmodule MyModule do
        @type num :: integer
        #               ^
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 2, 19)

      assert doc == %{
               args: [],
               type: :integer,
               module: nil,
               arity: 0,
               spec: "@type integer()",
               metadata: %{builtin: true},
               docs: "An integer number",
               kind: :type
             }
    end

    test "retrieve basic and builtin type documentation" do
      buffer = """
      defmodule MyModule do
        @type num :: list()
        #              ^
        @type num1 :: list(atom)
        #              ^
      end
      """

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 2, 18)

      assert doc == %{
               args: [],
               type: :list,
               arity: 0,
               module: nil,
               spec: "@type list() :: [any()]",
               metadata: %{builtin: true},
               docs: "A list",
               kind: :type
             }

      %{
        docs: [doc]
      } = ElixirSense.docs(buffer, 4, 18)

      assert doc == %{
               args: ["t"],
               type: :list,
               arity: 1,
               module: nil,
               spec: "@type list(t())",
               metadata: %{builtin: true},
               docs: "Proper list ([]-terminated)",
               kind: :type
             }
    end
  end

  describe "attributes" do
    test "retrieve reserved module attributes documentation" do
      buffer = """
      defmodule MyModule do
        @on_load :on_load

        def on_load(), do: :ok
      end
      """

      assert %{
               docs: [doc]
             } = ElixirSense.docs(buffer, 2, 6)

      assert doc == %{
               name: "on_load",
               docs: "A hook that will be invoked whenever the module is loaded.",
               kind: :attribute
             }
    end

    test "retrieve unreserved module attributes documentation" do
      buffer = """
      defmodule MyModule do
        @my_attribute nil
      end
      """

      assert %{
               docs: [doc]
             } = ElixirSense.docs(buffer, 2, 6)

      assert doc == %{name: "my_attribute", docs: "", kind: :attribute}
    end
  end

  test "retrieve docs on reserved words" do
    buffer = """
    defmodule MyModule do
    end
    """

    if Version.match?(System.version(), ">= 1.14.0") do
      assert %{
               docs: [doc]
             } = ElixirSense.docs(buffer, 1, 21)

      assert doc == %{name: "do", docs: "do-end block control keyword", kind: :keyword}
    else
      assert nil == ElixirSense.docs(buffer, 1, 21)
    end
  end

  describe "variables" do
    test "retrieve docs on variables" do
      buffer = """
      defmodule MyModule do
        def fun(my_var) do
          other_var = 5
          abc(my_var, other_var)
        end
      end
      """

      assert %{
               docs: [doc]
             } = ElixirSense.docs(buffer, 2, 12)

      assert doc == %{name: "my_var", kind: :variable}

      assert %{
               docs: [doc]
             } = ElixirSense.docs(buffer, 3, 6)

      assert doc == %{name: "other_var", kind: :variable}
    end

    test "variables shadow builtin functions" do
      buffer = """
      defmodule Vector do
        @spec magnitude(Vec2.t()) :: number()
        def magnitude(%Vec2{} = v), do: :math.sqrt(:math.pow(v.x, 2) + :math.pow(v.y, 2))

        @spec normalize(Vec2.t()) :: Vec2.t()
        def normalize(%Vec2{} = v) do
          length = magnitude(v)
          %{v | x: v.x / length, y: v.y / length}
        end
      end
      """

      assert %{
               docs: [%{kind: :variable}]
             } = ElixirSense.docs(buffer, 7, 6)

      assert %{
               docs: [%{kind: :variable}]
             } = ElixirSense.docs(buffer, 8, 21)
    end
  end

  test "find local type in typespec local def elsewhere" do
    buffer = """
    defmodule ElixirSenseExample.Some do
      @type some_local :: integer

      def some_local(), do: :ok

      @type user :: {some_local, integer}

      def foo do
        some_local
      end
    end
    """

    assert %{docs: [%{kind: :type}]} =
             ElixirSense.docs(buffer, 6, 20)

    assert %{docs: [%{kind: :function}]} =
             ElixirSense.docs(buffer, 9, 9)
  end

  describe "arity" do
    test "retrieves documentation for correct arity function" do
      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.FunctionsWithDefaultArgs, as: F
        def main, do: {F.my_func(), F.my_func("a"), F.my_func(1, 2, 3), F.my_func(1, 2, 3, 4)}
      end
      """

      assert %{docs: [doc]} =
               ElixirSense.docs(buffer, 3, 34)

      assert doc.docs =~ "2 params version"

      assert doc.specs == [
               "@spec my_func(1 | 2) :: binary()",
               "@spec my_func(1 | 2, binary()) :: binary()"
             ]

      # too many arguments
      assert nil == ElixirSense.docs(buffer, 3, 70)
    end

    test "retrieves documentation for all matching arities with incomplete code" do
      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.FunctionsWithDefaultArgs, as: F
        def main, do: F.my_func(
      end
      """

      assert %{docs: docs} =
               ElixirSense.docs(buffer, 3, 20)

      assert length(docs) == 3
      assert Enum.at(docs, 0).docs =~ "no params version"
      assert Enum.at(docs, 1).docs =~ "2 params version"
      assert Enum.at(docs, 2).docs =~ "3 params version"

      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.FunctionsWithDefaultArgs, as: F
        def main, do: F.my_func(1
      end
      """

      assert %{docs: docs} =
               ElixirSense.docs(buffer, 3, 20)

      assert length(docs) == 2
      assert Enum.at(docs, 0).docs =~ "2 params version"
      assert Enum.at(docs, 1).docs =~ "3 params version"

      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.FunctionsWithDefaultArgs, as: F
        def main, do: F.my_func(1, 2,
      end
      """

      assert %{docs: docs} =
               ElixirSense.docs(buffer, 3, 20)

      assert length(docs) == 1
      assert Enum.at(docs, 0).docs =~ "3 params version"

      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.FunctionsWithDefaultArgs, as: F
        def main, do: F.my_func(1, 2, 3
      end
      """

      assert %{docs: docs} =
               ElixirSense.docs(buffer, 3, 20)

      assert length(docs) == 1
      assert Enum.at(docs, 0).docs =~ "3 params version"

      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.FunctionsWithDefaultArgs, as: F
        def main, do: F.my_func(1, 2, 3,
      end
      """

      # too many arguments
      assert nil == ElixirSense.docs(buffer, 3, 20)

      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.FunctionsWithDefaultArgs, as: F
        def main, do: 1 |> F.my_func(
      end
      """

      assert %{docs: docs} =
               ElixirSense.docs(buffer, 3, 26)

      assert length(docs) == 2
      assert Enum.at(docs, 0).docs =~ "2 params version"
      assert Enum.at(docs, 1).docs =~ "3 params version"

      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.FunctionsWithDefaultArgs, as: F
        def main, do: 1 |> F.my_func(1,
      end
      """

      assert %{docs: docs} =
               ElixirSense.docs(buffer, 3, 26)

      assert length(docs) == 1
      assert Enum.at(docs, 0).docs =~ "3 params version"
    end

    test "retrieves documentation for correct arity function capture" do
      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.FunctionsWithDefaultArgs, as: F
        def go, do: &F.my_func/1
      end
      """

      assert %{docs: [doc]} =
               ElixirSense.docs(buffer, 3, 19)

      assert doc.docs =~ "2 params version"

      assert doc.specs == [
               "@spec my_func(1 | 2) :: binary()",
               "@spec my_func(1 | 2, binary()) :: binary()"
             ]
    end

    test "retrieves documentation for correct arity type" do
      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.TypesWithMultipleArity, as: T
        @type some :: {T.my_type, T.my_type(boolean), T.my_type(1, 2), T.my_type(1, 2, 3)}
      end
      """

      assert %{docs: [doc]} =
               ElixirSense.docs(buffer, 3, 32)

      assert doc.docs =~ "one param version"
      assert doc.spec == "@type my_type(a) :: {integer(), a}"

      # too many arguments
      assert nil == ElixirSense.docs(buffer, 3, 68)
    end

    test "retrieves documentation for all matching type arities with incomplete code" do
      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.TypesWithMultipleArity, as: T
        @type some :: T.my_type(
      end
      """

      assert %{docs: docs} =
               ElixirSense.docs(buffer, 3, 20)

      assert length(docs) == 3
      assert Enum.at(docs, 0).docs =~ "no params version"
      assert Enum.at(docs, 1).docs =~ "one param version"
      assert Enum.at(docs, 2).docs =~ "two params version"

      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.TypesWithMultipleArity, as: T
        @type some :: T.my_type(integer
      end
      """

      assert %{docs: docs} =
               ElixirSense.docs(buffer, 3, 20)

      assert length(docs) == 2
      assert Enum.at(docs, 0).docs =~ "one param version"
      assert Enum.at(docs, 1).docs =~ "two params version"

      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.TypesWithMultipleArity, as: T
        @type some :: T.my_type(integer, integer
      end
      """

      assert %{docs: docs} =
               ElixirSense.docs(buffer, 3, 20)

      assert length(docs) == 1
      assert Enum.at(docs, 0).docs =~ "two params version"

      buffer = """
      defmodule MyModule do
        alias ElixirSenseExample.TypesWithMultipleArity, as: T
        @type some :: T.my_type(integer, integer,
      end
      """

      # too many arguments
      assert nil == ElixirSense.docs(buffer, 3, 20)
    end
  end
end
