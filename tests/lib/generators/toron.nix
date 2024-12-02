{ config, lib, ... }:

{
  home.file."toron-result.ron".text = lib.hm.generators.toRON { } [
    # numbers
    {
      byte = {
        _type = "char";
        _prefix = "b";
        _value = "0";
      };
      # TODO: nix adds several trailing zeros to floats, is that an issue?
      float_exp = {
        _value = -1.0;
        _suffix = "e-16";
      };
      # while nix supports fractional notation, nix fmt will complain about .1
      # that said, consumers of RON shouldn't need fractional notation
      float_frac = { _prefix = ".1"; };
      float_int = 1000;
      # TODO: nix adds several trailing zeros to floats, is that an issue?
      float_std = 1000.0;
      float_suffix = { _prefix = "-.1f64"; };
      integer = 0;
      integer_suffix = {
        _prefix = "i";
        _value = 8;
      };
      unsigned_binary = {
        _prefix = "0b";
        _value = 10;
      };
      unsigned_decimal = 10;
      unsigned_hexadecimal = { _prefix = "0xFF"; };
      unsigned_octal = {
        _prefix = "0o";
        _value = 10;
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
    # option/enum
    {
      enum_nested = {
        _type = "enum";
        _prefix = "Some";
        _value = {
          _type = "enum";
          _prefix = "Some";
          _value = "aString";
        };
      };
      option_none_explicit = {
        _type = "enum";
        _prefix = "None";
        _value = null;
      };
      option_none_implicit = { _prefix = "None"; };
      option_some = {
        _type = "enum";
        _prefix = "Some";
        _value = 10;
      };
    }
    # list
    {
      list = [ 1 2 3 ];
    }
    # map
    {
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
      named_struct_explicit = {
        _prefix = "NamedStruct";
        _type = "struct";
        _value = {
          a = 1;
          b = 2;
          c = 3;
        };
      };
      named_struct_implicit = {
        _prefix = "NamedStruct";
        _value = {
          a = 1;
          b = 2;
          c = 3;
        };
      };
      tuple_struct_explicit = {
        _type = "tuple";
        _prefix = "TupleStruct";
        _value = [ 1 2 3 ];
      };
      tuple_struct_implicit = {
        _prefix = "TupleStruct";
        _value = [ 1 2 3 ];
      };
      unit_struct = {
        _type = "struct";
        _value = [ ];
      };
      unit_struct_ident = { _prefix = "MyUnitStruct"; };
    }
    # complex keys
    {
      ${
        lib.hm.generators.toRON {
          newline = "";
          tab = "";
        } {
          _type = "tuple";
          _value = [ "a" "tuple" ];
        }
      } = "can also be a key";
    }
  ];

  nmt.script = ''
    assertFileContent \
      home-files/toron-result.ron \
      ${./toron-result.ron}
  '';
}
