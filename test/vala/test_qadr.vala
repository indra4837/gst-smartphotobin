//  Copyright (c) 2021 Michael de Gans

//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:

//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.

//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.

static Gst.Element
make_elem(string name) {
    var maybe_elem = Gst.ElementFactory.make(name, name);
    if (!(maybe_elem is Gst.Element)) {
        error(@"$(name) could not be created");
    }
    return (!)maybe_elem;
}

int main(string[] args) {
    if (args.length != 2) {
        critical("uri for this test required");
        return -1;
    }
    Gst.init(ref args);

    int retcode = 0;
    var loop = new MainLoop();

    var pipe = new Gst.Pipeline("pipe");
    dynamic Gst.Element source = make_elem("uridecodebin");
    source.uri = args[1];
    dynamic Gst.Element qadr = make_elem("qadrbin");
    var sink = make_elem("autovideosink");

    pipe.add_many(source, qadr, sink);
    source.link_many(qadr, sink);

    assert(pipe.set_state(Gst.State.PLAYING) != Gst.StateChangeReturn.FAILURE);

    pipe.get_bus().add_watch(Priority.DEFAULT, (bus, msg) => {
        switch (msg.type) {
            case Gst.MessageType.ERROR: {
                Error err = null;
                string detail = null;
                msg.parse_error(out err, out detail);
                critical(@"$(err.code):$(err.message):$(detail)");
                // we want to forward the error code to the return code, but
                // we can't use 0, so we'll use -1 in that case.
                if (err.code == 0) {
                    retcode = -1;
                } else {
                    retcode = err.code;
                }
                loop.quit();
                break;
            }
            case Gst.MessageType.EOS: {
                loop.quit();
                break;
            }
        }
        return true;
    });

    loop.run();

    return retcode;
}