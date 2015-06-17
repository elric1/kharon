import subprocess
import pyarrayhash
import pyknc

class ParseError(Exception):
    pass


class ArrayHashStreamParser:
    """ Wrap the array hash C code with some niceties"""
    def __init__(self):
        self.p = pyarrayhash.parse_init()

    def __call__(self, data):
        res = pyarrayhash.parse(self.p, data)
        if res != None:
            return res

        if self.state()[0] == 256:
            raise ParseError("Error Parsing")

    def state(self):
        return pyarrayhash.parser_state(self.p)

    def code(self):
        return pyarrayhash.parser_state(self.p)[1]


class KNC:
    """ A wrapper for the native pyknc calls. """
    def __init__(self, svc, host, port):
        self.svc = svc
        self.host = host
        self.port = port
        self.conn = None
        self.banner = False

    def connect(self):
        self.conn = pyknc.connect(self.svc, self.host, str(self.port))

    def read_banner(self):
        data = pyknc.knc_read(self.conn, 1024)
        p = pyarrayhash.parse_init()
        while 1:
            obj = pyarrayhash.parse(p, data)
            if obj:
                break
            data = pyknc.knc_read(self.conn, 1024)
        self.banner = True
        return obj

    def send(self, data):
        pyknc.knc_write(self.conn, data)

    def read(self, ln):
        return pyknc.knc_read(self.conn, ln)


class KharonCallable:
    """A proxy, to allow pythonic calling of Kharon exported functions"""

    def __init__(self, client, func_name):
        self.client = client
        self.func_name = func_name


    # TODO FIXME Handling redirects as magical
    def __call__(self, *arg, **kwarg):
        if not self.client.banner:
            banner = self.client.read_banner()[0]


        fc = [self.func_name, ]

        if len(arg) > 0:
            fc = fc + list(arg)
        if len(kwarg) > 0:
            for it in kwarg.items():
                fc = fc + list(it)

        fcall = pyarrayhash.encode(fc)
        self.client.send(fcall+"\n")

        parser = ArrayHashStreamParser()

        while 1:
            res = self.client.read(1024)
            if res == None:
                break

            obj = parser(res)
            if obj != None:
                return (parser.code(), obj)

        raise ParseError("Response too short")


class KharonClient:
    """Kharon Client """
    def __init__(self, svc, host, port):
        self.client = KNC(svc, host, port)
        self.client.connect()

    def __getattr__(self, n):
        if n != 'client':
            return KharonCallable(self.client, n)
        return self.client


if __name__ == "__main__":
    kc = KharonClient("krb5_admin", "njekdc1.n.twosigma.com", "5003")
    code, obj =  kc.query("woodyard@N.TWOSIGMA.COM")

    if code == 250:
        for o in obj:
            print o
