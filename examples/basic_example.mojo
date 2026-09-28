from moclap import Arg, cli_parse


@fieldwise_init
struct Config(Defaultable, Writable):
    @__annotation(Arg(help="Application name.", short="n"))
    var name: String

    @__annotation(Arg(help="Port to listen on.", short="p"))
    var port: Int

    @__annotation(Arg(help="Enable verbose output.", short="v"))
    var verbose: Bool

    @__annotation(Arg(help="Request timeout in seconds."))
    var timeout: Float64

    @__annotation(Arg(help="Worker pool size.", long="pool-size"))
    var size: UInt

    def __init__(out self):
        self.name = "app"
        self.port = 8080
        self.verbose = False
        self.timeout = 30.0
        self.size = 13


def main() raises:
    var config = cli_parse[Config]()

    print(config)
