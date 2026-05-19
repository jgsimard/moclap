from std.sys import argv, exit
from std.reflection import (
    # struct_field_count,
    # struct_field_names,
    # struct_field_types,
    # get_type_name,
    # get_base_type_name,
    # is_struct_type,
    source_location,
    # reflect
)
from std.os.path import basename
from std.utils.numerics import max_finite, min_finite
from std.math import clamp


def cli_parse[T: Defaultable & Movable & Writable & ImplicitlyDestructible]() raises -> T:
    comptime r = reflect[T]
    comptime assert r.is_struct()

    # types
    comptime bool = reflect[Bool].name()
    comptime str = reflect[String].name()

    # index
    comptime int = reflect[Int].name()
    comptime uint = reflect[UInt].name()

    # ints
    comptime ints = {
        # get_type_name[Int](): DType.int,
        reflect[Int8].name(): DType.int8,
        reflect[Int16].name(): DType.int16,
        reflect[Int32].name(): DType.int32,
        reflect[Int64].name(): DType.int64,
        # get_type_name[UInt](): DType.uint,
        reflect[UInt8].name(): DType.uint8,
        reflect[UInt16].name(): DType.uint16,
        reflect[UInt32].name(): DType.uint32,
        reflect[UInt64].name(): DType.uint64,
    }

    # floats
    comptime floats = {
        reflect[Float16].name(): DType.float16,
        reflect[Float32].name(): DType.float32,
        reflect[Float64].name(): DType.float64,
    }

    var args = argv()
    var instance = T()

    # help
    for arg in args:
        if arg in ["--help", "-h"]:
            _print_help[T]()
            exit(0)

    comptime field_count = r.field_count()
    comptime field_names = r.field_names()
    comptime field_types = r.field_types()

    var i = 1
    while i < len(args):
        var arg = args[i]

        if not arg.startswith("--"):
            i += 1
            continue

        var arg_name = arg.strip("-")

        if arg_name not in materialize[field_names]():
            raise Error("Warning: Unknown arg --{}".format(arg_name))

        comptime for idx in range(field_count):
            comptime field_name = field_names[idx]
            comptime field_type = field_types[idx]
            comptime field_type_name = reflect[field_type].name()
            
            if arg_name != field_name:
                continue

            ref field = reflect[T].field_ref[idx](instance)
            comptime assert conforms_to(field_type, ImplicitlyCopyable)
            
            comptime if field_type_name == bool:
                comptime assert conforms_to(field_type, Boolable)
                field = rebind[field_type](~Bool(field))
                break

            var val: StringSlice[StaticConstantOrigin]
            if i + 1 < len(args):
                i += 1
                val = args[i]
            else:
                raise Error("Arg -- {} requires a value".format(arg_name))

            comptime if field_type_name == str:
                var parsed = rebind[field_type](String(val))
                field = parsed^
                break

            # index types
            elif field_type_name == int:
                field = rebind[field_type](atol(val))
                break

            elif field_type_name == uint:
                field = rebind[field_type](UInt(atol(val)))
                break

            # ints
            elif field_type_name in ints:
                comptime dtype = ints.get(field_type_name).value()
                field = rebind[field_type](
                    _parse_int[dtype](val, field_name)
                )
                break

            # floats
            elif field_type_name in floats:
                comptime dtype = floats.get(field_type_name).value()
                field = rebind[field_type](
                    _parse_float[dtype](val, field_name)
                )
                break

            else:
                raise Error(
                    "Cannot parse CLI value for unknown"
                    " type: {}, value:{}".format(field_type_name, val)
                )
        i += 1

    return instance^


def _parse_int[
    type: DType
](val: StringSlice[StaticConstantOrigin], name: String) raises -> Scalar[type]:
    var raw = Int128(atol(val))
    comptime min = Int128(min_finite[type]())
    comptime max = Int128(max_finite[type]())
    if not min <= raw <= max:
        raise Error(
            "Value {} for --{}  is out of bounds for {} : [{}, {}]".format(
                val, name, type, min, max
            )
        )
    return Scalar[type](raw)


def _parse_float[
    type: DType
](val: StringSlice[StaticConstantOrigin], name: String) raises -> Scalar[type]:
    var raw = atof(val)
    comptime min = Float64(min_finite[type]())
    comptime max = Float64(max_finite[type]())
    if not min <= raw <= max:
        raise Error(
            "Value {} for --{}  is out of bounds for {} : [{}, {}]".format(
                val, name, type, min, max
            )
        )
    return Scalar[type](raw)


def _print_help[T: Defaultable & Writable & ImplicitlyDestructible]() raises:
    print("Command Line Parser Help (-h or --help)")
    var loc = source_location()
    var file_name = basename(loc.file_name())
    print("Usage: mojo {} [options]".format(file_name))
    print("\nOptions:")

    comptime r = reflect[T]

    comptime field_names = r.field_names()
    comptime field_types = r.field_types()
    comptime field_count = r.field_count()

    var default = T()

    comptime for i in range(field_count):
        comptime field_name = field_names[i]
        comptime field_type = field_types[i]

        var tn: String = reflect[field_type].name()
        if "SIMD" in tn:
            tn = String(tn[byte=11:].split(",")[0])
            tn = tn.replace("f", "F").replace("u", "U").replace("i", "I")

        ref val = __struct_field_ref(i, default)

        def _get_padding[S: Writable](a: S, max_pad_len: Int = 10) -> String:
            var len = String(a).byte_length()
            return " " * clamp(max_pad_len - len, 1, max_pad_len)

        var pad_name = _get_padding(field_name)
        var pad_def = _get_padding(tn)

        comptime if not conforms_to(field_type, Writable):
            raise "type is not Writable = unable to print help"

        dv = String(trait_downcast[Writable](val))

        print(t"--{field_name} {pad_name}: {tn} {pad_def}(default: {dv})")
