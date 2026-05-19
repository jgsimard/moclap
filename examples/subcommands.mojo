from std.utils import Variant

from moclap import cli_parse


@fieldwise_init
struct Serve(Defaultable, Movable, Writable, ImplicitlyCopyable):
    var port: Int
    var host: String

    def __init__(out self):
        self.port = 8080
        self.host = "localhost"


@fieldwise_init
struct Build(Defaultable, Movable, Writable, ImplicitlyCopyable):
    var target: String
    var release: Bool

    def __init__(out self):
        self.target = "sys"
        self.release = False


@fieldwise_init
struct Launcher(Defaultable, Movable, Writable, ImplicitlyCopyable):
    var verbose: Bool
    var cmd: Variant[Serve, Build]

    def __init__(out self):
        self.verbose = False
        self.cmd = Serve()


def main() raises:
    var launcher = cli_parse[Launcher]()

    print(launcher)
