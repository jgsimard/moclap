from std.sys import argv, exit
from std.reflection import source_location
from std.os.path import basename
from std.utils.numerics import max_finite, min_finite
from std.math import clamp


struct Arg(ImplicitlyCopyable):
    var help: StaticString
    var long: StaticString
    var short: StaticString

    def __init__(
        out self,
        *,
        help: StaticString = "",
        long: StaticString = "",
        short: StaticString = "",
    ):
        self.help = help
        self.long = long
        self.short = short


def cli_parse[T: Defaultable & Movable & Deinitable]() raises -> T:
    comptime r = reflect[T]
    comptime assert r.is_struct()

    # types
    comptime bool = reflect[Bool].name()
    comptime str = reflect[String].name()

    # ints
    comptime ints = {
        reflect[Int].name(): DType.int,
        reflect[Int8].name(): DType.int8,
        reflect[Int16].name(): DType.int16,
        reflect[Int32].name(): DType.int32,
        reflect[Int64].name(): DType.int64,
        reflect[Int128].name(): DType.int128,
        reflect[Int256].name(): DType.int256,
        reflect[UInt].name(): DType.uint,
        reflect[UInt8].name(): DType.uint8,
        reflect[UInt16].name(): DType.uint16,
        reflect[UInt32].name(): DType.uint32,
        reflect[UInt64].name(): DType.uint64,
        reflect[UInt128].name(): DType.uint128,
        reflect[UInt256].name(): DType.uint256,
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

        if not arg.startswith("-"):
            raise Error(t"Unexpected positional argument: {arg}")

        var arg_name = arg.strip("-")

        if arg_name not in materialize[field_names]():
            raise Error(t"Warning: Unknown arg --{arg_name}")

        comptime for idx in range(field_count):
            comptime field_name = field_names[idx]
            comptime field_type = field_types[idx]
            comptime field_type_name = reflect[field_type].name()
            var metadata = _arg_metadata[T, idx]()
            var long_name = String(metadata.long)
            if not long_name:
                long_name = field_name

            var is_long = arg.startswith("--") and arg_name == long_name
            var is_short = (
                not arg.startswith("--")
                and metadata.short
                and arg_name == metadata.short
            )
            if not is_long and not is_short:
                continue

            ref field = reflect[T].field_ref[idx](instance)
            comptime assert conforms_to(field_type, ImplicitlyCopyable)
            comptime assert conforms_to(field_type, Deinitable)

            comptime if field_type_name == bool:
                field = rebind[field_type](True)
                break

            var val: StringSlice[ImmStaticOrigin]
            if i + 1 < len(args):
                i += 1
                val = args[i]
            else:
                raise Error(t"Arg --{arg_name} requires a value")

            comptime if field_type_name == str:
                field = rebind[field_type](String(val))
                break

            # ints
            elif field_type_name in ints:
                comptime dtype = ints.get(field_type_name).value()
                field = rebind[field_type](_parse_int[dtype](val, long_name))
                break

            # floats
            elif field_type_name in floats:
                comptime dtype = floats.get(field_type_name).value()
                field = rebind[field_type](_parse_float[dtype](val, long_name))
                break

            raise Error(
                t"Cannot parse value {val} of unknown type {field_type_name}"
            )
        i += 1

    return instance^


def _parse_int[
    type: DType
](val: ImmStringSpan, name: String) raises -> Scalar[type]:
    var raw = Int256(atol(val))
    comptime min = Int256(min_finite[type]())
    comptime max = Int256(max_finite[type]())
    if not min <= raw <= max:
        raise Error(
            t"Value {val} for --{name}  is out of bounds for {type} :"
            t" [{min}, {max}]"
        )
    return Scalar[type](raw)


def _parse_float[
    type: DType
](val: ImmStringSpan, name: String) raises -> Scalar[type]:
    var raw = atof(val)
    comptime min = Float64(min_finite[type]())
    comptime max = Float64(max_finite[type]())
    if not min <= raw <= max:
        raise Error(
            t"Value {val} for --{name}  is out of bounds for {type} :"
            t" [{min}, {max}]"
        )
    return Scalar[type](raw)


def _print_help[T: Defaultable & Deinitable]():
    print("Command Line Parser Help (-h or --help)")
    var loc = source_location()
    var file_name = basename(loc.file_name())
    print(t"Usage: mojo {file_name} [options]")
    print("\nOptions:")

    comptime r = reflect[T]

    comptime field_names = r.field_names()
    comptime field_types = r.field_types()
    comptime field_count = r.field_count()

    var default = T()

    comptime for i in range(field_count):
        comptime field_name = field_names[i]
        comptime field_type = field_types[i]
        var metadata = _arg_metadata[T, i]()
        var long_name = String(metadata.long)
        if not long_name:
            long_name = field_name

        var tn: String = reflect[field_type].name()
        if "SIMD" in tn:
            tn = (
                tn[byte=11:]
                .split(",")[0]
                .replace("f", "F")
                .replace("u", "U")
                .replace("i", "I")
            )

        ref val = reflect[T].field_ref[i](default)

        def _get_padding[S: Writable](a: S, max_pad_len: Int = 10) -> String:
            var len = String(a).byte_length()
            return " " * clamp(max_pad_len - len, 1, max_pad_len)

        var display_name = String(t"--{long_name}")
        if metadata.short:
            display_name = String(t"-{metadata.short}, {display_name}")

        var pad_name = _get_padding(display_name, 14)
        var pad_def = _get_padding(tn)

        comptime assert conforms_to(type_of(val), Writable)

        var help = String(metadata.help)
        if help:
            help = String(t" {help}")
        print(t"{display_name}{pad_name}: {tn} {pad_def}(default: {val}){help}")


def _arg_metadata[T: AnyType, field_index: Int]() -> Arg:
    var result = Arg()
    var annotations = reflect[T].field_annotations[field_index]()
    comptime types = type_of(annotations).Ts
    comptime for i in range(types.length):
        comptime if types[i] == Arg:
            result = rebind[Arg](annotations[i])
    return result^
