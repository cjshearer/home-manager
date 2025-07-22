{ config, lib, ... }:

{
  home.file."toron-result.ron".text = lib.hm.generators.toRON { } [
    # numbers
    {
      binary_signed = {
        _prefix = "-";
        _type = "binary";
        _value = "10010";
      };
      binary_unsigned = {
        _type = "binary";
        _value = "10";
      };
      byte = {
        _type = "byte";
        _value = "0";
      };
      decimal_signed = -10;
      decimal_unsigned = 10;
      # TODO: nix adds several trailing zeros to floats, is that an issue?
      float_64 = {
        _type = "f64";
        _value = -0.1;
      };
      float_exp = {
        _value = -1.0;
        _suffix = "e-16";
      };
      float_int = 1000;
      # TODO: nix adds several trailing zeros to floats, is that an issue?
      float_std = 1000.0;
      integer = 0;
      integer_32 = {
        _type = "i32";
        _value = 8;
      };

      hexadecimal = {
        _type = "hex";
        _value = "FF";
      };
      unsigned_octal = {
        _type = "octal";
        _value = "10";
      };
    }
    # chars
    {
      char = {
        _type = "char";
        _value = "a";
      };
    }
    # strings
    {
      byte_string_raw = {
        _prefix = "br##";
        _value = "Hello, World!";
        _suffix = "##";
      };
      byte_string_std = {
        _prefix = "b";
        _value = "Hello, World!";
      };
      string_escape_ascii = "\\'";
      string_escape_byte = "\\x0A";
      string_escape_unicode = "\\u{0A0A}";
      string_raw = {
        _prefix = "r##";
        _value = ''
          This is a "raw string".
          It can contain quotations or backslashes\!'';
        _suffix = "##";
      };
      string_std = "Hello, World!";
    }
    # boolean
    {
      boolean = true;
    }
    # enum
    {
      enum_named_map = {
        _type = "enum";
        _prefix = "Some";
        _value = {
          _type = "struct";
          _value = { map = { }; };
        };
      };
      enum_named_struct = {
        _type = "enum";
        _prefix = "Some";
        _value = {
          _type = "struct";
          _value = {
            struct = {
              _type = "struct";
              _prefix = "ANestedStruct";
              _value = { a = 1; };
            };
          };
        };
      };
      enum_named = {
        _type = "enum";
        _prefix = "Some";
        _value = {
          _type = "struct";
          _value = { named = "field"; };
        };
      };
      enum_none = null;
      enum_tuple = {
        _type = "enum";
        _prefix = "Some";
        _value = {
          _type = "tuple";
          _value = [ "enum" "values" ];
        };
      };
      enum_tuple_string = {
        _type = "enum";
        _prefix = "Some";
        _value = "string";
      };
      enum_tuple_list = {
        _type = "enum";
        _prefix = "Some";
        _value = [ "list" "of" "strings" ];
      };
      enum_tuple_tuple = {
        _type = "enum";
        _prefix = "Some";
        _value = {
          _type = "tuple";
          _value = [ "another" "tuple" ];
        };
      };
    }
    # list
    {
      list = [ 1 2 3 ];
    }
    # map
    {
      ${
        lib.hm.generators.toRON {
          newline = "";
          tab = "";
        } {
          _type = "tuple";
          _value = [ "complex" "keys" ];
        }
      } = "a tuple can also be a key";
      map_empty = { };
      map = {
        a = 1;
        b = 2;
        c = 3;
      };
    }
    # tuple
    {
      tuple = {
        _type = "tuple";
        _value = [ 1 2 3 ];
      };
    }
    # struct
    {
      named_struct = {
        _prefix = "NamedStruct";
        _type = "struct";
        _value = {
          a = 1;
          b = 2;
          c = 3;
        };
      };
      tuple_struct = {
        _type = "tuple";
        _prefix = "TupleStruct";
        _value = [ 1 2 3 ];
      };
      unit_struct = {
        _type = "struct";
        _value = [ ];
      };
      unit_struct_ident = { _prefix = "MyUnitStruct"; };
    }
  ];

  nmt.script = ''
    assertFileContent \
      home-files/toron-result.ron \
      ${./toron-result.ron}
  '';
}
