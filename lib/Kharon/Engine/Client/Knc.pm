#
# ProtocolEngineClientKnc
#
# Client base class, performs read/write operations on file descriptors
# connected to a server via knc(1)

package Kharon::Engine::Client::Knc;

use NEXT;
use base qw/Kharon::Engine::Client::NetImpl Kharon::Engine::Client::KncImpl/;

1;
