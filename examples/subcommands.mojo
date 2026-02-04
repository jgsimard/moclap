from utils import Variant

from moclap import cli_parse


@fieldwise_init
struct Serve(Defaultable, Movable, Writable):
    var port: Int
    var host: String

    fn __init__(out self):
        self.port = 8080
        self.host = "localhost"


@fieldwise_init
struct Build(Defaultable, Movable, Writable):
    var target: String
    var release: Bool

    fn __init__(out self):
        self.target = "sys"
        self.release = False


@fieldwise_init
struct Launcher(Defaultable, Movable, Writable):
    var verbose: Bool
    var cmd: Variant[Serve, Build]

    fn __init__(out self):
        self.verbose = False
        self.cmd = Serve()


fn main() raises:
    var launcher = cli_parse[Launcher]()

    print(launcher)
